class_name DriveVehicle
extends RigidBody3D
## Four independent contact rays, damped springs and a combined tire-force budget.
## An approachable driving model, not a validated automotive simulator.

var throttle: float = 0.0
var brake: float = 0.0
var steer: float = 0.0
var handbrake: bool = false
var enabled: bool = false:
	set(value):
		enabled = value
		if not enabled:
			effective_brake = 0.0
			rear_tire_slip = Vector2.ZERO
			downforce_newtons = 0.0
			if is_instance_valid(_effects):
				_effects.reset_effects()
var wetness: float = 0.0
var volume: float = 0.7
var fuel_liters: float = 42.0
var damage: float = 0.0
var speed_kmh: float = 0.0
var rpm: float = 850.0
var gear: int = 1
var distance_m: float = 0.0
var car_index: int = 0
var upgrade_level: int = 0
var cockpit_camera: Camera3D
var chase_camera: Camera3D
var reflection_probe: ReflectionProbe
## 0 = cockpit, 1 = chase. Main owns which camera becomes current.
var camera_mode: int = 1
var base_fov: float = 65.0
var effective_brake: float = 0.0
var grounded_wheels: int = 0
var rear_tire_slip := Vector2.ZERO
var rear_grounded := Vector2.ZERO
var rear_contact_points := PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
var downforce_coefficient: float = 1.8
var downforce_newtons: float = 0.0

const CAR_NAMES := ["Aster S", "Meridian GT", "Veloce R"]
const WHEEL_RADIUS: float = 0.32
const SPRING_REST: float = 0.48
const RAY_LENGTH: float = SPRING_REST + WHEEL_RADIUS + 0.12
const WHEEL_MOUNTS := [Vector3(-0.82, 0.28, -1.28), Vector3(0.82, 0.28, -1.28), Vector3(-0.82, 0.28, 1.28), Vector3(0.82, 0.28, 1.28)]

var _engine_force: float = 6600.0
var _top_speed: float = 48.0
var _steering: float = 0.0
var _steering_input: float = 0.0
var _wheel_spin: float = 0.0
var _wheel_pivots: Array[Node3D] = []
var _wheel_meshes: Array[Node3D] = []
var _steering_wheel: Node3D
var _speed_needle: Node3D
var _rpm_needle: Node3D
var _speed_label: Label3D
var _gear_label: Label3D
var _paint: StandardMaterial3D
var _engine_audio: Node
var _last_speed: float = 0.0
var _impact_cooldown: float = 0.0
var _reset_pending: bool = false
var _reset_transform: Transform3D
var _headlights: Array[SpotLight3D] = []
var headlights_on: bool = true
var _passenger: Node3D
var _passenger_coat: StandardMaterial3D
var _wiper_pivots: Array[Node3D] = []
var _wiper_clock: float = 0.0
var _wiper_angle: float = deg_to_rad(-73.0)
var _camera_rig: Node3D
var _effects: Node3D
const VehicleArt = preload("res://scripts/vehicle_art.gd")

func _ready() -> void:
	mass = 1280.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.0, 0.12)
	inertia = Vector3(1500, 1900, 650)
	linear_damp = 0.02
	angular_damp = 1.8
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 4
	can_sleep = false
	collision_layer = 2
	collision_mask = 1 | 2 | 4
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.72, 0.56, 3.92)
	collision.shape = shape
	collision.position.y = 0.28
	add_child(collision)
	var physics_material := PhysicsMaterial.new()
	physics_material.friction = 0.25
	physics_material.bounce = 0.05
	physics_material_override = physics_material
	_build_visuals()
	_camera_rig = load("res://scripts/vehicle_camera.gd").new()
	_camera_rig.target = self
	_camera_rig.base_fov = base_fov
	add_child(_camera_rig)
	chase_camera = _camera_rig.camera
	_camera_rig.reset_fov(cockpit_camera)
	_effects = load("res://scripts/vehicle_fx.gd").new()
	_effects.target = self
	add_child(_effects)
	reflection_probe = _effects.probe
	_engine_audio = load("res://scripts/vehicle_audio.gd").new()
	add_child(_engine_audio)
	configure(car_index, upgrade_level)

