class_name HarborPlayer
extends CharacterBody3D

signal footstep
var person := HarborPerson.new()
var pivot := Node3D.new()
var arm := SpringArm3D.new()
var camera := Camera3D.new()
var stick := Vector2.ZERO
var running := false
var first_person := true
var held_parcel := MeshInstance3D.new()
var active := false
var stride := 0.0
var yaw := 0.0
var pitch := -0.015

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var hit := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.33
	capsule.height = 1.72
	hit.shape = capsule
	hit.position.y = 0.86
	add_child(hit)
	add_child(person)
	person.outfit(0)
	add_child(pivot)
	pivot.position.y = 1.52
	pivot.add_child(arm)
	arm.collision_mask = 1
	arm.spring_length = 3.35
	arm.margin = 0.16
	var cam_shape := SphereShape3D.new()
	cam_shape.radius = 0.17
	arm.shape = cam_shape
	arm.add_excluded_object(get_rid())
	arm.add_child(camera)
	camera.near = 0.07
	camera.fov = 66
	var box := BoxMesh.new()
	box.size = Vector3(0.40,0.28,0.27)
	var kraft := StandardMaterial3D.new()
	kraft.albedo_color = Color("aa8662")
	box.material = kraft
	held_parcel.mesh = box
	camera.add_child(held_parcel)
	held_parcel.position = Vector3(0.21,-0.28,-0.56)
	held_parcel.rotation.y = -0.23
	held_parcel.hide()
	floor_snap_length = 0.2
	pivot.rotation.y = yaw
	arm.rotation.x = pitch

func set_view(eyes: bool) -> void:
	first_person = eyes
	person.visible = not eyes
	pivot.position.y = 1.63 if eyes else 1.52
	arm.spring_length = 0.0 if eyes else 3.35
	camera.fov = 72 if eyes else 66
	held_parcel.visible = eyes and person.carton.visible

func carry_carton(carrying: bool) -> void:
	person.carton.visible = carrying
	person.hands.carrying = carrying
	held_parcel.visible = first_person and carrying

func turn(amount: Vector2, options: Dictionary) -> void:
	var speed := 0.0012 + float(options.sensitivity)*0.000035
	yaw = wrapf(yaw-amount.x*speed,-PI,PI)
	pitch = clampf(pitch+amount.y*speed*(1 if options.invert else -1),-0.85,0.39)
	pivot.rotation.y = yaw
	arm.rotation.x = pitch

func _physics_process(delta: float) -> void:
	if not active: return
	var keyboard := Vector2(int(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT))-int(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)), int(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))-int(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)))
	var drive := (stick+keyboard).limit_length()
	var direction := Vector3(drive.x,0,drive.y).rotated(Vector3.UP,yaw)
	var sprint := (running or Input.is_key_pressed(KEY_SHIFT)) and not person.carton.visible
	var speed := 4.35 if sprint else 2.35
	velocity.x = move_toward(velocity.x,direction.x*speed,delta*14)
	velocity.z = move_toward(velocity.z,direction.z*speed,delta*14)
	velocity.y = -0.25 if is_on_floor() else velocity.y - delta*16
	move_and_slide()
	var motion := get_real_velocity().slide(Vector3.UP)
	if motion.length() > 0.1:
		person.face(motion,delta)
		person.pose("Run" if sprint else "Walk",clampf(motion.length()/(3.8 if sprint else 2.0),0.5,1.45))
		stride += motion.length()*delta
		if stride > 0.88:
			stride = 0
			footstep.emit()
	else: person.pose("Idle")
	if position.y < -2: position = Vector3(0,0.1,4)

func halt() -> void:
	active = false
	stick = Vector2.ZERO
	velocity = Vector3.ZERO
	person.pose("Idle")
