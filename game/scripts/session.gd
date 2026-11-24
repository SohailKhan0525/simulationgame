class_name DriveSession
extends RefCounted
## Offline career, deterministic job rules, and versioned atomic save data.

const SAVE_SCHEMA := 1
const TANK_LITERS := 46.0
const FUEL_PRICE := 1.85
const MAX_LEVEL := 20
const XP_PER_LEVEL := 500
const WORLD_LIMIT := 13850.0
const CARS: Array[Dictionary] = [
	{"name": "Aster S", "price": 0, "level": 1, "description": "A light four-cylinder. Your first city companion."},
	{"name": "Meridian GT", "price": 6500, "level": 4, "description": "A balanced six-cylinder grand tourer."},
	{"name": "Veloce R", "price": 18000, "level": 12, "description": "A V8 coupe built for a long open road."}
]
const LAUGHTER: Array[String] = [
	"Driver 01: Ha! Taking the scenic route?",
	"Driver 02: Haha, catch you at the next light!",
	"Driver 03: Heh, saving your tires for tomorrow?",
	"Driver 04: Ha-ha! Fair enough, enjoy your cruise.",
	"Driver 05: Haha! My grandma likes this lane too.",
	"Driver 06: Heh-heh, keeping the fuel bill down!",
	"Driver 07: Ha! Another time, road buddy.",
	"Driver 08: Hahaha, no hurry in this city!",
	"Driver 09: Heh! You make patience look expensive.",
	"Driver 10: Ha-ha, see you around the block!",
	"Driver 11: Haha! The sunset is worth slowing for.",
	"Driver 12: Heh, your ride, your rules."
]
const JOBS: Array[Dictionary] = [
	{"title":"First fare", "kind":"passenger", "passenger":"Maya · commuter", "dialogue":"First day? Welcome to the city. My office is just down the avenue.", "blocks":3, "level":1},
	{"title":"Last train home", "kind":"passenger", "passenger":"Finn · tipsy passenger", "dialogue":"I left the party early. A quiet ride home would be perfect, thanks.", "blocks":4, "level":2},
	{"title":"The blue badge", "kind":"passenger", "passenger":"Officer Rivera · off-duty cop", "dialogue":"Off duty tonight. Keep it smooth and I will tell you where the good coffee is.", "blocks":5, "level":3},
	{"title":"Riverside sprint", "kind":"race", "passenger":"Jules · local racer", "dialogue":"Three checkpoints, one finish. Ready when you are.", "blocks":5, "level":4},
	{"title":"Sealed envelope", "kind":"courier", "passenger":"Dispatch · document delivery", "dialogue":"A signed envelope for the gallery. Keep the corners clean.", "blocks":6, "level":5},
	{"title":"A change of plans", "kind":"passenger", "passenger":"Ash · reformed thief", "dialogue":"I used to pick pockets. These days I pick up honest shifts. Take me to work.", "blocks":6, "level":6},
	{"title":"Parkside afternoon", "kind":"passenger", "passenger":"Evelyn · birdwatcher", "dialogue":"The park is beautiful after the rain. Can we go there?", "blocks":7, "level":7},
	{"title":"Midtown minute", "kind":"time_trial", "passenger":"Dispatch · time trial", "dialogue":"An open-road checkpoint run. Stay in control and beat the clock.", "blocks":7, "level":8},
	{"title":"Velvet address", "kind":"passenger", "passenger":"Sol · hotel guest", "dialogue":"The hotel entrance is on the next avenue. Thank you for the lift.", "blocks":8, "level":9},
	{"title":"A quiet deal", "kind":"passenger", "passenger":"Rook · shady passenger", "dialogue":"No trouble tonight. Just take me to the diner and keep the radio on.", "blocks":8, "level":10},
	{"title":"Bridge run", "kind":"courier", "passenger":"Dispatch · studio supplies", "dialogue":"A studio crew needs this package. The case is secured in the back.", "blocks":9, "level":11},
	{"title":"Grand tourer", "kind":"race", "passenger":"Sana · touring club", "dialogue":"A longer route this time. Smooth driving wins long races.", "blocks":9, "level":12},
	{"title":"Rain check", "kind":"passenger", "passenger":"Noah · soaked commuter", "dialogue":"What a downpour! Thanks for stopping. I am heading to the station.", "blocks":10, "level":13},
	{"title":"Night shift", "kind":"passenger", "passenger":"Dr. Quinn · nurse", "dialogue":"Another night shift. A calm ride is all I need.", "blocks":10, "level":14},
	{"title":"Neighborhood hero", "kind":"courier", "passenger":"Dispatch · community kitchen", "dialogue":"Fresh groceries for the community kitchen. Everybody is waiting.", "blocks":11, "level":15},
	{"title":"Uptown circuit", "kind":"time_trial", "passenger":"Dispatch · precision route", "dialogue":"Four turns and a clean finish. Find your rhythm.", "blocks":11, "level":16},
	{"title":"The long way home", "kind":"passenger", "passenger":"Tess · village resident", "dialogue":"I have been in the city all week. Time to head somewhere greener.", "blocks":12, "level":17},
	{"title":"After the encore", "kind":"passenger", "passenger":"Leo · cheerful partygoer", "dialogue":"What a show! I am glad I called a driver. Home, please.", "blocks":12, "level":18},
	{"title":"City lights duel", "kind":"race", "passenger":"Jules · returning rival", "dialogue":"You have come a long way. One more run through the city lights?", "blocks":13, "level":19},
	{"title":"The endless road", "kind":"passenger", "passenger":"Maya · your first passenger", "dialogue":"Remember your first fare? Look at you now. Let us take another ride.", "blocks":14, "level":20}
]

