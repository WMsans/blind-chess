extends Control
## Full-screen black transition used for turn hand-offs and scene changes.
##
## Reproduces the godotshaders "transition_02" look: black is only ever the
## union of circles that spawn at the screen edges and grow inward, new ones
## appearing progressively closer to the centre. The coverage field - for each
## pixel, the factor at which a growing circle swallows it - is baked on the CPU
## into a texture, so the shader is one lookup and threshold and no solid region
## ever sweeps the screen. `factor` drives both directions: cover() runs it
## 0 -> 1, reveal() runs it back.

signal dismissed

const SHADER := preload("res://assets/shaders/circle_wipe.gdshader")
const COVER_TIME := 1.8
const REVEAL_TIME := 1.8
## Field width in texels; height follows the viewport aspect so baked circles
## stay round on any window shape.
const FIELD_WIDTH := 256
const BLOB_COUNT := 90
## Factor at which a circle at the screen edge / dead centre first appears.
const SPAWN_OUTER := 0.02
const SPAWN_INNER := 0.65
## Value for a pixel no circle covers: it only blacks out at the very end.
const FIELD_MAX := 0.97

## Set by a caller (the menu) just before a scene swap: the next veil to enter
## the tree starts fully covered and reveals itself, so the new scene never
## flashes before its own transition takes over. One-shot, consumed on ready.
static var start_covered := false

@onready var Black := get_node("Black") as ColorRect
@onready var Prompt := get_node("Prompt") as Label

var _factor := 0.0
var _busy := false
var _armed := false
var _mat: ShaderMaterial


func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("base_color", Color(0, 0, 0, 1))
	_mat.set_shader_parameter("field_texture", _field())
	_mat.set_shader_parameter("factor", _factor)
	Black.material = _mat
	# A resize re-stretches the field, so rebuild it to keep the circles round.
	get_viewport().size_changed.connect(_rebuild_field)
	if start_covered:
		start_covered = false
		_set_factor(1.0)
		visible = true
		reveal()


## Close the veil. Returns the Tween so the caller can await .finished.
## Dismissal stays disarmed until arm() is called, so a click while the veil
## is still closing is ignored instead of being emitted before anyone listens.
func cover() -> Tween:
	visible = true
	_busy = false
	_armed = false
	var t := create_tween()
	t.tween_method(_set_factor, _factor, 1.0, COVER_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return t


## Start listening for the dismiss click. Call this once the board has been
## prepared (covered, fogged, rotated) and the hand-off is ready to reveal.
func arm() -> void:
	_armed = true


## Open the veil and hide it once it is fully clear.
func reveal() -> Tween:
	_armed = false
	var t := create_tween()
	t.tween_method(_set_factor, _factor, 0.0, REVEAL_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func(): visible = false)
	return t


## Idempotent: repeated clicks emit `dismissed` once and reveal once.
func dismiss() -> void:
	if _busy or not _armed or not visible:
		return
	_busy = true
	dismissed.emit()
	await reveal().finished
	_busy = false


func is_covered() -> bool:
	return visible and _factor > 0.5


func set_prompt(text: String) -> void:
	Prompt.text = text


func _set_factor(value: float) -> void:
	_factor = value
	_mat.set_shader_parameter("factor", value)


# ponytail: rebuild is synchronous, so a live window drag re-bakes per resize
# event; debounce it if that ever shows up in a profile.
func _rebuild_field() -> void:
	_mat.set_shader_parameter("field_texture", _field())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		dismiss()


## Bake the coverage field. A circle turns a pixel black at factor
## `spawn + distance / growth`; storing the minimum of that over every circle
## gives, per pixel, the factor at which the first grown circle reaches it -
## exactly the union of the circles, with no underlying radial wipe.
func _field() -> ImageTexture:
	var size := get_viewport_rect().size
	if size.x < 1.0:
		size = Vector2(16, 9)
	var w := FIELD_WIDTH
	var h := clampi(int(round(float(w) * size.y / size.x)), 64, 512)
	var field := PackedFloat32Array()
	field.resize(w * h)
	field.fill(FIELD_MAX)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260212
	var mid := Vector2(w, h) * 0.5
	var corner := mid.length()
	for i in BLOB_COUNT:
		var growth := rng.randf_range(0.10, 0.26) * float(w)
		var center := Vector2(rng.randf() * w, rng.randf() * h)
		# Edge circles appear first, centre ones last.
		var spawn := lerpf(SPAWN_INNER, SPAWN_OUTER, center.distance_to(mid) / corner)
		var reach := int(growth * (1.0 - spawn)) + 1
		var x0 := maxi(0, int(center.x) - reach)
		var x1 := mini(w - 1, int(center.x) + reach)
		var y0 := maxi(0, int(center.y) - reach)
		var y1 := mini(h - 1, int(center.y) + reach)
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var t := Vector2(x - center.x, y - center.y).length() / growth + spawn
				var idx := y * w + x
				if t < field[idx]:
					field[idx] = t
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBAF)
	for y in h:
		for x in w:
			img.set_pixel(x, y, Color(field[y * w + x], 0, 0, 1))
	return ImageTexture.create_from_image(img)
