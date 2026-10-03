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
	await _test_setting_row()
	await _test_promotion()
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

func _test_setting_row() -> void:
	print("setting_row")
	var row = preload("res://scripts/ui/setting_row.gd").new()
	row.setting_name = "Master Volume"
	row.label_text = "Master Volume"
	row.min_value = 0
	row.max_value = 100
	row.size = Vector2(600, 56)
	root.add_child(row)
	await process_frame
	var seen := []
	row.changed.connect(func(v): seen.append(v))
	row.set_value(100)
	row._step(1)
	_check(row.value == 100, "clamps at max")
	row.set_value(0)
	row._step(-1)
	_check(row.value == 0, "clamps at min")
	row.set_value(50)
	row._step(1)
	_check(row.value == 51 and seen.has(51), "steps and emits changed")
	row.queue_free()

func _test_promotion() -> void:
	print("promotion")
	var p: Control = load("res://scenes/promotion.tscn").instantiate()
	root.add_child(p)
	await process_frame
	p.open(0)
	_check(p.visible, "open shows the picker immediately")
	_check(p.get_node("Panel").get_child_count() == 4, "four choices")
	var picked := []
	var closed := [false]
	p.chosen.connect(func(n): picked.append(n))
	p.closed.connect(func(): closed[0] = true)
	p.get_node("Panel/Queen").pressed.emit()
	_check(picked == ["Queen"], "chosen fires once")
	p.get_node("Panel/Rook").pressed.emit()
	_check(picked == ["Queen"], "a second choice is ignored")
	p.close()
	await p.closed
	_check(not p.visible, "closes after the exit")
	p.queue_free()