var state: Dictionary
var mission: Dictionary = {}
var status := "Your city. Your pace. Pick a fare or just drive."
var race_offer := false
var banter: Array[String] = []
var save_path: String
var _clock := 0.0

func _init(path: String = "user://qofeno-drive-save.json") -> void:
	save_path = path
	state = _default_state()

func _default_state() -> Dictionary:
	return {"schema":SAVE_SCHEMA, "cash":1800.0, "xp":0, "car":0,
		"upgrades":[0,0,0], "owned":[true,false,false], "position":[5.0,0.8,20.0],
		"yaw":0.0, "fuel":36.0, "damage":0.0, "mission":{}, "completed_jobs":[],
		"total_jobs":0, "total_distance":0.0, "saved_at":""}

func get_level() -> int:
	return clampi(1 + int(state.xp) / XP_PER_LEVEL, 1, MAX_LEVEL)

func get_level_progress() -> float:
	if get_level() == MAX_LEVEL:
		return 1.0
	return float(int(state.xp) % XP_PER_LEVEL) / float(XP_PER_LEVEL)

func get_jobs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(JOBS.size()):
		var job: Dictionary = JOBS[index].duplicate(true)
		job["index"] = index
		job["reward"] = _reward(index)
		job["xp"] = _xp(index)
		job["unlocked"] = int(job.level) <= get_level()
		job["completed"] = state.completed_jobs.has(index)
		result.append(job)
	return result

func get_car_specs(index: int) -> Dictionary:
	if index < 0 or index >= CARS.size():
		return {}
	var car: Dictionary = CARS[index].duplicate(true)
	car["owned"] = bool(state.owned[index])
	car["upgrades"] = int(state.upgrades[index])
	car["upgrade_price"] = 600 + int(state.upgrades[index]) * 500
	return car

