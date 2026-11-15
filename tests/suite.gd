extends SceneTree
## Run after import. All test files use a private temporary slot.
var n := 0
var failures: Array[String] = []
var prefix := "user://qa-"+str(Time.get_ticks_usec())

func expect(ok: bool, detail: String) -> void:
	n += 1
	if not ok:
		failures.append(detail)
		printerr("FAIL: ",detail)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	economy()
	line_accounts()
	persistence()
	versions()
	await integration()
	print("QOFENO CHECKS: %d passed, %d failed" % [n-failures.size(),failures.size()])
	quit(0 if failures.is_empty() else 1)

func economy() -> void:
	var m := Market.new()
	m.toggle_open()
	expect(not m.d.open,"cannot open empty shop")
	expect(not m.reserve(1,"tea"),"closed shop cannot reserve")
	m.order("tea")
	expect(m.d.cash == 75 and m.d.goods.tea.back == 5,"paid delivery")
	m.collect("tea")
	expect(m.d.goods.tea.back == 0 and m.d.quantity == 5,"transfer to hands")
	m.stock()
	expect(m.d.quantity == 0 and m.d.goods.tea.shelf == 5,"shelf transfer")
	m.order("tea")
	m.collect("tea")
	m.stock()
	expect(m.d.goods.tea.shelf == 6 and m.d.quantity == 4,"capacity preserves remainder")
	m.put_back()
	expect(m.d.goods.tea.back == 4 and m.d.quantity == 0,"return remainder")
	m.expand()
	expect(not m.d.expanded,"upgrade gated by first receipt")
	m.toggle_open()
	expect(m.choose_product(1)=="tea","shopper finds affordable stock")
	for i in 8: m.set_price("tea",1)
	expect(m.choose_product(1)=="","shopper declines unaffordable shelf price")
	for i in 8: m.set_price("tea",-1)
	expect(m.reserve(1,"tea") and not m.reserve(1,"tea"),"one basket per visit")
	m.set_price("tea",1)
	m.checkout(1)
	expect(m.d.cash == 63 and m.d.revenue == 8 and m.d.goods.tea.sold == 1,"price fixed on selection")
	var state := m.d.duplicate(true)
	m.checkout(1)
	m.mark("sale")
	expect(m.d == state,"duplicate sale and reward ignored")
	m.expand()
	expect(m.d.expanded and m.capacity() == 12 and m.d.cash == 18,"purchase changes capacity and cash")
	m.expand()
	expect(m.d.cash == 18,"upgrade charged once")
	for i in 4:
		m.reserve(1,"tea")
		m.checkout(1)
	expect(m.d.cash == 59 and m.level() >= 2 and m.cost_of_sales() == 20,"repeat objective and cost of sales")
	m.reserve(1,"tea")
	m.toggle_open()
	expect(m.reservations.has(1) and not m.reserve(2,"tea"),"close retains last basket and blocks new reservations")
	m.checkout(1)
	while m.d.cash >= 20: m.order("tea")
	var cash: int = m.d.cash
	m.order("tea")
	expect(m.d.cash == cash,"insufficient funds leaves wallet intact")

func line_accounts() -> void:
	var m := Market.new()
	m.install_queue_lane()
	expect(not m.d.queue_lane and m.d.cash == 95,"lane requires first sale")
	m.order("tea")
	m.collect("tea")
	m.stock()
	m.toggle_open()
	m.reserve(1,"tea")
	m.checkout(1)
	m.install_queue_lane()
	m.install_queue_lane()
	expect(m.customer_limit() == 3 and m.d.cash == 51, "lane charged once")
	expect(m.reserve(2,"tea"),"first shopper selects tea")
	m.set_price("tea",1)
	expect(m.reserve(3,"tea") and m.reserve(4,"tea") and not m.reserve(5,"tea"), "three held units fill the lane")
	expect(m.on_display("tea") == 1, "held items disappear from display")
	var before := m.d.duplicate(true)
	m.checkout(3)
	expect(m.d == before and m.reservations.size() == 3, "out-of-order payment rejected")
	m.checkout(2)
	m.checkout(2)
	m.cancel_basket(3)
	m.checkout(4)
	expect(m.d.cash == 68 and m.d.receipt == 3 and m.on_display("tea") == 2, "per-visit prices, cancellation and duplicate payment")
	expect(m.reserve(5,"tea") and m.reserve(6,"tea") and not m.reserve(7,"tea") and m.available().is_empty(), "last unit cannot be promised twice")
	var loaded := Market.new()
	expect(loaded.restore(JSON.parse_string(JSON.stringify(m.d))) and loaded.on_display("tea") == 2 and loaded.d.queue_lane, "reload returns unpaid baskets and retains upgrade")
	m.toggle_open()
	expect(m.reservations.size() == 2 and m.on_display("tea") == 0 and m.d.cash == 68, "closure preserves queued sales")
	var old := m.d.duplicate(true)
	old.schema = 2
	old.erase("queue_lane")
	expect(loaded.restore(old) and loaded.customer_limit() == 1 and loaded.d.cash == 68,"schema 2 retains paid progress")
	var invalid := m.d.duplicate(true)
	invalid.queue_lane = "yes"
	expect(not loaded.restore(invalid),"malformed lane ownership rejected")

