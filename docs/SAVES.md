# Shift persistence

The active slot is `user://harbor.json` in Android app-private storage. The current schema is 2. It records the position, camera yaw, day clock, cash, XP, mission flags, receipts, shelf extension, open state, product prices, quantities at receiving and on display, and the carton in hand. The last 15 receipts are retained. Level derives from XP. Anonymous browsing customers restart after loading and keep no money or stock.

Schema 1 restores with a neutral camera yaw. The parser rejects negative or fractional counts, unsupported future schemas, unknown carried goods, invalid capacity, malformed records and non-finite coordinates. A future-version slot blocks saving until the player explicitly chooses to replace the shift.

The game validates the candidate state, writes and flushes a staging file, reads it back, and renames it into the slot. A prior generation is retained as `.bak`. Load tries the primary, temporary and backup snapshots in order. A recovery message identifies a restored backup. Choosing Start fresh replaces the slot only after confirmation. Settings live in `user://settings.cfg`.

Business actions save after the transaction finishes. Timed autosave also records movement every 30 seconds when enabled. App backgrounding, manual Save and leaving the shift save position. Android app removal or clearing app data removes local progress. Internal and stable app IDs have different save directories. No cloud backup, account or export/import UI is implemented.
