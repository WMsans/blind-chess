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
	await create_timer(0.6).timeout
	_check(shots[0] == 1, "repeated clicks dismiss once")
	_check(not veil.is_covered(), "reveal fully opens")
	_check(not veil.visible, "veil hides after revealing")

	layer.queue_free()
	await process_frame
	print("RESULT: %d failure(s)" % _fails)
	quit(1 if _fails > 0 else 0)
