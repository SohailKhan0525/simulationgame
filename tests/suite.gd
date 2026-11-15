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
	persistence()
	versions()
	await integration()
	print("QOFENO CHECKS: %d passed, %d failed" % [n-failures.size(),failures.size()])
	quit(0 if failures.is_empty() else 1)

func economy() -> void:
	var m := Market.new()
	m.toggle_open()
	expect(not m.d.open,"cannot open empty shop")
	expect(not m.reserve("tea"),"closed shop cannot reserve")
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
	expect(m.reserve("tea") and not m.reserve("tea"),"one active basket")
	m.set_price("tea",1)
	m.checkout()
	expect(m.d.cash == 63 and m.d.revenue == 8 and m.d.goods.tea.sold == 1,"price fixed on selection")
	var state := m.d.duplicate(true)
	m.checkout()
	m.mark("sale")
	expect(m.d == state,"duplicate sale and reward ignored")
	m.expand()
	expect(m.d.expanded and m.capacity() == 12 and m.d.cash == 18,"purchase changes capacity and cash")
	m.expand()
	expect(m.d.cash == 18,"upgrade charged once")
	for i in 4:
		m.reserve("tea")
		m.checkout()
	expect(m.d.cash == 59 and m.level() >= 2 and m.cost_of_sales() == 20,"repeat objective and cost of sales")
	m.reserve("tea")
	m.toggle_open()
	expect(m.basket == "" and m.d.goods.tea.shelf == 1,"close releases reserved item")
	while m.d.cash >= 20: m.order("tea")
	var cash: int = m.d.cash
	m.order("tea")
	expect(m.d.cash == cash,"insufficient funds leaves wallet intact")

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
	expect(restored.restore(v1) and restored.d.yaw == 0 and restored.d.schema == 2,"v1 migration")
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
	game.player.stick = Vector2.UP
	for i in 195:
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
				expect(click_caption(game.ui.stage,"Orders") and click_caption(game.ui.stage,"Order 5"),"shop computer order")
				game.ui.hud()
			"receiving": expect(click_caption(game.ui.stage,"Collect Quayside"),"pickup from receiving")
			"display": expect(click_caption(game.ui.stage,"Stock carried"),"display action")
			"sign": expect(click_caption(game.ui.stage,"Open shop"),"open sign action")
	expect(game.market.d.open and game.market.d.goods.tea.shelf==5,"live stocked shop")
	var path_ok := true
	for i in 3600:
		game.flow.tick(1.0/60.0)
		if game.flow.person:
			var p: Vector3 = game.flow.person.position+Vector3.UP*0.7
			var q := PhysicsPointQueryParameters3D.new()
			q.position=p
			q.collision_mask=1
			if not game.get_world_3d().direct_space_state.intersect_point(q,1).is_empty(): path_ok=false
		if game.flow.phase==CustomerFlow.Phase.WAITING: break
	expect(path_ok and game.flow.phase==CustomerFlow.Phase.WAITING,"customer route clears fixed geometry and reaches till")
	game.player.position=Vector3(4.5,0.08,-1.9)
	game.update_location()
	game.interact()
	expect(click_caption(game.ui.stage,"Take payment") and game.market.d.receipt==1,"cashier completes customer sale")
	game.player.position=Vector3(4.6,0.08,-7.1)
	game.interact()
	expect(click_caption(game.ui.stage,"Upgrade") and click_caption(game.ui.stage,"Install extension") and game.market.d.expanded,"desk installs upgrade")
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
	game.show_menu()
	clean(game.slot.path)
	game.free()
	await process_frame

func clean(path: String) -> void:
	for suffix in ["",".tmp",".bak",".writing"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
