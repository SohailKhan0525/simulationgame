# Qofeno Simulation

Run Harbor Market on Quay Road. Prepare before 08:00 opening, order supplies at the shop computer, fill displays and scan customer purchases. Hire a cashier, license three more groceries and drive the estate along the waterfront. At 21:00 the doors close to new customers. Settle the last baskets, read the day’s statement and open again the next morning.

**Android playtest 0.5.1 · Counter Service** · [Download the 97.9 MB APK](https://github.com/SohailKhan0525/simulationgame/releases/download/internal-efcef962773f/Qofeno-Simulation-0.5.1-internal.apk) · [Release and checksum](https://github.com/SohailKhan0525/simulationgame/releases/tag/internal-efcef962773f)

**Unity and C# edition.** The [Harbor Market Unity project](UnityQofeno/README.md) contains the first native retail shift, original 3D models, and a landscape supplier terminal. The Android playtest linked above is the Godot edition.


Scan mixed baskets, read the running total on the physical register, and look up each receipt at the shop computer. Its monitor shows the same desktop and clock as the touch view. Loaded cartons ride on the estate and affect how it accelerates and brakes.

![A mixed basket on the native Android checkout belt](https://github.com/SohailKhan0525/simulationgame/releases/download/internal-efcef962773f/queue-first-basket.png)

[After the first scan](docs/visuals/counter-after-first-scan.png) · [Shop at night](https://github.com/SohailKhan0525/simulationgame/releases/download/internal-efcef962773f/quay-night.png) · [Workstation](https://github.com/SohailKhan0525/simulationgame/releases/download/internal-efcef962773f/workstation.png) · [Driving](https://github.com/SohailKhan0525/simulationgame/releases/download/internal-efcef962773f/drive-estate.png) · [Android verification](https://github.com/SohailKhan0525/simulationgame/actions/runs/43881759648) · [Reference research and playtest notes](docs/COUNTER_SERVICE.md)

## Play on Android

1. In the repository's Releases section, open the Harbor Market internal playtest and download the `.apk` under Assets. Use a phone with Android 7.0 or newer and OpenGL ES 3 support.
2. Open the file. If Android asks, allow installation from the browser or Files app you used, then confirm Install. You can switch that permission off afterward.
3. Launch **Qofeno Simulation** in landscape. Start new shift. Use Continue on the next launch.
4. If you already play an earlier internal build and want its shift, keep it installed. Internal builds use different debug keys. Android rejects in-place installation across those keys, and uninstalling removes the private save. Production and test editions use separate package IDs. The stable edition will support in-place updates with a persistent signing key. Removing an app deletes its local progress.

## First shift

| Action | Where and how |
|---|---|
| Walk and look | Drag on the left half for the floating stick. Drag on the right to turn the camera. Tap Run or Walk to change pace. Settings → First-person camera switches between eye-level and third-person views. |
| Enter the market | Walk through the open doorway under the striped awning. A contextual button appears within reach of equipment. |
| Order | At the rear-right computer, open Market, add cartons, review the order and choose Place order. The first tea carton costs $20 for five units. |
| Carry and stock | Collect the carton at the front-left pallet. Bring it to the rear-left display and tap Stock to place the contents directly. Product boxes appear on the shelf. |
| Trade | Use the sign beside the door to open. Wait for the shopper to browse and reach the till, then tap each grocery on the moving belt or use Scan product. Authorize a card or count out the difference between cash tendered and the scanned total. |
| Reinvest | At the computer, review receipts, set prices, and install the $45 display extension after the first sale. The $32 checkout lane admits up to three shoppers. Each chooses a product at its current price, then waits their turn. Every fifth sale awards a $5 trading bonus. |
| Hire and license | In Management, hire a cashier for $12 for the current day after your first sale. At level 2, the $36 dry goods licence adds oats, pasta, rice and their display. |
| Drive | Walk up to the blue estate outside the market. Tap Drive estate. Steer with the left controls, use Drive or Brake / R with the right thumb, then stop and tap Get out. |
| Collect by car | During order review, choose Collect by car for up to four cartons. Stop in the marked bay at East Pier Wholesale, load the roof rack, then unload at Harbor Market for a $4 freight credit. |
| Close | Use the door sign to switch the lights or close early. At 21:00, finish serving and return to the sign. Review and finish day shows the totals. Start the next day to return to 08:00. |
| Save and explore | Pause → Save now. Map shows your position and destination. Earnings and stock mutations save after each completed action. |

For desktop development use WASD or arrow keys, Shift to run, right-drag to look, E to interact, M for map and Escape to go back.

## Build and test

Open `project.godot` with **Godot 4.6.3 stable**. Run `bash ci/validate.sh` after installing that engine, or use the repository's Android workflow from a phone. The workflow imports engine resources, runs native GDScript tests, exports a real APK, verifies its signer and package metadata, then boots and relaunches it on an Android emulator.

[Visual study](docs/ART_DIRECTION.md) · [Architecture](docs/ARCHITECTURE.md) · [Android builds](docs/ANDROID_BUILDS.md) · [Saves](docs/SAVES.md) · [Updates](docs/UPDATES.md) · [Device QA](docs/QA.md) · [Known issues](docs/KNOWN_ISSUES.md) · [Roadmap](docs/ROADMAP.md) · [Add a simulator](docs/ADDING_SIMULATORS.md) · [Asset licenses](docs/ASSET_LICENSES.md)

Gameplay uses local storage. The optional update check contacts GitHub. No registration, ads, analytics, backend or Play service is required.
