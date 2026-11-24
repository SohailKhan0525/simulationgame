class_name DriveWorld
extends Node3D
## A deterministic fictional region: 28 x 28 km. One metre per world unit.
## Nearby geometry is generated incrementally; distant districts remain virtual.
const TILE := 160.0
const LIMIT := 14000.0
const ROAD_HALF := 11.0
const TrafficScript = preload("res://scripts/world_traffic.gd")
const STREET_ASSETS := {
	"brick_corner": "res://assets/world/brick_corner.glb",
	"limestone_midrise": "res://assets/world/limestone_midrise.glb",
	"brick_lowrise": "res://assets/world/brick_lowrise.glb",
	"street_plane_tree": "res://assets/world/street_plane_tree.glb"
}
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
var _asset_parts: Dictionary = {}

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
	_materials.sidewalk = ShaderMaterial.new()
	_materials.sidewalk.shader = load("res://scripts/world_paving.gdshader")
	_materials.curb = _material(Color("92928b"),0.95)
	_materials.marking = _material(Color("e6dcb9"),0.85)
	_materials.yellow = _material(Color("eab64c"),0.8)
	_materials.trim = _material(Color("192c34"),0.62,0.25)
	_materials.trunk = _material(Color("5e493c"),1.0)
	_materials.grass = _material(Color("293b20"),1.0)
	_materials.red = _material(Color("f44336"),0.4,0.0,Color("ff1a08"))
	_materials.green = _material(Color("57d6a0"),0.4,0.0,Color("20ff78"))
	_materials.white = _material(Color("f5ead3"),0.5,0.0,Color("fce2a3")*0.3)
	_materials.road = ShaderMaterial.new()
	_materials.road.shader = load("res://scripts/world_road.gdshader")
	_materials.building = ShaderMaterial.new()
	_materials.building.shader = load("res://scripts/world_building.gdshader")
	_materials.glass = ShaderMaterial.new()
	_materials.glass.shader = load("res://scripts/world_glass.gdshader")
	_materials.leaf = ShaderMaterial.new()
	_materials.leaf.shader = load("res://scripts/world_foliage.gdshader")
	for asset_id in STREET_ASSETS:
		var packed: PackedScene = load(STREET_ASSETS[asset_id])
		var source := packed.instantiate()
		var parts: Array = []
		_collect_asset_meshes(source,Transform3D.IDENTITY,parts)
		_asset_parts[asset_id] = parts
		source.free()
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_sky = ProceduralSkyMaterial.new()
	_sky.sky_top_color = Color("406b8d")
	_sky.sky_curve = 0.18
	_sky.sky_energy_multiplier = 0.6
	_sky.ground_energy_multiplier = 0.3
	_sky.sky_horizon_color = Color("ddc2a1")
	_sky.ground_bottom_color = Color("374551")
	_sky.ground_horizon_color = Color("ddc2a1")
	var sky := Sky.new()
	sky.sky_material = _sky
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("b6c4ce")
	_environment.ambient_light_energy = 0.30
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.fog_enabled = true
	_environment.fog_density = 0.0012
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

func _collect_asset_meshes(node: Node, parent_transform: Transform3D, parts: Array) -> void:
	var transform := parent_transform
	if node is Node3D: transform = parent_transform * node.transform
	if node is MeshInstance3D and node.mesh:
		parts.append({"mesh":node.mesh,"transform":transform,"material":node.mesh.surface_get_material(0)})
	for child in node.get_children(): _collect_asset_meshes(child,transform,parts)