func start_job(index: int, origin: Vector3) -> String:
	if not mission.is_empty():
		return _say("Finish or cancel your current job first.")
	if index < 0 or index >= JOBS.size():
		return _say("That job is unavailable.")
	var job: Dictionary = JOBS[index]
	if int(job.level) > get_level():
		return _say("Reach level %d to unlock this job." % int(job.level))
	race_offer = false
	var pickup := _road_anchor(origin + Vector3(0,0,-160))
	var route := _route(pickup, int(job.blocks), index)
	var racing: bool = str(job.kind) in ["race", "time_trial"]
	mission = {"job_index":index, "kind":job.kind, "title":job.title,
		"passenger":job.passenger, "dialogue":job.dialogue, "stage":"pickup",
		"pickup":_pack(pickup), "destination":route[-1], "checkpoints":route,
		"checkpoint":0, "time_left":_race_time(route, pickup) if racing else 0.0,
		"rival_progress":0.0, "race_elapsed":0.0, "reward":_reward(index), "xp":_xp(index)}
	state.mission = mission
	return _say("%s · Stop at the pickup marker." % str(job.title))

func get_goal() -> Vector3:
	if mission.is_empty():
		return Vector3.ZERO
	if str(mission.stage) == "pickup":
		return _unpack(mission.pickup)
	if str(mission.stage) == "racing":
		return _unpack(mission.checkpoints[int(mission.checkpoint)])
	return _unpack(mission.destination)

func goal_distance(pos: Vector3) -> float:
	if mission.is_empty():
		return 0.0
	return _flat_distance(pos, get_goal())

func get_goal_label() -> String:
	if mission.is_empty():
		return "Free drive · explore New York region"
	match str(mission.stage):
		"pickup": return "PICKUP · " + str(mission.passenger)
		"racing": return "CHECKPOINT %d / %d · %ds" % [int(mission.checkpoint)+1, mission.checkpoints.size(), ceili(float(mission.time_left))]
		_: return "DROP-OFF · " + str(mission.title)

func update_drive(pos: Vector3, speed: float, delta: float) -> void:
	var dt := clampf(delta, 0.0, 1.0)
	_clock += dt
	state.total_distance = float(state.total_distance) + maxf(0.0, absf(speed)) / 3.6 * dt
	if mission.is_empty() or str(mission.stage) != "racing":
		return
	mission.time_left = maxf(0.0, float(mission.time_left) - dt)
	mission.race_elapsed = float(mission.race_elapsed) + dt
	# This visible progress is a time-trial ghost, not a simulated physical traffic car.
	mission.rival_progress = clampf(float(mission.race_elapsed) / maxf(1.0, float(mission.time_left) + float(mission.race_elapsed)), 0.0, 1.0)
	if float(mission.time_left) <= 0.0:
		var title := str(mission.title)
		mission = {}
		state.mission = mission
		_say("%s · Time ran out. No money lost; try again." % title)
		return
	if goal_distance(pos) <= 18.0:
		mission.checkpoint = int(mission.checkpoint) + 1
		if int(mission.checkpoint) >= mission.checkpoints.size():
			_complete()
		else:
			_say("Checkpoint cleared. Keep it smooth!")

func interact(pos: Vector3, speed: float) -> String:
	if mission.is_empty():
		return _say("Choose a passenger job or a route from the Jobs menu.")
	if absf(speed) > 5.0:
		return _say("Slow to under 5 km/h to stop safely.")
	if goal_distance(pos) > 22.0:
		return _say("Follow the marker · %dm remaining." % roundi(goal_distance(pos)))
	if str(mission.stage) == "pickup":
		if str(mission.kind) in ["race", "time_trial"]:
			mission.stage = "racing"
			return _say("Go! Follow each checkpoint before the timer runs out.")
		mission.stage = "deliver"
		return _say(str(mission.dialogue))
	if str(mission.stage) == "deliver":
		return _complete()
	return _say("The next checkpoint is marked. Keep driving!")

func offer_race() -> bool:
	if not mission.is_empty() or race_offer:
		return false
	race_offer = true
	_say("Driver beside you: Nice ride! Fancy a checkpoint race?")
	return true

