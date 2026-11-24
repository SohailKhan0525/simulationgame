class_name DriveWorld
extends Node3D
## A deterministic fictional region: 28 x 28 km. One metre per world unit.
## Nearby geometry is generated incrementally; distant districts remain virtual.
const TILE := 160.0
const LIMIT := 14000.0
const ROAD_HALF := 11.0
const TrafficScript = preload("res://scripts/world_traffic.gd")
var ready_for_drive := false
var rival_finished := false
var rival_progress := 0.0
var player: Node3D
var quality := 1
var wetness := 0.0
var hour := 17.0
var elapsed := 0.0
var _radius := 2
var _chunks: Dictionary = {}
var _pending: Array[Vector2i] = []
var _center := Vector2i(99999,99999)
var _target_count := 25
var _materials: Dictionary = {}
var _box: BoxMesh
var _cylinder: CylinderMesh
var _sphere: SphereMesh
var _foliage: SphereMesh
var _environment: Environment
var _sky: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _rain: CPUParticles3D
var _traffic: Node3D
var _birds: MultiMeshInstance3D
var _signal_meshes: Array[MultiMeshInstance3D] = []
var _last_light_phase := -1
var _stream_timer := 0.0
var _prepared := false

func _ready() -> void:
	_prepare()
	_queue_chunks(_tile_at(player.global_position) if is_instance_valid(player) and player.is_inside_tree() else Vector2i.ZERO)

func _prepare() -> void:
	if _prepared: return
	_prepared = true
	_box = BoxMesh.new()
	_box.size = Vector3.ONE
	_cylinder = CylinderMesh.new()
	_cylinder.top_radius = 0.5
	_cylinder.bottom_radius = 0.5
	_cylinder.height = 1.0
	_cylinder.radial_segments = 8
	_sphere = SphereMesh.new()
	_sphere.radius = 0.5
	_sphere.height = 1.0
	_sphere.radial_segments = 8
	_sphere.rings = 4
	_foliage = SphereMesh.new()
	_foliage.radius = 0.5
	_foliage.height = 1.0
	_foliage.radial_segments = 8
	_foliage.rings = 4
	_materials.ground = _material(Color("434e41"),0.96)
	_materials.sidewalk = _material(Color("7c807c"),0.96)
	_materials.marking = _material(Color("e6dcb9"),0.85)
	_materials.yellow = _material(Color("eab64c"),0.8)
	_materials.trim = _material(Color("192c34"),0.62,0.25)
	_materials.trunk = _material(Color("5e493c"),1.0)
	_materials.grass = _material(Color("365c46"),1.0)
	_materials.red = _material(Color("f44336"),0.4,0.0,Color("ff1a08"))
	_materials.green = _material(Color("57d6a0"),0.4,0.0,Color("20ff78"))
	_materials.white = _material(Color("f5ead3"),0.5,0.0,Color("fce2a3")*0.3)
	_materials.road = ShaderMaterial.new()
	_materials.road.shader = load("res://scripts/world_road.gdshader")
	_materials.building = ShaderMaterial.new()
	_materials.building.shader = load("res://scripts/world_building.gdshader")
	_materials.leaf = ShaderMaterial.new()
	_materials.leaf.shader = load("res://scripts/world_foliage.gdshader")
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_sky = ProceduralSkyMaterial.new()
	_sky.sky_top_color = Color("406b8d")
	_sky.sky_curve = 0.32
	_sky.sky_energy_multiplier = 0.72
	_sky.ground_energy_multiplier = 0.65
	_sky.sky_horizon_color = Color("ddc2a1")
	_sky.ground_bottom_color = Color("374551")
	_sky.ground_horizon_color = Color("ddc2a1")
	var sky := Sky.new()
	sky.sky_material = _sky
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("8b9fab")
	_environment.ambient_light_energy = 0.35
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.fog_enabled = true
	_environment.fog_density = 0.0019
	_environment.fog_light_color = Color("a5b9c2")
	_environment.fog_sky_affect = 0.22
	var env_node := WorldEnvironment.new()
	env_node.environment = _environment
	add_child(env_node)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-25,-35,0)
	_sun.light_color = Color("ffe0ad")
	_sun.light_energy = 0.9
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 150
	add_child(_sun)
	_rain = CPUParticles3D.new()
	_rain.amount = 500
	_rain.lifetime = 0.7
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(15,10,15)
	_rain.direction = Vector3(-0.2,-1,0)
	_rain.spread = 3.0
	_rain.initial_velocity_min = 22
	_rain.initial_velocity_max = 30
	_rain.gravity = Vector3(0,-10,0)
	var rain_mesh := BoxMesh.new()
	rain_mesh.size = Vector3(0.018,0.55,0.018)
	rain_mesh.material = _material(Color("b9d9e3"),0.2)
	_rain.mesh = rain_mesh
	_rain.emitting = false
	add_child(_rain)
	_traffic = TrafficScript.new()
	_traffic.set("world",self)
	_traffic.set("player",player)
	add_child(_traffic)
	_birds = _multimesh(self,_box,_materials.trim,[],[])
	_birds.multimesh.instance_count = 24
	set_weather(wetness,hour)

