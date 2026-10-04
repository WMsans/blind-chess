extends Control
## Radial piece-type picker for guessing a covered enemy piece's identity.
##
## Cosmetic only: the choice is recorded on the piece via Fog.set_guess and the
## board rules never see it. Owns its own entrance/exit, exactly like the
## promotion picker, but the buttons ring the tapped square instead of sitting
## in a centred panel. `open()` shows the ring, a choice emits `chosen`, and
## `close()` plays the exit and then emits `closed`.

const UiMotion = preload("res://scripts/ui/ui_motion.gd")
const AnimatedButton = preload("res://scripts/ui/animated_button.gd")

const TYPES := ["Pawn", "Knight", "Bishop", "Rook", "Queen", "King"]
const ICON := "res://assets/textures/pieces/%s%s.svg"
const RADIUS := 72.0
const BUTTON := 56.0
## Keep the ring inside the window so a corner square's palette stays reachable.
const EDGE := 10.0

signal chosen(name: String)
signal closed

@onready var Dim: ColorRect = get_node("Dim")

var _buttons: Dictionary = {}
var _chosen := ""
var _closing := false


func _ready() -> void:
	_fit()
	get_viewport().size_changed.connect(_fit)
	for i in TYPES.size():
		var type: String = TYPES[i]
		var button := AnimatedButton.new()
		button.name = type
		button.custom_minimum_size = Vector2(BUTTON, BUTTON)
		button.size = Vector2(BUTTON, BUTTON)
		button.focus_mode = Control.FOCUS_NONE
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.expand_icon = true
		_skin(button, false)
		button.pressed.connect(_choose.bind(type))
		add_child(button)
		_buttons[type] = button
	Dim.gui_input.connect(_on_dim_input)


## `at` is the tapped square's screen centre, `color` picks the piece art (0
## white, 1 black) and `current` highlights the piece's existing guess.
func open(at: Vector2, color: int, current: String) -> void:
	visible = true
	_closing = false
	_chosen = ""
	# `at` is a global point; the board owns this node and may be mid-shake.
	var view := get_viewport_rect().size
	var reach := RADIUS + BUTTON / 2.0
	var center := at - global_position
	center = Vector2(
		clampf(center.x, reach + EDGE, view.x - reach - EDGE),
		clampf(center.y, reach + EDGE, view.y - reach - EDGE)
	)
	var side := "W" if color == 0 else "B"
	for i in TYPES.size():
		var type: String = TYPES[i]
		var button: Button = _buttons[type]
		button.icon = load(ICON % [side, type])
		_skin(button, type == current)
		var angle := -PI / 2.0 + TAU * float(i) / float(TYPES.size())
		button.position = center + Vector2(cos(angle), sin(angle)) * RADIUS - Vector2(BUTTON, BUTTON) / 2.0
		# Drop the stale resting spot from a previous open so appear() records
		# this ring position as the button's home.
		button.remove_meta(UiMotion.META + "_home")
		button.appear(UiMotion.APPEAR_STAGGER * i)
	Dim.modulate.a = 0.0
	UiMotion._track(self, create_tween()).tween_property(Dim, "modulate:a", 1.0, 0.14)


func close() -> void:
	if _closing:
		return
	_closing = true
	for i in TYPES.size():
		_buttons[TYPES[i]].dismiss(UiMotion.DISMISS_STAGGER * i)
	var t := UiMotion._track(self, create_tween())
	t.tween_interval(0.10)
	t.tween_property(Dim, "modulate:a", 0.0, 0.14)
	t.tween_callback(_finish)


func _choose(type: String) -> void:
	if _chosen != "" or _closing:
		return
	_chosen = type
	chosen.emit(type)


func _finish() -> void:
	visible = false
	_closing = false
	_chosen = ""
	closed.emit()


# The board root is a small Control, so a full-rect anchor would leave the dim
# and the ring the size of a tile. Size to the viewport instead.
func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()


# Compact skin: the theme's button margins are built for text and would leave a
# 56px disc almost no room for its icon.
func _skin(button: Button, active: bool) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = UiMotion.BG_RAISED
	box.set_corner_radius_all(14)
	box.set_border_width_all(3)
	box.border_color = UiMotion.GOLD if active else UiMotion.BORDER
	box.content_margin_left = 4.0
	box.content_margin_top = 4.0
	box.content_margin_right = 4.0
	box.content_margin_bottom = 4.0
	button.add_theme_stylebox_override("normal", box)
	var hover := box.duplicate() as StyleBoxFlat
	hover.bg_color = UiMotion.BG_RAISED.lightened(0.12)
	hover.border_color = UiMotion.GOLD
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
