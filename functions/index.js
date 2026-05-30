const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { google } = require('googleapis');
const fs = require('fs').promises;
const path = require('path');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const { defineSecret } = require('firebase-functions/params');
const pdfParse = require("pdf-parse");

// Define the secret parameter
const geminiApiKey = defineSecret('GEMINI_API_KEY');

// 1. Initialize Firebase Admin
// const serviceAccount = require("./serviceAccountKey.json");
// admin.initializeApp({
//     credential: admin.credential.cert(serviceAccount)
// });
// const db = admin.firestore();
if (!admin.apps.length) {
    admin.initializeApp();
}

const db = admin.firestore();

// 2. Configuration
const CREDENTIALS_PATH = path.join(__dirname, 'credentials.json');
const TARGET_EMAIL = 'louizkwok2@gmail.com';

// 3. Multi-User Gmail Auth
async function authenticateGmail(refreshToken) {
    const credsFile = await fs.readFile(CREDENTIALS_PATH, 'utf-8');
    const credentials = JSON.parse(credsFile);
    const { client_secret, client_id, redirect_uris } = credentials.installed || credentials.web;

    const oAuth2Client = new google.auth.OAuth2(client_id, client_secret, redirect_uris ? redirect_uris[0] : "");

    // Force the client to use the refresh token
    oAuth2Client.setCredentials({ refresh_token: refreshToken });

    // Explicitly refresh the access token before returning the gmail instance
    // This is the missing step that often causes '0 messages found'
    await oAuth2Client.getAccessToken();

    return google.gmail({ version: 'v1', auth: oAuth2Client });
}

async function saveToFirestore(collectionName, newData) {
    await db.collection(collectionName).add(newData);
}

async function clearCollection(collectionRef) {
    const snapshot = await collectionRef.get();
    if (snapshot.empty) return;
    const deletePromises = snapshot.docs.map(doc => doc.ref.delete());
    await Promise.all(deletePromises);
}

// 4. The Core Parsing Logic
async function checkAndParseEmails() {
    const genAI = new GoogleGenerativeAI(geminiApiKey.value());
    const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

    // Step A: Get all users who have linked their Gmail via the Flutter app
    const usersSnapshot = await db.collection('users').get();
    if (usersSnapshot.empty) {
        console.log("No users found in database.");
        return;
    }

    // Step B: Loop through every user and check their inbox
    for (const userDoc of usersSnapshot.docs) {
        const userData = userDoc.data();
        const email = userData.email;
        const refreshToken = userData.refreshToken;

        if (!refreshToken) continue;
        console.log(`Checking emails for user: ${email}`);

        try {
            const gmail = await authenticateGmail(refreshToken);
            const query = `from:${TARGET_EMAIL} is:unread`;
            const res = await gmail.users.messages.list({ userId: 'me', q: query });
            const messages = res.data.messages || [];

            if (messages.length === 0) continue;

            for (const msg of messages) {
                const msgData = await gmail.users.messages.get({ userId: 'me', id: msg.id });
                const payload = msgData.data.payload;

                const headers = payload.headers || [];
                const subjectHeader = headers.find(h => h.name.toLowerCase() === 'subject');
                const subject = subjectHeader ? subjectHeader.value : '';

                let base64Data = payload.parts && payload.parts.length > 0 ? payload.parts[0].body.data : payload.body.data;
                if (!base64Data) continue;

                const cleanText = Buffer.from(base64Data, 'base64').toString('utf-8');
                const snippetText = msgData.data.snippet || '';

                if (subject.includes("<NTHU Bulletin Board>") || cleanText.includes("<NTHU Bulletin Board>")) {
                    await clearCollection(db.collection('bulletins'));

                    let parts = cleanText.split("English Version");
                    let englishContent = parts.length > 1 ? parts[parts.length - 1].trim() : cleanText;

                    const footerMarker = "This message was sent automatically";
                    if (englishContent.includes(footerMarker)) {
                        englishContent = englishContent.split(footerMarker)[0].trim();
                    }

                    await saveToFirestore('bulletins', {
                        id: msg.id,
                        title: "Campus Announcements",
                        snippet: snippetText.split("English Version").pop().substring(0, 50).trim() + "...",
                        fullText: englishContent.replace(/\xa0\xa0/g, '\n\n'),
                        timestamp: admin.firestore.FieldValue.serverTimestamp()
                    });
                } else {
                    const prompt = `Extract task from: ${cleanText}`;
                    try {
                        const result = await model.generateContent(prompt);
                        const aiData = JSON.parse(result.response.text().replace(/```json|```/g, '').trim());

                        // Save the task and link it to the specific user who received it
                        await saveToFirestore('tasks', {
                            ...aiData,
                            id: msg.id,
                            userId: email, // <-- Links task to the user
                            status: "Incomplete",
                            timestamp: admin.firestore.FieldValue.serverTimestamp()
                        });
                    } catch (e) { console.error("Gemini Error:", e); }
                }

                // Mark as read so it isn't processed again
                await gmail.users.messages.modify({ userId: 'me', id: msg.id, requestBody: { removeLabelIds: ['UNREAD'] } });
            }
        } catch (error) {
            console.error(`Failed to process emails for ${email}:`, error);
        }
    }
}

