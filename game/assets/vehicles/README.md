# Aster authored vehicle kit

Original mesh and material work for Qofeno Drive. Rebuild from the repository root:

```sh
blender --background --python tools/build_vehicle_art.py
```

`art/vehicles/aster_cabin.blend` is the editable source, kept outside the runtime
project to avoid importing it twice. `aster_cabin.glb` has three named roots:
`BodyworkStatic`, `CockpitStatic`, and `SteeringWheel`. The four separately exported
wheels are `aster_wheel_fl.glb`, `aster_wheel_fr.glb`, `aster_wheel_rl.glb`, and
`aster_wheel_rr.glb`. All geometry and texture data are authored by the generator;
no external assets, vehicle brands, screenshots, or image-generation output are used.

## Materials and baking

Blender Cycles actually bakes one shared 1024×1024 atlas per channel:

| Map | Blender bake | Runtime use |
| --- | --- | --- |
| `aster_albedo.png` | EMIT, source base color only | sRGB surface color; paint regions are white for runtime recoloring |
| `aster_normal.png` | NORMAL | Tangent space, +X/+Y/+Z; procedural leather/paint/tire microdetail |
| `aster_roughness.png` | ROUGHNESS | Linear red channel |
| `aster_ao.png` | AO | Linear red channel, ambient occlusion |

The albedo emission pass avoids lighting and the black diffuse contribution of
metallic materials; it is a base-color bake, not baked illumination. The source
blend retains procedural material copies named `*.source` for editing. Runtime
GLBs intentionally contain no images: `vehicle_art.gd` assigns the same four texture
resources to body, cockpit and all wheels, avoiding four copies of the atlas.
Paint uses metallic 0.82, clearcoat 0.8 and coat roughness 0.11. Glass is translucent
and single-sided. `update_lights(vehicle, braking, headlights)` updates duplicated
headlamp and brake-lamp emissive materials without affecting other cars.

Hard-surface boxes and body panels receive two-segment bevels and weighted normals;
the generator records applied counts, bake settings, sizes, paths and timings in
`asset_report.json`. That report records actual output rather than a visual-quality claim.

The workflow follows Blender's official [baking documentation](https://docs.blender.org/manual/en/4.3/render/cycles/baking.html),
[bevel modifier](https://docs.blender.org/manual/en/4.3/modeling/modifiers/generate/bevel.html),
[weighted normals](https://docs.blender.org/manual/en/4.3/modeling/modifiers/normals/weighted_normal.html),
and [glTF material/export conventions](https://docs.blender.org/manual/en/4.3/addons/import_export/scene_gltf2.html).

## Wheel origins

Each wheel GLB has an identity root transform and its axle center at local origin.
Local X is the axle/spin axis, Y is up and Z is longitudinal. The source blend places
the four roots at nominal full-droop centers listed below; runtime suspension owns
their actual position. No offset is baked into wheel mesh vertices.

| Root | Source center, Godot metres |
| --- | --- |
| `Wheel_FL` | (-0.82, -0.20, -1.28) |
| `Wheel_FR` | (0.82, -0.20, -1.28) |
| `Wheel_RL` | (-0.82, -0.20, 1.28) |
| `Wheel_RR` | (0.82, -0.20, 1.28) |

Coordinates match the vehicle's existing metre scale, forward -Z / up +Y. The
cockpit keeps the existing driver camera, passenger space, suspension, animated
instrument needles, steering pivot, and wipers. `vehicle_art.gd` installs the kit
after the procedural animation anchors have been created. Static geometry is
combined by material inside each root to reduce draw overhead. Cabin geometry
does not cast individual mobile shadow passes.

The glazing is outward-facing and single-sided: exterior cameras see tinted
glass, while backface culling keeps the cockpit road view clear. Mirror surfaces
remain decorative; this asset does not add reflected mirror cameras or claim
automotive simulation accuracy. The instrument layer sits 45 mm in front of its
original plane so the authored binnacle cannot obscure ticks from the elevated
driver camera.
