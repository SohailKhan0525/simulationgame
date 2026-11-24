extends Node3D
@export var save_file := "user://qofeno-drive-save.json"
@export var settings_file := "user://settings.cfg"
const Vehicle = preload("res://scripts/vehicle.gd")
const World = preload("res://scripts/world.gd")
const Session = preload("res://scripts/session.gd")
const Minimap = preload("res://scripts/minimap.gd")
const Updater = preload("res://scripts/updater.gd")
const GOLD := Color("edb35c")
const TEAL := Color("c7d2d3")
const INK := Color("14171b")
const Controls = preload("res://scripts/drive_controls.gd")
const ControlsVisual = preload("res://scripts/controls_visual.gd")
var drive_controls: Control
var controls_visual: Control
var touch_mode := 0
var steering_sensitivity := 1.0
var camera_fov := 72.0
var time_mode := 1
var gear_button: Button
var interact_button: Button
var toast_panel: Panel
var toast_timer := 0.0
var page_return := "menu"
var settings_tab := 0
var has_driven := false
var loading_elapsed := 0.0
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
	canvas=CanvasLayer.new()
	add_child(canvas)
	screen=Control.new()
	screen.size=Vector2(1280,720)
	screen.theme=ui_theme
	canvas.add_child(screen)
	_layout_ui()
	get_viewport().size_changed.connect(_layout_ui)
	_show_loading("Preparing your city",false)
	await get_tree().process_frame
	await get_tree().process_frame
	session=Session.new(save_file)
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

	for pair in [["accelerate",JOY_AXIS_TRIGGER_RIGHT,1.0],["brake",JOY_AXIS_TRIGGER_LEFT,1.0],["left",JOY_AXIS_LEFT_X,-1.0],["right",JOY_AXIS_LEFT_X,1.0]]:
		var axis:=InputEventJoypadMotion.new()
		axis.axis=pair[1]
		axis.axis_value=pair[2]
		InputMap.action_add_event(pair[0],axis)
		InputMap.action_set_deadzone(pair[0],0.12)
	for pair in [["handbrake",JOY_BUTTON_A],["interact",JOY_BUTTON_X],["reverse",JOY_BUTTON_Y],["pause_drive",JOY_BUTTON_START],["horn",JOY_BUTTON_LEFT_SHOULDER]]:
		var button:=InputEventJoypadButton.new()
		button.button_index=pair[1]
		InputMap.action_add_event(pair[0],button)

func _setup_theme() -> void:
	ui_theme=Theme.new()
	ui_theme.default_font_size=20
	ui_theme.set_color("font_color","Label",Color("eef0f0"))
	for state in ["normal","hover","pressed","disabled","focus"]:
		var box:=StyleBoxFlat.new()
		box.bg_color=Color("24292f") if state=="normal" else Color("373d43")
		if state=="disabled": box.bg_color=Color("1a1d22")
		if state=="focus": box.bg_color=Color(0,0,0,0)
		box.set_corner_radius_all(3)
		box.content_margin_left=18
		box.content_margin_right=18
		box.content_margin_top=12
		box.content_margin_bottom=12
		box.border_color=GOLD if state=="focus" else Color("454b51")
		box.set_border_width_all(2 if state=="focus" else 1)
		ui_theme.set_stylebox(state,"Button",box)
		ui_theme.set_stylebox(state,"OptionButton",box)
	ui_theme.set_color("font_color","Button",Color("eff1f2"))
	ui_theme.set_color("font_disabled_color","Button",Color("72777d"))
	var panel:=StyleBoxFlat.new()
	panel.bg_color=Color(0.065,0.075,0.09,0.97)
	panel.set_corner_radius_all(4)
	panel.set_content_margin_all(28)
	panel.border_color=Color("3b4047")
	panel.set_border_width_all(1)
	ui_theme.set_stylebox("panel","PanelContainer",panel)
	var track:=StyleBoxFlat.new()
	track.bg_color=Color("343a41")
	ui_theme.set_stylebox("background","ProgressBar",track)
	var fill:=StyleBoxFlat.new()
	fill.bg_color=GOLD
	ui_theme.set_stylebox("fill","ProgressBar",fill)

