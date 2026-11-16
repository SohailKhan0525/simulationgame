# Windows build study: stocking and checkout

## Reference coverage

The reference was the 1,294,230,439-byte Git LFS object uploaded in commit `218252f6`. SHA-256 was `26429deb89edd3c391530cf018ba72e16977c5d6bd809464909859ce7bcbdbe4`. All 82 files and 16 directories were inventoried, and the full ZIP passed its CRC checks. The package identifies Nokta Games and Supermarket Simulator. Its scene and bundle headers report Unity 6000.3.6f1. It ships a Windows x86-64 player with IL2CPP metadata version 39. Original C#, the Unity editor project and source-level debug symbols are absent.

Cpp2IL 2022.1.0-pre-release.21 read the game assembly and its matching metadata. It mapped 161,470 method definitions across 114 assembly records. The audit indexed all emitted declarations and native method listings. The main gameplay assembly alone has 22,912 methods across 2,735 type listings with methods, including nested and compiler-generated types. Cpp2IL produced intermediate instructions for 157,476 methods overall, including 22,491 in the main gameplay assembly. The other 3,994 definitions had no intermediate body. Recovered declarations omit original method bodies. Native instruction listings support static inspection. This pass did not run the Windows player or step the original game in a source debugger.

UnityPy indexed the object tables in all four numbered scenes, serialized resource files and 23 bundles. Across 36 containers there are 789,813 object records. These are serialized totals, so a repeated object in two containers counts twice. The resource census includes 25,089 LOD groups, 33,650 box colliders, 755 rigid bodies, 76 wheel colliders and 803 lights. The physics manager specifies gravity Y −20 and six position-solver iterations. The time manager stores approximately 0.020 seconds per fixed step. Individual scripts can override global settings.

| Area studied | Evidence in the Windows build | Earlier prototype design |
|---|---|---|
| Checkout and customers | The belt places products into a grid and advances them after scanning. The customer has separate actions for holding a product, moving up to checkout, cash and card. The drawer handles money separately. | Shoppers gather up to three different groceries from one visited fixture. The same price-locked lines drive visible parcels, scanner, payment and receipt. |
| Physics and vehicles | The vehicle controller has fixed-step engine, steering and brake work. Traffic has its own routing. The scene data contains separate wheel, body and environment colliders. | The estate keeps its existing bicycle steering. Roof cargo increases the effective mass used for acceleration and braking. Parcel motion uses fixed steps, a constrained belt and a damped landing. |
| Graphics and lighting | Renderers, LOD groups and scene lights are separate objects. Day progression, lighting updates and street-light control appear separately in the listings. | The cashier camera shows actual stock in the existing daylight/night-lit shop. Batched rails, belt edging, basket slats and carton straps add depth at short viewing distance. |
| Workstation and touch UX | The computer opens and closes individual applications. The checkout screen and cash-change manager have separate responsibilities. | The Ledger app prints each sold product and its price. The till offers direct parcel taps and a fixed Scan button. Leaving and reopening the till preserves the current scan during the shift. |

