#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tool/check_offline.py
bash tool/test_reminder_time.sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
bash tool/package_apk.sh