func configure(selected_car: int, upgrades: int) -> void:
	car_index = clampi(selected_car, 0, 2)
	upgrade_level = clampi(upgrades, 0, 5)
	_engine_force = [6600.0, 8400.0, 10500.0][car_index] * (1.0 + 0.08 * upgrade_level)
	_top_speed = [48.0, 57.0, 67.0][car_index] + upgrade_level * 1.6
	mass = [1280.0, 1420.0, 1540.0][car_index]
	if _paint != null:
		_paint.albedo_color = [Color("526772"), Color("b94429"), Color("d8d2c1")][car_index]

func set_camera_mode(value: int, make_current: bool = true) -> void:
	camera_mode = clampi(value, 0, 1)
	if camera_mode == 1 and is_instance_valid(_camera_rig):
		_camera_rig.snap()
	if make_current:
		var selected := get_active_camera()
		if is_instance_valid(selected): selected.make_current()

func get_active_camera() -> Camera3D:
	return cockpit_camera if camera_mode == 0 else chase_camera

func set_base_fov(degrees: float) -> void:
	# Default65 reaches82 at160km/h. A user-adjusted base keeps the same17-degree
	# speed range; both views share the setting and remain switchable at any speed.
	base_fov = clampf(degrees, 50.0, 90.0)
	if is_instance_valid(_camera_rig):
		_camera_rig.base_fov = base_fov

func set_camera_far(distance: float) -> void:
	var far_distance := maxf(50.0, distance)
	if is_instance_valid(cockpit_camera): cockpit_camera.far = far_distance
	if is_instance_valid(chase_camera): chase_camera.far = far_distance

func set_visual_quality(value: int) -> void:
	if is_instance_valid(_effects): _effects.set_quality(value)

func reset_to(world_position: Vector3, yaw: float = 0.0) -> void:
	_reset_transform = Transform3D(Basis(Vector3.UP, yaw), world_position)
	_reset_pending = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = _reset_transform
	speed_kmh = 0.0
	effective_brake = 0.0
	grounded_wheels = 0
	rear_tire_slip = Vector2.ZERO
	rear_grounded = Vector2.ZERO
	downforce_newtons = 0.0
	if is_instance_valid(_camera_rig):
		_camera_rig.snap()
		_camera_rig.reset_fov(cockpit_camera)
	if is_instance_valid(_effects): _effects.reset_effects()
	sleeping = false

func set_passenger(active: bool, passenger_kind: String = "commuter") -> void:
	if _passenger == null:
		return
	_passenger.visible = active
	var kind := passenger_kind.to_lower()
	_passenger_coat.albedo_color = Color("526f62")
	if "cop" in kind or "officer" in kind:
		_passenger_coat.albedo_color = Color("243c61")
	elif "drunk" in kind or "tipsy" in kind:
		_passenger_coat.albedo_color = Color("805539")
	elif "thief" in kind or "shady" in kind:
		_passenger_coat.albedo_color = Color("292c38")

