# 🛠️ TOLII System Architecture, Implementation Log & Developer Guide

> **CRITICAL REFERENCE FOR DEVELOPERS AND AI ASSISTANTS**  
> *Last Updated: October 2026*  
> *Project: TOLII Sports Community Mobile Application*  
> *Branch / Status: Production-Ready (`email-otp-auth` / `release/email-otp-v1.0`)*

---

## 📌 1. Executive Overview & Tech Stack

TOLII is a mobile sports community application built to connect players, organize games, discover turf venues, and build local sports networks.

* **Frontend**: Flutter 3.x (Dart) with responsive Clean Architecture (Views, Controllers, Models, Repositories, Services).
* **Backend**: Node.js (Express) hosted on **Render** (`https://tolli-app.onrender.com`).
* **Authentication**: 
  * Custom **Email OTP Service** running on **Google Gmail REST API (OAuth 2.0 over HTTPS)**.
  * Backend mints **Firebase Custom Tokens** via `firebase-admin`.
  * Flutter authenticates via `FirebaseAuth.instance.signInWithCustomToken()`.
* **Database & Cloud**: Firebase Cloud Firestore & Firebase Auth.
* **Cost**: **$0.00 / month** (Generous free tier quotas across Google Cloud, Render, and Firebase).

---

## 🏛️ 2. Core Modules & End-to-End Flow

### 📱 A. Authentication Flow (Step 1 to Step 5)

```
[EmailScreen] ──(Pre-warm Ping)──> Render Backend
     │
     ▼ (User inputs email & taps "Send Code")
POST /api/request-otp ──> Gmail API (HTTPS) ──> User's Primary Inbox
     │
     ▼ (User navigates to OtpScreen)
[OtpScreen] ──(60s Cooldown Active: "Resend OTP in 00:XX" Disabled)
     │
     ▼ (User inputs 6-digit PIN & taps "Verify")
POST /api/verify-otp ──> Node Backend verifies HMAC-SHA256 hash
     │
     ├──> On Success: Mints Firebase Custom Token (JWT)
     ▼
FirebaseAuth.signInWithCustomToken(jwt)
     │
     ▼ Check Firestore: User Profile exists & isComplete?
     ├── YES ──> [HomeScreen] (Returning user skips onboarding!)
     └── NO  ──> [LocationScreen] (Step 3: Location detection)
                      │
                      ▼
                 [DetailsScreen] (Step 4: Name, DOB, Gender, Auto-Username)
                      │
                      ▼
                 [SportsScreen]  (Step 5: Favorite Sports, Skill Level)
                      │
                      ▼
                 [HomeScreen]    (Onboarding Complete)
```

---

## 🔒 3. OTP & Security Architecture

### Expiry & Cooldown Rules
1. **OTP Validity (TTL)**: **5 Minutes** (`300,000 ms`). After 5 minutes, the record is invalidated, and the backend returns `"OTP has expired. Please request a new code."`
2. **Resend Cooldown**: **60 Seconds**.
   * On Flutter UI: The `Resend OTP` button stays completely disabled while `_resendCountdown > 0`, displaying `"Resend OTP in 00:XX"`.
   * On Backend: If `/api/request-otp` is requested within 60 seconds for the same email, it responds with HTTP 429: `"Please wait Xs before requesting a new code"`.
3. **Brute-Force Lockout**: Max **5 failed attempts**. Upon the 5th wrong code, the OTP record is purged, preventing brute-force attacks.
4. **HMAC-SHA256 Salted Hashing**: Plaintext OTP codes are never stored in memory or database. Stored as `HMAC-SHA256(email + ':' + otp, OTP_SECRET)`.
5. **Periodic Memory Sweep**: Stale records in the in-memory store are automatically purged every 10 minutes.

---

## ⚡ 4. Google Gmail API OAuth 2.0 (The Permanent Production Solution)

### Why Not Traditional SMTP?
Cloud platforms like Render block or throttle outbound SMTP ports (`25`, `465`, `587`). Using Nodemailer SMTP caused 15–30 second request timeouts and broken user experiences.

### Why Gmail REST API over HTTPS?
* **Zero Port Blocking**: Uses standard HTTPS (Port 443).
* **Guaranteed Delivery**: Arrives in **Primary Inbox** (Zero spam flags).
* **Speed**: **~900 ms to 1.8 seconds** round-trip latency.
* **Free Quota**: 500 emails/day on standard accounts; 2,000 emails/day on Workspace accounts.

