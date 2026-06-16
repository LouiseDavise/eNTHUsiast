// \functions\tools\fetch_history_tool.js
const admin = require("firebase-admin");

// Initialize Firebase Admin (ensure serviceAccountKey.json is accessible)
const serviceAccount = require("../serviceAccountKey.json");
if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
}
const db = admin.firestore();

async function fetchHistory(uid) {
    try {
        // Fetch the user's document
        const userDoc = await db.collection('ccxpUsers').doc(uid).get();
        if (!userDoc.exists) throw new Error("User not found");
        
        const userData = userDoc.data();
        const graduationData = userData.graduationData || {};
        const allRecords = graduationData.allRecords || [];

        if (allRecords.length === 0) {
            console.log(JSON.stringify({ status: "empty", message: "No past academic history found." }));
            return;
        }

        // We filter out "inProgress" courses because we only care about past performance (Pass/Fail)
        const pastCourses = allRecords
            .filter(record => record.status !== "inProgress")
            .map(record => ({
                title: record.title || "Unknown",
                code: record.code,
                status: record.status, // e.g., "Failed", "Passed", "Withdrawn"
                grade: record.grade || "N/A"
            }));

        // Print output to stdout for OpenClaw to capture
        console.log(JSON.stringify({ status: "success", history: pastCourses }));

    } catch (error) {
        console.log(JSON.stringify({ status: "error", message: error.message }));
    }
}

const uidArg = process.argv[2];
if (!uidArg) {
    console.log(JSON.stringify({ status: "error", message: "Missing UID argument" }));
    process.exit(1);
}

fetchHistory(uidArg);