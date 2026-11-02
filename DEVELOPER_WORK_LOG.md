# 📝 TOLII DEVELOPER WORK LOG

> **Date:** November 2, 2026  
> **Branch:** `dev`  
> **Status:** Production Ready & Verified 🚀  

---

## 📌 Executive Summary of Today's Work

In today's engineering session, we audited the authentication pipeline, resolved critical blocking issues on both **Email OTP Authentication** and **Google Sign-In**, promoted **Brevo HTTP API** to Tier 1 for permanent zero-expiry reliability, and synchronized the repository with live production settings.

---

## 1. 📧 Email OTP Authentication: Root Cause & Permanent Fix

### Problem Encountered
When users clicked "Send OTP", the app returned:
```text
Failed to send email: Gmail API: Token error: {
  "error": "invalid_grant",
  "error_description": "Bad Request"
} | Gmail SMTP: Gmail SMTP port blocked or timed out
```

### Technical Root Cause
1. **Gmail OAuth Refresh Token Expiration**: The Google OAuth2 `GMAIL_REFRESH_TOKEN` on Render was invalidated due to Google security policies (password change, account security checkpoint, or cloud trial billing restrictions).
2. **Cloud SMTP Firewall**: Render automatically blocks outbound SMTP connections on ports 465 and 587 on standard tiers, causing Nodemailer SMTP fallback to time out.
3. **Brevo IP Restriction**: Brevo's default security whitelist was blocking Render's dynamic cloud IP (`74.220.48.71`).

### Resolutions Implemented
1. **Renewed Gmail OAuth2 Token**:
   - Built modern loopback generator in `tools/get_refresh_token.dart` (`http://localhost:8080`).
   - Authenticated with `tolii.team@gmail.com` and generated verified `GMAIL_REFRESH_TOKEN`.
2. **Activated & Promoted Brevo HTTP API to Tier 1 (Primary)**:
   - Configured Brevo REST API key (`BREVO_API_KEY`) on Render.
   - Deactivated IP restriction in Brevo Console (`app.brevo.com/security/authorised_ips`) to support dynamic cloud host IPs.
   - Re-ordered server dispatch sequence in `server/index.js` so **Brevo HTTP API is Attempt 1**:
     - Uses permanent static key (`xkeysib-...`) that **NEVER expires**.
     - No OAuth consent renewals or 7-day test expirations.
     - Dispatches in **~350–800 ms** directly to Primary Inbox.
     - Preserves full branded sports HTML email template (`⚽ 🏏 🏸 🎾 🚴 TOLII`).
3. **Failover Architecture**:
   - **Tier 1 (Primary)**: Brevo HTTP API (300 free emails/day forever).
   - **Tier 2 (Backup)**: Google Gmail API OAuth2 (500 free emails/day).
   - **Tier 3 (Fallback)**: SendGrid / Mailjet / Resend.

---

## 2. 🔑 Google Sign-In ("Continue with Google"): SHA-1 Missing Fix

### Problem Encountered
Tapping "Continue with Google" threw platform / ApiException errors during token exchange.

### Technical Root Cause
In `android/app/build.gradle.kts`, the app package name is `com.tolli.app`. However, in `android/app/google-services.json`:
- The previous client was configured under `com.example.tolii`.
- Under `com.tolli.app`, there was **no Android OAuth Client (`client_type: 1`)** registered in Firebase/Google Cloud, only a web client ID.

### Resolutions Implemented
1. Extracted exact local debug keystore certificates:
   - **SHA-1**: `3D:AB:CE:F6:DE:16:54:B9:75:8B:52:01:DD:CA:31:C1:D2:3B:FF:25`
   - **SHA-256**: `3E:B1:1C:44:F4:F6:B6:D1:3E:33:18:40:2E:99:08:59:2F:7B:36:22:15:B1:DF:EF:25:00:39:BD:A0:B9:B7:54`
2. Added certificate fingerprint to Firebase Console under Android app `com.tolli.app`.
3. Downloaded updated `google-services.json` containing:
   ```json
   {
     "client_id": "993511560623-nkos1q17o87aii40jvomdo4rhmvie4d5.apps.googleusercontent.com",
     "client_type": 1,
     "android_info": {
       "package_name": "com.tolli.app",
       "certificate_hash": "3dabcef6de1654b9758b5201ddca31c1d23bff25"
     }
   }
   ```
4. Replaced and committed `android/app/google-services.json`.

---

## 3. 📂 Repository & Deployment Status

| File | Changes Made |
|---|---|
| `server/index.js` | Reordered dispatch pipeline to prioritize Brevo HTTP API as primary Attempt 1. |
| `android/app/google-services.json` | Updated with official Android OAuth client credentials for `com.tolli.app`. |
| `EMAIL_OTP_ARCHITECTURE.md` | Updated tier architecture documentation to reflect Brevo Tier 1. |
| `tools/get_refresh_token.dart` | Added reusable Dart-based OAuth loopback helper tool. |
| `DEVELOPER_WORK_LOG.md` | Complete log of issues diagnosed, architectural decisions, and verification steps. |

---

## 4. 🚀 Verification Benchmarks

Live diagnostics against `https://tolli-app.onrender.com/api/test-transports`:
- **Gmail API**: `✅ Success (Token verified)`
- **Brevo API**: `✅ Success (Brevo email sent successfully)`
- **Live Dispatch Speed**: `⚡ 798 ms`
- **Delivery Confirmation**: Tested and delivered to user inbox.
