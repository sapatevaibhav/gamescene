@tool
extends EditorPlugin
## Editor-only: adds the Android plugin (bin/GameSceneNative-*.aar, built by
## platform/android/build.sh) to Android exports. Android exports must use
## the Gradle build (the presets do). Runtime code reaches the plugin through
## Native (src/io/native.gd).

var _export: AndroidExport


func _enter_tree() -> void:
	_export = AndroidExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


class AndroidExport:
	extends EditorExportPlugin

	func _get_name() -> String:
		return "GameSceneNative"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		return PackedStringArray(["gamescene_native/bin/GameSceneNative-%s.aar" % ("debug" if debug else "release")])

	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["androidx.core:core:1.13.1"])
