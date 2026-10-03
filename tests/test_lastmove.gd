extends SceneTree

var _fails := 0

func _initialize() -> void:
	_watchdog()
	_run()

func _watchdog() -> void:
	await create_timer(30.0).timeout
	printerr("TIMEOUT")
	quit(2)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok   - ", message)
	else:
		_fails += 1
		printerr("  FAIL - ", message)

# The overlays are Controls placed in FX, one tile-sized panel per square, so a
# square counts as marked when a live overlay sits exactly on its corner.
func _has_mark(board: Control, loc: String) -> bool:
	var cell: Control = board.get_node("Flow").get_node(loc)
	for mark in board.LastMoveMarks:
		if not is_instance_valid(mark):
			continue
		if mark.get_parent() != board.get_node("FX"):
			continue
		if mark.global_position.distance_to(cell.global_position) < 1.0:
			return true
	return false

func _run() -> void:
	var board: Control = load("res://scenes/board.tscn").instantiate()
	root.add_child(board)
	await process_frame

	_check(board.LastMoveMarks.size() == 0, "no indicator before the first move")

	# White pawn e2 -> e3, driven the same way a click drives it.
	board._on_flow_send_location("4-6")
	board._on_flow_send_location("4-5")
	await create_timer(1.2).timeout

	_check(board.LastMoveMarks.size() == 2, "one overlay per move square")
	_check(_has_mark(board, "4-6"), "the vacated square is marked")
	_check(_has_mark(board, "4-5"), "the landing square is marked")
	_check(board.get_node("Flow").get_node("4-5").get_child_count() == 1, "the landing square still holds exactly one piece")

	# Black replies e7 -> e6; the first pair must be replaced, not stacked.
	board._on_flow_send_location("4-1")
	board._on_flow_send_location("4-2")
	await create_timer(1.2).timeout

	_check(board.LastMoveMarks.size() == 2, "a new move keeps exactly one pair of overlays")
	_check(_has_mark(board, "4-1"), "black's origin is marked")
	_check(_has_mark(board, "4-2"), "black's landing is marked")
	_check(not _has_mark(board, "4-6"), "the previous pair is cleared")

	# Overlays must ride out a 180 degree board spin: the hand-off rotates Flow
	# while FX stays put, so a redraw has to line them back up with the cells.
	board.Flow.rotation = PI
	board.DrawLastMove()
	await process_frame
	_check(_has_mark(board, "4-1"), "origin re-aligns after the board rotates")
	_check(_has_mark(board, "4-2"), "landing re-aligns after the board rotates")

	board.queue_free()
	await process_frame
	print("RESULT: %d failure(s)" % _fails)
	quit(1 if _fails > 0 else 0)