func _layout_ui() -> void:
	if not is_instance_valid(screen): return
	var viewport_size:=get_viewport().get_visible_rect().size
	var factor:=minf(viewport_size.x/1280.0,viewport_size.y/720.0)
	screen.scale=Vector2.ONE*factor
	screen.position=(viewport_size-Vector2(1280,720)*factor)*0.5

func _shade(alpha: float=0.68) -> void:
	var shade:=ColorRect.new()
	shade.color=Color(0.025,0.03,0.04,alpha)
	shade.position=Vector2(-1280,-720)
	shade.size=Vector2(3840,2160)
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	screen.add_child(shade)

func _focus_first() -> void:
	var buttons:=screen.find_children("*","Button",true,false)
	for button in buttons:
		if button.is_visible_in_tree() and not button.disabled:
			button.grab_focus()
			break

func _accent_button(button: Button) -> void:
	for state in ["normal","hover","pressed"]:
		var style:=StyleBoxFlat.new()
		style.bg_color=GOLD if state=="normal" else Color("ffd18d")
		style.set_corner_radius_all(3)
		style.set_content_margin_all(16)
		button.add_theme_stylebox_override(state,style)
		button.add_theme_color_override("font_color" if state=="normal" else "font_"+state+"_color",INK)
	button.add_theme_color_override("font_focus_color",INK)

func _clear_ui() -> void:
	for child in screen.get_children():
		screen.remove_child(child)
		child.queue_free()
	if is_instance_valid(drive_controls): drive_controls.clear()
	drive_controls=null
	controls_visual=null
	toast_panel=null
	interact_button=null
	gear_button=null
	hud=null
	update_label=null
	offer_panel=null
	steer_touch=0
	throttle_touch=0
	brake_touch=0

func _label(text: String, size_font: int=20, color: Color=Color("ebf0ed")) -> Label:
	var label:=Label.new()
	label.text=text
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",size_font)
	label.add_theme_color_override("font_color",color)
	return label

func _button(text: String, action: Callable, height: float=48) -> Button:
	var button:=Button.new()
	button.text=text
	button.custom_minimum_size.y=height
	button.pressed.connect(action)
	button.focus_mode=Control.FOCUS_ALL
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
	menu_camera.position=vehicle.position+Vector3(5.5,2.15,-6.3)
	menu_camera.look_at(vehicle.position+Vector3(0,0.6,0))
	menu_camera.h_offset=-1.6
	menu_camera.current=true