func _batch_asset(parent: Node3D,asset_id: String,placements: Array[Transform3D]) -> void:
	if placements.is_empty(): return
	var detail_distance: float = [145.0,205.0,285.0][quality]
	for part in _asset_parts[asset_id]:
		var transforms: Array[Transform3D] = []
		for placement in placements: transforms.append(placement * part.transform)
		var override: Material = null
		if part.material and part.material.resource_name.contains("glazing"): override = _materials.glass
		var batch := _multimesh(parent,part.mesh,override,transforms,[])
		batch.name = asset_id
		batch.set_meta("authored_asset",true)
		# Shared imported geometry is instanced once per chunk/material, not per window.
		batch.visibility_range_end = detail_distance
		batch.visibility_range_end_margin = 8.0
	# At distance, complete blocks use a cheap facade mesh; source detail stays nearby.
	# Godot's importer additionally generates mesh LODs for each authored GLB.
	if asset_id == "street_plane_tree": return
	var height := 20.0
	var color := Color("996a50")
	if asset_id == "limestone_midrise":
		height = 33.0
		color = Color("c0b4a0")
	elif asset_id == "brick_lowrise": height = 14.0
	var proxies: Array[Transform3D] = []
	var colors: Array[Color] = []
	for placement in placements:
		proxies.append(placement * _xform(Vector3(0,height*0.5,0),Vector3(24,height,24)))
		colors.append(color)
		if asset_id == "limestone_midrise":
			proxies.append(placement * _xform(Vector3(0,height+3,0),Vector3(16,6,17)))
			colors.append(color)
	var distant := _multimesh(parent,_box,_materials.building,proxies,colors)
	distant.name = asset_id+"_distant"
	distant.set_meta("distant_asset",true)
	distant.visibility_range_begin = detail_distance
	distant.visibility_range_begin_margin = 8.0

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
		for chunk in _chunks.values():
			for node in chunk.get_children():
				if node.has_meta("authored_asset"): node.visibility_range_end = [145.0,205.0,285.0][quality]
				if node.has_meta("distant_asset"): node.visibility_range_begin = [145.0,205.0,285.0][quality]
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
	ready_for_drive = _pending.is_empty()

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
	_sun.light_energy = lerpf(0.08,0.82,daylight)*(1.0-wetness*0.55)
	_sun.light_color = Color("ffe7c4").lerp(Color("ffd09b"),sunset*0.5).lerp(Color("c6d5df"),wetness)
	_environment.ambient_light_energy = lerpf(0.18,0.32,daylight)
	_environment.fog_density = lerpf(0.0014,0.0045,wetness)
	if quality == 0: _environment.fog_density = maxf(_environment.fog_density,0.0065)
	_environment.fog_light_color = Color("3c5366").lerp(Color("8d9ba4"),daylight)
	_sky.sky_top_color = Color("101e34").lerp(Color("3e7298"),daylight).lerp(Color("73828b"),wetness*0.8)
	_sky.sky_horizon_color = Color("273b50").lerp(Color("a7b9c5"),daylight).lerp(Color("9ba7aa"),wetness)
	_sky.ground_horizon_color = _sky.sky_horizon_color
	_materials.road.set_shader_parameter("wetness",wetness)
	_materials.building.set_shader_parameter("night_amount",1.0-daylight*0.8)
	_materials.glass.set_shader_parameter("night_amount",1.0-daylight)
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
		# Junctions stay open: double-yellow lines stop before the crossing.
		for end in [-1,1]:
			center_transforms.append(_xform(Vector3(s*0.16,0.03,end*49.0),Vector3(0.1,0.012,62)))
			center_transforms.append(_xform(Vector3(end*49.0,0.031,s*0.16),Vector3(62,0.012,0.1)))
		stripe_transforms.append(_xform(Vector3(s*5.6,0.033,s*18.2),Vector3(10.2,0.012,0.42)))
		stripe_transforms.append(_xform(Vector3(-s*18.2,0.033,s*5.6),Vector3(0.42,0.012,10.2)))
		for d in range(-9,10,3):
			stripe_transforms.append(_xform(Vector3(d,0.034,s*14),Vector3(1.5,0.02,4)))
			stripe_transforms.append(_xform(Vector3(s*14,0.035,d),Vector3(4,0.02,1.5)))
	_multimesh(root,_box,_materials.marking,stripe_transforms,[])
	_multimesh(root,_box,_materials.yellow,center_transforms,[])
	var brick_blocks: Array[Transform3D] = []
	var stone_blocks: Array[Transform3D] = []
	var low_blocks: Array[Transform3D] = []
	var trees: Array[Transform3D] = []
	var curb_transforms: Array[Transform3D] = []
	var street_details: Array[Transform3D] = []
	var sidewalk_transforms: Array[Transform3D] = []
	var is_station := posmod(key.x,4)==0 and posmod(key.y,4)==0
	var district := district_at(root.position)
	for sx in [-1,1]:
		for sz in [-1,1]:
			var lot := Vector3(sx*47,0,sz*47)
			sidewalk_transforms.append(_xform(lot+Vector3(0,0.085,0),Vector3(66,0.17,66)))
			# Raised continuous curb and pedestrian pavement along each block face.
			curb_transforms.append(_xform(Vector3(sx*13.5,0.13,sz*47),Vector3(0.45,0.26,66)))
			curb_transforms.append(_xform(Vector3(sx*47,0.13,sz*13.5),Vector3(66,0.26,0.45)))
			# Drainage grates sit in the gutter, aligned with the real curb.
			for d in [25,70]:
				for grate in range(6):
					street_details.append(_xform(Vector3(sx*12.8,0.025,sz*d+grate*0.075),Vector3(0.7,0.015,0.035)))
					street_details.append(_xform(Vector3(sx*d+grate*0.075,0.025,sz*12.8),Vector3(0.035,0.015,0.7)))
			if is_station and sx==1 and sz==1:
				_station(root,ground)
				continue
			var park := district.contains("FOREST") or district.contains("PARK") or rng.randf()<0.07
			if park:
				_mesh_box(root,lot+Vector3(0,0.17,0),Vector3(58,0.1,58),_materials.grass)
				# A through path and perimeter planting make parks readable from the car.
				sidewalk_transforms.append(_xform(lot+Vector3(0,0.24,0),Vector3(3,0.08,60)))
				sidewalk_transforms.append(_xform(lot+Vector3(0,0.24,0),Vector3(60,0.08,3)))
				for t in range(9 if quality>0 else 5):
					var p := lot+Vector3(rng.randf_range(-25,25),0,rng.randf_range(-25,25))
					if absf(p.x-lot.x)<3: p.x += 5
					if absf(p.z-lot.z)<3: p.z += 5
					_add_authored_tree(p,rng,trees)
				continue
			var low_district := district.contains("VILLAGE") or district.contains("HEIGHTS")
			# Buildings line the street, rather than floating alone in large empty lots.
			var positions := [Vector3(sx*32,0,sz*32),Vector3(sx*64,0,sz*32),Vector3(sx*32,0,sz*64)]
			if low_district: positions = [Vector3(sx*34,0,sz*34),Vector3(sx*63,0,sz*63)]
			for j in range(positions.size()):
				var bp: Vector3 = positions[j]
				var height_scale := rng.randf_range(0.93,1.08)
				var height := 20.0
				var placement := Transform3D(Basis(Vector3.UP,float(rng.randi_range(0,3))*PI*0.5).scaled(Vector3(1,height_scale,1)),bp+Vector3(0,0.18,0))
				if low_district:
					low_blocks.append(placement)
					height = 14
				elif district.contains("MIDTOWN") and ((key.x+key.y+j)%3==0):
					stone_blocks.append(placement)
					height = 39
				else:
					brick_blocks.append(placement)
				_collision_box(ground,bp+Vector3(0,height*height_scale*0.5+0.18,0),Vector3(24,height*height_scale,24))
			# Small planted street trees frame the view without hiding junction sightlines.
			for t in [29,58]:
				_add_authored_tree(Vector3(sx*16.1,0,sz*t),rng,trees)
				_add_authored_tree(Vector3(sx*t,0,sz*16.1),rng,trees)
	_multimesh(root,_box,_materials.sidewalk,sidewalk_transforms,[])
	_multimesh(root,_box,_materials.curb,curb_transforms,[])
	_multimesh(root,_box,_materials.trim,street_details,[])
	_batch_asset(root,"brick_corner",brick_blocks)
	_batch_asset(root,"limestone_midrise",stone_blocks)
	_batch_asset(root,"brick_lowrise",low_blocks)
	_batch_asset(root,"street_plane_tree",trees)
	_street_furniture(root)
	if absf(root.position.x)>LIMIT-TILE or absf(root.position.z)>LIMIT-TILE:
		_build_boundary(root,ground)
	return root

func _add_authored_tree(p: Vector3,rng: RandomNumberGenerator,trees: Array[Transform3D]) -> void:
	var scale_tree := rng.randf_range(0.78,1.14)
	trees.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale_tree),p+Vector3(0,0.18,0)))

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
	# Restrained signs at a single corner make streets recognizable through the glass.
	_mesh_box(root,Vector3(-12.75,4.75,-12.75),Vector3(3.6,0.58,0.12),_materials.trim)
	var street_number := 40+roundi(root.position.z/TILE)
	var street_name := _label(root,"W %d ST" % absi(street_number),Vector3(-12.75,4.75,-12.83),0.012)
	street_name.modulate = Color("f0eee5")
	street_name.rotation.y = PI
	# Cast iron bollards and tree guards have scale cues close to the cockpit.
	var bollards: Array[Transform3D] = []
	for sx in [-1,1]:
		for sz in [-1,1]:
			for d in [18,76]:
				bollards.append(_xform(Vector3(sx*14.5,0.65,sz*d),Vector3(0.16,1.0,0.16)))
	_multimesh(root,_cylinder,_materials.trim,bollards,[])
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
