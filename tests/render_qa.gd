extends SceneTree
## Render reference frames with Godot's real desktop compatibility renderer.
var folder: String
var game
var failed := false

func _initialize() -> void:
	run.call_deferred()

func snap(label: String) -> void:
	for i in 4: await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(folder.path_join(label+".png")) != OK:
		failed = true
		printerr("Could not capture ",label)

func run() -> void:
	folder = OS.get_cmdline_user_args()[0]
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		quit(1)
		return
	game = load("res://world/main.tscn").instantiate()
	game.slot = Slot.new("user://render-review.json")
	root.add_child(game)
	await snap("menu")
	var market := Market.new()
	for id in market.catalog:
		market.order(id)
		market.collect(id)
		market.stock()
	market.toggle_open()
	game.start(market)
	await snap("storefront")
	game.player.position = Vector3(0.3,0.06,-2.3)
	game.player.yaw=0.39
	game.player.pivot.rotation.y=0.39
	game.update_location()
	await snap("shop-floor")
	game.player.position = Vector3(-4.5,0.06,-5.23)
	game.player.yaw = 0
	game.player.pivot.rotation.y = 0
	game.player.arm.rotation.x = -0.20
	game.update_location()
	await snap("stocked-display")
	game.player.position = Vector3(-0.6,0.06,13.3)
	game.player.pivot.rotation.y = 0.65
	game.player.arm.rotation.x = 0.02
	game.update_location()
	await snap("quayside-street")
	game.player.position=Vector3(4.6,0.05,-7.2)
	game.interact()
	await snap("workstation-desktop")
	game.market.edit_cart("tea",1)
	game.market.edit_cart("soap",1)
	game.ui.terminal("Market")
	await snap("shop-computer")
	game.ui.hud()
	game.player.position = Vector3(-4.1,0.07,7.05)
	game.update_location()
	game.interact()
	await snap("drive")
	game.interact()
	game.player.position = Vector3(-7.1,0.06,15.9)
	game.player.pivot.rotation.y = -0.35
	game.player.arm.rotation.x = 0.08
	for period in [[1082.0,"sunset"],[1259.0,"night"]]:
		market.d.clock = period[0]
		game.district.time_of_day(period[0])
		game.road.set_lighting(game.district.night)
		await snap(period[1])
	game.free()
	quit(1 if failed else 0)
