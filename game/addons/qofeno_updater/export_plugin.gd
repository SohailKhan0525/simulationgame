@tool
extends EditorPlugin

var android_export: AndroidExportPlugin

func _enter_tree() -> void:
	android_export = AndroidExportPlugin.new()
	add_export_plugin(android_export)

func _exit_tree() -> void:
	remove_export_plugin(android_export)
	android_export = null

class AndroidExportPlugin extends EditorExportPlugin:
	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_name() -> String:
		return "QofenoUpdater"

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["res://addons/qofeno_updater/QofenoUpdater.aar"])
