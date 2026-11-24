"""Set reproducible mobile VRAM import settings after Godot's first asset import.

Only original 3D world/vehicle textures are touched; UI textures are excluded.
Use --check in CI to reject missing sidecars or an uncompressed 3D texture.
"""
from pathlib import Path
import argparse
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--check', action='store_true')
args = parser.parse_args()
failures = []
count = 0
for directory in ('world', 'vehicles'):
    for image in sorted((ROOT / 'game/assets' / directory).glob('*.png')):
        sidecar = image.with_name(image.name + '.import')
        if not sidecar.exists():
            failures.append(f'{sidecar.relative_to(ROOT)}: run Godot editor --import first')
            continue
        original = sidecar.read_text()
        updated = original
        values = {
            'compress/mode': '2',
            'compress/high_quality': 'false',  # ETC2 mobile baseline; true selects ASTC.
            'mipmaps/generate': 'true',
        }
        if '_normal' in image.stem:
            values['compress/normal_map'] = '1'
        for key, value in values.items():
            pattern = re.compile(r'^' + re.escape(key) + r'=.*$', re.MULTILINE)
            if not pattern.search(updated):
                failures.append(f'{sidecar.relative_to(ROOT)}: missing importer parameter {key}')
                continue
            updated = pattern.sub(f'{key}={value}', updated)
        if updated != original:
            if args.check:
                failures.append(f'{sidecar.relative_to(ROOT)}: mobile compression/mipmaps differ')
            else:
                sidecar.write_text(updated)
        count += 1
if failures:
    print('\n'.join(failures), file=sys.stderr)
    sys.exit(1)
print(f'Mobile texture imports: {count} validated' if args.check else f'Mobile texture imports: {count} configured; reimport in Godot')
