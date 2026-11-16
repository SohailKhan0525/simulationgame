"""Generate two small seamless original surface maps. Requires Pillow."""
import math
from pathlib import Path
import random
from PIL import Image

dest = Path(__file__).resolve().parents[1] / "assets/environment"
dest.mkdir(parents=True, exist_ok=True)
size = 192
rng = random.Random(527)
for kind in ("limewash", "timber"):
    image = Image.new("RGB", (size, size))
    data = []
    for y in range(size):
        for x in range(size):
            u, v = x / size * math.tau, y / size * math.tau
            jitter = rng.gauss(0, 6)
            if kind == "limewash":
                pigment = 226 + 6*math.sin(u*2 + math.sin(v*3)) + 5*math.cos(v*4+math.sin(u))
                pigment += jitter + (rng.uniform(-34, -6) if rng.random()<0.075 else 0)
            else:
                strand = math.sin(v*19 + 1.1*math.sin(u*2) + 0.45*math.cos(u*5+v))
                pigment = 220 + 14*strand + 8*math.sin(v*56+math.sin(u*2)) + jitter*0.5
            value = round(max(0, min(255, pigment)))
            data.append((value, value, value))
    image.putdata(data)
    image.save(dest / (kind + ".png"))
