extends Node3D

var market := Market.new()
var directory := BusinessDirectory.new()
var slot := Slot.new()
var prefs := Preferences.new()
var updater := HarborUpdates.new()
var sound := HarborSound.new()
var district := District.new()
var player := HarborPlayer.new()
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
	add_child(flow)
	add_child(updater)
	add_child(view)
	ui.app = self
	add_child(ui)
	updater.result.connect(ui.update_result)
	player.footstep.connect(func(): sound.cue("step"))
	flow.changed.connect(ui.refresh)
	prefs.apply(get_viewport(),district.sun)
	view.position = Vector3(-4.6,3.1,12.6)
	view.look_at(Vector3(-4.2,1.9,-0.2))
	view.fov = 61
	show_menu()

func show_menu() -> void:
	in_shift = false
	sound.scene(false)
	view.current = true
	player.hide()
	flow.hide()
	ui.menu()

func request_new() -> void:
	if slot.exists(): ui.confirm_new()
	else: new_shift()

func new_shift() -> void:
	var fresh := Market.new()
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
	market = next
	directory.bind_operator("harbor_market",market)
	market.changed.connect(market_changed)
	if flow.person:
		flow.person.queue_free()
		flow.person = null
	flow.phase = CustomerFlow.Phase.AWAY
	flow.route.clear()
	flow.visits = int(market.d.receipt)
	flow.delay = 2.6
	flow.market = market
	flow.show()
	district.refresh(market)
	district.time_of_day(market.d.clock)
	player.position = Vector3(market.d.pos[0],market.d.pos[1],market.d.pos[2])
	player.yaw = market.d.yaw
	player.pivot.rotation.y = player.yaw
	player.person.rotation.y = player.yaw + PI
	player.person.carton.visible = market.d.quantity > 0
	player.person.hands.carrying = player.person.carton.visible
	player.show()
	player.camera.current = true
	in_shift = true
	sound.scene(true)
	dirty = false
	auto_time = 0
	ui.hud()
	update_location()

func set_playing(value: bool) -> void:
	player.active = value and in_shift
	flow.active = player.active
	if not player.active: player.halt()

func market_changed() -> void:
	dirty = true
	district.refresh(market)
	player.person.carton.visible = market.d.quantity > 0
	player.person.hands.carrying = player.person.carton.visible
	ui.refresh()

func _physics_process(dt: float) -> void:
	if not in_shift: return
	# Defer until the action finishes so rewards and the underlying sale save together.
	if dirty:
		dirty = false
		save_shift(true)
	if not player.active: return
	market.d.clock = fmod(float(market.d.clock)+dt*1.3,1440.0)
	auto_time += dt
	if prefs.values.autosave and auto_time >= 30:
		auto_time = 0
		save_shift(true)
	elapsed += dt
	if elapsed >= 0.16:
		elapsed = 0
		update_location()
		district.time_of_day(market.d.clock)

func update_location() -> void:
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
	ui.refresh()

func interact() -> void:
	if not player.active: return
	update_location()
	if nearest != "":
		var spot: Vector3 = District.SPOTS[nearest]
		var delta := spot-player.position
		if delta.length_squared()>0.01: player.person.rotation.y = atan2(delta.x,delta.z)
		player.person.hands.gesture(nearest,1.2)
	if nearest == "computer":
		market.mark("terminal")
		ui.terminal()
	elif nearest != "": ui.station(nearest)

func save_shift(quiet := false) -> String:
	if not in_shift: return "No active shift."
	var pos := player.position
	market.d.pos = [pos.x,pos.y,pos.z]
	market.d.yaw = player.yaw
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
		if ui.screen == "hud": ui.pause_menu()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_instance_valid(ui) and ui.is_inside_tree():
		ui.back()
