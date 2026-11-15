class_name MarketDesk
extends RefCounted

const INK := Color("193637")
const SUB := Color("485f60")
const PAPER := Color("edf0e9")
const WHITE := Color("fafaf4")
const BLUE := Color("1f6065")
const WALL := preload("res://ui/desk_wallpaper.gd")
var ui: HarborUI
var m: Market
var current := "Desktop"
var category := "All"

func open(host: HarborUI, page: String) -> void:
	ui = host
	m = ui.app.market
	current = page
	ui.clear("terminal")
	var background := WALL.new()
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.stage.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if page == "Desktop": desktop()
	else: window()
	ui.add_notice()

func desktop() -> void:
	var desk := ui.column(ui.stage)
	ui.anchor(desk,0,0,0,0,Rect2(27,24,280,300))
	ui.text(desk,"Harbor workstation",25,Color.WHITE,true)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",9)
	grid.add_theme_constant_override("v_separation",9)
	desk.add_child(grid)
	for app_name in ["Market","Pricing","Management","Ledger"]:
		var shortcut := ui.button(grid,app_name,ui.terminal.bind(app_name))
		shortcut.custom_minimum_size = Vector2(117,82)
		var tile := ui.style(Color("27494dee"),8,3)
		tile.content_margin_top = 42
		for state in ["normal","hover","pressed"]:
			var skin := tile.duplicate() as StyleBoxFlat
			if state != "normal": skin.bg_color = Color("3c6163")
			shortcut.add_theme_stylebox_override(state,skin)
		var icon: Control = preload("res://ui/desk_icon.gd").new()
		icon.application = app_name
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shortcut.add_child(icon)
		ui.anchor(icon,0,0,1,0,Rect2(0,6,0,38))
	var panel := ui.panel(ui.stage,Color("203b40eb"),14)
	ui.anchor(panel,0,1,1,1,Rect2(0,-63,0,63))
	var bar := ui.row(panel)
	var clock := ui.text(bar,"Harbor OS     /     Day %d      %02d:%02d" % [m.d.day,int(m.d.clock)/60,int(m.d.clock)%60],18,Color.WHITE,true)
	clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.quiet_button(bar,"Leave desk",ui.hud)

func window() -> void:
	var frame := ui.panel(ui.stage,PAPER,12)
	ui.anchor(frame,0,0,1,1,Rect2(12,10,-24,-20))
	var stack := ui.column(frame)
	var head := ui.panel(stack,Color("25474b"),6)
	var top := ui.row(head)
	ui.button(top,"Desktop",ui.terminal)
	var title := ui.text(top,current if current != "Cart" else "Review purchase",26,Color.WHITE,true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var wallet := ui.text(top,"Funds   $%d" % m.d.cash,19,Color.WHITE,true)
	wallet.autowrap_mode = TextServer.AUTOWRAP_OFF
	ui.button(top,"Leave desk",ui.hud)
	var line := ColorRect.new()
	line.color = Color("a7bcb7")
	line.custom_minimum_size.y = 2
	stack.add_child(line)
	if current == "Market":
		catalogue(stack)
		return
	var body := scroll(stack)
	match current:
		"Cart": review(body)
		"Management":
			ui.text(body,"Staff and licences",25,INK,true)
			var staff := ui.row(ui.panel(body,WHITE,10))
			var terms := ui.text(staff,"Cashier · serves waiting shoppers until close",18,INK)
			terms.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ui.button(staff,"On shift" if m.d.cashier else "Hire for $12",action.bind(m.hire_cashier)).disabled = m.d.cashier
			var licence := ui.row(ui.panel(body,WHITE,10))
			var range_name := ui.text(licence,"Dry goods · oats, pasta and rice · Level 2",18,INK)
			range_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ui.button(licence,"Licensed" if m.d.dry_goods else "Buy licence $36",action.bind(m.buy_license)).disabled = m.d.dry_goods
			ui.text(body,"Store fittings",25,INK,true)
			for spec in [["Display extension","Increase every display from six to twelve spaces.",m.d.expanded,Market.EXPANSION,m.expand],["Checkout lane","Give three shoppers room to queue for the till.",m.d.queue_lane,Market.QUEUE_LANE_COST,m.install_queue_lane]]:
				var card := ui.column(ui.panel(body,WHITE,12))
				ui.text(card,spec[0],22,INK,true)
				ui.text(card,spec[1],17,SUB)
				if spec[2]: ui.text(card,"Installed",17,BLUE,true)
				else: ui.button(card,"Install %s    $%d" % ["extension" if spec[0]=="Display extension" else "checkout lane",spec[3]],action.bind(spec[4]))
		"Pricing":
			ui.text(body,"Shelf labels",24,INK,true)
			for id in m.catalog:
				if not m.licensed(id): continue
				var row := ui.row(ui.panel(body,WHITE,10))
				ui.product_photo(row,id,Vector2(40,49))
				var info := ui.column(row)
				info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				ui.text(info,m.catalog[id].name,20,INK,true)
				ui.text(info,"Cost $%d   /   Display %d   /   Receiving %d" % [m.catalog[id].cost,m.on_display(id),m.d.goods[id].back],16,SUB)
				ui.button(row,"− $1",action.bind(m.set_price.bind(id,-1)))
				ui.text(row,"$%d" % m.d.goods[id].price,23,INK,true).autowrap_mode = TextServer.AUTOWRAP_OFF
				ui.button(row,"+ $1",action.bind(m.set_price.bind(id,1)))
		"Ledger":
			ui.text(body,"Day %d   /   Trading accounts" % m.d.day,25,INK,true)
			ui.text(body,"Today’s sales  $%d     •     Today’s stock purchases  $%d" % [m.d.revenue-m.d.morning[2],m.d.spend-m.d.morning[3]],20,SUB)
			ui.text(body,"Lifetime sales  $%d     •     Gross profit  $%d" % [m.d.revenue,m.d.revenue-m.cost_of_sales()],18,SUB)
			ui.text(body,"Last supplier delivery",21,INK,true)
			if m.d.last_order.is_empty(): ui.text(body,"No supplier receipt yet.",17,SUB)
			else:
				ui.text(body,"Delivery %03d    /    $%d" % [m.d.deliveries,m.order_total(m.d.last_order)],18,INK)
				for id in m.d.last_order: ui.text(body,"%d cartons   ·   %s" % [m.d.last_order[id],m.catalog[id].name],17,SUB)
			ui.text(body,"Till receipts",21,INK,true)
			if m.d.log.is_empty(): ui.text(body,"No payments recorded yet.",17,SUB)
			for sale in m.d.log: ui.text(body,"%03d     %s     +$%d" % [sale.n,m.catalog[sale.id].name,sale.paid],17,SUB)

func scroll(parent: Control) -> VBoxContainer:
	var scrollbox := ScrollContainer.new()
	scrollbox.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scrollbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scrollbox)
	var content := ui.column(scrollbox)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return content