func accept_race(pos: Vector3) -> String:
	if not race_offer:
		return _say("No rival is challenging you right now.")
	if not mission.is_empty():
		race_offer = false
		return _say("Finish your current job before racing.")
	race_offer = false
	var anchor := _road_anchor(pos)
	var route := _route(anchor, 5 + get_level() / 3, get_level())
	mission = {"job_index":-1, "kind":"race", "title":"Traffic-light challenge",
		"passenger":"Rival · checkpoint ghost", "dialogue":"See you at the finish!",
		"stage":"racing", "pickup":_pack(anchor), "destination":route[-1],
		"checkpoints":route, "checkpoint":0, "time_left":_race_time(route, anchor),
		"rival_progress":0.0, "race_elapsed":0.0, "reward":250 + get_level()*35,
		"xp":300 + get_level()*12}
	state.mission = mission
	return _say("Challenge accepted. Go through all checkpoints!")

func decline_race() -> String:
	if not race_offer:
		return status
	race_offer = false
	banter.assign(LAUGHTER)
	return _say("The crowd laughs, then the light changes. Your ride, your rules.")

func cancel_job() -> String:
	if mission.is_empty():
		return _say("You are already free to drive.")
	mission = {}
	state.mission = mission
	return _say("Job cancelled. No fee charged.")

func buy_car(index: int) -> String:
	if index < 0 or index >= CARS.size():
		return _say("This car is coming soon.")
	if bool(state.owned[index]):
		state.car = index
		return _say("Selected %s." % str(CARS[index].name))
	if get_level() < int(CARS[index].level):
		return _say("Reach level %d to unlock %s." % [int(CARS[index].level), str(CARS[index].name)])
	if float(state.cash) < float(CARS[index].price):
		return _say("Earn $%d more for this car." % ceili(float(CARS[index].price) - float(state.cash)))
	state.cash = snappedf(float(state.cash) - float(CARS[index].price), 0.01)
	state.owned[index] = true
	state.car = index
	return _say("%s is yours. Enjoy the drive!" % str(CARS[index].name))

func upgrade_car() -> String:
	var index := int(state.car)
	var upgrade := int(state.upgrades[index])
	if upgrade >= 5:
		return _say("This car is fully upgraded. More tuning is coming soon.")
	var price := 600 + upgrade * 500
	if float(state.cash) < price:
		return _say("This upgrade costs $%d. Complete a few more jobs." % price)
	state.cash = snappedf(float(state.cash) - price, 0.01)
	state.upgrades[index] = upgrade + 1
	return _say("Tuning stage %d fitted · engine, tires and brakes improved." % (upgrade + 1))

func refuel(liters: float) -> float:
	if not is_finite(liters) or liters <= 0.0:
		return 0.0
	var purchased := minf(liters, minf(maxf(0.0,TANK_LITERS - float(state.fuel)), float(state.cash) / FUEL_PRICE))
	purchased = floorf(purchased * 100.0) / 100.0
	state.cash = maxf(0.0, snappedf(float(state.cash) - purchased * FUEL_PRICE, 0.01))
	state.fuel = minf(TANK_LITERS, float(state.fuel) + purchased)
	_say("Attendant: %.1f liters filled · $%.2f. Have a good drive!" % [purchased, purchased * FUEL_PRICE])
	return purchased

func repair_car() -> String:
	var price := ceili(float(state.damage) * 4.0)
	if float(state.cash) < price:
		return _say("Repairs cost $%d. Earn a little more first." % price)
	state.cash = float(state.cash) - price
	state.damage = 0.0
	return _say("Car repaired · $%d. Ready for the road." % price)