func persistence() -> void:
	var m := Market.new()
	var slot := Slot.new(prefix+".json")
	m.order("tea")
	expect(slot.save(m),"first save")
	var old := m.d.duplicate(true)
	m.collect("tea")
	expect(slot.save(m),"second save")
	var restored := Market.new()
	expect(slot.load_into(restored) and restored.d == m.d,"round trip")
	FileAccess.open(slot.path,FileAccess.WRITE).store_string("damaged")
	expect(slot.load_into(restored) and slot.recovery and restored.d == old,"backup recovery")
	expect(slot.save(restored),"recovered save can be committed")
	FileAccess.open(slot.path,FileAccess.WRITE).store_string('{"schema":900}')
	expect(not slot.load_into(restored) and slot.incompatible and not slot.save(restored),"future save protected")
	var v1 := old.duplicate(true)
	v1.schema = 1
	v1.erase("yaw")
	expect(restored.restore(v1) and restored.d.yaw == 0 and restored.d.schema == Market.SCHEMA and not restored.d.queue_lane,"v1 migration")
	var bad := old.duplicate(true)
	bad.goods.tea.shelf = -1
	expect(not restored.restore(bad),"reject negative stock")
	var prefs := Preferences.new(prefix+".cfg")
	prefs.values.invert = true
	prefs.values.fps = 60
	expect(prefs.save()==OK and Preferences.new(prefix+".cfg").values.fps==60 and Preferences.new(prefix+".cfg").values.invert,"settings round trip")
	clean(slot.path)
	clean(prefs.file)

func versions() -> void:
	expect(HarborUpdates.newer("v0.10.1","0.9.99") and not HarborUpdates.newer("v1.0.0","1.0.0"),"numeric versions")
	expect(HarborUpdates.numbers("v1.0.0-beta").is_empty(),"reject beta tag")
	var tag := "v0.2.0"
	var page := HarborUpdates.REPO+"/releases/tag/"+tag
	var asset := {"name":"Qofeno-Simulation-0.2.0.apk","size":1536,"browser_download_url":HarborUpdates.REPO+"/releases/download/"+tag+"/Qofeno-Simulation-0.2.0.apk"}
	var metadata := {"tag_name":tag,"html_url":page,"draft":false,"prerelease":false,"assets":[asset]}
	expect(HarborUpdates.inspect(200,metadata,"0.1.0")[1]==page,"verified official metadata")
	asset.browser_download_url = "https://example.org/test.apk"
	expect(HarborUpdates.inspect(200,metadata,"0.1.0")[1]=="","reject external asset")
	metadata.prerelease = true
	expect(HarborUpdates.inspect(200,metadata,"0.1.0")[1]=="","reject prerelease")
	for code in [0,403,404,429,500,200]:
		expect(HarborUpdates.inspect(code,null,"0.1.0")[1]=="","error handling "+str(code))

func click_caption(parent: Node, caption: String, use_pointer := false) -> bool:
	for widget in parent.find_children("*","Button",true,false):
		if widget.text.begins_with(caption):
			if use_pointer:
				var press := InputEventMouseButton.new()
				press.position = widget.get_global_rect().get_center()
				press.button_index = MOUSE_BUTTON_LEFT
				press.pressed = true
				root.push_input(press,true)
				var release := press.duplicate() as InputEventMouseButton
				release.pressed = false
				root.push_input(release,true)
			else: widget.pressed.emit()
			return true
	return false

