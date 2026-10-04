extends SceneTree
## Headless check for the hidden-piece guess picker:
##   godot --headless --script res://tests/test_guess.gd
## Exercises the real tap handler, so it fails if tapping a covered enemy piece
## stops opening the ring, if the guess mutates the piece, or if choosing no
## longer toggles.

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


func _run() -> void:
	var board: Control = load("res://scenes/board.tscn").instantiate()
	root.add_child(board)
	await process_frame
	var flow: Control = board.get_node("Flow")
	var guess: Control = board.get_node("Guess")
	_check(not guess.visible, "the picker starts hidden")

	# A covered black pawn on an empty square.
	var pawn: Node2D = load("res://scenes/pieces/pawn.tscn").instantiate()
	pawn.Spawned(1)
	pawn.position = Vector2(25, 25)
	flow.get_node("3-3").add_child(pawn)
	Fog.hide(pawn)

	# Holding a piece must not open the picker on a square it cannot reach.
	board._on_flow_send_location("3-6")
	board._on_flow_send_location("3-3")
	await process_frame
	_check(not guess.visible, "a covered enemy tap while holding a piece is rejected")
	board._ReleaseSelection()

	board._on_flow_send_location("3-3")
	await process_frame
	_check(guess.visible, "tapping a covered enemy piece opens the picker")
	_check(board.GuessNode == "3-3", "the picker remembers the square")
	_check(guess.get_child_count() == 7, "six choices plus their dim")

	guess.chosen.emit("Knight")
	await process_frame
	_check(Fog.get_guess(pawn) == "Knight", "choosing records the guess")
	_check(pawn.name == "Pawn", "the piece's real identity is untouched")
	_check(Fog.is_hidden(pawn), "the piece stays covered after a guess")
	var icon := pawn.get_node("Cover/Icon") as TextureRect
	_check(icon.visible and icon.texture.resource_path.ends_with("BKnight.svg"), "the bet piece's icon is shown")
	_check(pawn.get_node("Cover/Mark").text == "?", "the cover still reads as a guess")
	await create_timer(0.5).timeout
	_check(not guess.visible, "the picker closes after a choice")

	# Choosing the same type again clears the guess back to a plain cover.
	board._on_flow_send_location("3-3")
	await process_frame
	guess.chosen.emit("Knight")
	await process_frame
	_check(Fog.get_guess(pawn) == "", "re-choosing the same type clears the guess")
	_check(not icon.visible, "the cover falls back to a plain ?")

	board.queue_free()
	await process_frame
	print("RESULT: %d failure(s)" % _fails)
	quit(1 if _fails > 0 else 0)
