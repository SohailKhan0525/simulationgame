extends SceneTree
## Headless behavior regression; GPU reflection quality and phone frame rate need
## rendered/device checks. Run with --fixed-fps60, never --time-scale.
const Vehicle = preload("res://scripts/vehicle.gd")
var car: RigidBody3D
var other_car: RigidBody3D
var scene: Node3D
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func frames(count: int) -> void:
	for _i in range(count): await process_frame

func run() -> void:
	scene = Node3D.new()
	root.add_child(scene)
	var floor := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(5000, 1, 5000)
	collision.shape = shape
	floor.add_child(collision)
	floor.position.y = -0.5
	scene.add_child(floor)
	car = Vehicle.new()
	car.position = Vector3(0, 0.8, 0)
	scene.add_child(car)
	car.enabled = true
	car.volume = 0.0
	car.set_camera_mode(1)
	other_car = Vehicle.new()
	other_car.position = Vector3(25, 0.8, 0)
	scene.add_child(other_car)
	other_car.volume = 0.0
	other_car.freeze = true
	await frames(120)
	check(car.chase_camera.current and car.get_active_camera() == car.chase_camera, "Selecting chase mode must activate its camera")
	check(is_equal_approx(car.chase_camera.fov, 65.0), "Stationary chase view must default to65 degrees")
	check(car.reflection_probe.update_mode == ReflectionProbe.UPDATE_ALWAYS, "Driving must update the player's live reflection probe")
	check(other_car.reflection_probe.update_mode == ReflectionProbe.UPDATE_ONCE, "An inactive vehicle must not continuously render another probe")
	check(car.reflection_probe.cull_mask & car.reflection_probe.reflection_mask == 0, "The car must be excluded from its own reflection capture")
	check(car.reflection_probe.reflection_mask == 2 and car.reflection_probe.cull_mask == 1, "The probe must affect player geometry while capturing the world")
	car.set_visual_quality(0)
	check(car._effects.smoke[0].amount == 16 and car.reflection_probe.max_distance == 65.0, "Low quality must bound particles and reflection capture distance")
	car.set_visual_quality(2)
	check(car._effects.smoke[0].amount == 36 and car.reflection_probe.max_distance == 120.0, "High quality must use its configured effect budget")
	car.set_camera_far(240.0)
	check(car.cockpit_camera.far == 240.0 and car.chase_camera.far == 240.0, "Visibility range must apply to both camera choices")
	car.freeze = true
	for sample_speed in [0.0, 80.0, 160.0, 0.0]:
		car.speed_kmh = sample_speed
		await frames(120)
		print("FOV sample %.0fkm/h: %.3f degrees" % [sample_speed, car.chase_camera.fov])
		var expected: float = 73.5 if sample_speed == 80.0 else (82.0 if sample_speed == 160.0 else 65.0)
		check(absf(car.chase_camera.fov - expected) < 0.05, "Speed FOV must settle to %.1f degrees at %.0fkm/h" % [expected, sample_speed])
		check(absf(car.cockpit_camera.fov - car.chase_camera.fov) < 0.001, "Switching views must preserve the same speed FOV")
	car.set_camera_mode(0)
	check(car.cockpit_camera.current and not car.chase_camera.current, "Cockpit selection must remain available")
	car.set_camera_mode(1)
	car.rotation = Vector3.ZERO
	car.linear_velocity = Vector3.ZERO
	car._camera_rig.snap()
	var initial_camera: Vector3 = car.chase_camera.global_position
	car.rotation.y = PI / 4.0
	await frames(6)
	check(car.chase_camera.global_position.x > initial_camera.x + 0.05 and car.chase_camera.global_position.x < car.position.x + 4.0, "Chase camera must ease toward a turn instead of snapping")
	await frames(120)
	car.rotation = Vector3.ZERO
	car._camera_rig.snap()
	car.linear_velocity = Vector3(7, 0, -12)
	await frames(120)
	check(car.chase_camera.global_position.x < car.position.x - 0.5, "Lateral slide velocity must produce a limited drift swing")
	car.rotation.z = 0.35
	await frames(60)
	check(absf(car.chase_camera.global_basis.x.y) < 0.001, "Chase view must keep a stable horizon when the body rolls")
	car.rotation = Vector3.ZERO
	car.linear_velocity = Vector3.ZERO
	car._camera_rig.snap()
	var wall := StaticBody3D.new()
	var wall_collision := CollisionShape3D.new()
	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(8, 5, 0.4)
	wall_collision.shape = wall_shape
	wall.add_child(wall_collision)
	wall.position = Vector3(0, 2.5, 3)
	scene.add_child(wall)
	await frames(10)
	check(car.chase_camera.global_position.z < 2.6 and car.chase_camera.global_position.z > 1.0, "Camera sweep must pull in before a wall behind the car")
	wall.queue_free()
	await frames(120)
	check(car.chase_camera.global_position.z > 6.0, "Camera must ease back out when its obstruction disappears")
	car.reset_to(Vector3(100, 0.8, 100), PI * 0.5)
	check(car.chase_camera.global_position.distance_to(car.position) < 8.0, "Recovery must snap the chase camera to the new location")
	check(car.chase_camera.fov == 65.0, "Recovery must clear speed FOV immediately")
	car.reset_to(Vector3(0, 0.8, 0), 0.0)
	car.freeze = false
	car.brake = 1.0
	other_car.reset_to(Vector3(25, 0.8, 0), 0.0)
	other_car.downforce_coefficient = 0.0
	other_car.enabled = true
	other_car.freeze = false
	other_car.brake = 1.0
	await frames(120)
	car.brake = 0.0
	car.throttle = 0.5
	car.linear_velocity = Vector3(0, 0, -20)
	other_car.brake = 0.0
	other_car.throttle = 0.5
	other_car.linear_velocity = Vector3(0, 0, -20)
	await frames(120)
	print("Aero load: %.1fN; matched suspension no-aero %.4f / aero %.4fm" % [car.downforce_newtons, other_car.position.y, car.position.y])
	check(car.downforce_newtons > 500.0 and car.downforce_newtons <= car.mass * 9.8 * 0.28, "Road speed must produce bounded aerodynamic downforce")
	check(car.position.y < other_car.position.y - 0.002, "Downforce must physically load the suspension compared with an otherwise matched car")
	other_car.enabled = false
	other_car.freeze = true
	car.linear_velocity = Vector3(7, 0, -14)
	car.handbrake = true
	await frames(12)
	var left: CPUParticles3D = car._effects.smoke[0]
	var right: CPUParticles3D = car._effects.smoke[1]
	check(left.emitting or right.emitting, "Sliding grounded rear tires must emit smoke")
	check(not left.local_coords and not right.local_coords, "Smoke must remain in world space as the vehicle moves on")
	check(left.global_position.distance_to(car.rear_contact_points[0]) < 0.2, "Rear smoke must originate at the measured tire contact")
	var lights: Dictionary = car.get_meta("vehicle_art_lights")
	var other_lights: Dictionary = other_car.get_meta("vehicle_art_lights")
	check(not lights.headlamps.is_empty() and not lights.brakelamps.is_empty(), "Authored headlight and brake-light materials must be registered")
	if not lights.brakelamps.is_empty() and not lights.headlamps.is_empty():
		check(lights.brakelamps[0].emission_energy_multiplier > 3.0, "Effective braking must brighten the actual rear-lamp material")
		check(other_lights.brakelamps[0].emission_energy_multiplier < 1.0, "Braking must not alter another vehicle's light material")
		car.headlights_on = false
		await frames(3)
		check(lights.headlamps[0].emission_energy_multiplier < 0.1 and not car._headlights[0].visible, "Headlights toggle must affect emissive lenses and road lights together")
	car.enabled = false
	check(not left.emitting and not right.emitting and car.downforce_newtons == 0.0, "Pausing must immediately stop smoke and clear active aero state")
	car.enabled = true
	car.handbrake = false
	car.throttle = 0.0
	car.reset_to(Vector3(0, 7, 0))
	await frames(2)
	car.linear_velocity = Vector3(0, 0, -25)
	await frames(5)
	check(car.grounded_wheels == 0 and car.downforce_newtons == 0.0, "An airborne car must not receive road-holding downforce")
	check(not left.emitting and not right.emitting, "Airborne tires must not create road-contact smoke")
	car.reset_to(Vector3(25, 0.8, 30))
	check(not left.visible and not right.visible, "Recovery must clear the old smoke trail immediately")
	print("Vehicle presentation: %d/%d checks passed; probe UPDATE_ALWAYS capture%d/%dm" % [checks - failures, checks, car.reflection_probe.cull_mask, int(car.reflection_probe.max_distance)])
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
