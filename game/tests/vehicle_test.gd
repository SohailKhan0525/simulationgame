extends SceneTree
## Run: godot --headless --path game --script res://tests/vehicle_test.gd --fixed-fps 60
## Fixed-fps runs quickly with a genuine 1/60 physics step. Do not use time-scale.
const Vehicle = preload("res://scripts/vehicle.gd")
var car: RigidBody3D
var tick: int = 0
var brake_speed: float = 0.0
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10000, 1, 10000)
	shape.shape = box
	floor.add_child(shape)
	floor.position.y = -0.5
	scene.add_child(floor)
	car = Vehicle.new()
	car.position = Vector3(0, 0.8, 0)
	scene.add_child(car)
	car.enabled = true
	car.volume = 0.0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _physics_process(_delta: float) -> bool:
	tick += 1
	if tick == 120:
		check(car.position.y > 0.3 and car.position.y < 0.6, "Suspension must settle above the road")
		check(car.linear_velocity.length() < 0.5, "Idle must remain stable")
		car.throttle = 1.0
	if tick == 720:
		print("Acceleration speed: %.1f km/h" % car.speed_kmh)
		brake_speed = car.speed_kmh
		check(car.position.z < -50.0, "Forward input must drive along -Z")
		check(car.fuel_liters < 42.0, "Driving must consume fuel")
		check(car.rpm > 1000.0, "Engine RPM should respond to driving")
		car.throttle = 0.0
		car.brake = 1.0
	if tick == 900:
		print("After braking: %.3f km/h" % car.speed_kmh)
		check(car.speed_kmh < 1.0, "Three seconds of braking must stop the starter car")
		check(brake_speed > 50.0, "Throttle should accelerate the starter car")
		car.brake = 0.0
		car.throttle = -1.0
	if tick == 1140:
		check(car.linear_velocity.z > 1.0, "Reverse should move along +Z")
		check(car.gear == -1, "Reverse gear indicator must follow reversing")
		car.reset_to(Vector3(0, 0.8, 0), 0.0)
		car.throttle = 1.0
		car.steer = 0.4
	if tick == 1620:
		check(car.position.x > 1.0, "Positive steering must turn right")
		check(car.global_basis.y.dot(Vector3.UP) > 0.7, "Cornering must keep the car upright")
		check(car.position.is_finite() and car.linear_velocity.is_finite(), "Physics must remain finite")
		car.reset_to(Vector3(25, 0.8, 30), PI * 0.5)
		car.throttle = 0.0
		car.brake = 1.0
		car.steer = 0.0
	if tick == 1740:
		check(car.position.distance_to(Vector3(25, 0.42, 30)) < 1.0, "Recovery must reset location and clear velocity")
		car.set_passenger(true, "cop")
		check(car.get_node("HandcraftedCockpit/Passenger").visible, "Passenger must appear in the cabin")
		car.configure(2, 5)
		check(car.car_index == 2 and car.upgrade_level == 5, "Garage configuration must reach the vehicle")
		print("Vehicle regression: %d/%d checks passed" % [checks - failures, checks])
		quit(1 if failures > 0 else 0)
	return false
