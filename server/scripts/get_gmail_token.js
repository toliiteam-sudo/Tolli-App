/**
 * Gmail OAuth2 Refresh Token Generator Helper
 * 
 * Usage:
 *   1. Ensure your server/.env has GMAIL_CLIENT_ID and GMAIL_CLIENT_SECRET
 *   2. Run: node scripts/get_gmail_token.js
 *   3. Follow the CLI prompt to authorize and copy the generated GMAIL_REFRESH_TOKEN
 */
const { google } = require('googleapis');
const readline = require('readline');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const CLIENT_ID = process.env.GMAIL_CLIENT_ID || process.argv[2];
const CLIENT_SECRET = process.env.GMAIL_CLIENT_SECRET || process.argv[3];
const REDIRECT_URI = 'urn:ietf:wg:oauth:2.0:oob';

if (!CLIENT_ID || !CLIENT_SECRET) {
  console.error('\n❌ ERROR: Missing Client ID or Client Secret.');
  console.log('Provide them via .env or pass as arguments:');
  console.log('node scripts/get_gmail_token.js <CLIENT_ID> <CLIENT_SECRET>\n');
  process.exit(1);
}

const oauth2Client = new google.auth.OAuth2(CLIENT_ID, CLIENT_SECRET, REDIRECT_URI);

const authUrl = oauth2Client.generateAuthUrl({
  access_type: 'offline',
  scope: ['https://www.googleapis.com/auth/gmail.send'],
  prompt: 'consent'
});

console.log('\n====================================================');
console.log('🔑 TOLII Gmail OAuth2 Token Setup');
console.log('====================================================');
console.log('\n1. Open this URL in browser:\n');
console.log(authUrl);
console.log('\n2. Sign in with the sender Google Account');
console.log('3. Click "Allow" on the consent screen');
console.log('4. Copy the authorization code provided by Google\n');
console.log('====================================================\n');

const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
rl.question('Paste the authorization code here: ', async (code) => {
  rl.close();
  try {
    const { tokens } = await oauth2Client.getToken(code.trim());
    console.log('\n====================================================');
    console.log('✅ REFRESH TOKEN GENERATED SUCCESSFULLY!');
    console.log('====================================================');
    console.log('\nGMAIL_REFRESH_TOKEN=' + tokens.refresh_token);
    console.log('\nAdd this value to your server/.env or cloud deployment dashboard (e.g. Render).\n');
  } catch (err) {
    console.error('\n❌ Failed to exchange code for tokens:', err.message);
  }
});
