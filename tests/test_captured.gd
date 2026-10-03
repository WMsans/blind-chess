extends SceneTree

var _fails := 0

func _initialize() -> void:
	_watchdog()
	_run()

func _watchdog() -> void:
	await create_timer(60.0).timeout
	printerr("TIMEOUT")
	quit(2)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok   - ", message)
	else:
		_fails += 1
		printerr("  FAIL - ", message)

func _run() -> void:
	var board: Control = load("res://scenes/board.tscn").instantiate()
	root.add_child(board)
	await process_frame
	var seen: Array = []
	board.Captured.connect(func(victim: Node2D): seen.append({"name": victim.name, "color": victim.PieceColor, "valid": is_instance_valid(victim)}))

	board._on_flow_send_location("0-6")
	board._on_flow_send_location("0-4")
	await board.MoveSettled
	board._on_flow_send_location("1-1")
	board._on_flow_send_location("1-3")
	await board.MoveSettled
	board._on_flow_send_location("0-4")
	board._on_flow_send_location("1-3")
	await board.MoveSettled

	_check(seen.size() == 1, "one capture emitted once")
	if seen.size() == 1:
		_check(seen[0].name == "Pawn" and seen[0].color == 1, "emitted the captured black pawn (got %s/%s)" % [seen[0].name, seen[0].color])
		_check(seen[0].valid, "victim is still alive when emitted")
	board.queue_free()
	await process_frame
	print("RESULT: %d failure(s)" % _fails)
	quit(1 if _fails > 0 else 0)
