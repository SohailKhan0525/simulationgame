# Opening Hours · Android 0.4.0

## A. Working game

The first shop day begins at 08:00. Prepare stock and set prices before opening. Use the sign to open, close or switch the interior lights. Four traffic cars follow Quay Road. Walk to the blue estate, get in, steer and drive, then stop to get out. The car and any prepaid cargo persist across saves.

Use the rear desk to open Market, Pricing, Management or Ledger. Review a mixed-carton order and pay once. Standard orders appear at receiving. Collect by car holds up to four cartons at East Pier Wholesale. Load the stationary estate at the depot bay and unload at the market for a $4 credit. After the first sale you can hire a cashier for $12 for the current day. A level-two $36 dry goods licence unlocks oats, pasta and rice. Customers reserve stock, queue and pay at the counter. Scan the item, then authorize the card or count the correct cash change.

At 21:00 new arrivals stop. Customers holding baskets can finish paying. Use the sign to read the closing statement and begin the next morning at 08:00. The store reopens by player choice.

## B. Repository

[Pull request 4](https://github.com/SohailKhan0525/simulationgame/pull/4) · [Shipped source a5559630b84b](https://github.com/SohailKhan0525/simulationgame/commit/a5559630b84befd4ca34252d9afa2e9549b9bed1). Scene entry is `world/main.tscn`. Core files are `core/market.gd`, `world/district.gd`, `world/motor_pool.gd`, `world/estate.gd`, `world/customer.gd` and `ui/desk.gd`.

## C. APK delivery

[Download APK](https://github.com/SohailKhan0525/simulationgame/releases/download/internal-a5559630b84b/Qofeno-Simulation-0.4.0-internal.apk) · [Release internal-a5559630b84b](https://github.com/SohailKhan0525/simulationgame/releases/tag/internal-a5559630b84b) · [Build run](https://github.com/SohailKhan0525/simulationgame/actions/runs/43747488356). The debug-signed internal APK is 97,898,870 bytes. Its package is `com.qofeno.simulation.internal`, version 0.4.0 (4), min SDK 24 and target SDK 36. Download validation included Android package inspection and v2/v3 signature verification.

SHA-256 `b9419b2c6ae13284ace4d81b1fc0e9949a8bcef14430a01be6d1bc44270228c4`

Signer SHA-256 `5f26c17362b60f8b8921697aa32e8f9bcb985fd4a6511587f2bd6aab5fce866d`

## D. Verification

Godot 4.6.3 passed 158 gameplay assertions, 18,000 deterministic store operations and 900 serialized save round-trips. Two actual schema-3 Android snapshots migrated with their balances and receipt counts intact. A separate 24,000-action exercise conserved money and inventory across 279 trading days with wages and freight credits. A native trip drove from the market to X 51.82 at the depot, loaded a prepaid order, reloaded the occupied estate and returned to X −4.46. The shop received five units of tea and the wallet ended at $79.

The Android 15 Pixel 5 emulator installed the exported APK, walked using touch and restored the shift after force-stop. In a seeded three-person queue, two real touch payments left $67 and 3 receipts. A separate fixture placed a mixed order from the computer. The device verified $29 remaining, five tea and six soap units at receiving. A touch-driven estate moved from X −4.10 to X -3.06. The saved driver relaunched in the car and got out. The device closed a seeded evening and verified day two at 08:00 with $67 and closed doors. Evening images use the installed APK at a staged location and time. Physical phone performance remains unmeasured.

## E. Install

Open the APK link on Android. If prompted, allow this download source to install apps, tap Install and launch Qofeno Simulation in landscape. This test build uses a different signing key from 0.3. Android cannot update the old test installation in place. Keep that installation to preserve its private save. A separate phone or Android user profile can keep both playtests available.

## F. Updates

Menu or Pause → Updates checks the official stable GitHub release on request. A newer accepted version opens its release page for manual installation. Internal playtests are downloaded directly from Releases. Stable in-place upgrades need the persistent signing identity and a two-version phone check.

## G. Graphics and references

The original Harbor OS desktop and wholesale order desk run inside the native game. The district uses its credited Poly Haven materials, sky and props, animated Quaternius people, original Blender estate with independent wheels, original labels, and an evening sky shader. Shop lighting, street lamps, lit apartment windows and the estate headlamps respond to the time of day. [Visual references and asset provenance](ART_DIRECTION.md) · [Licences](ASSET_LICENSES.md)

## H. Known limits

One shop, six products, one estate, one wholesale depot and a single waterfront street are playable. Each shopper carries one item. The cashier contract runs through the current day. Full store layout editing, online customer deliveries, multiple employees, theft, multiplayer and stable phone performance figures remain open.

## I. Expansion

Prioritize multi-item baskets, shelf placement and phone performance. Extend freight to customer deliveries, then shared vehicle ownership, fuel, dealership trading, and additional businesses including the gaming shop, restaurant and hotel. [Roadmap](ROADMAP.md) · [Backlog](backlog.json)

## J. Continuation

Check out the shipped source above or current main. Run `bash ci/validate.sh` using Godot 4.6.3. Run the Android workflow on a feature PR for full export, desktop captures and Android touch checks. A `release/internal-*` branch publishes the internal playtest after tests pass. Configure the production signer before publishing a stable version tag. [Android build instructions](ANDROID_BUILDS.md) · [QA record](QA.md)
