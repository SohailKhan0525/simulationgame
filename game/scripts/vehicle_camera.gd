extends Node3D
## Stable-horizon chase rig. Physics owns obstruction queries; exponential damping
## keeps the response independent of the display frame rate.
var target: RigidBody3D
var camera: Camera3D
var base_fov: float = 65.0
var speed_fov_boost: float = 17.0
var _heading: float = 0.0
var _focus := Vector3.ZERO
var _position := Vector3.ZERO
var _collision_shape := SphereShape3D.new()
var _collision_query := PhysicsShapeQueryParameters3D.new()
var _initialized: bool = false

func _ready() -> void:
	name = "ChaseCameraRig"
	camera = Camera3D.new()
	camera.name = "ChaseCamera"
	camera.top_level = true
	camera.near = 0.12
	camera.far = 700.0
	camera.fov = base_fov
	add_child(camera)
	# A Camera3D can automatically become current when it is the viewport's first.
	# Main owns activation; merely installing the rig must not change the view.
	camera.current = false
	_collision_shape.radius = 0.28
	_collision_query.shape = _collision_shape
	_collision_query.collision_mask = 1 | 4
	_collision_query.margin = 0.04
	_collision_query.exclude = [target.get_rid()]
	snap()

func snap() -> void:
	if not is_instance_valid(target) or not is_instance_valid(camera):
		return
	var forward := _flat_forward()
	_heading = atan2(-forward.x, -forward.z)
	_focus = target.global_position + Vector3.UP * 1.0 + forward * 1.4
	_position = target.global_position - forward * 6.6 + Vector3.UP * 2.8
	camera.global_position = _position
	camera.look_at(_focus, Vector3.UP)
	_initialized = true

func _flat_forward() -> Vector3:
	var forward := -target.global_basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 0.01 else Vector3.FORWARD

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target) or not is_instance_valid(camera) or not camera.current:
		return
	if not _initialized or _position.distance_squared_to(target.global_position) > 900.0:
		snap()
	var forward := _flat_forward()
	var desired_heading := atan2(-forward.x, -forward.z)
	var velocity := Vector3(target.linear_velocity.x, 0.0, target.linear_velocity.z)
	var speed := velocity.length()
	# Follow part of the velocity heading during a slide, capped so reversing or
	# spinning cannot suddenly turn the view around to face the player.
	if velocity.dot(forward) > 3.0:
		var velocity_heading := atan2(-velocity.x, -velocity.z)
		var slip_angle := clampf(wrapf(velocity_heading - desired_heading, -PI, PI), -0.45, 0.45)
		desired_heading += slip_angle * 0.6
	_heading = lerp_angle(_heading, desired_heading, 1.0 - exp(-4.8 * delta))
	var camera_forward := -Basis(Vector3.UP, _heading).z
	var speed_fraction := clampf(speed * 3.6 / 160.0, 0.0, 1.0)
	var anchor := target.global_position + Vector3.UP * 1.0
	var desired_focus := anchor + forward * (1.4 + speed_fraction * 1.2)
	var desired_position := target.global_position - camera_forward * (6.6 + speed_fraction * 0.6) + Vector3.UP * (2.8 + speed_fraction * 0.2)
	_focus = _focus.lerp(desired_focus, 1.0 - exp(-10.0 * delta))
	var candidate := _position.lerp(desired_position, 1.0 - exp(-8.0 * delta))
	_collision_query.transform = Transform3D(Basis.IDENTITY, anchor)
	_collision_query.motion = candidate - anchor
	var fractions := target.get_world_3d().direct_space_state.cast_motion(_collision_query)
	if fractions.size() >= 2 and fractions[0] < 1.0:
		# Move inward immediately when obstructed; the normal position damping then
		# eases outward once the obstruction clears.
		candidate = anchor + _collision_query.motion * maxf(0.0, fractions[0] - 0.015)
	_position = candidate
	camera.global_position = _position
	if _position.distance_squared_to(_focus) > 0.01:
		camera.look_at(_focus, Vector3.UP)

func update_fov(delta: float, speed_kmh: float, cockpit: Camera3D) -> void:
	var speed_fraction := smoothstep(0.0, 160.0, absf(speed_kmh))
	var desired_fov := base_fov + speed_fov_boost * speed_fraction
	var weight := 1.0 - exp(-3.5 * delta)
	camera.fov = lerpf(camera.fov, desired_fov, weight)
	if is_instance_valid(cockpit):
		cockpit.fov = lerpf(cockpit.fov, desired_fov, weight)

func reset_fov(cockpit: Camera3D) -> void:
	if is_instance_valid(camera):
		camera.fov = base_fov
	if is_instance_valid(cockpit):
		cockpit.fov = base_fov
