// \functions\tools\verify_schedule_tool.js
const admin = require("firebase-admin");

// Initialize Firebase Admin (ensure serviceAccountKey.json is accessible)
const serviceAccount = require("../serviceAccountKey.json");
if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
}
const db = admin.firestore();

async function verifySchedule(uid) {
    try {
        // Fetch the user's document
        const userDoc = await db.collection('ccxpUsers').doc(uid).get();
        if (!userDoc.exists) throw new Error("User not found");
        
        const userData = userDoc.data();
        const scheduleData = userData.scheduleData || [];

        if (scheduleData.length === 0) {
            console.log(JSON.stringify({ status: "empty", message: "No schedule data found for this user." }));
            return;
        }

        // We map the schedule data to send a clean, lightweight version to the LLM
        const cleanSchedule = scheduleData.map(course => ({
            code: course.code,
            title: course.title || "Unknown Title",
            day: course.day,
            startSlot: course.startSlot,
            duration: course.duration
        }));

        // Print output to stdout for OpenClaw to capture as an Observation
        console.log(JSON.stringify({ status: "success", schedule: cleanSchedule }));

    } catch (error) {
        console.log(JSON.stringify({ status: "error", message: error.message }));
    }
}

// OpenClaw will execute this file via CLI: `node verify_schedule_tool.js student_123`
const uidArg = process.argv[2];
if (!uidArg) {
    console.log(JSON.stringify({ status: "error", message: "Missing UID argument" }));
    process.exit(1);
}

verifySchedule(uidArg);