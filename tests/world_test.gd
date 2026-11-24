extends SceneTree
## Run: godot --headless --path game --script ../tests/world_test.gd
var world
var driver: Node3D
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool,message: String) -> void:
	checks += 1
	if not condition:
		push_error("WORLD TEST FAILED: "+message)
		quit(1)
		assert(condition,message)

func _settle(frames: int = 60) -> void:
	for frame in range(frames): await process_frame

func _run() -> void:
	world = load("res://scripts/world.gd").new()
	root.add_child(world)
	driver = Node3D.new()
	root.add_child(driver)
	driver.position = Vector3(5,1,20)
	world.set_player(driver)
	_check(world.get_load_progress()<1,"initial loading reports unfinished chunks")
	await _settle()
	_check(world.ready_for_drive,"initial region becomes driveable")
	_check(world._chunks.size()==25,"medium quality limits region to 25 chunks")
	_check(is_equal_approx(world.get_load_progress(),1),"real chunk progress completes")
	_check(world.nearest_station(driver.position)==Vector3(5,0,45),"start station is present at documented stop")
	_check(world.district_at(Vector3.ZERO).contains("MIDTOWN"),"origin is city")
	_check(world.district_at(Vector3(-5000,0,0)).contains("FOREST"),"west includes forest")
	_check(world.district_at(Vector3(0,0,8000)).contains("VILLAGE"),"south includes village")
	var first_chunk: Node3D = world._chunks[Vector2i.ZERO]
	var bodies := first_chunk.find_children("*","StaticBody3D",true,false)
	_check(not bodies.is_empty(),"terrain/building collision body exists")
	_check(bodies[0].get_child_count()>3,"collision body contains terrain and buildings")
	_check(bodies[0].collision_layer==1,"road surface layer is stable for wheel casts")
	var old_id: int = first_chunk.get_instance_id()
	driver.position=Vector3(1280,1,640)
	world._queue_chunks(Vector2i(8,4))
	await _settle()
	_check(world.ready_for_drive,"travel region becomes ready")
	_check(world._chunks.size()==25,"travel keeps bounded tile count")
	_check(not is_instance_id_valid(old_id),"departed chunk is freed")
	world.set_quality(2)
	await _settle()
	_check(world._chunks.size()==49,"high quality caps at 49 chunks")
	world.set_quality(0)
	await _settle()
	_check(world._chunks.size()==9,"low quality limits region to nine chunks")
	world.set_weather(0.9,23)
	_check(world._rain.emitting,"rain activates particles")
	_check(world._materials.road.get_shader_parameter("wetness")>0.8,"weather updates road material")
	_check(world.is_red(Vector3.ZERO,Vector3.FORWARD)!=world.is_red(Vector3.ZERO,Vector3.RIGHT),"crossing signals have opposite phases")
	# The physical rival must move through actual checkpoints and finish by position.
	world._traffic.car_count=0
	world.start_race([[1285,0,600],[1445,0,600]],Vector3(1285,0,645))
	_check(not world._traffic._rival.is_empty(),"race spawns a physical rival")
	var rival_body: Node3D = world._traffic._rival.body
	_check(rival_body is AnimatableBody3D,"rival participates in physics")
	_check(rival_body.collision_layer==4,"rival uses traffic collision layer")
	driver.position=Vector3(1100,1,800)
	for step in range(2400): world._traffic._drive_rival(1.0/60.0)
	_check(world._traffic.rival_finished,"rival reaches finish")
	_check(is_equal_approx(world._traffic.rival_progress,1),"rival progress reaches 100 percent")
	world.stop_race()
	await process_frame
	_check(world._traffic._rival.is_empty(),"stopping a race removes opponent")
	driver.position=Vector3(13980,1,0)
	world._queue_chunks(Vector2i(87,0))
	await _settle()
	_check(world._chunks.size()<=9,"edge streaming remains bounded")
	var edge_chunk: Node3D = world._chunks[Vector2i(87,0)]
	var edge_bodies := edge_chunk.find_children("*","StaticBody3D",true,false)
	var wall_found := false
	for shape in edge_bodies[0].get_children():
		if shape is CollisionShape3D and is_equal_approx(shape.shape.size.x,1.0) and is_equal_approx(shape.shape.size.y,3.0): wall_found=true
	_check(wall_found,"locked expansion boundary is a physical wall")
	print("WORLD TEST PASS: %d checks; chunk unloading, geometry collision, weather, traffic signals, rival route, world edge" % checks)
	quit(0)
