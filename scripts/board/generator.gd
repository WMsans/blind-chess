extends FlowContainer

@export var BoardXSize = 8
@export var BoardYSize = 8

@export var TileXSize: float = 50
@export var TileYSize: float = 50

@export var PlayRegularGame: bool = true

# When true the opening is dealt from a shuffled army instead of the regular
# setup. Kept off by default so the existing board tests keep the standard
# layout; the game scene overrides it on the Flow node.
@export var Randomize: bool = false

# Board look
const LIGHT_SQUARE := Color("#ebecd0")
const DARK_SQUARE := Color("#779556")
const FRAME_COLOR := Color("#2b3226")
const TILE_RADIUS := 8

signal SendLocation(Location: String)
signal HoverLocation(Location: String, entered: bool)

@export var Pawn: PackedScene
@export var Bishop: PackedScene
@export var Rook: PackedScene
@export var Knight: PackedScene
@export var Queen: PackedScene
@export var King: PackedScene

func _ready():
	# stop negative numbers from happening
	if BoardXSize < 0 || BoardYSize < 0:
		return
	var NumberX: int = 0
	var NumberY: int = 0
	# Set up the board
	while NumberY != BoardYSize:
		self.size.y += TileYSize + 5
		self.size.x += TileXSize + 5
		while NumberX != BoardXSize:
			var temp = Button.new()
			temp.set_custom_minimum_size(Vector2(TileXSize, TileYSize))
			temp.connect("pressed", func():
				SendLocation.emit(temp.name))
			temp.mouse_entered.connect(func(): HoverLocation.emit(temp.name, true))
			temp.mouse_exited.connect(func(): HoverLocation.emit(temp.name, false))
			temp.set_name(str(NumberX) + "-" + str(NumberY))
			temp.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			_StyleCell(temp, (NumberX + NumberY) % 2 == 0)
			temp.focus_mode = Control.FOCUS_NONE
			add_child(temp)
			NumberX += 1
		NumberY += 1
		NumberX = 0
	_Center()
	get_viewport().size_changed.connect(_Center)
	if Randomize:
		RandomGame()
	elif PlayRegularGame == true:
		RegularGame()


# Keep the board in the middle of the window, with the slab under it.
func _Center() -> void:
	var view := get_viewport_rect().size
	position = ((view - size) / 2.0).floor()
	_SizeFrame()


# Checkerboard squares with a hover lift and a press dip.
func _StyleCell(cell: Button, dark: bool) -> void:
	var base := DARK_SQUARE if dark else LIGHT_SQUARE
	cell.add_theme_stylebox_override("normal", _Box(base))
	cell.add_theme_stylebox_override("hover", _Box(base.lightened(0.14)))
	cell.add_theme_stylebox_override("pressed", _Box(base.darkened(0.12)))
	cell.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _Box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(TILE_RADIUS)
	return box


# The dark slab the grid sits on. The panel lives in board.tscn behind Flow,
# so this only has to size and paint it.
func _SizeFrame() -> void:
	var frame := get_parent().get_node_or_null("Frame") as Panel
	if frame == null:
		return
	var box := StyleBoxFlat.new()
	box.bg_color = FRAME_COLOR
	box.set_corner_radius_all(14)
	frame.add_theme_stylebox_override("panel", box)
	frame.position = position - Vector2(9, 9)
	frame.size = size + Vector2(18, 18)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE

# 1 = black
# 0 = white
func RegularGame():
	get_node("0-0").add_child(Summon(Rook, 1))
	get_node("1-0").add_child(Summon(Knight, 1))
	get_node("2-0").add_child(Summon(Bishop, 1))
	get_node("3-0").add_child(Summon(Queen, 1))
	get_node("4-0").add_child(Summon(King, 1))
	get_node("5-0").add_child(Summon(Bishop, 1))
	get_node("6-0").add_child(Summon(Knight, 1))
	get_node("7-0").add_child(Summon(Rook, 1))
	
	get_node("0-1").add_child(Summon(Pawn, 1))
	get_node("1-1").add_child(Summon(Pawn, 1))
	get_node("2-1").add_child(Summon(Pawn, 1))
	get_node("3-1").add_child(Summon(Pawn, 1))
	get_node("4-1").add_child(Summon(Pawn, 1))
	get_node("5-1").add_child(Summon(Pawn, 1))
	get_node("6-1").add_child(Summon(Pawn, 1))
	get_node("7-1").add_child(Summon(Pawn, 1))
	
	get_node("0-6").add_child(Summon(Pawn, 0))
	get_node("1-6").add_child(Summon(Pawn, 0))
	get_node("2-6").add_child(Summon(Pawn, 0))
	get_node("3-6").add_child(Summon(Pawn, 0))
	get_node("4-6").add_child(Summon(Pawn, 0))
	get_node("5-6").add_child(Summon(Pawn, 0))
	get_node("6-6").add_child(Summon(Pawn, 0))
	get_node("7-6").add_child(Summon(Pawn, 0))
	
	get_node("0-7").add_child(Summon(Rook, 0))
	get_node("1-7").add_child(Summon(Knight, 0))
	get_node("2-7").add_child(Summon(Bishop, 0))
	get_node("3-7").add_child(Summon(Queen, 0))
	get_node("4-7").add_child(Summon(King, 0))
	get_node("5-7").add_child(Summon(Bishop, 0))
	get_node("6-7").add_child(Summon(Knight, 0))
	get_node("7-7").add_child(Summon(Rook, 0))

func Summon(Scene: PackedScene, color: int):
	var Piece = Scene.instantiate()
	Piece.Spawned(color)
	# This is the point, ignore the warning
	Piece.position = Vector2(TileXSize / 2, TileYSize / 2)
	return Piece


# Deal a full army across a colour's two home ranks. Each side draws its own
# shuffle, so the two layouts are independent.
func RandomGame():
	var army: Array[PackedScene] = []
	for i in 8:
		army.append(Pawn)
	army.append(Rook)
	army.append(Rook)
	army.append(Knight)
	army.append(Knight)
	army.append(Bishop)
	army.append(Bishop)
	army.append(Queen)
	army.append(King)

	var black := army.duplicate()
	black.shuffle()
	_Deal(black, 1, 0, 1)

	var white := army.duplicate()
	white.shuffle()
	_Deal(white, 0, 7, 6)


func _Deal(pieces: Array, color: int, back_rank: int, front_rank: int):
	for i in pieces.size():
		var rank: int = back_rank if i < BoardXSize else front_rank
		var file: int = i % BoardXSize
		get_node(str(file) + "-" + str(rank)).add_child(Summon(pieces[i], color))
