# Counter Service · Qofeno Android 0.5.1

## Reference coverage

The reference was the 1,294,230,439-byte Git LFS object uploaded in commit `218252f6`. SHA-256 was `26429deb89edd3c391530cf018ba72e16977c5d6bd809464909859ce7bcbdbe4`. All 82 files and 16 directories were inventoried, and the full ZIP passed its CRC checks. The package identifies Nokta Games and Supermarket Simulator. Its scene and bundle headers report Unity 6000.3.6f1. It ships a Windows x86-64 player with IL2CPP metadata version 39. Original C#, the Unity editor project and source-level debug symbols are absent.

Cpp2IL 2022.1.0-pre-release.21 read the game assembly and its matching metadata. It mapped 161,470 method definitions across 114 assembly records. The audit indexed all emitted declarations and native method listings. The main gameplay assembly alone has 22,912 methods across 2,735 type listings with methods, including nested and compiler-generated types. Cpp2IL produced intermediate instructions for 157,476 methods overall, including 22,491 in the main gameplay assembly. The other 3,994 definitions had no intermediate body. Recovered declarations omit original method bodies. Native instruction listings support static inspection. This pass did not run the Windows player or step the original game in a source debugger.

UnityPy indexed the object tables in all four numbered scenes, serialized resource files and 23 bundles. Across 36 containers there are 789,813 object records. These are serialized totals, so a repeated object in two containers counts twice. The resource census includes 25,089 LOD groups, 33,650 box colliders, 755 rigid bodies, 76 wheel colliders and 803 lights. The physics manager specifies gravity Y −20 and six position-solver iterations. The time manager stores approximately 0.020 seconds per fixed step. Individual scripts can override global settings.

| Area studied | Evidence in the Windows build | Decision in Qofeno |
|---|---|---|
| Checkout and customers | The belt places products into a grid and advances them after scanning. The customer has separate actions for holding a product, moving up to checkout, cash and card. The drawer handles money separately. | Shoppers gather up to three different groceries from one visited fixture. The same price-locked lines drive visible parcels, scanner, payment and receipt. |
| Physics and vehicles | The vehicle controller has fixed-step engine, steering and brake work. Traffic has its own routing. The scene data contains separate wheel, body and environment colliders. | The estate keeps its existing bicycle steering. Roof cargo increases the effective mass used for acceleration and braking. Parcel motion uses fixed steps, a constrained belt and a damped landing. |
| Graphics and lighting | Renderers, LOD groups and scene lights are separate objects. Day progression, lighting updates and street-light control appear separately in the listings. | The cashier camera shows actual stock in the existing daylight/night-lit shop. Batched rails, belt edging, basket slats and carton straps add depth at short viewing distance. |
| Workstation and touch UX | The computer opens and closes individual applications. The checkout screen and cash-change manager have separate responsibilities. | The Ledger app prints each sold product and its price. The till offers direct parcel taps and a fixed Scan button. Leaving and reopening the till preserves the current scan during the shift. |

