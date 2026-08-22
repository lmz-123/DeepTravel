---
name: deeptravel-project
description: Project-specific operating context for DeepTravel (见地/JIAN·DI), covering its Flask/MySQL API, Flutter client, independent admin service, content and narration workflows, production deployment, runtime logs, local SDK/tool paths, mirror configuration, and Android/iOS packaging. Use whenever Codex works on this project, its server deployment, route/content configuration, audio voice selection, troubleshooting, release builds, or OpenSpec changes.
---

# DeepTravel project context

Use this skill as the first source of project-specific facts. Prefer the paths, commands, ports, and architectural boundaries below over rediscovering them. Re-check live state before mutating production data or deploying.

## Product and architecture

DeepTravel (产品名“见地 JIAN·DI”) is a deep-travel guide: published scenic routes deliver location-aware audio narration, fragmented historical storytelling, photo missions, and a final story reconstruction. Current content includes Shenzhen/Nantou, Dameisha, and Shanghai routes. Route content, images, audio tracks, publication status, and voice profiles come from the backend/admin system; do not hard-code city or route resources in Flutter.

Use a modular-monolith boundary:

- `backend/`: Flask API, domain/application/infrastructure/presentation layers, Alembic migrations, MySQL persistence, local/OSS media adapters.
- `mobile/`: Flutter feature-first client. Keep View, application state, domain models, repositories, REST/local storage, location, audio, and camera adapters separated.
- `Travel-Admin/` (sibling project): independent admin/content/log service. It is a separate Git repository and must be changed and pushed separately when applicable.
- `openspec/`: change proposals, designs, delta specs, and tasks. Use the OpenSpec skills in `.agents/skills/openspec-*` for implementation work that requires an OpenSpec change.
- `docs/`: implementation, deployment, verification, content packages, and field checklists.

Normal data flow:

`Flutter -> API /api/v1 -> Flask application -> MySQL + media adapter`; admin content and runtime logs use the separate `Travel-Admin` service on port 5100. Published content only is returned to the client. User journeys, progress, and evidence are isolated by authenticated user.

## Repository paths and remotes

Local workspace:

- Main repository: `/Users/li/Downloads/Project/Travel`
- Main remote: `git@github.com:lmz-123/DeepTravel.git`
- Main branch: `main`
- Admin repository: `/Users/li/Downloads/Project/Travel-Admin`
- Admin remote: `git@github.com:lmz-123/DeepTravel-admin.git`
- Admin branch: `main`
- Release artifacts: `/Users/li/Downloads/Project/Travel/dist`
- Local media source: `/Users/li/Downloads/Project/Travel/backend/media`
- Content packages: `/Users/li/Downloads/Project/Travel/docs/content-packages`
- Publishing helper: `/Users/li/Downloads/Project/Travel/tools/publish_content_package.py`
- Field notes: `/Users/li/Downloads/Project/Travel/docs/field-checklists`

Preserve unrelated working-tree changes. Build output under `mobile/build`, `mobile/ios/build`, and old APKs under `dist` may be untracked; inspect status before committing and do not commit generated build caches or APK artifacts unless explicitly requested.

## Default completion, push, package, and handoff workflow

Treat the following as the user's standing delivery authorization for DeepTravel work unless the current request explicitly says not to commit, push, or package:

1. Finish the scoped implementation and run proportionate validation. Do not push known failing code.
2. Inspect `git status`, `git diff`, and `git diff --check`; preserve unrelated files, generated caches, local skills, artifacts, and secrets. Fetch the matching remote and confirm the target branch has not diverged.
3. Commit only the task's reviewed source, tests, migrations, documentation, and OpenSpec artifacts. Push immediately to the corresponding repository's `main` branch without waiting for a separate “帮我推送” instruction. Push the main and admin repositories independently when both changed.
4. Stop and report instead of forcing a push when there is a merge conflict, remote divergence requiring judgment, missing permission, failed required validation, suspected secret, or unclear ownership of overlapping user changes.
5. Determine deployment surfaces from the committed files. End every completed code delivery with the pushed commit hash, validation result, and exact server deployment commands for each affected service. State explicitly when no server deployment is needed.
6. Package an Android APK when the change affects `mobile/` runtime behavior, UI, dependencies, Android configuration, or the user otherwise needs an installable build. Skip APK work for backend/admin/docs/OpenSpec-only changes unless explicitly requested.