func _material(color: Color, roughness: float, metallic: float = 0.0, emission: Color = Color.BLACK) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	mat.vertex_color_use_as_albedo = true
	if emission != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emission
	return mat

func set_player(value: Node3D) -> void:
	player = value
	if is_instance_valid(_traffic): _traffic.set("player",value)
	if is_instance_valid(player) and player.is_inside_tree(): _queue_chunks(_tile_at(player.global_position))

func set_quality(value: int) -> void:
	quality = clampi(value,0,2)
	_radius = quality + 1
	if _prepared:
		_sun.shadow_enabled = quality > 0
		_sun.directional_shadow_max_distance = 180 if quality == 2 else 100
		_rain.amount = [180,400,650][quality]
		set_weather(wetness,hour)
		if is_instance_valid(_traffic): _traffic.set("car_count",[10,18,28][quality])
		_queue_chunks(_tile_at(player.global_position) if is_instance_valid(player) else Vector2i.ZERO)

func get_load_progress() -> float:
	return 1.0 - float(_pending.size()) / float(maxi(1,_target_count))

func _tile_at(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x/TILE),roundi(p.z/TILE))

func _queue_chunks(center: Vector2i) -> void:
	_center = center
	var wanted: Dictionary = {}
	_pending.clear()
	for z in range(-_radius,_radius+1):
		for x in range(-_radius,_radius+1):
			var key := center + Vector2i(x,z)
			if absf(float(key.x)*TILE)>LIMIT+TILE or absf(float(key.y)*TILE)>LIMIT+TILE: continue
			wanted[key] = true
			if not _chunks.has(key): _pending.append(key)
	_pending.sort_custom(func(a: Vector2i,b: Vector2i): return a.distance_squared_to(center)<b.distance_squared_to(center))
	for key in _chunks.keys():
		if not wanted.has(key):
			_chunks[key].queue_free()
			_chunks.erase(key)
	_target_count = wanted.size()

func _process(delta: float) -> void:
	elapsed += delta
	if is_instance_valid(_traffic):
		rival_finished = bool(_traffic.get("rival_finished"))
		rival_progress = float(_traffic.get("rival_progress"))
	if not _pending.is_empty():
		var key: Vector2i = _pending.pop_front()
		_chunks[key] = _make_chunk(key)
	ready_for_drive = _pending.is_empty()
	if not is_instance_valid(player): return
	_stream_timer += delta
	if _stream_timer>0.25:
		_stream_timer = 0.0
		var center := _tile_at(player.global_position)
		if center != _center: _queue_chunks(center)
	_rain.global_position = player.global_position+Vector3(0,11,0)
	for i in range(24):
		var angle := elapsed*0.15+float(i)*0.7
		var p := player.global_position+Vector3(sin(angle)*85,30+sin(angle*1.7)*9,cos(angle)*85)
		var scale_bird := Vector3(1.0+sin(elapsed*8+i)*0.35,0.12,0.3)
		_birds.multimesh.set_instance_transform(i,Transform3D(Basis(Vector3.UP,-angle).scaled(scale_bird),p))
	var phase := int(elapsed/12.0)%2
	if phase != _last_light_phase:
		_last_light_phase = phase
		_update_signals()

