# Qofeno streetscape source

`qofeno_streetscape.blend` is the editable Blender source for four original
runtime assemblies: a brick corner building, limestone midrise, brick lowrise,
and branching street tree. Textures are packed into the source file. All mesh
geometry and texture pixels were authored for this project; no third-party or
generative-image assets are included.

Rebuild from the repository root with Blender 4.3 or later:

```sh
blender --background --python tools/build_world_assets.py
godot --headless --path game --editor --import --quit
```

The generator uses real-size geometry and UVs, creates material-specific meshes,
exports the four GLBs under `game/assets/world/`, then saves the editable source
with its assemblies spaced apart for inspection. GLBs use the normal game axes
after export; the source uses Blender's Z-up axes.

The building kit has recessed glazing, projecting window sills, cornices,
storefront awnings, metal fire escapes, parapets and rooftop equipment. Embedded
window faces are single-sided to avoid drawing invisible box interiors. Trees
use tapered branches and individual folded leaf geometry. These assets are
instanced in the streamed world, with simple collision volumes kept separate.

Godot generates mesh LODs during import. The world additionally replaces detailed
buildings with inexpensive facade proxies at 145/205/285 metres for low/balanced/
high quality. Distant proxies and shared materials keep the 28 km region bounded;
the whole region is never instantiated. Actual Android frame rate and memory
still need measurement on a device.

This is an original modular fictional city kit, not a scanned New York map or a
claim of photorealism. The source is included so the architecture, materials,
street composition and art direction can be iterated rather than painted over.
