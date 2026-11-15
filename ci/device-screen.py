"""Verify rendered Android UI text in its panel, then tap the detected word."""
import csv
import io
import os
from pathlib import Path
import subprocess
import sys
import time
from PIL import Image, ImageOps


def region(frame, word):
    width, height = frame.size
    if width <= height:
        return None
    if word == "Pause":
        return int(width * 0.84), 2, width, round(height * 0.115)
    # The large primary menu action has a copper fill. Locate the actual
    # button so a Continue slot, safe-area margins or text scaling can move it.
    x = int(width * 0.06)
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
    for row in csv.DictReader(io.StringIO(result.stdout.decode()), delimiter="\t"):
        if row["text"].strip().casefold() == word.casefold():
            return (bounds[0] + int(row["left"]) + int(row["width"]) // 2,
                    bounds[1] + int(row["top"]) + int(row["height"]) // 2)
    return None


def main():
    word, dest, *action = sys.argv[1:]
    adb = str(Path(os.environ["ANDROID_HOME"]) / "platform-tools/adb")
    for _ in range(22):
        frame = subprocess.check_output([adb, "exec-out", "screencap", "-p"], timeout=20)
        Path(dest).write_bytes(frame)
        point = locate(Image.open(io.BytesIO(frame)).convert("RGB"), word)
        if point:
            print(f"Rendered {word!r} in {dest} at {point}", flush=True)
            if action == ["tap"]:
                subprocess.run([adb, "shell", "input", "tap", *map(str, point)], timeout=10, check=True)
            return
        time.sleep(2)
    raise SystemExit(f"Could not find {word!r} on the installed APK screen")


if __name__ == "__main__":
    main()
