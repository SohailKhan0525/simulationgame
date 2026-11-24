extends Node3D
const Vehicle = preload("res://scripts/vehicle.gd")
const World = preload("res://scripts/world.gd")
const Session = preload("res://scripts/session.gd")
const Minimap = preload("res://scripts/minimap.gd")
const Updater = preload("res://scripts/updater.gd")
const GOLD := Color("ffcb85")
const TEAL := Color("6dded0")
const INK := Color("0b1922")
var vehicle: DriveVehicle
var world: DriveWorld
var session: DriveSession
var updater: Node
var canvas: CanvasLayer
var screen: Control
var hud: Control
var mode := "boot"
var settling := false
var ui_theme: Theme
var menu_camera: Camera3D
var loading_bar: ProgressBar
var loading_label: Label
var speed_label: Label
var stats_label: Label
var objective_label: Label
var toast_label: Label
var clock_label: Label
var map_view: Control
var update_label: Label
var offer_panel: PanelContainer
var goal_marker: MeshInstance3D
var paused := true
var quality := 0 if OS.get_name()=="Android" else 1
var audio_level := 0.65
var rain_mode := 0
var weather_time := 0.0
var wetness := 0.0
var steer_touch := 0.0
var throttle_touch := 0.0
var brake_touch := 0.0
var reverse_touch := false
var timer := 0.0
var save_timer := 0.0
var offer_timer := 0.0
var greeting_timer := 0.0
var fueling := false
var fuel_added := 0.0
var laugh_queue: Array = []
var laugh_timer := 0.0
var last_status := ""
var last_session_status := ""
var active_race_id := ""
var warning := ""
var safe_spawn := Vector3(5,0.8,20)

func _ready() -> void:
	_setup_input()
	_setup_theme()
	session=Session.new()
	session.load_save()
	_load_settings()
	world=World.new()
	add_child(world)
	world.set_quality(quality)
	vehicle=Vehicle.new()
	add_child(vehicle)
	vehicle.configure(int(session.state.car),int(session.state.upgrades[int(session.state.car)]))
	var saved: Array = session.state.position
	vehicle.reset_to(Vector3(float(saved[0]),maxf(0.8,float(saved[1])),float(saved[2])),float(session.state.yaw))
	vehicle.fuel_liters=float(session.state.fuel)
	vehicle.damage=float(session.state.damage)
	vehicle.enabled=false
	vehicle.freeze=true
	world.set_player(vehicle)
	menu_camera=Camera3D.new()
	add_child(menu_camera)
	menu_camera.fov=55
	menu_camera.far=1100
	_set_menu_camera()
	updater=Updater.new()
	add_child(updater)
	canvas=CanvasLayer.new()
	add_child(canvas)
	screen=Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.theme=ui_theme
	canvas.add_child(screen)
	goal_marker=MeshInstance3D.new()
	var ring:=CylinderMesh.new()
	ring.top_radius=5
	ring.bottom_radius=5
	ring.height=0.07
	goal_marker.mesh=ring
	var glow:=StandardMaterial3D.new()
	glow.albedo_color=TEAL
	glow.emission_enabled=true
	glow.emission=TEAL
	goal_marker.material_override=glow
	add_child(goal_marker)
	_show_loading("Preparing your city",false)

func _setup_input() -> void:
	var bindings := {"accelerate":KEY_W,"brake":KEY_S,"left":KEY_A,"right":KEY_D,"handbrake":KEY_SPACE,"interact":KEY_E,"horn":KEY_H,"pause_drive":KEY_ESCAPE,"reverse":KEY_R}
	for action in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		var event:=InputEventKey.new()
		event.physical_keycode=bindings[action]
		InputMap.action_add_event(action,event)
	for pair in [["accelerate",KEY_UP],["brake",KEY_DOWN],["left",KEY_LEFT],["right",KEY_RIGHT]]:
		var event:=InputEventKey.new()
		event.physical_keycode=pair[1]
		InputMap.action_add_event(pair[0],event)

