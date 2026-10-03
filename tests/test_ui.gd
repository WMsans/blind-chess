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
	await _test_menu()
	await _test_settings_input()
	await _test_menu_focus()
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

func _test_menu() -> void:
	print("menu")
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	_check(menu.get_script().get_script_constant_map()["PLAY_SCENE"] == "res://scenes/game.tscn", "Play targets the match scene")
	var buttons := menu.get_node("Buttons").get_children()
	_check(buttons.size() == 3, "three menu buttons")
	for b in buttons:
		_check(b is Button and not (b is Sprite2D), "menu items are Controls")
		_check(b.get_global_rect().end.y <= 648.0, "button inside the viewport")
	# Re-entering the panel mid-flight must not strand a control.
	var panel: Control = menu.get_node("SettingsPanel")
	panel.open()
	panel.close()
	panel.open()
	await create_timer(0.8).timeout
	for row in panel.get_node("Rows").get_children():
		if row is Button:
			_check(is_equal_approx(row.modulate.a, 1.0), "re-opened row is fully opaque")
	panel.set_value("Master Volume", 42)
	menu.push_data_to_manager()
	_check(root.get_node("Savemanager").get_setting("Master Volume") == 42, "window close persists live values")
	menu.queue_free()

func _test_settings_input() -> void:
	print("settings_input")
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await create_timer(0.8).timeout
	var panel: Control = menu.get_node("SettingsPanel")
	panel.open()
	await create_timer(0.5).timeout
	var row = panel.get_node("Rows/MasterVolume")
	row.set_value(row.min_value)
	row.grab_focus()
	var before: int = row.value
	_press_key(KEY_RIGHT, true)
	await create_timer(UiMotion.HOLD_DELAY + UiMotion.REPEAT_INTERVAL * 3.0 + 0.25).timeout
	_press_key(KEY_RIGHT, false)
	await create_timer(0.1).timeout
	_check(row.value >= before + 3, "holding ui_right repeats the step")
	menu.queue_free()


func _press_key(code: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _test_menu_focus() -> void:
	print("menu_focus")
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await create_timer(0.6).timeout
	var play = menu.get_node("Buttons/Play")
	play.grab_focus()
	menu._on_settings()
	await create_timer(0.4).timeout
	_check(play.focus_mode == Control.FOCUS_NONE, "dismissed menu button cannot take focus")
	_check(not play.has_focus(), "focus is not on a dismissed menu button")
	menu.queue_free()
