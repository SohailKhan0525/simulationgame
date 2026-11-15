class_name Masonry
extends Node3D
## Small reusable construction kit. Static details share one draw batch per shape.
var pieces := {}
var colliders := StaticBody3D.new()

func _init() -> void:
	add_child(colliders)

func solid(p: Vector3, size: Vector3) -> void:
	var hit := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	hit.shape = box
	hit.position = p
	colliders.add_child(hit)

func part(kind: String, p: Vector3, size: Vector3, tint: String, rotation_x := 0.0, rotation_y := 0.0) -> void:
	if not pieces.has(kind): pieces[kind] = []
	var basis := Basis.from_euler(Vector3(rotation_x, rotation_y, 0)).scaled_local(size)
	pieces[kind].append([Transform3D(basis, p), Color(tint)])

func box(x: float, y: float, z: float, w: float, h: float, depth: float, tint: String, blocks := false) -> void:
	var pos := Vector3(x,y,z)
	var size := Vector3(w,h,depth)
	part("block",pos,size,tint)
	if blocks: solid(pos,size)

func label3(words: String, p: Vector3, height: float, ink: String, yaw := 0.0) -> Label3D:
	var sign_label := Label3D.new()
	sign_label.text = words
	sign_label.font_size = 72
	sign_label.pixel_size = height / 72.0
	sign_label.modulate = Color(ink)
	sign_label.outline_size = 0
	sign_label.double_sided = false
	sign_label.position = p
	sign_label.rotation.y = yaw
	add_child(sign_label)
	return sign_label

func bake() -> void:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.88
	for key in pieces:
		var mesh: PrimitiveMesh
		match key:
			"block":
				mesh = BoxMesh.new()
			"crown":
				var sphere := SphereMesh.new()
				sphere.radial_segments = 9
				sphere.rings = 4
				sphere.radius = 0.5
				sphere.height = 1.0
				mesh = sphere
			_:
				var tube := CylinderMesh.new()
				tube.radial_segments = 10
				tube.rings = 0
				tube.top_radius = 0.5
				tube.bottom_radius = 0.5
				tube.height = 1
				mesh = tube
		mesh.material = mat
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.use_colors = true
		batch.mesh = mesh
		batch.instance_count = pieces[key].size()
		for i in batch.instance_count:
			batch.set_instance_transform(i,pieces[key][i][0])
			batch.set_instance_color(i,pieces[key][i][1])
		var node := MultiMeshInstance3D.new()
		node.multimesh = batch
		add_child(node)
	pieces.clear()