func district_at(p: Vector3) -> String:
	var radius := Vector2(p.x,p.z).length()
	if radius < 1500: return "MIDTOWN • NEW YORK REGION"
	if p.x < -4000 and p.z < 3000: return "GREENWOOD FOREST"
	if p.z > 6500: return "HUDSON VILLAGE"
	if p.x > 5000: return "THE HEIGHTS"
	if posmod(int(p.x/800)+int(p.z/800),7)==3: return "RIVERSIDE PARK"
	return "BROOKSIDE"

func road_point(p: Vector3) -> Vector3:
	var x := roundf(p.x/TILE)*TILE
	var z := roundf(p.z/TILE)*TILE
	if absf(p.x-x)<absf(p.z-z): return Vector3(clampf(x+5,-LIMIT+20,LIMIT-20),0,clampf(p.z,-LIMIT+20,LIMIT-20))
	return Vector3(clampf(p.x,-LIMIT+20,LIMIT-20),0,clampf(z+5,-LIMIT+20,LIMIT-20))

func nearest_station(p: Vector3) -> Vector3:
	return Vector3(clampf(roundf((p.x-5)/640.0)*640.0+5,-13435,13445),0,clampf(roundf((p.z-45)/640.0)*640.0+45,-13395,13485))

func is_red(_p: Vector3, direction: Vector3) -> bool:
	var ns_green := int(elapsed/12.0)%2 == 0
	return not ns_green if absf(direction.z)>0.5 else ns_green

func set_weather(rain_amount: float, time_of_day: float) -> void:
	wetness = clampf(rain_amount,0,1)
	hour = fposmod(time_of_day,24.0)
	if not _prepared: return
	var daylight := clampf(sin((hour-6.0)/24.0*TAU)*1.5,0.0,1.0)
	var sunset := 1.0-absf(daylight-0.45)
	_sun.rotation_degrees = Vector3(-maxf(8,sin((hour-6.0)/24.0*TAU)*65),-35,0)
	_sun.light_energy = lerpf(0.12,0.9,daylight)*(1.0-wetness*0.55)
	_sun.light_color = Color("ffe7c4").lerp(Color("ffd09b"),sunset*0.5).lerp(Color("c6d5df"),wetness)
	_environment.ambient_light_energy = lerpf(0.30,0.35,daylight)
	_environment.fog_density = lerpf(0.00095,0.0045,wetness)
	if quality == 0: _environment.fog_density = maxf(_environment.fog_density,0.0065)
	_environment.fog_light_color = Color("3c5366").lerp(Color("899896"),daylight)
	_sky.sky_top_color = Color("101e34").lerp(Color("32566f"),daylight).lerp(Color("52626d"),wetness*0.8)
	_sky.sky_horizon_color = Color("273b50").lerp(Color("bca58e"),daylight).lerp(Color("71828a"),wetness)
	_sky.ground_horizon_color = _sky.sky_horizon_color
	_materials.road.set_shader_parameter("wetness",wetness)
	_materials.building.set_shader_parameter("night_amount",1.0-daylight*0.8)
	_rain.emitting = wetness>0.15

