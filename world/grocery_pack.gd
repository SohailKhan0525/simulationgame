class_name GroceryPack
extends MeshInstance3D

## The origin is the centre of the package.
func dress(id: String, color: Color) -> void:
	var wrap := StandardMaterial3D.new()
	wrap.albedo_color = color
	wrap.roughness = 0.75
	var dimensions := Vector3(0.31,0.32,0.21)
	if id == "cocoa":
		var tin := CylinderMesh.new()
		tin.top_radius = 0.12
		tin.bottom_radius = 0.12
		tin.height = 0.31
		tin.radial_segments = 18
		tin.rings = 0
		tin.material = wrap
		mesh = tin
		dimensions = Vector3(0.18,0.27,0.24)
	else:
		if id == "soap": dimensions = Vector3(0.27,0.19,0.16)
		var pack := BoxMesh.new()
		pack.size = dimensions
		pack.material = wrap
		mesh = pack
	var ink := StandardMaterial3D.new()
	ink.albedo_texture = load("res://assets/packaging/%s.png" % id)
	var face := QuadMesh.new()
	face.size = Vector2(dimensions.x,dimensions.y)*0.94
	face.material = ink
	var label := MeshInstance3D.new()
	label.mesh = face
	add_child(label)
	label.position.z = dimensions.z*0.5+0.003
	var back := label.duplicate() as MeshInstance3D
	add_child(back)
	back.rotation.y = PI
	back.position.z = -label.position.z

func half_height() -> float:
	return mesh.get_aabb().size.y * 0.5
