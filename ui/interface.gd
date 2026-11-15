class_name HarborUI
extends CanvasLayer

const PAPER := Color("f7f3e8")
const MUTED := Color("b9c2c4")
const DARK := Color("172124")
const ACCENT := Color("f0be71")
const BODY_FONT := preload("res://assets/ui/type/Barlow-Regular.ttf")
const TITLE_FONT := preload("res://assets/ui/type/BarlowCondensed-SemiBold.ttf")
var safe := Control.new()
var stage := Control.new()
var shade: ColorRect
var body: VBoxContainer
var gestures: HarborGestures
var hud_stats: Label
var hud_task: Label
var interact: Button
var message: Label
var notice_time := 0.0
var desk := MarketDesk.new()
var scanned_visit := 0
var drawer := 0
var pedals: HarborPedals
var screen := ""
var app: Node

func _ready() -> void:
	var theme := Theme.new()
	theme.default_font = BODY_FONT
	safe.theme = theme
	add_child(safe)
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(stage)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(insets)
	insets()

func insets() -> void:
	if DisplayServer.get_name() == "headless" or not OS.has_feature("mobile"): return
	var area := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	var logical := get_viewport().get_visible_rect().size
	if win.x < 1 or win.y < 1 or area.size.x < 1: return
	var ratio := logical / Vector2(win)
	safe.offset_left = area.position.x*ratio.x
	safe.offset_top = area.position.y*ratio.y
	safe.offset_right = -(win.x-area.end.x)*ratio.x
	safe.offset_bottom = -(win.y-area.end.y)*ratio.y

