// \functions\tools\fetch_existing_tasks_tool.js
const admin = require("firebase-admin");
const path = require('path');

// Initialize Firebase Admin
const serviceAccount = require(path.join(__dirname, "..", "serviceAccountKey.json"));
if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
}
const db = admin.firestore();

async function fetchExistingTasks(uid) {
    try {
        // Query the upcoming collection for this user
        const snapshot = await db.collection('ccxpUsers').doc(uid).collection('upcoming').get();
        
        if (snapshot.empty) {
            console.log(JSON.stringify({ status: "empty", message: "No existing tasks found." }));
            return;
        }

        const existingTasks = [];
        snapshot.forEach(doc => {
            const data = doc.data();
            // We only need the title and code for the LLM to understand what it is
            if (data.title) {
                existingTasks.push({
                    title: data.title,
                    courseCode: data.code || "Unknown"
                });
            }
        });

        // Print output to stdout for OpenClaw to capture
        console.log(JSON.stringify({ status: "success", existingTasks: existingTasks }));

    } catch (error) {
        console.log(JSON.stringify({ status: "error", message: error.message }));
    }
}

// OpenClaw will execute this via CLI
const uidArg = process.argv[2];
if (!uidArg) {
    console.log(JSON.stringify({ status: "error", message: "Missing UID argument" }));
    process.exit(1);
}

fetchExistingTasks(uidArg);