func save(pos: Vector3, yaw: float, fuel: float, damage: float) -> bool:
	if not pos.is_finite():
		_say("Could not save an invalid vehicle position. Your previous drive is unchanged.")
		return false
	state.position = _pack(Vector3(clampf(pos.x,-WORLD_LIMIT,WORLD_LIMIT), clampf(pos.y,0.6,100.0), clampf(pos.z,-WORLD_LIMIT,WORLD_LIMIT)))
	state.yaw = yaw if is_finite(yaw) else 0.0
	state.fuel = clampf(fuel,0.0,TANK_LITERS) if is_finite(fuel) else 36.0
	state.damage = clampf(damage,0.0,100.0) if is_finite(damage) else 0.0
	state.mission = mission
	state.saved_at = Time.get_datetime_string_from_system(true)
	var temp_path := save_path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		_say("Could not save this drive. Check available storage.")
		return false
	file.store_string(JSON.stringify(state))
	file.flush()
	file.close()
	# Keep the last valid save: never replace a valid backup with corrupted input.
	if _read_valid(save_path) != null:
		var backup_error := DirAccess.copy_absolute(save_path, save_path + ".bak")
		if backup_error != OK:
			_say("Save backup failed. Your previous drive is unchanged.")
			DirAccess.remove_absolute(temp_path)
			return false
	var error := DirAccess.rename_absolute(temp_path, save_path)
	if error != OK:
		_say("Could not finish saving. Your previous drive is unchanged.")
		return false
	return true

func load_save() -> bool:
	var loaded: Variant = _read_valid(save_path)
	var recovered := false
	if loaded == null:
		loaded = _read_valid(save_path + ".bak")
		recovered = loaded != null
	if loaded == null:
		state = _default_state()
		mission = {}
		if FileAccess.file_exists(save_path):
			_say("The save could not be read. A new drive is ready; the old file is preserved.")
		return false
	state = _sanitize(loaded)
	mission = state.mission
	race_offer = false
	banter.clear()
	_say("Recovered your previous saved drive." if recovered else "Welcome back. Your drive is ready.")
	return true