func _make_chunk(key: Vector2i) -> Node3D:
	var root := Node3D.new()
	root.name = "Tile_%d_%d" % [key.x,key.y]
	root.position = Vector3(key.x*TILE,0,key.y*TILE)
	add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("qofeno:%d:%d" % [key.x,key.y])
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	ground.collision_mask = 0
	root.add_child(ground)
	_collision_box(ground,Vector3(0,-0.5,0),Vector3(TILE,1,TILE))
	_mesh_box(root,Vector3(0,-0.1,0),Vector3(TILE,0.2,TILE),_materials.ground)
	var road_transforms: Array[Transform3D] = []
	road_transforms.append(_xform(Vector3(0,0.007,0),Vector3(22,0.02,TILE)))
	road_transforms.append(_xform(Vector3(0,0.008,0),Vector3(TILE,0.02,22)))
	_multimesh(root,_box,_materials.road,road_transforms,[])
	var stripe_transforms: Array[Transform3D] = []
	var center_transforms: Array[Transform3D] = []
	for d in range(-75,80,12):
		if abs(d)<16: continue
		stripe_transforms.append(_xform(Vector3(5.5,0.024,d),Vector3(0.12,0.02,5)))
		stripe_transforms.append(_xform(Vector3(-5.5,0.024,d),Vector3(0.12,0.02,5)))
		stripe_transforms.append(_xform(Vector3(d,0.025,5.5),Vector3(5,0.02,0.12)))
		stripe_transforms.append(_xform(Vector3(d,0.025,-5.5),Vector3(5,0.02,0.12)))
	for s in [-1,1]:
		center_transforms.append(_xform(Vector3(s*0.22,0.03,0),Vector3(0.12,0.02,160)))
		center_transforms.append(_xform(Vector3(0,0.031,s*0.22),Vector3(160,0.02,0.12)))
		for d in range(-9,10,3):
			stripe_transforms.append(_xform(Vector3(d,0.034,s*14),Vector3(1.5,0.02,4)))
			stripe_transforms.append(_xform(Vector3(s*14,0.035,d),Vector3(4,0.02,1.5)))
	_multimesh(root,_box,_materials.marking,stripe_transforms,[])
	_multimesh(root,_box,_materials.yellow,center_transforms,[])
	var buildings: Array[Transform3D] = []
	var colors: Array[Color] = []
	var leaf_transforms: Array[Transform3D] = []
	var leaf_colors: Array[Color] = []
	var trunk_transforms: Array[Transform3D] = []
	var trim_transforms: Array[Transform3D] = []
	var sidewalk_transforms: Array[Transform3D] = []
	var is_station := posmod(key.x,4)==0 and posmod(key.y,4)==0
	var district := district_at(root.position)
	for sx in [-1,1]:
		for sz in [-1,1]:
			var lot := Vector3(sx*47,0,sz*47)
			sidewalk_transforms.append(_xform(lot+Vector3(0,0.08,0),Vector3(68,0.16,68)))
			if is_station and sx==1 and sz==1:
				_station(root,ground)
				continue
			var park := district.contains("FOREST") or district.contains("PARK") or rng.randf()<0.10
			if park:
				_mesh_box(root,lot+Vector3(0,0.17,0),Vector3(62,0.1,62),_materials.grass)
				for t in range(10 if quality>0 else 6):
					var p := lot+Vector3(rng.randf_range(-25,25),0,rng.randf_range(-25,25))
					_add_tree(p,rng,leaf_transforms,leaf_colors,trunk_transforms)
				continue
			var count := 2 if district.contains("VILLAGE") or district.contains("HEIGHTS") else 1
			for j in range(count):
				var bp := lot+Vector3((j-0.5)*30 if count>1 else 0,0,0)
				var height := rng.randf_range(17,36)
				var width := rng.randf_range(30,48)
				var depth := rng.randf_range(32,48)
				var tint := Color("8b7666").lerp(Color("6a8a93"),rng.randf())
				if district.contains("MIDTOWN"):
					height = rng.randf_range(45,142)
					tint = Color("476875").lerp(Color("77888d"),rng.randf())
				elif count>1:
					height = rng.randf_range(5,11)
					width = 22
					depth = 29
					tint = Color("cab89e").lerp(Color("aa8b71"),rng.randf())
				var size := Vector3(width,height,depth)
				buildings.append(_xform(bp+Vector3(0,height*0.5+0.15,0),size))
				colors.append(tint)
				_collision_box(ground,bp+Vector3(0,height*0.5+0.15,0),size)
				trim_transforms.append(_xform(bp+Vector3(0,height+0.4,0),Vector3(width+1.4,0.6,depth+1.4)))
				trim_transforms.append(_xform(bp+Vector3(0,3.8,0),Vector3(width+0.7,0.3,depth+0.7)))
				# Street-front awnings create real silhouette and shade without extra batches.
				for frontage in [-1,1]:
					trim_transforms.append(_xform(bp+Vector3(0,3.45,frontage*(depth*0.5+1.15)),Vector3(width*0.8,0.22,2.4)))
					trim_transforms.append(_xform(bp+Vector3(frontage*(width*0.5+1.15),3.45,0),Vector3(2.4,0.22,depth*0.8)))
				if height>30:
					buildings.append(_xform(bp+Vector3(0,height+4,0),Vector3(width*0.5,8,depth*0.5)))
					colors.append(tint*0.88)
				if rng.randf()<0.4:
					var sign := _label(root,["QOFENO","CAFE  /  24","ATELIER","PARK AVENUE"][rng.randi_range(0,3)],bp+Vector3(0,5.1,-depth*0.5-0.03),0.034)
					sign.modulate = Color("e6d5b7")
			for t in range(3):
				_add_tree(Vector3(sx*15.2,0,sz*(27+t*20)),rng,leaf_transforms,leaf_colors,trunk_transforms)
	_multimesh(root,_box,_materials.sidewalk,sidewalk_transforms,[])
	_multimesh(root,_box,_materials.building,buildings,colors)
	_multimesh(root,_box,_materials.trim,trim_transforms,[])
	_multimesh(root,_foliage,_materials.leaf,leaf_transforms,leaf_colors)
	_multimesh(root,_cylinder,_materials.trunk,trunk_transforms,[])
	_street_furniture(root)
	if absf(root.position.x)>LIMIT-TILE or absf(root.position.z)>LIMIT-TILE:
		_build_boundary(root,ground)
	return root

