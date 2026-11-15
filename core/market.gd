class_name Market
extends RefCounted

signal changed
signal display_changed
signal closed
const SCHEMA := 4
const OPENING := 480.0
const CLOSING := 1260.0
const PARK := [-4.1, 8.85, 0.0]
const DRY_GOODS := 36
const CASHIER_WAGE := 12
const EXPANSION := 45
const QUEUE_LANE_COST := 32
const QUEUE_LIMIT := 3
const MILESTONES := ["visit", "terminal", "order", "collect", "stock", "open", "sale", "expand"]
const OBJECTIVES := ["Enter Harbor Market", "Use the desk at the rear right", "Order a carton at the computer", "Collect your carton at receiving", "Fill the display shelves", "Open the shop at the door sign", "Serve a customer at the till", "Buy the shelf extension at the computer"]
var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
var d: Dictionary
## Visit IDs in insertion order. Each unpaid basket holds one unit at a fixed price.
var reservations: Dictionary[int, Dictionary] = {}

func _init() -> void:
	d = {"schema": SCHEMA, "cash": 95, "xp": 0, "open": false, "expanded": false, "queue_lane": false,
		"revenue": 0, "spend": 0, "receipt": 0, "clock": OPENING, "day": 1, "started": false, "lights": true,
		"morning": [95, 0, 0, 0], "van": PARK.duplicate(), "driving": false, "deliveries": 0,
		"dry_goods": false, "cashier": false, "last_order": {}, "cart": {}, "pos": [-2.14, 0.1, 7.1],
		"yaw": -0.29, "flags": {}, "log": [], "carry": "", "quantity": 0, "goods": {}}
	for id in catalog:
		d.goods[id] = {"back": 0, "shelf": 0, "sold": 0, "price": int(catalog[id].price)}

static func opening_shift() -> Market:
	var shop := Market.new()
	# The lease includes a small opening inventory. These units can be sold
	# once, priced and saved like every subsequent supplier delivery.
	shop.d.goods.soap.shelf = 4
	shop.d.goods.cocoa.shelf = 3
	return shop

func level() -> int:
	return 1 + floori(d.xp / 35.0)

func capacity() -> int:
	return 12 if d.expanded else 6

func objective() -> String:
	for i in MILESTONES.size():
		if not d.flags.has(MILESTONES[i]):
			return OBJECTIVES[i]
	return "Keep trading • every fifth sale earns a $5 bonus"

func mark(event: String) -> void:
	if event in MILESTONES and not d.flags.has(event):
		d.flags[event] = true
		d.xp += 4
		changed.emit()

func order(id: String) -> String:
	return place_order({id: 1})

func order_total(cart: Dictionary) -> int:
	var total := 0
	for id in cart:
		if not catalog.has(id) or not whole(cart[id], 1, 48): return -1
		total += int(cart[id] * catalog[id].pack * catalog[id].cost)
	return total

func licensed(id: String) -> bool:
	return catalog.has(id) and (catalog[id].category != "Dry goods" or d.dry_goods)

func buy_license() -> String:
	if d.dry_goods: return "Dry goods licence already purchased."
	if level() < 2: return "Reach store level 2 to buy this licence."
	if d.cash < DRY_GOODS: return "Insufficient funds."
	d.cash -= DRY_GOODS
	d.dry_goods = true
	changed.emit()
	return "Dry goods unlocked. The new display is installed."

func hire_cashier() -> String:
	if d.cashier: return "The cashier is already on shift."
	if not d.flags.has("sale"): return "Serve your first customer before hiring."
	if d.clock >= CLOSING: return "Hire a cashier at the start of the next day."
	if d.cash < CASHIER_WAGE: return "Insufficient funds."
	d.cash -= CASHIER_WAGE
	d.cashier = true
	changed.emit()
	return "Cashier hired until the end of this day."

