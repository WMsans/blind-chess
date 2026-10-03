extends SceneTree
## Headless check for the move-animation restructure:
##   godot --headless --script res://test_chess.gd
## Exercises the real tap handler and waits for MoveSettled, so it fails if the
## hop/land/commit sequencing stops putting pieces in the right cells.

const Juice = preload("res://ChessScripts/juice.gd")

var _fails := 0


func _initialize() -> void:
	_watchdog()
	_run()


func _watchdog() -> void:
	await create_timer(90.0).timeout
	printerr("TIMEOUT - a move never settled")
	quit(2)


func _run() -> void:
	await _test_move()
	await _test_illegal()
	await _test_capture()
	await _test_en_passant()
	await _test_castle()
	await _test_promotion()
	print("RESULT: %d failure(s)" % _fails)
	quit(1 if _fails > 0 else 0)


func _fresh() -> Control:
	var board: Control = load("res://board.tscn").instantiate()
	root.add_child(board)
	return board


func _drop(board: Control) -> void:
	board.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok   - ", message)
	else:
		_fails += 1
		printerr("  FAIL - ", message)


func _move(board: Control, from: String, to: String) -> void:
	board._on_flow_send_location(from)
	board._on_flow_send_location(to)
	await board.MoveSettled


func _test_move() -> void:
	print("normal move")
	var board := _fresh()
	await process_frame
	var flow: Control = board.get_node("Flow")

	board._on_flow_send_location("0-6")
	_check(board.Markers.size() == 2, "pawn offers two marker squares")
	_check(board.get_node("FX").get_child_count() == 2, "markers live on the FX layer")
	# Sampled after the bounce finishes: mid-tween values depend on frame pacing.
	await create_timer(0.4).timeout
	var pawn: Node2D = flow.get_node("0-6").get_child(0)
	_check(pawn.scale.is_equal_approx(Juice.SELECT_SCALE), "selected piece ends up enlarged by the bounce")

	board._on_flow_send_location("0-4")
	_check(board.Busy, "input locks while the piece is in the air")
	_check(pawn.get_parent() == board.get_node("FX"), "mover hops on the FX layer")
	await board.MoveSettled
	_check(flow.get_node("0-6").get_child_count() == 0, "origin square is empty")
	_check(flow.get_node("0-4").get_child(0) == pawn, "piece landed on the target square")
	_check(pawn.position.is_equal_approx(board.pos), "piece snapped to the square centre")
	_check(pawn.get_parent() == flow.get_node("0-4"), "piece re-parented back into the board")
	_check(board.Turn == 1, "turn passed to black")
	_check(not board.Busy, "input unlocked after the landing settles")
	await _drop(board)


func _test_illegal() -> void:
	print("illegal move")
	var board := _fresh()
	await process_frame
	var flow: Control = board.get_node("Flow")

	board._on_flow_send_location("0-6")
	board._on_flow_send_location("1-5")
	await create_timer(0.05).timeout
	_check(flow.get_node("0-6").get_child_count() == 1, "piece stayed put")
	_check(board.SelectedNode == "0-6", "selection survives the rejection")
	_check(board.Markers.size() == 2, "markers stay up after the rejection")
	_check(board.Turn == 0, "turn did not change")
	_check(not board.Busy, "rejection never locks input")
	await _drop(board)


func _test_capture() -> void:
	print("capture")
	var board := _fresh()
	await process_frame
	var flow: Control = board.get_node("Flow")

	await _move(board, "0-6", "0-4")
	await _move(board, "1-1", "1-3")
	await _move(board, "0-4", "1-3")
	var captured := flow.get_node("1-3").get_child(0)
	_check(captured.name == "Pawn" && captured.PieceColor == 0, "white pawn now owns the square")
	_check(flow.get_node("0-4").get_child_count() == 0, "attacker left its square")
	_check(board.Turn == 1, "turn passed to black")
	await _drop(board)


func _test_en_passant() -> void:
	print("en passant")
	var board := _fresh()
	await process_frame
	var flow: Control = board.get_node("Flow")

	await _move(board, "0-6", "0-4")
	await _move(board, "1-0", "2-2")
	await _move(board, "0-4", "0-3")
	await _move(board, "1-1", "1-3")
	await _move(board, "0-3", "1-3")
	var pawn := flow.get_node("1-2").get_child(0)
	_check(pawn.name == "Pawn" && pawn.PieceColor == 0, "pawn captured diagonally behind")
	_check(flow.get_node("1-3").get_child_count() == 0, "double-moved pawn is gone")
	_check(flow.get_node("0-3").get_child_count() == 0, "attacker left its square")
	await _drop(board)


func _test_castle() -> void:
	print("castling")
	var board := _fresh()
	await process_frame
	var flow: Control = board.get_node("Flow")
	flow.get_node("5-7").get_child(0).free()
	flow.get_node("6-7").get_child(0).free()

	board._on_flow_send_location("4-7")
	_check(board.Areas.has("7-7"), "rook square offered as a castling target")
	board._on_flow_send_location("7-7")
	_check(board.Busy, "castling animation started")
	await board.MoveSettled
	var king := flow.get_node("6-7").get_child(0)
	var rook := flow.get_node("5-7").get_child(0)
	_check(king.name == "King", "king castled to 6-7")
	_check(rook.name == "Rook", "rook hopped to 5-7")
	_check(flow.get_node("4-7").get_child_count() == 0 && flow.get_node("7-7").get_child_count() == 0, "castling squares vacated")
	_check(rook.Castling == false, "rook can no longer castle")
	_check(king.position.is_equal_approx(board.pos) && rook.position.is_equal_approx(board.pos), "both pieces snapped to centres")
	_check(board.Turn == 1, "turn passed to black")
	await _drop(board)


func _test_promotion() -> void:
	print("promotion")
	var board := _fresh()
	await process_frame
	var flow: Control = board.get_node("Flow")
	flow.get_node("0-1").get_child(0).free()
	flow.get_node("0-0").get_child(0).free()
	var pawn = load("res://ChessScenes/pawn.tscn").instantiate()
	pawn.Spawned(0)
	pawn.position = board.pos
	flow.get_node("0-1").add_child(pawn)

	await _move(board, "0-1", "0-0")
	_check(board.get_node("Promotion").visible, "promotion panel popped up")
	board.FinalizePromotion("Queen")
	var queen := flow.get_node("0-0").get_child(0)
	_check(queen.name == "Queen" && queen.PieceColor == 0, "pawn became a white queen")
	_check(flow.get_node("0-0").get_child_count() == 1, "only the new piece is on the square")
	_check(not board.get_node("Promotion").visible, "promotion panel closed")
	await _drop(board)
