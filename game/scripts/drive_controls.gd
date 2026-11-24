class_name DriveControls
extends Control
## Touch ownership is fixed when a finger lands: steering cannot steal a pedal.
## Rectangles use this Control's local coordinates, even when its HUD is scaled.

signal changed

var steer: float = 0.0
var throttle: float = 0.0
var brake: float = 0.0
var handbrake: bool = false
var steering_active: bool = false
var steering_touch_origin := Vector2.ZERO
var steering_touch_position := Vector2.ZERO
var sensitivity: float = 1.0
var analog_throttle: bool = false
var active: bool = true:
	set(value):
		active = value
		if not active:
			clear()

const MOUSE_POINTER: int = -100
var _regions: Dictionary = {}
var _pointers: Dictionary = {}
var _steering_pointer: int = MOUSE_POINTER - 1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visibility_changed.connect(_visibility_changed)
	tree_exiting.connect(clear)

func configure_regions(regions: Dictionary) -> void:
	clear()
	_regions = regions.duplicate()

func clear() -> void:
	_pointers.clear()
	_steering_pointer = MOUSE_POINTER - 1
	steer = 0.0
	throttle = 0.0
	brake = 0.0
	handbrake = false
	steering_active = false
	steering_touch_origin = Vector2.ZERO
	steering_touch_position = Vector2.ZERO
	changed.emit()

func _visibility_changed() -> void:
	if not is_visible_in_tree():
		clear()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		clear()

func _input(event: InputEvent) -> void:
	if not active or not is_visible_in_tree():
		return
	# Physical mouse support below already covers desktop use. Do not process a
	# second, synthetic touch stream when mouse-to-touch emulation is enabled.
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var handled := false
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			handled = _press(event.index, _local_position(event.position))
		else:
			handled = _release(event.index)
	elif event is InputEventScreenDrag:
		handled = _drag(event.index, _local_position(event.position))
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_LEFT:
			handled = _press(MOUSE_POINTER, _local_position(event.position)) if event.pressed else _release(MOUSE_POINTER)
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		# A missed mouse-up event (e.g. dragging outside the window) cannot latch a pedal.
		if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			handled = _release(MOUSE_POINTER)
		else:
			handled = _drag(MOUSE_POINTER, _local_position(event.position))
	if handled:
		get_viewport().set_input_as_handled()

func _local_position(viewport_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * viewport_position

func _press(pointer: int, at: Vector2) -> bool:
	if _pointers.has(pointer):
		_release(pointer)
	for role in ["handbrake", "brake", "throttle", "steering"]:
		if not _regions.has(role) or not (_regions[role] as Rect2).has_point(at):
			continue
		if role == "steering" and steering_active:
			return false
		_pointers[pointer] = {"role": role, "position": at}
		if role == "steering":
			_steering_pointer = pointer
			steering_active = true
			steering_touch_origin = at
			steering_touch_position = at
			steer = 0.0
		_refresh_pedals()
		changed.emit()
		return true
	return false

func _drag(pointer: int, at: Vector2) -> bool:
	if not _pointers.has(pointer):
		return false
	_pointers[pointer].position = at
	if pointer == _steering_pointer:
		steering_touch_position = at
		var region: Rect2 = _regions.steering
		var travel: float = maxf(36.0, region.size.x * 0.36)
		var raw: float = clampf((at.x - steering_touch_origin.x) / travel * clampf(sensitivity, 0.5, 2.0), -1.0, 1.0)
		# A small dead band absorbs thumb jitter without losing fine steering travel.
		steer = signf(raw) * maxf(0.0, (absf(raw) - 0.025) / 0.975)
	_refresh_pedals()
	changed.emit()
	return true

func _release(pointer: int) -> bool:
	if not _pointers.has(pointer):
		return false
	_pointers.erase(pointer)
	if pointer == _steering_pointer:
		_steering_pointer = MOUSE_POINTER - 1
		steering_active = false
		steer = 0.0
	_refresh_pedals()
	changed.emit()
	return true

func _refresh_pedals() -> void:
	throttle = 0.0
	brake = 0.0
	handbrake = false
	for pointer in _pointers.values():
		match pointer.role:
			"throttle":
				if analog_throttle:
					var region: Rect2 = _regions.throttle
					throttle = maxf(throttle, clampf((region.end.y - pointer.position.y) / maxf(1.0, region.size.y), 0.0, 1.0))
				else:
					throttle = 1.0
			"brake":
				brake = 1.0
			"handbrake":
				handbrake = true
