# Qofeno Drive: engineering research

Research date: 24 November 2026. The project pins Godot 4.5.1; links below are official documentation and some describe the current stable release. Engine-dependent behavior must still be checked against the pinned build and on Android hardware.

## What this first version can establish

A large world is a streaming problem, not a requirement to keep every building loaded. A procedural region can have a New York-scale footprint while generating only nearby streets. That does not make it a geographically accurate reconstruction of New York. A production-quality city also needs authored landmarks, road data, art, traffic design and extensive testing.

The first playable version focuses on staying in the car, driving, passengers, optional races, fuel, money, upgrades, saved progress and twenty progression levels. Photorealism, professional vehicle simulation and detailed building destruction are separate production goals, not claims this prototype makes.

## Rendering and world streaming

[Godot's renderer comparison](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html) distinguishes Mobile rendering for newer mobile hardware from Compatibility for broader hardware support. Forward+ is aimed at desktop rendering. A mobile game needs a measured performance budget, not every available effect enabled at once.

[Godot's 3D optimization guide](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html) recommends tiled loading for large worlds, levels of detail and occlusion culling. Practical application here: generate a bounded ring of nearby chunks, share meshes/materials, retain inexpensive distant silhouettes, and unload old chunks. Animate only nearby actors. Keep collision shapes simple and activate physics only around the player.

[MultiMesh documentation](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html) explains how instancing reduces draw overhead. Individual instances in one MultiMesh cannot be culled separately, so batch trees and repeated building elements by spatial chunk rather than across the whole world.

[Large-world coordinates](https://docs.godotengine.org/en/stable/tutorials/physics/large_world_coordinates.html) documents precision loss and the cost of double-precision builds on mobile. A scalable mobile implementation can retain logical world coordinates while shifting active physics objects back toward the origin. Broad world bounds alone do not validate collision precision at the far edge; that needs driving tests.

Rain should change more than appearance: wetness can reduce tire friction and alter road roughness, while local particles, wind animation and rain audio communicate weather. Dense transparent particles, many shadowed lights and full-scene reflections require especially careful mobile profiling.

## Vehicle physics

[Godot explicitly cautions](https://docs.godotengine.org/en/stable/classes/class_vehiclebody3d.html) that its built-in VehicleBody3D has known issues and is not intended for realistic vehicle physics. A custom rigid-body controller gives control over the handling model, but custom code alone does not establish simulator accuracy.

[NVIDIA's vehicle documentation](https://nvidia-omniverse.github.io/PhysX/physx/5.6.1/docs/Vehicles.html) describes a useful reference model: suspension supports sprung mass, tires generate longitudinal and lateral forces, and combined tire force is limited by normal load and friction. The model informs the design; this project does not embed the PhysX vehicle SDK.

A practical lightweight controller uses four wheel contact rays, spring/damper suspension, wheel-local contact velocity, engine torque and gearing, steering, braking, drag and rolling resistance. Wet roads reduce the friction budget. Keep simulation on a fixed timestep, limit unstable forces, use collision detection suitable for fast movement, and test braking distance, cornering, slopes, curbs and impacts. These tests establish repeatability and stability; they are not certification against a real vehicle.

## Loading, persistence and audio

[Godot's background-loading guide](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html) provides asynchronous resource requests and progress polling. Retrieve a resource only after its load completes to avoid blocking the main thread. Procedural generation progress should report completed work, with a bounded amount added each frame.

Save position, vehicle selection, fuel, money, experience, upgrades, settings and mission state using a versioned save format. Validate loaded values and use a temporary file plus replacement so a partial write does not destroy the last valid save. Mobile pause/resume deserves testing independently from desktop quit behavior.

Engine pitch should follow engine RPM and load, with different tuning for each car. Synthesized engine audio and device text-to-speech are reasonable prototype tools; they are not substitutes for recorded multi-layer engine samples or an expressive human voice performance.

## Android packaging and updates

[Godot's Android export guide](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html) documents JDK 17, Android SDK setup, release signing and environment overrides for keystore path, alias and password. Pin the engine, matching export templates and build dependencies for repeatable exports.

[Android DownloadManager](https://developer.android.com/reference/android/app/DownloadManager) provides persistent background HTTP downloads, retry behavior and downloaded/total byte counters. Persist the download identifier so progress can be recovered after relaunch. Treat missing total size as indeterminate progress and surface failed, paused and completed states separately.

[PackageManager.canRequestPackageInstalls](https://developer.android.com/reference/android/content/pm/PackageManager#canRequestPackageInstalls()) documents user permission for installing apps from a source. Downloading an update can happen in the background; installing it uses Android's user-mediated installation flow. Check version, package identity, signing certificate and download integrity before offering installation. A GitHub-distributed APK updater is a different distribution path from Google Play's update system.

[Android's signing guide](https://developer.android.com/studio/publish/app-signing) explains signing identity and key protection. Future updates need the established signing key. Keeping an encrypted keystore in the repository can satisfy source backup needs, but its decryption password must remain outside public source. Never publish the keystore and its usable password together.

## Releases and verification

[semantic-release's GitHub Actions recipe](https://semantic-release.gitbook.io/semantic-release/recipes/ci-configurations/github-actions) and [plugin lifecycle](https://semantic-release.gitbook.io/semantic-release/usage/plugins) support a pipeline that derives versions from commits, prepares a signed APK, then publishes release assets. Generate Android version metadata before export. Fail the release if build, signing or integrity checks fail.

[Android game optimization guidance](https://developer.android.com/games/optimize) emphasizes frame pacing, thermals and sustained performance. Record results on low-, middle- and high-tier devices, including a long driving session. Headless parse tests and successful APK signing do not prove touch responsiveness, stable frame rate, audio quality or visual fidelity on a phone.

Suggested acceptance scenarios: resume the saved car position; complete passenger pickup and drop-off; accept and decline a race; buy an upgrade; refuel without leaving the car; reach the level cap; cross multiple streaming boundaries; run out of fuel; interrupt and resume an update download; and verify an update preserves the save.


## Runtime quality budgets

The initial quality tiers retain 9 chunks on Low, 25 on Balanced, and 49 on High. Each chunk is 160 metres square. Low disables directional shadows, uses 10 traffic cars, and increases distance fog to soften its shorter view. Balanced uses 18 cars; High uses 28. Road markings, pavement, lamp lenses and signal lenses do not cast shadows. Traffic body geometry is shared in five material batches per car.

These are workload limits, not a guaranteed frame rate. Android GPU, memory and thermal profiling is still needed; the software-rendered desktop preview does not establish phone performance.
