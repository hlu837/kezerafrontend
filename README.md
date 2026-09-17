# KeferaJobs — Universal Flutter App (mobile + web)

One Flutter codebase for the whole frontend: seekers, employers, and
agencies all use the same app, same auth layer, with role-based routing
deciding what each user sees — the seeker flows are optimized for mobile,
the employer/agency backoffice for wide/web screens, all in one responsive
shell. There is no separate web app; the Express/MongoDB backend is
unchanged and untouched by this.

## Folder structure

```
lib/
  core/
    constants/app_constants.dart      # API base URL, storage keys, endpoints
    error/api_exception.dart          # Normalized error type
    network/api_client.dart           # Dio + interceptors
    storage/secure_storage_service.dart
    routing/app_router.dart           # go_router: role redirects + route guards
    widgets/
      responsive_shell.dart           # sidebar (web/wide) <-> bottom nav (mobile)
      coming_soon_screen.dart         # placeholder for not-yet-built routes
  features/
    auth/
      domain/                         # AuthUser, LoginPayload, RegisterSeekerPayload
      data/auth_repository.dart       # /auth/login, /auth/register
      presentation/                   # AuthState, AuthNotifier, providers, LoginScreen
    seeker/presentation/              # seeker nav config + dashboard
    employer/presentation/            # employer nav config + dashboard
    agency/presentation/              # agency nav config + dashboard
  main.dart                           # ProviderScope + MaterialApp.router
```

## How the "universal" part works

- **One router, three roles.** `core/routing/app_router.dart` is the single
  source of truth for navigation. It watches `authProvider`; on login it
  reads the returned user's `role` and redirects to that role's dashboard
  (`seeker → /seeker/dashboard`, `employer → /employer/dashboard`,
  `agency → /agency/dashboard`). It also guards routes both ways — a seeker
  can't navigate into `/employer/*` and land on someone else's screen.
- **One shell, two layouts.** `core/widgets/responsive_shell.dart` renders
  a fixed sidebar (matching the old Next.js `BackofficeShell`) at ≥900px —
  i.e. web/desktop/tablet — and a bottom nav bar below that, for phones.
  Each role passes in its own nav items; the shell doesn't know or care
  which role it's rendering.
- **Adding a page** = one `GoRoute` in `app_router.dart` + one
  `ShellNavItem` in that role's `*_shell.dart` config. Routing, the sidebar
  entry, and the role guard all update from that single change — no new
  layout code.

The `/employer/jobs/new`, `/employer/candidates`, `/agency/walk-in`, and
`/agency/placements` routes are wired up end-to-end (nav, routing, guards,
and real backend calls) — see "Notes / next steps" below for what each one
does.

## Backend contract (unchanged)

- Base URL: `{API_BASE_URL}` (default `http://localhost:3000/api/v1`)
- `POST /auth/login` — body `{ phone? | email?, password }` (login screen
  accepts a single "phone or email" field and picks the right key, same as
  the old web login form)
- `POST /auth/register` — body `{ role: "seeker", phone, password, full_name, email?, cv_url?, photo_url? }`
- Success envelope: `{ "status": "success", "data": { user, token } }`
- Error envelope: `{ "status": "error" | "fail", "message": string, "errors"?: [{ field?, message }] }`
- No `/auth/me` endpoint — the app caches the returned `user` object
  alongside the token and hydrates from that on startup.

## Getting started

This ships the Flutter source, web platform files, and the Android platform
project used by Codemagic for APK builds. `ios/`, `linux/`, `macos/`, and
`windows/` platform folders are not included.

```bash
flutter pub get
```

## Codemagic APK build

The repository root contains `codemagic.yaml`. Create a Codemagic workflow
from that file and connect the GitHub repository. The `android-apk` workflow
runs `flutter analyze`, then creates
`build/app/outputs/flutter-apk/app-release.apk` using the
`API_BASE_URL` environment variable.

