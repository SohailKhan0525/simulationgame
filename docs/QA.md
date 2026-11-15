# QA checkpoint

Run `bash ci/validate.sh` with the pinned Godot executable on PATH, or set GODOT to its absolute path. It performs an editor import, main-scene boot and the GDScript suite. Script/import errors fail the job even when Godot returns exit code zero. Tests create private temporary slots.

The development workspace ran 60 assertions successfully on Godot 4.6.3 Linux x86_64. They cover the live scene and controls, a controller crossing the doorway, workstation reach, supplier order, carry capacity, stocked display, open sign, customer navigation against actual collision, affordability, price locking, payment, duplicate prevention, upgrades, reports, level progression, map selection, two independent touch contacts, backup restoration, schema migration, future saves, settings and update metadata errors.

An additional fixed-seed stress run applies 18,000 mixed store actions with 900 JSON save round-trips, checking stock and money conservation on every action. The desktop review job captures the actual main scene, shop floor, storefront and computer at 1280 × 720. Those screenshots are separate from Android emulator captures.

The Android workflow verifies package ID, version name/code, file size and signer with aapt and apksigner. The smoke test uses a disposable API 35 x86_64 Pixel 5 profile, software GPU rendering, 720 × 1280 display override, 240 dpi and landscape gameplay. It reads actual rendered labels, taps Start, drives the floating joystick, checks the saved movement in internal builds, backgrounds and force-stops the app, then taps Continue and confirms the HUD on relaunch. The artifact contains screenshots and the Android build fingerprint for successful runs. See the release-linked workflow for the exact build outcome.

## Verified internal build

[Release internal-bd1646b866e1](https://github.com/SohailKhan0525/simulationgame/releases/tag/internal-bd1646b866e1) was produced by [Android run 43727365405](https://github.com/SohailKhan0525/simulationgame/actions/runs/43727365405) from commit `bd1646b866e12ca52b700a895a78d5f8b5253811`. All 60 checks and the 18,000-operation stress run passed. The Android test installed and launched the APK, recognized and tapped Start, walked from Z = 5.0 to Z = −3.57 through the front entrance, and confirmed the visit milestone and 4 XP in the background save. It force-stopped the application, relaunched, tapped Continue and observed the HUD back inside the shop. The job passed its Godot error and crash-log check.

The test sent touch input through ADB on a Pixel 5 emulator profile using software Mesa rendering. Its build fingerprint was `Android/sdk_phone64_x86_64/emu64x:15/AE3A.240806.019/12368160:userdebug/test-keys`. The full retail transaction was exercised in the real Godot scene by the headless suite. The Android smoke flow covered touch movement, app lifecycle and save restoration. The release's menu and storefront PNGs are framebuffer captures.

The public download was retrieved and checked against the published digest. File size is 85,156,573 bytes. SHA-256 is `35f9007b784697437d500b093160dc89cb0388f935f0010f7f80ea7f09087f9b`. Android apksigner verified v2 and v3 signatures, and aapt identified `com.qofeno.simulation.internal`, version 0.1.0 (1), minimum SDK 24 and target SDK 36. The only requested Android permission is INTERNET.

## Phone playtest

- Install the internal APK, launch in airplane mode and start a shift. Confirm the logo, menu and text are legible around your notch.
- Move with the left thumb and turn using the right. Walk and run through the door, around the counter and alongside both shelves. Check camera collision.
- Buy a tea carton. Confirm cash falls from $95 to $75 and five tea units arrive. Pick them up, stock them and open the store.
- Let one shopper reach the till. At the default price, take $8 and confirm cash reaches $83. The display now holds four units. Check the receipt in Reports.
- Buy the $45 upgrade. Cash should be $38. Check that shelf capacity is twelve per item. Close and reopen the shop.
- Change the look direction, quality, volume and FPS settings. Save, background, terminate and relaunch. Continue and compare the location, money and stock.
- Check Updates offline, then online. Retry should restore the check without affecting the shift.
- Play for ten minutes outdoors and inside; record phone model, Android version, preset, heat, camera hitches, UI overlap and customer behavior. The 30 FPS and 60 FPS settings are targets, not measured phone frame rates.

Matched-key stable APK-over-APK update, physical-device rendering, touch ergonomics, audio mix, battery life and thermal performance require further testing.

## Checkout lane, version 0.2.0

Godot 4.6.3 on Linux passed 126 checks, including body clearance through the shop, three distinct queue positions, fixed quotes, FIFO payment, stale taps, final-unit contention, returning unpaid baskets, schema 1/2 restoration and closing at 43 different times. The fixed-seed 18,000-action test now mixes three visit IDs with purchases and cancellations. It passed 900 save round-trips and preserved stock and cash.

The Android workflow additionally seeds a progressed shift in the disposable internal app after the original fresh-start and relaunch test. It verifies the three-shopper checkout prompt, taps two consecutive payments, and checks the saved receipts, cash, revenue and remaining stock. See the workflow run for the result. The seed skips setup for this device scenario. The Godot integration suite buys both upgrades through the UI.

On a phone, buy the checkout lane for $32 after the first sale. Stock at least three units. Let the line fill, take two payments and verify each receipt. Close the shop before serving the third shopper and check that the unpaid parcel is back on display.
