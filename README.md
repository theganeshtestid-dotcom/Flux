# FLUX

Flutter Android student planner using the approved V3-inspired light and dark themes. All academic data stays in a local SQLite database. No account, backend, analytics, backup/restore or INTERNET permission.

## Development

Install Flutter stable (the source scaffold uses Flutter commit `737ba8f885dc774b53b442759999a312c9461e4e`), Android SDK 36, Java 17+ and accept Android SDK licenses. Minimum Android API 24. The Android project uses Gradle 9.3.1, AGP 9.1.0, Kotlin 2.4.0 and core-library desugaring.

From this checkout:

```sh
flutter pub get
flutter analyze
flutter test
flutter run --release -d <android-device-id>
flutter build apk --release
bash tool/package_apk.sh
```

Use an attached Android device/emulator; native database, notifications and sharing do not target web. Without INTERNET permission, use release mode for on-device testing. The release variant currently uses the development debug signing key; configure a private signing key before distribution. Do not commit keys or `android/local.properties`.

## Implemented source

- Exactly four tabs: Home, Academics, Study, Profile. Four Quick Add forms: Subject, Assignment, Study Session, Exam.
- Subject and weekly-class management, time validation and overlap confirmation. Historical attendance survives subject/class deletion with stored labels.
- Present/Absent recording and correction, consistent recorded-only percentages. Dated timetable supports past occurrences.
- Assignment completion and date-based status, exam CRUD; manual study entry/history with positive durations.
- SQLite atomic document saves; failed writes roll back in-memory changes. Startup integrity check, damaged-file preservation and fresh-database recovery; unrelated access failures offer retry rather than reset.
- Five permanent badges; Monday–Sunday Weekly Recap and local progress-image sharing.
- Android local reminders 30 minutes before the device-local deadline (09:00 if no time specified). Android persists the civil deadline and recalculates alarms after timezone/clock changes and reboot. Optional exact-alarm access, inexact fallback, contextual notification permission, and per-channel permission checks. Edits, completion, deletion and global disablement replace/cancel alarms.
- System/Light/Dark appearance persisted locally. Local error log with clear confirmation.

## Verification status

The SDK download is blocked by the running environment's network policy for `storage.googleapis.com`. Flutter dependency resolution, analysis, tests and APK compilation have **not run**. Unit and widget tests are included but not yet verified. No installable APK has been produced. Allow the Flutter download host in environment settings, then run the commands above and resolve any reported issues before treating the app as ready.

Required device checks: CRUD and restart persistence; attendance correction across all summaries; badge permanence; airplane-mode workflows; notification denial/regrant and reboot; local reminder replacement/cancellation; share success/cancel/failure; missing/corrupted database recovery; large text and both themes. No device tests have run yet.

## Design

`design/index.html` is the approved proposal with theme previews. `design/USER_FLOW.md` records requirements and repository research. The Flutter app starts empty; it does not seed the mockups' illustrative data.

## Audit and focused verification

See [AUDIT.md](AUDIT.md) for repairs and explicit verification limits. `bash tool/test_reminder_time.sh` runs 9 native time tests without Flutter. `bash tool/verify.sh` runs the complete intended pipeline once SDK access is available. Only after a successful full build will `dist/FLUX.apk` and `dist/FLUX-download.zip` exist. Neither exists yet. Android SDK 36 is installed at `/workspace/tools/android-sdk`; Flutter remains blocked at SDK download.