func _setup_theme() -> void:
	ui_theme=Theme.new()
	ui_theme.default_font_size=19
	ui_theme.set_color("font_color","Label",Color("ebf0ed"))
	for state in ["normal","hover","pressed","disabled","focus"]:
		var box:=StyleBoxFlat.new()
		box.bg_color=Color("19303b") if state=="normal" else Color("34515b")
		if state=="disabled": box.bg_color=Color("101f29")
		box.set_corner_radius_all(8)
		box.set_content_margin_all(13)
		box.border_color=Color("45616a")
		box.set_border_width_all(1 if state=="focus" else 0)
		ui_theme.set_stylebox(state,"Button",box)
	ui_theme.set_color("font_color","Button",Color("eef3ed"))
	ui_theme.set_color("font_disabled_color","Button",Color("6c808b"))
	var panel:=StyleBoxFlat.new()
	panel.bg_color=Color(0.025,0.065,0.09,0.96)
	panel.set_corner_radius_all(16)
	panel.set_content_margin_all(24)
	panel.border_color=Color("29434e")
	panel.set_border_width_all(1)
	ui_theme.set_stylebox("panel","PanelContainer",panel)

func _clear_ui() -> void:
	for child in screen.get_children():
		screen.remove_child(child)
		child.queue_free()
	hud=null
	update_label=null
	offer_panel=null
	steer_touch=0
	throttle_touch=0
	brake_touch=0

func _label(text: String, size_font: int=20, color: Color=Color("ebf0ed")) -> Label:
	var label:=Label.new()
	label.text=text
	label.add_theme_font_size_override("font_size",size_font)
	label.add_theme_color_override("font_color",color)
	return label

func _button(text: String, action: Callable, height: float=48) -> Button:
	var button:=Button.new()
	button.text=text
	button.custom_minimum_size.y=height
	button.pressed.connect(action)
	button.focus_mode=Control.FOCUS_NONE
	return button

func _panel(pos: Vector2, dim: Vector2) -> VBoxContainer:
	var panel:=PanelContainer.new()
	panel.position=pos
	panel.size=dim
	screen.add_child(panel)
	var box:=VBoxContainer.new()
	box.add_theme_constant_override("separation",12)
	panel.add_child(box)
	return box

func _set_menu_camera() -> void:
	menu_camera.position=vehicle.position+Vector3(6,3,-7)
	menu_camera.look_at(vehicle.position+Vector3(0,0.6,0))
	menu_camera.current=true

func _show_loading(title: String, continuing: bool) -> void:
	_clear_ui()
	mode="loading_drive" if continuing else "boot"
	var box:=_panel(Vector2(390,245),Vector2(500,220))
	box.add_child(_label("QOFENO  /  DRIVE",28,GOLD))
	box.add_child(_label(title,22))
	loading_bar=ProgressBar.new()
	loading_bar.custom_minimum_size.y=10
	loading_bar.show_percentage=false
	box.add_child(loading_bar)
	loading_label=_label("Streaming streets and surroundings...",16)
	box.add_child(loading_label)

func _menu() -> void:
	pause_vehicle()
	_clear_ui()
	mode="menu"
	_set_menu_camera()
	var box:=_panel(Vector2(58,62),Vector2(390,585))
	box.add_child(_label("OPEN ROAD. YOUR STORY.",14,TEAL))
	box.add_child(_label("QOFENO\nDRIVE",56,GOLD))
	box.add_child(_label("New York region / Early access",17))
	box.add_child(HSeparator.new())
	box.add_child(_button("CONTINUE YOUR DRIVE   →",_continue_drive,58))
	box.add_child(_button("Garage & upgrades",_garage))
	box.add_child(_button("Your journey · 20 levels",_journey))
	box.add_child(_button("Settings & updates",_settings))
	box.add_child(_label("LEVEL %02d     $%s" % [session.get_level(),int(session.state.cash)],18,TEAL))
	var info:=_label("FICTIONAL NYC-SCALE WORLD\n784 km² to discover · More regions coming soon",16,Color("c4d8de"))
	info.position=Vector2(740,618)
	screen.add_child(info)

func _continue_drive() -> void:
	_show_loading("Getting you back on the road",true)

func _start_drive() -> void:
	_clear_ui()
	mode="drive"
	paused=false
	vehicle.freeze=false
	vehicle.enabled=true
	vehicle.get_node("CockpitCamera").current=true
	vehicle.get_node("CockpitCamera").far=[240.0,520.0,700.0][quality]
	_build_hud()
	greeting_timer=1.4

func pause_vehicle() -> void:
	paused=true
	fueling=false
	if vehicle:
		vehicle.enabled=false
		vehicle.freeze=true
		vehicle.throttle=0
		vehicle.brake=0
		vehicle.steer=0
	_save()

