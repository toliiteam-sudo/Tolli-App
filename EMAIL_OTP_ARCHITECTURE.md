# 📧 TOLII Email OTP Authentication Architecture & Developer Guide

> **Production Context & Reference Guide for the TOLII Engineering Team**  
> *Last Updated: September 2026*  
> *Status: Fully Operational in Production* 🚀

---

## 📌 Executive Summary

TOLII uses a zero-cost, high-deliverability **Email OTP Authentication System** designed for speed, security, and inbox placement:

- **Delivery Speed**: **~740 milliseconds** (< 1 second) from user tap to dispatch.
- **Inbox Placement**: **100% Primary Inbox** (zero Spam folder flags) via authenticated Google Gmail API OAuth2.
- **Cost**: **$0.00 / month** (500 free emails/day on standard Google accounts; 2,000/day on Google Workspace).
- **Backend Host**: Hosted on Render (`https://tolli-app.onrender.com`).
- **Security**: HMAC-SHA256 salted hashes, 5-minute expiry, 60-second resend cooldown, max 5 attempts rate limiting, and Firebase Admin Custom Token minting.

---

## 🏛️ System Architecture Diagram

```
+-------------------------------------------------------------------------------+
|                                FLUTTER CLIENT                                 |
|                                                                               |
|   EmailScreen                  OtpScreen                        HomeScreen    |
|   (Pre-warms backend)          (6-digit pin input)             (Logged in)    |
|        │                           │                                │         |
|        │ Request OTP               │ Verify OTP                     │         |
|        ▼                           ▼                                │         |
|   OtpService                  AuthController                        │         |
|   (EmailOtpProvider)          (signInWithCustomToken)               │         |
+────────┬───────────────────────────┬────────────────────────────────┼─────────+
         │                           │                                │
         │ HTTPS POST                │ HTTPS POST                     │
         │ /api/request-otp          │ /api/verify-otp                │
         ▼                           ▼                                │
+─────────────────────────────────────────────────────────────────────┼─────────+
|                               NODE.JS BACKEND                       │         |
|                       (https://tolli-app.onrender.com)              │         |
|                                                                     │         |
|   1. Validate Regex & Rate Limit (60s cooldown)                     │         |
|   2. Generate 6-digit crypto OTP                                    │         |
|   3. Store HMAC-SHA256 hash in memory (5 min TTL)                   │         |
|   4. Mint Firebase Custom Token on verify                           │         |
|                                                                     │         |
|              Dispatches Email via Multi-Tier Fallback:              │         |
|              ┌────────────────────────────────────────┐             │         |
|              │ Tier 1: Gmail API (OAuth2 over HTTPS)  │ ◄── PRIMARY │         |
|              │ Tier 2: SendGrid HTTP API              │ ◄── BACKUP  │         |
|              │ Tier 3: Resend HTTP API                │ ◄── BACKUP  │         |
|              └────────────────────────────────────────┘             │         |
+────────────────────────────────────┬────────────────────────────────┼─────────+
                                     │                                │
                                     ▼                                ▼
                       Google Gmail / SendGrid             Firebase Authentication
                     (Direct to User's Inbox)              (Signs user into Firebase)
```

---

## 🚀 End-to-End Request & Verification Flow

### 1. Requesting an OTP (`POST /api/request-otp`)

1. **User input**: User types email in `EmailScreen` and taps **"Send Code"**.
2. **Pre-warming**: `_EmailScreenState.initState()` automatically sends a lightweight GET ping to `https://tolli-app.onrender.com/` so the backend is awake before the user finishes typing.
3. **Payload**:
   ```json
   {
     "email": "user@example.com"
   }
   ```
4. **Validation & Rate Limiting**:
   - RFC email regex validation.
   - 60-second cooldown check (`RESEND_COOLDOWN_MS = 60 * 1000`). If requested too early, returns HTTP `429 Too Many Requests`.
5. **Code Generation**:
   - Uses Node.js `crypto.randomInt(100000, 999999)`.
   - Hashes `email:otp` with `HMAC-SHA256` using `OTP_SECRET`.
   - Stored in memory with `{ hash, expiresAt: now + 5 mins, attempts: 0, lastRequestedAt }`.
6. **Dispatch Pipeline**:
   - **Tier 1 (Gmail API)**: Dispatches via `https://gmail.googleapis.com/gmail/v1/users/me/messages/send` using OAuth2 Bearer token.
   - **Tier 2 (SendGrid)**: If Gmail API fails or times out (12s), falls back to SendGrid v3 API.
   - **Tier 3 (Resend)**: Final fallback.
7. **Response**:
   ```json
   {
     "success": true,
     "message": "OTP sent to your email successfully."
   }
   ```

---

### 2. Verifying an OTP (`POST /api/verify-otp`)

1. **User input**: User enters the 6-digit code in `OtpScreen`.
2. **Payload**:
   ```json
   {
     "email": "user@example.com",
     "otp": "482910"
   }
   ```
3. **Verification Steps**:
   - Checks if record exists (if not: *"No active OTP request found"*).
   - Checks if expired (TTL 5 minutes).
   - Checks attempt count: if >= 5 attempts, invalidates record to block brute-force.
   - Recomputes HMAC-SHA256 hash and compares in constant time.
   - Marks OTP as used and purges record.
