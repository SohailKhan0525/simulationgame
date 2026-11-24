# Qofeno Drive

An offline-first Android driving game built with **Godot 4.5.1**. Stay behind the wheel, take passengers across town, accept an occasional race, earn cash, refuel and build a collection of cars.

**First playable / prototype.** This version combines a streamed procedural layout with original Blender-authored streetscape and car assets. Its 28 × 28 km region covers 784 km² and is inspired by the scale and variety of New York; it is not an accurate New York street map or a photorealistic city recreation. Vehicle handling uses custom physics tuned for approachable gameplay, not validated automotive simulation.

[Android releases](https://github.com/SohailKhan0525/simulationgame/releases) · [Build and signing guide](docs/RELEASING.md) · [Engineering research](docs/RESEARCH.md) · [Experience rework and references](docs/EXPERIENCE_REWORK.md)

## Play

Install the signed `Qofeno-Drive.apk` from a published release on an Android 8+ device with ARM64 or x86_64 support. Android may ask you to allow installation from the app you use to open the APK. Desktop development builds can be run from the Godot editor.

Choose **Continue your drive**, open **Jobs**, accept a dispatch and follow the destination marker. Stop below 3 km/h at a pickup or destination and use **Interact**. At a petrol station, stop beside the attendant and interact to buy fuel without leaving the car. Cash and XP unlock cars, upgrades and later dispatches. Earlier jobs remain replayable.

| Action | Android | Keyboard |
| --- | --- | --- |
| Accelerate | Hold ACCEL | W / Up; controller RT |
| Brake | Hold BRAKE | S / Down; controller LT |
| Steer | Drag steering pad left/right | A/D or Left/Right; controller left stick |
| Reverse | Stop, toggle D / R, then ACCEL | R / controller Y toggles while stopped |
| Handbrake | Hold H/B | Space / controller A |
| Pickup, drop-off, refuel | Contextual Interact / Refuel | E / controller X |
| Horn | Horn | H / controller LB |
| Pause/menu | Pause button | Escape / controller Start |
| Dispatch/map/recovery | Jobs / Map; recovery in Settings | Keyboard/controller focus in pause menu |

Progress is saved automatically and when pausing. **Settings** provides steering sensitivity, touch display, cockpit field of view, graphics quality, audio, time/weather and update actions. Android update downloads run in the background with progress; installation still requires your approval in Android. Touch controls track independent fingers and reset on interruption; menus support visible keyboard/controller focus.

## Included in the prototype

- A fixed in-car driving view with a Blender-authored body and cabin, a modeled dashboard, animated speed/RPM needles, steering wheel, trim, seats and a visible passenger. There is no exit-car control.
- Four contact rays with spring/damper suspension, tire-force limits, braking, reverse, handbrake, wet grip, fuel consumption and impact damage. Engine, road, wind, horn and impact sounds are synthesized.
- Three fictional cars: Aster S, Meridian GT and Veloce R, each with five performance upgrade stages and different engine tuning.
- Twenty progression levels and twenty level-gated, repeatable dispatches, including passenger trips, deliveries and timed checkpoint challenges. Passenger dialogue includes commuters, a tipsy rider, an off-duty officer, a reformed thief and a shady fare.
- Optional traffic-light race invitations. Declining produces twelve distinct crowd banter lines without a money/XP penalty. Races use a visible physical waypoint-following rival; time trials use checkpoint timers. The rival yields to nearby obstructions, and reaching the finish first decides the race.
- A deterministic streamed region with a city center, residential areas, wealthy neighborhoods, parkland, a forest and a village. The whole initial region is open at level 1; future regions and more levels/cars are marked **Coming soon**.
- Blender-authored masonry blocks and trees, textured storefronts, distance proxies, wet road shading, wind-animated foliage, rain particles, day/night lighting, ambient weather effects, animated bird silhouettes, traffic signals and nearby traffic.
- In-game money, attendant refueling, repairs, mission markers, a map, loading screens, quality settings and versioned saves with backup recovery.
- Android background update support, persistent password-protected signing identity, GitHub Actions builds and semantic-release versioning.

## Current limits

Buildings have static collision, not destruction or structural simulation. The map is a regular procedural road grid rather than real geographic data. Mirrors are decorative. Birds are simple animated silhouettes, not an ecosystem. Cars share an original Blender-authored base body/cabin with distinct paint and handling rather than three separately modeled production cars. Engine sounds and speech need a recorded audio pass for a final-quality presentation.

The first version does not include multiplayer, pedestrian gameplay, walking outside the car, advanced traffic routing, functioning reflected mirrors, detailed deformation, licensed vehicles or production-grade racing AI. Future regions are placeholders, not downloadable expansion maps. Broad world bounds are implemented; sustained driving performance, far-edge physics precision and the full upgrade-installation flow still require testing on Android devices.

## Development

Open `game/project.godot` with Godot **4.5.1** (standard/GDScript edition), or run:

```sh
godot --path game --editor
godot --path game
```

The runtime uses the Compatibility renderer for broad hardware support. No paid engine subscription, cloud login or gameplay server is required. See [RELEASING.md](docs/RELEASING.md) for Android SDK, Gradle, signing and release setup.

Useful checks:

```sh
godot --headless --path game --editor --import --quit
godot --headless --path game --script ../tests/session_test.gd
godot --headless --path game --script res://tests/drive_controls_test.gd
godot --headless --path game --script res://tests/handling_test.gd --fixed-fps 60
godot --headless --path game --script res://tests/ui_flow_test.gd --fixed-fps 60
npm ci --ignore-scripts
npm run test:release
python3 tests/test_reset_history.py
```

The last test uses disposable local Git repositories; it does not modify GitHub. Successful automated checks do not establish mobile frame rate, steering feel, battery use or visual quality. Test the APK on a physical Android device before treating it as a production release.

## Source layout

| Path | Responsibility |
| --- | --- |
| `game/scripts/main.gd` | Startup, loading, menus, controls, HUD and gameplay orchestration |
| `game/scripts/vehicle.gd` | Custom vehicle physics and animated instruments |
| `game/scripts/drive_controls.gd` | Independent touch ownership and analog steering |
| `game/scripts/vehicle_art.gd` | Blender asset installation around animated instruments |
| `art/`, `tools/build_*_art.py`, `tools/build_world_assets.py` | Editable Blender scenes and reproducible art export |
| `game/scripts/vehicle_audio.gd` | Engine and driving sound synthesis |
| `game/scripts/world.gd` | Streamed chunks, scenery, stations, weather and region bounds |
| `game/scripts/world_traffic.gd` | Local traffic movement and signals |
| `game/scripts/world_*.gdshader` | Buildings, roads and foliage materials |
| `game/scripts/session.gd` | Jobs, progression, economy, race offers and saved state |
| `game/scripts/minimap.gd` | Route and world-map display |
| `game/scripts/updater.gd` | Update manifest/UI and native bridge integration |
| `android-plugin/` | DownloadManager, APK verification, installer and Android speech |
| `tools/`, `.github/workflows/` | Version stamping, validation, APK build and release automation |

## Repository initialization

The **Reset repository history once** workflow implements the owner's requested fresh `main`. Initial setup runs only when a push to `main` changes `tools/history-bootstrap.trigger` with the exact commit message `feat: bootstrap Qofeno Drive`. Manual dispatch instead accepts the exact reviewed main SHA. It preserves that commit's file tree in a new parentless commit and atomically removes only the old branches/tags recorded in `tools/history-reset-refs.tsv`. Every changed ref has an explicit expected-SHA lease. A changed or unexpected ref stops the operation before it writes anything. The workflow starts the Android release only if its signing secret is configured; otherwise it records the release blocker.

This is a one-time migration, not a normal release step. It does not delete existing release records, GitHub-managed pull-request refs, forks, clones or cached commits. Once migration succeeds, use ordinary commits for all game updates. See [GitHub's history-rewrite limitations](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository).

Validation details and remaining phone tests are recorded in [docs/VALIDATION.md](docs/VALIDATION.md).
