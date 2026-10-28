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

## APK download and verification

The GitHub Actions build passed for source commit `8e59bf3fa2aa337c0269b9e1f00647110dd6880d`.

[Download APK bundle](https://github.com/theganeshtestid-dotcom/Flux/actions/runs/40701612515/artifacts/12822346920) (sign in to GitHub). Extract the ZIP and install `dist/FLUX.apk`. The bundle also contains the APK checksum, an alternative ZIP, and the build log.

[Successful build](https://github.com/theganeshtestid-dotcom/Flux/actions/runs/40701612515): source manifest check, 9 native reminder-time checks, Flutter dependency resolution, Flutter analysis, Flutter tests, release APK compilation, APK signature verification, and packaged INTERNET-permission rejection all passed. The APK uses a development signing key; it is for testing, not a store release.

No Android device was attached. Actual alarm delivery, permission dialogs, reboot behavior, airplane-mode workflows, SQLite recovery and the native share sheet still require phone testing. A successful build does not establish those device outcomes.

The local cloud environment still blocks Flutter SDK downloads, so compilation was performed on GitHub's runner using the build-only workflow with read-only repository permissions.

## Design

`design/index.html` is the approved proposal with theme previews. `design/USER_FLOW.md` records requirements and repository research. The Flutter app starts empty; it does not seed the mockups' illustrative data.

## Audit and focused verification

See [AUDIT.md](AUDIT.md) for repairs and explicit verification limits. `bash tool/test_reminder_time.sh` runs 9 native time tests without Flutter. `bash tool/verify.sh` runs the complete intended pipeline once SDK access is available. The successful GitHub artifact contains `dist/FLUX.apk` and `dist/FLUX-download.zip`; they were built on GitHub, not in this local checkout. Android SDK 36 is installed at `/workspace/tools/android-sdk`; Flutter remains blocked at SDK download.
