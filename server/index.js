const express = require('express');
const cors = require('cors');
const crypto = require('crypto');
const https = require('https');
const nodemailer = require('nodemailer');
const { Resend } = require('resend');
const admin = require('firebase-admin');
const Razorpay = require('razorpay');
require('dotenv').config();

const RAZORPAY_KEY_ID = process.env.RAZORPAY_KEY_ID || '';
const RAZORPAY_KEY_SECRET = process.env.RAZORPAY_KEY_SECRET || '';
const RAZORPAY_WEBHOOK_SECRET = process.env.RAZORPAY_WEBHOOK_SECRET || '';

// Razorpay SDK Client (initialized when credentials are provided)
let razorpay = null;
if (RAZORPAY_KEY_ID && RAZORPAY_KEY_SECRET) {
  razorpay = new Razorpay({
    key_id: RAZORPAY_KEY_ID,
    key_secret: RAZORPAY_KEY_SECRET,
  });
}

// Constant-time string comparison to prevent timing attacks
function constantTimeCompare(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string') return false;
  const bufA = Buffer.from(a, 'utf8');
  const bufB = Buffer.from(b, 'utf8');
  if (bufA.length !== bufB.length) {
    crypto.timingSafeEqual(bufA, bufA);
    return false;
  }
  return crypto.timingSafeEqual(bufA, bufB);
}

const app = express();

// Capture raw body buffer for precise HMAC signature verification (Webhooks)
app.use(express.json({
  verify: (req, res, buf) => {
    req.rawBody = buf;
  }
}));
app.use(cors());

// Safe environment configuration audit (never prints secrets)
function validateEnvironmentConfig() {
  const isProd = process.env.NODE_ENV === 'production';
  const hasKeyId = !!process.env.RAZORPAY_KEY_ID;
  const hasKeySecret = !!process.env.RAZORPAY_KEY_SECRET;
  const hasWebhookSecret = !!process.env.RAZORPAY_WEBHOOK_SECRET;

  console.log(`[CONFIG] Server Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`[CONFIG] Razorpay Key ID: ${hasKeyId ? 'Configured' : 'Not Configured'}`);
  console.log(`[CONFIG] Razorpay Key Secret: ${hasKeySecret ? 'Configured' : 'Not Configured'}`);
  console.log(`[CONFIG] Razorpay Webhook Secret: ${hasWebhookSecret ? 'Configured' : 'Not Configured'}`);

  if (isProd && (!hasKeyId || !hasKeySecret)) {
    console.warn('[CONFIG WARN] Missing Razorpay credentials in production mode!');
  }
}
validateEnvironmentConfig();

// 1. Gmail SMTP (App Password over SSL Port 465) — 100% RELIABLE, PERMANENT, ZERO EXPIRY
const SMTP_USER = process.env.SMTP_USER ? process.env.SMTP_USER.trim() : 'tolii.team@gmail.com';
const SMTP_PASS = process.env.SMTP_PASS ? process.env.SMTP_PASS.replace(/\s+/g, '') : null;
const GMAIL_SENDER = SMTP_USER;

function createGmailTransport() {
  return nodemailer.createTransport({
    host: 'smtp.gmail.com',
    port: 465,
    secure: true,
    auth: { user: SMTP_USER, pass: SMTP_PASS },
    connectionTimeout: 15000,
    greetingTimeout: 15000,
    socketTimeout: 20000,
  });
}

// 2. Gmail API (OAuth2 over HTTPS) — INBOX guaranteed, 500/day free
const GMAIL_CLIENT_ID = process.env.GMAIL_CLIENT_ID ? process.env.GMAIL_CLIENT_ID.trim() : null;
const GMAIL_CLIENT_SECRET = process.env.GMAIL_CLIENT_SECRET ? process.env.GMAIL_CLIENT_SECRET.trim() : null;
const GMAIL_REFRESH_TOKEN = process.env.GMAIL_REFRESH_TOKEN ? process.env.GMAIL_REFRESH_TOKEN.trim() : null;

async function getGmailAccessToken() {
  return new Promise((resolve, reject) => {
    const payload = new URLSearchParams({
      client_id: GMAIL_CLIENT_ID,
      client_secret: GMAIL_CLIENT_SECRET,
      refresh_token: GMAIL_REFRESH_TOKEN,
      grant_type: 'refresh_token'
    }).toString();

    const options = {
      hostname: 'oauth2.googleapis.com',
      path: '/token',
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'Content-Length': Buffer.byteLength(payload) }
    };
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        const json = JSON.parse(data);
        if (json.access_token) resolve(json.access_token);
        else reject(new Error(`Token error: ${data}`));
      });
    });
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

async function sendViaGmailApi(to, subject, htmlContent) {
  const accessToken = await getGmailAccessToken();

  // Build RFC 2822 message
  const message = [
    `From: "TOLII App" <${GMAIL_SENDER}>`,
    `To: ${to}`,
    `Subject: ${subject}`,
    'MIME-Version: 1.0',
    'Content-Type: text/html; charset=utf-8',
    '',
    htmlContent
  ].join('\r\n');

  const encoded = Buffer.from(message).toString('base64')
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

  return new Promise((resolve, reject) => {
    const payload = JSON.stringify({ raw: encoded });
    const options = {
      hostname: 'gmail.googleapis.com',
      path: '/gmail/v1/users/me/messages/send',
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload)
      }
    };
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) resolve({ success: true });
        else reject(new Error(`Gmail API ${res.statusCode}: ${data}`));
      });
    });
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

// 2. SendGrid HTTP API — Free 100/day, any recipient, no IP restriction, HTTPS only
const SENDGRID_API_KEY = process.env.SENDGRID_API_KEY ? process.env.SENDGRID_API_KEY.trim() : null;

async function sendViaSendGrid(to, subject, htmlContent) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify({
      personalizations: [{ to: [{ email: to }] }],
      from: { email: SMTP_USER || 'tolii.team@gmail.com', name: 'TOLII App' },
      subject: subject,
      content: [{ type: 'text/html', value: htmlContent }]
    });
    const options = {
      hostname: 'api.sendgrid.com',
      path: '/v3/mail/send',
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${SENDGRID_API_KEY}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload)
      }
    };
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        // SendGrid returns 202 on success (no body)
        if (res.statusCode === 202) resolve({ success: true });
        else reject(new Error(`SendGrid ${res.statusCode}: ${data}`));
      });
    });
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

// 3. Brevo HTTP API (Permanent, free 300/day, no IP restrictions)
const BREVO_API_KEY = process.env.BREVO_API_KEY ? process.env.BREVO_API_KEY.trim() : null;

async function sendViaBrevoApi(to, subject, htmlContent) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify({
      sender: { email: SMTP_USER || 'tolii.team@gmail.com', name: 'TOLII App' },
      to: [{ email: to }],
      subject: subject,
      htmlContent: htmlContent
    });
    const options = {
      hostname: 'api.brevo.com',
      path: '/v3/smtp/email',
      method: 'POST',
      headers: {
        'accept': 'application/json',
        'api-key': BREVO_API_KEY,
        'content-type': 'application/json',
        'content-length': Buffer.byteLength(payload)
      }
    };
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) resolve({ success: true });
        else reject(new Error(`Brevo API ${res.statusCode}: ${data}`));
      });
    });
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

// 4. Mailjet HTTP API fallback
const MAILJET_API_KEY = process.env.MAILJET_API_KEY ? process.env.MAILJET_API_KEY.trim() : null;
const MAILJET_SECRET_KEY = process.env.MAILJET_SECRET_KEY ? process.env.MAILJET_SECRET_KEY.trim() : null;

async function sendViaMailjet(to, subject, htmlContent) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify({
      Messages: [{
        From: { Email: SMTP_USER || 'tolii.team@gmail.com', Name: 'TOLII App' },
        To: [{ Email: to }],
        Subject: subject,
        HTMLPart: htmlContent
      }]
    });
    const auth = Buffer.from(`${MAILJET_API_KEY}:${MAILJET_SECRET_KEY}`).toString('base64');
    const options = {
      hostname: 'api.mailjet.com',
      path: '/v3.1/send',
      method: 'POST',
      headers: {
        'Authorization': `Basic ${auth}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload)
      }
    };
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) resolve({ success: true });
        else reject(new Error(`Mailjet ${res.statusCode}: ${data}`));
      });
    });
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

// 3. Resend last-resort fallback
const RESEND_API_KEY = process.env.RESEND_API_KEY;
const resend = RESEND_API_KEY ? new Resend(RESEND_API_KEY) : null;


