# Waterfront 0.3.0 Android handoff

## A. Working game

Start a Harbor Market shift with $95 and opening stock. Walk the waterfront, use the market desk to order cartons, carry goods to the shelves, change prices, open the doors and take payments. A $32 lane unlocks after the first sale and supports three shoppers. Paid sales, stocked items, upgrades and position survive a restart.

## B. Repository

[Graphics and UX PR #3](https://github.com/SohailKhan0525/simulationgame/pull/3) and [retail queue PR #2](https://github.com/SohailKhan0525/simulationgame/pull/2) are merged into main. The shipped source is [75730294c4977a7958c9cb87c29568dfa522cf80](https://github.com/SohailKhan0525/simulationgame/commit/75730294c4977a7958c9cb87c29568dfa522cf80). The world is in `world/`, the native Godot interface in `ui/` and the shop accounts in `core/market.gd`.

## C. APK

[Download the 97,856,370-byte APK](https://github.com/SohailKhan0525/simulationgame/releases/download/internal-75730294c497/Qofeno-Simulation-0.3.0-internal.apk). Version 0.3.0 (3), package `com.qofeno.simulation.internal`, Android v2/v3 debug signature, min SDK 24, target SDK 36. The [release](https://github.com/SohailKhan0525/simulationgame/releases/tag/internal-75730294c497) and [build run](https://github.com/SohailKhan0525/simulationgame/actions/runs/43736526106) identify the source and checksum. Independently verified SHA-256 is `e8c6d29de20655ed4dcfc3e9e143b91f832aa0fec66fd081e63963a367c18e79`.

## D. Tests

Godot 4.6.3 passed 130 checks and 18,000 stock/economy operations with 900 save reloads. An Android 15 Pixel 5 emulator installed the APK, moved by touch, restored a shift after force-stop and recorded two successive touch payments in a seeded three-shopper scenario. [QA details and capture conditions](QA.md)

## E. Install on a phone

Download the APK from the release. Open it with the browser or Files app and allow installation from that source if Android asks. Launch Qofeno Simulation in landscape. An older internal installation has a different test signer. Keep it installed if its private shift matters. Uninstalling it deletes its save.

## F. Updates

Menu or Pause → Updates checks the official GitHub latest-stable endpoint on request. For a newer matching stable release the game opens GitHub in the browser. Internal previews are downloaded from Releases manually. A persistent production signer and a two-version in-place upgrade test remain pending. [Update design](UPDATES.md)

## G. Graphics and assets

The [Steam gallery study](ART_DIRECTION.md) informed the eye-level perspective, printed packages, readable prices, right-side checkout and layered street. The environment uses scanned surfaces, a photographed sky, original buildings, trees and estate cars, and a modified CC0 saloon. The two CC0 rigged characters have locomotion clips, task hand poses, revised shading and clothing variants. [Asset credits](ASSET_LICENSES.md)

## H. Known issues

Cars are parked scenery. Human silhouettes remain stylized. Real phone frame pacing, battery use, touch comfort and production signing still need acceptance. Three shoppers use routes authored for the current shop. [Known issues](KNOWN_ISSUES.md)

## I. Next expansion

Prioritize handset profiling, character art and the stable signer. Expand retail into the computer and gaming shop, then implement vehicle driving and deliveries before dealership and gas operations. Restaurant service and hotel rooms follow after resource, booking and persistence tests. [Roadmap](ROADMAP.md)

## J. Continuation checkpoint

Start from main and the verified source above. Run `bash ci/validate.sh` with Godot 4.6.3. The Android workflow in `.github/workflows/android.yml` builds and tests PRs. A push to a release/internal-* branch publishes a tested prerelease. The next session can read the [machine-readable backlog](backlog.json), [build instructions](ANDROID_BUILDS.md) and [phone checklist](QA.md).