func _add_tree(p: Vector3,rng: RandomNumberGenerator,leaves: Array[Transform3D],colors: Array[Color],trunks: Array[Transform3D]) -> void:
	var h := rng.randf_range(6,10)
	trunks.append(_xform(p+Vector3(0,h*0.4,0),Vector3(0.5,h*0.8,0.5)))
	leaves.append(_xform(p+Vector3(0,h,0),Vector3(6,h*0.8,6)))
	colors.append(Color("385f49").lerp(Color("799759"),rng.randf()))

func _street_furniture(root: Node3D) -> void:
	var poles: Array[Transform3D] = []
	var lamps: Array[Transform3D] = []
	var signals_ns: Array[Transform3D] = []
	var signals_ew: Array[Transform3D] = []
	for sx in [-1,1]:
		for sz in [-1,1]:
			poles.append(_xform(Vector3(sx*12.6,3.5,sz*12.6),Vector3(0.2,7,0.2)))
			poles.append(_xform(Vector3(sx*10,6.8,sz*12.6),Vector3(5.2,0.15,0.15)))
			lamps.append(_xform(Vector3(sx*7.6,6.65,sz*12.6),Vector3(1.1,0.13,0.6)))
			poles.append(_xform(Vector3(sx*12.3,3.2,sz*12.3),Vector3(0.5,1.1,0.5)))
			signals_ns.append(_xform(Vector3(sx*12.3,3.4,sz*12.63),Vector3(0.24,0.24,0.07)))
			signals_ew.append(_xform(Vector3(sx*12.63,3.4,sz*12.3),Vector3(0.07,0.24,0.24)))
	_multimesh(root,_box,_materials.trim,poles,[])
	_multimesh(root,_box,_materials.white,lamps,[])
	var ns := _multimesh(root,_box,_materials.green,signals_ns,[])
	ns.set_meta("north_south",true)
	var ew := _multimesh(root,_box,_materials.red,signals_ew,[])
	ew.set_meta("north_south",false)
	_signal_meshes.append(ns)
	_signal_meshes.append(ew)
	_update_signals()

func _update_signals() -> void:
	var valid: Array[MultiMeshInstance3D] = []
	for mesh in _signal_meshes:
		if not is_instance_valid(mesh): continue
		valid.append(mesh)
		var green: bool = (int(elapsed/12.0)%2==0) == bool(mesh.get_meta("north_south"))
		mesh.material_override = _materials.green if green else _materials.red
	_signal_meshes = valid

