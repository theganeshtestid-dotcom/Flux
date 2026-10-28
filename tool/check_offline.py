"""Check source manifests. Inspect the merged APK separately before release."""
from pathlib import Path
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
manifests = list((root / 'android/app/src').rglob('AndroidManifest.xml'))
assert manifests, 'No Android manifest found'
android = '{http://schemas.android.com/apk/res/android}'
for path in manifests:
    tree = ET.parse(path)
    permissions = [p.get(android + 'name') for p in tree.findall('uses-permission')]
    assert 'android.permission.INTERNET' not in permissions, path
app = ET.parse(root / 'android/app/src/main/AndroidManifest.xml').find('application')
assert app is not None and app.get(android + 'allowBackup') == 'false'
print(f'PASS: {len(manifests)} source manifest(s), no INTERNET permission; Android backup disabled.')
