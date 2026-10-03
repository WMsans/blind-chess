extends Control
## Hot-seat orchestration for blind chess.
##
## The board owns the rules; this scene owns the turn. It covers the board,
## flips it for the next player, re-applies the fog, and collects captures in
## the two side trays. While the veil is up it also blocks board input, so a
## player cannot move until the next one taps to reveal.

const Fog = preload("res://scripts/fx/fog.gd")

const WAKE_COLOR := Color("#fff4dc")
const SPARK := Color("#ffd76a")

@onready var Board: Control = get_node("Board")
@onready var Flow: Control = Board.get_node("Flow")
@onready var WhiteTray = get_node("Captured/WhiteTray")
@onready var BlackTray = get_node("Captured/BlackTray")
@onready var Veil: Control = get_node("TurnTransition/Veil")

var _handoff := false
var _game_over := false


func _ready() -> void:
	Board.Captured.connect(_on_captured)
	Board.GameWin.connect(_on_game_win)
	Board.MoveSettled.connect(_on_move_settled)
	_apply_fog()


## Cover every piece the side to move is not allowed to see.
func _apply_fog() -> void:
	for cell in Flow.get_children():
		if cell.get_child_count() != 1:
			continue
		var piece: Node2D = cell.get_child(0)
		if piece.PieceColor == Board.Turn:
			Fog.show(piece)
		else:
			Fog.hide(piece)


func _on_captured(victim: Node2D) -> void:
	var tray = BlackTray if victim.PieceColor == 0 else WhiteTray
	var item: TextureRect = tray.add_piece(victim.texture)
	await get_tree().process_frame
	Board.get_node("Effects").burst(item.get_global_rect().get_center(), SPARK, 8, 260.0)


func _on_game_win() -> void:
	_game_over = true
	Board.Locked = true


func _on_move_settled() -> void:
	if _handoff or _game_over:
		return
	_handoff = true
	# A promotion leaves its picker open; cover only once the player has chosen.
	while Board.get_node("Promotion").visible:
		await get_tree().process_frame
	await Veil.cover().finished
	_apply_fog()
	var center := get_viewport_rect().size / 2.0
	Board.get_node("Effects").shockwave(center, 0.018, WAKE_COLOR, 1.0)
	Board._Shake(0.35)
	# Rotate while covered, then arm the click: revealing during the spin (or
	# before this point) is what the early-dismiss guard exists to prevent.
	await _rotate_board().finished
	Veil.set_prompt("BLACK TO MOVE — TAP" if Board.Turn == 1 else "WHITE TO MOVE — TAP")
	Veil.arm()
	await Veil.dismissed
	Board.get_node("Effects").shockwave(center, 0.014, WAKE_COLOR, 1.0)
	Board._Shake(0.25)
	_handoff = false


## Rotate the board about its own centre. Frame is centred on the same point, so
## it needs no rotation; the pivot is what keeps the board on top of itself.
func _rotate_board() -> Tween:
	Flow.pivot_offset = Flow.size / 2.0
	var target := PI if absf(Flow.rotation) < PI / 2.0 else 0.0
	var t := create_tween()
	t.tween_property(Flow, "rotation", target, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return t
