extends SceneTree

var _fails := 0

func _initialize() -> void:
	_run()

func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok   - ", message)
	else:
		_fails += 1
		printerr("  FAIL - ", message)

func _run() -> void:
	var Save = load("res://savemanager.gd")

	var fresh: Dictionary = Save.merge_with_defaults({})
	_check(fresh["Master Volume"] == 50 and fresh["BGM Volume"] == 80 and fresh["SFX Volume"] == 65 and fresh["Brightness"] == 100, "empty save yields defaults")
	_check(fresh.has("Scenes"), "empty save keeps the Scenes bucket")

	var partial: Dictionary = Save.merge_with_defaults({"Master Volume": 12})
	_check(partial["Master Volume"] == 12, "a saved value wins")
	_check(partial["BGM Volume"] == 80 and partial["SFX Volume"] == 65 and partial["Brightness"] == 100, "missing keys fall back to defaults")

	var scenes: Dictionary = Save.merge_with_defaults({"Scenes": {"res://a.tscn": {"x": 1}}})
	_check(scenes["Scenes"]["res://a.tscn"]["x"] == 1, "scene progress round-trips")

	var junk: Dictionary = Save.merge_with_defaults({"Scenes": "nope", "Garbage": 3})
	_check(junk["Scenes"] == {}, "a malformed Scenes value is discarded")
	_check(not junk.has("Garbage"), "unknown keys are ignored")

	print("RESULT: %d failure(s)" % _fails)
	quit(1 if _fails > 0 else 0)