// --- CLOUD FUNCTION 1: The 30-Minute Cron Job ---
exports.nthuEmailParser = onSchedule({
    schedule: "every 30 minutes",
    secrets: [geminiApiKey]
}, async (event) => {
    await checkAndParseEmails();
});

// --- CLOUD FUNCTION 2: The Endpoint for the Flutter App ---
exports.linkGmailAccount = onCall(async (request) => {
    const { serverAuthCode, email } = request.data;

    if (!serverAuthCode || !email) {
        throw new HttpsError('invalid-argument', 'Missing serverAuthCode or email.');
    }

    try {
        const credsFile = await fs.readFile(CREDENTIALS_PATH, 'utf-8');
        const credentials = JSON.parse(credsFile);
        const { client_secret, client_id } = credentials.installed || credentials.web;

        // Trade the auth code for a permanent refresh token
        const oAuth2Client = new google.auth.OAuth2(client_id, client_secret, "");
        const { tokens } = await oAuth2Client.getToken(serverAuthCode);

        if (tokens.refresh_token) {
            // Save the refresh token to Firestore
            await db.collection('users').doc(email).set({
                email: email,
                refreshToken: tokens.refresh_token,
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            }, { merge: true });

            return { success: true, message: "Gmail successfully linked and token saved!" };
        } else {
            return { success: false, error: "No refresh token received. User already granted access previously." };
        }

    } catch (error) {
        console.error("Token exchange failed:", error);
        throw new HttpsError('internal', 'Failed to securely link Gmail account.');
    }
});

// --- CLOUD FUNCTION 3: Parse Curriculum PDF Without Saving PDF ---
// Flutter sends PDF bytes as base64.
// Function parses the PDF.
// Function saves only parsed curriculum JSON to Firestore:
// users/{uid}/curriculum/current

function extractCurriculumJsonObject(text) {
    const start = text.indexOf("{");
    const end = text.lastIndexOf("}");

    if (start === -1 || end === -1 || end <= start) {
        throw new Error("No JSON object found in Gemini response.");
    }

    return text.substring(start, end + 1);
}

function cleanCurriculumGeminiText(text) {
    return text
        .replace(/```json/g, "")
        .replace(/```/g, "")
        .trim();
}