func integration() -> void:
	var game = load("res://world/main.tscn").instantiate()
	game.slot = Slot.new(prefix+"-shift.json")
	root.add_child(game)
	await process_frame
	await process_frame
	expect(game.ui.screen=="menu","branded menu boot")
	expect(not game.directory.bind_operator("tide_hotel",Market.new()),"future property cannot bind an operator")
	expect(click_caption(game.ui.stage,"Start new",true) and game.ui.screen=="hud","new shift through menu")
	await physics_frame
	expect(game.directory.business("harbor_market")==game.market,"retail operator registered")
	expect(game.market.on_display("cocoa") == 3 and game.market.on_display("soap") == 4,"new lease includes seven sellable opening units")
	expect(game.player.first_person and not game.player.person.visible and game.player.arm.spring_length == 0,"eye-level view on first launch")
	game.player.set_view(false)
	expect(game.player.person.visible and game.player.arm.spring_length > 3,"third-person camera and character restored")
	game.player.set_view(true)
	game.player.stick = Vector2.UP
	for i in 245:
		game.player._physics_process(1.0/60)
	game.player.stick = Vector2.ZERO
	expect(game.player.position.z < -1.0 and game.player.is_on_floor(),"controller crosses the doorway on foot")
	for entry in [["computer",Vector3(4.6,0.08,-7.1)],["receiving",Vector3(-5.45,0.08,-1.38)],["display",Vector3(-4.55,0.08,-6.1)],["sign",Vector3(2.2,0.08,0.83)]]:
		game.player.position = entry[1]
		game.update_location()
		expect(game.nearest==entry[0],"reachable workstation "+entry[0])
		game.interact()
		match entry[0]:
			"computer":
				expect(click_caption(game.ui.stage,"Market"),"open the wholesale catalogue from desktop")
				await process_frame
				await process_frame
				var bounded := false
				for control in game.ui.stage.find_children("*","Button",true,false):
					if control.text == "Desktop": bounded = control.size.y < 65
				expect(bounded,"desk title bar leaves catalogue and cart visible")
				expect(click_caption(game.ui.stage,"Add carton") and click_caption(game.ui.stage,"Review order") and click_caption(game.ui.stage,"Place order"),"review and place supplier order")
				game.ui.hud()
			"receiving": expect(click_caption(game.ui.stage,"Collect Quayside"),"pickup from receiving")
			"display": expect(game.ui.screen=="hud" and game.market.d.quantity == 0,"stock carton directly on shop floor")
			"sign": expect(click_caption(game.ui.stage,"Open shop"),"open sign action")
	expect(game.market.d.open and game.market.d.goods.tea.shelf==5,"live stocked shop")
	var path_ok := true
	for i in 3600:
		game.flow.tick(1.0/60.0)
		if not game.flow.shoppers.is_empty():
			var p: Vector3 = game.flow.shoppers[0].person.position+Vector3.UP*0.7
			var q := PhysicsPointQueryParameters3D.new()
			q.position=p
			q.collision_mask=1
			if not game.get_world_3d().direct_space_state.intersect_point(q,1).is_empty(): path_ok=false
		if game.flow.ready_visit() != 0: break
	expect(path_ok and game.flow.ready_visit() != 0,"customer route clears fixed geometry and reaches till")
	game.player.position=Vector3(4.5,0.08,-1.9)
	game.update_location()
	game.interact()
	await process_frame
	await process_frame
	expect(click_caption(game.ui.stage,"Scan product"),"physical till scan")
	await process_frame
	await process_frame
	var pay_button: Button
	for control in game.ui.stage.find_children("*","Button",true,false):
		if control.text.begins_with("Take payment"): pay_button = control
	var receipt_width := 0.0
	for label in game.ui.body.find_children("*","Label",true,false):
		if label.text == "Quayside tea": receipt_width = label.size.x
	expect(receipt_width > 100 and pay_button != null and game.ui.body.get_parent().get_global_rect().encloses(pay_button.get_global_rect()),"basket name and payment fit inside the mobile till sheet")
	expect(click_caption(game.ui.stage,"Take payment") and game.market.d.receipt==1,"cashier completes customer sale")
	game.player.position=Vector3(4.6,0.08,-7.1)
	game.interact()
	expect(click_caption(game.ui.stage,"Management") and click_caption(game.ui.stage,"Install extension") and game.market.d.expanded,"desk installs upgrade")
	game.ui.hud()
	game.ui.map_view()
	expect(click_caption(game.ui.stage,"Tide Hotel") and game.waypoint==Vector2(-16,-5),"map waypoint")
	game.ui.hud()
	var g: HarborGestures = game.ui.gestures
	var press := InputEventScreenTouch.new()
	press.index=2
	press.pressed=true
	press.position=Vector2(75,330)
	g._gui_input(press)
	var drag := InputEventScreenDrag.new()
	drag.index=2
	drag.position=Vector2(75,270)
	g._gui_input(drag)
	expect(game.player.stick.y < -0.9,"floating stick drives motion")
	var initial: float = game.player.yaw
	var other := InputEventScreenTouch.new()
	other.index=3
	other.pressed=true
	other.position=Vector2(760,200)
	g._gui_input(other)
	var look := InputEventScreenDrag.new()
	look.index=3
	look.relative=Vector2(25,10)
	g._gui_input(look)
	expect(game.player.yaw != initial and game.player.stick.y < -0.9,"second finger looks independently")
	other.pressed=false
	g._gui_input(other)
	press.pressed=false
	g._gui_input(press)
	expect(game.player.stick==Vector2.ZERO,"release clears movement")
	game.ui.pause_menu()
	game.leave_shift()
	await process_frame
	await process_frame
	click_caption(game.ui.stage,"Continue",true)
	expect(game.market.d.receipt==1 and game.market.d.expanded and game.market.d.cash==38,"continue preserves entire paid shift")
	game.player.position = Vector3(4.6,0.08,-7.1)
	game.interact()
	expect(click_caption(game.ui.stage,"Management") and click_caption(game.ui.stage,"Install checkout lane") and game.market.d.cash == 6, "buy checkout lane from computer")
	game.ui.hud()
	exercise_lane(game)
	await test_road_and_day(game)
	game.show_menu()
	clean(game.slot.path)
	game.free()
	await process_frame

