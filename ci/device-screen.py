"""Verify rendered Android UI text in its panel, then tap the detected word."""
import csv
import io
import os
import re
from pathlib import Path
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from PIL import Image, ImageOps


def region(frame, word):
    width, height = frame.size
    if width <= height:
        return None
    if word == "Pause":
        return int(width * 0.84), 2, width, round(height * 0.115)
    if word in {"full-line", "ready-line"}:
        return int(width * 0.79), int(height * 0.878), int(width * 0.981), int(height * 0.956)
    # The large primary menu action has a copper fill. Locate the actual
    # button so a Continue slot, safe-area margins or text scaling can move it.
    x = int(width * (0.30 if word == "payment" else 0.06))
    rows = []
    for y in range(height // 5, height * 4 // 5):
        red, green, blue = frame.getpixel((x, y))
        if abs(red - 242) < 22 and abs(green - 187) < 22 and abs(blue - 120) < 22:
            rows.append(y)
    if not rows:
        return None
    start = rows[0]
    end = start
    for y in rows[1:]:
        if y != end + 1:
            if end - start > height * 0.035:
                break
            start = y
        end = y
    if end - start < height * 0.035:
        return None
    if word == "payment":
        return int(width * 0.22), start + 3, int(width * 0.78), end - 2
    return int(width * 0.05), start + 2, int(width * 0.34), end - 1


def locate(frame, word):
    bounds = region(frame, word)
    if not bounds:
        return None
    gray = ImageOps.grayscale(frame.crop(bounds))
    if word == "Pause":
        gray = ImageOps.invert(gray)
    gray = gray.point(lambda pixel: 255 if pixel > 114 else 0)
    source = io.BytesIO()
    gray.save(source, format="PPM")
    result = subprocess.run(["tesseract", "stdin", "stdout", "--psm", "7", "tsv"],
                            input=source.getvalue(), capture_output=True, timeout=10, check=True)
    words = list(csv.DictReader(io.StringIO(result.stdout.decode()), delimiter="\t"))
    if word in {"full-line", "ready-line"}:
        label = " ".join(row["text"] for row in words)
        count = "3" if word == "full-line" else "[1-3]"
        if re.search(r"Checkout\s*[·.°•:\-]?\s*" + count + r"\b", label, re.I):
            return (bounds[0] + bounds[2]) // 2, (bounds[1] + bounds[3]) // 2
        return None
    for row in words:
        if row["text"].strip().casefold() == word.casefold():
            return (bounds[0] + int(row["left"]) + int(row["width"]) // 2,
                    bounds[1] + int(row["top"]) + int(row["height"]) // 2)
    return None


def close_system_launcher_dialog(adb):
    # The stock AVD launcher can time out during its first indexing pass. Only
    # dismiss that exact process's system dialog. Game ANRs must fail the test.
    windows = subprocess.check_output([adb, "shell", "dumpsys", "window"],
                                      text=True, timeout=10)
    if not any("mCurrentFocus=" in line and "Application Not Responding: com.android.launcher3}" in line
               for line in windows.splitlines()):
        return
    remote = "/data/local/tmp/qofeno-qa-window.xml"
    subprocess.run([adb, "shell", "uiautomator", "dump", remote],
                   capture_output=True, check=True, timeout=15)
    layout = ET.fromstring(subprocess.check_output([adb, "exec-out", "cat", remote], timeout=10))
    for node in layout.iter("node"):
        if node.get("package") != "android" or node.get("text") != "Close app":
            continue
        coordinates = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", node.get("bounds", ""))
        if coordinates:
            x1, y1, x2, y2 = map(int, coordinates.groups())
            subprocess.run([adb, "shell", "input", "tap", str((x1+x2)//2), str((y1+y2)//2)],
                           check=True, timeout=10)
            print("Closed the AVD system launcher's ANR dialog", flush=True)
            return


def main():
    word, dest, *action = sys.argv[1:]
    adb = str(Path(os.environ["ANDROID_HOME"]) / "platform-tools/adb")
    for attempt in range(60 if word == "full-line" else 22):
        frame = subprocess.check_output([adb, "exec-out", "screencap", "-p"], timeout=20)
        Path(dest).write_bytes(frame)
        point = locate(Image.open(io.BytesIO(frame)).convert("RGB"), word)
        if point:
            print(f"Rendered {word!r} in {dest} at {point}", flush=True)
            if action == ["tap"]:
                subprocess.run([adb, "shell", "input", "tap", *map(str, point)], timeout=10, check=True)
            return
        if attempt % 4 == 2:
            close_system_launcher_dialog(adb)
        time.sleep(2)
    raise SystemExit(f"Could not find {word!r} on the installed APK screen")


if __name__ == "__main__":
    main()
