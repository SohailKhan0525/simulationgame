extends SceneTree
## Exercises real touch event shapes, pointer ownership, and HUD transforms.
const Controls = preload("res://scripts/drive_controls.gd")
var controls: Control
var holder: Control
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func touch(index: int, at: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = controls.get_global_transform_with_canvas() * at
	event.pressed = pressed
	event.canceled = canceled
	controls._input(event)

func drag(index: int, at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = controls.get_global_transform_with_canvas() * at
	controls._input(event)

func _run() -> void:
	holder = Control.new()
	holder.position = Vector2(73, 29)
	holder.scale = Vector2(1.35, 1.35)
	root.add_child(holder)
	controls = Controls.new()
	holder.add_child(controls)
	controls.configure_regions({
		"steering": Rect2(36, 486, 246, 192),
		"throttle": Rect2(1110, 510, 122, 168),
		"brake": Rect2(996, 552, 98, 126),
		"handbrake": Rect2(996, 478, 98, 60)
	})
	touch(0, Vector2(100, 580), true)
	touch(1, Vector2(1160, 590), true)
	drag(0, Vector2(145, 580))
	check(controls.steer > 0.4 and controls.steer < 0.6, "Scaled HUD must produce proportional steering")
	check(controls.throttle == 1.0, "Steering and throttle must work with separate fingers")
	drag(0, Vector2(1200, 580))
	check(controls.steer == 1.0 and controls.throttle == 1.0, "Crossing a pedal cannot transfer a steering finger's ownership")
	touch(1, Vector2(10, 10), false)
	check(controls.throttle == 0.0 and controls.steer == 1.0, "Pedal release outside its region must release only that pedal")
	touch(2, Vector2(160, 580), true)
	drag(2, Vector2(50, 580))
	check(controls.steer == 1.0, "A second steering finger cannot steal the wheel")
	touch(0, Vector2(100, 580), false)
	check(controls.steer == 0.0 and not controls.steering_active, "Releasing steering must center the input")
	touch(3, Vector2(1160, 590), true)
	touch(4, Vector2(1160, 600), true)
	touch(3, Vector2.ZERO, false)
	check(controls.throttle == 1.0, "Releasing one of two pedal fingers must retain the remaining press")
	touch(4, Vector2.ZERO, true, true)
	check(controls.throttle == 0.0, "Canceled touch must release a pedal even when pressed is true")
	touch(5, Vector2(1030, 600), true)
	touch(6, Vector2(1030, 500), true)
	check(controls.brake == 1.0 and controls.handbrake, "Brake and handbrake must support independent touches")
	controls.active = false
	check(controls.brake == 0.0 and not controls.handbrake, "Leaving driving must clear all held controls")
	touch(7, Vector2(1160, 590), true)
	check(controls.throttle == 0.0, "Inactive controls must ignore new touches")
	controls.active = true
	touch(7, Vector2(1160, 590), true)
	controls.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(controls.throttle == 0.0, "Losing application focus must release controls")
	touch(8, Vector2(1160, 590), true)
	holder.hide()
	check(controls.throttle == 0.0, "Hiding a parent HUD must release controls")
	holder.show()
	controls.analog_throttle = true
	touch(9, Vector2(1160, 594), true)
	check(is_equal_approx(controls.throttle, 0.5), "Optional throttle slider must give proportional input")
	drag(9, Vector2(1160, 500))
	check(controls.throttle == 1.0, "Throttle slider must clamp beyond its track")
	touch(9, Vector2.ZERO, false)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = controls.get_global_transform_with_canvas() * Vector2(1160, 550)
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	controls._input(mouse)
	check(controls.throttle == 0.0, "Emulated mouse events must not duplicate touchscreen input")
	mouse.device = 0
	controls._input(mouse)
	check(controls.throttle > 0.0, "A physical mouse must operate controls for desktop testing")
	var motion := InputEventMouseMotion.new()
	motion.button_mask = 0
	controls._input(motion)
	check(controls.throttle == 0.0, "A missing mouse-up must not leave throttle latched")
	print("Drive controls: %d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