exports.parseCurriculumPdfFromBytes = onCall(
    {
        region: "us-central1",
        memory: "1GiB",
        timeoutSeconds: 300,
        secrets: [geminiApiKey],
    },
    async (request) => {
        if (!request.auth) {
            throw new HttpsError(
                "unauthenticated",
                "You must be logged in before uploading curriculum."
            );
        }

        const uid = request.auth.uid;
        const fileName = request.data.fileName || "curriculum.pdf";
        const pdfBase64 = request.data.pdfBase64 || "";

        const userProfileDoc = await db.collection("users").doc(uid).get();
        const userProfile = userProfileDoc.data() || {};
        const studentId = userProfile.studentId || userProfile.accountStudentId || null;

        if (!pdfBase64 || typeof pdfBase64 !== "string") {
            throw new HttpsError(
                "invalid-argument",
                "Missing PDF data."
            );
        }

        if (!fileName.toLowerCase().endsWith(".pdf")) {
            throw new HttpsError(
                "invalid-argument",
                "Only PDF files are supported."
            );
        }

        const curriculumRef = db
            .collection("users")
            .doc(uid)
            .collection("curriculum")
            .doc("current");

        try {
            await curriculumRef.set(
                {
                    accountStudentId: studentId,
                    studentId: studentId,
                    authUid: uid,
                    status: "processing",
                    fileName: fileName,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                },
                { merge: true }
            );

            const buffer = Buffer.from(pdfBase64, "base64");

            if (buffer.length === 0) {
                throw new Error("PDF file is empty.");
            }

            const maxPdfBytes = 8 * 1024 * 1024;

            if (buffer.length > maxPdfBytes) {
                throw new Error(
                    "PDF is too large. Please upload a smaller curriculum PDF."
                );
            }

            const parsedPdf = await pdfParse(buffer);
            const pdfText = parsedPdf.text || "";

            if (!pdfText.trim()) {
                throw new Error(
                    "PDF text is empty. This file may be scanned/image-only, so Bao-Bao cannot read it yet."
                );
            }

            const genAI = new GoogleGenerativeAI(geminiApiKey.value());
            const model = genAI.getGenerativeModel({
                model: "gemini-2.5-flash",
            });

            const prompt = `
You convert university curriculum PDF text into clean JSON.

Return JSON only. No markdown.

Schema:
{
  "programName": "",
  "department": "",
  "entryYear": "",
  "minimumGraduationCredits": 0,
  "requirementGroups": [
    {
      "category": "",
      "requiredCredits": 0,
      "description": "",
      "courses": [
        {
          "name": "",
          "credits": 0,
          "acceptedCodes": [],
          "type": "",
          "remarks": ""
        }
      ]
    }
  ],
  "notes": []
}

Rules:
- Keep course names exactly when possible.
- acceptedCodes should include course codes like MATH1040, CS1356, EECS2080.
- If one requirement allows multiple course codes, put all codes in acceptedCodes.
- If credits are not clear, use 0.
- Do not invent courses that are not in the text.
- Preserve categories such as GE, required courses, basic core, professional electives, labs, free electives, and graduation credits.
- If there are Chinese course names, preserve them.
- If the PDF has tables, extract the course names, credits, categories, and notes as accurately as possible.

PDF text:
${pdfText.slice(0, 45000)}
`;

            const result = await model.generateContent(prompt);
            const responseText = result.response.text();

            const cleanedText = cleanCurriculumGeminiText(responseText);
            const jsonText = extractCurriculumJsonObject(cleanedText);
            const curriculum = JSON.parse(jsonText);

            await curriculumRef.set(
                {
                    accountStudentId: studentId,
                    studentId: studentId,
                    authUid: uid,
                    status: "ready",
                    fileName: fileName,
                    curriculum: curriculum,
                    parsedTextPreview: pdfText.slice(0, 3000),
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                },
                { merge: true }
            );

            console.log("Curriculum parsed successfully", {
                uid: uid,
                fileName: fileName,
            });

            return {
                ok: true,
                message: "Curriculum parsed successfully.",
            };
        } catch (error) {
            console.error("Curriculum parsing failed:", error);

            await curriculumRef.set(
                {
                    accountStudentId: studentId,
                    studentId: studentId,
                    authUid: uid,
                    status: "error",
                    fileName: fileName,
                    errorMessage: error.message || String(error),
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                },
                { merge: true }
            );

            throw new HttpsError(
                "internal",
                error.message || "Curriculum parsing failed."
            );
        }
    }
);