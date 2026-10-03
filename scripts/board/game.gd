extends Control

signal GameWin
# Emitted once per capture, while the victim still holds its real texture.
signal Captured(victim: Node2D)
# Emitted once a move animation has fully settled and input is unlocked again.
signal MoveSettled

const Juice = preload("res://scripts/fx/juice.gd")
const PROMOTION_SCENES := {
	"Bishop": preload("res://scenes/pieces/bishop.tscn"),
	"Queen": preload("res://scenes/pieces/queen.tscn"),
	"Rook": preload("res://scenes/pieces/rook.tscn"),
	"Knight": preload("res://scenes/pieces/knight.tscn"),
}

const MARKER_DOT := Color(0.13, 0.18, 0.13, 0.32)
const MARKER_RING := Color(0.13, 0.18, 0.13, 0.55)
const DENY_COLOR := Color(0.95, 0.28, 0.28, 0.9)

# Shockwave push, in screen-UV units. Bigger number = harder warp.
const WAVE_SELECT := 0.006
const WAVE_LAUNCH := 0.014
const WAVE_LAND := 0.022
const WAVE_CAPTURE := 0.03
const WAVE_WHITE := Color("#fff4dc")
const WAVE_LAUNCH_COLOR := Color("#cfe8ff")
const SPARK := Color("#ffd76a")
const DUST := Color("#d9d2bb")

# Screen shake is trauma-based: hits add trauma, it drains, and the offset is
# trauma squared so light taps stay subtle and heavy ones hit hard.
const SHAKE_MAX := 13.0
const SHAKE_DECAY := 2.4
const SHAKE_FREQ := 32.0

# Selected node is the button pressed before the one you just pressed.
var SelectedNode = ""
# The sprite currently selected, so it can be animated when released.
var SelectedPiece: Node2D = null
# Move markers live in FX so board cells only ever hold a single piece.
var Markers: Array[Control] = []
# True while a move animation plays: board input is ignored until it settles.
var Busy := false
# If you don't have a good solution, do your promotions with another variable~
var SavedNode = ""
var Turn = 0

# Location on which node was clicked.
# Ints are here to reduce the size of some lines.
var LocationX: String
var LocationY: String
var LocationXInt: int
var LocationYInt: int

# This is the board buttons.
@export_node_path("FlowContainer") var BoardPath
@onready var Flow = get_node(BoardPath)
@onready var FX: Node2D = get_node("FX")
@onready var Effects: Node2D = get_node("Effects")

@onready var pos: Vector2 = Vector2(Flow.TileXSize / 2, Flow.TileYSize / 2)
# Areas where the player can move
var Areas: PackedStringArray
# this is seperate the Areas for special circumstances, like castling.
var SpecialArea: PackedStringArray

# Shake lives on the root Board node, which nothing else writes - the generator
# centres Flow, not Board - so _Center() on resize never fights it.
var Trauma := 0.0
var _ShakeClock := 0.0


func _ready():
	_StylePromotion()


func _process(delta: float) -> void:
	if Trauma <= 0.0:
		return
	_ShakeClock += delta
	Trauma = maxf(Trauma - SHAKE_DECAY * delta, 0.0)
	var amp := Trauma * Trauma * SHAKE_MAX
	if Trauma <= 0.0:
		position = Vector2.ZERO
	else:
		position = Vector2(sin(_ShakeClock * SHAKE_FREQ), cos(_ShakeClock * SHAKE_FREQ * 1.37)) * amp


func _Shake(trauma: float) -> void:
	Trauma = minf(Trauma + trauma, 1.0)

