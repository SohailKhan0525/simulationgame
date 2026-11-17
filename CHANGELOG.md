# Changelog

## Unity Android 0.2.0 · Harbor Market

- Open a stocked grocery at 08:00. Serve shoppers with one to three items and a second shopper who can browse and join the queue.
- Tap items on the counter, count sterling change or accept a card. A shopper keeps their quoted prices when the owner changes a shelf label.
- Use the office to set prices, order six products across two ranges, buy a store expansion, hire a stockroom assistant and review daily accounts.
- Complete a supply contract by serving 15 customers and purchasing both improvements. The contract pays a single £25 bonus and trading continues.
- Added original product packaging, shelf-edge labels, shop fittings and shopper outfits. The Android update migrates existing inventory, carried cartons and pending sales.

## Unity Android 0.1.0 · In development

- Added the Unity Harbor Market shift, editable models and C# tests.
- Retired the earlier engine project and Android exporter. Unity now owns the Android application and build workflow.

## Earlier prototype history

The entries below record the retired prototype’s separate version line.

## 0.5.1 · Shop-floor detail

- The physical computer shows the same desktop shortcuts and trading clock as the touch interface. The register shows each scanned subtotal on both faces.
- The visible shop fittings switch with the indoor lights. Street-lamp diffusers brighten at dusk and apartment windows light up in stages.
- The Android checkout test taps the first physical grocery and uses the fixed button for the next one.

## 0.5.0 · Counter Service

- Shoppers gather up to three different groceries from the display they visit. Each unit keeps its shelf price until paid.
- Scan individual packages on the counter or use the Scan button. Watch each package move onto the bagging deck, take cash or card, then read the itemized receipt in Ledger.
- Supplier cartons are strapped onto the estate. Loaded acceleration and braking account for the cargo, including after a reload.
- Existing shifts migrate their receipts to the itemized format. The Android touch test runs a mixed cash basket followed by a card sale.

## 0.4.0 · Opening Hours

- Trade from 08:00 to 21:00 with a sunset, streetlamps, shop light switch and closing statement. Start the next day with your stock and cash.
- Operate a desktop with Market, Pricing, Management and Ledger. Build mixed-carton orders, inspect the receipt, hire a cashier and unlock three dry groceries.
- Scan items, accept cards and count cash change. Finish serving queued shoppers after the doors close.
- Drive the estate on Quay Road with touch controls, headlamps and persistent parking. Four other cars circulate and yield. Collect up to four prepaid cartons at East Pier Wholesale and unload them at the shop for a $4 freight credit.
- Schema 4 migrates existing shifts. The Android internal package uses a per-build debug signer.


## 0.3.0 internal playtest — Waterfront

- Rebuilt the market exterior, floor materials, sky, street trees, parked cars, shop fixtures and products. Added original package fronts and shelf-edge pricing.
- Start at eye level, switch to third person in Settings, stock a held carton directly and review the basket in a compact checkout sheet.
- Redesigned the title screen, HUD, supplier ordering and touch controls. Added close-up shop and street captures to visual QA.

## 0.2.0 internal playtest — Checkout lane

- Added a $32 checkout lane at the shop computer, available after the first payment. Three shoppers can visit together, collect visible parcels and take turns at the till.
- Held units leave the display immediately. Each shopper keeps the quoted price. Closing the shop or restoring a shift returns unpaid items. Only the shopper at the front can pay.
- Added floor markings, live queue counts, migration of 0.1.0 saves and regression tests for closing the shop at different points in a visit.

## 0.1.0 internal playtest — Harbor Market

- Built a native third-person Android waterfront district with an enterable provisions shop and three future storefronts.
- Connected supplier orders, carton handling, visible shelving, customer budgets, one-customer checkout, receipts and a display upgrade.
- Added the Harbor OS shop computer, map, missions, XP, timed and transaction saves, recovery, settings, audio and manual GitHub release checks.
- Pinned Godot and export templates, added Android verification and emulator smoke checks, and separated debug playtests from persistent-key production signing.
