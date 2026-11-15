# Adding a business

1. Choose a persistent ID and add a premises record to `data/places.json`. Set its type, world X/Z, map name and playable flag. Add the matching physical premises to the district. Future locations can be displayed without an operator.
2. Build a state-owning RefCounted operator with validated actions. Keep money changes inside the domain model. Reuse Market for retail when its inventory and checkout rules fit. Define a service model for room nights, fuel or prepared meals.
3. Bind the operator with `BusinessDirectory.bind_operator(id, operator)` during shift creation and restoration. Look it up by ID when opening its workstation. The current checkout and store HUD explicitly address Harbor Market.
4. Add the new interaction anchors, collision and routes, equipment screens and capacity tests. Customers need paths that remain clear with every upgrade.
5. Extend the save schema with a namespaced entry for the new operator. Add a migration and default state for existing shifts. Keep the retail fields and property IDs readable across upgrades.
6. Test unlock, ownership, an entire paid transaction, insufficient funds, cancellation, save restoration and map behavior before turning on the playable flag.

The current directory supports registry lookups and a single active retail operator. Hotel bookings, vehicle physics, staff scheduling and cross-business accounting are separate implementation projects.
