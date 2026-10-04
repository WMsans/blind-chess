extends RefCounted
## Face-down covers for the opponent's pieces.
##
## A cover is a child of the piece, so it inherits every hop, tilt and rotation
## the piece gets. Every cover is the same tile, so it never leaks which piece
## is underneath. hide()/show() toggle one reused cover instead of allocating
## during every turn hand-off, and they leave the real texture on the sprite so
## a capture can reveal it.

const COVER_SIZE := 46.0
const COVER_COLOR := Color("#22271f")
const COVER_BORDER := Color("#4f5d44")
const MARK_COLOR := Color("#c9d2b8")
const ICON := "res://assets/textures/pieces/%s%s.svg"
# A player's guess at a hidden piece's identity, stored on the piece so it
# survives moves and turn hand-offs. The cover is only ever visible to the
# player who cannot see the piece, so the guess leaks nothing to its owner.
const GUESS_META := "guess"


## Record (or clear, with "") the identity the current player believes this
## hidden piece is, and repaint its cover if it has one.
static func set_guess(piece: Node2D, name: String) -> void:
	if name == "":
		if piece.has_meta(GUESS_META):
			piece.remove_meta(GUESS_META)
	else:
		piece.set_meta(GUESS_META, name)
	var cover := piece.get_node_or_null("Cover") as Control
	if cover != null:
		_paint(cover, piece, name)


static func get_guess(piece: Node2D) -> String:
	return piece.get_meta(GUESS_META, "")


static func hide(piece: Node2D) -> void:
	var cover := piece.get_node_or_null("Cover") as Control
	if cover == null:
		cover = _build()
		piece.add_child(cover)
	_paint(cover, piece, get_guess(piece))
	cover.visible = true


static func show(piece: Node2D) -> void:
	var cover := piece.get_node_or_null("Cover") as Control
	if cover != null:
		cover.visible = false


static func is_hidden(piece: Node2D) -> bool:
	var cover := piece.get_node_or_null("Cover") as Control
	return cover != null and cover.visible


static func _build() -> Control:
	var cover := Panel.new()
	cover.name = "Cover"
	cover.size = Vector2(COVER_SIZE, COVER_SIZE)
	cover.position = -cover.size / 2.0
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = COVER_COLOR
	box.set_corner_radius_all(10)
	box.set_border_width_all(2)
	box.border_color = COVER_BORDER
	cover.add_theme_stylebox_override("panel", box)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 4.0
	icon.offset_top = 4.0
	icon.offset_right = -4.0
	icon.offset_bottom = -4.0
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.visible = false
	cover.add_child(icon)

	var mark := Label.new()
	mark.name = "Mark"
	mark.text = "?"
	mark.set_anchors_preset(Control.PRESET_FULL_RECT)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.add_theme_color_override("font_color", MARK_COLOR)
	mark.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.04, 0.95))
	mark.add_theme_constant_override("outline_size", 5)
	cover.add_child(mark)
	return cover


# A guess fills the tile with the believed piece and keeps a small "?" pinned
# to the corner, so a guess never passes for confirmed information. An empty
# guess falls back to the plain face-down tile.
static func _paint(cover: Control, piece: Node2D, guess: String) -> void:
	var icon := cover.get_node("Icon") as TextureRect
	var mark := cover.get_node("Mark") as Label
	var guessed := guess != ""
	icon.visible = guessed
	if guessed:
		var side := "B" if piece.get("PieceColor") == 1 else "W"
		icon.texture = load(ICON % [side, guess])
		mark.offset_right = -3.0
		mark.offset_bottom = -3.0
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		mark.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		mark.add_theme_font_size_override("font_size", 15)
	else:
		mark.offset_right = 0.0
		mark.offset_bottom = 0.0
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.add_theme_font_size_override("font_size", 22)