func horn() -> void:
	if _engine_audio != null:
		_engine_audio.horn()

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _reset_pending:
		state.transform = _reset_transform
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		_reset_pending = false
		_last_speed = 0.0
		_steering = 0.0
		_steering_input = 0.0
		speed_kmh = 0.0
		return
	var dt: float = state.step
	var body_basis: Basis = state.transform.basis.orthonormalized()
	var up: Vector3 = body_basis.y
	var forward: Vector3 = -body_basis.z
	var longitudinal_speed: float = state.linear_velocity.dot(forward)
	speed_kmh = state.linear_velocity.length() * 3.6
	var acceleration_input: float = clampf(throttle, -1.0, 1.0) if enabled and fuel_liters > 0.0 else 0.0
	var brake_input: float = clampf(brake, 0.0, 1.0) if enabled else 1.0
	# Selecting the other direction while moving first brakes the car. Reversing
	# drive torque at road speed makes the touchscreen D/R selector unpredictable.
	if acceleration_input * longitudinal_speed < 0.0 and absf(longitudinal_speed) > 1.2:
		brake_input = maxf(brake_input, absf(acceleration_input))
		acceleration_input = 0.0
	# A resting thumb on DRIVE must not fight the brake under the other thumb.
	acceleration_input *= 1.0 - brake_input
	effective_brake = maxf(brake_input, 1.0 if handbrake else 0.0) if enabled else 0.0
	var target_steer: float = clampf(steer, -1.0, 1.0) if enabled else 0.0
	var road_speed: float = absf(longitudinal_speed)
	var returning: bool = is_zero_approx(target_steer) or target_steer * _steering_input < 0.0
	var steering_rate: float = 4.6 if returning else lerpf(3.4, 2.2, clampf(road_speed / 35.0, 0.0, 1.0))
	_steering_input = move_toward(_steering_input, target_steer, dt * steering_rate)
	# Retain parking lock, then reduce lock with speed. The bicycle-model envelope
	# prevents a full thumb swipe from demanding an impossible high-speed corner.
	var steering_limit: float = clampf(atan(2.56 * 8.5 / maxf(1.0, road_speed * road_speed)), 0.005, 0.54)
	_steering = -_steering_input * steering_limit
	var contacts: int = 0
	var ground_normal := Vector3.ZERO
	rear_tire_slip = Vector2.ZERO
	rear_grounded = Vector2.ZERO
	for index in range(4):
		var mount: Vector3 = WHEEL_MOUNTS[index]
		var ray_origin: Vector3 = state.transform * mount
		var ray_end: Vector3 = ray_origin - up * RAY_LENGTH
		var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, 1 | 4, [get_rid()])
		var hit: Dictionary = state.get_space_state().intersect_ray(query)
		var spring_length: float = SPRING_REST
		if not hit.is_empty():
			var contact: Vector3 = hit.position
			var normal: Vector3 = hit.normal
			spring_length = clampf(ray_origin.distance_to(contact) - WHEEL_RADIUS, 0.02, SPRING_REST)
			var compression: float = SPRING_REST - spring_length
			var arm: Vector3 = contact - state.transform.origin
			var velocity_at_contact: Vector3 = state.linear_velocity + state.angular_velocity.cross(arm)
			var normal_force: float = clampf(compression * 32000.0 - velocity_at_contact.dot(up) * 3900.0, 0.0, 18000.0)
			if normal_force > 0.0 and normal.dot(up) > 0.35:
				contacts += 1
				ground_normal += normal
				state.apply_force(up * normal_force, ray_origin - state.transform.origin)
				var tire_forward: Vector3 = forward.rotated(up, _steering if index < 2 else 0.0)
				tire_forward = tire_forward.slide(normal).normalized()
				var tire_right: Vector3 = tire_forward.cross(normal).normalized()
				var forward_speed: float = velocity_at_contact.dot(tire_forward)
				var side_speed: float = velocity_at_contact.dot(tire_right)
				if index >= 2:
					var rear_index := index - 2
					rear_grounded[rear_index] = 1.0
					rear_contact_points[rear_index] = contact
					var slide := clampf((absf(side_speed) - 1.8) / 5.0, 0.0, 1.0)
					var locked := clampf((absf(forward_speed) - 5.0) / 12.0, 0.0, 1.0) if handbrake else 0.0
					rear_tire_slip[rear_index] = maxf(slide, locked) * (1.0 - clampf(wetness, 0.0, 1.0) * 0.75) if enabled else 0.0
				var grip: float = lerpf(1.25, 0.77, clampf(wetness, 0.0, 1.0))
				if enabled and handbrake and index >= 2:
					grip *= 0.5
				var drive: float = acceleration_input * _engine_force * 0.25
				var speed_limit: float = _top_speed if acceleration_input >= 0.0 else 10.0
				drive *= clampf(1.0 - absf(forward_speed) / speed_limit, 0.0, 1.0)
				var rolling_resistance: float = -forward_speed * 10.0
				var braking: float = brake_input * 9000.0
				if enabled and handbrake and index >= 2:
					braking += 11000.0
				# Limiting braking by the momentum removed per step prevents low-speed oscillation.
				var brake_force: float = -signf(forward_speed) * minf(braking, absf(forward_speed) * mass * 0.25 / dt)
				var lateral_force: float = -side_speed * mass * 1.6
				var tire_force: Vector3 = tire_forward * (drive + brake_force + rolling_resistance) + tire_right * lateral_force
				tire_force = tire_force.limit_length(normal_force * grip)
				state.apply_force(tire_force, arm)
		if index < _wheel_pivots.size():
			_wheel_pivots[index].position = mount - Vector3.UP * spring_length
			_wheel_pivots[index].rotation.y = _steering if index < 2 else 0.0
		# Keep decorative wheels separate from their steering pivots.
		if index < _wheel_meshes.size():
			_wheel_meshes[index].rotation.x = _wheel_spin
	var velocity: Vector3 = state.linear_velocity
	state.apply_central_force(-velocity * velocity.length() * 0.42)
	grounded_wheels = contacts
	downforce_newtons = 0.0
	if contacts >= 2:
		# Modest speed-squared aero load only while supported by the road. Capping
		# it at28% of weight avoids pinning the car down or accelerating an airborne car.
		if enabled and up.dot(Vector3.UP) > 0.35 and road_speed > 5.0:
			downforce_newtons = minf(maxf(0.0, downforce_coefficient) * road_speed * road_speed, mass * 9.8 * 0.28)
			state.apply_central_force(-ground_normal.normalized() * downforce_newtons)
		# Gentle anti-roll assistance retains bumps and weight transfer without easy mobile rollovers.
		var upright_error: Vector3 = up.cross(Vector3.UP)
		state.apply_torque(upright_error * 3600.0 - Vector3(state.angular_velocity.x, 0, state.angular_velocity.z) * 900.0)
	if enabled:
		distance_m += velocity.length() * dt
		fuel_liters = maxf(0.0, fuel_liters - (0.00025 + absf(acceleration_input) * 0.0015 + velocity.length() * 0.000015) * dt)
		_wheel_spin -= longitudinal_speed / WHEEL_RADIUS * dt
		if state.get_contact_count() > 0 and _impact_cooldown <= 0.0:
			var impact: float = maxf(0.0, _last_speed - velocity.length())
			if impact > 3.5:
				damage = clampf(damage + impact * 1.2, 0.0, 100.0)
				_impact_cooldown = 0.7
				if _engine_audio != null:
					_engine_audio.impact()
	_impact_cooldown = maxf(0.0, _impact_cooldown - dt)
	_last_speed = velocity.length()
	gear = -1 if acceleration_input < 0.0 and longitudinal_speed < 1.0 else clampi(1 + int(maxf(0, longitudinal_speed) / 9.0), 1, 6)
	var gear_speed: float = fmod(absf(longitudinal_speed), 9.0)
	var target_rpm: float = 850.0 + gear_speed / 9.0 * 4200.0 + absf(acceleration_input) * 850.0
	rpm = lerpf(rpm, target_rpm, minf(1.0, dt * 9.0)) if fuel_liters > 0.0 else 0.0