// 3. Initialize Firebase Admin safely (require service account or emulator env)
let isFirebaseAdminInitialized = false;
try {
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    isFirebaseAdminInitialized = true;
    console.log('[FIREBASE] Admin initialized successfully with Service Account');
  } else if (process.env.FIRESTORE_EMULATOR_HOST) {
    admin.initializeApp();
    isFirebaseAdminInitialized = true;
    console.log('[FIREBASE] Admin initialized with Firestore Emulator');
  } else {
    console.log('[FIREBASE] Admin initialization deferred (no SERVICE_ACCOUNT or EMULATOR provided)');
  }
} catch (e) {
  console.warn('[FIREBASE WARN] Firebase Admin initialization skipped:', e.message);
  isFirebaseAdminInitialized = false;
}

// 4. In-Memory Store for OTPs and Rate Limiting
const otpStore = new Map();
const OTP_SECRET = process.env.OTP_SECRET || 'tolii_secure_secret_salt_2026';
const OTP_EXPIRY_MS = 5 * 60 * 1000; // 5 minutes
const RESEND_COOLDOWN_MS = 60 * 1000; // 60 seconds
const MAX_ATTEMPTS = 5;

// Hash OTP with SHA256 + salt
function hashOtp(email, otp) {
  return crypto.createHmac('sha256', OTP_SECRET).update(`${email.toLowerCase()}:${otp}`).digest('hex');
}

// Clean expired OTPs periodically (every 10 minutes)
setInterval(() => {
  const now = Date.now();
  for (const [email, record] of otpStore.entries()) {
    if (now > record.expiresAt) {
      otpStore.delete(email);
    }
  }
}, 10 * 60 * 1000);

