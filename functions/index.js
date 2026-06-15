const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError, onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { google } = require('googleapis');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const path = require('path');
const { defineSecret } = require('firebase-functions/params');
const pdfParse = require("pdf-parse");

const openRouterApiKey = defineSecret('OPENROUTER_API_KEY_2');
const geminiApiKey = defineSecret('GEMINI_API_KEY');

const gmailCredentials = defineSecret('GMAIL_CREDENTIALS');
const openaiApiKey = defineSecret('OPENAI_API_KEY');
// const serviceAccount = require("./serviceAccountKey.json");

const express = require("express");
const cors = require("cors");

// Your custom modules
const { ccxpKeyGetter } = require("./scrapper/key_getter.js");
const { scrapTranscriptPage, scrapCurrentCourse} = require("./scrapper/ccxp_scrapper.js");
const {scrapEeclass} = require("./scrapper/eeclass_scrapper.js");
const { parseGraduationData, parseSchedule } = require("./parser/parser.js");



// admin.initializeApp();
admin.initializeApp({
    // credential: admin.credential.cert(serviceAccount)
});
const db = admin.firestore();

const ALLOWED_SENDERS = [
    'louizkwok2@gmail.com',
    'louizkwok@gmail.com',
    'no-reply@nthu.edu.tw',
];

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

async function callOpenRouter(prompt, { jsonMode = false, model = "openrouter/free" } = {}) {
    const body = {
        model: model,
        messages: [{ role: "user", content: prompt }],
    };

    if (jsonMode) {
        body.response_format = { type: "json_object" };
    }

    const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
        method: "POST",
        headers: {
            "Authorization": `Bearer ${openRouterApiKey.value()}`,
            "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
    });

    if (!response.ok) {
        const errText = await response.text();
        throw new Error(`OpenRouter request failed (${response.status}): ${errText}`);
    }

    const data = await response.json();
    const text = data.choices?.[0]?.message?.content;

    if (!text) {
        throw new Error("OpenRouter returned no content.");
    }

    return text;
}



async function callOpenAIChat({ systemPrompt, userContent, temperature = 0.05, maxTokens = 1000, model = "gpt-4.1-mini" }) {
    const response = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
            "Authorization": `Bearer ${openaiApiKey.value()}`,
            "Content-Type": "application/json",
        },
        body: JSON.stringify({
            model: model,
            messages: [
                { role: "system", content: systemPrompt || "" },
                { role: "user", content: userContent || "" },
            ],
            temperature: temperature,
            max_tokens: maxTokens,
        }),
    });

    if (!response.ok) {
        const errText = await response.text();
        throw new Error(`OpenAI request failed (${response.status}): ${errText}`);
    }

    const data = await response.json();
    const content = data.choices?.[0]?.message?.content;

    if (!content) {
        throw new Error("OpenAI returned no content.");
    }

    return content;
}

exports.baoBaoOpenAiChat = onCall(
    {
        region: "us-central1",
        memory: "512MiB",
        timeoutSeconds: 120,
        secrets: [openaiApiKey],
    },
    async (request) => {
        if (!request.auth) {
            throw new HttpsError("unauthenticated", "Please log in first.");
        }

        const systemPrompt = String(request.data.systemPrompt || "");
        const userContent = String(request.data.userContent || "");
        const temperature = Number(request.data.temperature ?? 0.05);
        const maxTokens = Math.min(Number(request.data.maxTokens ?? 1000), 2000);

        if (!systemPrompt.trim() || !userContent.trim()) {
            throw new HttpsError("invalid-argument", "Missing Bao-Bao prompt content.");
        }

        if (systemPrompt.length > 20000 || userContent.length > 120000) {
            throw new HttpsError("invalid-argument", "Bao-Bao prompt is too large.");
        }

        try {
            const content = await callOpenAIChat({
                systemPrompt: systemPrompt,
                userContent: userContent,
                temperature: temperature,
                maxTokens: maxTokens,
            });

            return {
                ok: true,
                content: content,
            };
        } catch (error) {
            console.error("Bao-Bao OpenAI callable failed:", error);
            throw new HttpsError(
                "internal",
                error.message || "Bao-Bao OpenAI request failed."
            );
        }
    }
);

