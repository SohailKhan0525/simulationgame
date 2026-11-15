extends Node3D

var market := Market.new()
var directory := BusinessDirectory.new()
var slot := Slot.new()
var prefs := Preferences.new()
var updater := HarborUpdates.new()
var sound := HarborSound.new()
var district := District.new()
var player := HarborPlayer.new()
var road := HarborRoad.new()
var flow := CustomerFlow.new()
var ui := HarborUI.new()
var view := Camera3D.new()
var in_shift := false
var nearest := ""
var waypoint := Vector2(0,-4)
var version: String = ProjectSettings.get_setting("application/config/version")
var elapsed := 0.0
var auto_time := 0.0
var dirty := false

func _ready() -> void:
	add_child(district)
	add_child(sound)
	add_child(player)
	add_child(road)
	add_child(flow)
	add_child(updater)
	add_child(view)
	ui.app = self
	add_child(ui)
	updater.result.connect(ui.update_result)
	player.footstep.connect(func(): sound.cue("step"))
	flow.changed.connect(ui.refresh)
	prefs.apply(get_viewport(),district.sun)
	view.position = Vector3(-11.3,2.47,16.32)
	view.look_at(Vector3(0.95,3.20,-1.7))
	view.fov = 59
	district.time_of_day(540)
	show_menu()

func show_menu() -> void:
	in_shift = false
	road.aboard = false
	district.time_of_day(540)
	road.set_lighting(district.night)
	sound.scene(false)
	view.current = true
	player.hide()
	flow.hide()
	ui.menu()

func request_new() -> void:
	if slot.exists(): ui.confirm_new()
	else: new_shift()

func new_shift() -> void:
	var fresh := Market.opening_shift()
	# Only an explicit new-shift action can replace an unreadable or future slot.
	var replacement := Slot.new(slot.path)
	replacement.recovery = true
	if not replacement.save(fresh):
		ui.toast(replacement.status)
		return
	for suffix in [".bak",".tmp"]:
		var old := ProjectSettings.globalize_path(slot.path+suffix)
		if FileAccess.file_exists(old): DirAccess.remove_absolute(old)
	slot = replacement
	start(fresh)

func resume_shift() -> void:
	var restored := Market.new()
	if not slot.load_into(restored):
		ui.toast(slot.status)
		return
	start(restored)
	ui.toast(slot.status)

func start(next: Market) -> void:
	if market.changed.is_connected(market_changed): market.changed.disconnect(market_changed)
	if market.display_changed.is_connected(refresh_display): market.display_changed.disconnect(refresh_display)
	market = next
	ui.scanned_visit = 0
	market.display_changed.connect(refresh_display)
	directory.bind_operator("harbor_market",market)
	market.changed.connect(market_changed)
	flow.reset(market)
	flow.show()
	district.refresh(market)
	district.time_of_day(market.d.clock)
	player.position = Vector3(market.d.pos[0],market.d.pos[1],market.d.pos[2])
	player.yaw = market.d.yaw
	player.pivot.rotation.y = player.yaw
	player.person.rotation.y = player.yaw + PI
	player.carry_carton(market.d.quantity > 0)
	player.set_view(prefs.values.first_person)
	player.show()
	road.park(market.d.van)
	road.aboard = market.d.driving
	player.visible = not road.aboard
	player.collision_layer = 0 if road.aboard else 2
	player.collision_mask = 5
	if road.aboard:
		road.update_camera(1.0)
		road.camera.current = true
	else: player.camera.current = true
	road.clear_spawns(player.position)
	road.set_lighting(district.night)
	in_shift = true
	sound.scene(true)
	dirty = false
	auto_time = 0
	ui.hud()
	update_location()

func set_playing(value: bool) -> void:
	road.inputs = Vector2.ZERO
	player.active = value and in_shift and not road.aboard
	flow.active = in_shift and (value or ui.screen in ["terminal","receiving","display","till","sign"])
	road.active = flow.active or not in_shift
	if not value: road.estate.speed = 0
	sound.engine(road.aboard and value,road.estate.speed)
	if not player.active: player.halt()

func refresh_display() -> void:
	district.refresh(market)

func market_changed() -> void:
	dirty = true
	district.refresh(market)
	player.carry_carton(market.d.quantity > 0)
	ui.refresh()

