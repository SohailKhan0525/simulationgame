# Counter Service · Qofeno Android 0.5.0

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

## Playing the new counter

Stock two or three goods on the same fixture. Open the shop. The first visitor selects one item. Later visitors can choose two or three if those products are in stock and within their budgets. Open Checkout when the front visitor reaches the register. Tap the leading grocery or **Scan product**. The running total shows only scanned lines. Cash customers need exact change. The computer's Ledger retains the latest 15 itemized receipts. The hired cashier scans and settles the same baskets.

At East Pier, stop in the loading bay and collect a prepaid pickup. One to four strapped cartons appear on the estate. The order survives a save while driving. Unload at Harbor Market to clear the rack and deliver the goods to receiving.

## Implementation and verification

`core/market.gd` owns allocations, locked prices and receipts. `world/counter_belt.gd` owns parcel motion and touch targeting. `world/customer.gd` owns the queue. `world/estate.gd` owns cargo presentation and driving. Save schema 5 migrates historical single-item receipts. An unpaid basket returns to shelf availability when reloading a shift.

Run `bash ci/validate.sh` with Godot 4.6.3. The native suite includes atomic reservation failure, stale scan rejection, running totals, station re-entry, payment validation, legacy receipts, accounting conservation and a loaded depot-to-market drive across a save/reload. The Android workflow installs the APK on Android 15, exercises a two-item cash purchase and a card sale with actual touch input, reads the saved ledger, and captures both stages of the scanner.
