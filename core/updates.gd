class_name HarborUpdates
extends HTTPRequest

signal result(message: String, page: String)
const REPO := "https://github.com/SohailKhan0525/simulationgame"
const API := "https://api.github.com/repos/SohailKhan0525/simulationgame/releases/latest"

func _ready() -> void:
	timeout = 9
	max_redirects = 0
	body_size_limit = 256 * 1024
	request_completed.connect(_completed)

static func numbers(tag: String) -> Array:
	var re := RegEx.new()
	re.compile("^v?(0|[1-9][0-9]{0,7})\\.(0|[1-9][0-9]{0,7})\\.(0|[1-9][0-9]{0,7})$")
	var m := re.search(tag)
	if m == null: return []
	return [int(m.get_string(1)), int(m.get_string(2)), int(m.get_string(3))]

static func newer(tag: String, installed: String) -> bool:
	var a := numbers(tag)
	var b := numbers(installed)
	if a.is_empty() or b.is_empty(): return false
	for i in 3:
		if a[i] != b[i]: return a[i] > b[i]
	return false

static func inspect(code: int, data: Variant, installed: String) -> Array:
	if code == 404: return ["No stable release has been published yet.", ""]
	if code in [403, 429]: return ["GitHub is limiting requests. Try again later.", ""]
	if code != 200 or not data is Dictionary: return ["Release information unavailable. You can keep playing offline.", ""]
	var tag: Variant = data.get("tag_name", "")
	if not tag is String or not tag.begins_with("v") or numbers(tag).is_empty() or data.get("prerelease") != false or data.get("draft") != false:
		return ["No supported stable release was found.", ""]
	var page := REPO + "/releases/tag/" + str(tag)
	if data.get("html_url") != page: return ["Unrecognized release page.", ""]
	if not newer(tag, installed): return ["Installed %s • latest stable %s." % [installed, tag], ""]
	var filename := "Qofeno-Simulation-%s.apk" % tag.substr(1)
	if data.get("assets") is Array:
		for asset in data.assets:
			if asset is Dictionary and asset.get("name") == filename and asset.get("browser_download_url") == REPO + "/releases/download/" + tag + "/" + filename and Market.whole(asset.get("size"), 1):
				return ["%s available • %.1f MB\n%s" % [tag, asset.size / 1000000.0, str(data.get("body", "")).left(700)], page]
	return ["The release has no matching Android APK.", ""]

func check() -> void:
	cancel_request()
	var err := request(API, ["Accept: application/vnd.github+json", "User-Agent: Qofeno-Simulation"])
	if err != OK: result.emit("Cannot reach GitHub. Retry when connected.", "")

func _completed(outcome: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if outcome != RESULT_SUCCESS:
		result.emit("Offline or timed out. Your shift is available offline.", "")
		return
	var parser := JSON.new()
	var data: Variant = null
	if parser.parse(body.get_string_from_utf8()) == OK: data = parser.data
	var info := inspect(code, data, ProjectSettings.get_setting("application/config/version"))
	result.emit(info[0], info[1])
