// const { chromium } = require('playwright');
// const cheerio = require('cheerio');
// const axios = require('axios');
// const fs = require('fs');
// const path = require('path');
// const whisper = require('whisper-node');

// import { chromium } from 'playwright';
// import * as cheerio from 'cheerio';
// import  axios from 'axios';
// import * as fs from 'fs';
// import * as path from 'path';
// import {whisper} from 'whisper-node';
// import { fileURLToPath } from 'url';
// import { exec } from 'child_process';
// import { promisify } from 'util';
const { chromium: playwright } = require('playwright-core');
const chromium = require('@sparticuz/chromium');
const cheerio = require('cheerio');
const axios = require('axios');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { OpenAI } = require('openai');

let openai;

function getOpenAiClient() {
  if (!openai) {
    openai = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
    });
  }
  return openai;
}

async function transcribeWithOpenAI(filePath) {
  try {
    const response = await getOpenAiClient().audio.transcriptions.create({
      file: fs.createReadStream(filePath),
      model: "whisper-1",
      language: "en", // Helps speed up processing time
    });

    // Captchas often come back with spaces (e.g., "1 2 3 4"). 
    // This strips all whitespace so it submits as a single token.
    // const parsedCaptchaText = response.text.replace(/\s+/g, '');
    const parsedCaptchaText = response.text.replace(/\D/g, '');
    console.log("Transcribed Captcha:", parsedCaptchaText);
    
    return parsedCaptchaText;
  } catch (err) {
    console.error("OpenAI Whisper API failed:", err);
    throw err;
  }
}

async function ccxpKeyGetter(username, passwd) {
  const baseUrl = 'https://www.ccxp.nthu.edu.tw/ccxp/INQUIRE/index.php?lang=english';
  
  const isCloudFunction = !!process.env.K_SERVICE || !!process.env.FUNCTION_NAME;
  const isLocal = !process.env.FUNCTIONS_EMULATOR && !isCloudFunction;

  const execPath = isLocal
    ? undefined
    : typeof chromium.executablePath === 'function'
      ? await chromium.executablePath()   // v107+
      : chromium.executablePath;          //

  const browser = await playwright.launch({
    args: isLocal ? [] : chromium.args,
    executablePath: await chromium.executablePath(),
    headless: true 
  });

  const context = await browser.newContext();
  const page = await context.newPage();
  
  // Only one temporary file is needed now
  const outputFilename = path.join(os.tmpdir(), 'captcha.wav');
  
  try {
    await page.goto(baseUrl);
    await page.waitForSelector('form'); 
    
    const html = await page.content();
    const $ = cheerio.load(html);
    
    const downloadLink = $('a').first();
    const fileUrl = downloadLink.attr('href');
    
    if (!fileUrl) {
      throw new Error('Could not find captcha audio link on page');
    }
    
    const fullUrl = new URL(fileUrl, baseUrl).href;
    
    // Download the captcha audio file using Axios
    const response = await axios({
      method: 'get',
      url: fullUrl,
      responseType: 'stream',
    });
    
    const writer = fs.createWriteStream(outputFilename);
    response.data.pipe(writer);
    
    await new Promise((resolve, reject) => {
      writer.on('finish', resolve);
      writer.on('error', reject);
    });
    
    // Call the OpenAI API directly using the downloaded file
    const captcha = await transcribeWithOpenAI(outputFilename);
    
    // Locate form fields and submit
    await page.fill('input[name="account"]', username);
    await page.fill('input[name="passwd"]', passwd);
    await page.fill('input[name="passwd2"]', captcha);
    
    await page.getByRole('button', { name: 'Login' }).click();
    await page.waitForSelector('frameset');
    
    const finalUrl = page.url();
    console.log("Navigated to:", finalUrl);
    
    const urlObj = new URL(finalUrl);
    const params = new URLSearchParams(urlObj.search);
    
    let sessKey = '';
    for (const [key, value] of params.entries()) {
      sessKey = value; 
      break; 
    }
    
    if (sessKey.length <= 10) {
      return null;
    } else {
      return sessKey;
    }
    
  } catch (error) {
    console.error('Scraping failed:', error);
    return null;
  } finally {
    // Clean up our single temporary file out of RAM
    if (fs.existsSync(outputFilename)) {
      fs.unlinkSync(outputFilename);
    }
    await browser.close();
  }
}

module.exports = {
  ccxpKeyGetter
};
