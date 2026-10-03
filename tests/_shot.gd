extends SceneTree

func _initialize() -> void:
	_run()

func _save(tag: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png("res://tests/_shot_%s.png" % tag)
	print("saved ", tag)

func _run() -> void:
	var s: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(s)
	var b: Node = s.get_node("Board")
	await create_timer(0.8).timeout
	await _save("initial")
	b._on_flow_send_location("4-6")
	await create_timer(0.8).timeout
	await _save("selected")
	b._on_flow_hover("3-6", true)
	await create_timer(0.5).timeout
	await _save("hover")
	quit()
