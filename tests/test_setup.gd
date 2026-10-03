extends SceneTree

var _fails := 0

func _initialize() -> void:
	_run()

func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok   - ", message)
	else:
		_fails += 1
		printerr("  FAIL - ", message)

func _fresh() -> Control:
	var board: Control = load("res://scenes/board.tscn").instantiate()
	board.get_node("Flow").Randomize = true
	root.add_child(board)
	return board

func _army(flow: Control) -> Dictionary:
	var counts := {}
	for cell in flow.get_children():
		if cell.get_child_count() != 1:
			continue
		var piece = cell.get_child(0)
		var key := "%d-%s" % [piece.PieceColor, piece.name]
		counts[key] = int(counts.get(key, 0)) + 1
	return counts

func _layout(flow: Control) -> String:
	var names := []
	for cell in flow.get_children():
		names.append("%s:%s" % [cell.name, cell.get_child(0).name if cell.get_child_count() == 1 else ""])
	return "|".join(names)

func _run() -> void:
	seed(1)
	var board := _fresh()
	await process_frame
	var flow: Control = board.get_node("Flow")
	var counts := _army(flow)
	for key in ["0-Pawn", "0-Rook", "0-Knight", "0-Bishop", "0-Queen", "0-King",
			"1-Pawn", "1-Rook", "1-Knight", "1-Bishop", "1-Queen", "1-King"]:
		var want := 8 if key.ends_with("Pawn") else (2 if key.ends_with("Rook") or key.ends_with("Knight") or key.ends_with("Bishop") else 1)
		_check(int(counts.get(key, 0)) == want, "%s count is %d" % [key, want])
	var homed := true
	for cell in flow.get_children():
		if cell.get_child_count() != 1:
			continue
		var piece = cell.get_child(0)
		var y := int(String(cell.name).split("-")[1])
		if piece.PieceColor == 0 and y < 6:
			homed = false
		if piece.PieceColor == 1 and y > 1:
			homed = false
	_check(homed, "each side sits on its own two home ranks")
	var first := _layout(flow)
	board.queue_free()
	await process_frame
	seed(2)
	var board2 := _fresh()
	await process_frame
	_check(_layout(board2.get_node("Flow")) != first, "different seeds deal different layouts")
	board2.queue_free()
	await process_frame
	print("RESULT: %d failure(s)" % _fails)
	quit(1 if _fails > 0 else 0)
