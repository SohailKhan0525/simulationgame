# Harbor Market for Unity

A first-person neighborhood grocer for landscape Android, built in Unity 6000.3.6f1 with C#. A new shop opens at 08:00 with £40, eleven products on display and a tea carton in receiving. Estate cars pass on the quay, daylight changes and shoppers visit until 21:00. Finish the last queued sale after closing, then explore the night or use the till to open at 08:00.

## One shift

1. Turn left at the entrance. Approach the tea carton in receiving and choose **Lift carton**. Carry it to the grocery shelf and choose **Stock shelf**. If a facing fills, the remaining units stay in your hands. You can return them to receiving.
2. Face the checkout. Tap a grocery on the conveyor or choose **Scan item**. The register tracks up to three items at their original shelf prices. For a cash sale, count sterling notes and coins into the change tray and choose **Give change**. Card customers pay at the terminal.
3. Approach the shop computer on the right and choose **Use computer**. Order cases, adjust shelf prices and compare the day's takings and expenditure. Shoppers can leave merchandise they consider too expensive.
4. Spend £30 on the shelf expansion to carry Coast Oats, Jetty Coffee and Pier Tomatoes. Spend £45 to hire a stockroom assistant who carries delivered inventory onto the shelves. With both improvements and fifteen completed checkouts, sign the supply contract at the office for a one-time £25 bonus. The store stays open for further play.

On a phone, drag with your left thumb to walk, drag with your right thumb to look, and tap the labeled action button. In the editor, use WASD or the arrow keys, drag the mouse to look, press E to interact, and Escape to leave the desk. A shift saves after each stock or payment action and when the app pauses. A reserved item and its scan state survive a restart.

## Open and build

Open this **UnityQofeno** directory in Unity Hub using **6000.3.6f1**. Open **Assets/Scenes/Harbor.unity** and press Play. The scene’s [MarketSession](Assets/Qofeno/Runtime/MarketSession.cs) opens the shopkeeper’s view, displays the loading message, and builds the market before enabling movement and saving.

With Android Build Support, its SDK/NDK tools and OpenJDK installed for that editor, choose **Qofeno → Build Android APK**. The output is `Builds/Android/Qofeno-Harbor-Market.apk`. The APK includes native ARM64 code for phones and x86-64 code for emulator testing. Its package ID is `com.qofeno.simulation.unity`. You can also use the [Android build workflow](https://github.com/SohailKhan0525/simulationgame/actions/workflows/unity-android.yml).

## Build on GitHub

The **Unity Android APK** workflow builds on changes to the Android project on `main`. You can also start it from [Actions → Unity Android APK → Run workflow](https://github.com/SohailKhan0525/simulationgame/actions/workflows/unity-android.yml). Select `main` and leave **Publish** enabled for a direct phone download.

Configure activation once in [Settings → Secrets and variables → Actions](https://github.com/SohailKhan0525/simulationgame/settings/secrets/actions). For account activation, set `UNITY_EMAIL`, `UNITY_PASSWORD`, and either `UNITY_LICENSE` (the contents of the Unity Personal license file) or `UNITY_SERIAL` (Pro). A Unity licensing server reachable from the runner is supported through `UNITY_LICENSING_SERVER`. [GameCI activation guide](https://game.ci/docs/github/activation/)

A successful run verifies the APK signature, package name and ARM64 Unity libraries. Its summary links the downloadable APK. Every published preview has a unique `unity-android-` tag. Manual runs with publication disabled keep the APK and checksum in the **Qofeno-Unity-Android** workflow artifact.

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

The simulation passed 57,423 checks, including 8,000 stock and till actions and 500 mid-shift save round-trips. The C# project was typechecked against the matching Unity engine and uGUI APIs. The initial local Unity Editor run stopped during licensing before the scene imported. The [Android workflow](https://github.com/SohailKhan0525/simulationgame/actions/workflows/unity-android.yml) records subsequent build results.

The mobile playtest target for this first Unity slice is to receive stock, complete a sale, order a replacement case and resume a partially scanned sale on an ARM64 phone. The traffic cars in this shift are driven by the simulation.