async function authenticateGmail(refreshToken) {
    const credentials = JSON.parse(gmailCredentials.value());
    const { client_secret, client_id, redirect_uris } = credentials.installed || credentials.web;

    const oAuth2Client = new google.auth.OAuth2(
        client_id,
        client_secret,
        redirect_uris ? redirect_uris[0] : ""
    );

    oAuth2Client.setCredentials({ refresh_token: refreshToken });
    await oAuth2Client.getAccessToken();

    return google.gmail({ version: 'v1', auth: oAuth2Client });
}

async function authenticateGmailWithAccessToken(accessToken) {
    const credentials = JSON.parse(gmailCredentials.value());
    const { client_secret, client_id, redirect_uris } = credentials.installed || credentials.web;

    const oAuth2Client = new google.auth.OAuth2(
        client_id,
        client_secret,
        redirect_uris ? redirect_uris[0] : ""
    );

    oAuth2Client.setCredentials({ access_token: accessToken });

    return google.gmail({ version: 'v1', auth: oAuth2Client });
}

async function getOAuthClient() {
    const credentials = JSON.parse(gmailCredentials.value());
    const { client_secret, client_id } = credentials.installed || credentials.web;
    return new google.auth.OAuth2(client_id, client_secret, "");
}

async function saveToFirestore(collectionName, newData) {
    await db.collection(collectionName).add(newData);
}

async function clearCollection(collectionRef) {
    const snapshot = await collectionRef.get();
    if (snapshot.empty) return;
    const deletePromises = snapshot.docs.map(doc => doc.ref.delete());
    await Promise.all(deletePromises);
}

