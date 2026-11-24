# Aster authored vehicle kit

Original mesh and material work for Qofeno Drive. Rebuild from the repository root:

```sh
blender --background --python tools/build_vehicle_art.py
```

`art/vehicles/aster_cabin.blend` is the editable source, kept outside the runtime
project to avoid importing it twice. `aster_cabin.glb` is the runtime export;
it contains four named roots: `BodyworkStatic`, `CockpitStatic`, `SteeringWheel`,
and `RoadWheel`. The original small leather-grain PNG is also packed in both files.
All geometry and texture data are authored by the generator; no external assets,
vehicle brands, screenshots, or image-generation output are used.

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
