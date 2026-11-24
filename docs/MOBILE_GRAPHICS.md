# Mobile graphics and art pipeline

This revision takes lighting and material cues from Forza Horizon 5 while retaining Qofeno Drive's original car, city, and missions. It does not include Forza assets or claim equivalent production quality. The [official Forza photo guide](https://forza.net/news/forza-photo-guide) informed highlight control, car/background separation, and warm low-angle light. The [environment production article](https://forza.net/news/exploring-forza-horizon-5-biomes-and-seasons) informed coherent surface scale and roadside vegetation. Reference imagery was inspected; all shipped geometry and textures are original.

## Renderer decisions

| Request | Implementation in Godot 4.5.1 |
| --- | --- |
| Mobile renderer | Mobile on desktop and Android; Vulkan explicitly selected on Android |
| AgX | AgX on non-Mobile renderers; ACES on Mobile. Godot documents AgX's fixed 16.29 white point as unsuitable for Mobile's limited HDR range. |
| Live 128² reflections | One live 256² probe. Godot's engine forces UPDATE_ALWAYS probes to 256; setting 128 silently incurs a resize and warning. |
| Golden hour | Default time preset 17:00, −20° sun pitch, warm #FFDFBA sunlight, directional shadows, subtle glow and depth fog |
| Mobile textures | 3D textures use VRAM compression and mipmaps. ETC2/ASTC import support is enabled; the portable ETC2 quality setting is selected. |
| Anti-aliasing | 2× MSAA |
| Performance | 60 FPS cap; adjustable 3D resolution, bounded streaming/detail and shadow distances, limited smoke, a single probe with shadows disabled |

The [Godot environment guide](https://docs.godotengine.org/en/4.5/tutorials/3d/environment_and_post_processing.html) describes the tone-mapping restriction and Mobile-supported depth fog/glow. The [4.5.1 reflection implementation](https://github.com/godotengine/godot/blob/4.5.1-stable/servers/rendering/renderer_rd/storage_rd/light_storage.cpp#L1498) enforces the live-probe size. Mobile has no SSR, SSAO or volumetric fog; the material AO is baked instead.

The probe captures the world without the player's own body and affects the car's render layer. It supplies specular reflections only: `AMBIENT_DISABLED` preserves the WorldEnvironment's diffuse fill instead of replacing it with the dark street capture. Its capture range is bounded by the selected quality level. Updating a cubemap is expensive even at a small resolution; this feature is included as requested, with no claim that every Android GPU can sustain it at 60 FPS.

## Rebuild the art

```sh
blender --background --python tools/build_vehicle_art.py
blender --background --python tools/build_world_assets.py
godot --headless --path game --editor --import --quit
python3 tools/configure_texture_imports.py
godot --headless --path game --editor --import --quit
python3 tools/validate_art_assets.py
```

The generators use Blender 4.3.2 and Cycles. Source `.blend` scenes remain editable. Runtime GLBs preserve UVs, normals, and wheel-local origins; shared 1024² albedo/normal/roughness/AO textures avoid a separate atlas copy for every wheel or building. Baked normals use the OpenGL tangent convention expected by Godot. Transparent glass and alpha-scissored foliage remain separate from opaque body/road surfaces.

## Check on an Android phone

Enable **Settings → Display & sound → Show FPS and frame time**. The overlay displays current FPS, the 95th-percentile frame time over the last one-second sample window, and draw calls. The target budget is 16.67 ms per frame; the overlay measures whole-frame intervals, not GPU-only timing.

Start at Balanced, drive through intersections and chunk boundaries for at least ten minutes, brake and drift, switch cameras, finish a passenger job, and interrupt/resume the app. Record the device, Android version, preset, resolution, frame-time spikes, sustained FPS, and thermal slowdown. Repeat in rain and at night. Lowering 3D resolution reduces fill cost but cannot eliminate CPU, streaming, or reflection-update cost.

Desktop software-renderer captures and headless tests establish appearance and behavior in those environments. They do not establish mobile performance, battery use, or an AAA quality level. Publishing the signed APK also requires the existing `QOFENO_KEYSTORE_PASSWORD` repository secret.
