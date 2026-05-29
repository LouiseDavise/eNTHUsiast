const fs = require("fs");
const path = require("path");

const { saveBulletinsToFirebase } = require("./bulletin_writer");

async function importBulletins() {
  const jsonPath = path.join(__dirname, "../bulletin.json");
  const jsonText = fs.readFileSync(jsonPath, "utf8");
  const bulletins = JSON.parse(jsonText);

  console.log(`Found ${bulletins.length} bulletin(s).`);

  await saveBulletinsToFirebase(bulletins);

  console.log("Done importing bulletins.");
}

importBulletins().catch((error) => {
  console.error("Import failed:", error);
});