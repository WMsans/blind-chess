extends SceneTree

const Fog = preload("res://scripts/fx/fog.gd")

var _fails := 0

func _initialize() -> void:
	_watchdog()
	_run()

func _watchdog() -> void:
	await create_timer(90.0).timeout
	printerr("TIMEOUT")
	quit(2)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok   - ", message)
	else:
		_fails += 1
		printerr("  FAIL - ", message)

func _run() -> void:
	seed(7)
	var game: Control = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var board: Control = game.get_node("Board")
	var flow: Control = board.get_node("Flow")
	var veil: Control = game.get_node("TurnTransition/Veil")

	# The scene must deal a shuffled opening, not the regular one; a broken
	# node override would silently ship standard chess under the fog.
	var plain: Control = load("res://scenes/board.tscn").instantiate()
	root.add_child(plain)
	await process_frame
	_check(_layout(flow) != _layout(plain.get_node("Flow")), "the scene deals a shuffled opening")
	plain.queue_free()
	await process_frame

	# Fog at start: black hidden, white visible.
	var black_hidden := 0
	var white_hidden := 0
	for cell in flow.get_children():
		if cell.get_child_count() != 1:
			continue
		var piece = cell.get_child(0)
		if fog_is(piece):
			if piece.PieceColor == 1: black_hidden += 1
			else: white_hidden += 1
	_check(black_hidden == 16 and white_hidden == 0, "start: all black hidden, all white visible")

	# Capture routes into the capturing side's tray.
	var victim = null
	for cell in flow.get_children():
		if cell.get_child_count() == 1 and cell.get_child(0).PieceColor == 0:
			victim = cell.get_child(0)
			break
	board.Captured.emit(victim)
	await process_frame
	_check(game.get_node("Captured/BlackTray").count() == 1, "white victim lands in black's tray")
	_check(game.get_node("Captured/WhiteTray").count() == 0, "the other tray stays empty")

	# Hand-off: cover, fog flip, rotate; dismiss reveals and keeps the rotation.
	board.Turn = 1
	game._on_move_settled()
	await create_timer(1.0).timeout
	_check(veil.is_covered(), "hand-off covers the board")
	_check(absf(flow.rotation - PI) < 0.01, "board rotated 180 degrees for black")
	var white_now_hidden := 0
	for cell in flow.get_children():
		if cell.get_child_count() == 1 and cell.get_child(0).PieceColor == 0 and fog_is(cell.get_child(0)):
			white_now_hidden += 1
	_check(white_now_hidden == 16, "hand-off hides white")
	veil.dismiss()
	await create_timer(0.6).timeout
	_check(not veil.is_covered(), "dismiss reveals the board")
	_check(absf(flow.rotation - PI) < 0.01, "rotation survives the reveal")

	# Second hand-off rotates back.
	board.Turn = 0
	game._on_move_settled()
	await create_timer(1.0).timeout
	_check(absf(flow.rotation) < 0.01, "second hand-off rotates back")
	veil.dismiss()
	await create_timer(0.6).timeout

	# Empty cells are skipped by the fog pass.
	var empty_cell := flow.get_node("0-0")
	if empty_cell.get_child_count() == 1:
		empty_cell.get_child(0).queue_free()
	await process_frame
	game._apply_fog()
	_check(true, "fog pass tolerates an empty cell")

	# Promotion panel defers the hand-off.
	game.get_node("Board/Promotion").visible = true
	game._on_move_settled()
	await create_timer(0.3).timeout
	_check(not veil.is_covered(), "hand-off waits for the promotion panel")
	game.get_node("Board/Promotion").visible = false
	await create_timer(0.6).timeout
	_check(veil.is_covered(), "hand-off proceeds once promotion closes")
	veil.dismiss()
	await create_timer(0.6).timeout

	# A finished game never covers the winning move.
	game._on_game_win()
	board.Turn = 1
	game._on_move_settled()
	await create_timer(0.3).timeout
	_check(not veil.is_covered(), "no hand-off after GameWin")

	game.queue_free()
	await process_frame
	print("RESULT: %d failure(s)" % _fails)
	quit(1 if _fails > 0 else 0)

func fog_is(piece: Node2D) -> bool:
	return Fog.is_hidden(piece)

func _layout(flow: Control) -> String:
	var s := ""
	for cell in flow.get_children():
		s += "%s=%s;" % [cell.name, cell.get_child(0).name if cell.get_child_count() == 1 else ""]
	return s
