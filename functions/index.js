const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { google } = require('googleapis');
const fs = require('fs').promises;
const path = require('path');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const { defineSecret } = require('firebase-functions/params');
// const {express} = require('express');
// const {cors} = require('cors');

// const { ccxpKeyGetter, transcribingLocalCaptcha } = require("./scrapper/key_getter.js");
// const { scrapTranscriptPage, scrapCurrentCourse } =require("./scrapper/ccxp_scrapper.js");
// const { parseGraduationData, parseSchedule } = require("./parser/parser.js");
// const { scrapEeclass } = require("./scrapper/eeclass_scrapper.js");

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

