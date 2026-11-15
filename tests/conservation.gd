extends SceneTree
func _initialize():
	var rng := RandomNumberGenerator.new()
	rng.seed=240519
	var m := Market.new()
	var ids := m.catalog.keys()
	for i in 18000:
		var id: String = ids[rng.randi_range(0,ids.size()-1)]
		match rng.randi_range(0,9):
			0: m.order(id)
			1: m.collect(id)
			2: m.put_back()
			3: m.stock()
			4: m.toggle_open()
			5: m.reserve(id)
			6: m.checkout()
			7: m.set_price(id,1 if i%2==0 else -1)
			8: m.expand()
			9: m.cancel_basket()
		if i%20 == 0:
			var saved := JSON.stringify(m.d)
			if not m.restore(JSON.parse_string(saved)):
				printerr("Could not restore at operation ",i)
				quit(1)
				return
		var value_in_goods := 0
		for k in m.catalog:
			var g: Dictionary = m.d.goods[k]
			var count := int(g.back+g.shelf+g.sold)+(int(m.d.quantity) if m.d.carry==k else 0)
			value_in_goods += count*int(m.catalog[k].cost)
		var expected := 95 + int(m.d.revenue) - int(m.d.spend) - (45 if m.d.expanded else 0) + floori(m.d.receipt/5.0)*5
		if m.d.cash!=expected or m.d.spend!=value_in_goods:
			printerr("Conservation failed ",i)
			quit(1)
			return
	print("18,000 deterministic mixed operations and 900 save round-trips passed; ",m.d.receipt," sales.")
	quit()