func _on_flow_send_location(Location: String):
	# Don't update ANYTHING if you still need to promote!
	if get_node("Promotion").visible == true:
		return
	# Nothing gets through while a piece is still in the air.
	if Busy:
		return

	var cell = Flow.get_node_or_null(Location)
	if cell == null:
		return

	# This is to try and grab the X and Y coordinates from the board
	var number = 0
	LocationX = ""
	LocationY = ""
	while Location.substr(number, 1) != "-":
		LocationX += Location.substr(number, 1)
		number += 1
	LocationY = Location.substr(number + 1)
	LocationXInt = int(LocationX)
	LocationYInt = int(LocationY)

	var occupied: bool = cell.get_child_count() != 0
	var mine: bool = occupied && cell.get_child(0).PieceColor == Turn

	if SelectedNode == "":
		if mine:
			_Select(Location, cell)
		else:
			_Reject(cell)
		return

	var en_passant_target := false
	if not mine && occupied && SpecialArea.size() == 2 && SpecialArea[0] == cell.name:
		en_passant_target = cell.get_child(0).name == "Pawn" && cell.get_child(0).EnPassant == true

	if mine && cell.get_child(0).name == "Rook" && Areas.has(cell.name):
		_DoCastle(cell)
	elif en_passant_target:
		_DoEnPassant(cell)
	elif mine:
		_Select(Location, cell)
	elif occupied:
		if Areas.has(cell.name):
			_DoCapture(cell)
		else:
			_Reject(cell)
	elif Areas.has(cell.name):
		_DoMove(cell)
	else:
		_Reject(cell)


# Cursor over a square: bounce the piece on it, but only if it is one of the
# active colour's. Enemy pieces do not react and the held piece has its own
# lift - killing its tweens here would strand the sway and outline mid-flight.
func _on_flow_hover(Location: String, entered: bool) -> void:
	if Busy:
		return
	var cell := Flow.get_node_or_null(Location)
	if cell == null || cell.get_child_count() != 1:
		return
	var piece: Node2D = cell.get_child(0)
	if piece.PieceColor != Turn || piece == SelectedPiece:
		return
	if entered:
		Juice.hover_in(piece)
	else:
		Juice.hover_out(piece)


# --- Selection -----------------------------------------------------------------

func _Select(Location: String, cell: Control):
	if is_instance_valid(SelectedPiece):
		Juice.release(SelectedPiece)
	SelectedNode = Location
	SelectedPiece = cell.get_child(0)
	Juice.select(SelectedPiece)
	Juice.tap(cell)
	Effects.shockwave(_CellCenter(cell), WAVE_SELECT, WAVE_LAUNCH_COLOR, 0.35)
	_Shake(0.1)
	GetMovableAreas()
	_ShowMarkers()


func _ReleaseSelection(except: Node2D = null):
	_ClearMarkers()
	if is_instance_valid(SelectedPiece) && SelectedPiece != except:
		Juice.release(SelectedPiece)
	SelectedPiece = null
	SelectedNode = ""


# --- Feedback ------------------------------------------------------------------

func _Reject(cell: Control):
	Juice.tap(cell)
	if is_instance_valid(SelectedPiece):
		Juice.reject(SelectedPiece)
	Juice.flash_out(_MakeMarker(cell, false, DENY_COLOR))


func _CellCenter(cell: Control) -> Vector2:
	return cell.global_position + cell.size / 2.0


func _MakeMarker(cell: Control, filled: bool, color: Color) -> Control:
	var tile: float = Flow.TileXSize
	var marker := Panel.new()
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	if filled:
		marker.size = Vector2(tile * 0.36, tile * 0.36)
		box.bg_color = color
	else:
		marker.size = Vector2(tile * 0.92, tile * 0.92)
		box.bg_color = Color(0, 0, 0, 0)
		box.set_border_width_all(4)
		box.border_color = color
	box.set_corner_radius_all(int(marker.size.x / 2.0))
	marker.add_theme_stylebox_override("panel", box)
	FX.add_child(marker)
	marker.global_position = _CellCenter(cell) - marker.size / 2.0
	return marker


func _ShowMarkers():
	_ClearMarkers()
	for name in Areas:
		_AddMarker(name, false)
	# Castling and en passant land on squares that aren't in Areas.
	if not is_instance_valid(SelectedPiece) || SpecialArea.size() != 2:
		return
	if SelectedPiece.name == "King":
		_AddMarker(SpecialArea[0], false)
		_AddMarker(SpecialArea[1], false)
	elif SelectedPiece.name == "Pawn":
		_AddMarker(SpecialArea[1], false)


func _AddMarker(Location: String, force_dot: bool):
	var cell := Flow.get_node_or_null(Location)
	if cell == null:
		return
	var filled: bool = force_dot || cell.get_child_count() == 0
	var marker := _MakeMarker(cell, filled, MARKER_DOT if filled else MARKER_RING)
	Markers.append(marker)
	Juice.marker_in(marker)


func _ClearMarkers():
	for marker in Markers:
		if is_instance_valid(marker):
			marker.queue_free()
	Markers.clear()


