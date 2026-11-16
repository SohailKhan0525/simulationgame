# Harbor Market for Unity

A first-person neighborhood grocer for landscape Android, built in Unity 6000.3.6f1 with C#. Start at 17:20 with £40 in the till and a case of Quayside Tea in receiving. Through the shop window, two estate cars pass the quay in opposite directions. As evening falls, the window light, street lamps and shop lights change. New shoppers arrive from 08:00 until 21:00. Finish the last sale after closing, then explore the night or use the till to open at 08:00.

## One shift

1. Turn left at the entrance. Approach the tea carton in receiving and choose **Lift carton**. Carry it to the grocery shelf and choose **Stock shelf**. If a facing fills, the remaining units stay in your hands. You can return them to receiving.
2. Watch the shopper walk in, pick an available product, and approach the checkout. Face the register, **Scan item**, then **Take payment**. The item travels over the scanner. The physical register shows the total, then the amount paid. The balance increases once.
3. Approach the shop computer on the right and choose **Use computer**. The camera moves to the monitor. Choose cases of tea, cocoa, or soap on the supplier order form. The form shows the cost and your balance after the purchase. Confirming delivers the cases to their marked spots. Leaving the desk restores the previous view.

On a phone, drag with your left thumb to walk, drag with your right thumb to look, and tap the labeled action button. In the editor, use WASD or the arrow keys, drag the mouse to look, press E to interact, and Escape to leave the desk. A shift saves after each stock or payment action and when the app pauses. A reserved item and its scan state survive a restart.

## Open and build

Open this **UnityQofeno** directory in Unity Hub using **6000.3.6f1**. Open **Assets/Scenes/Harbor.unity** and press Play. The entry scene intentionally starts empty. [MarketSession](Assets/Qofeno/Runtime/MarketSession.cs) constructs the harbor and starts the shift after the scene loads.

With Android Build Support, its SDK/NDK tools and OpenJDK installed for that editor, choose **Qofeno → Build Android APK**. The output is `Builds/Android/Qofeno-Harbor-Market.apk`. The standalone app targets ARM64 and uses `com.qofeno.simulation.unity`. The separately released [Godot Android playtest](../README.md) uses its own package and saves.

## Models, interface and source

- [Editable model pack](ArtSource/HarborMarketModels.glb) · [Model preview](ModelPreview.jpg). The shelf, tea packet, cocoa tin, soap, receiving carton, register with scanner and card terminal, customer, and estate car share a print atlas. Their C# mesh factories and the customer's walk cycle are in [ShopModels](Assets/Qofeno/Runtime/ShopModels.cs) and [ShopModels.Motion](Assets/Qofeno/Runtime/ShopModels.Motion.cs).
- [Harbor preview](HarborPreview.jpg) · [Harbor geometry](Assets/Qofeno/Runtime/HarborBlock.cs). The block contains the shopfront, interior, supplier computer and keyboard, pavement, warehouse fronts, dock and street fixtures. The two-lane traffic uses this project’s estate model.
- [Wholesale terminal preview](TerminalPreview.jpg) · [Interface source](Assets/Qofeno/Runtime/ShopInterface.cs). The terminal uses Barlow type, the on-shelf pack artwork and a single itemized order. The previews are offline renders of the authored assets or UI layout.
- [Source study](SourceStudy.md) · [Earlier Windows build audit](../docs/COUNTER_SERVICE.md) · [PC simulator comparisons](../docs/PC_SIMULATOR_STUDY.md). These document the retail assembly evidence and distinguish reconstructed behavior from original developer source. [Art and type credits](../docs/ASSET_LICENSES.md).

## Verification

Run the [retail simulation tests](Tests~/RetailFlowTests.cs) with .NET 8 from this folder.

```sh
dotnet run --project 'Tests~/RetailFlowTests.csproj' --configuration Release
```

The suite exercises partial cartons, full facings, invalid and unaffordable orders, scan/payment ordering, duplicate transactions and save/restore. The editor also provides **Qofeno → Check Harbor Scene in Play Mode** to check the assembled scene with an isolated save.

The simulation passed 57,423 checks, including 8,000 stock and till actions and 500 mid-shift save round-trips. The C# project was typechecked against the matching Unity engine and uGUI APIs. A Unity Editor batch run stopped while initializing licensing before the project could import, so there is no Android build or playtest result for this edition yet.

The mobile playtest target for this first Unity slice is to receive stock, complete a sale, order a replacement case and resume a partially scanned sale on an ARM64 phone. Driving the estate, staffing and the broader Godot campaign remain outside this first Unity shift.