func _station(root: Node3D,body: StaticBody3D) -> void:
	_mesh_box(root,Vector3(37,0.2,46),Vector3(43,0.2,58),_materials.sidewalk)
	_mesh_box(root,Vector3(36,4.5,45),Vector3(43,0.5,46),_materials.trim)
	_mesh_box(root,Vector3(36,4.1,45),Vector3(42,0.15,45),_materials.white)
	for x in [20,51]:
		for z in [27,63]:
			_mesh_box(root,Vector3(x,2.2,z),Vector3(0.4,4.4,0.4),_materials.trim)
			_collision_box(body,Vector3(x,2.2,z),Vector3(0.4,4.4,0.4))
	for z in [35,55]:
		_mesh_box(root,Vector3(18,1,z),Vector3(1.3,2,1),_materials.white)
		_mesh_box(root,Vector3(17.3,1.3,z),Vector3(0.06,0.5,0.65),_materials.trim)
		_collision_box(body,Vector3(18,1,z),Vector3(1.3,2,1))
	var sign := _label(root,"Q / FUEL",Vector3(13,4.9,45),0.05)
	sign.rotation.y = PI/2
	_label(root,"ATTENDANT SERVICE",Vector3(36,4.8,21.7),0.024)
	_mesh_box(root,Vector3(12.8,1.1,45),Vector3(0.5,0.75,0.35),_materials.green)
	var head := MeshInstance3D.new()
	head.mesh = _sphere
	head.position = Vector3(12.8,1.7,45)
	head.scale = Vector3(0.34,0.4,0.34)
	head.material_override = _materials.white
	root.add_child(head)
	for x in [12.65,12.95]:
		_mesh_box(root,Vector3(x,0.4,45),Vector3(0.14,0.8,0.18),_materials.trim)

func _build_boundary(root: Node3D,body: StaticBody3D) -> void:
	for axis in [0,2]:
		for sign_value in [-1,1]:
			var global_edge: float = LIMIT*float(sign_value)
			if absf(root.position[axis]-global_edge)>TILE: continue
			var p := Vector3(0,1.5,0)
			p[axis] = global_edge-root.position[axis]
			var size := Vector3(TILE,3,TILE)
			size[axis] = 1.0
			_mesh_box(root,p,size,_materials.trim)
			_collision_box(body,p,size)
			var label := _label(root,"MORE DISTRICTS\nCOMING SOON",p+Vector3(0,3,0),0.05)
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED

func _xform(p: Vector3,size: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY.scaled(size),p)

func _mesh_box(parent: Node3D,p: Vector3,size: Vector3,mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = _box
	mesh.position = p
	mesh.scale = size
	mesh.material_override = mat
	if mat in [_materials.ground,_materials.sidewalk,_materials.grass,_materials.white]:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh

func _multimesh(parent: Node3D,mesh: Mesh,mat: Material,transforms: Array[Transform3D],colors: Array[Color]) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i,transforms[i])
		if i<colors.size(): mm.set_instance_color(i,colors[i])
	node.multimesh = mm
	node.material_override = mat
	# Flat road markings and luminous lenses never need shadow passes.
	if mat in [_materials.road,_materials.marking,_materials.yellow,_materials.sidewalk,_materials.white,_materials.red,_materials.green]:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

func _collision_box(parent: StaticBody3D,p: Vector3,size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = p
	parent.add_child(shape)

func _label(parent: Node3D,text: String,p: Vector3,pixel_size: float) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = p
	label.font_size = 44
	label.pixel_size = pixel_size
	label.outline_size = 0
	label.no_depth_test = false
	parent.add_child(label)
	return label

func start_race(checkpoints: Array,start_position: Vector3) -> void:
	rival_finished = false
	rival_progress = 0
	if is_instance_valid(_traffic): _traffic.call("start_race",checkpoints,start_position)

func stop_race() -> void:
	rival_finished = false
	rival_progress = 0
	if is_instance_valid(_traffic): _traffic.call("stop_race")