async function checkAndParseEmails() {
    const usersSnapshot = await db.collection('ccxpUsers').get();
    if (usersSnapshot.empty) {
        console.log("No CCXP users found in database.");
        return;
    }

    for (const userDoc of usersSnapshot.docs) {
        const uid = userDoc.id;
        const userData = userDoc.data();

        const email = userData.email;
        const refreshToken = userData.refreshToken;
        const accessToken = userData.accessToken;
        const platform = userData.gmailLinkPlatform;
        const studentId = userData.studentId || userData.accountStudentId || uid;

        if (!email || (!refreshToken && !accessToken)) {
            console.log(`Skipping user uid=${uid}: no Gmail credentials linked.`);
            continue;
        }

        const scheduleData = userData.scheduleData || [];
        const courseListText = scheduleData
            .filter(c => c && c.code && c.title)
            .map(c => `${c.code} - ${c.title}`)
            .join('\n');

        console.log(`Checking emails for uid: ${uid} (studentId: ${studentId}, email: ${email}), platform: ${platform}`);

        try {
            let gmail;
            if (refreshToken) {
                gmail = await authenticateGmail(refreshToken);
            } else {
                console.log(`Using web accessToken for ${studentId} (expires after ~1hr)`);
                gmail = await authenticateGmailWithAccessToken(accessToken);
            }

            const fromFilter = ALLOWED_SENDERS.map(e => `from:${e}`).join(' OR ');
            const query = `(${fromFilter}) is:unread`;
            const res = await gmail.users.messages.list({ userId: 'me', q: query });
            const messages = res.data.messages || [];

            if (messages.length === 0) {
                console.log(`No unread messages from allowed senders for user ${studentId}.`);
                continue;
            }

            console.log(`Found ${messages.length} unread message(s) for ${studentId}.`);

            for (const msg of messages) {
                const msgData = await gmail.users.messages.get({ userId: 'me', id: msg.id });
                const payload = msgData.data.payload;

                const headers = payload.headers || [];
                const subjectHeader = headers.find(h => h.name.toLowerCase() === 'subject');
                const subject = subjectHeader ? subjectHeader.value : '';

                const base64Data = findPlainTextPart(payload);

                if (!base64Data) {
                    console.warn(`No text/plain content found for message ${msg.id}. Skipping.`);
                    continue;
                }

                const cleanText = Buffer.from(base64Data, 'base64').toString('utf-8');
                const snippetText = msgData.data.snippet || '';

                console.log(`Processing message ${msg.id}, subject: "${subject}"`);
                console.log(`cleanText preview: ${cleanText.substring(0, 100)}`);

                const isBulletin = subject.includes("<NTHU Bulletin Board>") || cleanText.includes("<NTHU Bulletin Board>");

                if (isBulletin) {
                    console.log(`â†’ Identified as BULLETIN for ${studentId}`);
                    await clearCollection(db.collection('bulletins'));

                    let parts = cleanText.split("English Version");
                    let englishContent = parts.length > 1 ? parts[parts.length - 1].trim() : cleanText;

                    const footerMarker = "This message was sent automatically";
                    if (englishContent.includes(footerMarker)) {
                        englishContent = englishContent.split(footerMarker)[0].trim();
                    }

                    await saveToFirestore('bulletins', {
                        id: msg.id,
                        title: "Campus Announcements",
                        snippet: snippetText.split("English Version").pop().substring(0, 50).trim() + "...",
                        fullText: englishContent.replace(/\xa0\xa0/g, '\n\n'),
                        timestamp: admin.firestore.FieldValue.serverTimestamp()
                    });

                    console.log(`âœ“ Bulletin saved to Firestore.`);

                } else {
                    console.log(`â†’ Identified as UPCOMING TASK for ${studentId}, sending to OpenRouter...`);

                    const prompt = `You are an assistant for a university app. Read the following email
and extract the task details into a strict JSON format.

The student is currently enrolled in these courses (format: CODE - Course Name):
${courseListText || "(no course schedule available)"}

If the email relates to one of these courses, use the matching course's CODE for the "code" field
and incorporate the course name into the "title" if helpful. If the email does not match any
listed course, leave "code" as "" and determine the title from the email content alone.

The JSON must have exactly these keys try your best to fill it all:
- title: A short, clear name for the task
- code: The course code. If none, return 
- time: The time of the class or deadline. If none, return ""
- type: Must be one of: "Homework", "Midterm", "Final", "Quiz", "Project", or "Other"
- dueDate: The deadline format as YYYY-MM-DD. Try your best to find the dueDate
- summary: A concise 1-3 sentence summary of the email content, written for a student to quickly understand what is being asked

Email Text:
${cleanText}`;

                    try {
                        const responseText = await callOpenRouter(prompt, { jsonMode: true });
                        const aiData = JSON.parse(responseText);

                        let firestoreDueDate = null;
                        if (aiData.dueDate && aiData.dueDate !== "") {
                            firestoreDueDate = admin.firestore.Timestamp.fromDate(new Date(aiData.dueDate));
                        }

                        await db.collection('ccxpUsers').doc(uid).collection('upcoming').doc(msg.id).set({
                            title: aiData.title || "New Task",
                            code: aiData.code || "",
                            time: aiData.time || "",
                            type: aiData.type || "Other",
                            dueDate: firestoreDueDate,
                            summary: aiData.summary || "",
                            source: "email",
                            id: msg.id,
                            status: "Incomplete",
                            timestamp: admin.firestore.FieldValue.serverTimestamp()
                        });

                        console.log(`âœ“ Upcoming task "${aiData.title}" saved for ${studentId}.`);

                    } catch (e) {
                        console.error(`OpenRouter Parsing Error for message ${msg.id}:`, e);
                    }
                }
            }
        } catch (error) {
            console.error(`Failed to process emails for ${email}:`, error);
        }
    }
}

exports.nthuEmailParser = onSchedule({
    schedule: "every 30 minutes",
    secrets: [openRouterApiKey, gmailCredentials]
}, async (event) => {
    await checkAndParseEmails();
});

