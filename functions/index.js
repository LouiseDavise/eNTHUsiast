const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { google } = require('googleapis');
const path = require('path');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const { defineSecret } = require('firebase-functions/params');
// const {express} = require('express');
// const {cors} = require('cors');

// const { ccxpKeyGetter, transcribingLocalCaptcha } = require("./scrapper/key_getter.js");
// const { scrapTranscriptPage, scrapCurrentCourse } =require("./scrapper/ccxp_scrapper.js");
// const { parseGraduationData, parseSchedule } = require("./parser/parser.js");
// const { scrapEeclass } = require("./scrapper/eeclass_scrapper.js");

const geminiApiKey = defineSecret('GEMINI_API_KEY');
const gmailCredentials = defineSecret('GMAIL_CREDENTIALS');

const serviceAccount = require("./serviceAccountKey.json");
admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});
const db = admin.firestore();

const ALLOWED_SENDERS = [
    'louizkwok2@gmail.com',
    'louizkwok@gmail.com',
    'no-reply@nthu.edu.tw',
];

// ─────────────────────────────────────────────────────────────────────────────
// BUG 1 FIX: Recursively find the text/plain part in nested multipart emails.
// Gmail wraps content in nested parts; parts[0].body.data is often null.
// ─────────────────────────────────────────────────────────────────────────────
function findPlainTextPart(payload) {
    // Base case: this part itself is text/plain
    if (payload.mimeType === 'text/plain' && payload.body && payload.body.data) {
        return payload.body.data;
    }
    // Recursive case: search nested parts
    if (payload.parts && payload.parts.length > 0) {
        for (const part of payload.parts) {
            const found = findPlainTextPart(part);
            if (found) return found;
        }
    }
    return null;
}

async function authenticateGmail(refreshToken) {
    const credentials = JSON.parse(gmailCredentials.value());
    const { client_secret, client_id, redirect_uris } = credentials.installed || credentials.web;

    const oAuth2Client = new google.auth.OAuth2(
        client_id,
        client_secret,
        redirect_uris ? redirect_uris[0] : ""
    );

    oAuth2Client.setCredentials({ refresh_token: refreshToken });
    await oAuth2Client.getAccessToken();

    return google.gmail({ version: 'v1', auth: oAuth2Client });
}

// BUG 3 FIX: Web users have accessToken instead of refreshToken.
// Authenticate using accessToken directly (short-lived, ~1hr).
async function authenticateGmailWithAccessToken(accessToken) {
    const credentials = JSON.parse(gmailCredentials.value());
    const { client_secret, client_id, redirect_uris } = credentials.installed || credentials.web;

    const oAuth2Client = new google.auth.OAuth2(
        client_id,
        client_secret,
        redirect_uris ? redirect_uris[0] : ""
    );

    // Set accessToken directly — no refresh token needed for short-lived reads
    oAuth2Client.setCredentials({ access_token: accessToken });

    return google.gmail({ version: 'v1', auth: oAuth2Client });
}