func _build_hud() -> void:
	hud=Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	screen.add_child(hud)
	_hud_back(Vector2(14,10),Vector2(1252,66))
	_hud_back(Vector2(16,247),Vector2(306,112))
	_hud_back(Vector2(266,85),Vector2(688,67))
	var top:=_label("QOFENO / DRIVE",18,GOLD)
	top.position=Vector2(28,20)
	hud.add_child(top)
	clock_label=_label("",17)
	clock_label.position=Vector2(28,49)
	hud.add_child(clock_label)
	stats_label=_label("",20,TEAL)
	stats_label.position=Vector2(890,24)
	hud.add_child(stats_label)
	var pause_button:=_button("Ⅱ",_menu,44)
	pause_button.position=Vector2(1200,18)
	pause_button.size.x=52
	hud.add_child(pause_button)
	map_view=Minimap.new()
	map_view.position=Vector2(28,92)
	map_view.size=Vector2(205,150)
	map_view.player=vehicle
	hud.add_child(map_view)
	objective_label=_label("",17)
	objective_label.position=Vector2(28,256)
	objective_label.size=Vector2(280,96)
	objective_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(objective_label)
	speed_label=_label("000",44,GOLD)
	speed_label.position=Vector2(600,526)
	hud.add_child(speed_label)
	var km:=_label("KM/H",13)
	km.position=Vector2(610,580)
	hud.add_child(km)
	toast_label=_label("WASD / arrows: drive   ·   E: interact   ·   H: horn   ·   R: reverse",17)
	toast_label.position=Vector2(280,90)
	toast_label.size=Vector2(660,60)
	toast_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(toast_label)
	_hold_button("<",Vector2(30,550),Vector2(96,96),func(): steer_touch=-1,func(): steer_touch=0)
	_hold_button(">",Vector2(140,550),Vector2(96,96),func(): steer_touch=1,func(): steer_touch=0)
	_hold_button("BRAKE",Vector2(1020,550),Vector2(100,108),func(): brake_touch=1,func(): brake_touch=0)
	_hold_button("DRIVE",Vector2(1134,520),Vector2(116,138),func(): throttle_touch=1,func(): throttle_touch=0)
	var actions:=HBoxContainer.new()
	actions.position=Vector2(312,652)
	actions.add_theme_constant_override("separation",8)
	hud.add_child(actions)
	actions.add_child(_button("Jobs",_jobs,40))
	actions.add_child(_button("Interact",_interact,40))
	actions.add_child(_button("Horn",func(): vehicle.horn(),40))
	actions.add_child(_button("D / R",func(): reverse_touch=not reverse_touch,40))
	actions.add_child(_button("Map",_map_screen,40))
	actions.add_child(_button("Rescue",_rescue,40))

func _hud_back(pos: Vector2, dim: Vector2) -> void:
	var panel:=Panel.new()
	panel.position=pos
	panel.size=dim
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style:=StyleBoxFlat.new()
	style.bg_color=Color(0.025,0.065,0.09,0.82)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel",style)
	hud.add_child(panel)

func _hold_button(text: String,pos: Vector2,dim: Vector2,down: Callable,up: Callable) -> void:
	var button:=_button(text,func(): pass)
	button.position=pos
	button.size=dim
	button.button_down.connect(down)
	button.button_up.connect(up)
	hud.add_child(button)

func _page(title: String, subtitle: String="") -> VBoxContainer:
	pause_vehicle()
	_clear_ui()
	mode="panel"
	var box:=_panel(Vector2(120,35),Vector2(1040,650))
	var heading:=HBoxContainer.new()
	box.add_child(heading)
	var text:=_label(title,30,GOLD)
	text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	heading.add_child(text)
	heading.add_child(_button("Back to drive",_start_drive,44))
	if subtitle!="": box.add_child(_label(subtitle,17))
	return box

func _jobs() -> void:
	var box:=_page("THE DISPATCH", "Passenger stories, deliveries and time trials. Stop inside each glowing marker to interact.")
	if not session.mission.is_empty():
		box.add_child(_label("Active: "+str(session.mission.get("title","Journey")),19,TEAL))
		box.add_child(_button("Cancel active job",func(): session.cancel_job(); _jobs()))
	var scroll:=ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var list:=VBoxContainer.new()
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var jobs: Array=session.get_jobs()
	for i in range(jobs.size()):
		var job: Dictionary=jobs[i]
		var index:=i
		var title:=str(job.get("title","Job"))
		var level:=int(job.get("level",i+1))
		var button:=_button("%02d   %s    ·    Level %d    ·    $%d" % [i+1,title,level,int(job.get("reward",250))],func(): _notify(session.start_job(index,vehicle.position)); _start_drive())
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.disabled=session.get_level()<level or not session.mission.is_empty()
		list.add_child(button)

