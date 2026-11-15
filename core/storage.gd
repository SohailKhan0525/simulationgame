class_name Slot
extends RefCounted

var path: String
var status := ""
var recovery := false
var incompatible := false

func _init(file := "user://harbor.json") -> void:
	path = file

func exists() -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak") or FileAccess.file_exists(path + ".tmp")

func _read(file: String) -> Variant:
	if not FileAccess.file_exists(file): return null
	var f := FileAccess.open(file, FileAccess.READ)
	if f == null or f.get_length() > 262144: return null
	var parser := JSON.new()
	if parser.parse(f.get_as_text()) != OK: return null
	return parser.data

func load_into(m: Market) -> bool:
	recovery = false
	incompatible = false
	for file in [path, path + ".tmp", path + ".bak"]:
		var value: Variant = _read(file)
		if value is Dictionary and Market.whole(value.get("schema"), Market.SCHEMA + 1):
			incompatible = true
			status = "This save needs a newer version of Qofeno."
			return false
		if m.restore(value):
			recovery = file != path
			status = "Recovered the last valid shift." if recovery else "Shift restored."
			return true
	status = "No readable save. Start a new shift to replace it."
	return false

func save(m: Market) -> bool:
	if incompatible:
		status = "Update Qofeno before saving this shift."
		return false
	if not Market.new().restore(m.d):
		status = "Save validation failed. Previous shift retained."
		return false
	var full := ProjectSettings.globalize_path(path)
	# Stage separately from all three files that can be recovered on load.
	var stage := full + ".writing"
	var f := FileAccess.open(stage, FileAccess.WRITE)
	if f == null: return _failed()
	f.store_string(JSON.stringify(m.d))
	f.flush()
	var ok := f.get_error() == OK
	f.close()
	if not ok or not Market.new().restore(_read(stage)): return _failed()
	if FileAccess.file_exists(full) and not recovery and Market.new().restore(_read(full)):
		if DirAccess.copy_absolute(full,full+".bak.next") != OK: return _failed()
		if DirAccess.rename_absolute(full+".bak.next",full+".bak") != OK: return _failed()
	if DirAccess.rename_absolute(stage, full + ".tmp") != OK: return _failed()
	if DirAccess.rename_absolute(full + ".tmp", full) != OK: return _failed()
	recovery = false
	status = "Shift saved."
	return true

func _failed() -> bool:
	status = "Save failed. Check free storage and retry."
	return false
