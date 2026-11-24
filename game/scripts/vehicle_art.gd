extends RefCounted
## Installs the authored Blender kit without taking ownership of physics or animation.
## Existing suspension, wheel-spin, instrument, wiper and passenger nodes stay alive.
const ART: PackedScene = preload("res://assets/vehicles/aster_cabin.glb")
const WHEELS: Array[PackedScene] = [
	preload("res://assets/vehicles/aster_wheel_fl.glb"),
	preload("res://assets/vehicles/aster_wheel_fr.glb"),
	preload("res://assets/vehicles/aster_wheel_rl.glb"),
	preload("res://assets/vehicles/aster_wheel_rr.glb")
]
const ALBEDO: Texture2D = preload("res://assets/vehicles/aster_albedo.png")
const NORMAL: Texture2D = preload("res://assets/vehicles/aster_normal.png")
const ROUGHNESS: Texture2D = preload("res://assets/vehicles/aster_roughness.png")
const OCCLUSION: Texture2D = preload("res://assets/vehicles/aster_ao.png")

static func install(vehicle: Node3D) -> void:
	var body := vehicle.get_node("Bodywork")
	var cabin := vehicle.get_node("HandcraftedCockpit")
	if cabin.has_node("CockpitStatic"):
		return
	var source := ART.instantiate()
	for child in body.get_children():
		if child is MeshInstance3D:
			body.remove_child(child)
			child.queue_free()
	for child in cabin.get_children():
		if child is MeshInstance3D:
			# The moving needles are separate nodes. Retain their static dial discs/ticks.
			var p: Vector3 = child.position
			var instrument := p.x < -0.15 and p.y > 0.80 and absf(p.z + 0.665) < 0.029
			if instrument:
				child.position.z += 0.045
			else:
				cabin.remove_child(child)
				child.queue_free()
	# Bring the whole instrument layer in front of the housing, including animated
	# needles and labels. A physical clearance avoids grazing-angle occlusion.
	for needle_name in ["_speed_needle", "_rpm_needle", "_speed_label", "_gear_label"]:
		var needle: Node3D = vehicle.get(needle_name)
		needle.position.z += 0.045
	for child in cabin.get_children():
		if child is Label3D and child.position.x < -0.15 and absf(child.position.z + 0.661) < 0.005:
			child.position.z += 0.045
	var body_art := _take(source, "BodyworkStatic", body)
	var paint: Material = vehicle.get("_paint")
	var lights := {"headlamps": [], "brakelamps": []}
	var shared_materials: Dictionary = {}
	_apply_materials(body_art, paint, lights, shared_materials)
	var cabin_art := _take(source, "CockpitStatic", cabin)
	_apply_materials(cabin_art, paint, lights, shared_materials)
	_no_shadows(cabin_art)
	var steering: Node3D = vehicle.get("_steering_wheel")
	for child in steering.get_children():
		steering.remove_child(child)
		child.queue_free()
	var wheel_art := _take(source, "SteeringWheel", steering)
	_apply_materials(wheel_art, paint, lights, shared_materials)
	_no_shadows(wheel_art)
	var spins: Array = vehicle.get("_wheel_meshes")
	for index in range(spins.size()):
		var spin: Node3D = spins[index]
		for child in spin.get_children():
			spin.remove_child(child)
			child.queue_free()
		var rolling_wheel := WHEELS[index].instantiate()
		spin.add_child(rolling_wheel)
		_apply_materials(rolling_wheel, paint, lights, shared_materials)
	vehicle.set_meta("vehicle_art_lights", lights)
	update_lights(vehicle, 0.0, bool(vehicle.get("headlights_on")))
	source.free()

static func _apply_materials(root: Node, paint: Material, lights: Dictionary, shared: Dictionary) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		for surface in range(node.mesh.get_surface_count()):
			var source: Material = node.mesh.surface_get_material(surface)
			if source == null:
				continue
			var key: String = source.resource_name
			if shared.has(key):
				node.set_surface_override_material(surface, shared[key])
				continue
			var material: StandardMaterial3D = paint if key == "Paint" else source.duplicate()
			if key == "Exterior glass":
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				material.albedo_color = Color(0.10, 0.16, 0.18, 0.48)
				material.cull_mode = BaseMaterial3D.CULL_BACK
				material.roughness = 0.12
			else:
				material.albedo_texture = ALBEDO
				if key != "Paint":
					material.albedo_color = Color.WHITE
				material.normal_enabled = true
				material.normal_texture = NORMAL
				material.normal_scale = 0.7
				material.roughness = 1.0
				material.roughness_texture = ROUGHNESS
				material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
				material.ao_enabled = true
				material.ao_texture = OCCLUSION
				material.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
				material.ao_light_affect = 0.0
			if key == "Paint":
				material.metallic = 0.65
				material.clearcoat_enabled = true
				material.clearcoat = 0.8
				material.clearcoat_roughness = 0.11
			elif key == "Headlamp lens":
				material.emission_enabled = true
				material.emission = Color(0.85, 0.93, 1.0)
				lights.headlamps.append(material)
			elif key == "Tail lamp":
				material.emission_enabled = true
				material.emission = Color(1.0, 0.02, 0.01)
				lights.brakelamps.append(material)
			shared[key] = material
			node.set_surface_override_material(surface, material)

static func update_lights(vehicle: Node3D, braking: float, headlights: bool) -> void:
	if not vehicle.has_meta("vehicle_art_lights"):
		return
	var lights: Dictionary = vehicle.get_meta("vehicle_art_lights")
	for material in lights.headlamps:
		material.emission_energy_multiplier = 2.2 if headlights else 0.02
	for material in lights.brakelamps:
		material.emission_energy_multiplier = (0.3 if headlights else 0.03) + clampf(braking, 0.0, 1.0) * 3.0

static func _take(source: Node, node_name: String, parent: Node) -> Node3D:
	var node: Node3D = source.get_node(node_name)
	node.owner = null
	for child in node.find_children("*", "", true, false):
		child.owner = null
	source.remove_child(node)
	parent.add_child(node)
	return node

static func _no_shadows(root: Node) -> void:
	for geometry in root.find_children("*", "GeometryInstance3D", true, false):
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