func _garage() -> void:
	var box:=_page("YOUR GARAGE", "Earn your next machine. Car upgrades improve power and grip. More cars coming soon.")
	box.add_child(_label("Balance  $%d" % int(session.state.cash),24,TEAL))
	for index in range(3):
		var i:=index
		var specs: Dictionary=session.get_car_specs(i)
		var label:=str(specs.get("name",["Aster S","Meridian GT","Veloce R"][i]))
		label+="   ·   "+("Owned" if bool(session.state.owned[i]) else "$%d"%int(specs.get("price",0)))
		if int(session.state.car)==i: label+="   ·   CURRENT"
		box.add_child(_button(label,func():
			warning=session.buy_car(i)
			_apply_car()
			_garage()))
	box.add_child(_button("Upgrade current car",func(): warning=session.upgrade_car(); _apply_car(); _garage()))
	box.add_child(_button("Repair bodywork · $%d" % ceili(vehicle.damage*4.0),func(): session.state.damage=vehicle.damage; warning=session.repair_car(); vehicle.damage=float(session.state.damage); _garage()))
	box.add_child(_label("Upgrade tier %d / 5" % int(session.state.upgrades[int(session.state.car)]),20))
	box.add_child(_label(warning,18,GOLD))
	box.add_child(_label("Vehicle changes are saved immediately.",16))

func _apply_car() -> void:
	vehicle.configure(int(session.state.car),int(session.state.upgrades[int(session.state.car)]))
	_save()

func _journey() -> void:
	var box:=_page("YOUR JOURNEY", "20 driving levels · All of the New York region is open from the start.")
	box.add_child(_label("LEVEL %02d   /   20     ·     %d XP" % [session.get_level(),int(session.state.xp)],32,TEAL))
	var bar:=ProgressBar.new()
	bar.value=session.get_level_progress()*100
	box.add_child(bar)
	box.add_child(_label("Complete passenger trips and races to earn money and experience.",20))
	box.add_child(_label("Every level brings a new dispatch. Earlier jobs remain replayable.",20))
	box.add_child(_label("BEYOND THE CITY",26,GOLD))
	box.add_child(_label("Hudson Highlands     LOCKED · Coming soon\nAtlantic Coast          LOCKED · Coming soon\nMore levels and cars coming soon",22))
	box.add_child(_button("Open dispatch",_jobs))

func _settings() -> void:
	var box:=_page("SETTINGS", "Choose a comfortable balance for your device.")
	var q:=OptionButton.new()
	for text in ["Low · shorter view / lighter shadows","Balanced · recommended","High · longer view"]: q.add_item(text)
	q.select(quality)
	q.item_selected.connect(func(index): quality=index; world.set_quality(index); _save_settings())
	box.add_child(q)
	box.add_child(_label("Engine and ambience volume",18))
	var volume:=HSlider.new()
	volume.max_value=1
	volume.step=0.05
	volume.value=audio_level
	volume.value_changed.connect(func(value): audio_level=value; _save_settings())
	box.add_child(volume)
	var rain:=OptionButton.new()
	for text in ["Weather · automatic","Weather · clear","Weather · rain"]: rain.add_item(text)
	rain.select(rain_mode)
	rain.item_selected.connect(func(index): rain_mode=index; _save_settings())
	box.add_child(rain)
	box.add_child(_label("GAME UPDATES",22,GOLD))
	update_label=_label(updater.message,17)
	update_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	box.add_child(update_label)
	var row:=HBoxContainer.new()
	box.add_child(row)
	row.add_child(_button("Check for updates",func(): updater.check()))
	row.add_child(_button("Download update",func(): updater.download()))
	row.add_child(_button("Install update",func(): updater.install()))
	box.add_child(_label("Downloads continue in the background. Android asks before installation.\nYour drive is saved before leaving the game.",16))
	box.add_child(_button("Main menu",_menu))

func _map_screen() -> void:
	var box:=_page("NEW YORK REGION", "Procedural fictional region · 28 × 28 km · Unlocked from level 1")
	var map:=Minimap.new()
	map.custom_minimum_size=Vector2(980,390)
	map.expanded=true
	map.player=vehicle
	map.goal=session.get_goal()
	box.add_child(map)
	box.add_child(_label("City / Financial / Residential / Village / Forest\nBeyond the border: future regions locked · More coming soon",19,TEAL))

