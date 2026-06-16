const { chromium: playwright } = require('playwright-core');
const chromium = require('@sparticuz/chromium');
const cheerio = require('cheerio');
const fs = require('fs');
const path = require('path');
const { parseGraduationData, parseSchedule } = require("../parser/parser.js");

const transcriptPage = 'https://www.ccxp.nthu.edu.tw/ccxp/INQUIRE/JH/8/R/6.3/JH8R63001.php?ACIXSTORE=';
const currentCourse = 'https://www.ccxp.nthu.edu.tw/ccxp/COURSE/JH/7/7.2/7.2.1/JH721001.php?ACIXSTORE=';

async function scrapTranscriptPage(sessKey) {
    const url = transcriptPage + sessKey;
    
    // Determine if running locally or in Firebase Cloud environment
    const isCloudFunction = !!process.env.K_SERVICE || !!process.env.FUNCTION_NAME;
    const isLocal = !process.env.FUNCTIONS_EMULATOR && !isCloudFunction;

    const browser = await playwright.launch({
        args: isLocal ? [] : chromium.args,
        executablePath: isLocal ? undefined : await chromium.executablePath(),
        headless: true 
    });
    
    const context = await browser.newContext();
    const page = await context.newPage();
    
    try {
        await page.goto(url);
        await page.waitForSelector('tr'); // Wait for course data
        
        const html = await page.content();
        const $ = cheerio.load(html);
        
        const courses = [];
        const gpa = [];
        let userInfo = null;
        
        $('tr, td').each((index, element) => {
            const tag = $(element);
            const tagName = element.name; 
            
            if (tagName === 'tr') {
                if (tag.attr('align') === 'center') {
                    courses.push(tag.toString());
                }
                
                if (tag.hasClass('input')) {
                    gpa.push(tag.toString());
                }
            } else if (tagName === 'td') {
                if (userInfo === null && tag.hasClass('input_red')) {
                    userInfo = tag.toString();
                }
            }
        });
        
        const scrappedData = [userInfo, ...courses, ...gpa];
        return parseGraduationData(scrappedData);
        
    } catch (error) {
        console.error("Error scraping transcript page:", error);
        throw error;
    } finally {
        await browser.close();
    }
}

async function scrapCurrentCourse(sessKey) {
    const url = currentCourse + sessKey;
    
    // Determine if running locally or in Firebase Cloud environment
    const isCloudFunction = !!process.env.K_SERVICE || !!process.env.FUNCTION_NAME;
    const isLocal = !process.env.FUNCTIONS_EMULATOR && !isCloudFunction;

    const browser = await playwright.launch({
        args: isLocal ? [] : chromium.args,
        executablePath: isLocal ? undefined : await chromium.executablePath(),
        headless: true 
    });
    
    const context = await browser.newContext();
    const page = await context.newPage();
    
    try {
        await page.goto(url);
        await page.waitForSelector('select');
        await page.selectOption('select[name="semester"]', '114,20')
        await page.waitForSelector('form'); // Wait for form loading
        
        // Use clean XPath to locate and select option
        const dropdown = page.locator('//html/body/form/table/tbody/tr[3]/td[2]/select[2]');
        await dropdown.click();
        await dropdown.selectOption("400P");
        
        // Click the submit button
        await page.locator("//html/body/form/table/tbody/tr[4]/td/p/input").click();
        
        await page.waitForSelector('body');
        
        const html = await page.content();
        const $ = cheerio.load(html);
        
        const courses = [];
        $('tr.class3').each((index, element) => {
            courses.push($(element).toString());
        });
        
        console.log(`Found ${courses.length} schedule courses.`);
        return parseSchedule(courses);
        
    } catch (error) {
        console.error("Error scraping current courses:", error);
        throw error;
    } finally {
        await browser.close();
    }
}

// Export functions using CommonJS format
module.exports = {
    scrapTranscriptPage,
    scrapCurrentCourse
};