func _show_loading(title: String, continuing: bool) -> void:
	_clear_ui()
	mode="loading_drive" if continuing else "boot"
	loading_elapsed=0
	_shade(0.94)
	var brand:=_label("QOFENO",22,GOLD)
	brand.position=Vector2(64,62)
	screen.add_child(brand)
	var heading:=_label("DRIVE",94)
	heading.position=Vector2(58,88)
	screen.add_child(heading)
	var info:=_label("YOUR CAR. YOUR CITY.",16,Color("9a9fa6"))
	info.position=Vector2(66,203)
	screen.add_child(info)
	var stage:=_label(title,28)
	stage.position=Vector2(64,504)
	screen.add_child(stage)
	loading_bar=ProgressBar.new()
	loading_bar.position=Vector2(64,563)
	loading_bar.size=Vector2(1152,5)
	loading_bar.show_percentage=false
	screen.add_child(loading_bar)
	loading_label=_label("Preparing nearby streets",18,Color("b8bec5"))
	loading_label.position=Vector2(64,589)
	screen.add_child(loading_label)
	var tip:=_label("Drive with two hands: steering on the left, pedals on the right.
Controls and camera can be adjusted in Settings.",18,Color("878e98"))
	tip.position=Vector2(64,643)
	screen.add_child(tip)

func _menu() -> void:
	pause_vehicle()
	_clear_ui()
	mode="menu"
	_set_menu_camera()
	_shade(0.16)
	var veil:=ColorRect.new()
	veil.color=Color(0.035,0.04,0.05,0.91)
	veil.size=Vector2(470,720)
	veil.mouse_filter=Control.MOUSE_FILTER_IGNORE
	screen.add_child(veil)
	var brand:=_label("QOFENO",24,GOLD)
	brand.position=Vector2(54,48)
	screen.add_child(brand)
	var title:=_label("DRIVE",76)
	title.position=Vector2(49,76)
	screen.add_child(title)
	var subtitle:=_label("PAUSED" if has_driven else "CAREER / FREE DRIVE",16,Color("9ca3ab"))
	subtitle.position=Vector2(56,172)
	screen.add_child(subtitle)
	var box:=VBoxContainer.new()
	box.position=Vector2(54,235)
	box.size=Vector2(360,370)
	box.add_theme_constant_override("separation",10)
	screen.add_child(box)
	var play:=_button("Resume drive" if has_driven else "Start driving",_continue_drive,62)
	play.alignment=HORIZONTAL_ALIGNMENT_LEFT
	_accent_button(play)
	box.add_child(play)
	for item in [["Dispatch",_jobs],["Garage",_garage],["Region map",_map_screen],["Driver profile",_journey],["Settings",_settings]]:
		var b:=_button(item[0],item[1],52)
		b.alignment=HORIZONTAL_ALIGNMENT_LEFT
		box.add_child(b)
	var profile:=_label("LEVEL %02d    /    $%s" % [session.get_level(),int(session.state.cash)],18)
	profile.position=Vector2(56,638)
	screen.add_child(profile)
	var version:=_label("OFFLINE CAREER",13,Color("858c95"))
	version.position=Vector2(56,674)
	screen.add_child(version)
	var car_title:=_label(["ASTER S","MERIDIAN GT","VELOCE R"][int(session.state.car)],25)
	car_title.add_theme_color_override("font_outline_color",Color("11151a"))
	car_title.add_theme_constant_override("outline_size",6)
	car_title.position=Vector2(520,610)
	screen.add_child(car_title)
	var details:=_label("%s  /  %.0f L fuel" % [world.district_at(vehicle.position).split(" • ")[0],vehicle.fuel_liters],17,Color("c1c6cb"))
	details.add_theme_color_override("font_outline_color",Color("11151a"))
	details.add_theme_constant_override("outline_size",5)
	details.position=Vector2(522,650)
	screen.add_child(details)
	_focus_first()

func _continue_drive() -> void:
	_show_loading("Getting you back on the road",true)

func _start_drive() -> void:
	_clear_ui()
	mode="drive"
	paused=false
	vehicle.freeze=false
	vehicle.enabled=true
	has_driven=true
	vehicle.cockpit_camera.fov=camera_fov
	vehicle.get_node("CockpitCamera").current=true
	vehicle.get_node("CockpitCamera").far=[240.0,520.0,700.0][quality]
	_build_hud()
	greeting_timer=0.0

func pause_vehicle() -> void:
	paused=true
	fueling=false
	if vehicle:
		vehicle.enabled=false
		vehicle.freeze=true
		vehicle.throttle=0
		vehicle.brake=0
		vehicle.steer=0
		vehicle.handbrake=false
	if is_instance_valid(drive_controls): drive_controls.clear()
	_save()

func _build_hud() -> void:
	hud=Control.new()
	hud.size=Vector2(1280,720)
	hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	screen.add_child(hud)
	_hud_back(Vector2(28,24),Vector2(274,46))
	clock_label=_label("",16)
	clock_label.position=Vector2(42,37)
	hud.add_child(clock_label)
	map_view=Minimap.new()
	map_view.position=Vector2(28,82)
	map_view.size=Vector2(218,150)
	map_view.player=vehicle
	hud.add_child(map_view)
	_hud_back(Vector2(28,242),Vector2(270,78))
	objective_label=_label("",17)
	objective_label.position=Vector2(42,252)
	objective_label.size=Vector2(245,64)
	objective_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(objective_label)
	stats_label=_label("",16)
	stats_label.position=Vector2(930,28)
	hud.add_child(stats_label)
	var nav:=HBoxContainer.new()
	nav.position=Vector2(968,68)
	nav.add_theme_constant_override("separation",8)
	hud.add_child(nav)
	for item in [["Jobs",_jobs],["Map",_map_screen],["Pause",_menu]]:
		var b:=_button(item[0],item[1],46)
		b.focus_mode=Control.FOCUS_NONE
		nav.add_child(b)
	speed_label=_label("0",58)
	speed_label.position=Vector2(824,555)
	speed_label.size.x=126
	speed_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	speed_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	speed_label.add_theme_constant_override("shadow_offset_x",2)
	speed_label.add_theme_constant_override("shadow_offset_y",2)
	hud.add_child(speed_label)
	var units:=_label("KM/H",14,Color("c4c9ce"))
	units.position=Vector2(899,623)
	hud.add_child(units)
	gear_button=_button("D",_toggle_reverse,46)
	gear_button.position=Vector2(883,650)
	gear_button.size=Vector2(70,46)
	gear_button.focus_mode=Control.FOCUS_NONE
	hud.add_child(gear_button)
	interact_button=_button("Interact",_interact,52)
	interact_button.position=Vector2(496,615)
	interact_button.size=Vector2(284,52)
	_accent_button(interact_button)
	interact_button.visible=false
	interact_button.focus_mode=Control.FOCUS_NONE
	hud.add_child(interact_button)
	toast_panel=Panel.new()
	toast_panel.position=Vector2(350,26)
	toast_panel.size=Vector2(540,64)
	toast_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style:=StyleBoxFlat.new()
	style.bg_color=Color(0.05,0.06,0.07,0.94)
	style.border_color=GOLD
	style.border_width_left=3
	toast_panel.add_theme_stylebox_override("panel",style)
	hud.add_child(toast_panel)
	toast_label=_label(last_status if toast_timer>0 else "",18)
	toast_label.position=Vector2(16,10)
	toast_label.size=Vector2(510,52)
	toast_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	toast_panel.add_child(toast_label)
	toast_panel.visible=false
	if _uses_touch():
		var horn_button:=_button("Horn",func(): vehicle.horn(),46)
		horn_button.position=Vector2(869,490)
		horn_button.size.x=84
		horn_button.focus_mode=Control.FOCUS_NONE
		hud.add_child(horn_button)
		drive_controls=Controls.new()
		drive_controls.size=Vector2(1280,720)
		drive_controls.sensitivity=steering_sensitivity
		hud.add_child(drive_controls)
		drive_controls.configure_regions({"steering":Rect2(36,486,246,192),"brake":Rect2(996,552,98,126),"throttle":Rect2(1110,510,122,168),"handbrake":Rect2(996,478,98,60)})
		controls_visual=ControlsVisual.new()
		controls_visual.controls=drive_controls
		controls_visual.size=Vector2(1280,720)
		hud.add_child(controls_visual)
	else:
		var hints:=_label("WASD / ARROWS   Drive     SPACE   Handbrake     E   Interact     R   Reverse     ESC   Pause",14,Color("bbc1c7"))
		hints.position=Vector2(28,680)
		hud.add_child(hints)

func _uses_touch() -> bool:
	return touch_mode==1 or (touch_mode==0 and (OS.get_name()=="Android" or DisplayServer.is_touchscreen_available()))

func _toggle_reverse() -> void:
	if vehicle.speed_kmh>3:
		_notify("Stop before changing between drive and reverse.")
		return
	reverse_touch=not reverse_touch
	if is_instance_valid(gear_button): gear_button.text="R" if reverse_touch else "D"

func _close_page() -> void:
	if page_return=="drive": _start_drive()
	else: _menu()

func _hud_back(pos: Vector2, dim: Vector2) -> void:
	var panel:=Panel.new()
	panel.position=pos
	panel.size=dim
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style:=StyleBoxFlat.new()
	style.bg_color=Color(0.045,0.05,0.06,0.78)
	style.set_corner_radius_all(3)
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
	if mode=="drive": page_return="drive"
	elif mode=="menu": page_return="menu"
	pause_vehicle()
	_clear_ui()
	mode="panel"
	_shade(0.58)
	var box:=_panel(Vector2(80,28),Vector2(1120,664))
	var heading:=HBoxContainer.new()
	box.add_child(heading)
	var text:=_label(title,32)
	text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	heading.add_child(text)
	heading.add_child(_button("Back",_close_page,46))
	if subtitle!="":
		var sub:=_label(subtitle,17,Color("a9b1b9"))
		sub.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		box.add_child(sub)
	box.add_child(HSeparator.new())
	var scroll:=ScrollContainer.new()
	scroll.follow_focus=true
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus=true
	box.add_child(scroll)
	var body:=VBoxContainer.new()
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.size_flags_vertical=Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",10)
	scroll.add_child(body)
	_focus_first.call_deferred()
	return body

func _jobs() -> void:
	var box:=_page("Dispatch", "Passenger stories, deliveries and time trials. Stop inside each glowing marker to interact.")
	if not session.mission.is_empty():
		box.add_child(_label("Active: "+str(session.mission.get("title","Journey")),19,TEAL))
		box.add_child(_button("Cancel active job",func(): session.cancel_job(); _jobs()))
	var scroll:=ScrollContainer.new()
	scroll.follow_focus=true
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
	var box:=_page("Garage", "Choose a car, improve its performance, or repair bodywork.")
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
	var box:=_page("Driver profile", "20 driving levels · All of the New York region is open from the start.")
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
	var box:=_page("Settings", "Changes are saved automatically.")
	var tabs:=HBoxContainer.new()
	tabs.add_theme_constant_override("separation",8)
	box.add_child(tabs)
	var names: Array[String]=["Controls","Display & sound","Updates"]
	for i in range(names.size()):
		var index:=i
		var tab:=_button(names[i],func(): settings_tab=index; _settings(),44)
		if settings_tab==i: _accent_button(tab)
		tabs.add_child(tab)
	if settings_tab==0:
		box.add_child(_label("Touch controls",21,GOLD))
		var touch:=OptionButton.new()
		for text in ["Automatic · touch devices only","Show touch controls","Hide touch controls"]: touch.add_item(text)
		touch.select(touch_mode)
		touch.item_selected.connect(func(index): touch_mode=index; _save_settings())
		box.add_child(touch)
		box.add_child(_label("Steering sensitivity",18))
		var sensitivity:=HSlider.new()
		sensitivity.min_value=0.5
		sensitivity.max_value=1.6
		sensitivity.step=0.05
		sensitivity.value=steering_sensitivity
		sensitivity.value_changed.connect(func(value): steering_sensitivity=value; _save_settings())
		box.add_child(sensitivity)
		box.add_child(_label("Drag the steering pad left or right. Release to centre.
Hold the accelerator and brake independently. H/B is the handbrake.
Stop before selecting D or R.",18,Color("bdc4cb")))
		box.add_child(_label("Keyboard / controller",21,GOLD))
		box.add_child(_label("WASD or arrows / left stick   Steer & drive
Space / A   Handbrake     E / X   Interact
R / Y   Change direction     Escape / Start   Pause",18))
		box.add_child(_button("Recover car to road",func(): _rescue(); _start_drive()))
	elif settings_tab==1:
		var q:=OptionButton.new()
		for text in ["Graphics · Low","Graphics · Balanced","Graphics · High"]: q.add_item(text)
		q.select(quality)
		q.item_selected.connect(func(index): quality=index; world.set_quality(index); _save_settings())
		box.add_child(q)
		box.add_child(_label("Cockpit field of view",18))
		var fov:=HSlider.new()
		fov.min_value=60
		fov.max_value=90
		fov.step=1
		fov.value=camera_fov
		fov.value_changed.connect(func(value): camera_fov=value; vehicle.cockpit_camera.fov=value; _save_settings())
		box.add_child(fov)
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
		var daylight:=OptionButton.new()
		for text in ["Time · device clock","Time · afternoon","Time · sunset"]: daylight.add_item(text)
		daylight.select(time_mode)
		daylight.item_selected.connect(func(index): time_mode=index; _save_settings())
		box.add_child(daylight)
	else:
		box.add_child(_label("Game updates",22,GOLD))
		box.add_child(_label("Downloads continue in the background. Android asks before installation.",17))
		var row:=HBoxContainer.new()
		box.add_child(row)
		row.add_child(_button("Check for updates",func(): updater.check()))
		row.add_child(_button("Download update",func(): updater.download()))
		row.add_child(_button("Install update",func(): updater.install()))
	# Always retain a status label so pending downloads remain visible in settings.
	update_label=_label(updater.message,16,Color("a9b1b9"))
	update_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	update_label.visible=settings_tab==2
	box.add_child(update_label)

func _map_screen() -> void:
	var box:=_page("Region map", "Local road network · The map fits your active route")
	var map:=Minimap.new()
	map.custom_minimum_size=Vector2(980,390)
	map.expanded=true
	map.player=vehicle
	map.goal=session.get_goal()
	map.has_goal=not session.mission.is_empty()
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
	var accept:=_button("Let's race",func(): session.accept_race(vehicle.position); _close_offer())
	row.add_child(accept)
	accept.grab_focus()
	row.add_child(_button("Keep cruising",_decline))
	offer_timer=0

func _close_offer() -> void:
	if is_instance_valid(offer_panel):
		var focus:=get_viewport().gui_get_focus_owner()
		if focus and offer_panel.is_ancestor_of(focus): focus.release_focus()
		offer_panel.queue_free()
	offer_panel=null
	offer_timer=0

func _decline() -> void:
	session.decline_race()
	laugh_queue=session.banter.duplicate()
	_close_offer()

func _notify(message: String) -> void:
	warning=message
	toast_timer=5.5
	if is_instance_valid(toast_panel): toast_panel.visible=true
	if is_instance_valid(toast_label): toast_label.text=message
	last_status=message

func _process(delta: float) -> void:
	if not is_instance_valid(world): return
	timer+=delta
	weather_time+=delta
	var now:=Time.get_datetime_dict_from_system()
	var hour:=float(now.hour)+float(now.minute)/60.0
	if time_mode==1: hour=15.5
	elif time_mode==2: hour=17.8
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
		loading_elapsed+=delta
		loading_label.text="Preparing nearby streets  %d%%" % int(loading_bar.value)
		if world.ready_for_drive: loading_label.text="Streets ready · settling vehicle"
		elif loading_elapsed>20: loading_label.text="Still preparing streets · %d%%" % int(loading_bar.value)
		if world.ready_for_drive:
			if mode=="boot" and not settling:
				settling=true
				vehicle.freeze=false
				await get_tree().create_timer(0.7).timeout
				if mode=="boot": _menu()
			elif mode=="loading_drive": _start_drive()
		return
	if mode!="drive":
		if Input.is_action_just_pressed("pause_drive"):
			if mode=="panel": _close_page()
			elif mode=="menu" and has_driven: _continue_drive()
		return
	if is_instance_valid(drive_controls):
		steer_touch=drive_controls.steer
		throttle_touch=drive_controls.throttle
		brake_touch=drive_controls.brake
	if Input.is_action_just_pressed("reverse"): _toggle_reverse()
	vehicle.throttle=maxf(Input.get_action_strength("accelerate"),throttle_touch)*(-1 if reverse_touch else 1)
	vehicle.brake=maxf(Input.get_action_strength("brake"),brake_touch)
	var key_steer:=Input.get_axis("left","right")
	vehicle.steer=key_steer if absf(key_steer)>absf(steer_touch) else steer_touch
	vehicle.handbrake=Input.is_action_pressed("handbrake") or (is_instance_valid(drive_controls) and drive_controls.handbrake)
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
	speed_label.text=str(int(absf(vehicle.speed_kmh)))
	if is_instance_valid(gear_button): gear_button.text="R" if reverse_touch else "D"
	toast_timer=maxf(0,toast_timer-delta)
	if is_instance_valid(toast_panel): toast_panel.visible=toast_timer>0
	var station_near:=vehicle.position.distance_to(world.nearest_station(vehicle.position))<16
	var goal_near:=not session.mission.is_empty() and str(session.mission.get("stage",""))!="racing" and vehicle.position.distance_to(session.get_goal())<15
	if is_instance_valid(interact_button):
		interact_button.visible=station_near or goal_near or fueling
		interact_button.text="Stop refuelling" if fueling else ("Refuel" if station_near else "Interact")
		interact_button.disabled=vehicle.speed_kmh>3
	stats_label.text="LV %02d     $%d     FUEL %.0f L" % [session.get_level(),int(session.state.cash),vehicle.fuel_liters]
	clock_label.text="%s  /  %s" % [world.district_at(vehicle.position).split(" • ")[0],"Rain" if wetness>0.3 else "Clear"]
	var goal:=session.get_goal()
	map_view.goal=goal
	map_view.has_goal=not session.mission.is_empty()
	goal_marker.visible=not session.mission.is_empty()
	goal_marker.position=goal+Vector3(0,0.08,0)
	if session.mission.is_empty():
		var station:=world.nearest_station(vehicle.position)
		objective_label.text="FREE DRIVE\nFuel station  %d m" % int(vehicle.position.distance_to(station))
	else:
		objective_label.text=session.get_goal_label()+"\nStop inside the marked area."
		if str(session.mission.get("stage",""))=="racing":
			objective_label.text="CHECKPOINT %d  /  %.0f s\nDrive through the marker" % [int(session.mission.get("checkpoint",0))+1,float(session.mission.get("time_left",0))]
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
	if what==NOTIFICATION_WM_CLOSE_REQUEST: _save()
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT]:
		if mode=="drive": _menu()
		else: _save()
func _load_settings() -> void:
	var config:=ConfigFile.new()
	if config.load(settings_file)==OK:
		quality=clampi(int(config.get_value("video","quality",quality)),0,2)
		audio_level=clampf(float(config.get_value("audio","volume",0.65)),0,1)
		rain_mode=clampi(int(config.get_value("world","weather",0)),0,2)
		touch_mode=clampi(int(config.get_value("controls","touch",0)),0,2)
		steering_sensitivity=clampf(float(config.get_value("controls","sensitivity",1.0)),0.5,1.6)
		camera_fov=clampf(float(config.get_value("video","fov",72.0)),60,90)
		time_mode=clampi(int(config.get_value("world","time",1)),0,2)
func _save_settings() -> void:
	var config:=ConfigFile.new()
	config.set_value("video","quality",quality)
	config.set_value("audio","volume",audio_level)
	config.set_value("world","weather",rain_mode)
	config.set_value("controls","touch",touch_mode)
	config.set_value("controls","sensitivity",steering_sensitivity)
	config.set_value("video","fov",camera_fov)
	config.set_value("world","time",time_mode)
	config.save(settings_file)
