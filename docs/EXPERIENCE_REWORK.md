# Driving experience rework

This pass addresses Qofeno Drive's cockpit visibility, touch handling, menus, loading, and environment art. The reference games inform specific interactions and composition; their graphics and assets are not included in this project.

## References reviewed

- [GRID Autosport mobile controls, Feral Interactive](https://www.feralinteractive.com/en/faqs/gridautosport/1.6/android/): independent touch steering and pedals, a discoverable controls page, adjustable sensitivity, and controller input. This implementation uses horizontal analog steering, manual pedals, and a separate handbrake. It does not implement tilt controls.
- [Xbox UI navigation](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/112) and [focus handling](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/113): consistent Back behavior and clearly visible keyboard/controller focus. The Outer Worlds menu and HUD screenshots were inspected for contrast and hierarchy.
- [The Last of Us Part I accessibility breakdown, PlayStation](https://blog.playstation.com/2022/08/26/the-last-of-us-part-i-full-list-of-accessibility-features/): camera and HUD adjustment. Gameplay screenshots were inspected for uncluttered central visibility and readable edge information; shooter control layouts were not carried into this driving game.
- [Godot background loading](https://docs.godotengine.org/en/4.5/tutorials/io/background_loading.html) and [Xbox UI context](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/114): show the loading screen before world construction, report completed world work, and make entry into play clear.
- [Blender glTF export](https://docs.blender.org/manual/en/4.3/addons/import_export/scene_gltf2.html) and [texture baking](https://docs.blender.org/manual/en/4.3/render/cycles/baking.html): editable source, portable runtime materials, and engine-side verification.
- [Poly Haven Namaqualand production breakdown](https://blog.polyhaven.com/namaqualand/) and [Epic's Medieval Game Environment breakdown](https://www.unrealengine.com/tech-blog/inside-the-medieval-game-environment-now-updated-for-ue5): coherent material scale, geometry, lighting, and distance budgets. Reference imagery was inspected; these assets were not imported.

## Implemented direction

The later mobile-graphics pass adds a chase camera while retaining the cockpit view; C, controller RB, or the View button changes views. Menus use a restrained charcoal and amber palette, a clear primary action, visible focus, and scrollable content. Settings return to the screen from which they were opened. The HUD keeps the road centre clear, moves navigation and driving information to the edges, and shows interaction only near relevant destinations or fuel stations. Touch controls appear automatically on touch devices and can be shown or hidden in Settings.

Each finger owns its steering, accelerator, brake, or handbrake input until release/cancellation. Steering responds progressively and returns to centre. Wheel lock reduces with speed. Braking takes precedence over acceleration, and the direction selector requires a near stop. Keyboard and gamepad use the same actions; gamepad triggers control acceleration and braking.

The world uses original Blender-authored masonry buildings, storefronts, roof details, and branched trees, with textured materials and distant proxies. The car uses an authored body and cabin while retaining its working instruments, suspension, and wipers. Editable `.blend` files and the scripts that build/export them are committed. The map continues to use the existing fictional road grid and missions.

## Limits and next validation

This is a substantial visual and interaction revision, not a claim of photorealism or validated vehicle simulation. Reference games have far larger art-production budgets. The map is still procedural and fictional; it is not geographically accurate New York. Recorded engine audio, more distinct districts, pedestrian animation, and reflected mirrors remain separate work.

Headless checks establish input/state behavior. Native desktop captures establish appearance and layout on the tested renderer. Neither establishes Android frame pacing, thermals, or how the touch controls feel on physical hardware. The next device check should cover simultaneous steering/pedal use, interruption and resume, a full job, and sustained driving through chunk boundaries.
