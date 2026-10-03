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


static func hide(piece: Node2D) -> void:
	var cover := piece.get_node_or_null("Cover") as Control
	if cover == null:
		cover = _build()
		piece.add_child(cover)
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
	var mark := Label.new()
	mark.text = "?"
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.set_anchors_preset(Control.PRESET_FULL_RECT)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.add_theme_color_override("font_color", Color("#c9d2b8"))
	mark.add_theme_font_size_override("font_size", 22)
	cover.add_child(mark)
	return cover