func order_error(cart: Dictionary) -> String:
	if cart.is_empty(): return "Your cart is empty."
	var total := order_total(cart)
	if total < 0: return "Invalid carton quantity."
	if total > d.cash: return "Insufficient funds."
	for id in cart:
		if not licensed(id): return "Purchase the dry goods licence first."
		if d.goods[id].back + cart[id] * catalog[id].pack > 48:
			return "Receiving is full for %s." % catalog[id].name
	return ""

func place_order(cart: Dictionary) -> String:
	var issue := order_error(cart)
	if issue != "": return issue
	var total := order_total(cart)
	for id in cart:
		d.goods[id].back += int(cart[id] * catalog[id].pack)
	d.cash -= total
	d.spend += total
	d.deliveries += 1
	d.last_order = cart.duplicate()
	d.cart = {}
	mark("order")
	changed.emit()
	return "Delivery %03d received at the front pallet." % d.deliveries

func edit_cart(id: String, delta: int) -> void:
	if not licensed(id) or absi(delta) != 1: return
	var count := clampi(int(d.cart.get(id, 0)) + delta, 0, 48)
	if count: d.cart[id] = count
	else: d.cart.erase(id)
	changed.emit()

func advance_clock(minutes: float) -> void:
	if not d.started or d.clock >= CLOSING or minutes <= 0.0: return
	d.clock = minf(CLOSING, d.clock + minutes)
	if d.clock == CLOSING:
		d.open = false
		closed.emit()
		changed.emit()

func toggle_lights() -> String:
	d.lights = not d.lights
	changed.emit()
	return "Shop lights on." if d.lights else "Shop lights off."

func can_finish() -> bool:
	return d.started and not d.open and reservations.is_empty()

func next_day() -> bool:
	if not can_finish(): return false
	d.day += 1
	d.cashier = false
	d.clock = OPENING
	d.started = false
	d.morning = [d.cash, d.receipt, d.revenue, d.spend]
	changed.emit()
	return true

func collect(id: String) -> String:
	if not catalog.has(id): return "Unknown product."
	if d.quantity > 0: return "Place your current carton on the shelf first."
	var n := mini(int(catalog[id].pack), int(d.goods[id].back))
	if n == 0: return "Order this product at the computer first."
	d.goods[id].back -= n
	d.quantity = n
	d.carry = id
	mark("collect")
	changed.emit()
	return "Carrying %d × %s." % [n, catalog[id].name]

func put_back() -> String:
	if d.quantity == 0: return "Your hands are empty."
	d.goods[d.carry].back += d.quantity
	d.quantity = 0
	d.carry = ""
	changed.emit()
	return "Carton returned to receiving."

func stock() -> String:
	if d.quantity == 0: return "Collect a carton at receiving first."
	var goods: Dictionary = d.goods[d.carry]
	var n := mini(capacity() - int(goods.shelf), int(d.quantity))
	if n == 0: return "That display is full. Return the carton to receiving."
	goods.shelf += n
	d.quantity -= n
	if d.quantity == 0: d.carry = ""
	mark("stock")
	changed.emit()
	return "Placed %d on display." % n

func set_price(id: String, delta: int) -> String:
	if not catalog.has(id) or absi(delta) != 1: return "Invalid price change."
	var price := int(d.goods[id].price) + delta
	if price < catalog[id].cost or price > catalog[id].price * 2: return "Price limit reached."
	d.goods[id].price = price
	changed.emit()
	return "%s is now $%d." % [catalog[id].name, price]

func toggle_open() -> String:
	if d.clock >= CLOSING: return "Trading has finished for today."
	if not d.open and available().is_empty(): return "Fill a display before opening."
	d.open = not d.open
	if d.open:
		d.started = true
		mark("open")
	else:
		closed.emit()
	changed.emit()
	return "The shop is open." if d.open else "The shop is closed."

func customer_limit() -> int:
	return QUEUE_LIMIT if d.queue_lane else 1