func _read_valid(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 2_000_000:
		return null
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return null
	var parsed: Variant = parser.data
	if not parsed is Dictionary or not (parsed.get("schema") is float or parsed.get("schema") is int):
		return null
	if int(parsed.schema) != SAVE_SCHEMA:
		return null
	return parsed

func _sanitize(data: Dictionary) -> Dictionary:
	var clean := _default_state()
	for key in ["cash","xp","car","yaw","fuel","damage","total_jobs","total_distance"]:
		if data.get(key) is float or data.get(key) is int:
			var number := float(data[key])
			if is_finite(number):
				clean[key] = number
	clean.cash = clampf(float(clean.cash),0.0,100000000.0)
	clean.xp = clampi(int(clean.xp),0,100000000)
	clean.fuel = clampf(float(clean.fuel),0.0,TANK_LITERS)
	clean.damage = clampf(float(clean.damage),0.0,100.0)
	clean.car = clampi(int(clean.car),0,CARS.size()-1)
	clean.total_jobs = maxi(0,int(clean.total_jobs))
	clean.total_distance = maxf(0.0,float(clean.total_distance))
	if data.get("upgrades") is Array and data.upgrades.size() == CARS.size():
		for i in range(CARS.size()):
			if data.upgrades[i] is float or data.upgrades[i] is int:
				clean.upgrades[i] = clampi(int(data.upgrades[i]),0,5)
	if data.get("owned") is Array and data.owned.size() == CARS.size():
		for i in range(CARS.size()):
			clean.owned[i] = data.owned[i] == true
	clean.owned[0] = true
	if not clean.owned[int(clean.car)]:
		clean.car = 0
	if _is_coordinate(data.get("position")):
		var pos := _unpack(data.position)
		clean.position = _pack(Vector3(clampf(pos.x,-WORLD_LIMIT,WORLD_LIMIT),clampf(pos.y,0.6,100.0),clampf(pos.z,-WORLD_LIMIT,WORLD_LIMIT)))
	if data.get("completed_jobs") is Array:
		for index in data.completed_jobs:
			if (index is int or index is float) and index >= 0 and index < JOBS.size() and not clean.completed_jobs.has(int(index)):
				clean.completed_jobs.append(int(index))
	if data.get("mission") is Dictionary and _valid_mission(data.mission):
		clean.mission = data.mission.duplicate(true)
	return clean

func _valid_mission(data: Dictionary) -> bool:
	if data.is_empty():
		return true
	for field in ["job_index","kind","title","stage","pickup","destination","checkpoints","checkpoint","time_left","reward","xp","race_elapsed","rival_progress","passenger","dialogue"]:
		if not data.has(field):
			return false
	if str(data.stage) not in ["pickup","deliver","racing"] or str(data.kind) not in ["passenger","courier","race","time_trial"]:
		return false
	if not _is_coordinate(data.pickup) or not _is_coordinate(data.destination):
		return false
	if not data.checkpoints is Array or data.checkpoints.is_empty() or data.checkpoints.size() > 16:
		return false
	for point in data.checkpoints:
		if not _is_coordinate(point):
			return false
	for field in ["job_index","checkpoint","time_left","reward","xp","race_elapsed","rival_progress"]:
		if not (data[field] is float or data[field] is int) or not is_finite(float(data[field])):
			return false
	return int(data.checkpoint) >= 0 and int(data.checkpoint) < data.checkpoints.size() and float(data.time_left) >= 0 and float(data.reward) >= 0 and float(data.reward) < 100000 and int(data.xp) >= 0 and int(data.xp) < 10000

func _complete() -> String:
	var previous_level := get_level()
	var reward := float(mission.reward)
	var earned_xp := int(mission.xp)
	var title := str(mission.title)
	var index := int(mission.job_index)
	state.cash = snappedf(float(state.cash) + reward, 0.01)
	state.xp = int(state.xp) + earned_xp
	state.total_jobs = int(state.total_jobs) + 1
	if index >= 0 and not state.completed_jobs.has(index):
		state.completed_jobs.append(index)
	mission = {}
	state.mission = mission
	var message := "%s complete · +$%d · +%d XP" % [title, roundi(reward), earned_xp]
	if get_level() > previous_level:
		message += " · LEVEL %d!" % get_level()
	if get_level() >= MAX_LEVEL:
		message += " · More levels coming soon."
	return _say(message)

func _reward(index: int) -> int:
	return 300 + index * 70

func _xp(index: int) -> int:
	return 550 + index * 25

func _route(start: Vector3, blocks: int, seed_index: int) -> Array:
	# Axis-aligned checkpoints keep every objective on the navigable road network.
	var direction := -1.0 if start.z > -11000.0 else 1.0
	var side := 1.0 if start.x < 11000.0 else -1.0
	if seed_index % 2 == 1 and absf(start.x) < 10000.0:
		side *= -1.0
	var first := _road_anchor(start + Vector3(0,0,direction * float(maxi(2,blocks / 2)) * 160.0))
	var second := _road_anchor(first + Vector3(side * float(maxi(1,blocks / 3))*160.0,0,0))
	var third := _road_anchor(second + Vector3(0,0,direction * float(maxi(1,blocks / 3))*160.0))
	return [_pack(first),_pack(second),_pack(third)]

func _race_time(route: Array, start: Vector3) -> float:
	var distance := 0.0
	var point := start
	for next in route:
		var destination := _unpack(next)
		distance += _flat_distance(point,destination)
		point = destination
	return 25.0 + distance / 11.0

func _road_anchor(pos: Vector3) -> Vector3:
	return Vector3(clampf(roundf(pos.x/160.0)*160.0+5.0,-13755.0,13765.0),0.8,clampf(roundf(pos.z/160.0)*160.0+5.0,-13755.0,13765.0))

func _flat_distance(a: Vector3,b: Vector3) -> float:
	return Vector2(a.x,a.z).distance_to(Vector2(b.x,b.z))

func _pack(pos: Vector3) -> Array:
	return [pos.x,pos.y,pos.z]

func _unpack(value: Array) -> Vector3:
	return Vector3(float(value[0]),float(value[1]),float(value[2]))

func _is_coordinate(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for component in value:
		if not (component is float or component is int) or not is_finite(float(component)):
			return false
	return true

func _say(message: String) -> String:
	status = message
	return message