exports.linkGmailAccount = onCall({
    secrets: [gmailCredentials],
    memory: "512MiB",
    timeoutSeconds: 60,
}, async (request) => {
    const { serverAuthCode, accessToken, email, studentId, uid, platform } = request.data;

    if (!email || !uid) {
        throw new HttpsError('invalid-argument', 'Missing email or uid.');
    }

    if (platform === 'web') {
        if (!accessToken) {
            throw new HttpsError('invalid-argument', 'Missing accessToken for web platform.');
        }

        try {
            await db.collection('ccxpUsers').doc(uid).set({
                email: email,
                studentId: studentId || null,
                accessToken: accessToken,
                refreshToken: null,
                gmailLinkedAt: admin.firestore.FieldValue.serverTimestamp(),
                gmailLinkPlatform: 'web',
            }, { merge: true });

            return { success: true, message: "Gmail linked via web. Re-linking required after ~1 hour." };
        } catch (error) {
            console.error("Web token storage failed:", error);
            throw new HttpsError('internal', 'Failed to store web Gmail access.');
        }
    }

    if (!serverAuthCode) {
        throw new HttpsError('invalid-argument', 'Missing serverAuthCode for mobile platform.');
    }

    try {
        const oAuth2Client = await getOAuthClient();
        const { tokens } = await oAuth2Client.getToken(serverAuthCode);

        if (tokens.refresh_token) {
            await db.collection('ccxpUsers').doc(uid).set({
                email: email,
                studentId: studentId || null,
                refreshToken: tokens.refresh_token,
                accessToken: null,
                gmailLinkedAt: admin.firestore.FieldValue.serverTimestamp(),
                gmailLinkPlatform: 'mobile',
            }, { merge: true });

            return { success: true, message: "Gmail successfully linked to CCXP profile!" };
        } else {
            return { success: false, error: "No refresh token received." };
        }

    } catch (error) {
        console.error("Token exchange failed:", error);
        throw new HttpsError('internal', 'Failed to securely link Gmail account.');
    }
});

function extractCurriculumJsonObject(text) {
    const start = text.indexOf("{");
    const end = text.lastIndexOf("}");

    if (start === -1 || end === -1 || end <= start) {
        throw new Error("No JSON object found in Gemini response.");
    }

    return text.substring(start, end + 1);
}

function cleanCurriculumGeminiText(text) {
    return text
        .replace(/```json/g, "")
        .replace(/```/g, "")
        .trim();
}

