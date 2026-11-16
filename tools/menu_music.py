"""Render the original four-bar Harbor Lights theme. Requires ffmpeg on PATH."""
import array
import math
from pathlib import Path
import subprocess
import sys

rate = 22050
beat = 60 / 84
length = round(16 * beat * rate)
samples = [0.0] * length
chords = [(48, 55, 59, 64), (45, 52, 55, 60), (41, 48, 52, 57), (43, 50, 55, 59)]
for bar, chord in enumerate(chords):
    for eighth, step in enumerate((0, 2, 1, 3, 0, 1, 3, 2)):
        note = chord[step] + (12 if eighth in (3, 6) else 0)
        freq = 440 * 2 ** ((note - 69) / 12)
        start = round((bar * 4 + eighth * 0.5) * beat * rate)
        for i in range(round(1.45 * rate)):
            t = i / rate
            env = (1 - math.exp(-100*t)) * math.exp(-3.8*t)
            tone = math.sin(math.tau*freq*t) + 0.27*math.sin(math.tau*2*freq*t)
            samples[(start+i) % length] += tone*env*(0.13 if eighth else 0.20)
pcm = array.array("h", [round(s*24000) for s in samples])
if sys.byteorder != "little":
    pcm.byteswap()
dest = Path(__file__).resolve().parents[1] / "assets/audio/harbor_lights.ogg"
dest.parent.mkdir(parents=True, exist_ok=True)
subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(rate),
                "-ac", "1", "-i", "pipe:0", "-c:a", "libvorbis", "-q:a", "3", str(dest)],
               input=pcm.tobytes(), check=True)