Before every new APK package, increment `version:` in `mobile/pubspec.yaml`. Treat `major.minor.patch+build` as the source of truth: increment the build number by at least one for every APK, never reuse or decrease a published build number, and increment the semantic patch/minor/major component as appropriate for a named product release. Commit this version bump with the mobile change before pushing. Pass the exact full pubspec value through `APP_VERSION`; Android `versionName` and `versionCode` continue to come from Flutter's pubspec integration.

Build only the production API flavor, copy a delivery APK to `dist/jiandi-<full-version>-release.apk`, and verify both manifest version and signature. Do not commit `dist/` unless explicitly requested. If a required production build secret such as `RUNTIME_LOG_TOKEN` is unavailable, do not invent it or claim a final distributable package; report the packaging blocker while still completing safe source validation and push when appropriate.

## Production server topology

These are the documented/current deployment locations. Verify with SSH before making destructive or production mutations:

- API checkout: `/root/DeepTravel`
- Independent admin checkout: `/root/DeepTravel-admin`
- Public API: `http://115.29.221.190:5001/api/v1`
- Admin/runtime-log service: `http://115.29.221.190:5100`
- API health: `GET /api/v1/health`
- Admin health: `GET /api/admin/health` with admin bearer token
- Client runtime-log receiver: `POST /api/runtime/client-logs` on port 5100
- API container media mount: host `${MEDIA_HOST_PATH}` -> `/app/media`
- API private evidence volume: `jiandi_evidence` -> `/app/private-evidence`
- MySQL data volume: `jiandi_mysql` -> `/var/lib/mysql` inside MySQL container
- Local API port mapping: host `5001` -> container `5000`
- Local MySQL port mapping: host `3307` -> container `3306`
- Admin port mapping: host `5100` -> container `5100`

Production API update/deploy (run on the server):

```bash
cd /root/DeepTravel
git fetch origin main
git checkout main
git pull --ff-only origin main
docker compose build api
docker compose run --rm api alembic upgrade head
docker compose up -d mysql api
docker compose ps
curl -fsS http://127.0.0.1:5001/api/v1/health
```

Production admin update/deploy:

```bash
cd /root/DeepTravel-admin
git fetch origin main
git checkout main
git pull --ff-only origin main
docker compose up -d --build
docker compose ps
curl -fsS -H "Authorization: Bearer ${ADMIN_TOKEN}" http://127.0.0.1:5100/api/admin/health
```

Do not run `docker compose down -v`; that deletes persistent MySQL/evidence volumes. Use normal restart/rebuild operations. Do not print `.env`, bearer tokens, OSS secrets, or TTS keys into chat, logs, commits, or this Skill.

## Content, media, and narration workflow

Add new cities/scenic areas through `Travel-Admin` content configuration and the content-package publishing tool; do not add city-specific Flutter code. The safe lifecycle is draft/review -> validated -> approved -> published. Only published routes/fragments/profiles can appear on the client.

For a new package:

1. Put a versioned JSON package under `docs/content-packages/` and media under `backend/media/` only when local media is intended.
2. Start admin/API, load admin `.env` into the shell without displaying it, and run `tools/publish_content_package.py` with `ADMIN_API_BASE=http://127.0.0.1:5100`.
3. Let the tool perform SHA-256 idempotency checks, media upload, import, validation, review, approval, and explicit publication.
4. Verify the public route endpoint and every image/audio URL before packaging the client.

Production content command:

```bash
cd /root/DeepTravel
set -a
. /root/DeepTravel-admin/.env
set +a
ADMIN_API_BASE=http://127.0.0.1:5100 \
python3 tools/publish_content_package.py \
  docs/content-packages/<package>.json
```

Use OSS for public/private media when configured. Keep MySQL as metadata/object-key storage; do not put credentials in Git. API local media is `/app/media`; private evidence is authenticated and should not be served from the public assets endpoint.