exports.parseCurriculumPdfFromBytes = onCall(
    {
        region: "us-central1",
        memory: "1GiB",
        timeoutSeconds: 300,
        secrets: [geminiApiKey],
    },
    async (request) => {
        if (!request.auth) {
            throw new HttpsError(
                "unauthenticated",
                "You must be logged in before uploading curriculum."
            );
        }

        const uid = request.auth.uid;
        const fileName = request.data.fileName || "curriculum.pdf";
        const pdfBase64 = request.data.pdfBase64 || "";
        const studentIdFromClient = request.data.studentId || null;

        const ccxpUserDoc = await db.collection("ccxpUsers").doc(uid).get();
        const ccxpUser = ccxpUserDoc.data() || {};

        const studentId =
            ccxpUser.studentId ||
            ccxpUser.accountStudentId ||
            studentIdFromClient ||
            null;

        if (!studentId) {
            throw new HttpsError(
                "failed-precondition",
                "Cannot find student ID for this Firebase user."
            );
        }

        if (!fileName.toLowerCase().endsWith(".pdf")) {
            throw new HttpsError(
                "invalid-argument",
                "Only PDF files are supported."
            );
        }

        const curriculumRef = db
            .collection("ccxpUsers")
            .doc(uid)
            .collection("curriculum")
            .doc("current");

        try {
            await curriculumRef.set(
                {
                    accountStudentId: studentId,
                    studentId: studentId,
                    authUid: uid,
                    status: "processing",
                    fileName: fileName,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                },
                { merge: true }
            );

            const buffer = Buffer.from(pdfBase64, "base64");

            if (buffer.length === 0) {
                throw new Error("PDF file is empty.");
            }

            const maxPdfBytes = 8 * 1024 * 1024;

            if (buffer.length > maxPdfBytes) {
                throw new Error(
                    "PDF is too large. Please upload a smaller curriculum PDF."
                );
            }

            const parsedPdf = await pdfParse(buffer);
            const pdfText = parsedPdf.text || "";

            if (!pdfText.trim()) {
                throw new Error(
                    "PDF text is empty. This file may be scanned/image-only, so Bao-Bao cannot read it yet."
                );
            }

            const genAI = new GoogleGenerativeAI(geminiApiKey.value());
            const model = genAI.getGenerativeModel({
                model: "gemini-2.5-flash",
            });

            const prompt = `
You convert university curriculum PDF text into clean JSON.

Return JSON only. No markdown.

Schema:
{
  "programName": "",
  "department": "",
  "entryYear": "",
  "minimumGraduationCredits": 0,
  "requirementGroups": [
    {
      "category": "",
      "requiredCredits": 0,
      "description": "",
      "courses": [
        {
          "name": "",
          "credits": 0,
          "acceptedCodes": [],
          "type": "",
          "remarks": ""
        }
      ]
    }
  ],
  "notes": []
}

Rules:
- Keep course names exactly when possible.
- acceptedCodes should include course codes like MATH1040, CS1356, EECS2080.
- If one requirement allows multiple course codes, put all codes in acceptedCodes.
- If credits are not clear, use 0.
- Do not invent courses that are not in the text.
- Preserve categories such as GE, required courses, basic core, professional electives, labs, free electives, and graduation credits.
- If there are Chinese course names, preserve them.
- If the PDF has tables, extract the course names, credits, categories, and notes as accurately as possible.

PDF text:
${pdfText.slice(0, 45000)}
`;

            const result = await model.generateContent(prompt);
            const responseText = result.response.text();

            const cleanedText = cleanCurriculumGeminiText(responseText);
            const jsonText = extractCurriculumJsonObject(cleanedText);
            const curriculum = JSON.parse(jsonText);

            await curriculumRef.set(
                {
                    accountStudentId: studentId,
                    studentId: studentId,
                    authUid: uid,
                    status: "ready",
                    fileName: fileName,
                    curriculum: curriculum,
                    parsedTextPreview: pdfText.slice(0, 3000),
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                },
                { merge: true }
            );

            console.log("Curriculum parsed successfully", {
                uid: uid,
                fileName: fileName,
            });

            return {
                ok: true,
                message: "Curriculum parsed successfully.",
            };
        } catch (error) {
            console.error("Curriculum parsing failed:", error);

            await curriculumRef.set(
                {
                    accountStudentId: studentId,
                    studentId: studentId,
                    authUid: uid,
                    status: "error",
                    fileName: fileName,
                    errorMessage: error.message || String(error),
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                },
                { merge: true }
            );

            throw new HttpsError(
                "internal",
                error.message || "Curriculum parsing failed."
            );
        }
    }
);
function compactSemesterCode(value) {
    return (value || "").toString().toUpperCase().replace(/[^A-Z0-9]/g, "");
}

function normalizeSemesterTitle(value) {
    return (value || "").toString().trim().toLowerCase().replace(/\s+/g, " ");
}

function yearToSemesterDocId(yearValue) {
    const year = (yearValue || "").toString().trim();

    if (/^\d{3}-[12]$/.test(year)) return year;

    if (/^\d{5}$/.test(year)) {
        const academicYear = year.substring(0, 3);
        const termDigit = year.substring(3, 4);
        return `${academicYear}-${termDigit === "1" ? "1" : "2"}`;
    }

    return "";
}

function recordCodeCandidates(record) {
    const year = (record.year || "").toString().trim();
    const rawCode = (record.code || record.courseNo || record["ç§‘è™Ÿ"] || "").toString().trim();
    const rawCompact = compactSemesterCode(rawCode);
    const candidates = new Set();

    if (rawCompact) candidates.add(rawCompact);

    if (year && rawCompact && !rawCompact.startsWith(year)) {
        candidates.add(compactSemesterCode(`${year}${rawCode}`));
    }

    return Array.from(candidates).filter(Boolean);
}

