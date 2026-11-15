# Harbor Market visual study

The reference set was ten published Steam gallery frames each from [Supermarket Simulator](https://store.steampowered.com/app/2670630/) and [Car For Sale Simulator 2023](https://store.steampowered.com/app/2248760/). This was a screenshot study. Neither game's files were used.

| Observation in the gallery | Change in the playable Harbor District |
|---|---|
| From eye height, Supermarket Simulator's packages have distinct fronts. The register and shelf-edge prices locate the task. | First-person camera with a third-person setting, printed tea and soap packaging, capped cocoa tins, live price labels, point-of-sale hardware and a compact till sheet with the selected product. |
| Retail tasks keep much of the aisle visible. Large management views appear at workstations. | A carried carton goes onto a shelf with one tap. The register and receiving panels occupy the right edge. The market desk keeps a larger supplier list with item pictures and order costs. |
| Car For Sale Simulator's street frames show body reflections, recognizable tire and wheel geometry, different building materials and depth beyond the road. | A fictional estate car with formed panels and alloy wheels, a repainted CC0 classic saloon, photographed asphalt and brick, glossy windows, divided upper-floor windows, street trees, rooflines and a photographed sky. |

In version 0.3 both cars were parked scenery. The models have no car badges or logos. The market has its own products and signs. The work retains Godot's Android compatibility renderer. Shadow-free interior lights, shared meshes, static building batches and a bounded customer population limit rendering work. Physical-device frame-time measurements remain pending.

To capture the actual game, run the Android workflow. Harbor-scenes contains the entrance, menu, stocked display, street, shop floor and market desk. Android-device contains emulator framebuffer captures, receipts and save evidence. The staged desktop views and the seeded Android queue test are documented separately in QA.

## Opening hours

The reference study used the published Steam galleries and public play guides. Supermarket Simulator presents the shop computer as a workstation with a Market cart and separates buying stock, receiving it, filling a shelf and taking payment. Its evening trading boundary and end-of-day statement informed the new sign and closing flow. Car For Sale Simulator shows vehicles from street and driving viewpoints. Qofeno's extended Quay Road, four-wheel estate, chase camera, warm evening light and original desktop illustration were built for this district.

- [Supermarket Simulator, official store and gallery](https://store.steampowered.com/app/2670630/)
- [The computer and applications](https://www.neoseeker.com/supermarket-simulator/The_Computer)
- [Market cart](https://supermarket-simulator.fandom.com/wiki/Market)
- [Trading hours and the daily statement](https://note.com/iyasaka83/n/nf95803f87bcd)
- [Car For Sale Simulator, official store and gallery](https://store.steampowered.com/app/2248760/)

The six fictional grocery prints, desk interface, changing sky, vehicle simulation and till interactions are original to Qofeno. The sky uses its licensed harbor panorama as the daytime layer. The estate has four independently rolling wheels, steerable front hubs and working headlamps.