# --- Move execution ------------------------------------------------------------
# Every move hops through FX and only lands in its cell as the impact beat
# starts, so UpdateGame always sees the destination in its final state.

func _DoMove(cell: Control):
	var piece = Flow.get_node(SelectedNode).get_child(0)
	SavedNode = str(cell.name)
	_ReleaseSelection(piece)
	_Commit(piece, cell)


func _DoCapture(cell: Control):
	var piece = Flow.get_node(SelectedNode).get_child(0)
	var victim = cell.get_child(0)
	if victim.name == "King":
		GameWin.emit()
	SavedNode = str(cell.name)
	_ReleaseSelection(piece)
	_Commit(piece, cell, victim)


func _DoCastle(rook_cell: Control):
	var king = Flow.get_node(SelectedNode).get_child(0)
	var rook = rook_cell.get_child(0)
	var king_target := Flow.get_node(SpecialArea[1])
	var rook_target := Flow.get_node(SpecialArea[0])
	_ReleaseSelection(king)
	_CommitPair(king, king_target, rook, rook_target)


func _DoEnPassant(victim_cell: Control):
	var pawn = Flow.get_node(SelectedNode).get_child(0)
	var victim = victim_cell.get_child(0)
	var target := Flow.get_node(SpecialArea[1])
	SavedNode = str(target.name)
	_ReleaseSelection(pawn)
	_Commit(pawn, target, victim)


func _Commit(piece: Node2D, target: Control, victim: Node2D = null):
	Busy = true
	var from: Vector2 = piece.global_position
	var landing := _CellCenter(target)
	Effects.burst(from, DUST, 6, 110.0, 200.0, 60.0, 0.3)
	# Effects.shockwave(from, WAVE_LAUNCH, WAVE_LAUNCH_COLOR, 0.6)
	_Shake(0.22)
	var flight := Juice.hop(piece, _Lift(piece), landing)
	await flight.finished
	var captured := is_instance_valid(victim)
	if captured:
		Captured.emit(victim)
		victim.reparent(FX)
		Juice.pop_out(victim)
	_Drop(piece, target)
	UpdateGame(target)
	Juice.impact(piece)
	Effects.burst(landing, SPARK, 14, 300.0)
	if captured:
		Effects.burst(landing, WAVE_WHITE, 24, 360.0)
		Effects.shockwave(landing, WAVE_CAPTURE, WAVE_WHITE, 1.0)
		_Shake(1.0)
	else:
		Effects.shockwave(landing, WAVE_LAND, WAVE_WHITE, 0.9)
		_Shake(0.7)
	# A plain timer, not the tween: a promotion can free the piece mid-settle and
	# a tween bound to it would never resume this await.
	await get_tree().create_timer(Juice.SETTLE_TIME).timeout
	Busy = false
	MoveSettled.emit()


func _CommitPair(king: Node2D, king_target: Control, rook: Node2D, rook_target: Control):
	Busy = true
	var king_from: Vector2 = king.global_position
	var rook_from: Vector2 = rook.global_position
	Effects.burst(king_from, DUST, 5, 110.0, 200.0, 60.0, 0.3)
	Effects.burst(rook_from, DUST, 5, 110.0, 200.0, 60.0, 0.3)
	Effects.shockwave(king_from, WAVE_LAUNCH, WAVE_LAUNCH_COLOR, 0.6)
	_Shake(0.25)
	var king_flight := Juice.hop(king, _Lift(king), _CellCenter(king_target))
	var rook_flight := Juice.hop(rook, _Lift(rook), _CellCenter(rook_target))
	await rook_flight.finished
	# The king's hop may already have finished this frame - awaiting a signal
	# that already fired would hang forever.
	if king_flight.is_running():
		await king_flight.finished
	_Drop(king, king_target)
	_Drop(rook, rook_target)
	rook.Castling = false
	UpdateGame(king_target)
	Juice.impact(king)
	Juice.impact(rook)
	Effects.burst(_CellCenter(king_target), SPARK, 16, 300.0)
	Effects.shockwave(_CellCenter(king_target), WAVE_LAND, WAVE_WHITE, 0.9)
	_Shake(0.7)
	await get_tree().create_timer(Juice.SETTLE_TIME).timeout
	Busy = false
	MoveSettled.emit()


# Move a piece into the FX layer without it visibly moving a pixel.
func _Lift(piece: Node2D) -> Vector2:
	var from: Vector2 = piece.global_position
	piece.reparent(FX)
	piece.global_position = from
	return from


