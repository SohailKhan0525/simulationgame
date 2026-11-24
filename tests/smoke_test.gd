extends SceneTree
var failures: Array[String]=[]
var game: Node
func _init() -> void:
	call_deferred("run")
func expect(value: bool,message: String) -> void:
	if not value: failures.append(message); push_error(message)
func frames(count: int) -> void:
	for _i in range(count): await process_frame
func capture(file_name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path("res://../build/previews/")
	DirAccess.make_dir_recursive_absolute(directory)
	root.get_texture().get_image().save_png(directory+file_name)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	var isolated:=ProjectSettings.globalize_path("res://../build/test-data/")
	DirAccess.make_dir_recursive_absolute(isolated)
	game.save_file=isolated+"smoke-%d.json" % OS.get_process_id()
	game.settings_file=isolated+"smoke-%d.cfg" % OS.get_process_id()
	root.add_child(game)
	current_scene=game
	await frames(140)
	expect(game.mode=="menu","Boot reaches menu after actual tile loading")
	await capture("qofeno-menu.png")
	game._start_drive()
	await frames(30)
	expect(game.vehicle.enabled and not game.vehicle.freeze,"Continue enables driving")
	await capture("qofeno-cockpit.png")
	Input.action_press("accelerate")
	await frames(300)
	Input.action_release("accelerate")
	expect(game.vehicle.speed_kmh>10,"Main input drives the vehicle")
	game._menu()
	expect(game.vehicle.freeze,"Menu safely freezes vehicle")
	game._settings()
	expect(is_instance_valid(game.update_label),"Settings includes real update state")
	game._garage()
	expect(game.mode=="panel","Garage renders")
	game._journey()
	game._jobs()
	game._map_screen()
	await frames(3)
	game._start_drive()
	game.session.cancel_job()
	game.session.start_job(0,game.vehicle.position)
	var pickup: Vector3=game.session.get_goal()
	game.vehicle.reset_to(pickup+Vector3.UP*0.8,0)
	game._interact()
	expect(str(game.session.mission.get("stage",""))=="deliver","Pickup works through interact")
	game._save()
	await frames(3)
	print("SMOKE TEST: ","PASS" if failures.is_empty() else "FAIL", " · ",failures.size()," failures")
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