function fullRecordCode(record) {
    const year = (record.year || "").toString().trim();
    const candidates = recordCodeCandidates(record);
    const withYear = candidates.find((code) => year && code.startsWith(year));
    return withYear || candidates[0] || "";
}

function catalogCodeCandidates(course) {
    if (!course) return [];

    const values = [
        course.courseNo,
        course.code,
        course["ç§‘è™Ÿ"],
        course.normalizedCourseNo,
        course.id,
    ].filter(Boolean);

    const candidates = new Set();

    for (const value of values) {
        const compact = compactSemesterCode(value);
        if (!compact) continue;

        candidates.add(compact);

        const noYear = compact.replace(/^\d{5}/, "");
        if (noYear) candidates.add(noYear);
    }

    return Array.from(candidates).filter(Boolean);
}

function catalogCourseNo(course) {
    if (!course) return "";
    return (
        course.courseNo ||
        course.code ||
        course["ç§‘è™Ÿ"] ||
        course.id ||
        ""
    ).toString();
}

function catalogTitles(course) {
    if (!course) return [];

    return [
        course.title,
        course.titleEn,
        course.titleZh,
        course.courseName,
        course.courseTitle,
        course["è‹±æ–‡èª²å"],
        course["ä¸­æ–‡èª²å"],
        course["èª²ç¨‹è‹±æ–‡åç¨±"],
        course["èª²ç¨‹ä¸­æ–‡åç¨±"],
    ]
        .map(normalizeSemesterTitle)
        .filter(Boolean);
}

function matchCatalogCourseForRecord(record, catalogCourses) {
    const recordCodes = recordCodeCandidates(record);
    const recordTitle = normalizeSemesterTitle(record.title);
    const recordCredits = Number(record.credits || 0);

    if (recordCodes.length > 0) {
        const codeMatches = catalogCourses.filter((course) => {
            const courseCodes = catalogCodeCandidates(course);
            return courseCodes.some((code) => recordCodes.includes(code));
        });

        if (codeMatches.length > 0) return codeMatches[0];
    }

    let titleMatches = catalogCourses.filter((course) => {
        return catalogTitles(course).includes(recordTitle);
    });

    if (titleMatches.length > 1 && recordCredits > 0) {
        const creditMatches = titleMatches.filter((course) => {
            return Number(course.credits || course["å­¸åˆ†æ•¸"] || course["å­¸åˆ†"] || 0) === recordCredits;
        });

        if (creditMatches.length > 0) titleMatches = creditMatches;
    }

    return titleMatches[0] || null;
}

function buildCategoryLookup(graduationData) {
    const lookup = new Map();
    const categories = graduationData.categories || [];

    for (const category of categories) {
        const title = category.title || "";
        const records = category.records || [];

        for (const record of records) {
            const key = `${record.year || ""}|${normalizeSemesterTitle(record.title)}`;
            lookup.set(key, title);
        }
    }

    return lookup;
}