func _Drop(piece: Node2D, target: Control):
	piece.reparent(target)
	piece.global_position = _CellCenter(target)
	piece.rotation = 0.0


# --- Promotion panel -----------------------------------------------------------

func _StylePromotion():
	var panel := get_node("Promotion") as Panel
	panel.add_theme_stylebox_override("panel", _Flat(Color("#232a20"), 12, Color("#4f5d44")))
	for button in panel.get_children():
		button.add_theme_stylebox_override("normal", _Flat(Color("#39452f"), 8))
		button.add_theme_stylebox_override("hover", _Flat(Color("#4b5a3c"), 8))
		button.add_theme_stylebox_override("pressed", _Flat(Color("#2b3423"), 8))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.add_theme_color_override("font_color", Color("#f0f2e6"))


func _Flat(color: Color, radius: int, border := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	if border.a > 0.0:
		box.set_border_width_all(3)
		box.border_color = border
	return box


func _ShowPromotion():
	var panel := get_node("Promotion") as Control
	panel.visible = true
	Juice.panel_in(panel)

func UpdateGame(cell):
	SelectedNode = ""
	var things = Flow.get_children()
	# get the en-passantable pieces and undo them
	for i in things:
		if i.get_child_count() != 0 && i.get_child(0).name == "Pawn" && i.get_child(0).PieceColor == Turn && i.get_child(0).EnPassant == true:
			i.get_child(0).EnPassant = false
		# This changes the color to regular white. For kings.
		elif i.get_child_count() != 0:
			i.get_child(0).modulate = Color(1, 1, 1, 1)
	
	# Remove and add the abilities once they are either used or not used
	if cell.get_child(0).name == "Pawn":
		PawnPromotion(cell.get_child(0))
		if cell.get_child(0).DoubleStart == true:
			cell.get_child(0).EnPassant = true
		cell.get_child(0).DoubleStart = false
	if cell.get_child(0).name == "King":
		cell.get_child(0).Castling = false
	if cell.get_child(0).name == "Rook":
		cell.get_child(0).Castling = false
	
	# King checking.
	CheckKing(things)
	SelectedNode = ""
	
	if Turn == 0:
		Turn = 1
	else:
		Turn = 0

# Below is the movement that is used for the pieces
func GetMovableAreas():
	# Clearing the arrays
	Areas.clear()
	SpecialArea.clear()
	var Piece = Flow.get_node(SelectedNode).get_child(0)
	# For the selected piece that we have, we can get the movement that we need here.
	if Piece.name == "Pawn":
		GetPawn(Piece)
	elif Piece.name == "Bishop":
		GetDiagonals()
	elif Piece.name == "King":
		GetAround(Piece)
	elif Piece.name == "Queen":
		GetDiagonals()
		GetRows()
	elif Piece.name == "Rook":
		GetRows()
	elif Piece.name == "Knight":
		GetHorse()

func PawnPromotion(Piece):
	# This is for going from the bottom to the top, also known as the white pawns.
	if IsNull(LocationX + "-" + str(LocationYInt - 1)) && Piece.PieceColor == 0:
		_ShowPromotion()
	elif IsNull(LocationX + "-" + str(LocationYInt + 1)) && Piece.PieceColor == 1:
		_ShowPromotion()


func FinalizePromotion(Selection):
	var cell := Flow.get_node(SavedNode)
	var pawn = cell.get_child(0)
	var color: int = pawn.PieceColor
	# The pawn has to leave before the replacement arrives: cells hold one piece.
	pawn.free()
	var new_piece = PROMOTION_SCENES[Selection].instantiate()
	new_piece.Spawned(color)
	new_piece.position = pos
	cell.add_child(new_piece)
	Juice.spawn(new_piece)
	_PromotionFX(cell)
	get_node("Promotion").visible = false


func _PromotionFX(cell: Control) -> void:
	var center := _CellCenter(cell)
	Effects.burst(center, SPARK, 20, 320.0)
	Effects.shockwave(center, WAVE_LAND, WAVE_WHITE, 0.9)
	_Shake(0.6)

func GetPawn(Piece):
	# This is for going from the bottom to the top, also known as the white pawns.
	if Piece.PieceColor == 0:
		if not IsNull(LocationX + "-" + str(LocationYInt - 1)) && Flow.get_node(LocationX + "-" + str(LocationYInt - 1)).get_child_count() == 0:
			Areas.append(LocationX + "-" + str(LocationYInt - 1))
		if not IsNull(LocationX + "-" + str(LocationYInt - 2)) && Piece.DoubleStart == true && Flow.get_node(LocationX + "-" + str(LocationYInt - 2)).get_child_count() == 0:
			Areas.append(LocationX + "-" + str(LocationYInt - 2))
		# Attacking squares
		if not IsNull(str(LocationXInt - 1) + "-" + str(LocationYInt - 1)) && Flow.get_node(str(LocationXInt - 1) + "-" + str(LocationYInt - 1)).get_child_count() == 1:
			Areas.append(str(LocationXInt - 1) + "-" + str(LocationYInt - 1))
		if not IsNull(str(LocationXInt + 1) + "-" + str(LocationYInt - 1)) && Flow.get_node(str(LocationXInt + 1) + "-" + str(LocationYInt - 1)).get_child_count() == 1:
			Areas.append(str(LocationXInt + 1) + "-" + str(LocationYInt - 1))
		# En passant
		if not IsNull(str(LocationXInt - 1) + "-" + LocationY) && not IsNull(str(LocationXInt - 1) + "-" + str(LocationYInt - 1)):
			if _IsEnPassantVictim(str(LocationXInt - 1) + "-" + LocationY) && Flow.get_node(str(LocationXInt - 1) + "-" + str(LocationYInt - 1)).get_child_count() != 1:
				SpecialArea.append(str(LocationXInt - 1) + "-" + LocationY)
				SpecialArea.append(str(LocationXInt - 1) + "-" + str(LocationYInt - 1))
		if not IsNull(str(LocationXInt + 1) + "-" + LocationY) && not IsNull(str(LocationXInt + 1) + "-" + str(LocationYInt - 1)):
			if _IsEnPassantVictim(str(LocationXInt + 1) + "-" + LocationY) && Flow.get_node(str(LocationXInt + 1) + "-" + str(LocationYInt - 1)).get_child_count() != 1:
				SpecialArea.append(str(LocationXInt + 1) + "-" + LocationY)
				SpecialArea.append(str(LocationXInt + 1) + "-" + str(LocationYInt - 1))
	# Black pawns
	else:
		if not IsNull(LocationX + "-" + str(LocationYInt + 1)) && Flow.get_node(LocationX + "-" + str(LocationYInt + 1)).get_child_count() == 0:
			Areas.append(LocationX + "-" + str(LocationYInt + 1))
		if not IsNull(LocationX + "-" + str(LocationYInt + 2)) && Piece.DoubleStart == true && Flow.get_node(LocationX + "-" + str(LocationYInt + 2)).get_child_count() == 0:
			Areas.append(LocationX + "-" + str(LocationYInt + 2))
		# Attacking squares
		if not IsNull(str(LocationXInt - 1) + "-" + str(LocationYInt + 1)) && Flow.get_node(str(LocationXInt - 1) + "-" + str(LocationYInt + 1)).get_child_count() == 1:
			Areas.append(str(LocationXInt - 1) + "-" + str(LocationYInt + 1))
		if not IsNull(str(LocationXInt + 1) + "-" + str(LocationYInt + 1)) && Flow.get_node(str(LocationXInt + 1) + "-" + str(LocationYInt + 1)).get_child_count() == 1:
			Areas.append(str(LocationXInt + 1) + "-" + str(LocationYInt + 1))
		# En passant
		if not IsNull(str(LocationXInt - 1) + "-" + LocationY) && not IsNull(str(LocationXInt - 1) + "-" + str(LocationYInt + 1)):
			if _IsEnPassantVictim(str(LocationXInt - 1) + "-" + LocationY) && Flow.get_node(str(LocationXInt - 1) + "-" + str(LocationYInt + 1)).get_child_count() != 1:
				SpecialArea.append(str(LocationXInt - 1) + "-" + LocationY)
				SpecialArea.append(str(LocationXInt - 1) + "-" + str(LocationYInt + 1))
		if not IsNull(str(LocationXInt + 1) + "-" + LocationY) && not IsNull(str(LocationXInt + 1) + "-" + str(LocationYInt + 1)):
			if _IsEnPassantVictim(str(LocationXInt + 1) + "-" + LocationY) && Flow.get_node(str(LocationXInt + 1) + "-" + str(LocationYInt+ 1)).get_child_count() != 1:
				SpecialArea.append(str(LocationXInt + 1) + "-" + LocationY)
				SpecialArea.append(str(LocationXInt + 1) + "-" + str(LocationYInt + 1))

# The pawn beside us only counts for en passant if it is an enemy pawn that
# just double-stepped - without the colour/flag check SpecialArea fills up with
# squares that are not en passant targets at all.
func _IsEnPassantVictim(Location: String) -> bool:
	var cell := Flow.get_node_or_null(Location)
	if cell == null || cell.get_child_count() != 1:
		return false
	var neighbor = cell.get_child(0)
	return neighbor.name == "Pawn" && neighbor.EnPassant == true


func GetAround(Piece):
	# Single Rows
	if not IsNull(LocationX + "-" + str(LocationYInt + 1)):
		Areas.append(LocationX + "-" + str(LocationYInt + 1))
	if not IsNull(LocationX + "-" + str(LocationYInt - 1)):
		Areas.append(LocationX + "-" + str(LocationYInt - 1))
	if not IsNull(str(LocationXInt + 1) + "-" + LocationY):
		Areas.append(str(LocationXInt + 1) + "-" + LocationY)
	if not IsNull(str(LocationXInt - 1) + "-" + LocationY):
		Areas.append(str(LocationXInt - 1) + "-" + LocationY)
	# Diagonal
	if not IsNull(str(LocationXInt + 1) + "-" + str(LocationYInt + 1)):
		Areas.append(str(LocationXInt + 1) + "-" + str(LocationYInt + 1))
	if not IsNull(str(LocationXInt - 1) + "-" + str(LocationYInt + 1)):
		Areas.append(str(LocationXInt - 1) + "-" + str(LocationYInt + 1))
	if not IsNull(str(LocationXInt + 1) + "-" + str(LocationYInt - 1)):
		Areas.append(str(LocationXInt + 1) + "-" + str(LocationYInt - 1))
	if not IsNull(str(LocationXInt - 1) + "-" + str(LocationYInt - 1)):
		Areas.append(str(LocationXInt - 1) + "-" + str(LocationYInt - 1))
	# Castling, if that is the case
	if Piece.Castling == true:
		Castle()

func GetRows():
	var AddX = 1
	# Getting the horizontal rows first.
	while not IsNull(str(LocationXInt + AddX) + "-" + LocationY):
		Areas.append(str(LocationXInt + AddX) + "-" + LocationY)
		if Flow.get_node(str(LocationXInt + AddX) + "-" + LocationY).get_child_count() != 0:
			break
		AddX += 1
	AddX = 1
	while not IsNull(str(LocationXInt - AddX) + "-" + LocationY):
		Areas.append(str(LocationXInt - AddX) + "-" + LocationY)
		if Flow.get_node(str(LocationXInt - AddX) + "-" + LocationY).get_child_count() != 0:
			break
		AddX += 1
	var AddY = 1
	# Now we are getting the vertical rows.
	while not IsNull(LocationX + "-" + str(LocationYInt + AddY)):
		Areas.append(LocationX + "-" + str(LocationYInt + AddY))
		if Flow.get_node(LocationX + "-" + str(LocationYInt + AddY)).get_child_count() != 0:
			break
		AddY += 1
	AddY = 1
	while not IsNull(LocationX + "-" + str(LocationYInt - AddY)):
		Areas.append(LocationX + "-" + str(LocationYInt - AddY))
		if Flow.get_node(LocationX + "-" + str(LocationYInt - AddY)).get_child_count() != 0:
			break
		AddY += 1
	
func GetDiagonals():
	var AddX = 1
	var AddY = 1
	while not IsNull(str(LocationXInt + AddX) + "-" + str(LocationYInt + AddY)):
		Areas.append(str(LocationXInt + AddX) + "-" + str(LocationYInt + AddY))
		if Flow.get_node(str(LocationXInt + AddX) + "-" + str(LocationYInt + AddY)).get_child_count() != 0:
			break
		AddX += 1
		AddY += 1
	AddX = 1
	AddY = 1
	while not IsNull(str(LocationXInt - AddX) + "-" + str(LocationYInt + AddY)):
		Areas.append(str(LocationXInt - AddX) + "-" + str(LocationYInt + AddY))
		if Flow.get_node(str(LocationXInt - AddX) + "-" + str(LocationYInt + AddY)).get_child_count() != 0:
			break
		AddX += 1
		AddY += 1
	AddX = 1
	AddY = 1
	while not IsNull(str(LocationXInt + AddX) + "-" + str(LocationYInt - AddY)):
		Areas.append(str(LocationXInt + AddX) + "-" + str(LocationYInt - AddY))
		if Flow.get_node(str(LocationXInt + AddX) + "-" + str(LocationYInt - AddY)).get_child_count() != 0:
			break
		AddX += 1
		AddY += 1
	AddX = 1
	AddY = 1
	while not IsNull(str(LocationXInt - AddX) + "-" + str(LocationYInt - AddY)):
		Areas.append(str(LocationXInt - AddX) + "-" + str(LocationYInt - AddY))
		if Flow.get_node(str(LocationXInt - AddX) + "-" + str(LocationYInt - AddY)).get_child_count() != 0:
			break
		AddX += 1
		AddY += 1

func GetHorse():
	var TheX = 2
	var TheY = 1
	var number = 0
	while number != 8:
		# So this one is interesting. This is most likely the cleanest code here.
		# Get the numbers, replace the numbers, and loop until it stops.
		if not IsNull(str(LocationXInt + TheX) + "-" + str(LocationYInt + TheY)):
			Areas.append(str(LocationXInt + TheX) + "-" + str(LocationYInt + TheY))
		number += 1
		match number:
			1:
				TheX = 1
				TheY = 2
			2:
				TheX = -2
				TheY = 1
			3:
				TheX = -1
				TheY = 2
			4:
				TheX = 2
				TheY = -1
			5:
				TheX = 1
				TheY = -2
			6:
				TheX = -2
				TheY = -1
			7:
				TheX = -1
				TheY = -2

func Castle():
	# This is the castling section right here, used if a person wants to castle.
	var CounterX = 1
	# These are very similar to gathering a row, except we want free tiles and a rook
	# Counting up
	while not IsNull(str(LocationXInt + CounterX) + "-" + LocationY) && Flow.get_node(str(LocationXInt + CounterX) + "-" + LocationY).get_child_count() == 0:
		CounterX += 1
	if not IsNull(str(LocationXInt + CounterX) + "-" + LocationY) && Flow.get_node(str(LocationXInt + CounterX) + "-" + LocationY).get_child(0).name == "Rook":
		if Flow.get_node(str(LocationXInt + CounterX) + "-" + LocationY).get_child(0).Castling == true:
			Areas.append(str(LocationXInt + CounterX) + "-" + LocationY)
			SpecialArea.append(str(LocationXInt + 1) + "-" + LocationY)
			SpecialArea.append(str(LocationXInt + 2) + "-" + LocationY)
	# Counting down
	CounterX = -1
	while not IsNull(str(LocationXInt + CounterX) + "-" + LocationY) && Flow.get_node(str(LocationXInt + CounterX) + "-" + LocationY).get_child_count() == 0:
		CounterX -= 1
	if not IsNull(str(LocationXInt + CounterX) + "-" + LocationY) && Flow.get_node(str(LocationXInt + CounterX) + "-" + LocationY).get_child(0).name == "Rook":
		if Flow.get_node(str(LocationXInt + CounterX) + "-" + LocationY).get_child(0).Castling == true:
			Areas.append(str(LocationXInt + CounterX) + "-" + LocationY)
			SpecialArea.append(str(LocationXInt - 1) + "-" + LocationY)
			SpecialArea.append(str(LocationXInt - 2) + "-" + LocationY)

# One function that shortens everything. Its also a pretty good way to see if we went off the board or not.
func IsNull(Location):
	if Flow.get_node_or_null(Location) == null:
		return true
	else:
		IsKing(Location)
		return false

# Checking for a king.
func CheckKing(Children):
	for i in Children:
		if i.get_child_count() != 0:
			SelectedNode = str(i.name)
			GetMovableAreas()

# Helper function
func IsKing(Location):
	var TheNode = Flow.get_node_or_null(Location)
	if TheNode != null && TheNode.get_child_count() != 0 && TheNode.get_child(0).PieceColor != Turn && TheNode.get_child(0).name == "King":
		TheNode.get_child(0).modulate = Color(1, 0, 0, 1)