func _interact() -> void:
	if vehicle.speed_kmh>3:
		_notify("Stop safely to interact.")
		return
	var station:=world.nearest_station(vehicle.position)
	if Vector2(station.x-vehicle.position.x,station.z-vehicle.position.z).length()<14:
		fueling=not fueling
		fuel_added=0.0
		_notify("Attendant: Filling your tank. Tap Interact to stop." if fueling else "Attendant: You're all set.")
	else:
		_notify(session.interact(vehicle.position,vehicle.speed_kmh))
		_save()

func _rescue() -> void:
	var point:=world.road_point(vehicle.position)
	point.y=0.8
	vehicle.reset_to(point,0)
	if vehicle.fuel_liters<1:
		vehicle.fuel_liters=3
		_notify("Roadside help: emergency 3 L added. Visit a fuel station soon.")
	else: _notify("Roadside help: your car is back on the road.")
	_save()

func _offer_race() -> void:
	if not session.mission.is_empty() or offer_panel: return
	session.offer_race()
	offer_panel=PanelContainer.new()
	offer_panel.position=Vector2(420,165)
	offer_panel.size=Vector2(440,180)
	hud.add_child(offer_panel)
	var box:=VBoxContainer.new()
	offer_panel.add_child(box)
	box.add_child(_label("RIVAL AT THE LIGHTS",16,TEAL))
	box.add_child(_label("Hey, nice car. Want to race?",22,GOLD))
	var row:=HBoxContainer.new()
	box.add_child(row)
	row.add_child(_button("Let's race",func(): session.accept_race(vehicle.position); _close_offer()))
	row.add_child(_button("Keep cruising",_decline))
	offer_timer=0

func _close_offer() -> void:
	if is_instance_valid(offer_panel): offer_panel.queue_free()
	offer_panel=null
	offer_timer=0

func _decline() -> void:
	session.decline_race()
	laugh_queue=session.banter.duplicate()
	_close_offer()

func _notify(message: String) -> void:
	warning=message
	if is_instance_valid(toast_label): toast_label.text=message
	last_status=message