func _process(delta: float) -> void:
	if is_instance_valid(_camera_rig):
		_camera_rig.update_fov(delta, speed_kmh, cockpit_camera)
	if is_instance_valid(_effects):
		_effects.update_effects(delta, rear_tire_slip, rear_contact_points, rear_grounded, enabled and not freeze)
	VehicleArt.update_lights(self, effective_brake, headlights_on)
	if wetness > 0.25:
		_wiper_clock += delta * lerpf(0.65, 1.35, clampf(wetness, 0.0, 1.0))
		# Ease at each end of the sweep, like a linked wiper motor.
		var sweep: float = 0.5 - 0.5 * cos(_wiper_clock * TAU)
		_wiper_angle = lerpf(deg_to_rad(-73.0), deg_to_rad(57.0), sweep)
	else:
		_wiper_angle = move_toward(_wiper_angle, deg_to_rad(-73.0), delta * 3.5)
		_wiper_clock = 0.0
	for wiper in _wiper_pivots:
		wiper.rotation.z = _wiper_angle
	if _steering_wheel != null:
		_steering_wheel.rotation.z = _steering * 3.0
		_speed_needle.rotation.z = deg_to_rad(125.0 - minf(speed_kmh, 240.0) / 240.0 * 250.0)
		_rpm_needle.rotation.z = deg_to_rad(125.0 - minf(rpm, 7500.0) / 7500.0 * 250.0)
		_speed_label.text = "%03d" % int(speed_kmh)
		_gear_label.text = "R" if gear < 0 else str(gear)
		cockpit_camera.position.y = lerpf(cockpit_camera.position.y, 1.13 + sin(Time.get_ticks_msec() * 0.025) * minf(speed_kmh / 20000.0, 0.004), minf(1.0, delta * 12.0))
	if _engine_audio != null:
		_engine_audio.engine_rpm = rpm
		_engine_audio.load_amount = absf(throttle)
		_engine_audio.speed = speed_kmh
		_engine_audio.car_index = car_index
		_engine_audio.rain_amount = clampf(wetness, 0.0, 1.0)
		_engine_audio.volume = volume if enabled else volume * 0.12
		_engine_audio.running = fuel_liters > 0.0
	for lamp in _headlights:
		lamp.visible = headlights_on

