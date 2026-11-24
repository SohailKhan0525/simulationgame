# First release validation

Godot 4.5.1 stable (f62fdbde1), Compatibility renderer, 60 Hz physics.

- 36 session checks: jobs, pickup/drop-offs, economy, XP, 20-level cap, fuel, cars, upgrades, races, save round trips, corruption backup.
- 27 world checks: bounded 9/25/49-tile streaming, unload/reload, colliders, station placement, signal phases, weather, map boundary, and moving rival completion.
- 15 vehicle checks: stable suspension, acceleration, braking, reverse, steering/upright recovery, fuel/RPM, respawn, passenger visibility, car configuration.
- 3 release-version checks: monotonic Android version codes and consistent version metadata.
- 8 migration checks against disposable local Git repositories: exact-tree parentless root, atomic ref removal, refusal on ref drift/new refs/dirty worktree, repeat refusal.
- Main scene smoke: boot/loading, continue, vehicle input, pause, settings/update state, garage, dispatch, map, passenger pickup and save.
- Native desktop rendering: menu, cockpit, settings and garage captured using the exact Godot 4.5.1 binary and Mesa software OpenGL. No game script or shader errors in the final capture. Balanced scene measured approximately 508 menu / 582 cockpit draw calls in that view, not a mobile FPS benchmark.

Android native updater Java compiles against Android 35 and Godot 4.5.1. The final build script independently verifies APK signing, signing-certificate continuity, package identity, version values, native ABIs, plugin inclusion and archive integrity before release publication.

## Still requires device testing

Physical-device frame pacing, thermals, battery drain, multi-touch, spoken voice availability, audio mixing, DownloadManager resumption, unknown-source permissions, and an actual older-to-newer APK installation have not been validated on an Android phone. Desktop physics/render tests do not prove those properties. No claim of elite simulation or photorealism is made: this is an original procedural first playable.

The region is a fictional 28 × 28 km grid, not surveyed New York geometry. Building physics means collision boundaries, not destructible structural simulation. Mirrors are decorative. Only the nearby world exists as rendered geometry; world coordinates currently remain within ±14 km rather than using floating-origin rebasing.
