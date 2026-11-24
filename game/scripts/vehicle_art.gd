extends RefCounted
## Installs the authored Blender kit without taking ownership of physics or animation.
## Existing suspension, wheel-spin, instrument, wiper and passenger nodes stay alive.
const ART: PackedScene = preload("res://assets/vehicles/aster_cabin.glb")

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
	for node in body_art.find_children("*", "MeshInstance3D", true, false):
		for surface in range(node.mesh.get_surface_count()):
			var material: Material = node.mesh.surface_get_material(surface)
			if material != null and material.resource_name == "Paint":
				node.set_surface_override_material(surface, paint)
			elif material != null and material.resource_name == "Exterior glass":
				var glazing := material.duplicate() as StandardMaterial3D
				glazing.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				glazing.albedo_color = Color(0.10, 0.16, 0.18, 0.48)
				glazing.cull_mode = BaseMaterial3D.CULL_BACK
				glazing.roughness = 0.12
				node.set_surface_override_material(surface, glazing)
	var cabin_art := _take(source, "CockpitStatic", cabin)
	_no_shadows(cabin_art)
	var steering: Node3D = vehicle.get("_steering_wheel")
	for child in steering.get_children():
		steering.remove_child(child)
		child.queue_free()
	var wheel_art := _take(source, "SteeringWheel", steering)
	_no_shadows(wheel_art)
	var wheel: Node3D = source.get_node("RoadWheel")
	var spins: Array = vehicle.get("_wheel_meshes")
	for spin in spins:
		for child in spin.get_children():
			spin.remove_child(child)
			child.queue_free()
		spin.add_child(wheel.duplicate())
	source.free()

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
