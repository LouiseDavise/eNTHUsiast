const cheerio = require('cheerio');
const fs = require('fs');
const path = require('path');

const styleMap = {
    'CS':    { bg: '0xFFECFDF5', border: '0xFFA7F3D0', text: '0xFF065F46' },
    'EECS':  { bg: '0xFFF5F3FF', border: '0xFFDDD6FE', text: '0xFF6D28D9' },
    'PHYS':  { bg: '0xFFFFF1F2', border: '0xFFFECACA', text: '0xFFB91C1C' },
    'MATH':  { bg: '0xFFFAF5FF', border: '0xFFE9D5FF', text: '0xFF7C3AED' },
    'CLC':   { bg: '0xFFFFF7ED', border: '0xFFFED7AA', text: '0xFFC2410C' },
    'PE':    { bg: '0xFFF8FAFC', border: '0xFFCBD5E1', text: '0xFF475569' },
};

function parseGraduationData(htmlContent) {
    // Handle both array and string inputs
    let html = htmlContent;
    if (Array.isArray(htmlContent)) {
        // Join array of HTML strings into a single valid HTML table
        html = '<table>' + htmlContent.join('\n') + '</table>';
    }
    
    const $ = cheerio.load(html);
    const rows = $('tr');
    
    const categories = {
        "Compulsory": { required: 30, courses: [] },
        "General Education": { required: 28, courses: [] },
        "Electives": { required: 40, courses: [] },
        "PE & Service": { required: 0, courses: [] }
    };
    const allRecords = [];

    let totalGradePoints = 0.0;
    let totalGpaCredits = 0;
    let studentInfo;

    rows.each((index, rowElement) => {
        const tds = $(rowElement).find('td');
        if(tds.hasClass("input_red")) {
            const studentData = $(tds[0]).text().trim();
            let arr = studentData.split(/\s+/);
            const studentId = arr[2].substring(7);
            const studentName = arr[4].substring(5);
            const studentDepartment = arr[8].substring(6);
            studentInfo = {
                "studentId" : studentId,
                "studentName" : studentName,
                "studentDepartment" : studentDepartment
            };
            return;
        }

        if(tds.length == 9) {
            const yearStr = $(tds[0]).text().trim() + $(tds[1]).text().trim();      
        }
        
        if (tds.length === 0) return; 

        // --- 1. PARSE SUMMARY ROWS (For Cumulative GPA) ---
        if (tds.length >= 16) {
            const gpaStr = $(tds[2]).text().trim();
            const creditsStr = $(tds[6]).text().trim(); 
            if (gpaStr && gpaStr !== '**' && /^\d+$/.test(creditsStr)) {
                const gpa = parseFloat(gpaStr);
                const creds = parseInt(creditsStr, 10);
                if (!isNaN(gpa) && !isNaN(creds)) {
                    totalGradePoints += gpa * creds;
                    totalGpaCredits += creds;
                }
            }
            return; 
        }

        // --- 2. PARSE COURSE ROWS ---
        if (tds.length < 6) return;
        
        const rawCredits = $(tds[4]).text().trim();
        const parsedCredits = parseInt(parseFloat(rawCredits ? rawCredits : '0'), 10);
        
        if (isNaN(parsedCredits)) {
            return; 
        }

        const code = $(tds[2]).text().trim();
        if (!code || code.includes("School Semester")) return;

        const nameBits = $(tds[3])
            .contents()
            .map((i, el) => $(el).text().trim())
            .get()
            .filter(text => text.length > 0);

        const title = nameBits.length > 2 ? nameBits[2] : nameBits[0];
        const grade = $(tds[5]).text().trim();
        const year =  $(tds[0]).text().trim() + $(tds[1]).text().trim();
        
        let status = "passed";
        if (grade.includes("Grade Not Submitted") || grade.includes("æˆç¸¾æœªåˆ°")) {
            status = "inProgress";
        } else if (["E", "X", "F"].includes(grade)) {
            status = "failed";
        } else if (grade.includes("Withdrawn") || grade.includes("停修")) {
            return; 
        }

        const record = {
            "title": title || "",
            "credits": parsedCredits,
            "grade": status === "passed" ? grade : "",
            "year": year,
            "code": code,
            "status": status
        };

        allRecords.push(record);
        if (["PE", "ZY", "ZZ"].some(prefix => code.includes(prefix))) {
            categories["PE & Service"]["courses"].push(record);
        } else if (code.includes("GE") || code.includes("GEC")) {
            categories["General Education"]["courses"].push(record);
        } else if (["CS", "MATH", "PHYS", "EECS", "EE"].some(prefix => code.includes(prefix)) && parsedCredits > 0) {
            categories["Compulsory"]["courses"].push(record);
        } else {
            categories["Electives"]["courses"].push(record);
        }
    });

    // --- 3. CALCULATE TOTALS ---
    const cumulativeGpa = totalGpaCredits > 0 ? (totalGradePoints / totalGpaCredits).toFixed(2) : "0.00";
    
    let currentCoursesCount = 0;
    const finalCategories = [];

    for (const [catName, data] of Object.entries(categories)) {
        let earned = 0;
        data.courses.forEach(c => {
            if (c.status === "passed") earned += c.credits;
            if (c.status === "inProgress") currentCoursesCount++;
        });

        finalCategories.push({
            "title": catName,
            "earnedCredits": earned,
            "requiredCredits": data.required,
            "records": data.courses
        });
    }

    const outputData = {
        "studentInfo": studentInfo,
        "summary": {
            "cumulativeGpa": cumulativeGpa,
            "currentSemesterCourses": String(currentCoursesCount)
        },
        "allRecords" : allRecords,
        "categories": finalCategories
    };

    return outputData;
}

function parseSchedule(htmlContent) {
    try {
        let html = htmlContent;
        if (Array.isArray(htmlContent)) {
            html = '<table>' + htmlContent.join('\n') + '</table>';
        }
        const $ = cheerio.load(html);
        
        const rows = $('tr.class3');
        const courseList = [];

        rows.each((index, rowElement) => {
            const tds = $(rowElement).find('td');
            if (tds.length < 7) return; 

            const rawFirst = $(tds[0]).text().trim();
            const yearMatch = rawFirst.match(/^(\d{3})/);
            const year = yearMatch ? yearMatch[1] : null;

            if (year === "114") {
                const code = rawFirst;
                
                const nameBits = $(tds[1])
                    .contents()
                    .map((i, el) => $(el).text().trim())
                    .get()
                    .filter(text => text.length > 0);
                    
                const title = nameBits.length > 1 ? nameBits[1] : nameBits[0];

                const prefixMatch = code.match(/^([a-zA-Z]+)/);
                const prefix = prefixMatch ? prefixMatch[1] : "DEFAULT";
                
                const style = styleMap[prefix] || { bg: '0xFFEFF6FF', border: '0xFFBFDBFE', text: '0xFF1D4ED8' };

                courseList.push({
                    "title": title || "",
                    "code": code,
                    "day": 1,
                    "startSlot": 0,
                    "duration": 2,
                    "bg": style.bg,
                    "border": style.border,
                    "text": style.text
                });
            }
        });

        return courseList;

    } catch (error) {
        console.error(`Error parsing file: ${error.message}`);
    }
}

// Export modules the CommonJS way
module.exports = {
    parseGraduationData,
    parseSchedule
};