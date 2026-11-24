extends Node3D
## Lightweight lane-following traffic. All cars remain in the loaded road network.
var world: Node3D
var player: Node3D
var car_count := 18
var _cars: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _mesh: BoxMesh
var _dark: StandardMaterial3D
var _glass: StandardMaterial3D
var _lamp: StandardMaterial3D
var _tail: StandardMaterial3D
var _ready_to_run := false
var _geometry_cache: Dictionary = {}

func _ready() -> void:
	_rng.seed = 1127
	_mesh = BoxMesh.new()
	_mesh.size = Vector3.ONE
	_dark = _mat(Color("192c32"),0.8)
	_glass = _mat(Color("486372"),0.15)
	_lamp = _mat(Color("f8e3b0"),0.3)
	_lamp.emission_enabled = true
	_lamp.emission = Color("e9d8ab")
	_tail = _mat(Color("c3382a"),0.4)
	_tail.emission_enabled = true
	_tail.emission = Color("a92217")
	_ready_to_run = true

func _mat(color: Color,rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m

func _box(parent: Node3D,p: Vector3,size: Vector3,mat: Material) -> void:
	var m := MeshInstance3D.new()
	m.mesh = _mesh
	m.material_override = mat
	m.position = p
	m.scale = size
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)

func _make_car(index: int) -> Dictionary:
	var body := AnimatableBody3D.new()
	body.name = "Traffic_%02d" % index
	body.collision_layer = 4
	body.collision_mask = 1
	body.sync_to_physics = false
	var paint := _mat([Color("6e8a91"),Color("bb8c46"),Color("b6b2a7"),Color("426b67"),Color("784f54")][index%5],0.26)
	paint.metallic = 0.5
	if index==99: paint.albedo_color = Color("e9a136")
	_box(body,Vector3(0,0.65,0),Vector3(1.85,0.7,4.1),paint)
	_box(body,Vector3(0,1.15,0.05),Vector3(1.65,0.65,2.3),_glass)
	_box(body,Vector3(0,1.5,0.1),Vector3(1.7,0.13,2.2),paint)
	for x in [-0.72,0.72]:
		_box(body,Vector3(x,0.72,-2.08),Vector3(0.45,0.2,0.06),_lamp)
		_box(body,Vector3(x,0.72,2.08),Vector3(0.45,0.2,0.06),_tail)
	for x in [-0.91,0.91]:
		for z in [-1.3,1.3]:
			_box(body,Vector3(x,0.35,z),Vector3(0.25,0.65,0.65),_dark)
	_merge_visuals(body,paint)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8,1.3,4.0)
	shape.shape = box
	shape.position.y = 0.75
	body.add_child(shape)
	add_child(body)
	var car := {"body":body,"direction":Vector3.FORWARD,"speed":0.0,"desired":_rng.randf_range(9,16)}
	_respawn(car,index)
	return car

func _respawn(car: Dictionary,index: int) -> void:
	var origin := player.global_position if is_instance_valid(player) else Vector3.ZERO
	var north_south := index%2==0
	var sign_value := -1.0 if index%4<2 else 1.0
	var direction := Vector3(0,0,sign_value) if north_south else Vector3(sign_value,0,0)
	var x := roundf(origin.x/160.0)*160.0
	var z := roundf(origin.z/160.0)*160.0
	if north_south:
		x += float((index/4)%3-1)*160.0 - sign_value*5.0
		z += _rng.randf_range(100,300)*(-sign_value)
	else:
		z += float((index/4)%3-1)*160.0 + sign_value*5.0
		x += _rng.randf_range(100,300)*(-sign_value)
	var body: AnimatableBody3D = car.body
	body.position = Vector3(x,0,z)
	body.rotation.y = atan2(-direction.x,-direction.z)
	car.direction = direction
	car.speed = car.desired

func _physics_process(delta: float) -> void:
	if not _ready_to_run or not is_instance_valid(player) or not world.get("ready_for_drive"): return
	_drive_rival(delta)
	while _cars.size()<car_count: _cars.append(_make_car(_cars.size()))
	while _cars.size()>car_count:
		var removed: Dictionary = _cars.pop_back()
		removed.body.queue_free()
	for i in _cars.size():
		var car := _cars[i]
		var body: AnimatableBody3D = car.body
		var direction: Vector3 = car.direction
		if body.position.distance_to(player.global_position)>440:
			_respawn(car,i)
			continue
		var desired: float = car.desired
		var coordinate := body.position.z if absf(direction.z)>0.5 else body.position.x
		var travel_sign := direction.z if absf(direction.z)>0.5 else direction.x
		var forward_intersection := (floorf(coordinate/160.0)+1)*160.0 if travel_sign>0 else (ceilf(coordinate/160.0)-1)*160.0
		var remaining := absf(coordinate-forward_intersection)
		if remaining>15 and remaining<43 and world.call("is_red",body.position,direction):
			desired = minf(desired,maxf(0,remaining-19)*0.8)
		var ahead_player := player.global_position-body.position
		var forward := ahead_player.dot(direction)
		var lateral := (ahead_player-direction*forward).length()
		if forward>0 and forward<20 and lateral<2.6:
			desired = minf(desired,maxf(0,forward-6)*0.6)
		for other in _cars:
			if other==car: continue
			var delta_p: Vector3 = other.body.position-body.position
			var ahead := delta_p.dot(direction)
			if ahead>0 and ahead<20 and (delta_p-direction*ahead).length()<2.7:
				desired = minf(desired,maxf(0,ahead-7)*0.7)
		car.speed = move_toward(float(car.speed),desired,delta*(7 if desired<float(car.speed) else 2.5))
		body.position += direction*float(car.speed)*delta

