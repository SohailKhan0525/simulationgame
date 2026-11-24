# Qofeno streetscape source

`qofeno_streetscape.blend` is the editable Blender source for eight original
runtime assemblies: a brick corner building, limestone midrise, brick lowrise,
branching street tree, roadside shrub, rock, road slab and kerbstone. Textures are packed into the source file. All mesh
geometry and texture pixels were authored for this project; no third-party or
generative-image assets are included.

Rebuild from the repository root with Blender 4.3 or later:

```sh
blender --background --python tools/build_world_assets.py
godot --headless --path game --editor --import --quit
```

The generator uses real-size geometry and UVs, creates material-specific meshes,
exports the eight GLBs under `game/assets/world/`, then saves the editable source
with its assemblies spaced apart for inspection. GLBs contain geometry and material
names without embedded texture copies. Runtime materials share the same texture
resources. GLBs use the normal game axes
after export; the source uses Blender's Z-up axes.

The building kit has recessed glazing, projecting window sills, cornices,
storefront awnings, metal fire escapes, parapets and rooftop equipment. Embedded
window faces are single-sided to avoid drawing invisible box interiors. Broad
architectural edges, road slabs and kerbstones use applied two-segment bevels and
weighted normals. Trees use tapered branches and original textured branch cards
with alpha scissor at runtime. These assets are
instanced in the streamed world, with simple collision volumes kept separate.

Godot generates mesh LODs during import. The world additionally replaces detailed
buildings with inexpensive facade proxies at 145/205/285 metres for low/balanced/
high quality. Groundcover and bevelled kerbstone detail are limited to 85/125/175
metres, with continuous inexpensive curb silhouettes beyond that. Rocks remain
in park planting areas, and foliage avoids the roadway and station approach.
Distant proxies and shared materials keep the 28 km region bounded;
the whole region is never instantiated. Actual Android frame rate and memory
still need measurement on a device.

## Baked surfaces and lighting

Two shared 1024 × 1024 PBR surface sets, `masonry_*` and `mineral_*`, each include
albedo, tangent-space normal, roughness and ambient occlusion maps. The generator
constructs physical 256 × 256 relief grids and bakes onto flat UV receivers in
Cycles with 16 samples. Albedo excludes direct/indirect lighting; roughness comes
from a varying surface material, normals from the relief, and AO from ray-traced
cavities. AO can be mostly white on the shallow mineral surface; it is a real
bake, not a constant placeholder. The separate original `foliage_atlas.png` is
1024 × 1024 RGBA, with hard alpha cutouts used for correct foliage depth/shadows.

For geometry-only iteration, reuse already baked images explicitly:

```sh
blender --background --python tools/build_world_assets.py -- --reuse-bakes
```

`game/assets/world/asset_report.json` records bake settings, channels, applied
bevel/normal counts and triangle/material-batch counts for every assembly.

At the 17:00 golden-hour preset the sun is pitched −20° and colored `#FFDFBA`.
Directional shadow splits concentrate detail near the car. The environment uses
depth fog to soften the streamed horizon; its density is maximum opacity rather
than exponential density. Glow is restrained and disabled at low quality.

AgX is used where the renderer supports its working range. On Godot 4.5 Mobile,
ACES is used with a white point of 2.0: the official renderer documentation says
AgX's fixed 16.29 white point is unsuitable for Mobile's HDR ceiling of 2.0. No
unsupported Mobile volumetric fog, screen-space GI or SSAO is enabled.

References: [Godot 4.5 environment](https://docs.godotengine.org/en/4.5/tutorials/3d/environment_and_post_processing.html),
[Godot alpha scissor](https://docs.godotengine.org/en/4.5/tutorials/3d/standard_material_3d.html),
[Blender 4.3 baking](https://docs.blender.org/manual/en/4.3/render/cycles/baking.html).

This is an original modular fictional city kit, not a scanned New York map or a
claim of photorealism. The source is included so the architecture, materials,
street composition and art direction can be iterated rather than painted over.
