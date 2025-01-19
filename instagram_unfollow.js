const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch({
    headless: false,
    userDataDir: 'C:\\Users\\friv1\\AppData\\Local\\Google\\Chrome\\User Data',
    executablePath: 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe', // Path to your installed Chrome
    args: [
      '--start-maximized',
      '--profile-directory=Default',
    ],
  });

  const page = await browser.newPage();
  await page.goto('https://www.instagram.com/', { waitUntil: 'networkidle2' });

  console.log('Instagram loaded successfully with the Default profile!');
  
  // You can add Instagram automation code here after logging in manually
  
  
})();