For a distributable signed APK, configure an Android keystore and Codemagic
secure signing variables in the Codemagic UI, then update the workflow with
the signing setup required by your keystore. The checked-in workflow uses
Flutter's debug signing key so it can build without secrets; do not distribute
that artifact to end users.

Run on mobile (Android emulator can't reach `localhost` — use `10.0.2.2`):

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

Run on web (localhost works directly; the backend already has permissive
CORS enabled via `app.use(cors())`, so no extra config is needed):

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api/v1
```

To ship a production web build (e.g. to deploy behind a static host or
reverse proxy alongside the backend):

```bash
flutter build web --dart-define=API_BASE_URL=https://api.keferajobs.com/api/v1
# output: build/web/
```

## Key pieces (unchanged from the original auth-only app)

- **`ApiClient`** (`core/network/api_client.dart`) — configures `Dio` with
  the base URL, injects `Authorization: Bearer <token>` from secure storage
  on every request, and normalizes the backend's error envelope into an
  `ApiException`. On a 401 it clears storage and calls `onUnauthorized`,
  which `authProvider` wires to `AuthNotifier.forceLogout`.
- **`SecureStorageService`** (`core/storage/`) — wraps
  `flutter_secure_storage` for the JWT and cached user JSON. Works on web
  too (backed by browser storage), so hydration behaves the same on both
  platforms.
- **`AuthNotifier`** (`features/auth/presentation/auth_provider.dart`) —
  Riverpod `StateNotifier<AuthState>` exposing `login`, `registerSeeker`,
  `logout`, and automatic hydration on startup. `AuthState.status` now
  drives `go_router`'s redirect logic instead of a manual `AuthGate` switch.

## Notes / next steps

- **Seeker profile is now live end-to-end**: `/seeker/dashboard`
  (`features/seeker/presentation/seeker_dashboard_screen.dart`) fetches the
  logged-in seeker's own profile via `GET /seekers/me`, edits `full_name`/
  `bio` via `PATCH /seekers/me` (only fields the backend's
  `updateProfileSchema` actually accepts — skills/city aren't
  self-editable), toggles `availability_status` via
  `PATCH /seekers/me/availability` (optimistic, rolls back on failure), and
  uploads CV/photo via `POST /seekers/upload` (multipart, `file_picker`,
  same bytes-based `WalkInAttachment` pattern the agency walk-in screen
  uses so it works on web too). Backed by
  `features/seeker/data/seeker_profile_repository.dart` and
  `features/seeker/presentation/seeker_profile_provider.dart` — kept
  separate from the pre-existing `SeekerRepository`, which only covers the
  employer/agency-facing `GET /seekers/search` (a different caller and a
  different backend auth guard).
- **Employer job postings are live end-to-end**: `/employer/jobs/new`
  (`features/jobs/presentation/post_job_screen.dart`) posts via
  `POST /jobs/create`, and `/employer/dashboard` lists them via
  `GET /jobs/my-jobs` with an open/closed toggle (`PATCH /jobs/:id`).
- Registration covers all three self-service roles (`seeker`, `employer`,
  `agency`) behind a `SegmentedButton` role picker at `/register` — 7–15
  digit phone, 8+ char password, per-role required fields, so the backend
  never rejects a well-formed submission.
- **Agency + candidates screens are also live end-to-end**:
  `/agency/walk-in` (walk-in candidate registration with optional
  CV/photo attachments), `/agency/placements` (placement pipeline with
  status updates), and `/employer/candidates` (candidate search) all call
  their real backend endpoints — nothing in the app points at a
  placeholder screen anymore.
- The backend has fully moved off PostgreSQL onto MongoDB (auth, jobs,
  placements, and profile data all read/write Mongo now). That's a backend
  concern and doesn't change anything about this app's structure.
- No code generation (no `freezed`/`build_runner`) — models use hand-written
  `fromJson`/`toJson` to keep the setup fast to build on and easy to read.