func _material(color: Color, metallic: float = 0.0, roughness: float = 0.6, glow: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material

func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance

func _cylinder(parent: Node3D, radius: float, height: float, at: Vector3, material: Material, sides: int = 20) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance

func _label(parent: Node3D, value: String, at: Vector3, size: int, color: Color) -> Label3D:
	var text := Label3D.new()
	text.text = value
	text.position = at
	text.font_size = size
	text.pixel_size = 0.001
	text.modulate = color
	text.no_depth_test = false
	text.outline_size = 0
	parent.add_child(text)
	return text

func _build_visuals() -> void:
	_paint = _material(Color("526772"), 0.65, 0.25)
	var leather := _material(Color("141c21"), 0.05, 0.8)
	var leather_light := _material(Color("273039"), 0.0, 0.88)
	var trim := _material(Color("82928e"), 0.8, 0.22)
	var black := _material(Color("070d12"), 0.0, 0.65)
	var tan := _material(Color("9e7960"), 0.0, 0.86)
	var aqua := _material(Color("a6e4cd"), 0.3, 0.3, 0.7)
	var warm := _material(Color("fff0cc"), 0.0, 0.2, 2.4)
	var red := _material(Color("d83c32"), 0.0, 0.3, 1.5)
	var outer := Node3D.new()
	outer.name = "Bodywork"
	add_child(outer)
	_box(outer, Vector3(1.76, 0.42, 3.9), Vector3(0, 0.27, 0), _paint)
	_box(outer, Vector3(1.7, 0.18, 1.14), Vector3(0, 0.55, -1.36), _paint)
	_box(outer, Vector3(1.68, 0.14, 0.7), Vector3(0, 0.56, 1.54), _paint)
	_box(outer, Vector3(1.65, 0.08, 1.98), Vector3(0, 1.52, 0.31), _paint)
	_box(outer, Vector3(1.74, 0.11, 0.08), Vector3(0, 0.19, -1.99), black)
	_box(outer, Vector3(0.72, 0.16, 0.03), Vector3(0, 0.4, -1.97), black)
	for x in [-0.59, 0.59]:
		_box(outer, Vector3(0.42, 0.09, 0.035), Vector3(x, 0.52, -1.99), warm)
		_box(outer, Vector3(0.49, 0.08, 0.035), Vector3(x, 0.5, 1.99), red)
		var lamp := SpotLight3D.new()
		lamp.position = Vector3(x, 0.55, -2.02)
		lamp.light_color = Color("e1eddf")
		lamp.light_energy = 1.1
		lamp.spot_range = 32.0
		lamp.spot_angle = 32.0
		lamp.shadow_enabled = false
		outer.add_child(lamp)
		_headlights.append(lamp)
	for x in [-0.84, 0.84]:
		_box(outer, Vector3(0.055, 0.52, 2.2), Vector3(x, 0.61, 0.14), _paint)
		_box(outer, Vector3(0.075, 0.09, 2.25), Vector3(x, 0.93, 0.16), leather)
		var pillar := _box(outer, Vector3(0.055, 0.79, 0.055), Vector3(x * 0.95, 1.15, -0.8), leather)
		pillar.rotation.x = -0.34
		_box(outer, Vector3(0.075, 0.58, 0.07), Vector3(x * 0.96, 1.21, 1.18), leather)
		_box(outer, Vector3(0.06, 0.57, 0.075), Vector3(x * 0.98, 1.2, 0.44), leather)
		_box(outer, Vector3(0.21, 0.14, 0.28), Vector3(x * 1.17, 0.94, -0.71), _paint)
		_box(outer, Vector3(0.18, 0.1, 0.01), Vector3(x * 1.17, 0.94, -0.56), trim)
		_box(outer, Vector3(0.035, 0.025, 0.19), Vector3(x * 1.06, 0.75, 0.5), trim)
		_box(outer, Vector3(0.04, 0.08, 1.7), Vector3(x * 0.9, 0.66, 0.22), tan)
	for i in range(4):
		var pivot := Node3D.new()
		pivot.position = WHEEL_MOUNTS[i] - Vector3.UP * SPRING_REST
		add_child(pivot)
		_wheel_pivots.append(pivot)
		var spin := Node3D.new()
		pivot.add_child(spin)
		_wheel_meshes.append(spin)
		var tire := _cylinder(spin, WHEEL_RADIUS, 0.24, Vector3.ZERO, black, 24)
		tire.rotation.z = PI * 0.5
		var rim := _cylinder(spin, 0.23, 0.252, Vector3.ZERO, trim, 12)
		rim.rotation.z = PI * 0.5
		var hub := _cylinder(spin, 0.07, 0.26, Vector3.ZERO, leather, 12)
		hub.rotation.z = PI * 0.5
		for spoke_index in range(5):
			var angle: float = spoke_index * TAU / 5.0
			var spoke := _box(spin, Vector3(0.265, 0.038, 0.38), Vector3.ZERO, leather)
			spoke.rotation.x = angle
	var cabin := Node3D.new()
	cabin.name = "HandcraftedCockpit"
	add_child(cabin)
	_box(cabin, Vector3(1.55, 0.12, 2.2), Vector3(0, 0.28, 0.19), leather)
	_box(cabin, Vector3(1.58, 0.23, 0.39), Vector3(0, 0.75, -0.83), leather)
	_box(cabin, Vector3(1.5, 0.025, 0.035), Vector3(0, 0.78, -0.618), trim)
	_box(cabin, Vector3(1.48, 0.025, 0.028), Vector3(0, 0.69, -0.616), tan)
	_box(cabin, Vector3(0.25, 0.3, 1.5), Vector3(0, 0.43, 0.1), leather)
	_box(cabin, Vector3(0.21, 0.01, 0.45), Vector3(0, 0.59, -0.2), trim)
	for x in [-0.4, 0.4]:
		_box(cabin, Vector3(0.57, 0.16, 0.58), Vector3(x, 0.5, 0.38), tan)
		var seat_back := _box(cabin, Vector3(0.56, 0.61, 0.12), Vector3(x, 0.82, 0.72), tan)
		seat_back.rotation.x = -0.12
		_box(cabin, Vector3(0.27, 0.17, 0.13), Vector3(x, 1.18, 0.75), leather_light)
		for seam in [-0.19, 0.19]:
			_box(cabin, Vector3(0.009, 0.135, 0.52), Vector3(x + seam, 0.515, 0.38), leather_light)
	# Instrument cluster faces the seated driver, with luminous markings and real needles.
	_box(cabin, Vector3(0.61, 0.21, 0.04), Vector3(-0.4, 0.9, -0.7), black)
	_speed_needle = _dial(cabin, Vector3(-0.53, 0.9, -0.67), "KM/H", aqua, black)
	_rpm_needle = _dial(cabin, Vector3(-0.27, 0.9, -0.67), "RPM", aqua, black)
	_speed_label = _label(cabin, "000", Vector3(-0.53, 0.87, -0.645), 21, Color("d8f3e5"))
	_gear_label = _label(cabin, "1", Vector3(-0.4, 0.91, -0.645), 22, Color("e6b66f"))
	_box(cabin, Vector3(0.24, 0.15, 0.028), Vector3(0.15, 0.9, -0.65), black)
	_label(cabin, "QOFENO", Vector3(0.15, 0.935, -0.63), 16, Color("afdbc7"))
	_label(cabin, "DRIVE / LIVE", Vector3(0.15, 0.89, -0.63), 10, Color("81958c"))
	for x in [-0.73, 0.4, 0.65]:
		_box(cabin, Vector3(0.13, 0.045, 0.016), Vector3(x, 0.84, -0.614), black)
		for slat in range(4):
			_box(cabin, Vector3(0.005, 0.035, 0.022), Vector3(x - 0.046 + slat * 0.03, 0.84, -0.6), trim)
	_steering_wheel = Node3D.new()
	_steering_wheel.position = Vector3(-0.4, 0.81, -0.39)
	cabin.add_child(_steering_wheel)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.159
	torus.outer_radius = 0.184
	torus.rings = 28
	torus.ring_segments = 8
	ring.mesh = torus
	ring.rotation.x = PI * 0.5
	ring.material_override = leather
	_steering_wheel.add_child(ring)
	_box(_steering_wheel, Vector3(0.3, 0.033, 0.028), Vector3(0, -0.008, 0), trim)
	_box(_steering_wheel, Vector3(0.035, 0.14, 0.028), Vector3(0, -0.075, 0), trim)
	_box(_steering_wheel, Vector3(0.11, 0.075, 0.045), Vector3.ZERO, leather_light)
	_label(_steering_wheel, "Q", Vector3(0, 0, 0.025), 30, Color("a4b5ac"))
	var shifter := _cylinder(cabin, 0.025, 0.12, Vector3(0, 0.67, -0.13), trim, 12)
	shifter.rotation.x = -0.2
	_box(cabin, Vector3(0.058, 0.055, 0.09), Vector3(0, 0.74, -0.15), leather)
	_box(cabin, Vector3(0.27, 0.08, 0.03), Vector3(0.15, 1.38, -0.69), black)
	_box(cabin, Vector3(0.25, 0.06, 0.01), Vector3(0.15, 1.38, -0.67), trim)
	# Thin, shadow-free geometry follows the sloping windshield plane.
	# There is no full-screen glass overlay, so the road remains clearly visible.
	for pivot_x in [-0.37, 0.43]:
		var mount := Node3D.new()
		mount.name = "WindshieldWiperMount"
		mount.position = Vector3(pivot_x, 0.88, -0.98)
		mount.rotation.x = 0.38
		cabin.add_child(mount)
		var sweep_pivot := Node3D.new()
		sweep_pivot.rotation.z = _wiper_angle
		mount.add_child(sweep_pivot)
		_wiper_pivots.append(sweep_pivot)
		var arm := _box(sweep_pivot, Vector3(0.009, 0.28, 0.009), Vector3(0, 0.14, 0), trim)
		arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var blade := _box(sweep_pivot, Vector3(0.014, 0.25, 0.014), Vector3(0, 0.33, 0.006), black)
		blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_passenger = Node3D.new()
	_passenger.name = "Passenger"
	_passenger.position = Vector3(0.4, 0, 0.48)
	_passenger.visible = false
	cabin.add_child(_passenger)
	_passenger_coat = _material(Color("526f62"), 0.0, 0.9)
	_box(_passenger, Vector3(0.4, 0.4, 0.22), Vector3(0, 0.83, 0), _passenger_coat)
	var skin := _material(Color("b58a68"), 0.0, 0.96)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.11
	head_mesh.height = 0.25
	head_mesh.radial_segments = 16
	head_mesh.rings = 8
	head.mesh = head_mesh
	head.material_override = skin
	head.position = Vector3(0, 1.15, -0.015)
	_passenger.add_child(head)
	_box(_passenger, Vector3(0.2, 0.07, 0.2), Vector3(0, 1.25, 0), black)
	for arm_x in [-0.24, 0.24]:
		_box(_passenger, Vector3(0.09, 0.3, 0.1), Vector3(arm_x, 0.8, -0.03), _passenger_coat)
		_box(_passenger, Vector3(0.13, 0.15, 0.4), Vector3(arm_x * 0.5, 0.6, -0.17), leather)
	# Cabin pieces are always close to the camera. They receive scene lighting but
	# do not need individual shadow-map passes on mobile; exterior bodywork keeps shadows.
	for geometry in cabin.find_children("*", "GeometryInstance3D", true, false):
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cockpit_camera = Camera3D.new()
	cockpit_camera.name = "CockpitCamera"
	cockpit_camera.position = Vector3(-0.4, 1.13, 0.25)
	cockpit_camera.rotation.x = deg_to_rad(-3.0)
	cockpit_camera.fov = 78.0
	cockpit_camera.near = 0.035
	cockpit_camera.far = 1400.0
	cockpit_camera.current = false
	add_child(cockpit_camera)

	VehicleArt.install(self)

func _dial(parent: Node3D, at: Vector3, title: String, luminous: Material, background: Material) -> Node3D:
	var disc := _cylinder(parent, 0.086, 0.008, at, background, 32)
	disc.rotation.x = PI * 0.5
	for i in range(11):
		var angle: float = deg_to_rad(-125.0 + i * 25.0)
		var tick := _box(parent, Vector3(0.003, 0.012, 0.002), at + Vector3(sin(angle), cos(angle), 0) * 0.07 + Vector3(0, 0, 0.006), luminous)
		tick.rotation.z = -angle
	_label(parent, title, at + Vector3(0, 0.025, 0.009), 10, Color("8cb7a5"))
	var needle := Node3D.new()
	needle.position = at + Vector3(0, 0, 0.012)
	parent.add_child(needle)
	_box(needle, Vector3(0.003, 0.06, 0.003), Vector3(0, 0.026, 0), luminous)
	return needle
