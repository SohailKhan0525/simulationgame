# Qofeno Simulation

Run Harbor Market, a small provisions shop on a walkable waterfront. Start with $95, order your first carton, stock the shelves and open the doors. A shopper chooses an affordable item and brings it to the till. The first payment unlocks a display extension. Your shift, prices, receipts and upgrades persist on the phone.

**Development status** • The Harbor Market district is an internal Android playtest. The hotel, computer store and café appear as future premises. Public APKs and their checksums are distributed on [GitHub Releases](https://github.com/SohailKhan0525/simulationgame/releases).

## Play on Android

1. In the repository's Releases section, open the Harbor Market internal playtest and download the `.apk` under Assets. Use a phone with Android 7.0 or newer and OpenGL ES 3 support.
2. Open the file. If Android asks, allow installation from the browser or Files app you used, then confirm Install. You can switch that permission off afterward.
3. Launch **Qofeno Simulation** in landscape. Start new shift. Use Continue on the next launch.
4. Keep the internal app installed to retain its save. Production and test editions use separate package IDs. The stable edition will support in-place updates with a persistent signing key. Removing an app deletes its local progress.

## First shift

| Action | Where and how |
|---|---|
| Walk and look | Drag on the left half for the floating stick. Drag on the right to turn the camera. Tap Walking to toggle running. |
| Enter the market | Walk through the open doorway under the striped awning. A contextual button appears within reach of equipment. |
| Order | Use the rear-right computer, choose Orders, and buy a carton. The first tea carton costs $20 for five units. |
| Carry and stock | Collect the carton at the front-left pallet. Bring it to the rear-left display and stock it. Product boxes appear on the shelf. |
| Trade | Use the sign beside the door to open. Wait for the shopper to browse and reach the till, then use Checkout to take payment. |
| Reinvest | At the computer, review receipts, set prices, and install the $45 display extension after the first sale. Every fifth sale awards a $5 trading bonus. |
| Save and explore | Pause → Save now. Map shows your position and destination. Earnings and stock mutations save after each completed action. |

For desktop development use WASD or arrow keys, Shift to run, right-drag to look, E to interact, M for map and Escape to go back.

## Build and test

Open `project.godot` with **Godot 4.6.3 stable**. Run `bash ci/validate.sh` after installing that engine, or use the repository's Android workflow from a phone. The workflow imports engine resources, runs native GDScript tests, exports a real APK, verifies its signer and package metadata, then boots and relaunches it on an Android emulator.

[Architecture](docs/ARCHITECTURE.md) · [Android builds](docs/ANDROID_BUILDS.md) · [Saves](docs/SAVES.md) · [Updates](docs/UPDATES.md) · [Device QA](docs/QA.md) · [Known issues](docs/KNOWN_ISSUES.md) · [Roadmap](docs/ROADMAP.md) · [Add a simulator](docs/ADDING_SIMULATORS.md) · [Asset licenses](docs/ASSET_LICENSES.md)

Gameplay uses local storage. The optional update check contacts GitHub. No registration, ads, analytics, backend or Play service is required.
