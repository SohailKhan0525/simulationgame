extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	while game.mode!="menu": await process_frame
	await take("menu")
	game._start_drive()
	for _i in range(30): await process_frame
	await take("cockpit")
	game._settings()
	await take("settings")
	game._garage()
	await take("garage")
	print("RENDER_CAPTURE_PASS")
	game.queue_free()
	await process_frame
	quit()
func take(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var dir:=ProjectSettings.globalize_path("res://../build/previews/")
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_texture().get_image().save_png(dir+label+".png")
	print("CAPTURED ",label," · draw calls ",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
