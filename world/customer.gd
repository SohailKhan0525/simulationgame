class_name CustomerFlow
extends Node3D

signal changed
enum Phase { ARRIVING, BROWSING, TO_LINE, IN_LINE, LEAVING }
const STREET := Vector3(-12,0.055,3.35)
const ENTRY := Vector3(-0.85,0.055,3.35)
const AISLE := Vector3(-0.85,0.055,-4.45)
const SHELF := Vector3(-4.45,0.055,-6.27)
const LINE_START := Vector3(1.25,0.055,-1.98)
const TILL := Vector3(3.85,0.055,-1.98)
const SPACING := 0.95
const INNER_EXIT := Vector3(0.85,0.055,-0.95)
const OUTER_EXIT := Vector3(0.85,0.055,2.55)
const PIER := Vector3(12,0.055,2.55)

class Shopper extends RefCounted:
	var visit: int
	var person: HarborPerson
	var phase := Phase.ARRIVING
	var route: Array[Vector3] = []
	var browse_left := 1.7
	var speed: float

var market: Market
var shoppers: Array[Shopper] = []
var line: Array[Shopper] = []
var next_arrival := 2.6
var visits := 0
var active := false

func reset(next: Market) -> void:
	if market:
		market.closed.disconnect(close_lane)
		for shopper in shoppers:
			market.cancel_basket(shopper.visit)
			shopper.person.hide()
			shopper.person.queue_free()
	shoppers.clear()
	line.clear()
	market = next
	market.closed.connect(close_lane)
	visits = int(market.d.receipt)
	next_arrival = 2.6

func spawn_shopper() -> void:
	visits += 1
	var shopper := Shopper.new()
	shopper.visit = visits
	shopper.speed = 1.65 + 0.15 * (visits % 3)
	shopper.person = HarborPerson.new()
	add_child(shopper.person)
	shopper.person.outfit(visits % 2)
	shopper.person.position = STREET
	shopper.route.assign([ENTRY, AISLE, Vector3(-4.45,0.055,-4.45), SHELF])
	shoppers.append(shopper)

func close_lane() -> void:
	for shopper in shoppers:
		if shopper.phase != Phase.LEAVING:
			depart(shopper)
	line.clear()
	changed.emit()

func depart(shopper: Shopper) -> void:
	shopper.phase = Phase.LEAVING
	shopper.person.hands.carrying = false
	shopper.person.carton.hide()
	var pos := shopper.person.position
	shopper.route.clear()
	if pos.z >= ENTRY.z - 0.01 and pos.x < ENTRY.x:
		shopper.route.append(STREET)
		return
	if pos.z < -0.25:
		# Clear the counter's front edge before crossing toward the exit lane.
		if pos.x > 1.4 and pos.z >= TILL.z - 0.05:
			shopper.route.append(Vector3(pos.x, INNER_EXIT.y, INNER_EXIT.z))
		shopper.route.append(INNER_EXIT)
	shopper.route.append(OUTER_EXIT)
	shopper.route.append(PIER)

func line_position(index: int) -> Vector3:
	return TILL - Vector3.RIGHT * SPACING * index

func ready_visit() -> int:
	if line.is_empty(): return 0
	var head := line[0]
	if head.phase == Phase.IN_LINE and head.person.position.is_equal_approx(TILL):
		return head.visit
	return 0

func serve(visit: int) -> String:
	if visit < 1 or ready_visit() != visit: return "Wait for the next shopper at the till."
	var shopper := line.pop_front() as Shopper
	var message := market.checkout(visit)
	depart(shopper)
	changed.emit()
	return message

func _physics_process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	if not active or market == null: return
	if market.d.open and shoppers.size() < market.customer_limit() and not market.available().is_empty():
		next_arrival -= delta
		if next_arrival <= 0:
			spawn_shopper()
			next_arrival = 6.5
	# Iterate a snapshot because a shopper can leave during this step.
	for shopper: Shopper in shoppers.duplicate():
		match shopper.phase:
			Phase.BROWSING:
				shopper.browse_left -= delta
				if shopper.browse_left <= 0: select_item(shopper)
			Phase.IN_LINE:
				var index := line.find(shopper)
				if advance(shopper, line_position(index), delta):
					shopper.person.face(Vector3.FORWARD if index == 0 else Vector3.RIGHT, delta)
			_:
				var target := shopper.route[0]
				# The doorway is 3.4 m wide. Round its inside corner instead of
				# making departing shoppers converge on the very same point.
				if target == INNER_EXIT and shopper.person.position.distance_to(INNER_EXIT) < 0.75:
					shopper.route.pop_front()
					target = shopper.route[0]
				if advance(shopper, target, delta):
					shopper.route.pop_front()
					if shopper.route.is_empty(): arrive(shopper)

func select_item(shopper: Shopper) -> void:
	var id := market.choose_product(shopper.visit)
	if id.is_empty() or not market.reserve(shopper.visit, id):
		depart(shopper)
		return
	line.append(shopper)
	shopper.phase = Phase.TO_LINE
	shopper.route.assign([Vector3(1.25,0.055,-6.27), LINE_START])
	var parcel := shopper.person.carton
	parcel.scale = Vector3(0.67,0.69,0.70)
	var wrap := StandardMaterial3D.new()
	wrap.albedo_color = Color(market.catalog[id].color)
	parcel.material_override = wrap
	parcel.show()
	shopper.person.hands.carrying = true
	changed.emit()

func advance(shopper: Shopper, destination: Vector3, delta: float) -> bool:
	var person := shopper.person
	if person.position.is_equal_approx(destination):
		person.pose("Idle")
		return true
	var next := person.position.move_toward(destination, shopper.speed * delta)
	for other in shoppers:
		if other == shopper: continue
		var other_pos := other.person.position
		# Yield only while approaching, so adjacent shoppers can move apart.
		var gap := next.distance_squared_to(other_pos)
		if gap < 0.58 * 0.58 and gap < person.position.distance_squared_to(other_pos):
			person.pose("Idle")
			return false
	person.face(destination - person.position, delta)
	person.pose("Walk", shopper.speed / 1.9)
	person.position = next
	return next.is_equal_approx(destination)

func arrive(shopper: Shopper) -> void:
	shopper.person.pose("Idle")
	match shopper.phase:
		Phase.ARRIVING:
			shopper.phase = Phase.BROWSING
			shopper.person.rotation.y = PI
			shopper.person.hands.gesture("display", shopper.browse_left)
		Phase.TO_LINE:
			shopper.phase = Phase.IN_LINE
		Phase.LEAVING:
			shoppers.erase(shopper)
			shopper.person.queue_free()
	changed.emit()
