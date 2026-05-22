const { onSchedule } = require("firebase-functions/v2/scheduler");
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

// 3. Configuration
const CREDENTIALS_PATH = path.join(__dirname, 'credentials.json');
const TOKEN_PATH = path.join(__dirname, 'token.json');
const TARGET_EMAIL = 'louizkwok2@gmail.com';

async function authenticateGmail() {
    const credsFile = await fs.readFile(CREDENTIALS_PATH, 'utf-8');
    const credentials = JSON.parse(credsFile);
    const { client_secret, client_id, redirect_uris } = credentials.installed || credentials.web;
    const oAuth2Client = new google.auth.OAuth2(client_id, client_secret, redirect_uris[0]);

    const tokenFile = await fs.readFile(TOKEN_PATH, 'utf-8');
    const token = JSON.parse(tokenFile);
    oAuth2Client.setCredentials(token);
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

async function checkAndParseEmails() {
    // INITIALIZE GEMINI INSIDE THE FUNCTION AT RUNTIME
    const genAI = new GoogleGenerativeAI(geminiApiKey.value()); 
    const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

    const gmail = await authenticateGmail();
    const query = `from:${TARGET_EMAIL} is:unread`;
    const res = await gmail.users.messages.list({ userId: 'me', q: query });
    const messages = res.data.messages || [];

    if (messages.length === 0) return;

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
                await saveToFirestore('tasks', {
                    ...aiData,
                    id: msg.id,
                    status: "Incomplete",
                    timestamp: admin.firestore.FieldValue.serverTimestamp()
                });
            } catch (e) { console.error(e); }
        }

        await gmail.users.messages.modify({ userId: 'me', id: msg.id, requestBody: { removeLabelIds: ['UNREAD'] } });
    }
}

exports.nthuEmailParser = onSchedule({
    schedule: "every 30 minutes",
    secrets: [geminiApiKey]
}, async (event) => {
    await checkAndParseEmails();
});