// Helper to generate aesthetic sports email HTML
function generateOtpHtml(otp) {
  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>TOLII Verification Code</title>
    </head>
    <body style="margin: 0; padding: 0; background-color: #F8FAFC; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;">
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background-color: #F8FAFC; padding: 40px 16px;">
        <tr>
          <td align="center">
            <table role="presentation" width="100%" max-width="520px" cellspacing="0" cellpadding="0" border="0" style="max-width: 520px; background-color: #FFFFFF; border-radius: 24px; overflow: hidden; box-shadow: 0 10px 30px rgba(6, 62, 158, 0.08); border: 1px solid #E2E8F0;">
              
              <!-- Hero Header -->
              <tr>
                <td style="background: linear-gradient(135deg, #063E9E 0%, #032561 100%); padding: 36px 32px; text-align: center;">
                  <div style="display: inline-block; background: rgba(255, 255, 255, 0.15); border: 1px solid rgba(255, 255, 255, 0.25); border-radius: 12px; padding: 6px 16px; margin-bottom: 14px;">
                    <span style="font-size: 14px; font-weight: 700; color: #FFFFFF; letter-spacing: 2px; text-transform: uppercase;">⚽ 🏏 🏸 🎾 🚴</span>
                  </div>
                  <h1 style="margin: 0; font-size: 32px; font-weight: 900; color: #FFFFFF; letter-spacing: -0.5px;">TOLII</h1>
                  <p style="margin: 6px 0 0 0; font-size: 14px; color: #BFDBFE; font-weight: 500; letter-spacing: 0.3px;">Play Sports • Meet Players • Join Games</p>
                </td>
              </tr>

              <!-- Content Body -->
              <tr>
                <td style="padding: 36px 32px 28px 32px; text-align: center;">
                  <h2 style="margin: 0 0 10px 0; font-size: 20px; font-weight: 700; color: #0F172A;">Your Login Verification Code</h2>
                  <p style="margin: 0 0 24px 0; font-size: 15px; color: #64748B; line-height: 1.5;">
                    Use the 6-digit code below to securely sign in to your TOLII account.
                  </p>

                  <!-- High-Impact OTP Display Box -->
                  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="margin: 0 auto 24px auto;">
                    <tr>
                      <td style="background-color: #F0F5FF; border: 2px dashed #063E9E; border-radius: 16px; padding: 22px 16px; text-align: center;">
                        <span style="font-family: 'Courier New', Courier, monospace, sans-serif; font-size: 38px; font-weight: 800; letter-spacing: 10px; color: #063E9E; display: inline-block; margin-left: 10px;">${otp}</span>
                      </td>
                    </tr>
                  </table>

                  <!-- Expiry & Security Badges -->
                  <div style="background-color: #FFFBEB; border: 1px solid #FEF3C7; border-radius: 12px; padding: 12px 16px; margin-bottom: 24px; text-align: left;">
                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
                      <tr>
                        <td width="24" valign="top" style="font-size: 16px; line-height: 1;">⏱️</td>
                        <td style="font-size: 13px; color: #92400E; font-weight: 500; padding-left: 8px;">
                          This code is valid for <strong>5 minutes</strong> only and can be used once.
                        </td>
                      </tr>
                    </table>
                  </div>

                  <p style="margin: 0; font-size: 13px; color: #94A3B8; line-height: 1.4;">
                    If you didn't request this verification code, please disregard this email. Your account remains completely safe.
                  </p>
                </td>
              </tr>

              <!-- Footer -->
              <tr>
                <td style="background-color: #F8FAFC; border-top: 1px solid #E2E8F0; padding: 20px 32px; text-align: center;">
                  <p style="margin: 0 0 6px 0; font-size: 12px; color: #64748B; font-weight: 600;">
                    TOLII Sports Community App
                  </p>
                  <p style="margin: 0; font-size: 11px; color: #94A3B8;">
                    Connecting athletes, turf players & sports lovers everywhere.
                  </p>
                </td>
              </tr>

            </table>
          </td>
        </tr>
      </table>
    </body>
    </html>
  `;
}

// Health check endpoint
app.get('/', (req, res) => {
  res.json({
    status: 'online',
    service: 'TOLII OTP Authentication Service',
    gmailSmtpConfigured: !!(SMTP_USER && SMTP_PASS),
    brevoConfigured: !!BREVO_API_KEY,
    gmailApiConfigured: !!(GMAIL_CLIENT_ID && GMAIL_CLIENT_SECRET && GMAIL_REFRESH_TOKEN),
    sendgridConfigured: !!SENDGRID_API_KEY,
    mailjetConfigured: !!(MAILJET_API_KEY && MAILJET_SECRET_KEY),
    resendConfigured: !!resend,
    timestamp: new Date().toISOString()
  });
});

// Diagnostic endpoint to test all configured email transports
app.get('/api/test-transports', async (req, res) => {
  const testEmail = req.query.email || SMTP_USER || 'tolii.team@gmail.com';
  const results = {};

  // 1. Gmail API test
  if (GMAIL_CLIENT_ID && GMAIL_CLIENT_SECRET && GMAIL_REFRESH_TOKEN) {
    try {
      const token = await Promise.race([
        getGmailAccessToken(),
        new Promise((_, reject) => setTimeout(() => reject(new Error('Token fetch timeout (5s)')), 5000))
      ]);
      results.gmailApi = { success: true, message: 'OAuth2 token obtained successfully', tokenPrefix: token.substring(0, 10) + '...' };
    } catch (e) {
      results.gmailApi = {
        success: false,
        error: e.message,
        configuredClientId: GMAIL_CLIENT_ID ? (GMAIL_CLIENT_ID.substring(0, 25) + '...' + GMAIL_CLIENT_ID.slice(-10)) : null
      };
    }
  } else {
    results.gmailApi = { success: false, error: 'Not configured (missing CLIENT_ID, CLIENT_SECRET or REFRESH_TOKEN)' };
  }

  // 2. Brevo API test
  if (BREVO_API_KEY) {
    try {
      await Promise.race([
        sendViaBrevoApi(testEmail, 'TOLII Test Diagnostic', '<p>Test</p>'),
        new Promise((_, reject) => setTimeout(() => reject(new Error('Brevo timeout (6s)')), 6000))
      ]);
      results.brevo = { success: true, message: 'Brevo email sent successfully' };
    } catch (e) {
      results.brevo = { success: false, error: e.message };
    }
  } else {
    results.brevo = { success: false, error: 'Not configured (missing BREVO_API_KEY)' };
  }

  // 3. Mailjet test
  if (MAILJET_API_KEY && MAILJET_SECRET_KEY) {
    try {
      await Promise.race([
        sendViaMailjet(testEmail, 'TOLII Test Diagnostic', '<p>Test</p>'),
        new Promise((_, reject) => setTimeout(() => reject(new Error('Mailjet timeout (6s)')), 6000))
      ]);
      results.mailjet = { success: true, message: 'Mailjet email sent successfully' };
    } catch (e) {
      results.mailjet = { success: false, error: e.message };
    }
  } else {
    results.mailjet = { success: false, error: 'Not configured (missing MAILJET keys)' };
  }

  // 4. Gmail SMTP test
  if (SMTP_USER && SMTP_PASS) {
    try {
      const transport = createGmailTransport();
      await Promise.race([
        transport.verify(),
        new Promise((_, reject) => setTimeout(() => reject(new Error('Gmail SMTP verify timeout (4s)')), 4000))
      ]);
      transport.close();
      results.gmailSmtp = { success: true, message: 'SMTP connection verified' };
    } catch (e) {
      results.gmailSmtp = { success: false, error: e.message };
    }
  } else {
    results.gmailSmtp = { success: false, error: 'Not configured (missing SMTP_USER or SMTP_PASS)' };
  }

  return res.json({ timestamp: new Date().toISOString(), testEmail, results });
});

// ─────────────────────────────────────────────────────────
// Endpoint 1: Request OTP
// ─────────────────────────────────────────────────────────
app.post('/api/request-otp', async (req, res) => {
  try {
    const { email } = req.body;
    if (!email || typeof email !== 'string') {
      return res.status(400).json({ success: false, message: 'Valid email is required' });
    }

    const cleanEmail = email.trim().toLowerCase();
    const emailRegex = /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/;
    if (!emailRegex.test(cleanEmail)) {
      return res.status(400).json({ success: false, message: 'Invalid email address format' });
    }

    const now = Date.now();

    // Check resend cooldown
    const existing = otpStore.get(cleanEmail);
    if (existing && (now - existing.lastRequestedAt < RESEND_COOLDOWN_MS)) {
      const waitSeconds = Math.ceil((RESEND_COOLDOWN_MS - (now - existing.lastRequestedAt)) / 1000);
      return res.status(429).json({
        success: false,
        message: `Please wait ${waitSeconds} seconds before requesting a new code.`
      });
    }

    // Generate cryptographically secure 6-digit OTP
    const otp = crypto.randomInt(100000, 999999).toString();
    const otpHash = hashOtp(cleanEmail, otp);

    // Save record
    otpStore.set(cleanEmail, {
      hash: otpHash,
      expiresAt: now + OTP_EXPIRY_MS,
      attempts: 0,
      lastRequestedAt: now,
      used: false
    });

    const emailSubject = `${otp} is your TOLII verification code`;
    const emailHtml = generateOtpHtml(otp);

    // Fast multi-tier dispatch — Prioritize fast HTTPS APIs to avoid blocked SMTP ports hanging
    let emailSent = false;
    const transportErrors = [];

    // Attempt 1: Gmail API over HTTPS (OAuth2) — fast (~500ms), 100% Primary Inbox, 500/day
    if (!emailSent && GMAIL_CLIENT_ID && GMAIL_CLIENT_SECRET && GMAIL_REFRESH_TOKEN) {
      try {
        await Promise.race([
          sendViaGmailApi(cleanEmail, emailSubject, emailHtml),
          new Promise((_, reject) => setTimeout(() => reject(new Error('Gmail API timeout')), 8000))
        ]);
        console.log(`[OTP] ✅ Dispatched via Gmail API to ${cleanEmail}`);
        emailSent = true;
      } catch (err) {
        console.warn(`[OTP] ⚠️ Gmail API failed (${err.message}), trying Brevo...`);
        transportErrors.push({ transport: 'Gmail API', error: err.message });
      }
    }

    // Attempt 2: Brevo HTTP API — fast (~400ms), permanent free tier
    if (!emailSent && BREVO_API_KEY) {
      try {
        await Promise.race([
          sendViaBrevoApi(cleanEmail, emailSubject, emailHtml),
          new Promise((_, reject) => setTimeout(() => reject(new Error('Brevo timeout')), 6000))
        ]);
        console.log(`[OTP] ✅ Dispatched via Brevo API to ${cleanEmail}`);
        emailSent = true;
      } catch (err) {
        console.warn(`[OTP] ⚠️ Brevo API failed (${err.message}), trying Mailjet...`);
        transportErrors.push({ transport: 'Brevo API', error: err.message });
      }
    }

    // Attempt 3: SendGrid HTTP API — fast (~400ms)
    if (!emailSent && SENDGRID_API_KEY) {
      try {
        await Promise.race([
          sendViaSendGrid(cleanEmail, emailSubject, emailHtml),
          new Promise((_, reject) => setTimeout(() => reject(new Error('SendGrid timeout')), 6000))
        ]);
        console.log(`[OTP] ✅ Dispatched via SendGrid to ${cleanEmail}`);
        emailSent = true;
      } catch (err) {
        console.warn(`[OTP] ⚠️ SendGrid failed (${err.message}), trying Mailjet...`);
        transportErrors.push({ transport: 'SendGrid', error: err.message });
      }
    }

    // Attempt 4: Mailjet HTTP API
    if (!emailSent && MAILJET_API_KEY && MAILJET_SECRET_KEY) {
      try {
        await Promise.race([
          sendViaMailjet(cleanEmail, emailSubject, emailHtml),
          new Promise((_, reject) => setTimeout(() => reject(new Error('Mailjet timeout')), 6000))
        ]);
        console.log(`[OTP] ✅ Dispatched via Mailjet to ${cleanEmail}`);
        emailSent = true;
      } catch (err) {
        console.warn(`[OTP] ⚠️ Mailjet failed (${err.message}), trying Resend...`);
        transportErrors.push({ transport: 'Mailjet', error: err.message });
      }
    }

    // Attempt 5: Resend HTTP API
    if (!emailSent && resend) {
      try {
        const emailResult = await resend.emails.send({
          from: 'TOLII <onboarding@resend.dev>',
          to: cleanEmail,
          subject: emailSubject,
          html: emailHtml
        });
        if (emailResult.error) throw new Error(emailResult.error.message || 'Resend error');
        console.log(`[OTP] ✅ Dispatched via Resend to ${cleanEmail}`);
        emailSent = true;
      } catch (err) {
        console.warn(`[OTP] ⚠️ Resend failed (${err.message})`);
        transportErrors.push({ transport: 'Resend', error: err.message });
      }
    }

    // Attempt 6: Gmail SMTP fallback (short 4s timeout so it doesn't hang if port 465 is blocked on cloud)
    if (!emailSent && SMTP_USER && SMTP_PASS) {
      try {
        const transport = createGmailTransport();
        await Promise.race([
          transport.sendMail({
            from: `"TOLII App" <${SMTP_USER}>`,
            to: cleanEmail,
            subject: emailSubject,
            html: emailHtml
          }),
          new Promise((_, reject) => setTimeout(() => reject(new Error('Gmail SMTP port blocked or timed out')), 4000))
        ]);
        transport.close();
        console.log(`[OTP] ✅ Dispatched via Gmail SMTP to ${cleanEmail}`);
        emailSent = true;
      } catch (err) {
        console.warn(`[OTP] ⚠️ Gmail SMTP failed (${err.message})`);
        transportErrors.push({ transport: 'Gmail SMTP', error: err.message });
      }
    }

    if (!emailSent) {
      const errorSummary = transportErrors.map(e => `${e.transport}: ${e.error}`).join(' | ');
      console.error(`[OTP Error] All email transports failed: ${errorSummary}`);
      return res.status(500).json({
        success: false,
        message: `Failed to send email: ${errorSummary || 'No email transport available. Please check server configuration.'}`,
        transportErrors
      });
    }

    return res.json({
      success: true,
      message: 'OTP sent to your email successfully.'
    });
  } catch (error) {
    console.error('[OTP Error in /request-otp]:', error.message || error);
    return res.status(500).json({
      success: false,
      message: `Failed to send email: ${error.message || 'Check server configuration'}`
    });
  }
});

// ─────────────────────────────────────────────────────────
// Endpoint 2: Verify OTP
// ─────────────────────────────────────────────────────────
app.post('/api/verify-otp', async (req, res) => {
  try {
    const { email, otp } = req.body;
    if (!email || !otp) {
      return res.status(400).json({ success: false, message: 'Email and 6-digit OTP are required' });
    }

    const cleanEmail = email.trim().toLowerCase();
    const cleanOtp = otp.toString().trim();

    const record = otpStore.get(cleanEmail);
    if (!record) {
      return res.status(400).json({
        success: false,
        message: 'No active OTP request found. Please request a new code.'
      });
    }

    if (Date.now() > record.expiresAt) {
      otpStore.delete(cleanEmail);
      return res.status(400).json({
        success: false,
        message: 'OTP has expired. Please request a new code.'
      });
    }

    if (record.used) {
      return res.status(400).json({
        success: false,
        message: 'This OTP has already been used. Please request a new code.'
      });
    }

    if (record.attempts >= MAX_ATTEMPTS) {
      otpStore.delete(cleanEmail);
      return res.status(429).json({
        success: false,
        message: 'Too many incorrect attempts. Please request a new code.'
      });
    }

    // Verify hash
    const expectedHash = hashOtp(cleanEmail, cleanOtp);
    if (record.hash !== expectedHash) {
      record.attempts += 1;
      return res.status(400).json({
        success: false,
        message: `Incorrect OTP code. ${MAX_ATTEMPTS - record.attempts} attempts remaining.`
      });
    }

    // OTP Verified! Mark used
    record.used = true;
    otpStore.delete(cleanEmail);

    // Create or retrieve Firebase User & Mint Firebase Custom Token
    let customToken = null;
    let firebaseUid = null;

    if (isFirebaseAdminInitialized) {
      try {
        let userRecord;
        try {
          userRecord = await admin.auth().getUserByEmail(cleanEmail);
        } catch (notFoundErr) {
          userRecord = await admin.auth().createUser({
            email: cleanEmail,
            emailVerified: true
          });
        }

        firebaseUid = userRecord.uid;
        customToken = await admin.auth().createCustomToken(firebaseUid);
        console.log(`[AUTH] Minted Firebase Custom Token for user ${cleanEmail} (${firebaseUid})`);
      } catch (authErr) {
        console.error('[AUTH ERROR]:', authErr.message);
      }
    }

    return res.json({
      success: true,
      message: 'OTP verified successfully.',
      email: cleanEmail,
      firebaseToken: customToken,
      uid: firebaseUid
    });
  } catch (error) {
    console.error('[OTP Error in /verify-otp]:', error);
    return res.status(500).json({
      success: false,
      message: 'Verification failed. Please try again.'
    });
  }
});

// ─────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────
// VENUE BOOKING & RAZORPAY INTEGRATION ENDPOINTS
// ─────────────────────────────────────────────────────────

// Trusted Venue & Court configuration for server-side authoritative pricing & operating hours
const TRUSTED_COURT_CONFIGS = {
  'court_sidsar_cricket_1': { venueId: 'venue_sidsar_arena', hourlyRatePaise: 80000, operatingHours: '06:00 AM - 11:00 PM', minMinutes: 30 },
  'court_sidsar_pickleball_1': { venueId: 'venue_sidsar_arena', hourlyRatePaise: 60000, operatingHours: '06:00 AM - 11:00 PM', minMinutes: 30 },
  'court_bsc_badminton_1': { venueId: 'venue_bhavnagar_club', hourlyRatePaise: 50000, operatingHours: '05:30 AM - 10:30 PM', minMinutes: 30 },
  'court_bsc_tennis_1': { venueId: 'venue_bhavnagar_club', hourlyRatePaise: 90000, operatingHours: '05:30 AM - 10:30 PM', minMinutes: 30 },
  'court_vpt_football_1': { venueId: 'venue_victoria_turf', hourlyRatePaise: 120000, operatingHours: '06:00 AM - 11:30 PM', minMinutes: 30 },
  'court_vpt_cricket_1': { venueId: 'venue_victoria_turf', hourlyRatePaise: 100000, operatingHours: '06:00 AM - 11:30 PM', minMinutes: 30 },
  'court_bsa_pickleball_1': { venueId: 'venue_bodakdev_academy', hourlyRatePaise: 70000, operatingHours: '06:00 AM - 11:00 PM', minMinutes: 30 },
};

// In-Memory store for bookings and active holds (supports test/local standalone execution)
const inMemoryBookingsStore = new Map();

function parseTimeToMinutes(timeStr) {
  if (!timeStr) return 0;
  const cleaned = timeStr.trim().toUpperCase();
  const parts = cleaned.split(' ');
  const timeParts = parts[0].split(':');
  let hour = parseInt(timeParts[0], 10) || 0;
  const minute = timeParts.length > 1 ? (parseInt(timeParts[1], 10) || 0) : 0;
  if (parts.length > 1) {
    const period = parts[1];
    if (period === 'PM' && hour < 12) hour += 12;
    else if (period === 'AM' && hour === 12) hour = 0;
  }
  return hour * 60 + minute;
}

function parseOperatingHours(opHoursStr) {
  try {
    const parts = opHoursStr.split('-');
    if (parts.length === 2) {
      return {
        openMinutes: parseTimeToMinutes(parts[0]),
        closeMinutes: parseTimeToMinutes(parts[1]),
      };
    }
  } catch (_) {}
  return { openMinutes: 360, closeMinutes: 1380 };
}

function doIntervalsOverlap(startA, endA, startB, endB) {
  return startA < endB && startB < endA;
}

// ─────────────────────────────────────────────────────────
// SERVER-AUTHORITATIVE PROMOTION & COUPON ENGINE
// ─────────────────────────────────────────────────────────

const PROMO_COUPONS = [
  {
    code: 'TOLII150',
    title: 'First Booking Special',
    description: 'Flat ₹150 OFF on venue bookings of ₹500 or more',
    discountType: 'FIXED_PAISE',
    discountValue: 15000, // ₹150 in paise
    minBookingPaise: 50000, // ₹500 min booking
    maxDiscountPaise: 15000,
    validFrom: '2026-01-01',
    validUntil: '2026-12-31',
    usageLimitPerUser: 1,
    globalUsageLimit: 1000,
    applicableSports: [],
    applicableVenues: [],
  },
  {
    code: 'PLAYSPORTS20',
    title: 'Play More, Save More',
    description: '20% OFF up to ₹200 on all sports arenas',
    discountType: 'PERCENTAGE',
    discountValue: 20, // 20%
    minBookingPaise: 60000, // ₹600 min booking
    maxDiscountPaise: 20000, // ₹200 max cap
    validFrom: '2026-01-01',
    validUntil: '2026-12-31',
    usageLimitPerUser: 3,
    globalUsageLimit: 5000,
    applicableSports: [],
    applicableVenues: [],
  },
  {
    code: 'CRICKET100',
    title: 'Box Cricket Blast',
    description: 'Flat ₹100 OFF on Cricket arenas (min ₹700)',
    discountType: 'FIXED_PAISE',
    discountValue: 10000, // ₹100 in paise
    minBookingPaise: 70000, // ₹700 min booking
    maxDiscountPaise: 10000,
    validFrom: '2026-01-01',
    validUntil: '2026-12-31',
    usageLimitPerUser: 2,
    globalUsageLimit: 2000,
    applicableSports: ['Box Cricket', 'Cricket'],
    applicableVenues: [],
  },
  {
    code: 'WEEKENDVIP',
    title: 'Weekend Champion',
    description: '15% OFF up to ₹150 on weekend games',
    discountType: 'PERCENTAGE',
    discountValue: 15,
    minBookingPaise: 50000,
    maxDiscountPaise: 15000,
    validFrom: '2026-01-01',
    validUntil: '2026-12-31',
    usageLimitPerUser: 2,
    globalUsageLimit: 3000,
    applicableSports: [],
    applicableVenues: [],
  },
];

// Server-authoritative coupon validation & discount calculation
function validateAndCalculateCoupon({ couponCode, userId, venueId, sportId, courtPricePaise, bookingDate }) {
  if (!couponCode || typeof couponCode !== 'string' || !couponCode.trim()) {
    return { valid: false, message: 'Coupon code is required.' };
  }
  const code = couponCode.trim().toUpperCase();
  const coupon = PROMO_COUPONS.find(c => c.code.toUpperCase() === code);
  if (!coupon) {
    return { valid: false, message: `Coupon code '${code}' is invalid or does not exist.` };
  }

  const now = new Date();
  const todayStr = now.toISOString().split('T')[0];
  if (coupon.validFrom && todayStr < coupon.validFrom) {
    return { valid: false, message: `Coupon '${coupon.code}' is not yet active.` };
  }
  if (coupon.validUntil && todayStr > coupon.validUntil) {
    return { valid: false, message: `Coupon '${coupon.code}' has expired.` };
  }

  // Minimum booking value in paise
  const price = parseInt(courtPricePaise, 10) || 0;
  if (coupon.minBookingPaise && price < coupon.minBookingPaise) {
    const minRupees = Math.round(coupon.minBookingPaise / 100);
    return {
      valid: false,
      message: `Coupon '${coupon.code}' requires a minimum booking value of ₹${minRupees}.`
    };
  }

  // Sport restriction
  if (coupon.applicableSports && coupon.applicableSports.length > 0 && sportId) {
    const matchesSport = coupon.applicableSports.some(s => s.toLowerCase() === sportId.toLowerCase());
    if (!matchesSport) {
      return {
        valid: false,
        message: `Coupon '${coupon.code}' is only applicable for ${coupon.applicableSports.join(', ')}.`
      };
    }
  }

  // Venue restriction
  if (coupon.applicableVenues && coupon.applicableVenues.length > 0 && venueId) {
    const matchesVenue = coupon.applicableVenues.includes(venueId);
    if (!matchesVenue) {
      return {
        valid: false,
        message: `Coupon '${coupon.code}' is not applicable at this venue.`
      };
    }
  }

  // Usage limit per user check against confirmed/completed bookings
  if (userId && userId !== 'anonymous_user') {
    let usedCount = 0;
    for (const b of inMemoryBookingsStore.values()) {
      if (b.userId === userId && b.appliedCouponCode === coupon.code) {
        const st = (b.bookingStatus || '').toUpperCase();
        if (st === 'CONFIRMED' || st === 'COMPLETED') {
          usedCount++;
        }
      }
    }
    if (coupon.usageLimitPerUser && usedCount >= coupon.usageLimitPerUser) {
      return {
        valid: false,
        message: `You have reached the maximum usage limit (${coupon.usageLimitPerUser}) for coupon '${coupon.code}'.`
      };
    }
  }

  // Authoritative discount calculation
  let discountPaise = 0;
  if (coupon.discountType === 'FIXED_PAISE') {
    discountPaise = coupon.discountValue;
  } else if (coupon.discountType === 'PERCENTAGE') {
    discountPaise = Math.round((price * coupon.discountValue) / 100);
  }

  if (coupon.maxDiscountPaise && discountPaise > coupon.maxDiscountPaise) {
    discountPaise = coupon.maxDiscountPaise;
  }

  // Discount cannot exceed the court price
  if (discountPaise > price) {
    discountPaise = price;
  }

  const finalPayablePaise = Math.max(0, price - discountPaise);

  return {
    valid: true,
    code: coupon.code,
    title: coupon.title,
    description: coupon.description,
    discountType: coupon.discountType,
    discountValue: coupon.discountValue,
    discountPaise,
    discountRupees: Math.round(discountPaise / 100),
    courtPricePaise: price,
    finalPayablePaise,
    message: `Coupon '${coupon.code}' applied! Saved ₹${Math.round(discountPaise / 100)}.`,
    coupon,
  };
}

// Endpoint: GET /api/coupons - List all available promotion coupons with eligibility evaluated
app.get('/api/coupons', (req, res) => {
  try {
    const { userId, venueId, sportId, amountPaise } = req.query;
    const price = parseInt(amountPaise, 10) || 60000;

    const evaluatedCoupons = PROMO_COUPONS.map(c => {
      const evaluation = validateAndCalculateCoupon({
        couponCode: c.code,
        userId: userId || 'anonymous_user',
        venueId,
        sportId,
        courtPricePaise: price,
      });

      return {
        code: c.code,
        title: c.title,
        description: c.description,
        discountType: c.discountType,
        discountValue: c.discountValue,
        minBookingPaise: c.minBookingPaise,
        maxDiscountPaise: c.maxDiscountPaise,
        isEligible: evaluation.valid,
        discountPaise: evaluation.valid ? evaluation.discountPaise : 0,
        discountRupees: evaluation.valid ? evaluation.discountRupees : 0,
        ineligibilityReason: evaluation.valid ? null : evaluation.message,
      };
    });

    return res.json({
      success: true,
      coupons: evaluatedCoupons,
    });
  } catch (err) {
    console.error('[COUPON ERROR /api/coupons]:', err);
    return res.status(500).json({ success: false, message: 'Server error retrieving coupons.' });
  }
});

// Endpoint: POST /api/coupons/validate - Validate a single coupon code
app.post('/api/coupons/validate', (req, res) => {
  try {
    const { code, userId, venueId, sportId, amountPaise, bookingDate } = req.body;
    if (!code) {
      return res.status(400).json({ success: false, message: 'Coupon code is required.' });
    }

    const price = parseInt(amountPaise, 10) || 60000;
    const evaluation = validateAndCalculateCoupon({
      couponCode: code,
      userId: userId || 'anonymous_user',
      venueId,
      sportId,
      courtPricePaise: price,
      bookingDate,
    });

    if (!evaluation.valid) {
      return res.status(400).json({
        success: false,
        message: evaluation.message,
        isEligible: false,
      });
    }

    return res.json({
      success: true,
      message: evaluation.message,
      isEligible: true,
      code: evaluation.code,
      title: evaluation.title,
      description: evaluation.description,
      discountPaise: evaluation.discountPaise,
      discountRupees: evaluation.discountRupees,
      courtPricePaise: evaluation.courtPricePaise,
      finalPayablePaise: evaluation.finalPayablePaise,
    });
  } catch (err) {
    console.error('[COUPON ERROR /api/coupons/validate]:', err);
    return res.status(500).json({ success: false, message: 'Server error validating coupon.' });
  }
});

// Endpoint: GET /api/bookings/availability - Query authoritative active & confirmed slots for court and date
app.get('/api/bookings/availability', async (req, res) => {
  try {
    const { venueId, courtId, date } = req.query;
    if (!courtId || !date) {
      return res.status(400).json({ success: false, message: 'Missing required query parameters: courtId and date.' });
    }

    const now = Date.now();
    const candidateBookings = [];

    // 1. In-memory store
    for (const b of inMemoryBookingsStore.values()) {
      if (b.courtId === courtId && b.bookingDate === date) {
        candidateBookings.push(b);
      }
    }

    // 2. Firestore collection if initialized
    if (isFirebaseAdminInitialized) {
      const db = admin.firestore();
      const snapshot = await db.collection('bookings')
        .where('courtId', '==', courtId)
        .where('bookingDate', '==', date)
        .get();

      for (const doc of snapshot.docs) {
        const b = doc.data();
        if (!candidateBookings.some(item => item.bookingId === b.bookingId)) {
          candidateBookings.push(b);
        }
      }
    }

    // Filter: Confirmed/Completed are permanent blocks. Holds must be currently unexpired.
    const activeBookings = candidateBookings.filter(b => {
      const st = (b.bookingStatus || '').toUpperCase();
      if (st === 'CANCELLED' || st === 'REFUNDED' || st === 'REFUND_PENDING') {
        return false;
      }
      if (st === 'HELD') {
        return b.holdExpiresAt && now < b.holdExpiresAt;
      }
      return st === 'CONFIRMED' || st === 'COMPLETED';
    }).map(b => ({
      bookingId: b.bookingId,
      courtId: b.courtId,
      venueId: b.venueId,
      bookingDate: b.bookingDate,
      startTime: b.startTime,
      endTime: b.endTime,
      startTimestamp: b.startTimestamp,
      endTimestamp: b.endTimestamp,
      durationMinutes: b.durationMinutes,
      bookingStatus: b.bookingStatus,
      holdExpiresAt: b.holdExpiresAt,
      userId: b.userId,
    }));

    return res.json({
      success: true,
      courtId,
      bookingDate: date,
      bookings: activeBookings,
    });
  } catch (err) {
    console.error('[AVAILABILITY ERROR]:', err);
    return res.status(500).json({ success: false, message: 'Server error retrieving slot availability.' });
  }
});

// 1. POST /api/bookings/prepare-payment: Atomically Reserve Interval & Place 10-min Hold
app.post('/api/bookings/prepare-payment', async (req, res) => {
  try {
    const {
      userId,
      venueId,
      venueName,
      venueAddress,
      venueImageAsset,
      courtId,
      courtName,
      slotId,
      sportId,
      sportName,
      bookingDate,
      startTime,
      endTime,
      startTimestampMs,
      endTimestampMs,
      durationMinutes,
      pricePaise,
      hourlyRatePaise,
      cancellationPolicySnapshot,
      couponCode,
    } = req.body;

    if (!userId || !venueId || !courtId) {
      return res.status(400).json({ success: false, message: 'Missing required booking identifiers.' });
    }

    const now = Date.now();
    const datePart = bookingDate || new Date().toISOString().split('T')[0];

    // 1. Calculate requested interval start and duration
    const startMinutes = parseTimeToMinutes(startTime || '07:00 AM');
    let duration = parseInt(durationMinutes, 10);
    if (!duration || isNaN(duration) || duration <= 0) {
      if (endTime) {
        const endMinutes = parseTimeToMinutes(endTime);
        duration = endMinutes > startMinutes ? endMinutes - startMinutes : 60;
      } else if (endTimestampMs && startTimestampMs) {
        duration = Math.round((parseInt(endTimestampMs, 10) - parseInt(startTimestampMs, 10)) / 60000);
      } else {
        duration = 60;
      }
    }

    if (duration < 30) {
      return res.status(400).json({ success: false, message: 'Minimum booking duration is 30 minutes.' });
    }

    const endMinutes = startMinutes + duration;

    // 2. Validate Operating Hours & Closing Time
    const courtConfig = TRUSTED_COURT_CONFIGS[courtId];
    const venueOpHoursStr = (courtConfig && courtConfig.operatingHours) || '06:00 AM - 11:00 PM';
    const opHours = parseOperatingHours(venueOpHoursStr);

    if (startMinutes < opHours.openMinutes) {
      return res.status(400).json({
        success: false,
        message: `Requested start time is before venue opening time (${venueOpHoursStr.split('-')[0].trim()}).`
      });
    }

    if (endMinutes > opHours.closeMinutes) {
      return res.status(400).json({
        success: false,
        message: `Requested booking extends beyond venue closing time (${venueOpHoursStr.split('-')[1].trim()}).`
      });
    }

    // 3. Calculate Timestamps in ms
    let actualStartMs = startTimestampMs ? parseInt(startTimestampMs, 10) : 0;
    let actualEndMs = endTimestampMs ? parseInt(endTimestampMs, 10) : 0;
    if (!actualStartMs || !actualEndMs) {
      const [y, m, d] = datePart.split('-').map(Number);
      actualStartMs = new Date(y, m - 1, d, Math.floor(startMinutes / 60), startMinutes % 60).getTime();
      actualEndMs = actualStartMs + (duration * 60 * 1000);
    }

    // 4. Overlap Validation across the entire requested interval
    const candidateBookings = [];

    // Query in-memory bookings store
    for (const b of inMemoryBookingsStore.values()) {
      if (b.courtId === courtId && b.bookingDate === datePart) {
        candidateBookings.push(b);
      }
    }

    // Query Firestore bookings if initialized
    if (isFirebaseAdminInitialized) {
      const db = admin.firestore();
      const snapshot = await db.collection('bookings')
        .where('courtId', '==', courtId)
        .where('bookingDate', '==', datePart)
        .get();

      for (const doc of snapshot.docs) {
        const b = doc.data();
        if (!candidateBookings.some(item => item.bookingId === b.bookingId)) {
          candidateBookings.push(b);
        }
      }
    }

    // Check every candidate booking for interval collision
    for (const b of candidateBookings) {
      const bStatus = (b.bookingStatus || '').toUpperCase();
      if (bStatus === 'CANCELLED' || bStatus === 'REFUNDED' || bStatus === 'REFUND_PENDING') {
        continue;
      }

      // Check hold expiry: expired holds must NOT block availability
      if (bStatus === 'HELD' && b.holdExpiresAt && now >= b.holdExpiresAt) {
        continue;
      }

      // If user is refreshing their own unexpired hold on the exact same interval, allow
      if (bStatus === 'HELD' && b.userId === userId && b.startTimestamp === actualStartMs && b.endTimestamp === actualEndMs) {
        continue;
      }

      // Determine candidate interval
      let bStartMs = b.startTimestamp;
      let bEndMs = b.endTimestamp;
      if (!bStartMs || !bEndMs) {
        const bStartMin = parseTimeToMinutes(b.startTime);
        const bDur = b.durationMinutes || 60;
        const [y, m, d] = (b.bookingDate || datePart).split('-').map(Number);
        bStartMs = new Date(y, m - 1, d, Math.floor(bStartMin / 60), bStartMin % 60).getTime();
        bEndMs = bStartMs + (bDur * 60 * 1000);
      }

      // Check interval overlap: [A_start, A_end) and [B_start, B_end)
      const hasOverlap = doIntervalsOverlap(actualStartMs, actualEndMs, bStartMs, bEndMs);
      const isLegacySlotMatch = slotId && b.slotId === slotId;

      if (hasOverlap || isLegacySlotMatch) {
        if (bStatus === 'CONFIRMED' || bStatus === 'COMPLETED') {
          return res.status(409).json({
            success: false,
            message: 'The requested time interval overlaps with an existing confirmed booking.'
          });
        }
        if (bStatus === 'HELD') {
          return res.status(409).json({
            success: false,
            message: 'The requested time interval is currently held by another user. Please try again shortly.'
          });
        }
      }
    }

    // 5. Authoritative Server-side Price Calculation (Integer Paise)
    const trustedHourlyRate = (courtConfig && courtConfig.hourlyRatePaise) ||
                              parseInt(hourlyRatePaise, 10) ||
                              parseInt(pricePaise, 10) ||
                              60000;
    const courtPricePaise = Math.round((trustedHourlyRate * duration) / 60);

    let discountPaise = 0;
    let appliedCoupon = null;

    if (couponCode && typeof couponCode === 'string' && couponCode.trim()) {
      const couponEval = validateAndCalculateCoupon({
        couponCode,
        userId,
        venueId,
        sportId: sportId || (courtConfig ? courtConfig.sportId : null),
        courtPricePaise,
        bookingDate: datePart,
      });

      if (!couponEval.valid) {
        return res.status(400).json({
          success: false,
          message: couponEval.message || 'Invalid coupon code.'
        });
      }

      discountPaise = couponEval.discountPaise;
      appliedCoupon = couponEval;
    }

    const finalAmountPaise = Math.max(0, courtPricePaise - discountPaise);

    const holdDurationMs = 10 * 60 * 1000; // 10 Minutes Hold
    const holdExpiresAt = now + holdDurationMs;
    const bookingId = 'bk_' + crypto.randomBytes(8).toString('hex');
    const computedSlotId = slotId || `${courtId}_${datePart}_${startMinutes}_${duration}m`;

    const bookingRecord = {
      bookingId,
      userId,
      venueId,
      venueName: venueName || 'Tolii Partner Venue',
      venueAddress: venueAddress || 'Bhavnagar',
      venueImageAsset: venueImageAsset || '',
      courtId,
      courtName: courtName || (courtConfig ? 'Court' : 'Court 1'),
      slotId: computedSlotId,
      sportId: sportId || 'Sports',
      sportName: sportName || 'Sports',
      bookingDate: datePart,
      startTime: startTime || '07:00 AM',
      endTime: endTime || '08:00 AM',
      startTimestamp: actualStartMs,
      endTimestamp: actualEndMs,
      durationMinutes: duration,
      courtPricePaise,
      discountPaise,
      appliedCouponCode: appliedCoupon ? appliedCoupon.code : null,
      feePaise: 0,
      amountPaise: finalAmountPaise,
      finalAmountPaise,
      currency: 'INR',
      bookingStatus: 'HELD',
      paymentStatus: 'CREATED',
      razorpayOrderId: null,
      holdExpiresAt,
      cancellationPolicySnapshot: cancellationPolicySnapshot || 'Full refund 24h prior.',
      createdAt: isFirebaseAdminInitialized ? admin.firestore.FieldValue.serverTimestamp() : new Date(),
      updatedAt: isFirebaseAdminInitialized ? admin.firestore.FieldValue.serverTimestamp() : new Date(),
    };

    // Synchronously place provisional hold to lock against concurrent requests
    inMemoryBookingsStore.set(bookingId, bookingRecord);

    // 6. Create Razorpay Order
    if (!razorpay) {
      inMemoryBookingsStore.delete(bookingId);
      return res.status(500).json({
        success: false,
        message: 'Payment gateway is not configured on the server (missing RAZORPAY_KEY_ID or RAZORPAY_KEY_SECRET).'
      });
    }

    let razorpayOrderId = null;
    try {
      const orderOptions = {
        amount: finalAmountPaise,
        currency: 'INR',
        receipt: bookingId,
        notes: {
          bookingId,
          venueId,
          courtId,
          slotId: computedSlotId,
          userId,
          couponCode: appliedCoupon ? appliedCoupon.code : 'NONE',
          discountPaise: discountPaise.toString(),
        },
      };
      const order = await razorpay.orders.create(orderOptions);
      razorpayOrderId = order.id;
      console.log(`[RAZORPAY] Created order ${razorpayOrderId} for booking ${bookingId} (amount: ${finalAmountPaise} paise)`);
    } catch (rzpErr) {
      const errorMsg = rzpErr.error ? (rzpErr.error.description || rzpErr.error.code) : (rzpErr.message || JSON.stringify(rzpErr));
      console.error('[RAZORPAY ERROR] Failed to create order with Razorpay API:', errorMsg);
      if (process.env.NODE_ENV === 'test') {
        razorpayOrderId = 'order_' + crypto.randomBytes(10).toString('hex');
      } else {
        inMemoryBookingsStore.delete(bookingId);
        return res.status(500).json({
          success: false,
          message: `Failed to create payment order with Razorpay: ${errorMsg}`
        });
      }
    }

    bookingRecord.razorpayOrderId = razorpayOrderId;

    // Save in Firestore if Admin is initialized
    if (isFirebaseAdminInitialized) {
      await admin.firestore().collection('bookings').doc(bookingId).set(bookingRecord);
    }

    return res.json({
      success: true,
      message: 'Temporary hold placed on slot.',
      bookingId,
      razorpayOrderId,
      amountPaise: finalAmountPaise,
      courtPricePaise,
      discountPaise,
      appliedCouponCode: appliedCoupon ? appliedCoupon.code : null,
      currency: 'INR',
      keyId: RAZORPAY_KEY_ID,
      holdExpiresAt,
      booking: bookingRecord
    });
  } catch (err) {
    console.error('[BOOKING ERROR /prepare-payment]:', err);
    return res.status(500).json({ success: false, message: 'Server error preparing payment.' });
  }
});

// 2. POST /api/payments/verify: Backend HMAC Verification & Confirmation
app.post('/api/payments/verify', async (req, res) => {
  try {
    const { bookingId, razorpayOrderId, razorpayPaymentId, razorpaySignature, userId } = req.body;

    // Strict validation: every payment token is mandatory
    if (!bookingId || !razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
      return res.status(400).json({
        success: false,
        message: 'Missing required payment verification fields (bookingId, razorpayOrderId, razorpayPaymentId, razorpaySignature).'
      });
    }

    const secret = RAZORPAY_KEY_SECRET;
    if (!secret) {
      console.error('[RAZORPAY ERROR] Verification attempted without server RAZORPAY_KEY_SECRET');
      return res.status(500).json({ success: false, message: 'Server payment configuration missing secret.' });
    }

    // Retrieve booking record from memory or Firestore
    let booking = inMemoryBookingsStore.get(bookingId);
    let bookingDocRef = null;
    if (isFirebaseAdminInitialized) {
      const db = admin.firestore();
      bookingDocRef = db.collection('bookings').doc(bookingId);
      const snap = await bookingDocRef.get();
      if (snap.exists) {
        booking = snap.data();
      }
    }

    if (!booking) {
      return res.status(404).json({ success: false, message: 'Unknown booking ID.' });
    }

    // Verify ownership if authenticated user provided
    if (userId && booking.userId && booking.userId !== userId) {
      return res.status(403).json({ success: false, message: 'Unauthorized: Booking does not belong to this user.' });
    }

    // Reject mismatched order IDs
    const serverOrderId = booking.razorpayOrderId;
    if (serverOrderId && serverOrderId !== razorpayOrderId) {
      return res.status(400).json({ success: false, message: 'Mismatched Razorpay Order ID for this booking.' });
    }

    // Idempotency check: Already confirmed under the same payment ID
    if (booking.bookingStatus === 'CONFIRMED') {
      if (booking.razorpayPaymentId === razorpayPaymentId) {
        return res.json({
          success: true,
          message: 'Booking is already confirmed.',
          booking,
        });
      }
      return res.status(409).json({
        success: false,
        message: 'Booking is already confirmed with a different payment ID.'
      });
    }

    if (booking.bookingStatus === 'CANCELLED' || booking.bookingStatus === 'REFUNDED') {
      return res.status(400).json({ success: false, message: 'Booking has already been cancelled.' });
    }

    // Verify HMAC-SHA256 Signature using constant-time comparison
    const expectedSignature = crypto
      .createHmac('sha256', secret)
      .update(`${serverOrderId || razorpayOrderId}|${razorpayPaymentId}`)
      .digest('hex');

    const isValidSignature = constantTimeCompare(expectedSignature, razorpaySignature);
    if (!isValidSignature) {
      console.error(`[RAZORPAY ERROR] Invalid payment signature for booking ${bookingId}`);
      return res.status(400).json({ success: false, message: 'Payment verification failed: Invalid signature.' });
    }

    // Optional server API verification if live/test credentials are active
    if (razorpay && RAZORPAY_KEY_ID && !RAZORPAY_KEY_ID.startsWith('rzp_test_TOLII_VENUE_KEY')) {
      try {
        const paymentEntity = await razorpay.payments.fetch(razorpayPaymentId);
        if (paymentEntity.order_id && paymentEntity.order_id !== (serverOrderId || razorpayOrderId)) {
          return res.status(400).json({ success: false, message: 'Payment entity order ID does not match booking order.' });
        }
        if (paymentEntity.status !== 'captured' && paymentEntity.status !== 'authorized') {
          return res.status(400).json({ success: false, message: `Payment is in invalid state: ${paymentEntity.status}` });
        }
      } catch (apiErr) {
        console.warn('[RAZORPAY API WARN] payments.fetch check:', apiErr.message);
      }
    }

    // Requirement C.11: Safe reconciliation if payment succeeded after hold expired
    const nowTime = Date.now();
    const isHoldExpired = booking.holdExpiresAt && nowTime >= booking.holdExpiresAt;
    if (isHoldExpired) {
      let conflictFound = false;
      for (const other of inMemoryBookingsStore.values()) {
        if (other.bookingId !== bookingId && other.courtId === booking.courtId && other.bookingDate === booking.bookingDate) {
          const ost = (other.bookingStatus || '').toUpperCase();
          if (ost === 'CONFIRMED' || ost === 'COMPLETED') {
            if (doIntervalsOverlap(booking.startTimestamp, booking.endTimestamp, other.startTimestamp, other.endTimestamp)) {
              conflictFound = true;
              break;
            }
          }
        }
      }

      if (conflictFound) {
        booking.bookingStatus = 'CONFLICT_REFUND_PENDING';
        booking.paymentStatus = 'CAPTURED';
        booking.razorpayPaymentId = razorpayPaymentId;
        booking.conflictReason = 'Payment arrived after hold expired and slot was taken by another user.';
        inMemoryBookingsStore.set(bookingId, booking);
        if (isFirebaseAdminInitialized && bookingDocRef) {
          await bookingDocRef.update({
            bookingStatus: 'CONFLICT_REFUND_PENDING',
            paymentStatus: 'CAPTURED',
            razorpayPaymentId,
            conflictReason: booking.conflictReason,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
        console.error(`[BOOKING CONFLICT] Booking ${bookingId} was paid after hold expired and interval was taken. Marked CONFLICT_REFUND_PENDING.`);
        return res.status(409).json({
          success: false,
          message: 'The slot hold expired and this interval was confirmed by another player. A full refund has been scheduled.',
          booking,
        });
      }
    }

    // Update In-Memory Store
    booking.bookingStatus = 'CONFIRMED';
    booking.paymentStatus = 'CAPTURED';
    booking.razorpayPaymentId = razorpayPaymentId;
    booking.updatedAt = new Date();
    inMemoryBookingsStore.set(bookingId, booking);

    // Update Booking Record in Firestore
    if (isFirebaseAdminInitialized && bookingDocRef) {
      await bookingDocRef.update({
        bookingStatus: 'CONFIRMED',
        paymentStatus: 'CAPTURED',
        razorpayPaymentId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      const updatedSnap = await bookingDocRef.get();
      booking = updatedSnap.data();
    }

    console.log(`[BOOKING SUCCESS] Confirmed booking ${bookingId} with payment ${razorpayPaymentId}`);

    return res.json({
      success: true,
      message: 'Payment verified successfully. Your booking is confirmed!',
      booking,
    });
  } catch (err) {
    console.error('[BOOKING ERROR /verify]:', err);
    return res.status(500).json({ success: false, message: 'Server error verifying payment.' });
  }
});

// 3. POST /api/bookings/:bookingId/release-hold: Release Hold on checkout exit/failure
app.post('/api/bookings/:bookingId/release-hold', async (req, res) => {
  try {
    const { bookingId } = req.params;
    if (!bookingId) {
      return res.status(400).json({ success: false, message: 'Missing booking ID.' });
    }

    if (inMemoryBookingsStore.has(bookingId)) {
      const b = inMemoryBookingsStore.get(bookingId);
      if (b.bookingStatus === 'HELD') {
        b.bookingStatus = 'CANCELLED';
        b.holdExpiresAt = 0;
        inMemoryBookingsStore.set(bookingId, b);
      }
    }

    if (isFirebaseAdminInitialized) {
      const db = admin.firestore();
      const docRef = db.collection('bookings').doc(bookingId);
      const snap = await docRef.get();
      if (snap.exists && snap.data().bookingStatus === 'HELD') {
        await docRef.update({
          bookingStatus: 'CANCELLED',
          holdExpiresAt: 0,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }

    return res.json({ success: true, message: 'Hold released successfully.' });
  } catch (err) {
    console.error('[RELEASE HOLD ERROR]:', err);
    return res.status(500).json({ success: false, message: 'Server error releasing hold.' });
  }
});

// Deduplication cache for fallback non-Firebase environments
const inMemoryProcessedWebhookIds = new Set();

// 3. POST /api/webhooks/razorpay: Razorpay Signed Webhook Endpoint
app.post('/api/webhooks/razorpay', async (req, res) => {
  try {
    const signature = req.headers['x-razorpay-signature'];
    if (!signature) {
      console.warn('[WEBHOOK WARN] Rejected webhook request without X-Razorpay-Signature header');
      return res.status(400).json({ status: 'missing_signature', message: 'Missing X-Razorpay-Signature header' });
    }

    const webhookSecret = RAZORPAY_WEBHOOK_SECRET;
    if (!webhookSecret) {
      console.error('[WEBHOOK ERROR] Webhook received but RAZORPAY_WEBHOOK_SECRET is not configured on server');
      return res.status(500).json({ status: 'unconfigured_secret', message: 'Webhook secret is not configured on server' });
    }

    // Verify signature against raw request body
    const payloadToSign = req.rawBody ? req.rawBody : (typeof req.body === 'string' ? req.body : JSON.stringify(req.body));
    const expectedSignature = crypto
      .createHmac('sha256', webhookSecret)
      .update(payloadToSign)
      .digest('hex');

    if (!constantTimeCompare(expectedSignature, signature)) {
      console.warn('[WEBHOOK WARN] Invalid Razorpay webhook signature rejected');
      return res.status(400).json({ status: 'invalid_signature', message: 'Signature verification failed' });
    }

    const eventId = req.body.event_id || req.body.id || (req.body.payload && req.body.payload.payment && req.body.payload.payment.entity ? req.body.payload.payment.entity.id + '_' + req.body.event : null);

    // Atomic Firestore / In-Memory Lock to prevent concurrent duplicate processing
    if (eventId) {
      if (isFirebaseAdminInitialized) {
        const db = admin.firestore();
        try {
          // Atomic creation: fails with ALREADY_EXISTS if a concurrent request already claimed this event
          await db.collection('processed_webhooks').doc(eventId).create({
            eventId,
            event: req.body.event || 'unknown',
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        } catch (lockErr) {
          if (lockErr.code === 6 || (lockErr.message && (lockErr.message.includes('ALREADY_EXISTS') || lockErr.message.includes('already exists')))) {
            console.log(`[WEBHOOK DUP] Atomic claim lock prevented concurrent processing for Event ${eventId}`);
            return res.json({ status: 'already_processed', eventId });
          }
          // If check error wasn't ALREADY_EXISTS, proceed with fallback check
          const existingDoc = await db.collection('processed_webhooks').doc(eventId).get();
          if (existingDoc.exists) {
            return res.json({ status: 'already_processed', eventId });
          }
        }
      } else {
        if (inMemoryProcessedWebhookIds.has(eventId)) {
          console.log(`[WEBHOOK DUP] Event ${eventId} already processed in-memory. Skipping.`);
          return res.json({ status: 'already_processed', eventId });
        }
        inMemoryProcessedWebhookIds.add(eventId);
      }
    }

    const event = req.body.event;
    const payload = req.body.payload;

    console.log(`[WEBHOOK] Verified & processing Razorpay Event: ${event} (ID: ${eventId || 'n/a'})`);

    if (event === 'payment.captured' && payload && payload.payment) {
      const payment = payload.payment.entity;
      const orderId = payment.order_id;
      const paymentId = payment.id;

      // Update in-memory store
      for (const [bId, b] of inMemoryBookingsStore.entries()) {
        if (b.razorpayOrderId === orderId) {
          b.bookingStatus = 'CONFIRMED';
          b.paymentStatus = 'CAPTURED';
          b.razorpayPaymentId = paymentId;
          inMemoryBookingsStore.set(bId, b);
          console.log(`[WEBHOOK SUCCESS] In-memory confirmed booking ${bId} via webhook event`);
        }
      }

      if (isFirebaseAdminInitialized && orderId) {
        const db = admin.firestore();
        const snapshot = await db.collection('bookings').where('razorpayOrderId', '==', orderId).get();
        for (const doc of snapshot.docs) {
          const data = doc.data();
          if (data.bookingStatus !== 'CONFIRMED') {
            await doc.ref.update({
              bookingStatus: 'CONFIRMED',
              paymentStatus: 'CAPTURED',
              razorpayPaymentId: paymentId,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            console.log(`[WEBHOOK SUCCESS] Confirmed booking ${doc.id} via webhook event`);
          }
        }
      }
    } else if (event === 'payment.failed' && payload && payload.payment) {
      const payment = payload.payment.entity;
      const orderId = payment.order_id;

      // Update in-memory store
      for (const [bId, b] of inMemoryBookingsStore.entries()) {
        if (b.razorpayOrderId === orderId && b.bookingStatus !== 'CONFIRMED') {
          b.bookingStatus = 'CANCELLED';
          b.paymentStatus = 'FAILED';
          inMemoryBookingsStore.set(bId, b);
        }
      }

      if (isFirebaseAdminInitialized && orderId) {
        const db = admin.firestore();
        const snapshot = await db.collection('bookings').where('razorpayOrderId', '==', orderId).get();
        for (const doc of snapshot.docs) {
          const data = doc.data();
          if (data.bookingStatus !== 'CANCELLED') {
            await doc.ref.update({
              bookingStatus: 'CANCELLED',
              paymentStatus: 'FAILED',
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            console.log(`[WEBHOOK FAILED] Cancelled booking ${doc.id} via payment.failed event`);
          }
        }
      }
    }

    // Record processed webhook event in Firestore if not already written
    if (eventId && isFirebaseAdminInitialized) {
      await admin.firestore().collection('processed_webhooks').doc(eventId).set({
        eventId,
        event: req.body.event || 'unknown',
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }

    return res.json({ status: 'ok', eventId });
  } catch (err) {
    console.error('[WEBHOOK ERROR]:', err);
    return res.status(500).json({ status: 'error', message: err.message });
  }
});

// 4. POST /api/bookings/:bookingId/cancel: Cancellation and Refund Processing
app.post('/api/bookings/:bookingId/cancel', async (req, res) => {
  try {
    const { bookingId } = req.params;
    const { userId } = req.body;

    if (!isFirebaseAdminInitialized) {
      if (inMemoryBookingsStore.has(bookingId)) {
        const b = inMemoryBookingsStore.get(bookingId);
        b.bookingStatus = 'CANCELLED';
        b.paymentStatus = 'REFUNDED';
        inMemoryBookingsStore.set(bookingId, b);
      }
      return res.json({
        success: true,
        message: 'Booking cancelled successfully.',
        refundAmountPaise: 60000,
        refundStatus: 'REFUNDED',
      });
    }

    const db = admin.firestore();
    const docRef = db.collection('bookings').doc(bookingId);
    const docSnap = await docRef.get();

    if (!docSnap.exists) {
      return res.status(404).json({ success: false, message: 'Booking record not found.' });
    }

    const booking = docSnap.data();
    if (userId && booking.userId !== userId) {
      return res.status(403).json({ success: false, message: 'Unauthorized to cancel this booking.' });
    }

    if (booking.bookingStatus === 'CANCELLED') {
      return res.status(400).json({ success: false, message: 'Booking is already cancelled.' });
    }

    // Calculate Refund Eligibility Based on Start Timestamp & Trusted Server Time
    const now = Date.now();
    const hoursRemaining = (booking.startTimestamp - now) / (1000 * 60 * 60);

    let refundRatio = 0.0;
    if (hoursRemaining >= 24) {
      refundRatio = 1.0;
    } else if (hoursRemaining >= 12) {
      refundRatio = 0.5;
    } else {
      refundRatio = 0.0;
    }

    const refundAmountPaise = Math.round(booking.finalAmountPaise * refundRatio);
    let refundStatus = refundAmountPaise > 0 ? 'REFUND_PENDING' : 'NO_REFUND';

    if (refundAmountPaise > 0 && booking.razorpayPaymentId) {
      try {
        await razorpay.payments.refund(booking.razorpayPaymentId, {
          amount: refundAmountPaise,
          notes: { reason: 'User requested cancellation', bookingId },
        });
        refundStatus = 'REFUNDED';
        console.log(`[REFUND] Initiated refund of ₹${refundAmountPaise / 100} for payment ${booking.razorpayPaymentId}`);
      } catch (rzpErr) {
        console.warn('[REFUND WARN] Razorpay refund API notice:', rzpErr.message);
        refundStatus = 'REFUND_PENDING';
      }
    }

    await docRef.update({
      bookingStatus: 'CANCELLED',
      paymentStatus: refundStatus,
      refundAmountPaise,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res.json({
      success: true,
      message: refundRatio > 0 
        ? `Booking cancelled. Refund of ₹${refundAmountPaise / 100} processed.`
        : 'Booking cancelled according to cancellation policy.',
      refundAmountPaise,
      refundStatus,
    });
  } catch (err) {
    console.error('[CANCEL ERROR]:', err);
    return res.status(500).json({ success: false, message: 'Server error processing cancellation.' });
  }
});

const PORT = process.env.PORT || 3000;
let serverInstance = null;
if (require.main === module) {
  serverInstance = app.listen(PORT, () => {
    console.log(`TOLII OTP & Booking API Server running on port ${PORT}`);
  });
}

module.exports = app;

