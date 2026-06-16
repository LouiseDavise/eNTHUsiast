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

// ── DEBUG HELPER ─────────────────────────────────────────────────────────
// Semua log debug dikirim ke stderr (console.error), BUKAN stdout.
// Ini penting: agent_server.js membaca stdout via execSync sebagai Observation,
// jadi kalau debug log masuk ke stdout, itu akan merusak parsing JSON di LLM.
// stderr aman karena tidak ditangkap oleh execSync().toString().
function debugLog(label, value) {
    console.error(`[GMAIL_TOOL_DEBUG] ${label}:`, value);
}

async function fetchGmail(uid) {
    try {
        // ── DEBUG STEP 0: Konfirmasi project & UID yang diterima ──────────
        debugLog("Project ID dari serviceAccountKey.json", serviceAccount.project_id);
        debugLog("UID diterima (raw)", JSON.stringify(uid));
        debugLog("Tipe data UID", typeof uid);
        debugLog("Panjang UID", uid.length);
        // UID Firebase Auth standar = 28 karakter alfanumerik, tanpa spasi
        debugLog("Mengandung whitespace tersembunyi?", /\s/.test(uid));

        // 1. Get user credentials from Firestore
        const userRef = db.collection('ccxpUsers').doc(uid);
        debugLog("Path Firestore yang diquery", userRef.path);

        const userDoc = await userRef.get();
        debugLog("Dokumen ditemukan?", userDoc.exists);

        if (!userDoc.exists) {
            // ── DEBUG STEP 1: Dokumen tidak ada — tampilkan UID apa saja yang BENAR ada ──
            debugLog("Dokumen tidak ditemukan. Mengambil daftar UID yang benar-benar ada di 'ccxpUsers'...", "");

            const allUsersSnapshot = await db.collection('ccxpUsers').limit(20).get();

            if (allUsersSnapshot.empty) {
                debugLog("PERINGATAN", "Collection 'ccxpUsers' KOSONG TOTAL. Tidak ada satu dokumen pun.");
            } else {
                const existingUids = allUsersSnapshot.docs.map(d => d.id);
                debugLog("UID yang TERSEDIA di Firestore (root ccxpUsers)", existingUids);

                // Cek kecocokan case-insensitive untuk mendeteksi typo huruf besar/kecil
                const caseInsensitiveMatch = existingUids.find(
                    existingUid => existingUid.toLowerCase() === uid.toLowerCase()
                );
                if (caseInsensitiveMatch) {
                    debugLog("KEMUNGKINAN BUG DITEMUKAN", `UID yang dicari berbeda HURUF BESAR/KECIL dari yang ada: "${caseInsensitiveMatch}" vs "${uid}"`);
                }
            }

            throw new Error("User not found");
        }

        const userData = userDoc.data();
        debugLog("Field yang tersedia di dokumen", Object.keys(userData));

        // Check for accessToken (from Web) or refreshToken (from Mobile)
        if (!userData.accessToken && !userData.refreshToken) {
            debugLog("PERINGATAN", "Dokumen pengguna ADA, tapi tidak ada field 'accessToken' maupun 'refreshToken'.");
            throw new Error("No Gmail access token found for user in Firestore");
        }

        debugLog("Punya accessToken?", !!userData.accessToken);
        debugLog("Punya refreshToken?", !!userData.refreshToken);

        // 2. Set up OAuth2 Client
        const oauth2Client = new google.auth.OAuth2();

        // Pass the token exactly how the Google API library expects it
        if (userData.accessToken) {
            oauth2Client.setCredentials({ access_token: userData.accessToken });
        } else if (userData.refreshToken) {
            oauth2Client.setCredentials({ refresh_token: userData.refreshToken });
        }

        const gmail = google.gmail({ version: 'v1', auth: oauth2Client });

        // 3. Fetch Unread Emails from Allowed Senders (using your friend's exact logic)
        const ALLOWED_SENDERS = ['louizkwok2@gmail.com', 'louizkwok@gmail.com', 'chang.amartyananda14@gmail.com', 'no-reply@nthu.edu.tw'];
        const query = `is:unread (${ALLOWED_SENDERS.map(sender => `from:${sender}`).join(' OR ')})`;
        debugLog("Gmail query string", query);

        const res = await gmail.users.messages.list({ userId: 'me', q: query });
        const messages = res.data.messages || [];
        debugLog("Jumlah email ditemukan", messages.length);

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
            await gmail.users.messages.modify({ userId: 'me', id: msg.id, requestBody: { removeLabelIds: ['UNREAD'] }});
        }

        // 4. Print output to stdout for OpenClaw to capture as an Observation
        console.log(JSON.stringify({ status: "success", data: extractedEmails }));

    } catch (error) {
        // ── DEBUG STEP 2: Tangkap detail error API Google secara lebih dalam ──
        // Error dari googleapis sering menyimpan detail asli di error.response.data
        if (error.response && error.response.data) {
            debugLog("Detail error mentah dari Google API", JSON.stringify(error.response.data));
        }
        if (error.code) {
            debugLog("Kode error", error.code);
        }

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