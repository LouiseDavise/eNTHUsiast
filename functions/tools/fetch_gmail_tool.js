const { google } = require('googleapis');
const path = require('path');
const admin = require("firebase-admin");

// Initialize standard local Firebase Admin (ensure serviceAccountKey.json is accessible)
const serviceAccount = require(path.join(__dirname, "..", "serviceAccountKey.json"));
if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
}
const db = admin.firestore();

// Helper: Extract plain text from Gmail payload
function findPlainTextPart(payload) {
    if (payload.mimeType === 'text/plain' && payload.body && payload.body.data) {
        return payload.body.data;
    }
    if (payload.parts && payload.parts.length > 0) {
        for (const part of payload.parts) {
            const found = findPlainTextPart(part);
            if (found) return found;
        }
    }
    return null;
}

async function fetchGmail(uid) {
    try {
        // 1. Get user credentials from Firestore (using your friend's structure)
        const userDoc = await db.collection('ccxpUsers').doc(uid).get();
        if (!userDoc.exists) throw new Error("User not found");
        
        const userData = userDoc.data();
        if (!userData.gmailTokens) throw new Error("No Gmail tokens found for user");

        // 2. Set up OAuth2 Client
        const oauth2Client = new google.auth.OAuth2();
        oauth2Client.setCredentials(userData.gmailTokens);
        const gmail = google.gmail({ version: 'v1', auth: oauth2Client });

        // 3. Fetch Unread Emails from Allowed Senders (using your friend's exact logic)
        const ALLOWED_SENDERS = ['louizkwok2@gmail.com', 'louizkwok@gmail.com', 'no-reply@nthu.edu.tw'];
        const query = `is:unread (${ALLOWED_SENDERS.map(sender => `from:${sender}`).join(' OR ')})`;
        
        const res = await gmail.users.messages.list({ userId: 'me', q: query });
        const messages = res.data.messages || [];

        let extractedEmails = [];

        for (const msg of messages) {
            const msgData = await gmail.users.messages.get({ userId: 'me', id: msg.id });
            const payload = msgData.data.payload;
            const headers = payload.headers;
            
            const subject = headers.find(h => h.name === 'Subject')?.value || 'No Subject';
            const from = headers.find(h => h.name === 'From')?.value || 'Unknown Sender';
            const date = headers.find(h => h.name === 'Date')?.value || 'Unknown Date';
            
            const base64Body = findPlainTextPart(payload);
            let cleanText = "";
            if (base64Body) {
                const buffer = Buffer.from(base64Body, 'base64');
                cleanText = buffer.toString('utf-8').replace(/\s+/g, ' ').trim();
            }

            extractedEmails.push({ subject, from, date, text: cleanText });

            // Optional: Mark as read
            // await gmail.users.messages.modify({ userId: 'me', id: msg.id, requestBody: { removeLabelIds: ['UNREAD'] }});
        }

        // 4. Print output to stdout for OpenClaw to capture as an Observation
        console.log(JSON.stringify({ status: "success", data: extractedEmails }));

    } catch (error) {
        // Print error to stdout so the LLM knows the tool failed and can reason about it
        console.log(JSON.stringify({ status: "error", message: error.message }));
    }
}

// OpenClaw will execute this file via CLI like: `node fetch_gmail_tool.js student_123`
const uidArg = process.argv[2];
if (!uidArg) {
    console.log(JSON.stringify({ status: "error", message: "Missing UID argument" }));
    process.exit(1);
}

fetchGmail(uidArg);