async function getOAuthClient() {
    const credentials = JSON.parse(gmailCredentials.value());
    const { client_secret, client_id } = credentials.installed || credentials.web;
    return new google.auth.OAuth2(client_id, client_secret, "");
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

async function checkAndParseEmails() {
    const genAI = new GoogleGenerativeAI(geminiApiKey.value());
    const model = genAI.getGenerativeModel({
        model: "gemini-2.5-flash",
        generationConfig: { responseMimeType: "application/json" }
    });

    const usersSnapshot = await db.collection('ccxpUsers').get();
    if (usersSnapshot.empty) {
        console.log("No CCXP users found in database.");
        return;
    }

    for (const userDoc of usersSnapshot.docs) {
        const studentId = userDoc.id;
        const userData = userDoc.data();

        const email = userData.email;
        const refreshToken = userData.refreshToken;
        const accessToken = userData.accessToken;
        const platform = userData.gmailLinkPlatform;

        // BUG 3 FIX: Skip only if BOTH tokens are missing, not just refreshToken
        if (!email || (!refreshToken && !accessToken)) {
            console.log(`Skipping user ${studentId}: no Gmail credentials linked.`);
            continue;
        }

        console.log(`Checking emails for user: ${studentId} (${email}), platform: ${platform}`);

        try {
            // BUG 3 FIX: Choose auth method based on which token is available
            let gmail;
            if (refreshToken) {
                gmail = await authenticateGmail(refreshToken);
            } else {
                // Web user — use accessToken (may fail if expired ~1hr)
                console.log(`Using web accessToken for ${studentId} (expires after ~1hr)`);
                gmail = await authenticateGmailWithAccessToken(accessToken);
            }

            const fromFilter = ALLOWED_SENDERS.map(e => `from:${e}`).join(' OR ');
            const query = `(${fromFilter}) is:unread`;
            const res = await gmail.users.messages.list({ userId: 'me', q: query });
            const messages = res.data.messages || [];

            if (messages.length === 0) {
                console.log(`No unread messages from ${TARGET_EMAIL} for user ${studentId}.`);
                continue;
            }

            console.log(`Found ${messages.length} unread message(s) for ${studentId}.`);

            for (const msg of messages) {
                const msgData = await gmail.users.messages.get({ userId: 'me', id: msg.id });
                const payload = msgData.data.payload;

                const headers = payload.headers || [];
                const subjectHeader = headers.find(h => h.name.toLowerCase() === 'subject');
                const subject = subjectHeader ? subjectHeader.value : '';

                // BUG 1 FIX: Use recursive search instead of parts[0].body.data
                const base64Data = findPlainTextPart(payload);

                if (!base64Data) {
                    console.warn(`No text/plain content found for message ${msg.id}. Skipping.`);
                    // Still mark as read to avoid re-processing
                    await gmail.users.messages.modify({
                        userId: 'me',
                        id: msg.id,
                        requestBody: { removeLabelIds: ['UNREAD'] }
                    });
                    continue;
                }

                const cleanText = Buffer.from(base64Data, 'base64').toString('utf-8');
                const snippetText = msgData.data.snippet || '';

                console.log(`Processing message ${msg.id}, subject: "${subject}"`);
                console.log(`cleanText preview: ${cleanText.substring(0, 100)}`);

                // BUG 2 NOTE: Subject check is now the primary gate; cleanText is fallback
                const isBulletin = subject.includes("<NTHU Bulletin Board>") || cleanText.includes("<NTHU Bulletin Board>");

                if (isBulletin) {
                    console.log(`→ Identified as BULLETIN for ${studentId}`);
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

                    console.log(`✓ Bulletin saved to Firestore.`);

                } else {
                    console.log(`→ Identified as UPCOMING TASK for ${studentId}, sending to Gemini...`);

                    const prompt = `You are an assistant for a university app. Read the following email
and extract the task details into a strict JSON format.

The JSON must have exactly these keys:
- title: A short, clear name for the task
- code: The course code. If none, return ""
- time: The time of the class or deadline. If none, return ""
- type: Must be one of: "Homework", "Midterm", "Final", "Quiz", "Project", or "Other"
- dueDate: The deadline format as YYYY-MM-DD. If none, return ""

Email Text:
${cleanText}`;

                    try {
                        const result = await model.generateContent(prompt);
                        const aiData = JSON.parse(result.response.text());

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

                        console.log(`✓ Upcoming task "${aiData.title}" saved for ${studentId}.`);

                    } catch (e) {
                        console.error(`Gemini Parsing Error for message ${msg.id}:`, e);
                    }
                }

                // Mark as read so it isn't processed again
                await gmail.users.messages.modify({
                    userId: 'me',
                    id: msg.id,
                    requestBody: { removeLabelIds: ['UNREAD'] }
                });
            }
        } catch (error) {
            console.error(`Failed to process emails for ${email}:`, error);
        }
    }
}

exports.nthuEmailParser = onSchedule({
    schedule: "every 1 minutes",
    secrets: [geminiApiKey, gmailCredentials]
}, async (event) => {
    await checkAndParseEmails();
});

exports.linkGmailAccount = onCall({
    secrets: [gmailCredentials]
}, async (request) => {
    const { serverAuthCode, accessToken, email, studentId, platform } = request.data;

    if (!email || !studentId) {
        throw new HttpsError('invalid-argument', 'Missing email or studentId.');
    }

    if (platform === 'web') {
        if (!accessToken) {
            throw new HttpsError('invalid-argument', 'Missing accessToken for web platform.');
        }

        try {
            await db.collection('ccxpUsers').doc(studentId).set({
                email: email,
                accessToken: accessToken,
                refreshToken: null,
                gmailLinkedAt: admin.firestore.FieldValue.serverTimestamp(),
                gmailLinkPlatform: 'web',
            }, { merge: true });

            return { success: true, message: "Gmail linked via web. Re-linking required after ~1 hour." };
        } catch (error) {
            console.error("Web token storage failed:", error);
            throw new HttpsError('internal', 'Failed to store web Gmail access.');
        }
    }

    if (!serverAuthCode) {
        throw new HttpsError('invalid-argument', 'Missing serverAuthCode for mobile platform.');
    }

    try {
        const oAuth2Client = await getOAuthClient();
        const { tokens } = await oAuth2Client.getToken(serverAuthCode);

        if (tokens.refresh_token) {
            await db.collection('ccxpUsers').doc(studentId).set({
                email: email,
                refreshToken: tokens.refresh_token,
                accessToken: null,
                gmailLinkedAt: admin.firestore.FieldValue.serverTimestamp(),
                gmailLinkPlatform: 'mobile',
            }, { merge: true });

            return { success: true, message: "Gmail successfully linked to CCXP profile!" };
        } else {
            return { success: false, error: "No refresh token received." };
        }

    } catch (error) {
        console.error("Token exchange failed:", error);
        throw new HttpsError('internal', 'Failed to securely link Gmail account.');
    }
});






//Only change code after this or the dependencies
// const app = express();
// app.use(cors());
// const PORT = 8080;
// app.use(express.json());
// app.listen(
//     PORT,
//     () => console.log(`http://localhost:${PORT}`)
// )

// app.post('/login',async (req,res) => {
//     const { uid } = req.body;
//     const { pw } = req.body;

//     const sessKey = await ccxpKeyGetter(uid,pw);
    
//     res.send({
//         sessKey: sessKey
//     });
// });

// app.post('/graduationData',async (req,res) => {
//     const { sessKey } = req.body;

//     const graduationData = await scrapTranscriptPage(sessKey);
//     console.log(graduationData);
//     res.json(graduationData);
// });

// app.post('/schedule',async (req,res) => {
//     const { sessKey } = req.body;

//     const schedule = await scrapCurrentCourse(sessKey);
//     res.json(schedule);
// });

