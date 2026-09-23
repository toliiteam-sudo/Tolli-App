const express = require('express');
const cors = require('cors');
const crypto = require('crypto');
const https = require('https');
const { Resend } = require('resend');
const admin = require('firebase-admin');
require('dotenv').config();

const app = express();
app.use(express.json());
app.use(cors());

// 1. Brevo Transactional Email HTTP API — Free 300/day, any recipient, no SMTP ports, no IP restriction
const BREVO_API_KEY = process.env.BREVO_API_KEY ? process.env.BREVO_API_KEY.trim() : null;

async function sendViaBrevoApi(to, subject, htmlContent) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify({
      sender: { email: 'tolii.team@gmail.com', name: 'TOLII App' },
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
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve({ success: true });
        } else {
          reject(new Error(`Brevo API error ${res.statusCode}: ${data}`));
        }
      });
    });
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

// 2. Initialize Resend Fallback
const RESEND_API_KEY = process.env.RESEND_API_KEY;
const resend = RESEND_API_KEY ? new Resend(RESEND_API_KEY) : null;

// 3. Initialize Firebase Admin
let isFirebaseAdminInitialized = false;
try {
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    isFirebaseAdminInitialized = true;
    console.log('Firebase Admin initialized successfully with Service Account');
  } else {
    admin.initializeApp();
    isFirebaseAdminInitialized = true;
    console.log('Firebase Admin initialized with default credentials');
  }
} catch (e) {
  console.warn('Firebase Admin initialization deferred/failed:', e.message);
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
    brevoConfigured: !!BREVO_API_KEY,
    resendConfigured: !!resend,
    timestamp: new Date().toISOString()
  });
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

    // Dispatch email — Brevo HTTP API (primary) → Resend (fallback)
    let emailSent = false;

    // Attempt 1: Brevo HTTP API (free, any recipient, no IP restriction, ~1-2s)
    if (!emailSent && BREVO_API_KEY) {
      try {
        await Promise.race([
          sendViaBrevoApi(cleanEmail, emailSubject, emailHtml),
          new Promise((_, reject) => setTimeout(() => reject(new Error('Brevo API timeout')), 10000))
        ]);
        console.log(`[OTP] ✅ Dispatched via Brevo API to ${cleanEmail}`);
        emailSent = true;
      } catch (err) {
        console.warn(`[OTP] ⚠️ Brevo API failed (${err.message}), trying Resend...`);
      }
    }

    // Attempt 2: Resend (last resort)
    if (!emailSent && resend) {
      const emailResult = await resend.emails.send({
        from: 'TOLII <onboarding@resend.dev>',
        to: cleanEmail,
        subject: emailSubject,
        html: emailHtml
      });
      if (emailResult.error) {
        throw new Error(emailResult.error.message || 'Resend error');
      }
      console.log(`[OTP] ✅ Dispatched via Resend to ${cleanEmail}`);
      emailSent = true;
    }

    if (!emailSent) {
      throw new Error('No email transport available. Please check server configuration.');
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

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`TOLII OTP API Server running on port ${PORT}`);
});
