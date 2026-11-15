class_name HarborRoad
extends Node3D

const HALF_STREET := 61.0
const TURN := 2.2
const STRAIGHT := HALF_STREET*2
const ARC := PI*TURN
const LAP := 2*(STRAIGHT+ARC)
var estate := HarborEstate.new()
var traffic: Array[HarborEstate] = []
var progress := PackedFloat32Array([46.0,102.0,175.0,239.0])
var camera := Camera3D.new()
var aboard := false
var inputs := Vector2.ZERO
var active := false
var night := 0.0

func _ready() -> void:
	add_child(estate)
	estate.equip_headlights()
	park(Market.PARK)
	camera.fov = 66
	camera.near = 0.12
	add_child(camera)
	for color in ["984d42","b9aa82","506779","758675"]:
		var car := HarborEstate.new()
		car.paint = Color(color)
		add_child(car)
		var at := progress[traffic.size()]
		car.transform = lane(at)
		traffic.append(car)

func lane(offset: float) -> Transform3D:
	var s := fposmod(offset,LAP)
	var x: float
	var z: float
	var heading: float
	if s < STRAIGHT:
		x = -HALF_STREET+s
		z = TURN
		heading = 0.0
	elif s < STRAIGHT+ARC:
		heading = (s-STRAIGHT)/TURN
		x = HALF_STREET + TURN*sin(heading)
		z = TURN*cos(heading)
	elif s < 2*STRAIGHT+ARC:
		heading = PI
		x = HALF_STREET-(s-STRAIGHT-ARC)
		z = -TURN
	else:
		heading = PI+(s-2*STRAIGHT-ARC)/TURN
		x = -HALF_STREET + TURN*sin(heading)
		z = TURN*cos(heading)
	return Transform3D(Basis(Vector3.UP,heading), Vector3(x,0.045,z+12.8))

func clear_spawns(walker: Vector3) -> void:
	for i in traffic.size():
		var car := traffic[i]
		for attempt in 24:
			var clear := car.position.distance_to(estate.position)>5.4 and car.position.distance_to(walker)>3.2
			for other in traffic:
				if other != car and car.position.distance_to(other.position)<5.4: clear = false
			if clear: break
			progress[i] = fposmod(progress[i]+7.0,LAP)
			car.transform = lane(progress[i])
		car.speed = 0

func park(pose: Array) -> void:
	estate.position = Vector3(pose[0],0.045,pose[1])
	estate.rotation.y = pose[2]
	estate.speed = 0
	estate.steering = 0
	inputs = Vector2.ZERO

func pose() -> Array:
	return [estate.position.x,estate.position.z,estate.rotation.y]

func update_camera(blend: float) -> void:
	var nose := estate.transform.basis.x
	var focus := estate.position + Vector3.UP*1.15
	var end := focus - nose*5.9 + Vector3.UP*2.0
	var ray := PhysicsRayQueryParameters3D.create(focus,end,1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty(): end = hit.position + hit.normal*0.25
	camera.position = camera.position.lerp(end,blend)
	camera.look_at(focus+nose*1.85)

func exit_point() -> Variant:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.72
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 5
	for local in [Vector3(0.2,0,-1.65),Vector3(0.2,0,1.65),Vector3(-2.9,0,0)]:
		var spot := estate.to_global(local)
		query.transform.origin = spot + Vector3.UP*0.9
		if get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return spot
	return null

func set_lighting(amount: float) -> void:
	night = amount
	estate.lighting(night,aboard)
	for car in traffic: car.lighting(night)

func _physics_process(dt: float) -> void:
	if not active: return
	if aboard:
		var steer := Input.get_axis("ui_left","ui_right") + float(Input.is_key_pressed(KEY_D))-float(Input.is_key_pressed(KEY_A))
		var pedal := Input.get_axis("ui_down","ui_up") + float(Input.is_key_pressed(KEY_W))-float(Input.is_key_pressed(KEY_S))
		estate.drive(dt,(inputs+Vector2(steer,pedal)).clamp(Vector2(-1,-1),Vector2.ONE))
		update_camera(1.0-exp(-8*dt))
	for i in traffic.size():
		var car := traffic[i]
		var forward := car.transform.basis.x
		var gap := 0.8+car.speed*0.75
		var blocked := car.test_move(car.transform,forward*gap)
		var cruise := 4.3 + 0.45*i
		var arc_offset := fposmod(progress[i],STRAIGHT+ARC)
		if arc_offset > STRAIGHT-3: cruise = 2.25
		car.speed = move_toward(car.speed,0.0 if blocked else cruise,dt*(9.5 if blocked else 2.6))
		var advance := dt*car.speed
		var next := lane(progress[i]+advance)
		if car.test_move(car.transform,next.origin-car.position):
			car.speed = 0
			continue
		car.steering = 0.44 if arc_offset > STRAIGHT else 0.0
		car.transform = next
		progress[i] = fposmod(progress[i]+advance,LAP)
		car.roll(advance)
