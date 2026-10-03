extends SceneTree

const Fog = preload("res://scripts/fx/fog.gd")

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
	var piece := Sprite2D.new()
	piece.texture = load("res://assets/textures/pieces/WPawn.svg")
	root.add_child(piece)
	_check(not Fog.is_hidden(piece), "a fresh piece is not hidden")

	Fog.hide(piece)
	_check(Fog.is_hidden(piece), "hide covers the piece")
	var cover := piece.get_node_or_null("Cover") as Control
	_check(cover != null and cover.size.is_equal_approx(Vector2(Fog.COVER_SIZE, Fog.COVER_SIZE)), "cover is a fixed tile")
	_check(cover.position.is_equal_approx(-Vector2(Fog.COVER_SIZE, Fog.COVER_SIZE) / 2.0), "cover is centred on the piece")
	_check(cover.mouse_filter == Control.MOUSE_FILTER_IGNORE, "cover never eats clicks")

	Fog.hide(piece)
	_check(piece.get_children().filter(func(c): return c.name == "Cover").size() == 1, "hiding twice reuses one cover")

	Fog.show(piece)
	_check(not Fog.is_hidden(piece), "show reveals the piece")
	_check(piece.texture != null, "show keeps the real texture")

	piece.queue_free()
	await process_frame
	print("RESULT: %d failure(s)" % _fails)
	quit(1 if _fails > 0 else 0)
