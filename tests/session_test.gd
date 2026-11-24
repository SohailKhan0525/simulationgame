extends SceneTree
## Run: godot --headless --path game --script ../tests/session_test.gd
const Session = preload("res://scripts/session.gd")
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	var path := "user://test-session-%d.json" % Time.get_ticks_usec()
	var session = Session.new(path)
	check(session.state.cash == 1800.0, "Starting cash")
	check(session.get_level() == 1, "Starting level")
	check(session.get_jobs().size() == 20, "Twenty authored jobs")
	check(session.state.owned == [true,false,false], "Only starter car owned")
	session.start_job(19,Vector3.ZERO)
	check(session.mission.is_empty(), "High-level job locked")
	session.start_job(0,Vector3(5,0.8,20))
	var pickup: Vector3 = session.get_goal()
	check(not session.mission.is_empty(), "First fare starts")
	session.interact(pickup,20.0)
	check(session.mission.stage == "pickup", "Cannot collect passenger at speed")
	session.interact(pickup,0.0)
	check(session.mission.stage == "deliver", "Passenger collected while stopped")
	var destination: Vector3 = session.get_goal()
	session.interact(destination + Vector3(100,0,0),0.0)
	check(session.mission.stage == "deliver", "Cannot complete from far away")
	session.interact(destination,0.0)
	check(session.mission.is_empty(), "Passenger delivered")
	check(session.state.cash == 2100.0 and session.state.xp == 550, "Correct one-time rewards")
	session.interact(destination,0.0)
	check(session.state.cash == 2100.0, "No duplicate reward")
	check(session.get_level() == 2, "XP unlocks level two")
	session.state.xp = 999999
	check(session.get_level() == 20 and session.get_level_progress() == 1.0, "Level cap")
	session.state.cash = 100.0
	session.state.fuel = 45.0
	var purchased: float = session.refuel(100.0)
	check(is_equal_approx(purchased,1.0) and session.state.fuel == 46.0, "Tank capacity")
	check(is_equal_approx(session.state.cash,98.15), "Fuel bill")
	check(session.refuel(-8.0) == 0.0 and session.refuel(NAN) == 0.0, "Invalid fuel rejected")
	session.state.cash = 1.0
	session.state.fuel = 0.0
	check(session.refuel(20.0) <= 1.0 / Session.FUEL_PRICE and session.state.cash >= 0, "Affordable fueling cannot overdraw")
	session.state.cash = 100.0
	session.upgrade_car()
	check(session.state.upgrades[0] == 0, "Cannot buy unaffordable upgrade")
	session.state.cash = 10000.0
	session.upgrade_car()
	check(session.state.upgrades[0] == 1 and session.state.cash == 9400.0, "Upgrade charged once")
	session.buy_car(1)
	check(session.state.car == 1 and session.state.owned[1] and session.state.cash == 2900.0, "Car purchase")
	session.buy_car(1)
	check(session.state.cash == 2900.0, "Selecting owned car free")
	session.offer_race()
	session.decline_race()
	check(session.banter.size() == 12 and not session.race_offer, "Twelve distinct optional race reactions")
	var seen := {}
	for line in session.banter:
		seen[line] = true
	check(seen.size() == 12, "Reactions unique")
	session.offer_race()
	session.accept_race(Vector3(5,0.8,20))
	check(session.mission.stage == "racing", "Rival offer accepted")
	var cash_before: float = session.state.cash
	while not session.mission.is_empty():
		session.update_drive(session.get_goal(),40.0,0.016)
	check(session.state.cash > cash_before, "All race checkpoints reward completion")
	session.offer_race()
	session.accept_race(Vector3(5,0.8,20))
	session.mission.time_left = 0.1
	session.update_drive(Vector3.ZERO,0.0,0.2)
	check(session.mission.is_empty(), "Race timeout clears mission")
	session.start_job(1,Vector3(5,0.8,20))
	session.interact(session.get_goal(),0.0)
	var saved_goal: Vector3 = session.get_goal()
	check(session.save(Vector3(5,0.8,345),1.0,28.0,3.0), "Save written")
	var restored = Session.new(path)
	check(restored.load_save(), "Save loaded")
	check(restored.mission.stage == "deliver" and restored.get_goal().is_equal_approx(saved_goal), "Active mission survives load")
	check(restored.state.fuel == 28.0 and restored.state.damage == 3.0 and restored.state.yaw == 1.0, "Vehicle state roundtrip")
	check(restored.state.owned[1] and restored.state.upgrades[0] == 1, "Career state roundtrip")
	restored.state.cash = 1234.0
	check(restored.save(Vector3(5,0.8,346),2.0,27.0,4.0), "Second save creates backup")
	var corrupted := FileAccess.open(path,FileAccess.WRITE)
	corrupted.store_string("{broken-json")
	corrupted.close()
	var recovered = Session.new(path)
	check(recovered.load_save() and recovered.state.yaw == 1.0, "Corrupt current save restores previous valid backup")
	check(recovered.save(Vector3(5,0.8,347),3.0,26.0,5.0), "Recovered session can save")
	var backup: Variant = recovered._read_valid(path + ".bak")
	check(backup != null and backup.yaw == 1.0, "Corrupt save never poisons valid backup")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	if failures.is_empty():
		print("PASS: %d session checks" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func check(condition: bool,label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