Narration is route-wide by voice profile. The admin generates all missing tracks for a selected scenic route/profile, stores them, validates coverage, and publishes the profile. The client reads profiles from `data.audio_tour.narration_profiles` and lets the traveler choose; it must not contain voice IDs or city-specific profile constants. The default Dameisha route ID observed in production is `91608e67-dbad-4d26-889c-dd3089201003`; verify IDs from the API rather than assuming them.

## Local toolchain and mirrors

Known installed paths on the development Mac:

- Flutter 3.47.1: `/Users/li/tools/flutter-3.47.1/bin/flutter`
- Flutter engine artifacts, including iOS release framework: `/Users/li/tools/flutter-3.47.1/bin/cache/artifacts/engine/ios-release/Flutter.xcframework`
- Android SDK: `/opt/homebrew/share/android-commandlinetools`
- Android SDK platforms: `/opt/homebrew/share/android-commandlinetools/platforms/android-35` and `android-36`
- Android NDK: `/opt/homebrew/share/android-commandlinetools/ndk/28.2.13676358`
- Android build tools: `/opt/homebrew/share/android-commandlinetools/build-tools/36.0.0`
- Android `aapt`/`apksigner`: same build-tools directory
- OpenJDK 17 with `jlink`: `/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home`; set `JAVA_HOME` to this path for Gradle/Flutter Android builds
- Xcode: `/Applications/Xcode.app`; developer directory `/Applications/Xcode.app/Contents/Developer`
- CocoaPods 1.16.2: executable `/Users/li/.local/bin/pod`; gems `/Users/li/.local/share/gem/cocoapods`; when invoking, set `GEM_HOME` and `GEM_PATH` to that gem directory and put the portable Ruby directory on `PATH`
- Dart packages: `/Users/li/.pub-cache/hosted/pub.flutter-io.cn`
- Gradle caches/wrapper: `/Users/li/.gradle`; current Gradle wrapper cache includes Gradle 9.3.1
- Homebrew: `/opt/homebrew/bin/brew`

Use mirrors for Flutter/Dart/Android/Ruby/Homebrew dependencies:

```bash
export PUB_HOSTED_URL=https://mirrors.tuna.tsinghua.edu.cn/dart-pub/
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
export HOMEBREW_API_DOMAIN=https://mirrors.aliyun.com/homebrew/homebrew-bottles/api
export HOMEBREW_BOTTLE_DOMAIN=https://mirrors.aliyun.com/homebrew/homebrew-bottles
```

For CocoaPods installed in the known local Gem directory:

```bash
export GEM_HOME=/Users/li/.local/share/gem/cocoapods
export GEM_PATH=/Users/li/.local/share/gem/cocoapods
export PATH="/Users/li/.local/bin:/opt/homebrew/Library/Homebrew/vendor/portable-ruby/current/bin:$PATH"
export COCOAPODS_DISABLE_STATS=true
```

Do not invoke Xcode's `xcodebuild -downloadPlatform` automatically. As of the last verified build, Xcode reported version 26.3, showed an iPhoneOS 26.2 SDK at `/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk`, but reported the iOS platform as not installed for generic device destinations; `security find-identity -v -p codesigning` reported zero valid identities. This means a signed device IPA is not guaranteed on this machine. The user explicitly rejected unrequested SDK installation; explain this blocker and ask before installing Apple components. iPhone 16 compatibility is covered by the universal iOS target and deployment target 15.0 once Xcode signing/platform state is valid.

## Release builds

Read the current version from `mobile/pubspec.yaml`, increment it before each APK as described above, and use that same full value for the build define and artifact name. Always build the API production flavor with the server endpoint, not demo data:

```bash
cd /Users/li/Downloads/Project/Travel/mobile
export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
export PUB_HOSTED_URL=https://mirrors.tuna.tsinghua.edu.cn/dart-pub/
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
/Users/li/tools/flutter-3.47.1/bin/flutter build apk --release \
  --dart-define=APP_MODE=api \
  --dart-define=API_BASE_URL=http://115.29.221.190:5001/api/v1 \
  --dart-define=DEFAULT_CITY_SLUG=shenzhen \
  --dart-define=RUNTIME_LOG_ENDPOINT=http://115.29.221.190:5100/api/runtime/client-logs \
  --dart-define=RUNTIME_LOG_TOKEN=${RUNTIME_LOG_TOKEN} \
  --dart-define=APP_VERSION=<FULL_VERSION_FROM_PUBSPEC> \
  --dart-define=TEST_AUTH_ENABLED=false
```

