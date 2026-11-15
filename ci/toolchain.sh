#!/usr/bin/env bash
set -euo pipefail
version=4.6.3-stable
base="https://github.com/godotengine/godot-builds/releases/download/$version"
stage="$RUNNER_TEMP/qofeno-tools"
target="$HOME/.local/share/godot/export_templates/4.6.3.stable"
mkdir -p "$stage" "$target"
cd "$stage"
curl --fail --location --retry 3 "$base/Godot_v${version}_linux.x86_64.zip" -o editor.zip
curl --fail --location --retry 3 "$base/Godot_v${version}_export_templates.tpz" -o templates.tpz
echo 'd0bc2113065e481c9c2c2b2c37daa4e8be3fe9e27f0ab9ab0b6096e9a37907f3  editor.zip' | sha256sum -c -
echo '3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8  templates.tpz' | sha256sum -c -
unzip -q editor.zip
mv Godot_v${version}_linux.x86_64 godot
unzip -jq templates.tpz templates/android_debug.apk templates/android_release.apk templates/version.txt -d "$target"
echo "$stage" >> "$GITHUB_PATH"