func exercise_lane(game: Node) -> void:
	var flow: CustomerFlow = game.flow
	var m: Market = game.market
	var probe := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.65
	probe.shape = capsule
	probe.collision_mask = 1
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var clear_paths := true
	for i in 1100:
		flow.tick(0.05)
		for shopper in flow.shoppers:
			probe.transform.origin = shopper.person.position + Vector3.UP * 0.85
			if not space.intersect_shape(probe,1).is_empty(): clear_paths = false
			for other in flow.shoppers:
				if other != shopper and other.person.position.distance_to(shopper.person.position) < 0.57:
					clear_paths = false
	expect(clear_paths and flow.shoppers.size() == 3 and flow.line.size() == 3,"three customers traverse clear aisles with body spacing")
	if flow.line.size() != 3: return
	for i in 3:
		expect(flow.line[i].person.position.is_equal_approx(flow.line_position(i)),"shopper reaches marked space "+str(i))
	var before_units := 0
	var display_units := 0
	for id in m.catalog:
		before_units += int(m.d.goods[id].shelf)
		display_units += m.on_display(id)
	expect(before_units - display_units == 3, "three actual shopper parcels leave the display")
	var first := flow.ready_visit()
	var second := flow.line[1].visit
	flow.serve(second)
	expect(m.d.receipt == 1 and flow.ready_visit() == first,"only the shopper at the register can pay")
	flow.serve(first)
	flow.serve(first)
	expect(m.d.receipt == 2 and flow.ready_visit() == 0, "next shopper must physically advance before paying")
	for i in 100: flow.tick(0.05)
	expect(flow.ready_visit() == second, "next shopper reaches register after head leaves")
	m.toggle_open()
	expect(flow.ready_visit() == second and m.reservations.size() == 2, "last baskets remain payable after closing")
	for i in 900:
		flow.tick(0.05)
		if flow.ready_visit(): flow.serve(flow.ready_visit())
	expect(flow.shoppers.is_empty() and m.reservations.is_empty(),"last customers pay and leave the closed shop")
	for cutoff in range(1,44):
		m = Market.opening_shift()
		m.d.queue_lane = true
		flow.reset(m)
		m.toggle_open()
		for i in cutoff*20: flow.tick(0.05)
		m.toggle_open()
		for i in 900:
			flow.tick(0.05)
			if flow.ready_visit(): flow.serve(flow.ready_visit())
		expect(flow.shoppers.is_empty() and m.reservations.is_empty(),"closed shop drains at second "+str(cutoff))