Copy `mobile/build/app/outputs/flutter-apk/app-release.apk` to `dist/jiandi-<full-version>-release.apk` only as a delivery artifact. Verify that `versionName` and `versionCode` match `mobile/pubspec.yaml`, then verify the signature with:

```bash
/opt/homebrew/share/android-commandlinetools/build-tools/36.0.0/aapt dump badging dist/jiandi-<full-version>-release.apk
/opt/homebrew/share/android-commandlinetools/build-tools/36.0.0/apksigner verify --verbose --print-certs dist/jiandi-<full-version>-release.apk
```

For iOS, first use the normal Flutter/Xcode flow only after the platform and signing state are available:

```bash
cd /Users/li/Downloads/Project/Travel/mobile
export PUB_HOSTED_URL=https://mirrors.tuna.tsinghua.edu.cn/dart-pub/
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
flutter build ipa --release <same production dart-defines>
```

Do not claim an installable IPA if the archive is unsigned or if Xcode reports no eligible generic iOS destination. An unsigned `.app`/IPA can be useful for inspection but cannot be installed on a normal iPhone without signing.

## Diagnostics and validation

For backend/admin logs:

```bash
cd /root/DeepTravel
docker compose logs -f --tail=200 api
cd /root/DeepTravel-admin
docker compose logs -f --tail=200 admin-api
```

The admin log page reads API and client runtime sources from port 5100. If the page does not update, check the browser's polling/SSE request and the admin container logs; do not assume the client action did not reach the server.

For a client route/voice issue, verify in order: `GET /api/v1/routes/<slug>` returns published data; `data.audio_tour.narration_profiles` has the expected profiles; every fragment has a track for the selected profile; audio URLs return `206`/`200` with an audio content type; then force refresh/re-enter the route. The Flutter route provider is auto-dispose and the repository must not retain an indefinite route cache.

Run proportionate checks after changes:

```bash
cd backend && ruff check app tests && pytest
cd ../mobile && dart format --output=none --set-exit-if-changed lib test && flutter analyze && flutter test
openspec validate <change-name> --strict
```

Use OpenSpec for feature changes: create/update proposal, design, delta specs, and tasks before implementation when the user requests that workflow; then apply the change, validate, commit, and push the correct repository branch under the standing delivery workflow above.

## Safety and project invariants

- Keep `TEST_AUTH_ENABLED=false` in production builds and production server configuration.
- Preserve the always-visible real/simulated location switch; simulated arrival is a temporary test capability, not a reason to remove real positioning.
- Keep routes/content/media server-driven. Avoid adding fixed city names, image paths, audio paths, voice IDs, or route progress to Flutter.
- Only published content is online-visible; `in_review`/`verified`/draft semantics must be checked against the current admin/API lifecycle before changing status logic.
- Do not expose or commit `.env`, `MINIMAX_API_KEY`, `ADMIN_TOKEN`, `OSS_ACCESS_KEY_SECRET`, JWT secrets, or database passwords. The Skill intentionally records names/locations, not secret values.
- Do not delete MySQL/evidence volumes, production media, or generated audio to “clean up” without explicit scope and a backup/rollback plan.
- Preserve user changes and inspect `git diff`/`git status` before committing. Push `DeepTravel` and `DeepTravel-admin` independently to their own `main` branches.

## Canonical project documents

Read these when the task needs more detail:

- `README.md`: architecture, API summary, local development, known MVP boundaries.
- `docs/deployment-production.md`: idempotent server deployment, OSS migration, content publication.
- `docs/content-management.md`: content lifecycle and admin editing model.
- `docs/implementation-design.md`: MVP implementation design.
- `docs/verification.md`: verification evidence and release checks.
- `openspec/specs/` and `openspec/changes/`: behavior contracts and change-specific plans.
- `/Users/li/Downloads/Project/Travel-Admin/README.md`: admin deployment, logs, reverse proxy, and runtime API details.