### ⚠️ Permanent Token Guide (Solving the 7-Day Expiry)
* **The Problem**: In Google Cloud Console, projects in **"Testing"** status expire OAuth refresh tokens every **7 days**.
* **The Permanent Solution**:
  1. Open [Google Cloud Console](https://console.cloud.google.com/auth/branding) $\rightarrow$ **Branding**.
  2. Fill the required fields:
     * App Name: `TOLII App`
     * User support email: `tolii.team@gmail.com`
     * Application home page: `https://tolli-app.onrender.com`
     * Privacy policy: `https://tolli-app.onrender.com/privacy`
     * Terms of Service: `https://tolli-app.onrender.com/terms`
     * **Authorised domains**: Add `tolli-app.onrender.com`
     * Developer contact email: `tolii.team@gmail.com`
     * Click **Save**.
  3. Navigate to **Audience** (OAuth Consent Screen):
     * Click **"Publish App"** (or *Push to production*).
     * Confirm modal.
     * Status becomes **"In production"**.
  4. **Result**: The refresh token is now **Lifetime Permanent** and will NEVER expire.

---

## 🗂️ 5. Key File Locations & Responsibilities

| File Path | Description / Responsibility |
|---|---|
| `lib/services/otp_service.dart` | Communicates with the Render server (`/api/request-otp`, `/api/verify-otp`, `warmUp()`). |
| `lib/controllers/auth_controller.dart` | State manager for authentication, step navigation, 60s cooldown timer, and Firebase session initialization. |
| `lib/views/email_screen.dart` | Step 1 screen. Initiates pre-warming ping on `initState` and validates email. |
| `lib/views/otp_screen.dart` | Step 2 screen. 6-pin input, 5-min expiry notice, disabled resend button during cooldown, and intelligent home/onboarding routing. |
| `server/index.js` | Express.js backend. Handles Gmail API HTTPS dispatch, HMAC hashing, cooldowns, and Firebase custom token creation. |
| `tools/get_refresh_token.dart` | Local utility tool (`http://127.0.0.1:8989`) to generate Google OAuth2 refresh tokens in 1 minute. |
| `tools/benchmark_otp.dart` | Benchmark tool to test live server latency and OTP round-trip speed from terminal. |
| `EMAIL_OTP_ARCHITECTURE.md` | In-depth technical reference for the Email OTP subsystem. |

---

## 🛑 6. Golden Rules for Developers & AI Assistants

> [!WARNING]
> Follow these strict rules to avoid breaking production stability:

1. **NEVER revert back to SMTP port 465 or 587**: Render blocks outbound SMTP connections. Always use the HTTPS Gmail API implementation in `server/index.js`.
2. **DO NOT remove `warmUp()` in `EmailScreen`**: Render's free tier sleeps on idle. `warmUp()` awakens the instance while the user is typing, making OTP dispatch virtually instant.
3. **DO NOT modify Google Cloud Consent Screen back to "Testing"**: Keep it in **"In production"** to maintain lifetime token validity.
4. **ALWAYS keep rate limiting active**: The 60-second client-side cooldown and backend checks prevent abuse and protect Google API daily quotas.
5. **TEST before committing**: Always run:
   ```bash
   dart analyze lib
   dart run tools/benchmark_otp.dart https://tolli-app.onrender.com your-email@gmail.com
   ```

---

## 📜 7. Work & Change History Log

### October 2026:
* **Production Gmail OAuth2 Migration**:
  * Replaced blocked cloud SMTP with Google Gmail REST API v1 over HTTPS.
  * Created `tools/get_refresh_token.dart` to automate OAuth2 token generation.
  * Verified Google Cloud project branding and set publishing status to **"In production"** for permanent lifetime tokens.
* **Authentication Flow, Session Persistence & UX Polish**:
  * Added pre-warming (`warmUp()`) on `EmailScreen` to eliminate Render cold-start latency.
  * Enforced strict 60-second cooldown timer on `OtpScreen`.
  * Added `"Code is valid for 5 minutes"` expiry notice on UI.
  * Implemented disabled visual state for `Resend OTP` button during cooldown.
  * Added instant multi-tap prevention in `resendOtp()`.
  * Automated persistent login: `SplashScreen` checks `FirebaseAuth.instance.currentUser` and cached profile status; authenticated users jump directly to `HomeScreen`, skipping login screens on every app launch until explicit logout.
  * Configured Firebase Custom Token minting on Render backend via `FIREBASE_SERVICE_ACCOUNT` for authenticating Firebase Auth and passing Firestore security rules.
  * Enhanced `CreateProfileScreen` error handling to display explicit SnackBars for auth and validation failures.
  * Set official App Icon and project assets (`app_logo.png`, Android mipmaps & iOS AppIcon).
  * Added end-to-end terminal console logging across the entire pipeline (`[OTP REQUEST]`, `[OTP VERIFY]`, `[AUTH CONTROLLER]`, `[SAVE PROFILE]`, `[SPLASH SCREEN]`) so every network call, error, and status is visibly printed for debugging.
* **Documentation**:
  * Created `EMAIL_OTP_ARCHITECTURE.md` for dedicated OTP docs.
  * Created `DEVELOPER_WORK_LOG.md` as master developer reference.
  * Updated `README.md` with developer entry point guidance.

---

## 🌐 8. External Cloud Services & Web Portals Reference

The TOLII project integrates several web platforms. Any new developer or AI assistant should refer to these URLs and credentials:

| Service / Platform | Role / Purpose | URL / Access | Primary Credentials / Notes |
|---|---|---|---|
| **GitHub Repository** | Source code, branches (`main`, `dev`, feature branches) | `https://github.com/toliiteam-sudo/Tolli-App` | Account: `toliiteam-sudo`<br>Shared Team Google Account: `tolii.team@gmail.com` |
| **Render Web Service** | Hosts Node.js backend (`server/index.js`) for OTP & Auth API | `https://dashboard.render.com`<br>Live API: `https://tolli-app.onrender.com` | Sign in with GitHub (`toliiteam-sudo`) or Google (`tolii.team@gmail.com`).<br>Service Name: `tolli-app` |
| **Firebase Console** | Cloud Firestore, Firebase Authentication, Security Rules | `https://console.firebase.google.com` | Project: `tolii-app` (or active TOLII project).<br>Uses `FIREBASE_SERVICE_ACCOUNT` for admin token minting. |
| **Google Cloud Console** | Gmail REST API OAuth 2.0, OAuth Consent Screen, Credentials | `https://console.cloud.google.com` | Project: `Tolii App`<br>OAuth Consent status: **In production** (permanent tokens). |

---

## 🚀 9. Developer Git Workflow & Automated Sync Guide

> [!IMPORTANT]
> **GOLDEN RULE: NEVER CODE DIRECTLY ON `dev` OR `main`!**  
> Always create a new feature branch (`feature/<your-feature-name>`), commit your work there, test thoroughly, and then create a Pull Request or merge into `dev`.

### 🔑 A. Connecting to GitHub Repository (One-Time Setup)

When a developer sets up on a new PC:

1. **Clone the repository**:
   ```bash
   git clone https://github.com/toliiteam-sudo/Tolli-App.git
   cd Tolli-App
   ```
2. **Configure Git Identity**:
   ```bash
   git config user.name "toliiteam-sudo"
   git config user.email "tolii.team@gmail.com"
   ```
3. **Verify Remote Connection**:
   ```bash
   git remote -v
   # Should display:
   # origin https://github.com/toliiteam-sudo/Tolli-App.git (fetch)
   # origin https://github.com/toliiteam-sudo/Tolli-App.git (push)
   ```

---

### 🔄 B. Automated Setup & Pull Script (`scripts/sync_dev.ps1`)

Developers can run this automated command whenever they start work to sync with the latest `dev` code cleanly without merge conflicts:

#### In PowerShell (Windows):
```powershell
# 1. Fetch latest changes from GitHub
git fetch origin

# 2. Stash or discard uncommitted temporary changes to keep working directory clean
git status --short
# If you have uncommitted changes you want to keep:
git stash

# 3. Switch to dev branch and pull latest code
git checkout dev
git pull origin dev

# 4. Create your new feature branch for today's work
# Replace 'feature-name' with what you are building (e.g., feature/chat-screen, feature/turf-booking)
git checkout -b feature/<feature-name>

# 5. Get Flutter dependencies
flutter pub get
```

#### In Bash / macOS / Linux:
```bash
git fetch origin
git stash
git checkout dev
git pull origin dev
git checkout -b feature/<feature-name>
flutter pub get
```

---

### 🧹 C. Clean Working Directory Rules (Before Pull & Before Push)

Before pulling or pushing, always ensure your working tree is clean:

1. **Check Status**:
   ```bash
   git status
   ```
2. **If you have untracked build files or temporary artifacts**:
   ```bash
   flutter clean
   flutter pub get
   ```
3. **If you have unfinished edits you don't want to lose**:
   ```bash
   git stash
   # To restore them later on your feature branch:
   git stash pop
   ```
4. **If you want to discard accidental modifications**:
   ```bash
   git restore .
   ```

---

### 📤 D. Daily Developer Push Workflow (Step-by-Step)

```
[Start Work]
     │
     ▼
git checkout -b feature/my-new-task
     │
     ▼ (Write code, fix bugs, add features)
flutter analyze
dart run tools/benchmark_otp.dart https://tolli-app.onrender.com tolii.team@gmail.com
     │
     ▼
git add .
git commit -m "feat(module): descriptive explanation of what changed"
     │
     ▼
git push -u origin feature/my-new-task
     │
     ▼
[Open GitHub PR: feature/my-new-task ──> dev]
```

> [!CAUTION]
> **NEVER PUSH SECRETS TO GITHUB!**
> GitHub has active Secret Scanning and Push Protection. Never hardcode:
> - Google OAuth Client Secrets
> - Firebase private keys
> - Resend / Brevo API keys
> Always store them in environment variables or Render dashboard secrets.