func style(bg: Color, pad := 14, radius := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	for side in [SIDE_LEFT,SIDE_RIGHT]: s.set_content_margin(side,pad)
	for side in [SIDE_TOP,SIDE_BOTTOM]: s.set_content_margin(side,pad*0.62)
	return s

func text(parent: Control, content: String, font_size := 18, color := PAPER, display := false) -> Label:
	var l := Label.new()
	l.text = content
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",color)
	if display: l.add_theme_font_override("font",TITLE_FONT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l

func button(parent: Control, caption: String, action: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size = Vector2(0,46)
	b.add_theme_font_size_override("font_size",17)
	b.add_theme_color_override("font_color",DARK if primary else PAPER)
	b.add_theme_color_override("font_hover_color",DARK if primary else PAPER)
	b.add_theme_color_override("font_pressed_color",DARK if primary else PAPER)
	b.add_theme_stylebox_override("normal",style(ACCENT if primary else Color("303b3ef2")))
	b.add_theme_stylebox_override("hover",style(Color("f5c789") if primary else Color("465052")))
	b.add_theme_stylebox_override("pressed",style(Color("dfa765") if primary else Color("505953")))
	b.pressed.connect(func(): app.sound.cue("tap"); action.call())
	parent.add_child(b)
	return b

func row(parent: Control) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation",9)
	parent.add_child(line)
	return line

func clear(id: String) -> void:
	if is_instance_valid(gestures): gestures.reset()
	if is_instance_valid(pedals): pedals.release_all()
	pedals = null
	# Input dispatch may still reference the pressed button until this frame ends.
	# Hide the old screen now and let the engine retire its controls after dispatch.
	stage.hide()
	stage.queue_free()
	stage = Control.new()
	safe.add_child(stage)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen = id
	gestures = null
	hud_stats = null
	message = null
	app.set_playing(id == "hud")

func panel(parent: Control, fill: Color, pad := 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel",style(fill,pad))
	parent.add_child(p)
	return p

func column(parent: Control) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation",8)
	parent.add_child(v)
	return v

func anchor(n: Control, left: float, top: float, right: float, bottom: float, offsets: Rect2) -> void:
	n.anchor_left = left
	n.anchor_top = top
	n.anchor_right = right
	n.anchor_bottom = bottom
	n.offset_left = offsets.position.x
	n.offset_top = offsets.position.y
	n.offset_right = offsets.end.x
	n.offset_bottom = offsets.end.y

func scrim(parent: Control, from: Vector2, to: Vector2, colors: PackedColorArray) -> void:
	var fade := GradientTexture2D.new()
	fade.gradient = Gradient.new()
	fade.gradient.colors = colors
	fade.gradient.offsets = PackedFloat32Array([0.0,0.47,1.0])
	fade.fill_from = from
	fade.fill_to = to
	fade.width = 128
	fade.height = 8
	var cover := TextureRect.new()
	cover.texture = fade
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func quiet_button(parent: Control, caption: String, action: Callable) -> Button:
	var b := button(parent,caption,action)
	b.add_theme_stylebox_override("normal",style(Color("121a1cbb"),11,2))
	return b

func menu() -> void:
	clear("menu")
	scrim(stage,Vector2(0.12,0.86),Vector2(0.80,0.31),PackedColorArray([Color("10191df4"),Color("142126a5"),Color("16222600")]))
	var menu_stack := column(stage)
	anchor(menu_stack,0,1,0,1,Rect2(36,-316,395,292))
	menu_stack.add_theme_constant_override("separation",4)
	var title := text(menu_stack,"QOFENO",77,PAPER,true)
	title.add_theme_constant_override("line_spacing",-8)
	text(menu_stack,"SIMULATION",31,PAPER,true)
	var location := text(menu_stack,"Harbor Market  /  Waterfront district",18,PAPER)
	location.add_theme_color_override("font_outline_color",Color("172124e0"))
	location.add_theme_constant_override("outline_size",3)
	var actions := row(menu_stack)
	actions.add_theme_constant_override("separation",6)
	if app.slot.exists(): button(actions,"Continue shift",app.resume_shift,true)
	button(actions,"Start new shift",app.request_new,not app.slot.exists())
	var links := row(menu_stack)
	links.add_theme_constant_override("separation",3)
	quiet_button(links,"Settings",settings)
	quiet_button(links,"Updates",updates)
	quiet_button(links,"Credits",credits)
	var version_label := text(stage,"QOFENO   /   "+app.version,14,PAPER,true)
	anchor(version_label,1,1,1,1,Rect2(-171,-38,146,26))
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_notice()

func hud() -> void:
	clear("hud")
	if app.road.aboard:
		pedals = HarborPedals.new()
		stage.add_child(pedals)
		pedals.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pedals.moved.connect(func(value: Vector2): app.road.inputs = value)
	else:
		gestures = HarborGestures.new()
		stage.add_child(gestures)
		gestures.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		gestures.moved.connect(func(value: Vector2): app.player.stick = value)
		gestures.looked.connect(func(value: Vector2): app.player.turn(value,app.prefs.values))
	# Restrict contrast backing to the corners, leaving the player's view clear.
	var compass := Control.new()
	stage.add_child(compass)
	compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor(compass,0,0,0,0,Rect2(0,0,400,84))
	scrim(compass,Vector2(0.06,0.1),Vector2(0.9,0.88),PackedColorArray([Color("10191edb"),Color("14202783"),Color("14202700")]))
	hud_stats = text(stage,"",23,PAPER,true)
	anchor(hud_stats,0,0,0,0,Rect2(18,8,360,30))
	hud_stats.add_theme_color_override("font_shadow_color",Color("162027"))
	hud_stats.add_theme_constant_override("shadow_offset_y",1)
	hud_task = text(stage,"",16,PAPER)
	anchor(hud_task,0,0,0,0,Rect2(18,39,380,36))
	hud_task.add_theme_color_override("font_outline_color",Color("182121d6"))
	hud_task.add_theme_constant_override("outline_size",3)
	var top := row(stage)
	anchor(top,1,0,1,0,Rect2(-149,10,136,46))
	quiet_button(top,"Map",map_view)
	quiet_button(top,"Pause",pause_menu)
	if app.prefs.values.first_person and not app.road.aboard:
		var dot := Panel.new()
		stage.add_child(dot)
		anchor(dot,0.5,0.5,0.5,0.5,Rect2(-2.3,-2.3,4.6,4.6))
		var sight := style(Color("f4f0e0cf"),0,3)
		sight.set_border_width_all(1)
		sight.border_color = Color("243030a0")
		dot.add_theme_stylebox_override("panel",sight)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interact = button(stage,"Interact",app.interact,true)
	anchor(interact,1,1,1,1,Rect2(-215,-70,199,51))
	if app.road.aboard:
		anchor(interact,1,1,1,1,Rect2(-137,-174,119,49))
		var transfer := button(stage,"Load cartons",app.handle_freight,true)
		transfer.name = "Freight"
		anchor(transfer,1,1,1,1,Rect2(-324,-174,177,49))
	var run := quiet_button(stage,"Run",func(): app.player.running = not app.player.running; refresh())
	run.name = "Pace"
	run.visible = not app.road.aboard
	anchor(run,1,1,1,1,Rect2(-105,-122,89,46))
	add_notice()
	refresh()

func add_notice() -> void:
	message = Label.new()
	stage.add_child(message)
	anchor(message,0.5,1,0.5,1,Rect2(-245,-160,490,63))
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_stylebox_override("normal",style(Color("203e3ef5"),8))
	message.add_theme_color_override("font_color",PAPER)
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message.hide()

func toast(words: String) -> void:
	if not is_instance_valid(message): return
	message.text = words
	message.show()
	notice_time = 3.2

func _process(dt: float) -> void:
	if is_instance_valid(message) and message.visible:
		notice_time -= dt
		if notice_time <= 0: message.hide()

func refresh() -> void:
	if screen != "hud" or not is_instance_valid(hud_stats): return
	var m: Market = app.market
	var minutes := int(m.d.clock)
	hud_stats.text = "Day %d    %02d:%02d    /    $%d" % [m.d.day,minutes/60,minutes%60,m.d.cash]
	if app.road.aboard:
		hud_task.text = "%02d km/h   ·   Quay Road" % roundi(absf(app.road.estate.speed)*3.6)
		interact.visible = true
		interact.text = "Get out"
		var freight := stage.get_node("Freight") as Button
		var bay: String = app.district.loading_bay(app.road.estate.position)
		freight.visible = (bay=="depot" and m.d.freight=="depot") or (bay=="market" and m.d.freight=="estate")
		freight.text = "Load cartons" if bay=="depot" else "Unload cartons"
		if m.d.freight=="depot": hud_task.text += "   /   East Pier Wholesale →"
		if m.d.freight=="estate": hud_task.text += "   /   Return to Harbor Market"
		return
	hud_task.text = m.objective() if app.prefs.values.hints else "Harbor District"
	if minutes >= Market.CLOSING: hud_task.text = "Closing time · Finish trading at the door sign"
	if m.d.quantity: hud_task.text += "  •  Carrying %d" % m.d.quantity
	interact.visible = app.nearest != ""
	if interact.visible:
		interact.text = District.NAMES[app.nearest]
		if app.nearest == "display" and m.d.quantity > 0:
			interact.text = "Stock %d × %s" % [m.d.quantity,m.catalog[m.d.carry].name]
		elif app.nearest == "computer": interact.text = "Use market desk"
		if app.nearest == "till" and app.flow.ready_visit() != 0:
			interact.text = "Checkout  ·  %d" % app.flow.line.size()
	(stage.get_node("Pace") as Button).text = "Walk" if app.player.running else "Run"

func sheet(id: String, eyebrow: String, title: String, back: Callable) -> void:
	clear(id)
	shade = ColorRect.new()
	shade.color = Color("10171980")
	stage.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame := panel(stage,Color("192326fa"),18)
	if id in ["till","sign","receiving","display"]:
		anchor(frame,1,0.08,1,0.92,Rect2(-365,0,348,0))
	elif id == "pause":
		anchor(frame,0,0.06,0,0.94,Rect2(20,0,340,0))
	else:
		anchor(frame,0.09,0.045,0.91,0.955,Rect2())
	var stack := column(frame)
	var bar := row(stack)
	var section := text(bar,eyebrow,14,ACCENT)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quiet_button(bar,"Back",back)
	text(stack,title,30,PAPER,true)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	body = column(scroll)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_notice()

func back() -> void:
	match screen:
		"hud": pause_menu()
		"menu": return
		"settings","updates","credits": pause_menu() if app.in_shift else menu()
		"new": menu()
		"terminal":
			if desk.current == "Desktop": hud()
			elif desk.current == "Cart": terminal("Market")
			else: terminal()
		"daily": station("sign")
		"receiving","display","till","sign","map","pause": hud()
		"exit": pause_menu()
		_: menu()

func confirm_new() -> void:
	sheet("new","SAVE SLOT","Start a new shift?",menu)
	text(body,"This replaces your current shift and its recovery copy with a fresh market.")
	button(body,"Start fresh",app.new_shift,true)

func pause_menu() -> void:
	sheet("pause","HARBOR MARKET","Shift paused",hud)
	button(body,"Resume shift",hud,true)
	button(body,"Save now",func(): toast(app.save_shift()))
	var r := row(body)
	button(r,"Settings",settings)
	button(r,"Updates",updates)
	button(r,"Credits",credits)
	button(body,"Return to main menu",leave_dialog)

func leave_dialog() -> void:
	sheet("exit","SAVE SLOT","Leave this shift?",pause_menu)
	text(body,"Save your position, stock and accounts before returning to the waterfront.")
	button(body,"Save and return",app.leave_shift,true)
	button(body,"Stay in shift",pause_menu)

func settings() -> void:
	sheet("settings","PREFERENCES","Settings",back)
	var p: Dictionary = app.prefs.values
	var options := [["quality","Graphics",["Low","Standard","High"]],["fps","Frame limit",[30,60]],
		["volume","Master volume",[0,25,50,75,100]],["ambience","Harbor ambience",[0,20,40,70,100]],
		["music","Menu music",[0,25,50,75,100]],["effects","Shop effects",[0,25,50,75,100]],["ui","Interface volume",[0,25,50,75,100]],
		["first_person","First-person camera",[true,false]],["sensitivity","Look sensitivity",[20,45,65,85,100]],["invert","Invert vertical look",[false,true]],
		["hints","Objective hints",[false,true]],["autosave","Timed autosave",[false,true]]]
	for opt in options:
		var id: String = opt[0]
		var choices: Array = opt[2]
		var v: Variant = p[id]
		var visible_value: Variant = choices[v] if id=="quality" else v
		var caption := str(visible_value)
		if v is bool: caption = "On" if v else "Off"
		button(body,"%s    ·    %s" % [opt[1],caption],func():
			if id=="quality": p[id] = (int(p[id])+1)%3
			else: p[id] = choices[(choices.find(p[id])+1)%choices.size()]
			var err: Error = app.prefs.save()
			app.prefs.apply(get_viewport(),app.district.sun)
			app.player.set_view(p.first_person)
			settings()
			if err != OK: toast("Settings could not be saved."))

func updates() -> void:
	sheet("updates","GITHUB RELEASES","Game updates",back)
	text(body,"Installed "+app.version+"   •   Stable release channel")
	if OS.has_feature("android") and OS.is_debug_build():
		text(body,"Internal test edition. A stable APK installs separately and starts its own save slot.",16,ACCENT)
	text(body,"Check when you choose. Installation takes place on the official GitHub release page.",17,MUTED)
	button(body,"Check for updates",func():
		toast("Checking GitHub…")
		app.updater.check(),true)

func update_result(details: String, link: String) -> void:
	if screen != "updates": return
	updates()
	text(body,details,17)
	if link != "": button(body,"Open official release",func(): OS.shell_open(link),true)

func credits() -> void:
	sheet("credits","QOFENO SIMULATION","Credits",back)
	text(body,"Harbor District • Original streets, storefronts, products, interface and synthesized audio.")
	text(body,"People by Quaternius. Sky, scanned surfaces, apple and crate from Poly Haven (CC0). Barlow and Barlow Condensed by Jeremy Tribby (SIL OFL). Built with Godot Engine (MIT).",17,MUTED)
	button(body,"Engine and third-party licenses",func(): OS.shell_open("https://godotengine.org/license/"))

func product_photo(parent: Control, id: String, box: Vector2) -> void:
	var picture := TextureRect.new()
	picture.texture = District.PACK_PRINT[id]
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = box
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(picture)

func terminal(page := "Desktop") -> void:
	desk.open(self,page)

func daily_report() -> void:
	var m: Market = app.market
	sheet("daily","HARBOR MARKET","Day %d  ·  Closing statement" % m.d.day,station.bind("sign"))
	var opening: Array = m.d.morning
	text(body,"Opening cash     $%d" % opening[0],19)
	text(body,"Customer payments     %d     /     $%d" % [m.d.receipt-opening[1],m.d.revenue-opening[2]],19)
	text(body,"Stock purchased     $%d" % [m.d.spend-opening[3]],19)
	text(body,"Net cash change     $%d" % [m.d.cash-opening[0]],19)
	text(body,"Closing cash     $%d" % m.d.cash,26,ACCENT,true)
	button(body,"Start day %d" % (m.d.day+1),func():
		if not m.next_day(): return
		scanned_visit = 0
		app.flow.reset(m)
		app.district.time_of_day(m.d.clock)
		app.road.set_lighting(app.district.night)
		app.save_shift(true)
		hud()
		toast("08:00 · The shop is ready for a new day."),true)

func station(id: String) -> void:
	var m: Market = app.market
	sheet(id,"HARBOR MARKET",District.NAMES[id],hud)
	match id:
		"receiving":
			if m.d.quantity:
				text(body,"Carrying %d × %s" % [m.d.quantity,m.catalog[m.d.carry].name])
				button(body,"Return carton",world_action.bind(m.put_back))
			else:
				for key in m.catalog:
					if not m.licensed(key): continue
					button(body,"Collect %s    ·    %d available" % [m.catalog[key].name,m.d.goods[key].back],world_action.bind(m.collect.bind(key)))
		"display":
			text(body,"Display capacity   %d per product" % m.capacity())
			for key in m.catalog:
				if not m.licensed(key): continue
				text(body,"%s   ·   %d on shelf" % [m.catalog[key].name,m.on_display(key)],17,MUTED)
			button(body,"Stock carried carton",world_action.bind(m.stock),true)
		"sign":
			text(body,"Day %d   ·   Trading hours 08:00–21:00" % m.d.day)
			if m.d.clock < Market.CLOSING:
				button(body,"Close shop" if m.d.open else "Open shop",world_action.bind(m.toggle_open),true)
			button(body,"Turn shop lights %s" % ("off" if m.d.lights else "on"),world_action.bind(m.toggle_lights))
			if m.can_finish(): button(body,"Review and finish day",daily_report,true)
			elif not m.d.open and not m.reservations.is_empty(): text(body,"Serve the remaining baskets before finishing the day.",17,MUTED)
		"till":
			var visit: int = app.flow.ready_visit()
			if visit:
				var item: Dictionary = m.reservations[visit]
				var basket_row := row(body)
				product_photo(basket_row,item.id,Vector2(65,81))
				var receipt := column(basket_row)
				receipt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				text(receipt,m.catalog[item.id].name,24,PAPER,true)
				text(receipt,"1 item    /    $%d each" % item.price,16,MUTED)
				text(body,"Total    $%d.00" % item.price,31,PAPER,true)
				if app.flow.line.size() > 1:
					text(body,"%d more in line" % (app.flow.line.size()-1),17,MUTED)
				if scanned_visit != visit:
					button(body,"Scan product",func():
						scanned_visit = visit
						drawer = 0
						app.sound.cue("scan")
						station("till"),true)
				elif visit % 2 == 1:
					text(body,"Card presented · charge the scanned total.",17,MUTED)
					button(body,"Take payment    $%d" % item.price,world_action.bind(app.flow.serve.bind(visit)),true)
				else:
					var tender := ceili(item.price/5.0)*5
					text(body,"Cash tendered   $%d" % tender,18)
					var change := row(body)
					button(change,"Less $1",func(): drawer = maxi(0,drawer-1); station("till"))
					text(change,"Change $%d" % drawer,18).autowrap_mode = TextServer.AUTOWRAP_OFF
					button(change,"Add $1",func(): drawer = mini(tender,drawer+1); station("till"))
					button(body,"Take payment    $%d" % item.price,world_action.bind(app.flow.serve.bind(visit)),true).disabled = drawer != tender-int(item.price)
			elif app.flow.line.is_empty(): text(body,"A shopper will wait here after choosing a product.")
			else: text(body,"The next shopper is approaching. Return to the shop floor to let them reach the till.")

func world_action(action: Callable) -> void:
	var feedback: String = action.call()
	if screen == "till": scanned_visit = 0
	app.player.person.hands.gesture(screen,0.9)
	app.sound.cue("coin" if screen=="till" else ("door" if screen=="sign" else "crate"))
	hud()
	toast(feedback)

func map_view() -> void:
	sheet("map","HARBOR DISTRICT","Waterfront map",hud)
	var map := HarborAtlas.new()
	map.places = app.directory.entries.duplicate()
	map.places.append({"name":"East Pier Wholesale","x":District.DEPOT.x,"z":5.0,"playable":false,"supplier":true})
	map.player_pos = app.road.estate.position if app.road.aboard else app.player.position
	map.target = app.waypoint
	map.car_pos = app.road.estate.position
	map.custom_minimum_size.y = 156
	body.add_child(map)
	text(body,"White dot · You      Blue car · Estate      Copper ring · Destination",15,MUTED)
	for place in map.places:
		button(body,place.name + ("   ·   Loading bay" if place.get("supplier",false) else ("   ·   Your shop" if place.playable else "   ·   Future premises")),func():
			app.waypoint = Vector2(place.x,place.z)
			map.target = app.waypoint
			map.queue_redraw())