func on_display(id: String) -> int:
	var count := int(d.goods[id].shelf)
	for item in reservations.values():
		if item.id == id: count -= 1
	return count

func available() -> Array:
	var ids := []
	for id in catalog:
		if on_display(id) > 0: ids.append(id)
	return ids

func choose_product(visit: int) -> String:
	# Shoppers differ in willingness to pay. A higher margin can lose a visit.
	var options := available()
	for i in options.size():
		var id: String = options[(visit-1+i)%options.size()]
		var budget := int(catalog[id].price) + (visit % 4)
		if d.goods[id].price <= budget: return id
	return ""

func reserve(visit: int, id: String) -> bool:
	if not d.open or visit < 1 or reservations.has(visit) or reservations.size() >= customer_limit():
		return false
	if not catalog.has(id) or on_display(id) < 1:
		return false
	reservations[visit] = {"id": id, "price": int(d.goods[id].price)}
	display_changed.emit()
	return true

func cancel_basket(visit: int) -> void:
	if reservations.erase(visit):
		display_changed.emit()

func checkout(visit: int) -> String:
	if reservations.is_empty() or reservations.keys().front() != visit:
		return "Serve the first shopper in line."
	var item := reservations[visit]
	var id: String = item.id
	var paid: int = item.price
	var g: Dictionary = d.goods[id]
	if g.shelf < 1: return "Item unavailable."
	reservations.erase(visit)
	g.shelf -= 1
	g.sold += 1
	d.revenue += paid
	d.cash += paid
	d.receipt += 1
	d.xp += 8
	var bonus: bool = int(d.receipt) % 5 == 0
	if bonus: d.cash += 5
	d.log.push_front({"n": d.receipt, "id": id, "paid": paid})
	if d.log.size() > 15: d.log.pop_back()
	mark("sale")
	changed.emit()
	return "Paid $%d for %s.%s" % [paid, catalog[id].name, " Trading bonus +$5." if bonus else ""]

func expand() -> String:
	if d.expanded: return "Display extension already installed."
	if not d.flags.has("sale"): return "Serve your first customer to unlock."
	if d.cash < EXPANSION: return "The extension costs $%d." % EXPANSION
	d.cash -= EXPANSION
	d.expanded = true
	mark("expand")
	changed.emit()
	return "Extended displays • 12 spaces per product."

func install_queue_lane() -> String:
	if d.queue_lane: return "Checkout lane already installed."
	if not d.flags.has("sale"): return "Take the first payment to unlock the checkout lane."
	if d.cash < QUEUE_LANE_COST: return "The checkout lane costs $%d." % QUEUE_LANE_COST
	d.cash -= QUEUE_LANE_COST
	d.queue_lane = true
	changed.emit()
	return "Checkout lane installed. Up to three shoppers can visit at once."

func cost_of_sales() -> int:
	var total := 0
	for id in catalog: total += int(d.goods[id].sold * catalog[id].cost)
	return total

static func whole(v: Variant, lo: int, hi: int = 2000000000) -> bool:
	return (v is float or v is int) and is_finite(float(v)) and float(v) == floor(float(v)) and v >= lo and v <= hi

