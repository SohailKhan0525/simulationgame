extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game = load("res://world/main.tscn").instantiate()
	root.add_child(game)
	game.slot = Slot.new("user://freight-road-%d.json" % Time.get_ticks_usec())
	game.start(Market.opening_shift())
	game.market.edit_cart("tea",1)
	game.market.place_order(game.market.d.cart,true)
	game.player.position = Vector3(-4.1,0.08,7.1)
	game.update_location()
	game.interact()
	var road: HarborRoad = game.road
	road.inputs = Vector2(0,1)
	for i in 900:
		road._physics_process(1.0/60.0)
		if road.estate.position.x>47.05: break
	road.inputs = Vector2(0,-1)
	for i in 125:
		road._physics_process(1.0/60.0)
		if absf(road.estate.speed)<0.12: break
	road.inputs = Vector2.ZERO
	game.handle_freight()
	print("Depot ",road.pose()," ",game.market.d.freight)
	if game.market.d.freight != "estate" or road.estate.cargo_count != 1: quit(1); return
	game.save_shift()
	game.resume_shift()
	if not is_instance_valid(road.estate.roof_load) or road.estate.cargo_count != 1: quit(1); return
	road.inputs = Vector2(0,-1)
	for i in 1400:
		road._physics_process(1.0/60.0)
		if road.estate.position.x< -3.8: break
	road.inputs = Vector2(0,1)
	for i in 60:
		road._physics_process(1.0/60.0)
		if absf(road.estate.speed)<0.14: break
	road.inputs = Vector2.ZERO
	game.handle_freight()
	print("Market ",road.pose()," cash ",game.market.d.cash," tea ",game.market.d.goods.tea.back)
	var ok: bool = game.market.d.shipment.is_empty() and game.market.d.cash==79 and game.market.d.goods.tea.back==5 and road.estate.cargo_count == 0
	for suffix in ["",".bak",".tmp"]:
		var path: String = game.slot.path+suffix
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.free()
	quit(0 if ok else 1)
