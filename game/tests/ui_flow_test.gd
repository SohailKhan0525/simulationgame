extends SceneTree
## Run with --headless --path game --script res://tests/ui_flow_test.gd --fixed-fps 60.
## Tests real main-scene transitions and input integration in resized viewports.
var game: Node
var viewport: SubViewport
var checks: int = 0
var failures: Array[String] = []
var test_save: String
var test_settings: String

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func frames(count: int = 3) -> void:
	for _i in range(count):
		await process_frame

func touch(index: int, local_position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = game.drive_controls.get_global_transform_with_canvas() * local_position
	event.pressed = pressed
	game.drive_controls._input(event)

func drag(index: int, local_position: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = game.drive_controls.get_global_transform_with_canvas() * local_position
	game.drive_controls._input(event)

func check_visible_actions_fit(label: String) -> void:
	var available := Rect2(Vector2.ZERO, Vector2(viewport.size)).grow(0.5)
	for child in game.screen.find_children("*", "Control", true, false):
		if not (child is BaseButton or child is Slider) or not child.is_visible_in_tree():
			continue
		var ancestor: Node = child.get_parent()
		var scroll: ScrollContainer
		while ancestor != game.screen and ancestor != null:
			if ancestor is ScrollContainer:
				scroll = ancestor
				break
			ancestor = ancestor.get_parent()
		if scroll != null and child.focus_mode != Control.FOCUS_NONE and not (child is BaseButton and child.disabled):
			child.grab_focus()
			await frames(2)
		var bounds: Rect2 = child.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, child.size)
		var name: String = child.text if child is BaseButton else child.get_class()
		check(available.encloses(bounds), "%s: %s is outside the viewport (%s)" % [label, name, bounds])
		if scroll != null:
			var scroll_bounds: Rect2 = scroll.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, scroll.size)
			# Scroll offsets are integral; allow one pixel after the HUD transform.
			var tolerance: float = maxf(1.0, game.screen.scale.y)
			check(scroll_bounds.grow(tolerance).encloses(bounds), "%s: focused %s must be revealed by scrolling (control %s; scroll %s)" % [label, name, bounds, scroll_bounds])

