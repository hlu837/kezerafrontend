# Deployment guide

This repo is a monorepo: a Flutter app at the root (`lib/`, `android/`,
`web/`) and a Node/Express API in `backend/`. They deploy to two
different places:

- **`backend/`** → Vercel (serverless API)
- **root Flutter project** → Codemagic (Android APK)

Both are already configured (`backend/vercel.json`, `/codemagic.yaml`).
This doc is the checklist for actually standing them up.

---

## ⚠️ Before anything else: rotate your credentials

The `backend/.env` in the zip you gave me had **live secrets committed
in plaintext** — a real MongoDB Atlas connection string (with
password), AWS access keys, a JWT signing secret, and Chapa payment
keys. I removed that file from this deliverable and added `.gitignore`
rules so it can't happen again, but the values themselves were already
exposed to anyone who had the zip. Please rotate all of these before
going live:

- MongoDB Atlas: change the database user's password (or delete/recreate
  the user), then update `MONGODB_URI` wherever you set it.
- AWS: deactivate that IAM access key pair in the IAM console and issue
  a new one.
- `JWT_SECRET`: generate a new long random value (rotating this
  invalidates all existing login sessions — expected).
- Chapa: rotate the secret key from the Chapa dashboard.

`backend/.env.example` is the checked-in template — copy it to
`backend/.env` for local dev only; never commit the real file (it's now
gitignored).

---

## Part 1 — Backend on Vercel

### 1. Create the Vercel project

- Import this repo into Vercel.
- **Root Directory: set it to `backend`.** This is the one setting
  that's easy to miss in a monorepo — without it, Vercel will try to
  build from the repo root and won't find `backend/vercel.json` or
  `backend/api/index.js`.
- Framework preset: "Other" (it's a plain Node/Express app, not
  Next.js).

### 2. Set environment variables

In the Vercel project's Settings → Environment Variables, add every key
from `backend/.env.example` with your real values. At minimum, the API
won't boot without these (see `src/config/env.js`'s `REQUIRED_VARS`):

- `MONGODB_URI` — must point at a **MongoDB Atlas** cluster (or another
  reachable replica set). A local `mongod` won't be reachable from
  Vercel. Mongoose transactions (`services/auth.service.js`) require a
  replica set — Atlas gives you one by default.
- `JWT_SECRET`, `JWT_EXPIRES_IN`, `JWT_ISSUER`
- `AWS_REGION`, `AWS_S3_BUCKET`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`

Also set these — not boot-required, but needed for full functionality:

- `BCRYPT_SALT_ROUNDS`, `MAX_UPLOAD_SIZE_MB`
- `REDIS_URL` — see the Upstash note below
- `PUBLIC_BASE_URL` — the exact `https://your-project.vercel.app`
  origin, used to verify Twilio's inbound webhook signature
- `SMS_PROVIDER` + whichever of `TWILIO_*` / `AT_*` you use (the
  inbound SMS webhook route runs on the API itself, so it needs these
  even though outbound sending happens in the notifications worker)
- `SENDGRID_API_KEY`, `NOTIFICATIONS_FROM_EMAIL`, `NOTIFICATIONS_FROM_NAME`
- `CHAPA_SECRET_KEY`, `CHAPA_BASE_URL` (payments run in simulated mode
  without these — fine for testing, not for real transactions)

MongoDB Atlas network access: either allow-list `0.0.0.0/0` (Vercel's
outbound IPs aren't static) or use the official Vercel↔Atlas
integration from the Vercel marketplace, which handles this for you.

### 3. Redis — use a serverless-friendly provider

`ioredis`/BullMQ need a real TCP connection, which rules out most
"HTTP-only" serverless Redis products. **Upstash Redis** works — it
gives you a standard `rediss://` URL that `ioredis` connects to
directly. Create a database there and set `REDIS_URL` to the connection
string it gives you.

### 4. Deploy

Push to the branch Vercel is watching, or run `vercel --prod` from
`backend/`. Once it's up, hit `https://your-project.vercel.app/health`
— it should return `{"status":"ok"}`.

### 5. ⚠️ The background workers do NOT run on Vercel

`src/matching-worker.js` and `src/notifications-worker.js` are
long-running BullMQ consumers — they sit in a loop pulling jobs off
Redis. Vercel serverless functions are stateless and short-lived; they
cannot host these. If you deploy only the API to Vercel:

- Job creation will still **enqueue** a `JOB_MATCHING` task (the API
  route that does this doesn't need the worker to be running).
- But nothing will ever **process** that task — no suggested seekers
  will show up, and no candidate notifications will go out — until a
  worker is running somewhere and consuming the queue.

Deploy the two workers as persistent processes on a platform that
supports them — Railway, Render, Fly.io, or a small VPS all work. Point
them at the same `MONGODB_URI` and `REDIS_URL` as the Vercel API.
Start commands:

```
npm run worker                # src/matching-worker.js
npm run notifications-worker  # src/notifications-worker.js
```

Both now establish their own MongoDB connection on startup (this was
missing before and would have crashed them immediately — fixed as part
of this pass, see `src/matching-worker.js` / `src/notifications-worker.js`).

---

## Part 2 — Flutter Android APK on Codemagic

`codemagic.yaml` at the repo root defines a single `android-apk`
workflow: `flutter pub get` → `flutter analyze` → `flutter build apk
--release`.

### 1. Connect the repo

In Codemagic, add this repository and it should auto-detect
`codemagic.yaml`. No extra app-level setup needed for this workflow —
it doesn't reference any Codemagic-managed signing/App Store Connect
integration.

### 2. Point it at your deployed API

`codemagic.yaml` currently has:

```yaml
vars:
  API_BASE_URL: https://kezerajobs.vercel.app/api/v1
```

Update this to your actual Vercel deployment URL from Part 1 (must
include the `/api/v1` suffix — that's the Express mount point, see
`app.js`). This gets baked into the APK at build time via
`--dart-define`, which is how `lib/core/constants/app_constants.dart`
picks it up.

### 3. Run the build

Start the `android-apk` workflow. On success, the APK is attached as a
build artifact (`build/app/outputs/flutter-apk/app-release.apk`) —
downloadable from the build page. Uncomment the `publishing.email`
block in `codemagic.yaml` (with your address filled in) if you want it
emailed to you automatically instead.

### 4. Before shipping this to real users

A few things are currently fine for internal testing but worth doing
before a Play Store release or wider distribution:

- **App ID**: `android/app/build.gradle.kts` still has the Flutter
  template default, `applicationId = "com.example.kefera_jobs_app"`.
  Change this to your real reverse-domain package name — once an APK
  ships under an ID, changing it later means users can't upgrade in
  place, they'd need to install a separate app.
- **Release signing**: the `release` build type currently signs with
  the **debug** key (see the `signingConfig` in the same file) — that's
  why no keystore setup was needed to get a working APK. This is fine
  for sideloading/internal testing but the Play Store requires a real
  upload key. When you're ready, generate a keystore, add a
  `signingConfigs.release` block, and switch to Codemagic's [Android
  code signing](https://docs.codemagic.io/yaml-code-signing/signing-android/)
  (store the keystore as an encrypted Codemagic environment variable —
  don't commit it).
- **App icon**: still the default Flutter icon. Consider the
  `flutter_launcher_icons` package if you want a custom one generated
  automatically as part of the build.
