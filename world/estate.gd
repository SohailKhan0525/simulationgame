class_name HarborEstate
extends CharacterBody3D

const MODEL := preload("res://assets/props/quayside_estate.glb")
const WHEELBASE := 2.75
var cargo_count := 0
var roof_load: Masonry
var speed := 0.0
var steering := 0.0
var wheels: Array[Node3D] = []
var paint := Color("34626b")
var headlamps: SpotLight3D
var lenses: Array[StandardMaterial3D] = []

func _ready() -> void:
	collision_layer = 4
	collision_mask = 7
	var hit := CollisionShape3D.new()
	var body := BoxShape3D.new()
	body.size = Vector3(4.32,1.32,1.8)
	hit.shape = body
	hit.position.y = 0.82
	add_child(hit)
	var model := MODEL.instantiate()
	add_child(model)
	for node in model.find_children("*","MeshInstance3D",true,false):
		if node.name.begins_with("Wheel_"):
			wheels.append(node)
		else:
			for i in node.mesh.get_surface_count():
				var mat: StandardMaterial3D = node.mesh.surface_get_material(i)
				if mat.resource_name.begins_with("Deep Atlantic"):
					var coat := mat.duplicate() as StandardMaterial3D
					coat.albedo_color = paint
					node.set_surface_override_material(i,coat)
				elif mat.resource_name in ["Headlight glass","Tail lamp lens"]:
					var lens := mat.duplicate() as StandardMaterial3D
					lens.emission_enabled = true
					lens.emission = Color("ffe4b9") if mat.resource_name == "Headlight glass" else Color("e84827")
					lens.emission_energy_multiplier = 0
					node.set_surface_override_material(i,lens)
					lenses.append(lens)

func load_shipments(shipment: Dictionary) -> void:
	var count := 0
	for quantity in shipment.values(): count += int(quantity)
	if count == cargo_count: return
	cargo_count = count
	if roof_load:
		roof_load.hide()
		roof_load.queue_free()
		roof_load = null
	if count == 0: return
	roof_load = Masonry.new()
	add_child(roof_load)
	for x in [-1.35,-0.13]:
		roof_load.part("steel",Vector3(x,1.64,0),Vector3(0.064,0.055,1.32),"475b5a")
	for i in count:
		var x := -1.08 + (i/2)*0.68
		var z := -0.28 + (i%2)*0.56
		roof_load.box(x,1.861,z,0.65,0.38,0.53,"a8825b")
		roof_load.box(x,2.055,z,0.645,0.009,0.06,"e6c29b")
		roof_load.box(x-0.326,1.87,z,0.006,0.16,0.22,"e8ddc6")
		roof_load.box(x,2.065,z,0.045,0.012,0.54,"285d63")
		for side in [-1,1]:
			roof_load.box(x,1.86,z+side*0.265,0.045,0.40,0.016,"285d63")
	roof_load.bake()

func equip_headlights() -> void:
	headlamps = SpotLight3D.new()
	headlamps.position = Vector3(2.15,0.79,0)
	headlamps.rotation_degrees = Vector3(-7,-90,0)
	headlamps.spot_range = 22
	headlamps.spot_angle = 33
	headlamps.spot_attenuation = 0.7
	headlamps.light_color = Color("ffecd2")
	headlamps.light_energy = 2.6
	add_child(headlamps)
	headlamps.hide()

func lighting(night: float, occupied := false) -> void:
	for lens in lenses: lens.emission_energy_multiplier = night * 1.7
	if headlamps: headlamps.visible = occupied and night > 0.2

func roll(distance: float) -> void:
	for wheel in wheels:
		wheel.rotation.z = wrapf(wheel.rotation.z - distance/0.356,-PI,PI)
		if wheel.name.begins_with("Wheel_F"): wheel.rotation.y = steering

func drive(dt: float, input: Vector2) -> void:
	var target := input.y * (9.0 if input.y >= 0 else 3.3)
	var rate := 2.0 if is_zero_approx(input.y) else 4.4
	if speed * input.y < 0: rate = 8.4
	# Cartons increase the mass accelerated by the same engine and brake force.
	var mass_factor := 1.0 + 0.045 * cargo_count
	speed = move_toward(speed,target,dt*rate/mass_factor)
	steering = move_toward(steering,-input.x*0.5,dt*1.9)
	var distance := speed*dt
	if absf(distance) < 0.0001: return
	var next_yaw := rotation.y + distance*tan(steering)/WHEELBASE
	var shift := Vector3.RIGHT.rotated(Vector3.UP,next_yaw) * distance
	var pose := Transform3D(Basis(Vector3.UP,next_yaw), position + shift)
	var shape := PhysicsShapeQueryParameters3D.new()
	shape.shape = (get_child(0) as CollisionShape3D).shape
	shape.transform = pose.translated_local(Vector3.UP*0.82)
	shape.exclude = [get_rid()]
	shape.collision_mask = collision_mask
	var bounds := pose.origin
	if absf(bounds.x)>72.0 or bounds.z<7.2 or bounds.z>19.0 or not get_world_3d().direct_space_state.intersect_shape(shape,1).is_empty():
		speed = 0
		return
	rotation.y = next_yaw
	var hit := move_and_collide(shift)
	roll(distance if hit == null else signf(distance)*hit.get_travel().length())
	if hit: speed = 0
