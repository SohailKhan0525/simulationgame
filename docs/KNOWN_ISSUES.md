# Current limitations

- Internal playtest, English, one owned shop, three products, one upgrade and one concurrent customer. Future premises are closed. Vehicles, pedestrians outside customer visits, employees and other business simulations are pending.
- Original architecture and licensed characters use a stylized low-poly art direction. Stronger material detail, night lighting, dedicated task animations and character variety remain art work.
- The fixed retail route covers this shop's layout. No dynamic crowds, obstacle avoidance, arbitrary shelf rearrangement or generalized navigation mesh is implemented.
- A shopper in progress restarts after a reload. Unpaid baskets keep their units on the shelf. Paid receipts persist.
- Internal CI uses a disposable debug signer. Stable signing, stable-to-stable upgrade testing and personal-device performance acceptance remain open. Keep a test installation if its private save matters.
- The updater hands off to a verified GitHub release page. It relies on the browser and Android package installer. There is no native download manager or in-app install progress.
- No physical handset performance claim has been made. The graphics presets adjust rendering scale and shadows. Scene-wide static batches and city size need measurement before expansion.