func _physics_process(dt: float) -> void:
	if not in_shift: return
	# Defer until the action finishes so rewards and the underlying sale save together.
	if dirty:
		dirty = false
		save_shift(true)
	if not flow.active: return
	var was_open: bool = market.d.open
	market.advance_clock(dt*2.5)
	if was_open and not market.d.open: ui.toast("21:00 · Trading closed. Serve the last baskets, then visit the door sign.")
	auto_time += dt
	if prefs.values.autosave and auto_time >= 30:
		auto_time = 0
		save_shift(true)
	elapsed += dt
	if elapsed >= 0.16:
		elapsed = 0
		sound.engine(road.aboard and road.active,road.estate.speed)
		update_location()
		district.time_of_day(market.d.clock)
		road.set_lighting(district.night)

func update_location() -> void:
	if road.aboard:
		nearest = ""
		ui.refresh()
		return
	if player.position.z < -0.4 and absf(player.position.x) < 6.8 and player.position.z > -9.9: market.mark("visit")
	nearest = ""
	var best := 2.25
	for key in District.SPOTS:
		var spot: Vector3 = District.SPOTS[key]
		var distance := Vector2(player.position.x-spot.x,player.position.z-spot.z).length()
		if distance >= best: continue
		var from := player.position+Vector3.UP*1.23
		var to := spot+Vector3.UP*1.23
		var ray := PhysicsRayQueryParameters3D.create(from,to,1)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.position.distance_to(to)>0.42: continue
		nearest = key
		best = distance
	var car_point := road.estate.to_local(player.position)
	if absf(car_point.x) <= 2.85 and absf(car_point.z) <= 2.15 and nearest == "":
		nearest = "estate"
	ui.refresh()

func drive_estate() -> void:
	if road.aboard:
		if absf(road.estate.speed) > 0.75:
			ui.toast("Release the accelerator and brake before getting out.")
			return
		var spot: Variant = road.exit_point()
		if spot == null:
			ui.toast("Both doors are blocked. Park in a clear space.")
			return
		road.estate.speed = 0
		player.position = spot
		player.yaw = road.estate.rotation.y - PI/2
		player.pivot.rotation.y = player.yaw
		player.collision_layer = 2
		player.show()
		player.camera.current = true
	else:
		if nearest != "estate": return
		if market.d.quantity > 0:
			ui.toast("Set your carton down before driving.")
			return
		player.halt()
		player.hide()
		player.collision_layer = 0
		road.update_camera(1.0)
		road.camera.current = true
	road.aboard = not road.aboard
	market.d.driving = road.aboard
	road.set_lighting(district.night)
	ui.hud()
	update_location()
	save_shift(true)

func handle_freight() -> void:
	if not road.aboard or ui.screen != "hud": return
	if absf(road.estate.speed)>0.75:
		ui.toast("Stop inside the loading bay.")
		return
	var result := market.transfer_freight(district.loading_bay(road.estate.position))
	ui.toast(result)
	save_shift(true)

func interact() -> void:
	if road.aboard and ui.screen == "hud":
		drive_estate()
		return
	if not player.active: return
	update_location()
	if nearest == "estate":
		drive_estate()
		return
	if nearest != "":
		var spot: Vector3 = District.SPOTS[nearest]
		var delta := spot-player.position
		if delta.length_squared()>0.01: player.person.rotation.y = atan2(delta.x,delta.z)
		player.person.hands.gesture(nearest,1.2)
	if nearest == "computer":
		market.mark("terminal")
		ui.terminal()
	elif nearest == "display" and market.d.quantity > 0:
		var feedback := market.stock()
		sound.cue("crate")
		ui.toast(feedback)
	elif nearest != "": ui.station(nearest)

func save_shift(quiet := false) -> String:
	if not in_shift: return "No active shift."
	var pos := player.position
	market.d.pos = [pos.x,pos.y,pos.z]
	market.d.yaw = player.yaw
	market.d.driving = road.aboard
	market.d.van = road.pose()
	if not slot.save(market) and quiet: ui.toast(slot.status)
	return slot.status

func leave_shift() -> void:
	save_shift()
	if slot.status != "Shift saved.":
		ui.toast(slot.status)
		return
	show_menu()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E: interact()
			KEY_ESCAPE: ui.back()
			KEY_M:
				if ui.screen == "hud": ui.map_view()
				elif ui.screen == "map": ui.hud()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and in_shift:
		save_shift(true)
		if ui.screen != "menu": ui.pause_menu()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_instance_valid(ui) and ui.is_inside_tree():
		ui.back()
