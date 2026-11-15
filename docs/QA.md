# QA checkpoint

Run `bash ci/validate.sh` with the pinned Godot executable on PATH, or set GODOT to its absolute path. It performs an editor import, main-scene boot and the GDScript suite. Script/import errors fail the job even when Godot returns exit code zero. Tests create private temporary slots.

The development workspace ran 60 assertions successfully on Godot 4.6.3 Linux x86_64. They cover the live scene and controls, a controller crossing the doorway, workstation reach, supplier order, carry capacity, stocked display, open sign, customer navigation against actual collision, affordability, price locking, payment, duplicate prevention, upgrades, reports, level progression, map selection, two independent touch contacts, backup restoration, schema migration, future saves, settings and update metadata errors.

An additional fixed-seed stress run applies 18,000 mixed store actions with 900 JSON save round-trips, checking stock and money conservation on every action. The desktop review job captures the actual main scene, shop floor, storefront and computer at 1280 × 720. Those screenshots are separate from Android emulator captures.

The Android workflow verifies package ID, version name/code, file size and signer with aapt and apksigner. The smoke test uses a disposable API 35 x86_64 Pixel 5 profile, software GPU rendering, 720 × 1280 display override, 240 dpi and landscape gameplay. It reads actual rendered labels, taps Start, backgrounds and force-stops the app, then taps Continue and confirms the HUD on relaunch. The artifact contains screenshots and the Android build fingerprint for successful runs. See the release-linked workflow for the exact build outcome.

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
