extends SceneTree
## Physical behavior regression for touchscreen overlap and abrupt inputs.
const Vehicle = preload("res://scripts/vehicle.gd")
var car: RigidBody3D
var tick: int = 0
var checks: int = 0
var failures: int = 0
var forward_speed: float = 0.0

func _initialize() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var floor := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(10000, 1, 10000)
	collision.shape = shape
	floor.add_child(collision)
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
		car.throttle = 1.0
		car.brake = 1.0
	if tick == 240:
		check(car.speed_kmh < 0.25, "Brake must hold the car still when both pedals are pressed")
		car.brake = 0.0
	if tick == 600:
		forward_speed = car.speed_kmh
		check(forward_speed > 35.0, "Car must accelerate after the brake is released")
		car.throttle = -1.0
	if tick == 660:
		check(car.speed_kmh < forward_speed * 0.5, "Selecting reverse while moving must first slow the car")
		check(car.linear_velocity.z < 0.0, "Reverse selection must not instantly reverse travel direction")
	if tick == 900:
		check(car.linear_velocity.z > 1.0, "Holding reverse must drive backward after stopping")
		car.reset_to(Vector3(0, 0.8, 0), 0.0)
		car.throttle = 0.0
		car.brake = 1.0
	if tick == 1020:
		car.linear_velocity = Vector3(0, 0, -30)
		car.brake = 0.0
		car.throttle = 0.5
		car.steer = 1.0
	if tick == 1140:
		check(car.position.x > 2.0, "Full steering at highway speed must still turn the car")
		check(car.global_basis.y.dot(Vector3.UP) > 0.85, "Abrupt full steering at highway speed must not roll the car")
		check(car.position.is_finite() and car.linear_velocity.is_finite(), "Abrupt input must preserve finite physics")
		car.steer = 0.0
	if tick == 1170:
		check(absf(car._wheel_pivots[0].rotation.y) < 0.001, "Released steering must center the front wheels promptly")
		print("Handling regression: %d/%d checks passed" % [checks - failures, checks])
		quit(1 if failures > 0 else 0)
	return false
