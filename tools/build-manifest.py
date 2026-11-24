"""Verify the built APK's metadata and publish the updater's pinned manifest."""
import hashlib
import json
import re
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parent.parent
build = root / 'build'
version = json.loads((root / 'game/version.json').read_text())
badging = (build / 'package.txt').read_text()
signature = (build / 'signature.txt').read_text()
assert "package: name='com.qofeno.drive'" in badging, 'Unexpected package identity'
assert f"versionCode='{version['version_code']}'" in badging, 'Version code differs from game metadata'
assert f"versionName='{version['version']}'" in badging, 'Version name differs from game metadata'
assert "sdkVersion:'26'" in badging, 'Unexpected minimum Android SDK'
assert "targetSdkVersion:'35'" in badging, 'Unexpected target Android SDK'
assert re.search(r'Verified using v[23](?:\.[0-9]+)? scheme .*: true', signature), 'APK lacks modern signature'
expected_signer = hashlib.sha256((build / 'signing-certificate.der').read_bytes()).hexdigest()
assert f'Signer #1 certificate SHA-256 digest: {expected_signer}' in signature, 'APK signing key differs from the persistent release key'
apk = build / 'Qofeno-Drive.apk'
with zipfile.ZipFile(apk) as archive:
    names = archive.namelist()
    for abi in ('arm64-v8a', 'x86_64'):
        assert any(name.startswith(f'lib/{abi}/') and 'godot' in name for name in names), f'Missing {abi} player'
    dex_names = [name for name in names if re.fullmatch(r'classes\d*\.dex', name)]
    assert dex_names, 'Missing Android Java bytecode'
    assert any(b'Lcom/qofeno/drive/QofenoUpdater;' in archive.read(name) for name in dex_names), 'Missing native update plugin'
digest = hashlib.sha256(apk.read_bytes()).hexdigest()
(build / 'Qofeno-Drive.apk.sha256').write_text(f'{digest}  Qofeno-Drive.apk\n')
manifest = {
    **version,
    'package': 'com.qofeno.drive',
    'url': f"https://github.com/SohailKhan0525/simulationgame/releases/download/v{version['version']}/Qofeno-Drive.apk",
    'sha256': digest,
    'size': apk.stat().st_size,
    'min_android': 26,
}
(build / 'update.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(f"Verified Qofeno Drive {version['version']}: {apk.stat().st_size} bytes, SHA-256 {digest}")