Public visual references were the [Supermarket Simulator Steam gallery](https://store.steampowered.com/app/2670630/) and the [Car For Sale Simulator Steam gallery](https://store.steampowered.com/app/2248760/). The reference binary, its art, and reconstructed listings were used outside the game project. Qofeno ships its own Godot code and the assets credited in this repository.

## What the four scenes contain

Unity stores a scene as an object graph. For each numbered scene the audit followed transform parents to roots, joined each canvas to its game object, and counted cameras, lights, colliders, LOD groups and reflection probes. Scene numbers below are the names found in the player build.

| Serialized records | level0 | level1 | level2 | level3 |
|---|---:|---:|---:|---:|
| Game objects | 27 | 1,752 | 54,459 | 51,747 |
| Screen-overlay canvases | 3 | 10 | 43 | 41 |
| World-space canvases | 0 | 8 | 42 | 34 |
| Mesh renderers | 0 | 0 | 31,148 | 30,775 |
| LOD groups | 0 | 0 | 12,277 | 12,270 |
| Lights | 0 | 0 | 373 | 373 |
| Reflection probes | 0 | 0 | 22 | 22 |

The entry scene contains initialization and warnings. The second scene devotes 1,158 transforms to the settings hierarchy alone. In level2, 41,711 transforms descend from the environment root, 5,501 from the gameplay root and 2,375 from the UI root. Navigation and maps have their own roots. Both large scenes contain terrain and 512-pixel reflection probes. In the stored quality presets the low and medium shadow distances are 20 units, while high is 40. These counts include inactive objects and describe the saved scenes. They cannot determine simultaneous draw calls or phone frame rate.

The storefront computer's desktop and Market app are world-space canvases. Price-setting and over-change feedback are screen overlays. Qofeno now builds the physical monitor and touch desktop from the same layout and app icons. The monitor texture refreshes when the displayed minute changes near the desk. Both sides of the 3D register show the current scanned subtotal. Fixtures and the light they cast follow the same switch and dusk state.

## Decompilation and debugger checks

The [assembly census](REFERENCE_COVERAGE.csv) covers the full metadata inventory, including engine, game and dependency assemblies. Cpp2IL decoded all available type and method records and produced native listings. For closer study, angr reconstructed higher-level control flow for seven specific routines from their original x86-64 bytes. These covered receiving a scan, belt advance, moving a shopper forward, daylight updates, opening a desktop app, fixed-step braking and activating street lighting. The recovered graphs contained 33, 60, 68, 57, 5, 63 and 15 basic blocks respectively. Engine calls and inferred variable names in these reconstructions retain uncertainty.

A separate check used pefile, Capstone and Unicorn to single-step isolated native routines from the game assembly using synthetic objects and a stack. The test ran the original machine instructions for those routines. No host game process was launched.

| Native behavior checked | Test inputs | Observed result |
|---|---|---|
| Register total and change | Bill/change pairs 8/2, 14/1 and 25/0 | Writing one field preserved the other. Both getters returned the amounts separately. |
| End of day | Normalized day progress 0.00, 0.99, 1.00 and 1.01 | The condition was false, false, true and true. |
| Vehicle gear-change state | Remaining timer −0.01, 0.00 and +0.01 | The state was inactive, inactive and active. |

Unity compiles IL2CPP code through C++ into native machine code. Recovered instruction listings and pseudocode give different levels of detail from a developer's original source and comments. The publisher site and Steam listing identify the released game. [Unity's IL2CPP pipeline](https://docs.unity3d.com/cn/2018.3/Manual/IL2CPP-HowItWorks.html) · [Cpp2IL](https://github.com/SamboyCoding/Cpp2IL) · [Nokta Games](https://noktagames.net/).

## Playing the new counter

Stock two or three goods on the same fixture. Open the shop. The first visitor selects one item. Later visitors can choose two or three if those products are in stock and within their budgets. Open Checkout when the front visitor reaches the register. Tap the leading grocery or **Scan product**. The running total shows only scanned lines. Cash customers need exact change. The computer's Ledger retains the latest 15 itemized receipts. The hired cashier scans and settles the same baskets.

At East Pier, stop in the loading bay and collect a prepaid pickup. One to four strapped cartons appear on the estate. The order survives a save while driving. Unload at Harbor Market to clear the rack and deliver the goods to receiving.

## Implementation and verification

`core/market.gd` owns allocations, locked prices and receipts. `world/counter_belt.gd` owns parcel motion and touch targeting. `world/customer.gd` owns the queue. `world/estate.gd` owns cargo presentation and driving. Save schema 5 migrates historical single-item receipts. An unpaid basket returns to shelf availability when reloading a shift.

Run `bash ci/validate.sh` with Godot 4.6.3. The native suite includes atomic reservation failure, stale scan rejection, running totals, station re-entry, payment validation, legacy receipts, accounting conservation and a loaded depot-to-market drive across a save/reload. The Android workflow installs the APK on Android 15, exercises a two-item cash purchase and a card sale with actual touch input, reads the saved ledger, and captures both stages of the scanner.