var rival_finished := false
var rival_progress := 0.0
var _rival: Dictionary = {}
var _race_points: Array[Vector3] = []
var _race_index := 0
var _race_total := 1.0
var _race_distance := 0.0

func start_race(checkpoints: Array,start_position: Vector3) -> void:
	stop_race()
	for point in checkpoints:
		if point is Vector3:
			_race_points.append(Vector3(point.x,0,point.z))
		elif point is Array and point.size()>=3:
			_race_points.append(Vector3(float(point[0]),0,float(point[2])))
	if _race_points.is_empty(): return
	_rival = _make_car(99)
	var start := Vector3(start_position.x,0,start_position.z)
	var direction := (_race_points[0]-start).normalized()
	var side := direction.cross(Vector3.UP)*4.2
	_rival.body.position = start+side
	_rival.body.rotation.y = atan2(-direction.x,-direction.z)
	_rival.speed = 0.0
	_rival.direction = direction
	_rival.body.name = "RaceRival"
	var label := Label3D.new()
	label.text = "RIVAL"
	label.position = Vector3(0,2.8,0)
	label.font_size = 32
	label.pixel_size = 0.025
	label.modulate = Color("ffce66")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_rival.body.add_child(label)
	var last: Vector3 = _rival.body.position
	_race_total = 0
	for point in _race_points:
		_race_total += point.distance_to(last)
		last = point
	_race_total = maxf(1,_race_total)

func stop_race() -> void:
	if not _rival.is_empty() and is_instance_valid(_rival.get("body")):
		_rival.body.queue_free()
	_rival = {}
	_race_points.clear()
	_race_index = 0
	_race_distance = 0
	rival_finished = false
	rival_progress = 0

func _drive_rival(delta: float) -> void:
	if _rival.is_empty() or rival_finished: return
	var body: AnimatableBody3D = _rival.body
	var target: Vector3 = _race_points[_race_index]
	var to_target := target-body.position
	to_target.y = 0
	if to_target.length()<5:
		_race_index += 1
		if _race_index>=_race_points.size():
			rival_finished = true
			rival_progress = 1
			_rival.speed = 0
			return
		target = _race_points[_race_index]
		to_target = target-body.position
		to_target.y = 0
	var direction := to_target.normalized()
	var desired := 14.5
	if to_target.length()<25: desired = 8.0
	var ahead_player := player.global_position-body.position
	ahead_player.y = 0
	var forward := ahead_player.dot(direction)
	if forward>0 and forward<14 and (ahead_player-direction*forward).length()<2.1:
		desired = minf(desired,maxf(0,forward-5)*0.9)
	for traffic_car in _cars:
		var delta_p: Vector3 = traffic_car.body.position-body.position
		var ahead := delta_p.dot(direction)
		if ahead>0 and ahead<16 and (delta_p-direction*ahead).length()<2.2:
			desired = minf(desired,maxf(0,ahead-5.5)*0.9)
	_rival.speed = move_toward(float(_rival.speed),desired,delta*3.2)
	var movement := direction*float(_rival.speed)*delta
	body.position += movement
	body.rotation.y = lerp_angle(body.rotation.y,atan2(-direction.x,-direction.z),minf(1,delta*5.0))
	_race_distance += movement.length()
	rival_progress = clampf(_race_distance/_race_total,0,0.999)

func _merge_visuals(body: Node3D,paint: Material) -> void:
	# Five cached material batches per car, instead of twelve individual boxes.
	var materials: Array[Material] = [paint,_glass,_dark,_lamp,_tail]
	var groups: Dictionary = {}
	for child in body.get_children():
		if not child is MeshInstance3D: continue
		var role := materials.find(child.material_override)
		if not groups.has(role): groups[role] = []
		groups[role].append(child)
	for role in groups:
		if not _geometry_cache.has(role):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			for child in groups[role]: surface.append_from(child.mesh,0,child.transform)
			_geometry_cache[role] = surface.commit()
		for child in groups[role]:
			body.remove_child(child)
			child.free()
		var merged := MeshInstance3D.new()
		merged.mesh = _geometry_cache[role]
		merged.material_override = materials[role]
		merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(merged)
