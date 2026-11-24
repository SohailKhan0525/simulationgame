#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
repo_root="$PWD"
godot_bin="${GODOT_BIN:-godot}"
: "${ANDROID_HOME:?Set ANDROID_HOME to the Android SDK directory.}"
: "${JAVA_HOME:?Set JAVA_HOME to the JDK 17 directory.}"
: "${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:?Set the private release keystore password. Debug signing is never used.}"
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-$repo_root/signing/qofeno-release.keystore}"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="${GODOT_ANDROID_KEYSTORE_RELEASE_USER:-qofeno}"
test -s "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH"
mkdir -p build game/addons/qofeno_updater

# Use the same Gradle/Android toolchain versions as the Godot 4.5.1 template.
"${GRADLE_BIN:-gradle}" -p android-plugin --no-daemon assembleRelease
cp android-plugin/build/outputs/aar/qofeno-updater-release.aar game/addons/qofeno_updater/QofenoUpdater.aar

# Editor SDK paths are host settings; keep them out of version control.
python3 - <<'PY'
import os
from pathlib import Path
config = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config'))) / 'godot'
config.mkdir(parents=True, exist_ok=True)
def escaped(value):
    return value.replace('\\', '/').replace('"', '\\"')
(config / 'editor_settings-4.5.tres').write_text(
    '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
    + 'export/android/android_sdk_path="' + escaped(os.environ['ANDROID_HOME']) + '"\n'
    + 'export/android/java_sdk_path="' + escaped(os.environ['JAVA_HOME']) + '"\n')
PY
"$godot_bin" --headless --path game --editor --import --quit 2>&1 | tee build/import.log
if grep -Eq 'SCRIPT ERROR:|Parse Error:|Failed to load script' build/import.log; then
  echo 'Godot import reported script errors.' >&2
  exit 1
fi
python3 tools/configure_texture_imports.py --check
python3 tools/validate_art_assets.py
"$godot_bin" --headless --path game --install-android-build-template --export-release Android "$repo_root/build/Qofeno-Drive.apk"

# Fail the release if package identity, SDK, versions, ABI contents or signing differ.
build_tools="$ANDROID_HOME/build-tools/35.0.0"
"$build_tools/apksigner" verify --verbose --print-certs build/Qofeno-Drive.apk > build/signature.txt
"$build_tools/aapt" dump badging build/Qofeno-Drive.apk > build/package.txt
"$JAVA_HOME/bin/keytool" -exportcert -keystore "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" \
  -alias "$GODOT_ANDROID_KEYSTORE_RELEASE_USER" -storepass:env GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD \
  -file build/signing-certificate.der
unzip -tq build/Qofeno-Drive.apk
python3 tools/build-manifest.py
