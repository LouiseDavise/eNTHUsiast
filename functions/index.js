const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { google } = require('googleapis');
const fs = require('fs').promises;
const path = require('path');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const { defineSecret } = require('firebase-functions/params');

// Define the secret parameter
const geminiApiKey = defineSecret('GEMINI_API_KEY');

// 1. Initialize Firebase Admin
const serviceAccount = require("./serviceAccountKey.json");
admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});
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
    const model = genAI.getGenerativeModel({
        model: "gemini-2.5-flash",
        generationConfig: { responseMimeType: "application/json" }
    });

    // Step A: Get all users who have linked their Gmail via the Flutter app
    const usersSnapshot = await db.collection('ccxpUsers').get();
    if (usersSnapshot.empty) {
        console.log("No CCXP users found in database.");
        return;
    }

    // Step B: Loop through every user and check their inbox
    for (const userDoc of usersSnapshot.docs) {
        const studentId = userDoc.id; // <--- The document ID is the studentId
        const userData = userDoc.data();

        const email = userData.email;
        const refreshToken = userData.refreshToken;

        // Skip users who haven't linked their Gmail yet
        if (!refreshToken || !email) continue;

        console.log(`Checking emails for student: ${studentId} (${email})`);

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
                    const prompt = `You are an assistant for a university app. Read the following email
and extract the task details into a strict JSON format.

The JSON must have exactly these keys:
- title: A short, clear name for the task
- code: The course code. If none, return ""
- time: The time of the class or deadline. If none, return ""
- type: Must be one of: "Homework", "Midterm", "Final", "Quiz", "Project", or "Other"
- dueDate: The deadline format as YYYY-MM-DD. If none, return ""

Email Text:
${cleanText}`; // Note: Ensure this variable matches your script (cleanText vs clean_text)

                    try {
                        const result = await model.generateContent(prompt);

                        // 2. Safely parse directly without regex because of the MimeType config
                        const aiData = JSON.parse(result.response.text());

                        // 3. Optional but highly recommended: Convert the YYYY-MM-DD string into a true Firestore Timestamp.
                        // This allows you to easily sort by date in Flutter using .orderBy('dueDate') in the future.
                        let firestoreDueDate = null;
                        if (aiData.dueDate && aiData.dueDate !== "") {
                            firestoreDueDate = admin.firestore.Timestamp.fromDate(new Date(aiData.dueDate));
                        }

                        await db.collection('ccxpUsers').doc(studentId).collection('upcoming').doc(msg.id).set({
                            title: aiData.title || "New Task",
                            code: aiData.code || "",
                            time: aiData.time || "",
                            type: aiData.type || "Other",
                            dueDate: firestoreDueDate,
                            id: msg.id,
                            status: "Incomplete",
                            timestamp: admin.firestore.FieldValue.serverTimestamp()
                        });

                    } catch (e) {
                        console.error(`Gemini Parsing Error for message ${msg.id}:`, e);
                    }
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
    const { serverAuthCode, email, studentId } = request.data;

    if (!serverAuthCode || !email || !studentId) {
        throw new HttpsError('invalid-argument', 'Missing serverAuthCode, email, or studentId.');
    }

    try {
        const credsFile = await fs.readFile(CREDENTIALS_PATH, 'utf-8');
        const credentials = JSON.parse(credsFile);
        const { client_secret, client_id } = credentials.installed || credentials.web;

        // Trade the auth code for a permanent refresh token
        const oAuth2Client = new google.auth.OAuth2(client_id, client_secret, "");
        const { tokens } = await oAuth2Client.getToken(serverAuthCode);

        if (tokens.refresh_token) {
            // 2. Save the refresh token and email into the existing CCXP user document
            await db.collection('ccxpUsers').doc(studentId).set({
                email: email,
                refreshToken: tokens.refresh_token,
                gmailLinkedAt: admin.firestore.FieldValue.serverTimestamp()
            }, { merge: true }); // <--- merge: true is CRITICAL so it doesn't delete their CCXP graduation data!

            return { success: true, message: "Gmail successfully linked to CCXP profile!" };
        } else {
            return { success: false, error: "No refresh token received." };
        }

    } catch (error) {
        console.error("Token exchange failed:", error);
        throw new HttpsError('internal', 'Failed to securely link Gmail account.');
    }
});