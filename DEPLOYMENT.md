# Deployment guide — Flutter app (Codemagic)

This folder (`kezerajobs-frontend-clean/`) is a standalone Flutter
app. The simplest setup is to push it to its own Git repository and
connect *that* to Codemagic — `codemagic.yaml` already sits at this
folder's root, so no extra "working directory" setting is needed in
that case.

(If you'd rather keep this and `backend-clean/` in one monorepo
instead, that works too — Codemagic lets you set this folder as the
build's working directory in the app settings.)

The backend (`backend-clean/`) deploys separately, to Vercel — see
`backend-clean/DEPLOYMENT.md` for that side, including an important
note about credentials that needs attention before you push anything
to a Git host.

---

## Part 1 — Point this app at your deployed backend

`codemagic.yaml` currently has:

```yaml
vars:
  API_BASE_URL: https://kezera-backend.vercel.app/api/v1
```

Update this to your actual Vercel deployment URL (must include the
`/api/v1` suffix — that's the Express mount point, see
`backend-clean/src/app.js`). This gets baked into the APK at build
time via `--dart-define`, which is how
`lib/core/constants/app_constants.dart` picks it up — that file has
the same placeholder as its `defaultValue`, so update both together if
you'd rather not rely on the build-time override.

## Part 2 — Connect this repo to Codemagic

`codemagic.yaml` defines a single `android-apk` workflow:
`flutter pub get` → `flutter analyze` → `flutter build apk --release`.

### 1. Connect the repo

In Codemagic, add this repository and it should auto-detect
`codemagic.yaml`. No extra app-level setup needed for this workflow —
it doesn't reference any Codemagic-managed signing/App Store Connect
integration.

### 2. Run the build

Start the `android-apk` workflow. On success, the APK is attached as a
build artifact (`build/app/outputs/flutter-apk/app-release.apk`) —
downloadable from the build page. Uncomment the `publishing.email`
block in `codemagic.yaml` (with your address filled in) if you want it
emailed to you automatically instead.

### 3. Before shipping this to real users

A few things are currently fine for internal testing but worth doing
before a Play Store release or wider distribution:

- **App ID**: `android/app/build.gradle.kts` still has the Flutter
  template default, `applicationId = "com.example.kezera_jobs_app"`.
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