func _process(delta: float) -> void:
	if not is_instance_valid(world): return
	timer+=delta
	weather_time+=delta
	var now:=Time.get_datetime_dict_from_system()
	var hour:=float(now.hour)+float(now.minute)/60.0
	var target_wet:=0.7 if sin(weather_time/180.0)>0.3 else 0.0
	if rain_mode==1: target_wet=0
	if rain_mode==2: target_wet=0.9
	wetness=move_toward(wetness,target_wet,delta*0.08)
	world.set_weather(wetness,hour)
	vehicle.wetness=wetness
	vehicle.volume=audio_level
	world.process_mode=Node.PROCESS_MODE_DISABLED if paused and mode not in ["boot","loading_drive"] else Node.PROCESS_MODE_INHERIT
	if is_instance_valid(update_label): update_label.text=updater.message
	if mode in ["boot","loading_drive"]:
		loading_bar.value=world.get_load_progress()*100
		loading_label.text="Streets ready · %d%%" % int(loading_bar.value)
		if world.ready_for_drive:
			if mode=="boot" and not settling:
				settling=true
				vehicle.freeze=false
				await get_tree().create_timer(0.7).timeout
				if mode=="boot": _menu()
			elif mode=="loading_drive": _start_drive()
		return
	if mode!="drive": return
	vehicle.throttle=maxf(Input.get_action_strength("accelerate"),throttle_touch)*(-1 if reverse_touch or Input.is_action_pressed("reverse") else 1)
	vehicle.brake=maxf(Input.get_action_strength("brake"),brake_touch)
	vehicle.steer=clampf(Input.get_axis("left","right")+steer_touch,-1,1)
	vehicle.handbrake=Input.is_action_pressed("handbrake")
	if fueling:
		vehicle.throttle=0
		vehicle.brake=1
		session.state.fuel=vehicle.fuel_liters
		var added:float=session.refuel(delta*4.0)
		vehicle.fuel_liters=float(session.state.fuel)
		fuel_added+=added
		_notify("Attendant filling · %.1f L / 46 L · $1.85 per litre" % vehicle.fuel_liters)
		if added<=0 or vehicle.fuel_liters>=45.99:
			fueling=false
			_notify("Attendant: %.1f litres added. Enjoy the drive!" % fuel_added)
			_save()
	if Input.is_action_just_pressed("pause_drive"):
		_menu()
		return
	if Input.is_action_just_pressed("interact"): _interact()
	if Input.is_action_just_pressed("horn"): vehicle.horn()
	var racing: bool = not session.mission.is_empty() and str(session.mission.get("stage",""))=="racing" and str(session.mission.get("kind",""))=="race"
	if racing:
		var race_id:=str(session.mission.get("title",""))
		if active_race_id!=race_id:
			active_race_id=race_id
			var checkpoints:Array=session.mission.checkpoints.slice(int(session.mission.get("checkpoint",0)))
			world.start_race(checkpoints,vehicle.position)
		if world.rival_finished:
			session.cancel_job()
			session.status="Your rival reached the finish first. Try again—no money lost."
	elif active_race_id!="":
		world.stop_race()
		active_race_id=""
	vehicle.set_passenger(not session.mission.is_empty() and str(session.mission.get("stage",""))=="deliver" and str(session.mission.get("kind",""))=="passenger",str(session.mission.get("passenger","commuter")))
	session.update_drive(vehicle.position,vehicle.speed_kmh,delta)
	if session.status!=last_session_status and session.status!="":
		last_session_status=session.status
		_notify(session.status)
	speed_label.text="%03d" % int(absf(vehicle.speed_kmh))
	stats_label.text="L%02d   $%d   %.0f L" % [session.get_level(),int(session.state.cash),vehicle.fuel_liters]
	clock_label.text="%02d:%02d  ·  %s  ·  %s" % [now.hour,now.minute,world.district_at(vehicle.position),"Rain" if wetness>0.3 else "Clear"]
	var goal:=session.get_goal()
	map_view.goal=goal
	goal_marker.visible=not session.mission.is_empty()
	goal_marker.position=goal+Vector3(0,0.08,0)
	if session.mission.is_empty():
		var station:=world.nearest_station(vehicle.position)
		objective_label.text="FREE DRIVE\nOpen Jobs to find your next story.\nFuel station  %d m" % int(vehicle.position.distance_to(station))
	else:
		objective_label.text=session.get_goal_label()+"\n%d m · Stop in the marker, tap Interact"%int(vehicle.position.distance_to(goal))
		if str(session.mission.get("kind",""))=="race": objective_label.text+="\nTime left  %.0f s"%float(session.mission.get("time_left",0))
	save_timer+=delta
	if save_timer>10:
		save_timer=0
		_save()
	if greeting_timer>0:
		greeting_timer-=delta
		if greeting_timer<=0:
			updater.say("Ahhh... Let's go ride it. Let's go!")
			_notify("Ahhh... Let's go ride it. Let's go!")
	offer_timer+=delta
	if offer_panel and (offer_timer>12 or vehicle.speed_kmh>18): _decline()
	if not offer_panel and offer_timer>45 and vehicle.speed_kmh<4 and session.mission.is_empty():
		var intersection_distance:=Vector2(fposmod(vehicle.position.x+80,160)-80,fposmod(vehicle.position.z+80,160)-80).length()
		if intersection_distance<45: _offer_race()
	if not laugh_queue.is_empty():
		laugh_timer-=delta
		if laugh_timer<=0:
			var line:=str(laugh_queue.pop_front())
			_notify(line)
			updater.say(line)
			laugh_timer=3.5
	if vehicle.position.y < -8 or absf(vehicle.position.x)>13960 or absf(vehicle.position.z)>13960: _rescue()

func _save() -> void:
	if session and is_instance_valid(vehicle): session.save(vehicle.position,vehicle.rotation.y,vehicle.fuel_liters,vehicle.damage)
func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_PAUSED or what==NOTIFICATION_WM_CLOSE_REQUEST: _save()
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and mode=="drive": _menu()
func _load_settings() -> void:
	var config:=ConfigFile.new()
	if config.load("user://settings.cfg")==OK:
		quality=clampi(int(config.get_value("video","quality",quality)),0,2)
		audio_level=clampf(float(config.get_value("audio","volume",0.65)),0,1)
		rain_mode=clampi(int(config.get_value("world","weather",0)),0,2)
func _save_settings() -> void:
	var config:=ConfigFile.new()
	config.set_value("video","quality",quality)
	config.set_value("audio","volume",audio_level)
	config.set_value("world","weather",rain_mode)
	config.save("user://settings.cfg")