func catalogue(stack: Control) -> void:
	var split := ui.row(stack)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := ui.column(split)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.text(left,"Quayside Wholesale",27,INK,true)
	var filters := ui.row(left)
	var categories := ["All","Pantry","Household"]
	if m.d.dry_goods: categories.append("Dry goods")
	if not category in categories: category = "All"
	for name in categories:
		ui.button(filters,name,filter.bind(name),category==name)
	var products := scroll(left)
	for id in m.catalog:
		var item: Dictionary = m.catalog[id]
		if not m.licensed(id): continue
		if category != "All" and item.category != category: continue
		var row := ui.row(ui.panel(products,WHITE,8))
		ui.product_photo(row,id,Vector2(45,54))
		var info := ui.column(row)
		info.add_theme_constant_override("separation",0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ui.text(info,item.name,22,INK,true)
		ui.text(info,"%d units / carton   ·   $%d" % [item.pack,item.cost*item.pack],17,SUB)
		ui.button(row,"Add carton",edit.bind(id,1))
	var receipt := ui.panel(split,Color("d3dfd8"),15)
	receipt.custom_minimum_size.x = 264
	var side := ui.column(receipt)
	ui.text(side,"Purchase order",24,INK,true)
	ui.text(side,"Delivery to Harbor Market",16,SUB)
	var lines := scroll(side)
	if m.d.cart.is_empty(): ui.text(lines,"Add a carton to start an order.",17,SUB)
	for id in m.d.cart:
		var qty := int(m.d.cart[id])
		ui.text(lines,m.catalog[id].name,18,INK,true)
		var step := ui.row(lines)
		ui.button(step,"−",edit.bind(id,-1))
		ui.text(step,"%d" % qty,19,INK).autowrap_mode = TextServer.AUTOWRAP_OFF
		ui.button(step,"+",edit.bind(id,1))
	ui.text(side,"Total     $%d" % m.order_total(m.d.cart),23,INK,true)
	ui.button(side,"Review order",ui.terminal.bind("Cart"),true).disabled = m.d.cart.is_empty()

func review(body: Control) -> void:
	ui.text(body,"Deliver to receiving",24,INK,true)
	for id in m.d.cart:
		var qty := int(m.d.cart[id])
		var item: Dictionary = m.catalog[id]
		ui.text(body,"%s      %d carton(s)  ×  %d units      $%d" % [item.name,qty,item.pack,qty*item.pack*item.cost],19,INK)
	var due := m.order_total(m.d.cart)
	var issue := m.order_error(m.d.cart)
	ui.text(body,"Order total   $%d" % due,25,INK,true)
	ui.text(body,issue if issue != "" else "Balance after delivery   $%d" % (m.d.cash-due),18,SUB)
	var actions := ui.row(body)
	ui.button(actions,"Edit cart",ui.terminal.bind("Market"))
	ui.button(actions,"Place order",submit,true).disabled = issue != ""

func submit() -> void:
	if current != "Cart" or not m.order_error(m.d.cart).is_empty(): return
	var message := m.place_order(m.d.cart)
	ui.terminal("Ledger")
	ui.toast(message)

func filter(next: String) -> void:
	category = next
	ui.terminal("Market")

func edit(id: String, delta: int) -> void:
	m.edit_cart(id,delta)
	ui.terminal("Market")

func action(fn: Callable) -> void:
	var result: String = fn.call()
	ui.terminal(current)
	ui.toast(result)