4. **Firebase Token Minting**:
   - If `FIREBASE_SERVICE_ACCOUNT` is initialized, calls `admin.auth().getUserByEmail(email)` (or `createUser` if new).
   - Mints a Firebase Custom Token (`admin.auth().createCustomToken(uid)`).
5. **Response**:
   ```json
   {
     "success": true,
     "message": "OTP verified successfully.",
     "email": "user@example.com",
     "firebaseToken": "<JWT_CUSTOM_TOKEN>",
     "uid": "<FIREBASE_UID>"
   }
   ```
6. **Flutter Client Session Establishment**:
   - Flutter calls `FirebaseAuth.instance.signInWithCustomToken(response.firebaseToken)`.
   - Fetches user profile from Firestore.
   - **Smart Navigation**:
     - If `isProfileComplete == true` (returning user) $\rightarrow$ Navigates directly to `HomeScreen`.
     - If `isProfileComplete == false` (new user) $\rightarrow$ Navigates to onboarding (`LocationScreen`).

---

## 🔑 Environment Variables Reference

Configure these in `server/.env` (locally) and in your Render Dashboard (**Settings $\rightarrow$ Environment Variables**):

| Variable | Description | Example / Format |
|---|---|---|
| `PORT` | Web server listening port | `3000` (Render overrides automatically) |
| `GMAIL_CLIENT_ID` | Google Cloud OAuth2 Client ID | `993511560623-xxxx.apps.googleusercontent.com` |
| `GMAIL_CLIENT_SECRET` | Google Cloud OAuth2 Client Secret | `GOCSPX-xxxx` |
| `GMAIL_REFRESH_TOKEN` | Google OAuth2 Refresh Token for `tolii.team@gmail.com` | `1//04xxxx` |
| `SMTP_USER` | Official sender email address | `tolii.team@gmail.com` |
| `SENDGRID_API_KEY` | SendGrid fallback API Key | `SG.xxxx` |
| `RESEND_API_KEY` | Resend fallback API Key | `re_xxxx` |
| `OTP_SECRET` | Secret salt for HMAC-SHA256 hashing | Secure random 32+ char string |
| `FIREBASE_SERVICE_ACCOUNT` | Raw JSON string of Firebase Admin Service Account Key | `{"type": "service_account", ...}` |

---

## 🛠️ How to Generate or Renew Gmail OAuth2 Refresh Token

If you ever change the sender Google account or need to regenerate the OAuth2 refresh token:

1. **Prerequisites in Google Cloud Console**:
   - Ensure the Google Cloud Project has **Gmail API** enabled.
   - In **APIs & Services $\rightarrow$ Credentials**, create an **OAuth 2.0 Client ID** of type **Desktop App** (or Web).
   - In **OAuth consent screen**, ensure `https://www.googleapis.com/auth/gmail.send` scope is added.

2. **Run the Helper Script**:
   ```bash
   cd server
   node scripts/get_gmail_token.js <YOUR_CLIENT_ID> <YOUR_CLIENT_SECRET>
   ```

3. **Authorize**:
   - The script will print an authorization URL.
   - Open that URL in your browser, log in with `tolii.team@gmail.com`, and click **Allow**.
   - Copy the authorization code shown by Google and paste it into the terminal prompt.

4. **Update Render**:
   - Copy the generated `GMAIL_REFRESH_TOKEN` into the Render Dashboard environment variables.
   - Trigger a deploy or restart the service.

---

## 📱 Flutter Code Structure

| File | Purpose |
|---|---|
| `lib/services/otp_service.dart` | Singleton service wrapping `EmailOtpProvider`, handles HTTP POST to Render, background pre-warming (`warmUp()`), and error deserialization. |
| `lib/controllers/auth_controller.dart` | Manages auth state, validation, 60s resend timer, OTP submission, Firebase custom token sign-in, and profile completeness sync. |
| `lib/views/email_screen.dart` | Step 1 screen. Initiates pre-warming on `initState`, validates email format, displays error SnackBar on dispatch failure. |
| `lib/views/otp_screen.dart` | Step 2 screen. 6-pin input box, resend countdown timer, intelligent post-verification routing to `HomeScreen` or `LocationScreen`. |
| `tools/benchmark_otp.dart` | Diagnostic tool to measure live server wakeup latency and OTP delivery time from terminal. |

---

## ⚡ Performance Benchmark (Verified)

Run from repository root:
```bash
dart tools/benchmark_otp.dart
```

**Results:**
- **Server Ping Latency**: `~711 ms`
- **Total OTP Dispatch Latency**: `~744 ms`
- **Total Round-Trip Time**: **< 1.0 second**
- **User Perspective**: OTP appears in the user's Gmail Primary Inbox within 2 seconds of tapping "Send Code".

---

## 🛡️ Production Checklist for Developers

- [x] **No hardcoded secrets**: All API keys and secrets reside strictly in environment variables.
- [x] **Safe Fallbacks**: If Gmail API hits rate limits or network issues, SendGrid and Resend automatically catch the request.
- [x] **Rate Limiting**: Server enforces 60-second cooldown per email; max 5 incorrect attempts before lockout.
- [x] **Memory Management**: Expired OTP records are cleaned every 10 minutes automatically.
- [x] **Zero Static Analysis Warnings**: Flutter codebase passes `dart analyze lib` with `No issues found!`.
- [x] **Smooth UX**: Existing users skip onboarding straight to `HomeScreen`.
