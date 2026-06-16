const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const functions = require('firebase-functions');

// Add this after the requires at the top of sync_semester_history.js
const getDb = () => admin.firestore();

const ROOT = process.cwd();


const semesterFiles = [
  { semester: '113-1', file: 'assets/data/113_1_course.json' },
  { semester: '113-2', file: 'assets/data/113_2_course.json' },
  { semester: '114-1', file: 'assets/data/114_1_course.json' },
  { semester: '115-1', file: 'assets/data/115_course.json' },
];

function normalizeText(value) {
  return (value || '')
    .toString()
    .trim()
    .toLowerCase()
    .replace(/[\s\u3000]+/g, ' ')
    .replace(/[()ï¼ˆï¼‰:ï¼š,ï¼Œ.ã€‚\-â€“â€”]/g, '')
    .replace(/â…°/g, 'i')
    .replace(/â…±/g, 'ii')
    .replace(/â…²/g, 'iii')
    .replace(/â…³/g, 'iv');
}

function compactCode(value) {
  return (value || '').toString().replace(/\s+/g, '').toUpperCase();
}

function safeDocId(value, fallback) {
  const raw = (value || fallback || '').toString().trim();
  const cleaned = raw
    .replace(/[\\/#?\[\]*]/g, '_')
    .replace(/\s+/g, '_')
    .slice(0, 140);
  return cleaned || fallback;
}

function pick(data, keys) {
  for (const key of keys) {
    const value = data?.[key];
    if (value === undefined || value === null) continue;
    const text = value.toString().trim();
    if (text && text.toLowerCase() !== 'null') return text;
  }
  return '';
}

function pickInt(data, keys) {
  for (const key of keys) {
    const value = data?.[key];
    if (value === undefined || value === null) continue;
    if (typeof value === 'number') return Math.round(value);
    const match = value.toString().match(/\d+/);
    if (match) return Number(match[0]);
  }
  return 0;
}

function extractCourses(json) {
  if (Array.isArray(json)) return json;
  for (const key of ['courses', 'courseList', 'data', 'results', 'items']) {
    if (Array.isArray(json?.[key])) return json[key];
  }
  if (json && typeof json === 'object') {
    const values = Object.values(json).filter((item) => item && typeof item === 'object');
    if (values.length > 0) return values;
  }
  return [];
}

function normalizeCatalogCourse(raw, semester, sourceFile, index) {
  const courseNo = pick(raw, [
    'courseNo', 'courseNumber', 'code', '科號', '課號', 'Course Number', 'Course No', 'course_code'
  ]);

  const titleEn = pick(raw, [
    'titleEn', 'courseEnglishName', 'courseNameEn', 'englishName', 'è‹±æ–‡èª²å', 'èª²ç¨‹è‹±æ–‡åç¨±', 'English Course Title'
  ]);

  const titleZh = pick(raw, [
    'titleZh', 'courseChineseName', 'courseNameZh', 'chineseName', 'ä¸­æ–‡èª²å', 'èª²ç¨‹ä¸­æ–‡åç¨±', 'Chinese Course Title'
  ]);

  const title = pick(raw, [
    'title', 'courseTitle', 'courseName', 'èª²ç¨‹åç¨±', 'name'
  ]) || titleEn || titleZh;

  const teacher = pick(raw, [
    'teacher', 'professor', 'instructor', '教師', '授課教師', 'Teacher', 'Instructor'
  ]);

  const slotCode = pick(raw, [
    'slotCode', 'timeSlot', 'time', 'æ™‚é–“', 'ä¸Šèª²æ™‚é–“', 'Class Time'
  ]);

  const rawTimeLocation = pick(raw, [
    'rawTimeLocation', 'classroomAndClassTime', 'classTime', '教室與上課時間', '教室上課時間'
  ]);

  const location = pick(raw, [
    'location', 'classroom', 'room', 'æ•™å®¤', 'Classroom'
  ]);

  const credits = pickInt(raw, [
    'credits', 'credit', '學分數', '學分', 'Credit'
  ]);

  const capacity = pickInt(raw, [
    'capacity', 'limit', 'enrollmentLimit', 'äººé™'
  ]);

  const departmentCode = pick(raw, [
    'departmentCode', 'department', 'deptCode', '代碼', '開課單位', 'Department'
  ]);

  const docId = safeDocId(courseNo || `${semester}_${title}`, `course_${index}`);

  return {
    ...raw,
    semester,
    sourceFile,
    courseNo,
    normalizedCourseNo: compactCode(courseNo),
    title,
    titleEn,
    titleZh,
    normalizedTitle: normalizeText(title || titleEn || titleZh),
    teacher,
    slotCode,
    rawTimeLocation,
    location,
    credits,
    capacity,
    departmentCode,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    __docId: docId,
  };
}

async function commitBatch(batch, count) {
  if (count === 0) return;
  await batch.commit();
}

async function importCatalogFile({ semester, file }) {
  const filePath = path.join(ROOT, file);
  if (!fs.existsSync(filePath)) {
    console.log(`SKIP ${semester}: missing ${file}`);
    return;
  }

  const json = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  const courses = extractCourses(json);
  const parentRef = getDb().collection('courseCatalogs').doc(semester);
  const coursesRef = parentRef.collection('courses');

  let batch = getDb().batch();
  let batchCount = 0;
  let total = 0;

  for (let i = 0; i < courses.length; i++) {
    const normalized = normalizeCatalogCourse(courses[i], semester, file, i);
    const docId = normalized.__docId;
    delete normalized.__docId;

    batch.set(coursesRef.doc(docId), normalized, { merge: true });
    batchCount += 1;
    total += 1;

    if (batchCount >= 450) {
      await commitBatch(batch, batchCount);
      batch = getDb().batch();
      batchCount = 0;
    }
  }

  await commitBatch(batch, batchCount);

  await parentRef.set({
    semester,
    sourceFile: file,
    courseCount: total,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  console.log(`IMPORTED ${semester}: ${total} courses from ${file}`);
}

function yearToSemester(year) {
  const text = (year || '').toString().trim();
  const match = text.match(/^(\d{3})(10|20)$/);
  if (!match) return '';
  return `${match[1]}-${match[2] === '10' ? '1' : '2'}`;
}

function courseTypeFromCategory(categoryTitle) {
  const title = (categoryTitle || '').toLowerCase();
  if (title.includes('compulsory')) return 'CORE';
  if (title.includes('general')) return 'GE';
  if (title.includes('pe') || title.includes('service')) return 'PE';
  if (title.includes('elective')) return 'ELECTIVE';
  return 'ELECTIVE';
}

async function findUserDoc(studentId) {
  const users = getDb().collection('ccxpUsers');
  const queries = [
    users.where('accountStudentId', '==', studentId).limit(1),
    users.where('studentId', '==', studentId).limit(1),
    users.where('studentInfo.studentId', '==', studentId).limit(1),
    users.where('graduationData.studentInfo.studentId', '==', studentId).limit(1),
  ];

  for (const query of queries) {
    const snap = await query.get();
    if (!snap.empty) return snap.docs[0];
  }

  const all = await users.get();
  const found = all.docs.find((doc) => {
    const d = doc.data();
    return d?.graduationData?.studentInfo?.studentId === studentId ||
      d?.accountStudentId === studentId ||
      d?.studentId === studentId;
  });

  if (found) return found;

  throw new Error(`No ccxpUsers document found for studentId ${studentId}`);
}

async function loadCatalogIndex(semester) {
  const snap = await getDb().collection('courseCatalogs').doc(semester).collection('courses').get();
  return snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
}

function recordCourseCodeCandidates(record) {
  const year = (record.year || '').toString().trim();
  const rawCode = (record.code || record.courseNo || record['科號'] || '').toString().trim();

  if (!rawCode) return [];

  const rawCompact = compactCode(rawCode);
  const candidates = new Set();

  if (rawCompact) candidates.add(rawCompact);

  if (year && rawCompact && !rawCompact.startsWith(year)) {
    candidates.add(compactCode(`${year}${rawCode}`));
  }

  return Array.from(candidates).filter(Boolean);
}

function fullRecordCourseNo(record) {
  const year = (record.year || '').toString().trim();
  const candidates = recordCourseCodeCandidates(record);

  if (!candidates.length) return '';

  const withYear = candidates.find((code) => year && code.startsWith(year));
  return withYear || candidates[0];
}

function catalogCourseCodeCandidates(course) {
  if (!course) return [];

  const rawValues = [
    course.courseNo,
    course.code,
    course['科號'],
    course.originalData?.['科號'],
    course.normalizedCourseNo,
    course.id,
  ].filter(Boolean);

  const candidates = new Set();

  for (const raw of rawValues) {
    const compact = compactCode(raw);
    if (!compact) continue;

    candidates.add(compact);

    // Some old catalog rows store code without semester prefix.
    // Some generated document ids store code with semester prefix.
    const noYear = compact.replace(/^\d{5}/, '');
    if (noYear) candidates.add(noYear);
  }

  return Array.from(candidates).filter(Boolean);
}

function catalogCourseNo(course) {
  if (!course) return '';
  return (
    course.courseNo ||
    course.code ||
    course['科號'] ||
    course.originalData?.['科號'] ||
    course.id ||
    ''
  ).toString();
}

function matchCatalogCourse(record, catalogCourses) {
  const recordCodes = recordCourseCodeCandidates(record);
  const recordTitle = normalizeText(record.title);
  const recordCredits = Number(record.credits || 0);

  // 1. Exact code match first.
  if (recordCodes.length > 0) {
    const codeMatches = catalogCourses.filter((course) => {
      const courseCodes = catalogCourseCodeCandidates(course);
      return courseCodes.some((courseCode) => recordCodes.includes(courseCode));
    });

    if (codeMatches.length > 0) return codeMatches[0];
  }

  // 2. Fallback: exact title match only.
  let matches = catalogCourses.filter((course) => {
    const titles = [
      course.title,
      course.titleEn,
      course.titleZh,
      course.courseName,
      course.courseTitle,
      course['英文課名'],
      course['中文課名'],
      course['課程英文名稱'],
      course['課程中文名稱'],
    ]
      .map(normalizeText)
      .filter(Boolean);

    return titles.includes(recordTitle);
  });

  if (matches.length > 1 && recordCredits > 0) {
    const creditMatches = matches.filter((course) => Number(course.credits || course['學分數'] || 0) === recordCredits);
    if (creditMatches.length > 0) matches = creditMatches;
  }

  return matches[0] || null;
}

function buildCategoryMap(graduationData) {
  const map = new Map();
  const categories = graduationData?.categories || [];

  for (const category of categories) {
    const categoryTitle = category.title || '';
    for (const record of category.records || []) {
      const key = `${normalizeText(record.title)}|${record.year || ''}`;
      map.set(key, categoryTitle);
    }
  }

  return map;
}

function matchScheduleData(record, scheduleData) {
  const recordCodes = recordCourseCodeCandidates(record);
  const title = normalizeText(record.title);
  const year = (record.year || '').toString();

  if (recordCodes.length > 0) {
    const exact = (scheduleData || []).find((item) => {
      const itemCode = compactCode(item.code || '');
      const itemCodeNoYear = itemCode.replace(/^\d{5}/, '');
      return recordCodes.includes(itemCode) || recordCodes.includes(itemCodeNoYear);
    });

    if (exact) return exact;
  }

  return (scheduleData || []).find((item) => {
    const itemCode = (item.code || '').toString();
    return itemCode.startsWith(year) && normalizeText(item.title) === title;
  }) || null;
}

async function buildSemesterCourses(studentId) {
  const userDoc = await findUserDoc(studentId);
  const userRef = userDoc.ref;
  const user = userDoc.data();
  const graduationData = user.graduationData || {};
  const allRecords = graduationData.allRecords || [];
  const scheduleData = user.scheduleData || [];
  const categoryMap = buildCategoryMap(graduationData);

  const catalogCache = new Map();
  const grouped = new Map();

  for (const record of allRecords) {
    const semester = yearToSemester(record.year);
    if (!semester) continue;

    if (!catalogCache.has(semester)) {
      catalogCache.set(semester, await loadCatalogIndex(semester));
    }

    const catalogCourse = matchCatalogCourse(record, catalogCache.get(semester));
    const scheduleCourse = matchScheduleData(record, scheduleData);
    const categoryKey = `${normalizeText(record.title)}|${record.year || ''}`;
    const categoryTitle = categoryMap.get(categoryKey) || '';

    const enriched = {
      year: record.year || '',
      semester,
      title: record.title || catalogCourse?.title || catalogCourse?.titleEn || catalogCourse?.titleZh || '',
      code: scheduleCourse?.code || fullRecordCourseNo(record) || catalogCourseNo(catalogCourse) || '',
      credits: Number(record.credits || catalogCourse?.credits || 0),
      grade: record.grade || '',
      status: record.status || '',
      courseType: courseTypeFromCategory(categoryTitle),
      categoryTitle,
      teacher: scheduleCourse?.teacher || catalogCourse?.teacher || catalogCourse?.['教師'] || catalogCourse?.['授課教師'] || '',
      room: scheduleCourse?.room || catalogCourse?.location || catalogCourse?.['教室'] || '',
      time: scheduleCourse?.time || catalogCourse?.slotCode || catalogCourse?.['上課時間'] || catalogCourse?.rawTimeLocation || catalogCourse?.['教室與上課時間'] || '',
      platform: scheduleCourse?.platform || '',
      url: scheduleCourse?.url || '',
      catalogDocId: catalogCourse?.id || '',
      matchedCatalog: Boolean(catalogCourse),
      hasTimetableData: Boolean((scheduleCourse?.time || catalogCourse?.slotCode || '').toString().trim()),
    };

    if (!grouped.has(semester)) grouped.set(semester, []);
    grouped.get(semester).push(enriched);
  }

  for (const [semester, courses] of grouped.entries()) {
    const totalCredits = courses
      .filter((course) => course.status !== 'failed')
      .reduce((sum, course) => sum + Number(course.credits || 0), 0);

    await userRef.collection('semesterCourses').doc(semester).set({
      semester,
      studentId,
      source: 'graduationData.allRecords + courseCatalogs',
      courseCount: courses.length,
      totalCredits,
      courses,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    const matched = courses.filter((course) => course.matchedCatalog).length;
    const withTime = courses.filter((course) => course.hasTimetableData).length;
    console.log(`WROTE ${semester}: ${courses.length} courses, matched catalog ${matched}, with time ${withTime}`);
  }
}

async function main() {
  console.log('Importing course catalogs...');
  for (const item of semesterFiles) {
    await importCatalogFile(item);
  }

  console.log(`Building semesterCourses for student ${STUDENT_ID}...`);
  await buildSemesterCourses(STUDENT_ID);

  console.log('DONE');
}

exports.syncUserOnLogin = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  const studentId = data.studentId; // passed from Flutter
  if (!studentId) {
    throw new functions.https.HttpsError('invalid-argument', 'studentId is required');
  }

  for (const item of semesterFiles) {
    await importCatalogFile(item);
  }

  await buildSemesterCourses(studentId);

  return { success: true };
});




module.exports = { buildSemesterCourses, importCatalogFile, semesterFiles };








