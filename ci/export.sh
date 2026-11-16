#!/usr/bin/env bash
set -euo pipefail
mode=${1:?debug or release}
engine=${GODOT:-godot}
version=$(sed -n 's/^config\/version="\([^"]*\)"/\1/p' project.godot)
grep -Fxq "version/name=\"$version\"" export_presets.cfg
code=$(sed -n 's/^version\/code=//p' export_presets.cfg)
package=com.qofeno.simulation
name="Qofeno-Simulation-$version"
case "$mode" in
  debug)
    name+="-internal"
    package+=.internal
    sed -i "s/com.qofeno.simulation\"/$package\"/" export_presets.cfg
    key_dir=$(mktemp -d "$RUNNER_TEMP/qofeno-key.XXXXXX")
    trap 'sed -i "s/com.qofeno.simulation.internal\"/com.qofeno.simulation\"/" export_presets.cfg; rm -f "$key_dir/debug.keystore"; rmdir "$key_dir"' EXIT
    export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$key_dir/debug.keystore"
    export GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey
    GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=$(python3 -c 'import secrets; print(secrets.token_hex(24))')
    export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD
    keytool -genkeypair -noprompt -keystore "$GODOT_ANDROID_KEYSTORE_DEBUG_PATH" \
      -storepass:env GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD -keypass:env GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD \
      -alias "$GODOT_ANDROID_KEYSTORE_DEBUG_USER" -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Qofeno Internal"
    ;;
  release)
    [[ "${GITHUB_REF_NAME:-}" == "v$version" ]] || { echo 'Tag must match project version'; exit 1; }
    : "${SIGNING_STORE_B64:?Missing persistent release keystore}" "${GODOT_ANDROID_KEYSTORE_RELEASE_USER:?}" "${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:?}" "${RELEASE_CERT_SHA256:?}"
    umask 077
    export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$RUNNER_TEMP/release.keystore"
    trap 'rm -f "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH"' EXIT
    printf %s "$SIGNING_STORE_B64" | base64 -d > "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH"
    ;;
  *) exit 2 ;;
esac
settings="${XDG_CONFIG_HOME:-$HOME/.config}/godot"
mkdir -p "$settings" build
cat > "$settings/editor_settings-4.6.tres" <<SETTINGS
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$ANDROID_HOME"
export/android/java_sdk_path = "$JAVA_HOME"
SETTINGS
apk="build/$name.apk"
"$engine" --headless "--export-$mode" Android "$apk"
test -s "$apk"
python3 - "$apk" <<'PYZIP'
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as apk:
    for name in apk.namelist():
        if name.lower().endswith((".zip", ".7z", "gameassembly.dll", "global-metadata.dat", ".bundle")):
            raise SystemExit(f"Unexpected reference content in APK: {name}")
PYZIP
bt="$ANDROID_HOME/build-tools/35.0.1"
"$bt/apksigner" verify --verbose --print-certs "$apk" > build/signature.txt
if [[ "$mode" == release ]]; then
  grep -Fxiq "Signer #1 certificate SHA-256 digest: $RELEASE_CERT_SHA256" build/signature.txt
fi
"$bt/aapt" dump badging "$apk" > build/package.txt
grep -F "name='$package' versionCode='$code' versionName='$version'" build/package.txt
(cd build && sha256sum "$name.apk" > "$name.apk.sha256")
git rev-parse HEAD > build/commit.txt
python3 ci/release_manifest.py "$mode"
