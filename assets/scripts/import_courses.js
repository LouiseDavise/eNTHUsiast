const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

const serviceAccount = require("../../serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

function safeDocId(courseNo) {
  return String(courseNo)
    .trim()
    .replace(/\s+/g, "_")
    .replace(/[^a-zA-Z0-9_-]/g, "_");
}

function getDepartmentCode(courseNo) {
  const text = String(courseNo || "").trim();

  // Example: "11420AES 470100" -> "AES"
  const match = text.match(/11420([A-Z]+)/);

  if (match) {
    return match[1];
  }

  return "";
}

function parseTimeLocation(raw) {
  if (!raw) {
    return {
      location: "",
      slotCode: "",
    };
  }

  const text = String(raw).trim();

  // Example:
  // "BMES醫環717 R7R8R9"
  // location = "BMES醫環717"
  // slotCode = "R7R8R9"
  const parts = text.split(/\s+/);

  if (parts.length === 1) {
    return {
      location: parts[0],
      slotCode: "",
    };
  }

  return {
    location: parts.slice(0, -1).join(" "),
    slotCode: parts[parts.length - 1],
  };
}

function mapCourse(raw) {
  const courseNo = raw["科號"] ?? "";
  const timeLocation = parseTimeLocation(raw["教室與上課時間"]);

  return {
    courseNo: courseNo,
    titleZh: raw["課程中文名稱"] ?? "",
    titleEn: raw["課程英文名稱"] ?? "",
    credits: Number(raw["學分數"] ?? 0),
    capacity: raw["人限"] === null ? null : Number(raw["人限"]),
    reservedFreshman: Number(raw["新生保留人數"] ?? 0),
    geTarget: raw["通識對象"] ?? null,
    geCategory: raw["通識類別"] ?? null,
    language: raw["授課語言"] ?? "",
    note: raw["備註"] ?? null,
    cancelled: raw["停開註記"] ?? null,
    rawTimeLocation: raw["教室與上課時間"] ?? null,
    location: timeLocation.location,
    slotCode: timeLocation.slotCode,
    teacher: raw["授課教師"] ?? "",
    prerequisiteNote: raw["擋修說明"] ?? null,
    restrictionNote: raw["課程限制說明"] ?? null,
    majorMapping: raw["第一二專長對應"] ?? null,
    programMapping: raw["學分學程對應"] ?? null,
    noExtraSelectionNote: raw["不可加簽說明"] ?? null,
    requiredElectiveNote: raw["必選修說明"] ?? null,
    departmentCode: getDepartmentCode(courseNo),
    originalData: raw,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

async function importCourses() {
  const jsonPath = path.join(__dirname, "../course_data.json");
  const jsonText = fs.readFileSync(jsonPath, "utf8");
  const courses = JSON.parse(jsonText);

  console.log(`Found ${courses.length} courses.`);

  let count = 0;
  let skipped = 0;

  for (const rawCourse of courses) {
    const courseNo = rawCourse["科號"];

    if (!courseNo) {
      skipped++;
      console.log("Skipped course without 科號:", rawCourse);
      continue;
    }

    const docId = safeDocId(courseNo);
    const ref = db.collection("courses").doc(docId);

    try {
      await ref.set(mapCourse(rawCourse), { merge: true });
      count++;

      if (count % 100 === 0) {
        console.log(`Uploaded ${count} courses...`);
      }
    } catch (error) {
      console.error("Failed at course:");
      console.error("courseNo:", courseNo);
      console.error("docId:", docId);
      console.error("titleZh:", rawCourse["課程中文名稱"]);
      console.error("titleEn:", rawCourse["課程英文名稱"]);
      console.error("rawTimeLocation:", rawCourse["教室與上課時間"]);
      console.error("error:", error);

      throw error;
    }
  }

  console.log(`Done. Uploaded ${count} courses. Skipped ${skipped}.`);
}

importCourses().catch((error) => {
  console.error("Import failed:", error);
});