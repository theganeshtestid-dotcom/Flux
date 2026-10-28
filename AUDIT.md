# FLUX audit and repairs

What this repo does: FLUX is a Flutter Android planner with on-device academic records, weekly class recurrence, attendance, study history and reminders. The expected load is one student using one phone, including rapid taps, device clock changes, restarts, and denied permissions.

Review references: [Ponytail whole-repo audit](https://github.com/DietrichGebert/ponytail/blob/main/skills/ponytail-audit/SKILL.md), [Superpowers systematic debugging](https://github.com/obra/superpowers/blob/main/skills/systematic-debugging/SKILL.md), and the gstack review checklist. The relevant downloaded instructions were read; installers, agent hooks and external telemetry were not enabled. The user's request to repair issues extends Ponytail's report-only audit scope.

## Must fix — source repairs applied, full Flutter verification pending

1. **Reminder lead time was wrong** (`lib/reminders.dart`, `ReminderTime.java`). The source subtracted one hour; the requirement is 30 minutes. Android now calculates the trigger from the selected local deadline minus 30 minutes. A 14:00 assignment targets 13:30.
2. **Timezone changes could leave old UTC alarms** (`ReminderScheduler.kt`, manifest). A fixed UTC instant did not follow a later device timezone change while FLUX was closed. Android now persists the civil date and minute, recalculates with the device's ZoneId, and handles timezone, clock, reboot and app-update broadcasts. DST offsets come from Java's timezone rules. Nonexistent DST wall times shift forward; ambiguous times use the earlier valid offset.
3. **Rapid attendance taps could duplicate a class occurrence** (`lib/data.dart`). Lookup happened before entering the write queue, so two taps could both insert. Lookup and upsert now happen together inside the serialized operation. Present/Absent changes preserve one occurrence and its saved historical subject, teacher and time.
4. **Future attendance could inflate totals** (`lib/main.dart`, `lib/data.dart`). The timetable permitted marking a future date. Future buttons are now disabled and the store rejects future marks as well.
5. **New schedules appeared before their creation** (`ClassForm`, `todayClasses`). A weekday matched every past date indefinitely. New classes now have an explicit first date and recur weekly from it. No class is automatically marked absent. Existing records without a first date retain their original recurrence behavior.
6. **No branded splash screen** (Android resources, `Bootstrap`). The default startup background had no logo. The original logo is now used by pre-Android-12 and Android-12+ launch themes and during Flutter database initialization. Approved light/dark background colors are retained. AAPT2 compiled and linked these resources successfully.
7. **Weekly calendar arithmetic crossed DST incorrectly** (`calendarDays`, recap). Adding elapsed 24-hour durations can produce 23:00/01:00 week boundaries. Civil dates now use calendar components for Monday boundaries and recap navigation.
8. **Channel-level notification denial was invisible** (`ReminderScheduler`, `MainActivity`). Android can disable a notification channel while global notification status stays enabled. Permission status now checks both, opens system notification settings when appropriate, and exposes optional precise-alarm access with inexact fallback.
9. **Native background scheduling errors could be hidden** (`Reminders`, native bridge). Receiver errors are saved locally and copied into FLUX's error log on the next sync. Scheduling errors do not remove the academic record or crash the app.

## Should fix — source repairs applied

10. **Timetable omitted teacher and subject attendance context** (`classCard`, subject detail). Teacher labels now appear beside classes. Subject detail shows that subject's recorded-only attendance; historical labels survive subject deletion.
11. **Attendance and day summaries could remain on yesterday's date** (`PlannerHome`). A long-running foreground screen had no midnight refresh. It now checks the local day periodically and refreshes on resume; unmarked classes still never become absences.
12. **Save/back and duplicate class-save races** (forms). Leaving while a save was pending could dispose the form; repeated save taps could open multiple overlap warnings. Save operations now block navigation and re-entry. Inputs remain visible after storage errors.
13. **Small-screen and large-text sheets could overflow** (Quick Add, subject detail). Sheets now scroll. The four tabs, four Quick Add types and five badges remain unchanged.
14. **No verified artifact packaging path** (`tool/package_apk.sh`). No APK had actually been built; earlier source archives were not installable apps. The new packaging step accepts only a real release APK, verifies its signature, rejects INTERNET permission in the packaged manifest, and produces `dist/FLUX.apk`, a checksum and `dist/FLUX-download.zip`. It has not run because there is no compiled APK yet. It does not fix a client download UI that has not been exercised.

## Reminder lifecycle

- New or edited assignments/exams replace persisted alarm plans. Completion, deletion and global disablement cancel alarms and visible notifications on sync.
- Deadlines without a selected time use 09:00 device-local time, with an 08:30 target reminder.
- A new deadline less than 30 minutes away gets one immediate reminder if the deadline is still future. Past deadlines do not generate stale reminders.
- Permission denied or channel disabled: records still save; alarms stay inactive until permission is restored and the app syncs.
- Exact alarm access allows `setExactAndAllowWhileIdle`; otherwise the app uses inexact alarms and explains possible Android delays. Battery policies, force-stop, permission revocation and OEM restrictions prevent a universal exact-delivery guarantee.
- Notifications display the deadline itself, avoiding a misleading “in 30 minutes” message after Android delays delivery.

## Evidence from this run

Passed:

- 9 executable Java tests against the production `ReminderTime` class: 14:00→13:30, India/New York/London, timezone offsets, previous-day midnight reminder, spring/fall DST, invalid minutes.
- Native scheduler Kotlin compilation against real Android API 36 and generated resources. The activity reference used a compile-boundary stub; this is not the full Flutter Android build.
- Android AAPT2 resource compilation/linking, including light/dark and Android 12+ logo splash resources.
- Source manifest check: no INTERNET permission; Android backup disabled.
- 10 Android XML files parsed; 8 Dart source/test files passed syntax parsing. These do not replace Flutter analysis.

Added but **not executed**:

- 14 Flutter tests covering calculations, tabs/Quick Add, form validation, theme colors, atomic attendance marking, recurrence, historical labels, rollback, and reminder bridge lifecycle. Database-boundary tests use a failure-capable fake and do not prove on-device SQLite persistence.

Not checked:

- Flutter dependency resolution, static analysis, tests, full Android build, APK signing/installability, actual light/dark Flutter rendering, airplane-mode device workflows, real alarm delivery, clock-change broadcasts on device, reboot/force-stop behavior, Android permission dialogs, SQLite recovery on-device, and share-sheet behavior.
- No Android emulator or device is attached. `adb devices` returned an empty list.

Verdict: the identified source defects have repairs and targeted checks, but the app is **not release-verified**. The current environment still blocks `storage.googleapis.com`, which Flutter needs to download Dart/engine artifacts. The required host was saved to the environment draft previously; it is absent from the running enforced policy. No full APK has been generated, and no working-APK download can honestly be provided yet.

## Subsequent APK build verification

[Run 40701612515](https://github.com/theganeshtestid-dotcom/Flux/actions/runs/40701612515) passed for `8e59bf3fa2aa337c0269b9e1f00647110dd6880d`. Flutter analysis, the Flutter test suite, release APK compilation, signature verification and packaged permission inspection now pass. Dart statement-block diagnostics found during this run were fixed without weakening the analysis gate. The earlier unrun statuses above describe the initial local audit and are superseded for those checks. Actual device notification delivery and other device workflows remain untested.

[Download the APK artifact](https://github.com/theganeshtestid-dotcom/Flux/actions/runs/40701612515/artifacts/12822346920); GitHub sign-in is required. It contains `dist/FLUX.apk`, checksums and the build output. The build uses a development signing key.
