# Stocking and checkout in the Windows reference

I traced four routines in the uploaded *Supermarket Simulator* v1.7.3 Windows build. The evidence comes from Cpp2IL's named instruction listings for the game's IL2CPP assembly, checked against native branch targets and field offsets. Addresses below are relative to `GameAssembly.dll` in the archive whose SHA-256 begins `26429deb89edd3c3`. These observations describe that version. [Archive identity, engine version and earlier audit](../docs/COUNTER_SERVICE.md)

| Routine and RVA | What the compiled game does |
|---|---|
| `DisplaySlot.CanRestockWith`, `0xB68010` | Rejects a negative product ID or a display being moved. For a slot containing a product, it compares the incoming ID with the existing ID, then checks the first item's count against the product's storage grid capacity. This explains why a nonempty facing can refuse another carton even though the player is aiming at a shelf. |
| `BoxInteraction.PlaceProductToDisplay`, `0x66C190` | The placement path calls into inventory bookkeeping, the placing sound and local-player haptic feedback. The tutorial can advance on this action. Putting an item down has both a stock consequence and immediate sensory feedback. |
| `DisplaySlot.SetPriceTag`, `0xB69AC0` | Looks up the first product's ID and discounted price, then updates tag visibility and requests label and discount mask updates. A shelf's price label follows the stock occupying its facing. |
| `CheckoutInteraction.OnApproveCheckout`, `0x68CB70` | Calls the cash-payment completion check. A failed result skips the calls that clear interaction hints, restore the normal hint and play the acknowledgement vibration. The confirmation belongs after payment succeeds. |

## What the retail archive contains

The 0.2.0 study checked the complete 1,294,230,439-byte ZIP against its Git LFS SHA-256 and validated every entry's CRC. The ZIP has 82 files and 16 directory entries. The Windows player includes an 82,208,768-byte native gameplay library and a 19,590,904-byte IL2CPP v39 metadata file. Neither the ZIP directory nor the serialized assets supplied a C# project, a debugging-symbol file or a developer-authored C# source file. All 5,023 Unity script records contained type and assembly metadata. The four embedded text assets contained configuration.

The assembly metadata identifies 22,912 named methods in the gameplay assembly. The following observations informed the Android game. Counts, prices, visual designs, customer preferences and the Harbor supply contract were designed for Qofeno.

Three native routines provided a cross-check. At RVA `0x7D1AF0`, the price manager computes markup relative to current cost. The daily statistics methods at `0x6DFF70` and `0x6DFF90` independently increment counters for a missing product and an expensive product. These are observations from the executable instructions. The demand curve in Qofeno is our own.

| Evidence in the Windows build | Decision in Harbor Market |
| --- | --- |
| Pricing records distinguish selling price, market reference, average cost and discounts. Shelf labels follow product identity. | Show a reference price alongside the player's price. Update the physical shelf label when the owner changes it. Preserve the shopper's quote from the moment they select an item. |
| The daily statistics record separates revenue, operating costs, goods unavailable and customer price objections. | Keep till income, purchases, store investment and other income as separate ledger entries. Close each day's books once. |
| Checkout code distinguishes scanner interaction, cash verification and card approval. | Provide an itemized conveyor and separate tender flows. Cash is credited after the player gives exact change. |
| License records distinguish owned and active ranges. Shopper and queue records are separate from inventory records. | Installing the pantry extension opens a three-product coastal range. A second shopper can wait in line and survives a save. |

## Published games and source comparisons

Nokta's official screenshots show the total, tendered amount and change on the register, individual compartments in the cash drawer, and the supplier catalog on a physical office monitor. Qofeno uses an original sterling drawer, supplier artwork and a touch office sized for landscape phones. [Nokta's game and screenshots](https://www.noktagames.net/) · [Supermarket Simulator on Steam](https://store.steampowered.com/app/2670630/Supermarket_Simulator/)

Supermarket Together connects staff and new product ranges to store progression. Sunday.gg's mobile Shop Manager 3D features stocking, serving a line and delegating work. In Qofeno the owner can do each job manually, then invest sales proceeds in another fixture or a restocker. [Supermarket Together](https://store.steampowered.com/app/2709570/Supermarket_Together/) · [Shop Manager 3D](https://play.google.com/store/apps/details?id=my.perfect.shop.simulation)

The author-published Unity project *Stock and Shop* provided readable C# examples of customer price tolerance, queue order and the handoff from the till to daily accounting. A separate public *Cashier Simulator* project provides concrete examples of placing items on a conveyor and checking tender before ending a sale. Both are independent developer projects. Qofeno's C# and assets live in this repository. [Stock and Shop](https://github.com/Richard-Casey/Stock-and-Shop) · [Cashier Simulator source at the reviewed revision](https://github.com/Swiper0/Cashier-Simulator/tree/891e2063ae5bfe89244b6f192319cbccb55a5d3c/Assets/Script)

## The C# source and the free Prologue

The retail archive has compiled gameplay and metadata. Its 5,023 Unity script records were checked for embedded script text in the earlier audit. I found no published Nokta source project in the developer's site or its official Steam materials. [Nokta Games](https://www.noktagames.net/) · [Unity's IL2CPP build process](https://docs.unity3d.com/6000.0/Documentation/Manual/il2cpp-introduction.html)

Nokta also released a free Windows *Prologue*. Its depot lists a 371 KiB managed `Assembly-CSharp.dll`. I retried an anonymous Steam content session for that specific file. Both Steam connection-directory requests timed out and DNS bootstrap failed before any file transfer. I verified the public filename, but could not inspect the Prologue's method bodies. A managed build could yield a readable reconstruction of this earlier version. The exact project files, including the developer's comments, would require an original source copy. [Official Prologue](https://store.steampowered.com/app/2772560/) · [Depot inventory](https://steamdb.info/depot/2772561/)
