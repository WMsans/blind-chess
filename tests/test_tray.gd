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
	var tray: Panel = load("res://scenes/tray.tscn").instantiate()
	root.add_child(tray)
	await process_frame
	_check(tray.count() == 0, "a tray starts empty")

	var tex: Texture2D = load("res://assets/textures/pieces/BRook.svg")
	var item: TextureRect = tray.add_piece(tex)
	await process_frame
	_check(tray.count() == 1, "adding a piece counts once")
	_check(item.texture == tex, "the thumbnail shows the given texture")
	_check(item.get_parent() == tray.get_node("Flow"), "the thumbnail lives in the wrapping container")
	_check(item.custom_minimum_size.x > 0.0, "the thumbnail has a minimum size")
	tray.queue_free()
	await process_frame
	print("RESULT: %d failure(s)" % _fails)
	quit(1 if _fails > 0 else 0)
