extends SceneTree

var _fails := 0

func _initialize() -> void:
	_watchdog()
	_run()

func _watchdog() -> void:
	await create_timer(120.0).timeout
	printerr("TIMEOUT")
	quit(2)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok   - ", message)
	else:
		_fails += 1
		printerr("  FAIL - ", message)

func _run() -> void:
	await _test_theme()
	print("RESULT: %d failure(s)" % _fails)
	quit(1 if _fails > 0 else 0)

func _test_theme() -> void:
	print("theme")
	var theme: Theme = load("res://themes/blind_chess.tres")
	_check(theme != null, "theme loads")
	_check(theme.default_font != null and theme.default_font.get_font_name() == "MedievalSharp", "theme ships MedievalSharp")
	_check(theme.default_font_size == 32, "theme base size is 32")
	_check(theme.has_stylebox("normal", "Button") and theme.has_stylebox("focus", "Button"), "theme styles buttons")
