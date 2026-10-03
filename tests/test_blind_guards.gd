extends SceneTree

const Fog = preload("res://scripts/fx/fog.gd")

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

func _clear(flow: Control, loc: String) -> void:
	var cell := flow.get_node(loc)
	if cell.get_child_count() > 0:
		cell.get_child(0).free()

func _put(flow: Control, loc: String, piece: String, color: int) -> Node2D:
	var scene: PackedScene = load("res://scenes/pieces/%s.tscn" % piece)
	var p: Node2D = scene.instantiate()
	p.Spawned(color)
	p.position = Vector2(25, 25)
	flow.get_node(loc).add_child(p)
	return p

func _run() -> void:
	var board: Control = load("res://scenes/board.tscn").instantiate()
	root.add_child(board)
	await process_frame
	var flow: Control = board.get_node("Flow")
	_clear(flow, "4-4")
	_clear(flow, "3-4")
	_put(flow, "4-4", "queen", 0)
	var king := _put(flow, "3-4", "king", 1)
	Fog.hide(king)

	# Selecting an attacker scans the squares it hits and, without a guard,
	# tints the enemy king red - which bleeds through the face-down cover and
	# gives its identity away.
	board._on_flow_send_location("4-4")
	_check(Fog.is_hidden(king), "the attacked black king stays covered")
	_check(king.modulate.is_equal_approx(Color(1, 1, 1, 1)), "the covered king gets no check tint")

	# Castling must be refused when a landing square is occupied; the random
	# deal can put a rook beside the king on a file the old code never checked,
	# which drops both pieces into one cell.
	_clear(flow, "5-7")
	_clear(flow, "6-7")
	_clear(flow, "7-7")
	_put(flow, "5-7", "rook", 0)
	_put(flow, "6-7", "knight", 0)
	board._on_flow_send_location("4-7")
	_check(board.SpecialArea.is_empty(), "castling is not offered onto an occupied square")

	board.queue_free()
	await process_frame

	# After a king capture the board must freeze: otherwise the next move flips
	# Turn while the hand-off is skipped, so the fog is never re-applied.
	var game: Control = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var gboard: Control = game.get_node("Board")
	var white_cell := ""
	for cell in gboard.get_node("Flow").get_children():
		if cell.get_child_count() == 1 and cell.get_child(0).PieceColor == gboard.Turn:
			white_cell = cell.name
			break
	game._on_game_win()
	_check(gboard.Locked, "a finished game locks the board")
	gboard._on_flow_send_location(white_cell)
	await process_frame
	_check(gboard.SelectedNode == "", "a move after GameWin is ignored")
	game.queue_free()
	await process_frame

	print("RESULT: %d failure(s)" % _fails)
	quit(1 if _fails > 0 else 0)
