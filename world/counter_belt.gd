class_name CounterBelt
extends Node3D

# Metres in the shop. Each parcel has a fixed lane so FIFO order stays legible.
const DECK := 1.195
const SCANNER := 4.57
var camera := Camera3D.new()
var parcels: Array[GroceryPack] = []
var fall_speed: Array[float] = []
var visit := 0
var scanned := 0

func _ready() -> void:
	add_child(camera)
	camera.position = Vector3(4.53,2.49,-4.67)
	camera.look_at(Vector3(4.27,1.27,-3.10))
	camera.h_offset = 0.42
	camera.fov = 47

func present(next: int, market: Market) -> void:
	if next != visit:
		for parcel in parcels:
			parcel.hide()
			parcel.queue_free()
		parcels.clear()
		fall_speed.clear()
		visit = next
		scanned = 0
		if visit == 0: return
		var basket := market.reservations[visit]
		for i in basket.lines.size():
			var id: String = basket.lines[i].id
			var pack := GroceryPack.new()
			add_child(pack)
			pack.dress(id, Color(market.catalog[id].color))
			pack.position = Vector3(SCANNER - 0.22 - i*0.37, DECK + pack.half_height() + 0.13, -3.06)
			pack.rotation.y = 0.055 if i%2 else -0.035
			parcels.append(pack)
			fall_speed.append(0.0)
	if visit: scanned = market.reservations[visit].scanned

func _physics_process(delta: float) -> void:
	for i in parcels.size():
		var pack := parcels[i]
		var goal := SCANNER - 0.22 - (i-scanned)*0.37
		if i < scanned: goal = 5.69 - i*0.37
		pack.position.x = move_toward(pack.position.x,goal,1.55*delta)
		var floor_y := DECK + pack.half_height()
		if pack.position.y > floor_y or fall_speed[i] != 0.0:
			fall_speed[i] -= 9.81*delta
			pack.position.y += fall_speed[i]*delta
			if pack.position.y <= floor_y:
				pack.position.y = floor_y
				fall_speed[i] = -fall_speed[i]*0.16 if fall_speed[i] < -0.48 else 0.0

func hits_next(point: Vector2) -> bool:
	if not camera.current or scanned >= parcels.size(): return false
	var pack := parcels[scanned]
	var centre := camera.unproject_position(pack.global_position)
	var above := camera.unproject_position(pack.global_position + Vector3.UP*pack.half_height())
	var radius := maxf(26.0, centre.distance_to(above)*1.7)
	return point.distance_to(centre) <= radius
