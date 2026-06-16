// functions/tools/debug_check_user.js
// Jalankan: node tools/debug_check_user.js <uid>
// Skrip debug untuk memeriksa apakah dokumen pengguna benar-benar ada di Firestore
// dan project mana yang sedang digunakan oleh service account.

const admin = require("firebase-admin");
const path  = require('path');

const serviceAccount = require(path.join(__dirname, "..", "serviceAccountKey.json"));

if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
}
const db = admin.firestore();

async function debugCheck(uid) {
    console.log("──────────────────────────────────────────────");
    console.log("Project ID dari serviceAccountKey.json:", serviceAccount.project_id);
    console.log("UID yang diperiksa:                     ", JSON.stringify(uid)); // JSON.stringify reveals hidden whitespace
    console.log("Panjang UID:                             ", uid.length, "(UID Firebase normal = 28 karakter)");
    console.log("──────────────────────────────────────────────");

    try {
        // 1. Cek apakah dokumen ccxpUsers/{uid} ada
        const userDoc = await db.collection('ccxpUsers').doc(uid).get();
        console.log("ccxpUsers/" + uid + " ada?  →", userDoc.exists);

        if (userDoc.exists) {
            const data = userDoc.data();
            console.log("Field yang tersedia:", Object.keys(data));
            console.log("Punya accessToken?  →", !!data.accessToken);
            console.log("Punya refreshToken? →", !!data.refreshToken);
        }

        // 2. List semua dokumen di ccxpUsers untuk melihat UID mana yang benar-benar ada
        console.log("──────────────────────────────────────────────");
        console.log("Semua dokumen UID yang ada di collection 'ccxpUsers':");
        const allUsers = await db.collection('ccxpUsers').limit(20).get();
        if (allUsers.empty) {
            console.log("  (Collection ccxpUsers KOSONG! Tidak ada dokumen sama sekali.)");
        } else {
            allUsers.forEach(doc => {
                console.log("  -", doc.id, doc.id === uid ? "  ← COCOK dengan UID yang dicari" : "");
            });
        }

    } catch (error) {
        console.error("Error saat memeriksa Firestore:", error.message);
    }
}

const uidArg = process.argv[2];
if (!uidArg) {
    console.log("Penggunaan: node debug_check_user.js <uid>");
    process.exit(1);
}

debugCheck(uidArg);