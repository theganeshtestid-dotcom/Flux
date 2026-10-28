#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
classes_dir=$(mktemp -d)
trap 'rm -rf "$classes_dir"' EXIT
java -m jdk.compiler/com.sun.tools.javac.Main -d "$classes_dir" \
  android/app/src/main/java/com/flux/studentplanner/ReminderTime.java \
  test/native/ReminderTimeTest.java
java -cp "$classes_dir" ReminderTimeTest
