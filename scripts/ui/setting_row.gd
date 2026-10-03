extends "res://scripts/ui/animated_button.gd"
## One focusable settings row: a label, its value, and a gold value bar.
##
## Reuses AnimatedButton for hover/press/hold. Left and right step the value;
## holding a direction repeats it after the shared hold delay. This is the one
## place the direction repeat lives - AnimatedButton's hold is a visual state
## only.

signal changed(value: int)

@export var setting_name := ""
@export var label_text := ""
@export var min_value := 0
@export var max_value := 100
@export var step := 1

var value: int = 0

var _label: Label
var _bar: ColorRect
var _dir := 0
var _dir_time := 0.0
var _repeat_clock := 0.0


func _ready() -> void:
	super()
	_bar = ColorRect.new()
	_bar.color = UiMotion.GOLD
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.add_theme_color_override("font_color", UiMotion.CREAM)
	add_child(_label)
	resized.connect(_refresh)
	set_process(true)
	_refresh()


func _process(delta: float) -> void:
	super._process(delta)
	# Left/right are polled so a held key keeps stepping even if the release
	# event lands on another control.
	var d := 0
	if Input.is_action_pressed("ui_left"):
		d = -1
	elif Input.is_action_pressed("ui_right"):
		d = 1
	if d != _dir:
		_dir = d
		_dir_time = 0.0
		_repeat_clock = 0.0
		if d != 0:
			_step(d)
			return
	if _dir == 0:
		return
	_dir_time += delta
	if _dir_time < UiMotion.HOLD_DELAY:
		return
	_repeat_clock += delta
	if _repeat_clock >= UiMotion.REPEAT_INTERVAL:
		_repeat_clock -= UiMotion.REPEAT_INTERVAL
		_step(_dir)


## Swallow left/right so the viewport does not move focus off the row while the
## player is adjusting a value.
func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		accept_event()


func set_value(v: int) -> void:
	value = clampi(v, min_value, max_value)
	_refresh()


func _step(dir: int) -> void:
	var next := clampi(value + dir * step, min_value, max_value)
	if next == value:
		return
	value = next
	_refresh()
	_flash()
	changed.emit(value)


func _refresh() -> void:
	if _label == null:
		return
	_label.text = "%s   %d" % [label_text, value]
	var frac := 0.0
	if max_value > min_value:
		frac = float(value - min_value) / float(max_value - min_value)
	_bar.position = Vector2(0.0, maxf(size.y - 6.0, 0.0))
	_bar.size = Vector2(size.x * frac, 6.0)


func _flash() -> void:
	var t := UiMotion._track(self, create_tween())
	t.tween_property(_bar, "modulate", Color(1.6, 1.4, 1.0, 1.0), 0.05)
	t.tween_property(_bar, "modulate", Color.WHITE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _up() -> void:
	super()
	# AnimatedButton disables processing on release; the direction poll needs it.
	set_process(true)
