class_name HarborUI
extends CanvasLayer

const PAPER := Color("f8edd6")
const MUTED := Color("bbccba")
const DARK := Color("123537")
const ACCENT := Color("f2bb78")
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
var screen := ""
var app: Node
var display_font := SystemFont.new()

func _ready() -> void:
	display_font.font_names = PackedStringArray(["Georgia","Noto Serif","DejaVu Serif","serif"])
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

func style(bg: Color, pad := 14, radius := 6) -> StyleBoxFlat:
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
	if display: l.add_theme_font_override("font",display_font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l

func button(parent: Control, caption: String, action: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size = Vector2(0,43)
	b.add_theme_font_size_override("font_size",17)
	b.add_theme_color_override("font_color",DARK if primary else PAPER)
	b.add_theme_color_override("font_hover_color",DARK if primary else PAPER)
	b.add_theme_color_override("font_pressed_color",DARK if primary else PAPER)
	b.add_theme_stylebox_override("normal",style(ACCENT if primary else Color("295153")))
	b.add_theme_stylebox_override("hover",style(Color("f5c789") if primary else Color("386360")))
	b.add_theme_stylebox_override("pressed",style(Color("dfa765") if primary else Color("3c6862")))
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
	for c in stage.get_children():
		stage.remove_child(c)
		c.queue_free()
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

func menu() -> void:
	clear("menu")
	var p := panel(stage,Color("143c3df7"),25)
	anchor(p,0,0,0,1,Rect2(0,0,365,0))
	var sc := ScrollContainer.new()
	p.add_child(sc)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := column(sc)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text(v,"Q  /  HARBOR DISTRICT",15,ACCENT)
	text(v,"Qofeno\nSimulation",46,PAPER,true)
	text(v,"Run a neighborhood market on the waterfront.",19,MUTED)
	if app.slot.exists(): button(v,"Continue shift",app.resume_shift,true)
	button(v,"Start new shift",app.request_new,not app.slot.exists())
	var r := row(v)
	button(r,"Settings",settings)
	button(r,"Updates",updates)
	button(v,"Credits",credits)
	text(v,"Harbor Market   •   "+app.version,14,MUTED)
	add_notice()

func hud() -> void:
	clear("hud")
	gestures = HarborGestures.new()
	stage.add_child(gestures)
	gestures.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gestures.moved.connect(func(value: Vector2): app.player.stick = value)
	gestures.looked.connect(func(value: Vector2): app.player.turn(value,app.prefs.values))
	var p := panel(stage,Color("123537e9"),12)
	anchor(p,0,0,0,0,Rect2(12,10,382,62))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := column(p)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation",1)
	hud_stats = text(v,"",17,ACCENT)
	hud_task = text(v,"",15,PAPER)
	var top := row(stage)
	anchor(top,1,0,1,0,Rect2(-185,10,172,43))
	button(top,"Map",map_view)
	button(top,"Pause",pause_menu)
	interact = button(stage,"Interact",app.interact,true)
	anchor(interact,1,1,1,1,Rect2(-215,-70,199,51))
	var run := button(stage,"Walk / run",func(): app.player.running = not app.player.running; refresh())
	run.name = "Pace"
	anchor(run,1,1,1,1,Rect2(-129,-123,113,44))
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
	hud_stats.text = "$%d   •   Level %d   •   %02d:%02d   •   %s" % [m.d.cash,m.level(),minutes/60,minutes%60,"Open" if m.d.open else "Closed"]
	hud_task.text = m.objective() if app.prefs.values.hints else "Harbor District"
	if m.d.quantity: hud_task.text += "  •  Carrying %d" % m.d.quantity
	interact.visible = app.nearest != ""
	if interact.visible: interact.text = District.NAMES[app.nearest]
	(stage.get_node("Pace") as Button).text = "Running" if app.player.running else "Walking"

func sheet(id: String, eyebrow: String, title: String, back: Callable) -> void:
	clear(id)
	shade = ColorRect.new()
	shade.color = Color("091e29b6")
	stage.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame := panel(stage,DARK,21)
	anchor(frame,0.12,0.045,0.88,0.955,Rect2())
	var stack := column(frame)
	var bar := row(stack)
	var section := text(bar,eyebrow,14,ACCENT)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(bar,"Back",back)
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
		"terminal","receiving","display","till","sign","map","pause": hud()
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
		["sensitivity","Look sensitivity",[20,45,65,85,100]],["invert","Invert vertical look",[false,true]],
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
			settings()
			if err != OK: toast("Settings could not be saved."))

func updates() -> void:
	sheet("updates","GITHUB RELEASES","Game updates",back)
	text(body,"Installed "+app.version+"   •   Stable release channel")
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
	text(body,"Man and Woman Casual by Quaternius, CC0. Built with Godot Engine (MIT).",17,MUTED)
	button(body,"Engine and third-party licenses",func(): OS.shell_open("https://godotengine.org/license/"))

func terminal(tab := "Overview") -> void:
	sheet("terminal","HARBOR OS  /  SHOP COMPUTER","Market desk",hud)
	var m: Market = app.market
	var tabs := row(body)
	for key in ["Overview","Orders","Prices","Reports","Upgrade"]:
		button(tabs,key,terminal.bind(key),key==tab)
	match tab:
		"Overview":
			text(body,"Cash  $%d     •     XP  %d     •     Level  %d" % [m.d.cash,m.d.xp,m.level()],22)
			text(body,m.objective(),19,ACCENT)
			for id in m.catalog:
				var g: Dictionary = m.d.goods[id]
				text(body,"%s   •   %d at receiving   /   %d on display" % [m.catalog[id].name,g.back,g.shelf],17,MUTED)
			text(body,"Pick up deliveries at the front-left pallet. Place them on the rear-left display. Use the door sign to start trading.",16)
		"Orders":
			text(body,"Supplier delivers to receiving immediately. Cash available $%d." % m.d.cash,17,MUTED)
			for id in m.catalog:
				var item: Dictionary = m.catalog[id]
				button(body,"Order %d × %s     $%d" % [item.pack,item.name,item.cost*item.pack],transaction.bind(m.order.bind(id),tab))
		"Prices":
			for id in m.catalog:
				var line := row(body)
				var info := text(line,"%s   $%d" % [m.catalog[id].name,m.d.goods[id].price])
				info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				button(line,"− $1",transaction.bind(m.set_price.bind(id,-1),tab))
				button(line,"+ $1",transaction.bind(m.set_price.bind(id,1),tab))
		"Reports":
			text(body,"Revenue  $%d    •    Gross profit  $%d" % [m.d.revenue,m.d.revenue-m.cost_of_sales()],21)
			text(body,"Stock purchased $%d   •   Cost of goods sold $%d   •   %d sales" % [m.d.spend,m.cost_of_sales(),m.d.receipt],16,MUTED)
			for id in m.catalog: text(body,"%s sold   %d" % [m.catalog[id].name,m.d.goods[id].sold],16)
			for entry in m.d.log: text(body,"Receipt %03d    %s    +$%d" % [entry.n,m.catalog[entry.id].name,entry.paid],16,MUTED)
		"Upgrade":
			text(body,"Display extension",22)
			text(body,"Adds a second row on every shelf. Capacity rises from six to twelve units per product. Unlocks after the first sale.",17,MUTED)
			if m.d.expanded: text(body,"Installed",19,ACCENT)
			else: button(body,"Install extension    $45",transaction.bind(m.expand,tab),true)

func transaction(action: Callable, tab: String) -> void:
	var info: String = action.call()
	terminal(tab)
	toast(info)

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
					button(body,"Collect %s    ·    %d available" % [m.catalog[key].name,m.d.goods[key].back],world_action.bind(m.collect.bind(key)))
		"display":
			text(body,"Display capacity   %d per product" % m.capacity())
			for key in m.catalog: text(body,"%s   ·   %d on shelf" % [m.catalog[key].name,m.d.goods[key].shelf],17,MUTED)
			button(body,"Stock carried carton",world_action.bind(m.stock),true)
		"sign":
			text(body,"Customers browse stocked products, then bring a basket to the till.")
			button(body,"Close shop" if m.d.open else "Open shop",world_action.bind(m.toggle_open),true)
		"till":
			if app.flow.phase == CustomerFlow.Phase.WAITING:
				text(body,"%s    × 1" % m.catalog[m.basket].name)
				button(body,"Take payment    $%d" % m.quote,world_action.bind(app.flow.serve),true)
			else: text(body,"The till is clear. A shopper will wait here after choosing a product.")

func world_action(action: Callable) -> void:
	var feedback: String = action.call()
	app.sound.cue("coin" if screen=="till" else "crate")
	hud()
	toast(feedback)

func map_view() -> void:
	sheet("map","HARBOR DISTRICT","Waterfront map",hud)
	var map := HarborAtlas.new()
	map.player_pos = app.player.position
	map.target = app.waypoint
	map.custom_minimum_size.y = 156
	body.add_child(map)
	text(body,"White dot • your position     Copper ring • selected destination",15,MUTED)
	for place in map.places:
		button(body,place.name + ("   ·   Your shop" if place.playable else "   ·   Future premises"),func():
			app.waypoint = Vector2(place.x,place.z)
			map.target = app.waypoint
			map.queue_redraw())