exports.syncSemesterHistoryForUser = onCall(
    {
        region: "us-central1",
        memory: "512MiB",
        timeoutSeconds: 180,
    },
    async (request) => {
        if (!request.auth) {
            throw new HttpsError(
                "unauthenticated",
                "You must be logged in before syncing semester history."
            );
        }

        const uid = request.auth.uid;
        const userRef = db.collection("ccxpUsers").doc(uid);
        const userSnap = await userRef.get();

        if (!userSnap.exists) {
            throw new HttpsError("not-found", "ccxpUsers profile not found.");
        }

        const userData = userSnap.data() || {};
        const graduationData = userData.graduationData || {};
        const allRecords = graduationData.allRecords || [];

        if (!Array.isArray(allRecords) || allRecords.length === 0) {
            throw new HttpsError(
                "failed-precondition",
                "No graduationData.allRecords found for this user."
            );
        }

        const categoryLookup = buildCategoryLookup(graduationData);
        const grouped = {};

        for (const record of allRecords) {
            const semester = yearToSemesterDocId(record.year);
            if (!semester) continue;

            if (!grouped[semester]) grouped[semester] = [];
            grouped[semester].push(record);
        }

        const result = {};

        for (const [semester, records] of Object.entries(grouped)) {
            const catalogSnap = await db
                .collection("courseCatalogs")
                .doc(semester)
                .collection("courses")
                .get();

            const catalogCourses = catalogSnap.docs.map((doc) => ({
                id: doc.id,
                ...doc.data(),
            }));

            const courses = records.map((record) => {
                const catalogCourse = matchCatalogCourseForRecord(record, catalogCourses);
                const categoryKey = `${record.year || ""}|${normalizeSemesterTitle(record.title)}`;
                const categoryTitle = categoryLookup.get(categoryKey) || "";

                const time =
                    catalogCourse?.slotCode ||
                    catalogCourse?.["ä¸Šèª²æ™‚é–“"] ||
                    catalogCourse?.rawTimeLocation ||
                    "";

                const room =
                    catalogCourse?.location ||
                    catalogCourse?.room ||
                    catalogCourse?.["æ•™å®¤"] ||
                    "";

                const teacher =
                    catalogCourse?.teacher ||
                    catalogCourse?.["æ•™å¸«"] ||
                    catalogCourse?.["æŽˆèª²æ•™å¸«"] ||
                    "";

                return {
                    year: record.year || "",
                    semester,
                    title:
                        record.title ||
                        catalogCourse?.title ||
                        catalogCourse?.titleEn ||
                        catalogCourse?.["è‹±æ–‡èª²å"] ||
                        "",
                    code: catalogCourseNo(catalogCourse) || fullRecordCode(record),
                    credits: Number(record.credits || 0),
                    grade: record.grade || "",
                    status: record.status || "",
                    courseType: categoryTitle.toUpperCase().includes("COMPULSORY")
                        ? "CORE"
                        : categoryTitle.toUpperCase().includes("GENERAL")
                            ? "GE"
                            : categoryTitle.toUpperCase().includes("PE")
                                ? "PE"
                                : "ELECTIVE",
                    categoryTitle,
                    teacher,
                    room,
                    time,
                    platform: "",
                    url: "",
                    catalogDocId: catalogCourse?.id || "",
                    matchedCatalog: Boolean(catalogCourse),
                    hasTimetableData: Boolean(time),
                };
            });

            await userRef.collection("semesterCourses").doc(semester).set(
                {
                    semester,
                    courses,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                },
                { merge: true }
            );

            result[semester] = {
                courses: courses.length,
                withTime: courses.filter((course) => course.time).length,
            };
        }

        return {
            ok: true,
            uid,
            result,
        };
    }
);





//

const app = express();

// Enable CORS for all incoming requests
app.use(cors({ origin: true }));
app.use(express.json());

// --- ENDPOINTS ---

app.post('/login', async (req, res) => {
    try {
        const { uid, pw } = req.body;
        const sessKey = await ccxpKeyGetter(uid, pw);
        res.send({ sessKey: sessKey });
    } catch (error) {
        console.error("Login Error:", error);
        res.status(500).send({ error: error.message });
    }
});

app.post('/graduationData', async (req, res) => {
    try {
        const { sessKey } = req.body;
        const graduationData = await scrapTranscriptPage(sessKey);
        res.json(graduationData);
    } catch (error) {
        console.error("Graduation Data Error:", error);
        res.status(500).send({ error: error.message });
    }
});

app.post('/schedule', async (req, res) => {
    try {
        const { sessKey } = req.body;
        const schedule = await scrapCurrentCourse(sessKey);
        const courses = await scrapEeclass(sessKey,schedule);
        res.json(courses);
    } catch (error) {
        console.error("Schedule Error:", error);
        res.status(500).send({ error: error.message });
    }
});

// --- FIREBASE EXPORT ---
// Wrapping the Express app in Firebase's HTTPS trigger.
// Adjusted memory and timeout to handle the heavy load of a web scraper.
exports.api = onRequest({
    memory: "2GiB",
    timeoutSeconds: 300,
    secrets: [openaiApiKey],
}, app);
