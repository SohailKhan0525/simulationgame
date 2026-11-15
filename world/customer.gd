class_name CustomerFlow
extends Node3D

signal changed
enum Phase { AWAY, ARRIVING, BROWSING, QUEUING, WAITING, LEAVING }
const ENTRY := Vector3(0,0.055,2.3)
const AISLE := Vector3(0,0.055,-4.65)
const BROWSE := Vector3(-4.45,0.055,-6.27)
const TILL := Vector3(3.8,0.055,-2.03)
const STREET := Vector3(-12,0.055,2.3)
var market: Market
var person: HarborPerson
var phase := Phase.AWAY
var route: Array = []
var delay := 3.0
var visits := 0
var active := false

func walk(next: Phase, path: Array) -> void:
	phase = next
	route = path
	changed.emit()

func depart() -> void:
	market.cancel_basket()
	if phase in [Phase.AWAY,Phase.LEAVING]: return
	# Exit through the same clear central aisle as the arrival.
	if person.position.z > -0.3: walk(Phase.LEAVING,[ENTRY,STREET])
	else: walk(Phase.LEAVING,[AISLE,Vector3(0,0.055,-0.6),ENTRY,STREET])

func serve() -> String:
	if phase != Phase.WAITING: return "The till is clear. Customers browse before paying."
	var message := market.checkout()
	depart()
	return message

func _physics_process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	if not active or market == null: return
	if not market.d.open: depart()
	if phase == Phase.AWAY:
		if not market.d.open or market.available().is_empty(): return
		delay -= delta
		if delay > 0: return
		visits += 1
		person = HarborPerson.new()
		add_child(person)
		person.outfit(visits % 2)
		person.position = STREET
		walk(Phase.ARRIVING,[ENTRY,Vector3(0,0.055,-0.6),AISLE,BROWSE])
	elif phase == Phase.BROWSING:
		delay -= delta
		if delay > 0: return
		var choice := market.choose_product(visits)
		if choice == "" or not market.reserve(choice):
			depart()
		else: walk(Phase.QUEUING,[AISLE,Vector3(1.8,0.055,-1.75),TILL])
	elif phase == Phase.WAITING:
		person.pose("Idle")
	elif not route.is_empty():
		var dest: Vector3 = route[0]
		var dir := dest - person.position
		person.face(dir,delta)
		var speed := 1.65 + 0.15*(visits%3)
		person.pose("Walk",speed/1.9)
		person.position = person.position.move_toward(dest,delta*speed)
		if person.position.distance_squared_to(dest) < 0.0004:
			route.pop_front()
			if route.is_empty(): arrived()

func arrived() -> void:
	person.pose("Idle")
	match phase:
		Phase.ARRIVING:
			phase = Phase.BROWSING
			person.rotation.y = PI
			delay = 1.7
		Phase.QUEUING:
			phase = Phase.WAITING
			person.rotation.y = PI
		Phase.LEAVING:
			person.queue_free()
			person = null
			phase = Phase.AWAY
			delay = 3.5
	changed.emit()
