// const { chromium } = require('playwright');
// const cheerio = require('cheerio');
// const axios = require('axios');
// const fs = require('fs');
// const path = require('path');
// const whisper = require('whisper-node');

import { chromium } from 'playwright';
import * as cheerio from 'cheerio';
import  axios from 'axios';
import * as fs from 'fs';
import * as path from 'path';
import {whisper} from 'whisper-node';
import { fileURLToPath } from 'url';
import { exec } from 'child_process';
import { promisify } from 'util';

// const __filename = fileUrlToPath(import.meta.url);
const __dirname = import.meta.dirname;
const execPromise = promisify(exec);

// Helper function to convert audio with ffmpeg
async function convertAudioWithFFmpeg(inputFile, outputFile) {
  try {
    const command = `ffmpeg -i ${inputFile} -ar 16000 ${outputFile} -y`;
    await execPromise(command);
    console.log(`Audio converted: ${inputFile} -> ${outputFile}`);
  } catch (err) {
    console.error('FFmpeg conversion failed:', err);
    throw err;
  }
}

export async function transcribingLocalCaptcha(outputFilename) {
  try {
    // Options configuration for the local whisper instance
    const options = {
      modelName: "base.en",       // Automatically downloads the tiny English model if missing
      whisperOptions: {
        language: "en",  
        gen_file_txt: false,      // outputs .txt file
        gen_file_subtitle: false, // outputs .srt file
        gen_file_vtt: false,        // Force English processing to skip language detection lag
        word_timestamps: true,   // Keeps execution lean and fast
      }
    };

    // Execute the local transcription engine
    const transcript = await whisper(outputFilename,options);
    
    const captchaText = Array.isArray(transcript) ? transcript.filter(item => !isNaN(item.speech)) : '';
    const parsedCaptchaText = Array.isArray(captchaText) ? captchaText.map(item => item.speech).join('') : '';
    
    // console.log(parsedCaptchaText);
    // console.log(captchaText);
    // Return transcript array with all segments
    return parsedCaptchaText;
    
  } catch (err) {
    console.error("Local Whisper engine failed:", err);
    throw err;
  }
}

export async function ccxpKeyGetter(username, passwd) {
  const baseUrl = 'https://www.ccxp.nthu.edu.tw/ccxp/INQUIRE/index.php?lang=english';
  
  // Launch Playwright browser (defaults to asynchronous execution)
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();
  const page = await context.newPage();
  
  try {
    await page.goto(baseUrl);
    await page.waitForSelector('form'); // Wait for form data
    
    // Get HTML and load it into Cheerio (equivalent to BeautifulSoup)
    const html = await page.content();
    const $ = cheerio.load(html);
    
    // Find the audio link
    const downloadLink = $('a').first();
    const fileUrl = downloadLink.attr('href');
    
    if (!fileUrl) {
      throw new Error('Could not find captcha audio link on page');
    }
    
    // Resolve the full URL (equivalent to urljoin)
    const fullUrl = new URL(fileUrl, baseUrl).href;
    const outputFilename = path.join(__dirname, 'captcha/captcha.wav');
    
    // Download the captcha audio file using Axios (equivalent to requests)
    const response = await axios({
      method: 'get',
      url: fullUrl,
      responseType: 'stream',
    });
    
    // Save file locally using native Node.js streams
    const writer = fs.createWriteStream(outputFilename);
    response.data.pipe(writer);
    
    await new Promise((resolve, reject) => {
      writer.on('finish', resolve);
      writer.on('error', reject);
    });
    
    // Convert audio to 16kHz WAV using ffmpeg
    const convertedFilename = outputFilename.replace('.wav', '_converted.wav');
    await convertAudioWithFFmpeg(outputFilename, convertedFilename);
    
    const captcha = await transcribingLocalCaptcha(convertedFilename);
    // return captcha;
    
    // Locate form fields and submit (Playwright selectors)
    await page.fill('input[name="account"]', username);
    await page.fill('input[name="passwd"]', passwd);
    await page.fill('input[name="passwd2"]', captcha);
    
    // Click submit and wait for navigation/load complete
    await page.getByRole('button', { name: 'Login' }).click();
    // await page.click('input[name="Submit"]');
    await page.waitForSelector('frameset');
    
    const finalUrl = page.url();
    console.log(finalUrl);
    
    // Extract the session key using URL parameters instead of fragile string slicing
    const urlObj = new URL(finalUrl);
    // Assuming the URL looks like: view.php?sessKey=xyz&otherParam=123
    // We fetch the first key-value pair from the search params
    const params = new URLSearchParams(urlObj.search);
    
    let sessKey = '';
    for (const [key, value] of params.entries()) {
      // This mimics your Python logic finding the string between "=" and "&"
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
    await browser.close();
  }
}