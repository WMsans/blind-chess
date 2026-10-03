extends Control
## The pawn-promotion picker.
##
## Owns its own entrance and exit. The board drives it: `open(color)` shows the
## four choices, a choice emits `chosen`, and `close()` plays the exit and then
## emits `closed`. `visible` is set synchronously on open (input blocking) and
## only cleared when the exit finishes.

const UiMotion = preload("res://scripts/ui/ui_motion.gd")

const PIECES := ["Queen", "Rook", "Bishop", "Knight"]
const ICONS := {
	"Queen": ["res://assets/textures/pieces/WQueen.svg", "res://assets/textures/pieces/BQueen.svg"],
	"Rook": ["res://assets/textures/pieces/WRook.svg", "res://assets/textures/pieces/BRook.svg"],
	"Bishop": ["res://assets/textures/pieces/WBishop.svg", "res://assets/textures/pieces/BBishop.svg"],
	"Knight": ["res://assets/textures/pieces/WKnight.svg", "res://assets/textures/pieces/BKnight.svg"],
}

signal chosen(piece_name: String)
signal closed

@onready var Dim: ColorRect = get_node("Dim")
@onready var Plate: Panel = get_node("Panel")

var _chosen := ""
var _closing := false


func _ready() -> void:
	for piece in PIECES:
		Plate.get_node(piece).pressed.connect(_choose.bind(piece))


## `color` is 0 for white, 1 for black - it picks which piece art to show.
func open(color: int) -> void:
	visible = true
	_closing = false
	_chosen = ""
	for piece in PIECES:
		var button: Button = Plate.get_node(piece)
		button.icon = load(ICONS[piece][color])
		button.expand_icon = true
	UiMotion.prepare(Plate)
	Dim.modulate = Color(1, 1, 1, 0)
	UiMotion._track(self, create_tween()).tween_property(Dim, "modulate:a", 1.0, 0.16)
	Plate.modulate.a = 0.0
	Plate.scale = Vector2(0.85, 0.85)
	var pop := UiMotion._track(self, create_tween())
	pop.tween_property(Plate, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.parallel().tween_property(Plate, "modulate:a", 1.0, 0.18)
	var i := 0
	for piece in PIECES:
		Plate.get_node(piece).appear(UiMotion.APPEAR_STAGGER * i)
		i += 1
	await get_tree().process_frame
	Plate.get_node("Queen").grab_focus()


func close() -> void:
	if _closing:
		return
	_closing = true
	var i := 0
	for piece in PIECES:
		Plate.get_node(piece).dismiss(UiMotion.DISMISS_STAGGER * i)
		i += 1
	var t := UiMotion._track(self, create_tween())
	t.tween_interval(0.12)
	t.tween_property(Plate, "scale", Vector2(0.85, 0.85), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(Plate, "modulate:a", 0.0, 0.16)
	t.parallel().tween_property(Dim, "modulate:a", 0.0, 0.16)
	t.tween_callback(_finish_close)


func _choose(piece_name: String) -> void:
	if _chosen != "":
		return
	_chosen = piece_name
	chosen.emit(piece_name)


func _finish_close() -> void:
	visible = false
	_closing = false
	closed.emit()
