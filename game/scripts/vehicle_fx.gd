extends Node3D
## One small live probe and two bounded CPU emitters for the player's vehicle.
## Cubemap resolution is project-wide: reflections/reflection_atlas/reflection_size.
const PLAYER_VISUAL_LAYER: int = 2
var target: RigidBody3D
var probe: ReflectionProbe
var smoke: Array[CPUParticles3D] = []
var _strength := Vector2.ZERO
var _quality: int = 1

func _ready() -> void:
	name = "VehicleEffects"
	# Exclude the car itself from its captured cubemap, while applying the probe
	# only to the car. These are render layers, independent of physics layers.
	for geometry in target.find_children("*", "GeometryInstance3D", true, false):
		geometry.layers = PLAYER_VISUAL_LAYER
	probe = ReflectionProbe.new()
	probe.name = "LiveVehicleReflection"
	probe.position = Vector3(0, 0.9, 0)
	probe.size = Vector3(5, 4, 8)
	probe.cull_mask = 1
	probe.reflection_mask = PLAYER_VISUAL_LAYER
	probe.max_distance = 90.0
	probe.mesh_lod_threshold = 4.0
	probe.enable_shadows = false
	probe.box_projection = false
	probe.update_mode = ReflectionProbe.UPDATE_ALWAYS
	add_child(probe)
	var texture := _smoke_texture()
	for side in range(2):
		var emitter := CPUParticles3D.new()
		emitter.name = "RearTireSmokeLeft" if side == 0 else "RearTireSmokeRight"
		emitter.emitting = false
		emitter.layers = PLAYER_VISUAL_LAYER
		emitter.amount = 24
		emitter.lifetime = 0.8
		emitter.lifetime_randomness = 0.25
		emitter.local_coords = false
		emitter.fixed_fps = 30
		emitter.direction = Vector3.UP
		emitter.spread = 42.0
		emitter.gravity = Vector3(0, 0.3, 0)
		emitter.initial_velocity_min = 0.2
		emitter.initial_velocity_max = 0.7
		emitter.scale_amount_min = 0.35
		emitter.scale_amount_max = 0.75
		emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		emitter.emission_sphere_radius = 0.12
		emitter.visibility_aabb = AABB(Vector3(-8, -2, -8), Vector3(16, 6, 16))
		emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var fade := Gradient.new()
		fade.set_color(0, Color(0.74, 0.73, 0.70, 0.0))
		fade.set_color(1, Color(0.82, 0.81, 0.78, 0.0))
		fade.add_point(0.15, Color(0.74, 0.73, 0.70, 0.46))
		fade.add_point(0.5, Color(0.79, 0.78, 0.75, 0.26))
		emitter.color_ramp = fade
		var growth := Curve.new()
		growth.add_point(Vector2(0, 0.4))
		growth.add_point(Vector2(1, 1.0))
		emitter.scale_amount_curve = growth
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.vertex_color_use_as_albedo = true
		material.albedo_texture = texture
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.roughness = 1.0
		var mesh := QuadMesh.new()
		mesh.size = Vector2.ONE
		mesh.material = material
		emitter.mesh = mesh
		add_child(emitter)
		smoke.append(emitter)

func _smoke_texture() -> ImageTexture:
	var texture := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	for y in range(48):
		for x in range(48):
			var point := (Vector2(x, y) - Vector2(23.5, 23.5)) / 23.5
			var radial := 1.0 - smoothstep(0.15, 1.0, point.length())
			var variation := 0.88 + sin(float(x) * 0.53 + cos(float(y) * 0.61)) * 0.12
			texture.set_pixel(x, y, Color(1, 1, 1, radial * variation))
	return ImageTexture.create_from_image(texture)

func set_quality(value: int) -> void:
	_quality = clampi(value, 0, 2)
	for emitter in smoke:
		emitter.amount = [16, 24, 36][_quality]
	if is_instance_valid(probe):
		probe.max_distance = [65.0, 90.0, 120.0][_quality]

func reset_effects() -> void:
	_strength = Vector2.ZERO
	for emitter in smoke:
		emitter.visible = false
		emitter.restart()
		emitter.emitting = false

func update_effects(delta: float, slip: Vector2, contacts: PackedVector3Array, grounded: Vector2, active: bool) -> void:
	var update_mode := ReflectionProbe.UPDATE_ALWAYS if active else ReflectionProbe.UPDATE_ONCE
	if probe.update_mode != update_mode:
		probe.update_mode = update_mode
	if not active:
		if _strength != Vector2.ZERO or smoke[0].emitting or smoke[1].emitting:
			reset_effects()
		return
	_strength = _strength.lerp(slip, 1.0 - exp(-12.0 * delta))
	for side in range(2):
		var emitter := smoke[side]
		if contacts.size() > side:
			emitter.global_position = contacts[side] + Vector3.UP * 0.07
		if grounded[side] < 0.5:
			_strength[side] = 0.0
		emitter.visible = true
		emitter.color.a = clampf(_strength[side], 0.0, 1.0)
		emitter.emitting = _strength[side] > 0.08
