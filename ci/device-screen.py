"""Find actual rendered button text, save its frame and optionally tap its center."""
import csv
import io
import os
from pathlib import Path
import subprocess
import sys
import time

word, dest, *action = sys.argv[1:]
adb = str(Path(os.environ["ANDROID_HOME"]) / "platform-tools/adb")
for _ in range(32):
    frame = subprocess.check_output([adb, "exec-out", "screencap", "-p"])
    Path(dest).write_bytes(frame)
    text = subprocess.run(
        ["tesseract", dest, "stdout", "--psm", "11", "tsv"],
        capture_output=True, text=True, check=True
    ).stdout
    match = next((r for r in csv.DictReader(io.StringIO(text), delimiter="\t")
                  if r["text"].strip().casefold() == word.casefold()), None)
    if match:
        print(f"Rendered {word!r} in {dest}")
        if action == ["tap"]:
            x = int(match["left"]) + int(match["width"]) // 2
            y = int(match["top"]) + int(match["height"]) // 2
            subprocess.run([adb, "shell", "input", "tap", str(x), str(y)], check=True)
        break
    time.sleep(2)
else:
    raise SystemExit(f"Could not find {word!r} on the installed APK screen")
