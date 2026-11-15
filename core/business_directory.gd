class_name BusinessDirectory
extends RefCounted
## Definitions outlive shift instances. A playable location must bind a real operator.
var entries: Array = []
var by_id := {}
var operators := {}

func _init() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/places.json"))
	if not raw is Array: return
	for p in raw:
		if not p is Dictionary or not p.get("id") is String or by_id.has(p.id): continue
		if not p.get("name") is String or not p.get("type") is String or not p.get("playable") is bool: continue
		if not (p.get("x") is float or p.get("x") is int) or not (p.get("z") is float or p.get("z") is int): continue
		by_id[p.id] = p
		entries.append(p)

func bind_operator(id: String, operator: RefCounted) -> bool:
	if operator == null or not by_id.has(id) or not by_id[id].playable: return false
	operators[id] = operator
	return true

func business(id: String) -> RefCounted:
	return operators.get(id)

func is_operating_site(id: String) -> bool:
	return operators.has(id) and by_id.has(id) and by_id[id].playable
