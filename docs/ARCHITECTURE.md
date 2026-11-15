# Runtime structure

The main scene owns one district, player, flow of shoppers, camera and UI. It injects the same Market instance into the shop computer, store equipment and customer simulation. The menu camera frames the real storefront. Beginning a shift activates the player's camera in the same district.

| Area | Responsibility |
|---|---|
| `core/market.gd` | Owns cash, prices, stock, shelf capacity, purchases, XP and receipts. Uses whole currency units. Only Market can authorize a sale or upgrade. |
| `core/business_directory.gd`, `data/places.json` | Map metadata and binding of playable premises to running operators. Locked sites reject operator registration. |
| `world/district.gd`, `world/masonry.gd` | Shop, waterfront streets, physical collision and fixed interaction anchors. Static detail is batched by mesh type with per-instance colors. |
| `world/player.gd`, `ui/gestures.gd` | Accelerated ground movement, two independent touch contacts, camera spring-arm collision and walk/run toggle. |
| `world/person.gd`, `world/hand_pose.gd` | Imported skeletal locomotion with crossfades. An analytic two-link pose guides hands to cartons and workstation targets. |
| `world/customer.gd` | One customer at a time follows an authored aisle route, browses, selects an affordable item, waits, pays and departs. Closing cancels the reservation. |
| `ui/interface.gd`, `ui/atlas.gd` | Native Godot Control screens, phone-safe margins, shop computer, map and feedback. Opening a panel halts gameplay simulation. |
| `core/storage.gd`, `core/preferences.gd` | Validated and recoverable shift snapshots, independent persistent settings and live application of preferences. |
| `core/updates.gd` | Optional fixed-origin GitHub Releases check and user-controlled external page handoff. |
| `core/sound.gd` | Original menu theme, synthesized shore loop and activity cues. Master, ambience, music, effects and interface volume controls. |

A product travels from supplier to receiving, into a carried carton and onto the display. Browsing holds a quote in memory. Only checkout debits one displayed unit, records the receipt and credits cash. Saving between selection and payment leaves the item on the shelf. Display price changes affect future baskets. Gross profit subtracts cost of sold goods. Stock purchases, upgrade spend and repeat-order rewards explain differences between cash and gross profit.

Use lower_snake_case resource paths, stable data IDs, typed scene references and Godot-generated UID/import files. Keep secrets and editor caches out of Git. Geometry uses meters. The front of Harbor Market faces positive Z.
