extends Node
signal changed(message: String)
var message := "Updates are checked when you choose Check for updates."
var manifest: Dictionary = {}
var bridge: Object
var request: HTTPRequest
var running_version := 1000000
var poll := 0.0
func _ready() -> void:
	if Engine.has_singleton("QofenoUpdater"):
		bridge = Engine.get_singleton("QofenoUpdater")
	request = HTTPRequest.new()
	request.timeout = 25
	request.body_size_limit = 32768
	add_child(request)
	request.request_completed.connect(_checked)
	if FileAccess.file_exists("res://version.json"):
		var v = JSON.parse_string(FileAccess.get_file_as_string("res://version.json"))
		if v is Dictionary: running_version = int(v.get("version_code",1000000))
func check() -> void:
	_set_message("Checking GitHub for a newer release...")
	var err := request.request("https://github.com/SohailKhan0525/simulationgame/releases/latest/download/update.json",["Accept: application/json"])
	if err != OK: _set_message("Could not connect. Your offline drive is still available.")
func _checked(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_set_message("No update feed available yet. Try again later.")
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary or data.get("package","") != "com.qofeno.drive" or not str(data.get("url","")).begins_with("https://github.com/SohailKhan0525/simulationgame/releases/download/") or str(data.get("sha256","")).length()!=64:
		_set_message("The update information could not be verified.")
		return
	manifest=data
	if int(data.get("version_code",0)) <= running_version:
		manifest={}
		_set_message("You're up to date. Enjoy the drive.")
	else: _set_message("Version %s available. Download when you're ready." % data.get("version","new"))
func download() -> void:
	if manifest.is_empty():
		check()
		return
	if bridge:
		_set_message(str(bridge.start_download(str(manifest.url),str(manifest.sha256),int(manifest.version_code))))
	else: _set_message("Background APK updates are available in the Android build.")
func install() -> void:
	if bridge:
		var result: String=str(bridge.install_update())
		_set_message("Allow installs from Qofeno Drive in Android Settings, then tap Install again." if result=="permission_required" else result)
	else: _set_message("Install the Android release on your phone to use this feature.")
func say(text: String) -> void:
	if bridge: bridge.speak(text)
	elif OS.get_name() in ["Windows","macOS"]:
		var voices := DisplayServer.tts_get_voices_for_language("en")
		if not voices.is_empty(): DisplayServer.tts_speak(text,voices[0],80,1.12,1.08)
func _process(delta: float) -> void:
	poll += delta
	if bridge and poll > 1:
		poll=0
		var data = JSON.parse_string(str(bridge.get_status()))
		if data is Dictionary:
			var state := str(data.get("state","idle"))
			if state in ["downloading","pending","paused","verifying"]:
				_set_message("Update %s · %d%% · %.1f MB" % [state,roundi(float(data.get("progress",0))*100.0),float(data.get("bytes",0))/1048576.0])
			elif state == "ready": _set_message("Update verified and ready. Tap Install update.")
			elif state == "failed" or state == "error": _set_message("Update failed: %s" % data.get("error","Please retry."))
func _set_message(value: String) -> void:
	message=value
	changed.emit(value)