Public visual references were the [Supermarket Simulator Steam gallery](https://store.steampowered.com/app/2670630/) and the [Car For Sale Simulator Steam gallery](https://store.steampowered.com/app/2248760/). The reference binary, its art, and reconstructed listings were used outside the game project. Qofeno’s Android implementation is in the [Unity project](../UnityQofeno/README.md).

## Where the original C# can be read

The search included embedded content. All 5,023 serialized MonoScript records have six fields describing the name, class, namespace, assembly, property hash and execution order. None contains script text. All four TextAsset payloads were read and checked for C# source. None supplied a game source file. The 18 Windows EXE/DLL files were inspected for debug-directory records. The game assembly contains a CodeView record referring to `GameAssembly.pdb`. The ZIP contains no matching PDB or embedded portable PDB, source project, or C# file. The Microsoft-format GUID and age embedded in each binary were checked against [Unity's public symbol server](https://docs.unity.com/en-us/engine/6000.6/manual/platform-specific/windows/develop/debugging/instructions). The exact game PDB lookup returned HTTP 404. The same lookup succeeded for UnityPlayer: the 25,432,064-byte engine PDB matched its GUID and age and contained 119,232 public symbol records. Engine symbols describe the player runtime. Looking up Nokta Games' publisher site and public Steam materials also yielded no developer-published game-source repository.

Actual C# is publicly readable for some dependencies. The uploaded build lists Unity's UI assembly. The separate [Unity uGUI source tree](https://github.com/Unity-Technologies/uGUI/tree/5e55142c416efc0440b44b1ea7e23811219ed57a/com.unity.ugui/Runtime/UGUI) was inventoried at a recorded revision: 86 runtime C# files. Three implementations were read closely. CanvasScaler handles physical-world canvases separately from screen resolution scaling. GraphicRaycaster uses the canvas camera when testing world-space graphics. Button checks that a control is active and interactable before sending its click event. This is upstream engine source. The exact uGUI source revision that Nokta shipped could not be established from these files.

The game-specific evidence below comes from scene records and compiled game routines. Cpp2IL's C#-shaped files give declarations and recovered names. The 15 higher-level routine reconstructions are decompiler pseudocode. The developer's comments, original expressions and source-line layout require a developer-supplied project or an official source release.

### Public sources checked on 16 November 2026

I searched in English and Turkish using the game title, studio name and creator's name. Nokta's site, its Steam releases, public developer interviews and indexed code repositories yielded no verifiable studio release of the original Unity project. Some similarly named repositories do contain C# files. Their provenance matters.

| Lead | What the evidence establishes |
|---|---|
| Nokta's **free Prologue**, 26 January 2024 | The published depot inventory lists a 371 KiB managed `Assembly-CSharp.dll`. This older build is a candidate for recovering readable method bodies with a .NET decompiler. The depot listing was verified. The Steam content session timed out here, so this pass did not obtain or decompile that DLL. [Nokta's Steam listing](https://store.steampowered.com/app/2772560/Supermarket_Simulator_Prologue/) · [Depot file list](https://steamdb.info/depot/2772561/) |
| GitHub project titled **SuperMarket-Simulator-Source-Code** | Its checked-in Unity settings name the product *SuperMarket Store Simulator*, name a different company, and specify the Android application ID `com.supermarket.simulator.uiop.store.sim`. Those identifiers give no basis for attributing this project to Nokta. [Project settings at the inspected revision](https://github.com/Grigore1P/SuperMarket-Simulator-Source-Code/blob/2f9af434167efe3f812eaf75cafb3782b441366c/ProjectSettings/ProjectSettings.asset) |
| Community code | Tobey's repository describes its mod-loading package. An April 2024 community patch proposes assigning shoppers to the shortest eligible queue and a second patch proposes taking from the least-filled available carton. These are the mod author's proposed changes. Neither patch establishes the retail game's current selection rule. [Mod pack](https://github.com/toebeann/BepInEx.SupermarketSimulator) · [Queue patch](https://github.com/marcbal/SupermarketAssistant/blob/516694961ca41de44ddf71e14880d8353be93afc/mods/customer-pick-checkout-wisely.diff) · [Carton patch](https://github.com/marcbal/SupermarketAssistant/blob/516694961ca41de44ddf71e14880d8353be93afc/mods/restocker-choose-emptiest-box.diff) |

### What the developer documented

- **Checkout.** Nokta describes letting players decide how much change to give. In the uploaded 1.7.3 build, the cash-completion routine references separate change-approval and minimum-change checks, customer speech and incorrect-change statistics. Qofeno 0.5.1 enforces exact change. A player can therefore produce a different outcome at the two registers even when their displays look similar. [Nokta's game description](https://noktagames.net/)
- **Handheld UI.** Patch 1.6.0 added larger type and images. Players can change the layout at the market computer and choose it separately for individual panels. Qofeno could use that distinction to enlarge a crowded ordering screen while preserving the view of physical groceries at the till. [Developer patch notes](https://store.steampowered.com/news/app/2670630/view/676255623445217640)
- **Graphics.** The 1.0 release notes identify the product-and-box renderer, displays mounted on furniture, nighttime rendering and store lighting as specific areas of work. For Qofeno, a stocked aisle, an active computer and an illuminated shop at closing are three distinct scenes worth measuring on the same phone. [Producer's release notes](https://store.steampowered.com/news/posts/?enddate=1750355136&feed=steam_community_announcements)
- **Staff and vehicles.** Nokta described rewriting restockers to address stalled workers and flying boxes, then adding a courier in 1.7.3. The player packs the order and hands it over before the courier takes responsibility. These are concrete handoffs to test when extending Qofeno beyond its current supplier pickup. [Restocker rewrite](https://steamdb.info/patchnotes/22885784/) · [Courier update](https://store.steampowered.com/news/app/2670630/view/680764929940134716)

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

The [assembly census](REFERENCE_COVERAGE.csv) covers the full metadata inventory, including engine, game and dependency assemblies. Cpp2IL decoded all available type and method records and produced native listings. For closer study, angr reconstructed higher-level control flow for 15 specific routines from their original x86-64 bytes. These covered receiving a scan, belt advance, moving a shopper forward, daylight updates, opening a desktop app, fixed-step braking and activating street lighting. A second pass covered shelf removal, carton contents, inventory costing, cart totals, cashier payment animation, traffic spawning, save-slot lookup and the computer camera layout. In total the 15 recovered graphs contained 711 basic blocks. Engine calls and inferred variable names in these reconstructions retain uncertainty. Matching call destinations to recovered method records showed that the scan path updates grid occupancy and can finish scanning or advance the belt. Belt advance updates collider state and requests local movement on the product transform. Fixed-step braking calls into wheel handbrake and brake-torque operations. Lighting updates set ambient color and material parameters. Shelf removal checks for an available product before removing it. The costing path reads the inventory count and previous average. The NPC spawn path consults spawn transforms and uses pooled objects for its local path. Qofeno implements those interactions with its own fixed-step parcels, vehicle mass factor and lamp materials.

A separate check used pefile, Capstone and Unicorn to single-step isolated native routines from the game assembly using synthetic objects and a stack. The test ran the original machine instructions for those routines. No host game process was launched.

| Native behavior checked | Test inputs | Observed result |
|---|---|---|
| Register total and change | Bill/change pairs 8/2, 14/1 and 25/0 | Writing one field preserved the other. Both getters returned the amounts separately. |
| End of day | Normalized day progress 0.00, 0.99, 1.00 and 1.01 | The condition was false, false, true and true. |
| Vehicle gear-change state | Remaining timer −0.01, 0.00 and +0.01 | The state was inactive, inactive and active. |

Unity compiles IL2CPP code through C++ into native machine code. Recovered instruction listings and pseudocode give different levels of detail from a developer's original source and comments. The publisher site and Steam listing identify the released game. [Unity's IL2CPP pipeline](https://docs.unity3d.com/cn/2018.3/Manual/IL2CPP-HowItWorks.html) · [Cpp2IL](https://github.com/SamboyCoding/Cpp2IL) · [Nokta Games](https://noktagames.net/).

### Repeating the inspection

The reference hash can be checked with `sha256sum`. Python's `ZipFile.testzip()` verifies all entry CRCs. UnityPy reads each numbered scene, asset container and bundle directly from its decompressed entry. Count unique path IDs within each serialized file; associate Transform and RectTransform with their game object and follow the parent to assign a root.

For the native side, pair the uploaded build's own `GameAssembly.dll` with its own `il2cpp_data/Metadata/global-metadata.dat`. With Cpp2IL pre-release.21, supply both paths and Unity version `6000.3.6f1`. The `diffable-cs` format emits declarations; the `isil` format emits native and intermediate listings. The census counts method entries per assembly and subtracts entries that explicitly report no intermediate instructions. The 114 assembly rows sum to the totals above.
