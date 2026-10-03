extends Control
## Bottom-sheet settings panel for the main menu.
##
## open() always wins over an in-flight close: it kills the panel's tweens and
## restages, so the sheet can be re-entered mid-animation without stranding a
## row. `closed` is emitted by the close tween's final callback, so a close that
## a re-open cancels never reports itself.

const UiMotion = preload("res://scripts/ui/ui_motion.gd")

signal closed

const HIDDEN_OFFSET := Vector2(0, 360)

@onready var Dim: ColorRect = get_node("Dim")
@onready var Rows: Control = get_node("Rows")

var _rest := Vector2.ZERO
var _closing := false


func _ready() -> void:
	_rest = Rows.position
	Rows.position = _rest + HIDDEN_OFFSET
	Rows.visible = false
	Dim.modulate.a = 0.0
	Dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Dim.gui_input.connect(_on_dim_input)
	get_node("Rows/Back").pressed.connect(close)


func open() -> void:
	UiMotion._kill(self)
	visible = true
	_closing = false
	Rows.visible = true
	Rows.position = _rest + HIDDEN_OFFSET
	Dim.mouse_filter = Control.MOUSE_FILTER_STOP
	Dim.modulate.a = 0.0
	var t := UiMotion._track(self, create_tween())
	t.tween_property(Rows, "position", _rest, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(Dim, "modulate:a", 1.0, 0.22)
	var i := 0
	for row in Rows.get_children():
		if row is Button:
			row.appear(0.06 + UiMotion.APPEAR_STAGGER * i)
			i += 1
	Rows.get_node("MasterVolume").grab_focus()


func close() -> void:
	if _closing or not visible:
		return
	UiMotion._kill(self)
	_closing = true
	var i := 0
	for row in Rows.get_children():
		if row is Button:
			row.dismiss(UiMotion.DISMISS_STAGGER * i)
			i += 1
	var t := UiMotion._track(self, create_tween())
	t.tween_interval(0.1)
	t.tween_property(Rows, "position", _rest + HIDDEN_OFFSET, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(Dim, "modulate:a", 0.0, 0.2)
	t.tween_callback(_finish_close)


func set_value(setting_name: String, value: int) -> void:
	for row in Rows.get_children():
		if row.has_method("set_value") and row.get("setting_name") == setting_name:
			row.set_value(value)
			return


func get_values() -> Dictionary:
	var out := {}
	for row in Rows.get_children():
		if not row.has_method("set_value"):
			continue
		var key: String = row.get("setting_name")
		if key != "":
			out[key] = row.get("value")
	return out


func _finish_close() -> void:
	visible = false
	_closing = false
	Rows.visible = false
	Dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	closed.emit()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
