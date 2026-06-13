// const { chromium } = require('playwright');
// const cheerio = require('cheerio');
// const fs = require('fs');
// const path = require('path');

import { chromium } from "playwright";
import * as cheerio from 'cheerio';
import * as fs from 'fs';
import * as path from 'path';
import { parseGraduationData, parseSchedule } from "../parser/parser.js";



const transcriptPage = 'https://www.ccxp.nthu.edu.tw/ccxp/INQUIRE/JH/8/R/6.3/JH8R63001.php?ACIXSTORE=';
const currentCourse = 'https://www.ccxp.nthu.edu.tw/ccxp/COURSE/JH/7/7.2/7.2.1/JH721001.php?ACIXSTORE=';

// Ensure the HTML directory exists safely before writing files
// const htmlDir = path.join(__dirname, 'html');
// if (!fs.existsSync(htmlDir)){
//     fs.mkdirSync(htmlDir);
// }

export async function scrapTranscriptPage(sessKey) {
    const url = transcriptPage + sessKey;
    const browser = await chromium.launch({ headless: true });
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
        
        // Cheerio can search for multiple tag types at once just like soup.find_all(['tr', 'td'])
        $('tr, td').each((index, element) => {
            const tag = $(element);
            const tagName = element.name; // 'tr' or 'td'
            
            if (tagName === 'tr') {
                if (tag.attr('align') === 'center') {
                    courses.push(tag.toString());
                }
                
                // equivalent to: 'input' in tag.get('class', [])
                if (tag.hasClass('input')) {
                    gpa.push(tag.toString());
                }
            } else if (tagName === 'td') {
                if (userInfo === null && tag.hasClass('input_red')) {
                    userInfo = tag.toString();
                    // Found userInfo, mimicking your Python conditional break logic
                }
            }
        });
        
        // Write out the raw collected HTML strings to the file
        // const filePath = path.join(htmlDir, 'graduation_data.html');
        // const writeStream = fs.createWriteStream(filePath);
        
        // courses.forEach(item => writeStream.write(item + '\n'));
        // gpa.forEach(item => writeStream.write(item + '\n'));
        // if (userInfo) {
        //     writeStream.write(userInfo + '\n');
        // }
        
        // writeStream.end();
        // console.log(`Saved transcript data to ${filePath}`);
        // console.log(courses);
        // console.log(gpa);
        // console.log(userInfo);
        const scrappedData = [userInfo,...courses,...gpa];
        // console.log(scrappedData);
        return parseGraduationData(scrappedData);

        
        // return [userInfo,...courses,...gpa];
        
    } catch (error) {
        console.error("Error scraping transcript page:", error);
    } finally {
        await browser.close();
    }
}

export async function scrapCurrentCourse(sessKey) {
    const url = currentCourse + sessKey;
    const browser = await chromium.launch({ headless: true });
    const context = await browser.newContext();
    const page = await context.newPage();
    
    try {
        await page.goto(url);
        await page.waitForSelector('form'); // Wait for course data
        
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
        // Cheerio matches soup.find_all('tr', class_="class3")
        $('tr.class3').each((index, element) => {
            courses.push($(element).toString());
        });
        
        console.log(`Found ${courses.length} schedule courses.`);
        
        // Write the data to your schedule file
        // console.log(courses);
        return parseSchedule(courses);
        // const filePath = path.join(htmlDir, 'schedule.html');
        // const writeStream = fs.createWriteStream(filePath);
        
        // courses.forEach(item => writeStream.write(item + '\n'));
        
        // writeStream.end();
        // console.log(`Saved schedule data to ${filePath}`);

        
    } catch (error) {
        console.error("Error scraping current courses:", error);
    } finally {
        await browser.close();
    }
}