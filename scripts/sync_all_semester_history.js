const admin = require('firebase-admin');
const { execSync } = require('child_process');

const key = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(key),
});

const db = admin.firestore();

async function main() {
  const usersSnap = await db.collection('ccxpUsers').get();

  console.log(`FOUND ${usersSnap.size} ccxpUsers`);

  for (const doc of usersSnap.docs) {
    const data = doc.data();
    const studentId = data?.graduationData?.studentInfo?.studentId;

    if (!studentId) {
      console.log(`SKIP ${doc.id}: no studentId`);
      continue;
    }

    console.log(`\nSYNC ${studentId} (${doc.id})`);

    try {
      execSync(`node scripts\\sync_semester_history.js ${studentId}`, {
        stdio: 'inherit',
      });
    } catch (error) {
      console.error(`FAILED ${studentId}:`, error.message);
    }
  }

  console.log('\nDONE syncing all users');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
