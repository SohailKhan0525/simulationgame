#!/usr/bin/env bash
# Hosted runner, disposable AVD. Capture the installed app's own framebuffer.
set -euo pipefail
out="${RUNNER_TEMP}/qofeno-device"
mkdir -p "$out" build/device
sdk="$ANDROID_HOME/cmdline-tools/latest/bin"
adb="$ANDROID_HOME/platform-tools/adb"
package=${1:-com.qofeno.simulation.internal}
image='system-images;android-35;default;x86_64'
export ANDROID_USER_HOME="$RUNNER_TEMP/qofeno-android-user"
export ANDROID_AVD_HOME="$ANDROID_USER_HOME/avd"
mkdir -p "$ANDROID_AVD_HOME"
"$sdk/sdkmanager" emulator "$image"
echo no | "$sdk/avdmanager" create avd -f -n harbor -k "$image" -d pixel_5 -p "$ANDROID_AVD_HOME/harbor.avd"
test -s "$ANDROID_AVD_HOME/harbor.avd/config.ini"
# New command-line tools may put the descriptor under XDG config. Supply the
# standard emulator index entry for the explicitly created virtual device.
printf 'avd.ini.encoding=UTF-8\npath=%s\ntarget=android-35\n' "$ANDROID_AVD_HOME/harbor.avd" > "$ANDROID_AVD_HOME/harbor.ini"
"$ANDROID_HOME/emulator/emulator" -list-avds | grep -Fx harbor
sudo chmod a+rw /dev/kvm
"$ANDROID_HOME/emulator/emulator" -avd harbor -no-window -no-audio -no-boot-anim -no-snapshot -gpu swiftshader_indirect -cores 2 -memory 2500 > "$out/emulator.log" 2>&1 &
emulator=$!
trap 'status=$?; if (( status != 0 )); then "$adb" logcat -d -t 3000 > "$out/logcat.txt" 2>/dev/null || true; tail -50 "$out/emulator.log"; fi; kill "$emulator" 2>/dev/null || true' EXIT
for _ in {1..90}; do
  if "$adb" devices | grep -q 'emulator-.*device$'; then break; fi
  kill -0 "$emulator" 2>/dev/null || { cat "$out/emulator.log"; exit 1; }
  sleep 2
done
timeout 15 "$adb" wait-for-device
for _ in {1..100}; do
  if [[ $("$adb" shell getprop sys.boot_completed | tr -d '\r') == 1 ]]; then break; fi
  kill -0 "$emulator" || { cat "$out/emulator.log"; exit 1; }
  sleep 2
done
"$adb" shell wm size 720x1280
"$adb" shell wm density 240
"$adb" shell input keyevent KEYCODE_WAKEUP
"$adb" shell wm dismiss-keyguard
"$adb" shell settings put secure immersive_mode_confirmations confirmed
"$adb" install -r build/*.apk
"$adb" logcat -c
launch() {
  "$adb" shell am start -W -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -p "$package"
}
launch
python3 ci/device-screen.py "Start" build/device/menu.png tap
python3 ci/device-screen.py "Pause" build/device/first-shift.png
"$adb" shell input keyevent KEYCODE_HOME
sleep 2
"$adb" shell am force-stop "$package"
launch
python3 ci/device-screen.py "Continue" build/device/relaunch.png tap
python3 ci/device-screen.py "Pause" build/device/continued-shift.png
"$adb" shell pidof "$package"
"$adb" logcat -d > "$out/logcat.txt"
if grep -E 'SCRIPT ERROR:|FATAL EXCEPTION:|Fatal signal [0-9]+.*qofeno|E godot *:.*ERROR:' "$out/logcat.txt"; then exit 1; fi
"$adb" shell getprop ro.build.fingerprint > build/device/fingerprint.txt
