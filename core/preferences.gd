class_name Preferences
extends RefCounted

const DEFAULTS := {"quality":1, "fps":30, "first_person":true, "volume":75, "ambience":40, "music":50, "effects":75, "ui":75, "sensitivity":65, "invert":false, "hints":true, "autosave":true}
var values := DEFAULTS.duplicate()
var file: String

func _init(path := "user://settings.cfg") -> void:
	file = path
	var cfg := ConfigFile.new()
	if cfg.load(file) != OK: return
	for key in DEFAULTS:
		var val: Variant = cfg.get_value("options", key, DEFAULTS[key])
		if DEFAULTS[key] is bool and val is bool: values[key] = val
		elif DEFAULTS[key] is int and val is int:
			match key:
				"quality": values[key] = clampi(val, 0, 2)
				"fps": values[key] = 60 if val == 60 else 30
				_: values[key] = clampi(val, 0, 100)

func save() -> Error:
	var cfg := ConfigFile.new()
	for key in values: cfg.set_value("options", key, values[key])
	return cfg.save(file)

func apply(view: Viewport, light: DirectionalLight3D) -> void:
	Engine.max_fps = values.fps
	view.scaling_3d_scale = [0.65, 0.85, 1.0][values.quality]
	if light: light.shadow_enabled = values.quality > 0
	AudioServer.set_bus_volume_db(0, linear_to_db(values.volume / 100.0))
	for pair in [["Ambience","ambience"],["Music","music"],["Effects","effects"],["Interface","ui"]]:
		var bus := AudioServer.get_bus_index(pair[0])
		if bus >= 0: AudioServer.set_bus_volume_db(bus,linear_to_db(float(values[pair[1]])/100.0))