func test_road_and_day(game: Node) -> void:
	var m := Market.opening_shift()
	game.start(m)
	m.advance_clock(500)
	expect(m.d.clock == 480,"morning holds while preparing")
	m.edit_cart("tea",1)
	m.edit_cart("soap",1)
	expect(m.order_total(m.d.cart)==38,"mixed cart priced by units per carton")
	var invalid := {"tea":1,"soap":48}
	var before := m.d.duplicate(true)
	m.place_order(invalid)
	expect(m.d == before,"invalid mixed order moves no stock or money")
	m.place_order(m.d.cart)
	expect(m.d.cash==57 and m.d.goods.tea.back==5 and m.d.goods.soap.back==6 and m.d.cart.is_empty(),"single transaction delivers mixed cartons")
	var freight := Market.new()
	freight.place_order({"tea":2},true)
	expect(freight.d.cash==55 and freight.d.goods.tea.back==0 and freight.d.freight=="depot","prepaid pickup waits at depot")
	var depot_state := freight.d.duplicate(true)
	freight.transfer_freight("depot")
	expect(freight.d==depot_state,"loading needs the estate")
	freight.d.driving = true
	freight.transfer_freight("depot")
	var in_transit := Market.new()
	expect(in_transit.restore(JSON.parse_string(JSON.stringify(freight.d))) and in_transit.d.freight=="estate","cargo survives relaunch")
	in_transit.transfer_freight("market")
	in_transit.transfer_freight("market")
	expect(in_transit.d.goods.tea.back==10 and in_transit.d.cash==59 and in_transit.d.shipment.is_empty(),"unload and freight credit apply once")
	expect(game.district.loading_bay(Vector3(51,0,9))=="depot" and game.district.loading_bay(Vector3(28,0,9)).is_empty(),"only signed bays transfer cargo")
	m.toggle_open()
	m.reserve(99,"soap")
	m.advance_clock(1200)
	expect(m.d.clock == 1260 and not m.d.open and not m.can_finish(),"21:00 closes admissions while protecting a basket")
	m.checkout(99)
	m.toggle_lights()
	var dawn := Market.new()
	expect(dawn.restore(JSON.parse_string(JSON.stringify(m.d))) and not dawn.d.lights and dawn.d.clock==1260,"dark closed shift restores")
	expect(m.next_day() and not m.next_day() and m.d.day==2 and m.d.clock==480 and m.d.morning[2]==6,"daily settlement is idempotent")
	m.d.xp = 36
	m.buy_license()
	m.order("rice")
	expect(m.d.dry_goods and m.d.goods.rice.back==5,"licensed groceries reach receiving")
	m.d.cash = 30
	m.hire_cashier()
	m.toggle_open()
	for i in 1200: game.flow.tick(0.05)
	expect(m.d.cashier and m.d.receipt>1,"hired cashier serves a live shopper")
	var road: HarborRoad = game.road
	game.player.position=Vector3(-4.1,0.09,7.1)
	game.update_location()
	game.interact()
	expect(road.aboard and road.camera.current and not game.player.active,"board parked estate from street")
	var pads: HarborPedals = game.ui.pedals
	var boxes := pads.boxes()
	pads.contact(1,boxes[0].get_center(),true)
	pads.contact(2,boxes[3].get_center(),true)
	expect(road.inputs==Vector2(-1,1),"two fingers steer and accelerate independently")
	pads.contact(2,boxes[3].get_center(),false)
	expect(road.inputs==Vector2(-1,0),"lifting the accelerator retains steering")
	pads.release_all()
	expect(road.inputs==Vector2.ZERO,"pausing clears held pedals")
	var at := road.estate.position
	var traffic_at: Vector3 = road.traffic[0].position
	road.inputs = Vector2(0,1)
	for i in 90: road._physics_process(1.0/60)
	expect(road.estate.position.x > at.x+2 and road.estate.wheels.size()==4,"engine drives four animated wheels")
	expect(road.traffic[0].position.distance_to(traffic_at)>1,"traffic advances along the quay")
	road.inputs = Vector2(0.55,1)
	var heading := road.estate.rotation.y
	for i in 18: road._physics_process(1.0/60)
	expect(absf(road.estate.rotation.y-heading)>0.02,"steering changes heading while rolling")
	game.interact()
	expect(road.aboard,"moving car cannot be exited")
	game.save_shift()
	var parked := road.pose()
	game.resume_shift()
	expect(road.aboard and road.estate.position.distance_to(Vector3(parked[0],0.045,parked[1]))<0.001,"saved vehicle resumes with driver")
	game.interact()
	expect(not road.aboard and game.player.active and game.player.camera.current,"safe exit restores foot controls")
	m = game.market
	m.d.clock=1259.0
	m.advance_clock(2.0)
	game.district.time_of_day(m.d.clock)
	expect(game.district.night>0.99 and game.district.street_lights[0].visible,"street lighting follows closing time")
	await process_frame

func clean(path: String) -> void:
	for suffix in ["",".tmp",".bak",".writing"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
