extends SceneTree

const UiMotion = preload("res://scripts/ui/ui_motion.gd")

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
	await _test_ui_motion()
	await _test_animated_button()
	print("RESULT: %d failure(s)" % _fails)
	quit(1 if _fails > 0 else 0)

func _test_theme() -> void:
	print("theme")
	var theme: Theme = load("res://themes/blind_chess.tres")
	_check(theme != null, "theme loads")
	_check(theme.default_font != null and theme.default_font.get_font_name() == "MedievalSharp", "theme ships MedievalSharp")
	_check(theme.default_font_size == 32, "theme base size is 32")
	_check(theme.has_stylebox("normal", "Button") and theme.has_stylebox("focus", "Button"), "theme styles buttons")

func _test_ui_motion() -> void:
	print("ui_motion")
	var c := ColorRect.new()
	c.size = Vector2(200, 60)
	root.add_child(c)
	await process_frame
	var home := c.position
	await UiMotion.appear(c, Vector2(-40, 0), 0.0).finished
	_check(c.scale.is_equal_approx(Vector2.ONE), "appear rests at scale 1")
	_check(c.position.is_equal_approx(home), "appear rests at home")
	_check(is_equal_approx(c.modulate.a, 1.0), "appear rests opaque")
	await UiMotion.dismiss(c, Vector2(0, 40), 0.0).finished
	_check(is_equal_approx(c.modulate.a, 0.0), "dismiss leaves it transparent")
	c.queue_free()

func _test_animated_button() -> void:
	print("animated_button")
	var b = preload("res://scripts/ui/animated_button.gd").new()
	b.text = "Play"
	b.size = Vector2(240, 64)
	root.add_child(b)
	await process_frame
	var started := [false]
	var released := [false]
	b.hold_started.connect(func(): started[0] = true)
	b.hold_released.connect(func(): released[0] = true)
	b.button_down.emit()
	await create_timer(0.5).timeout
	_check(started[0], "hold_started fires while held")
	_check(b.is_holding(), "hold state is on")
	b.button_up.emit()
	await create_timer(0.1).timeout
	_check(released[0], "hold_released fires on release")
	_check(not b.is_holding(), "hold state is off")
	b.queue_free()