func run() -> void:
	test_save = "res://../build/test-data/ui-flow-%d.json" % OS.get_process_id()
	test_settings = "res://../build/test-data/ui-flow-settings-%d.cfg" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(test_save.get_base_dir()))
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	game = load("res://scenes/main.tscn").instantiate()
	# Configure isolation before _ready() can read settings or load/save a career.
	game.save_file = test_save
	game.settings_file = test_settings
	viewport.add_child(game)
	if not game.is_node_ready():
		await game.ready
	# Startup deliberately yields so the loading screen appears before world setup.
	for _i in range(30):
		if game.session != null and game.world != null:
			break
		await process_frame
	check(game.session != null and game.world != null, "Startup must initialize the driving session")
	if game.session == null or game.world == null:
		await finish()
		return
	check(game.session.save_path == test_save, "Startup must use the isolated career path")
	game.session.mission.clear()
	game.touch_mode = 1
	game.audio_level = 0.0
	game.quality = 0
	game.world.set_quality(0)
	for _i in range(600):
		if game.mode == "menu":
			break
		await process_frame
	check(game.mode == "menu", "Boot must reach the main menu")
	if game.mode != "menu":
		await finish()
		return
	await frames()
	check(viewport.gui_get_focus_owner() != null, "Main menu must select an actionable item for keyboard/controller users")
	var focus_style: StyleBoxFlat = game.ui_theme.get_stylebox("focus", "Button")
	check(focus_style.border_width_left >= 2 and focus_style.border_color.a >= 0.8, "Focused menu actions need a visible outline")
	var event_counts: Dictionary = {}
	for action in ["accelerate", "brake", "left", "right", "handbrake", "interact", "horn", "pause_drive", "reverse", "camera_view"]:
		event_counts[action] = InputMap.action_get_events(action).size()
	game._setup_input()
	for action in event_counts:
		check(InputMap.action_get_events(action).size() == event_counts[action], "Repeated setup must not duplicate %s bindings" % action)
	var trigger := InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	trigger.axis_value = 1.0
	check(InputMap.event_is_action(trigger, "accelerate"), "Right gamepad trigger must accelerate")
	trigger.axis = JOY_AXIS_TRIGGER_LEFT
	check(InputMap.event_is_action(trigger, "brake"), "Left gamepad trigger must brake")
	var reverse := InputEventJoypadButton.new()
	reverse.button_index = JOY_BUTTON_Y
	reverse.pressed = true
	check(InputMap.event_is_action(reverse, "reverse"), "Gamepad Y must map to the direction selector")
	reverse.button_index = JOY_BUTTON_RIGHT_SHOULDER
	check(InputMap.event_is_action(reverse, "camera_view"), "Gamepad right shoulder must change the camera")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	check(InputMap.event_is_action(key, "accelerate"), "Physical W key must map to acceleration")

	game._settings()
	await frames()
	check(game.mode == "panel" and game.vehicle.freeze, "Opening settings from menu must leave the vehicle paused")
	game.settings_tab = 1
	game._settings()
	await frames()
	game._close_page()
	await frames()
	check(game.mode == "menu" and game.vehicle.freeze, "Back after changing settings tabs must return to the originating menu")

	game._start_drive()
	await frames()
	check(game.vehicle.enabled and not game.vehicle.freeze, "Starting must enable the vehicle")
	check(is_instance_valid(game.drive_controls), "Explicit touch mode must install the input helper")
	check(game.camera_mode == 1 and viewport.get_camera_3d() == game.vehicle.chase_camera, "New careers must start with the chase view")
	game._toggle_camera()
	check(game.camera_mode == 0 and viewport.get_camera_3d() == game.vehicle.cockpit_camera, "View control must switch to the cockpit immediately")
	var camera_config := ConfigFile.new()
	check(camera_config.load(test_settings) == OK and int(camera_config.get_value("video", "camera", -1)) == 0, "Selected camera must persist in settings")
	game._toggle_camera()
	check(viewport.get_camera_3d() == game.vehicle.chase_camera, "Second view change must restore the chase view")
	game._settings()
	await frames()
	game._close_page()
	await frames()
	check(game.mode == "drive" and not game.vehicle.freeze, "Back from driving settings must resume driving")
	check(viewport.get_camera_3d() == game.vehicle.chase_camera, "Back from settings must restore the chosen camera")

	touch(0, Vector2(120, 575), true)
	drag(0, Vector2(165, 575))
	touch(1, Vector2(1160, 590), true)
	touch(2, Vector2(1030, 600), true)
	touch(3, Vector2(1030, 500), true)
	await frames(2)
	check(game.vehicle.steer > 0.4 and game.vehicle.throttle == 1.0 and game.vehicle.brake == 1.0 and game.vehicle.handbrake, "Main scene must receive simultaneous steering, pedals and handbrake")
	var old_controls: Control = game.drive_controls
	game._menu()
	check(game.vehicle.throttle == 0.0 and game.vehicle.brake == 0.0 and game.vehicle.steer == 0.0 and not game.vehicle.handbrake, "Pause must clear every vehicle command")
	check(old_controls.throttle == 0.0 and old_controls.brake == 0.0 and old_controls.steer == 0.0 and not old_controls.handbrake, "Pause must release all captured touches")
	await frames()
	game._start_drive()
	touch(7, Vector2(120, 575), true)
	drag(7, Vector2(165, 575))
	touch(8, Vector2(1160, 590), true)
	touch(9, Vector2(1030, 500), true)
	await frames(2)
	old_controls = game.drive_controls
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(game.mode == "menu" and game.vehicle.freeze and not game.vehicle.enabled, "Application suspension must safely pause driving")
	check(game.vehicle.throttle == 0.0 and game.vehicle.steer == 0.0 and not game.vehicle.handbrake, "Application suspension must clear active vehicle input")
	check(old_controls.throttle == 0.0 and old_controls.steer == 0.0 and not old_controls.handbrake, "Application suspension must release captured touches")
	await frames()
	game._start_drive()
	game.vehicle.freeze = true
	game.vehicle.speed_kmh = 0.0
	game.reverse_touch = false
	game._toggle_reverse()
	check(game.reverse_touch and game.gear_button.text == "R", "Stopped direction selector must enter reverse and update its label")
	game.vehicle.speed_kmh = 20.0
	game._toggle_reverse()
	check(game.reverse_touch and game.warning.contains("Stop"), "Direction change while moving must be blocked with feedback")
	game.vehicle.speed_kmh = 0.0
	game._toggle_reverse()
	check(not game.reverse_touch and game.gear_button.text == "D", "Stopped direction selector must return to drive")
	touch(10, Vector2(120, 575), true)
	drag(10, Vector2(165, 575))
	Input.action_press("right", 0.8)
	Input.action_press("accelerate", 0.4)
	await frames(2)
	check(is_equal_approx(game.vehicle.steer, 0.8), "Keyboard/gamepad and touch steering must use the strongest input without adding them")
	check(is_equal_approx(game.vehicle.throttle, 0.4), "Analog acceleration action must reach the vehicle unchanged")
	Input.action_release("right")
	Input.action_release("accelerate")
	touch(10, Vector2.ZERO, false)
	Input.action_press("reverse")
	await frames(3)
	check(game.reverse_touch, "Reverse action must toggle once rather than switch repeatedly while held")
	Input.action_release("reverse")
	await frames(2)
	Input.action_press("reverse")
	await frames(2)
	check(not game.reverse_touch, "A new reverse action press must toggle back to drive")
	Input.action_release("reverse")
	game.vehicle.speed_kmh = 0.0
	game._offer_race()
	await frames(2)
	var offer_focus: Control = viewport.gui_get_focus_owner()
	check(is_instance_valid(game.offer_panel) and offer_focus != null and game.offer_panel.is_ancestor_of(offer_focus), "Race offer must receive initial keyboard/controller focus")
	game._close_offer()
	await frames(2)
	check(viewport.gui_get_focus_owner() == null, "Closing the race offer must release its focus")

	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 864), Vector2i(1024, 768)]:
		viewport.size = dimensions
		await frames()
		game._layout_ui()
		game._menu()
		await frames()
		await check_visible_actions_fit("Menu %s" % dimensions)
		for tab in range(3):
			game.settings_tab = tab
			game._settings()
			await frames()
			await check_visible_actions_fit("Settings tab %d at %s" % [tab, dimensions])
			check(viewport.gui_get_focus_owner() != null, "Settings must retain a keyboard/controller focus target")
		game._start_drive()
		game.vehicle.freeze = true
		await frames()
		await check_visible_actions_fit("Driving HUD %s" % dimensions)
		touch(4, Vector2(120, 575), true)
		drag(4, Vector2(165, 575))
		touch(5, Vector2(1160, 590), true)
		await frames(2)
		check(game.vehicle.steer > 0.4 and game.vehicle.steer < 0.6 and game.vehicle.throttle == 1.0, "Scaled viewport %s must preserve analog steering and pedals" % dimensions)
		touch(4, Vector2.ZERO, false)
		touch(5, Vector2.ZERO, false)
		await frames(2)
		check(game.vehicle.steer == 0.0 and game.vehicle.throttle == 0.0, "Scaled viewport %s must release controls outside their region" % dimensions)
	await finish()

func finish() -> void:
	for action in ["accelerate", "brake", "left", "right", "handbrake", "reverse"]:
		Input.action_release(action)
	game.queue_free()
	await process_frame
	viewport.queue_free()
	await process_frame
	for suffix in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(test_save + suffix)
	DirAccess.remove_absolute(test_settings)
	print("UI flow: %d/%d checks passed" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
