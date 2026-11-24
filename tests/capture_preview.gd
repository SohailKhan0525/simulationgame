extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	var isolated:=ProjectSettings.globalize_path("res://../build/test-data/")
	DirAccess.make_dir_recursive_absolute(isolated)
	game.save_file=isolated+"capture-%d.json" % OS.get_process_id()
	game.settings_file=isolated+"capture-%d.cfg" % OS.get_process_id()
	root.add_child(game)
	current_scene=game
	await take("loading")
	while game.mode!="menu": await process_frame
	game.session.cancel_job()
	game.session.status=""
	game.last_session_status=""
	game.toast_timer=0
	await take("menu")
	game._start_drive()
	for _i in range(10): await process_frame
	await take("chase")
	game.camera_mode=0
	game._start_drive()
	for _i in range(10): await process_frame
	await take("cockpit")
	game.camera_mode=1
	game.touch_mode=1
	game._start_drive()
	await take("touch")
	game._settings()
	await take("settings")
	game.settings_tab=1
	game._settings()
	await take("display-settings")
	game._garage()
	await take("garage")
	game.session.start_job(0,game.vehicle.position)
	game._map_screen()
	await take("map")
	game._start_drive()
	root.size=Vector2i(1440,648)
	for _i in range(8): await process_frame
	game._layout_ui()
	await take("wide-touch")
	print("RENDER_PROFILE method=",RenderingServer.get_current_rendering_method()," msaa=",root.msaa_3d," atlas=",ProjectSettings.get_setting("rendering/reflections/reflection_atlas/reflection_size"))
	print("RENDER_CAPTURE_PASS")
	if "--interactive-preview" in OS.get_cmdline_user_args():
		game._menu()
		return
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
