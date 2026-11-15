class_name Market
extends RefCounted

signal changed
signal display_changed
signal closed
const SCHEMA := 3
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
		"revenue": 0, "spend": 0, "receipt": 0, "clock": 510.0, "pos": [-2.14, 0.1, 7.1],
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
	if not catalog.has(id): return "Unknown product."
	var item: Dictionary = catalog[id]
	var cost := int(item.pack * item.cost)
	if d.cash < cost: return "Insufficient funds."
	if d.goods[id].back + item.pack > 48: return "Receiving is full for this product."
	d.cash -= cost
	d.spend += cost
	d.goods[id].back += int(item.pack)
	mark("order")
	changed.emit()
	return "Delivered %d × %s to receiving." % [item.pack, item.name]

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
	if not d.open and available().is_empty(): return "Fill a display before opening."
	d.open = not d.open
	if d.open: mark("open")
	else:
		reservations.clear()
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
	if not d.open or reservations.is_empty() or reservations.keys().front() != visit:
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
	if absf(s.pos[0]) > 36 or absf(s.pos[2]) > 28 or absf(s.pos[1]) > 12 or s.clock < 0 or s.clock >= 1440: return false
	d = s
	reservations.clear()
	return true
