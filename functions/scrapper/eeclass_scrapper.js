import { chromium } from "playwright";
import * as cheerio from 'cheerio';
import * as fs from 'fs';
import * as path from 'path';
import { fileURLToPath } from 'url';

const eeclassPage = "https://www.ccxp.nthu.edu.tw/ccxp/INQUIRE/SSO_LINK/oauth_eeclass.php?ACIXSTORE=";
const __dirname = import.meta.dirname;
const outputDest = path.join(__dirname, 'captcha/page.png');

export async function scrapEeclass(sessKey, currCourses) {
    const url = eeclassPage + sessKey;
    const browser = await chromium.launch({ headless: false });
    const context = await browser.newContext();
    const page = await context.newPage();

    try{
        await page.goto(url);
        await page.waitForSelector('a');
        
        // const html = await page.content();
        // const $ = cheerio.load(html);
        
        const coursesLink = [];
        // fs-p
        // fs-list
        
        for(const course of currCourses) {
            const courseTitle = course['title'];
            console.log(courseTitle);
            const link = await page.getByText(courseTitle).click();
            await page.waitForSelector('.fs-p');
            const url = page.url();

            const html = await page.content();
            const $ = cheerio.load(html);
            const courseAnnouncement = $('.fs-list').length;
            if(courseAnnouncement) {
                coursesLink.push({title : courseTitle, url: url})
            }

            
            await page.goBack();
    
            await page.waitForLoadState('domcontentloaded');
        }
        return coursesLink;

    }
    catch (e) {
        console.log(e);
    }
    finally {
        await browser.close();
    }
}
