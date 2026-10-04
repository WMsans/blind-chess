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
	var layer: CanvasLayer = load("res://scenes/transition.tscn").instantiate()
	root.add_child(layer)
	await process_frame
	var veil: Control = layer.get_node("Veil")
	_check(veil.mouse_filter == Control.MOUSE_FILTER_STOP, "veil blocks the board while up")
	_check(not veil.is_covered(), "veil starts open")
	# gif 02 covers the screen with growing circles only; a radial gradient or
	# shape texture reappearing here would silently regress it to a solid iris.
	var mat: ShaderMaterial = layer.get_node("Veil/Black").material
	_check(mat.get_shader_parameter("field_texture") is ImageTexture, "the wipe uses the generated circle field")

	var covering: Tween = veil.cover()
	# A click before the cover finishes must be ignored: the hand-off is not
	# listening yet, so an early dismiss would be lost and stall the turn.
	await create_timer(0.15).timeout
	veil.dismiss()
	await covering.finished
	_check(veil.is_covered(), "a click during the cover is ignored")

	veil.arm()
	var shots := [0]
	veil.dismissed.connect(func(): shots[0] += 1)
	veil.dismiss()
	veil.dismiss()
	await create_timer(2.0).timeout
	_check(shots[0] == 1, "repeated clicks dismiss once")
	_check(not veil.is_covered(), "reveal fully opens")
	_check(not veil.visible, "veil hides after revealing")

	layer.queue_free()
	await process_frame

	# Arriving from the menu: the one-shot flag makes a fresh veil start fully
	# closed and reveal itself, so swapping scenes never flashes the new board.
	var veil_script = load("res://scripts/game/transition.gd")
	veil_script.start_covered = true
	var arriving: CanvasLayer = load("res://scenes/transition.tscn").instantiate()
	root.add_child(arriving)
	await process_frame
	var fresh: Control = arriving.get_node("Veil")
	_check(fresh.is_covered(), "a veil flagged by the menu starts covered")
	_check(not veil_script.start_covered, "the start-covered flag is one-shot")
	await create_timer(2.0).timeout
	_check(not fresh.is_covered(), "the arriving veil reveals itself")
	_check(not fresh.visible, "the arriving veil hides after revealing")

	arriving.queue_free()
	await process_frame
	print("RESULT: %d failure(s)" % _fails)
	quit(1 if _fails > 0 else 0)
