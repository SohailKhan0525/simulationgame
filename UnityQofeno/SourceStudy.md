# Stocking and checkout in the Windows reference

I traced four routines in the uploaded *Supermarket Simulator* v1.7.3 Windows build. The evidence comes from Cpp2IL's named instruction listings for the game's IL2CPP assembly, checked against native branch targets and field offsets. Addresses below are relative to `GameAssembly.dll` in the archive whose SHA-256 begins `26429deb89edd3c3`. These observations describe that version. [Archive identity, engine version and earlier audit](../docs/COUNTER_SERVICE.md)

| Routine and RVA | What the compiled game does |
|---|---|
| `DisplaySlot.CanRestockWith`, `0xB68010` | Rejects a negative product ID or a display being moved. For a slot containing a product, it compares the incoming ID with the existing ID, then checks the first item's count against the product's storage grid capacity. This explains why a nonempty facing can refuse another carton even though the player is aiming at a shelf. |
| `BoxInteraction.PlaceProductToDisplay`, `0x66C190` | The placement path calls into inventory bookkeeping, the placing sound and local-player haptic feedback. The tutorial can advance on this action. Putting an item down has both a stock consequence and immediate sensory feedback. |
| `DisplaySlot.SetPriceTag`, `0xB69AC0` | Looks up the first product's ID and discounted price, then updates tag visibility and requests label and discount mask updates. A shelf's price label follows the stock occupying its facing. |
| `CheckoutInteraction.OnApproveCheckout`, `0x68CB70` | Calls the cash-payment completion check. A failed result skips the calls that clear interaction hints, restore the normal hint and play the acknowledgement vibration. The confirmation belongs after payment succeeds. |

## The C# source and the free Prologue

The retail archive has compiled gameplay and metadata. Its 5,023 Unity script records were checked for embedded script text in the earlier audit. I found no published Nokta source project in the developer's site or its official Steam materials. [Nokta Games](https://www.noktagames.net/) · [Unity's IL2CPP build process](https://docs.unity3d.com/6000.0/Documentation/Manual/il2cpp-introduction.html)

Nokta also released a free Windows *Prologue*. Its depot lists a 371 KiB managed `Assembly-CSharp.dll`. I retried an anonymous Steam content session for that specific file. Both Steam connection-directory requests timed out and DNS bootstrap failed before any file transfer. I verified the public filename, but could not inspect the Prologue's method bodies. A managed build could yield a readable reconstruction of this earlier version. The exact project files, including the developer's comments, would require an original source copy. [Official Prologue](https://store.steampowered.com/app/2772560/) · [Depot inventory](https://steamdb.info/depot/2772561/)
