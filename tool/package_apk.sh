#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Package only a real, successfully built APK. Never package resource-only files.
apk=build/app/outputs/flutter-apk/app-release.apk
test -s "$apk"
sdk_dir=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-/workspace/tools/android-sdk}}
"$sdk_dir/build-tools/36.0.0/apksigner" verify "$apk"
permissions_file=$(mktemp)
trap 'rm -f "$permissions_file"' EXIT
"$sdk_dir/build-tools/36.0.0/aapt2" dump permissions "$apk" > "$permissions_file"
python3 - "$permissions_file" <<'PY'
import pathlib,sys
assert 'android.permission.INTERNET' not in pathlib.Path(sys.argv[1]).read_text(), 'Packaged APK has INTERNET permission'
PY
mkdir -p dist
cp "$apk" dist/FLUX.apk
(cd dist && sha256sum FLUX.apk > FLUX.apk.sha256)
python3 - <<'PY'
import zipfile
with zipfile.ZipFile('dist/FLUX-download.zip','w',zipfile.ZIP_DEFLATED) as archive:
    archive.write('dist/FLUX.apk','FLUX.apk')
    archive.write('dist/FLUX.apk.sha256','FLUX.apk.sha256')
PY
printf '%s\n' 'Verified APK: dist/FLUX.apk' 'ZIP alternative: dist/FLUX-download.zip'
