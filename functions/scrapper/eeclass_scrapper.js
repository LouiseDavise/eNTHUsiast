const { chromium: playwright } = require('playwright-core');
const chromium = require('@sparticuz/chromium');
const cheerio = require('cheerio');
const fs = require('fs');
const path = require('path');

const eeclassPage = "https://www.ccxp.nthu.edu.tw/ccxp/INQUIRE/SSO_LINK/oauth_eeclass.php?ACIXSTORE=";

async function scrapEeclass(sessKey, currCourses) {
    const url = eeclassPage + sessKey;

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
        await page.waitForSelector('a');

        const courses = [];

        for (let i = 0; i < currCourses.length; i++) {
            let html = await page.content();
            let $ = cheerio.load(html);

            const courseTitle = currCourses[i]['title'].replace(/,/g, '#');
            await page.getByText(courseTitle).click();
            await page.waitForSelector('.fs-p');
            const url = page.url();
            html = await page.content();
            $ = cheerio.load(html);
            const courseAnnouncement = $('.fs-list').length;

            await page.getByText('Course materials').click();
            await page.waitForSelector('.fs-table');
            html = await page.content();
            $ = cheerio.load(html);
            const links = $('a[href^="/media/doc/"]');
            const materials = [];
            links.each((i, el) => {
                const href = $(el).attr('href');
                const text = $(el).text().trim();
                materials.push({ title: text, url: "https://eeclass.nthu.edu.tw" + href });
            });
            materials.reverse();

            if (courseAnnouncement) {
                currCourses[i]['platform'] = 'EECLASS';
                currCourses[i]['url'] = url;
                currCourses[i]['materials'] = materials;
            } else {
                currCourses[i]['platform'] = 'ELEARN';
                currCourses[i]['url'] = 'https://elearn.nthu.edu.tw/my/';
            }

            await page.goBack();
            await page.goBack();
            await page.waitForLoadState('domcontentloaded');
        }
        return currCourses;
    } catch (e) {
        console.log(e);
    } finally {
        await browser.close();
    }
}

module.exports = { scrapEeclass };