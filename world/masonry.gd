class_name Masonry
extends Node3D
## Small reusable construction kit. Static details share one draw batch per shape.
const SURFACES := {
	"road": ["asphalt_04",0.28], "brick": ["red_brick_03",0.83],
	"paving": ["concrete_pavement",0.55], "tile": ["floor_tiles_06",0.38]
}
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
	part("wood" if tint in ["ac7853","9c6847","bb8b61"] else "block",pos,size,tint)
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
		var surface := mat.duplicate() as StandardMaterial3D
		if SURFACES.has(key):
			var spec: Array = SURFACES[key]
			var prefix := "res://assets/environment/harbor/" + str(spec[0])
			surface.albedo_texture = load(prefix+".jpg")
			surface.normal_enabled = true
			surface.normal_texture = load(prefix+"_n.jpg")
			surface.normal_scale = 0.55
			surface.roughness = 0.42 if key == "tile" else 0.91
			surface.uv1_triplanar = true
			surface.uv1_world_triplanar = true
			surface.uv1_scale = Vector3.ONE * float(spec[1])
		elif key == "steel":
			surface.metallic = 0.72
			surface.roughness = 0.32
		elif key == "window":
			surface.metallic = 0.72
			surface.roughness = 0.13
		elif key == "luminous":
			surface.emission_enabled = true
			surface.emission = Color("fff0ce")
			surface.emission_energy_multiplier = 0.65
		elif key == "wood":
			surface.albedo_texture = load("res://assets/environment/timber.png")
			surface.uv1_triplanar = true
			surface.uv1_world_triplanar = true
			surface.uv1_scale = Vector3.ONE * (1.1 if key=="wood" else 0.9)
		elif key == "glass":
			surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			surface.albedo_color = Color(0.72,0.86,0.91,0.17)
			surface.metallic = 0.48
			surface.roughness = 0.12
		match key:
			"block","wood","glass","brick","tile","road","paving","steel","window","luminous":
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
		mesh.material = surface
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
		if key == "glass": node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
	pieces.clear()
