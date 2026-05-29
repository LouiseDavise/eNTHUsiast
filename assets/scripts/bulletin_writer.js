const admin = require("firebase-admin");
const path = require("path");

const serviceAccount = require("../../serviceAccountKey.json");

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();

function safeDocId(value) {
  return String(value)
    .trim()
    .replace(/\s+/g, "_")
    .replace(/[^a-zA-Z0-9_-]/g, "_");
}

function mapBulletin(raw) {
  return {
    id: raw.id ?? "",
    sender: raw.sender ?? "",
    title: raw.title ?? "",
    snippet: raw.snippet ?? "",
    fullText: raw.fullText ?? "",
    source: "email",
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

async function saveBulletinsToFirebase(bulletins) {
  if (!Array.isArray(bulletins)) {
    throw new Error("saveBulletinsToFirebase expects an array.");
  }

  let count = 0;

  for (const bulletin of bulletins) {
    const rawId = bulletin.id || `${bulletin.sender}_${bulletin.title}`;
    const docId = safeDocId(rawId);

    const ref = db.collection("bulletins").doc(docId);

    await ref.set(mapBulletin(bulletin), { merge: true });

    count++;
  }

  console.log(`Saved ${count} bulletin(s) to Firestore.`);
}

module.exports = {
  saveBulletinsToFirebase,
};