# Vaccinators App — Flutter project (v1)

EPI District Chakwal · 70 vaccinators · free APK, no Play Store.

## Run locally (needs Flutter SDK)

```bash
flutter pub get
flutter analyze
flutter run            # on a connected Android phone / emulator
flutter build apk --release   # output: build/app/outputs/flutter-apk/app-release.apk
```

## Verification (19 Nov 2026, this VM)
- `flutter pub get` — PASS (103 dependencies, `pubspec.lock` pinned).
- `flutter analyze` — **No issues found!**
- Local `flutter build apk` — BLOCKED by this VM's sandbox (Gradle daemon
  IPC over localhost fails here even for a trivial Gradle project;
  `gradlew --version` works). This is environmental, not a code defect —
  GitHub Actions is the build path (see goal `README.md` Step 3).

## Versioning

Bump **both** files together on every release:

- `pubspec.yaml` — `version: 1.0.0+1` (versionName+versionCode)
- `android/app/build.gradle.kts` — `versionCode = 1`, `versionName = "1.0.0"`

Then update `version.json` on the EPI site (see goal `README.md` Step 4).

## Structure

```
lib/
  main.dart            # app shell, 4 bottom tabs, update check, queue sync
  config.dart          # endpoints, colours, rules (10 AM cutoff, leave limits)
  models/              # Vaccinator (roster row), PendingItem (offline queue)
  services/
    api_service.dart       # single POST + gviz reads + verify-before-success
    storage_service.dart   # login, roster cache, offline queue
    sync_service.dart      # flush queue one-by-one, in order
    location_service.dart  # GPS + Workmanager background (30 min)
    update_service.dart    # version.json check on the EPI site
  screens/             # login, home, location, report, leave,
                       # notifications, profile, admin map, admin late list
  widgets/common.dart  # big buttons, status chips, info boxes
android/               # manifest (location background + internet + camera),
                       # build.gradle.kts (debug-signed release for sideloading)
```

## Backend honesty

- `location` + `leave` work today against the existing Apps Script endpoint.
- `dailyReport`, `zeroEntry` (+ `checkin`/`checkout` as separate types) are
  **new payload types** — the app queues them and says "queued", never
  "submitted", until the script adds them. Check-In/Out are sent as
  `type: 'location'` + `event: 'checkin'/'checkout'` so they verify today.
- Verify-before-success: no screen says "Submitted" until the row is
  found back in the sheet (username + timestamp, fallback ±60 s + GPS pin).
