extends Panel
## A side tray collecting the pieces this colour has captured.
##
## Each capture becomes a small thumbnail that pops in and bounces on hover.
## HFlowContainer wraps the thumbnails, so a full 15-piece haul still fits the
## board's height.

const Juice = preload("res://scripts/fx/juice.gd")
const THUMB := Vector2(30, 30)


func _ready() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#232a20")
	box.set_corner_radius_all(12)
	box.set_border_width_all(3)
	box.border_color = Color("#4f5d44")
	add_theme_stylebox_override("panel", box)


## Add a revealed capture as a thumbnail. Returns the new item.
func add_piece(texture: Texture2D) -> TextureRect:
	var item := TextureRect.new()
	item.texture = texture
	item.custom_minimum_size = THUMB
	item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item.mouse_entered.connect(func(): Juice.tray_hover(item, true))
	item.mouse_exited.connect(func(): Juice.tray_hover(item, false))
	get_node("Flow").add_child(item)
	Juice.tray_in(item)
	return item


func count() -> int:
	return get_node("Flow").get_child_count()