func restore(raw: Variant) -> bool:
	if not raw is Dictionary or not whole(raw.get("schema"), 1, SCHEMA): return false
	var s: Dictionary = raw.duplicate(true)
	if int(s.schema) == 1:
		s["yaw"] = 0.0
		s.schema = 2
	if int(s.schema) == 2:
		s["queue_lane"] = false
		s.schema = 3
	if int(s.schema) == 3:
		s.day = 1
		s.dry_goods = false
		s.cashier = false
		if s.get("goods") is Dictionary:
			for id in catalog:
				if catalog[id].category == "Dry goods" and not s.goods.has(id):
					s.goods[id] = {"back":0,"shelf":0,"sold":0,"price":int(catalog[id].price)}
		s.started = s.get("open") == true or (s.get("flags") is Dictionary and s.flags.has("open"))
		s.lights = true
		s.driving = false
		s.deliveries = 0
		s.van = PARK.duplicate()
		s.cart = {}
		s.last_order = {}
		s.morning = [s.get("cash"),s.get("receipt"),s.get("revenue"),s.get("spend")]
		if s.get("clock") is int or s.get("clock") is float:
			if s.clock < 0 or s.clock >= 1440: return false
			s.clock = clampf(s.clock, OPENING, CLOSING) if s.started else OPENING
			if s.clock == CLOSING: s.open = false
		s.schema = SCHEMA
	s.schema = int(s.schema)
	for k in ["cash", "xp", "revenue", "spend", "receipt", "quantity"]:
		if not whole(s.get(k), 0): return false
		s[k] = int(s[k])
	if not s.get("open") is bool or not s.get("expanded") is bool or not s.get("queue_lane") is bool: return false
	if not s.get("goods") is Dictionary or not s.get("flags") is Dictionary: return false
	if not s.get("carry") is String or s.quantity > 6 or (s.quantity == 0) != (s.carry == ""): return false
	if s.quantity > 0 and not catalog.has(s.carry): return false
	var count := 0
	for id in catalog:
		var g: Variant = s.goods.get(id)
		if not g is Dictionary: return false
		for k in ["back", "shelf", "sold", "price"]:
			if not whole(g.get(k), 0): return false
			g[k] = int(g[k])
		if g.back > 54 or g.shelf > (12 if s.expanded else 6): return false
		if g.price < catalog[id].cost or g.price > catalog[id].price * 2: return false
		count += int(g.sold)
	if count != s.receipt: return false
	for k in s.flags:
		if not k in MILESTONES or s.flags[k] != true: return false
	if not s.get("log") is Array or s.log.size() > 15: return false
	for row in s.log:
		if not row is Dictionary or not catalog.has(row.get("id")): return false
		if not whole(row.get("n"), 1, s.receipt) or not whole(row.get("paid"), 1): return false
		row.n = int(row.n)
		row.paid = int(row.paid)
	if not s.get("pos") is Array or s.pos.size() != 3: return false
	for val in s.pos + [s.get("yaw"), s.get("clock")]:
		if not (val is float or val is int) or not is_finite(float(val)): return false
	if absf(s.pos[0]) > 76 or absf(s.pos[2]) > 28 or absf(s.pos[1]) > 12 or s.clock < 0 or s.clock >= 1440: return false
	if not whole(s.get("day"), 1) or not whole(s.get("deliveries"), 0): return false
	for key in ["lights","started","driving","cashier","dry_goods"]:
		if not s.get(key) is bool: return false
	if s.clock < OPENING or s.clock > CLOSING: return false
	if not s.get("morning") is Array or s.morning.size() != 4: return false
	for number in s.morning:
		if not whole(number, 0): return false
	if s.morning[1] > s.receipt or s.morning[2] > s.revenue or s.morning[3] > s.spend: return false
	if s.open and (not s.started or s.clock >= CLOSING): return false
	for key in ["cart", "last_order"]:
		if not s.get(key) is Dictionary or order_total(s[key]) < 0: return false
	if not s.get("van") is Array or s.van.size() != 3: return false
	for val in s.van:
		if not (val is float or val is int) or not is_finite(float(val)): return false
	if absf(s.van[0]) > 74 or s.van[1] < 5 or s.van[1] > 21: return false
	s.day = int(s.day)
	s.deliveries = int(s.deliveries)
	for i in s.morning.size(): s.morning[i] = int(s.morning[i])
	for key in ["cart","last_order"]:
		for id in s[key]:
			if catalog[id].category == "Dry goods" and not s.dry_goods: return false
			s[key][id] = int(s[key][id])
	d = s
	reservations.clear()
	return true
