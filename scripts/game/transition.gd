extends Control
## Full-screen black transition that covers the board for a turn hand-off.
##
## Uses the Godot Shaders "transition shader with patterns" with a radial
## gradient, so the wipe closes like an iris. Both textures are generated in
## code - no binary assets - and the single `factor` uniform drives both
## directions: cover() runs it 0 -> 1, reveal() runs it back.

signal dismissed

const SHADER := preload("res://assets/shaders/transition.gdshader")
const COVER_TIME := 0.45
const REVEAL_TIME := 0.35
const TEX_SIZE := 256

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
	_mat.set_shader_parameter("gradient_texture", _radial())
	_mat.set_shader_parameter("shape_texture", _radial())
	_mat.set_shader_parameter("factor", _factor)
	Black.material = _mat
	_sync_resolution()
	get_viewport().size_changed.connect(_sync_resolution)


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


func _sync_resolution() -> void:
	_mat.set_shader_parameter("node_resolution", get_viewport_rect().size)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		dismiss()


func _radial() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 1))
	grad.set_color(1, Color(1, 1, 1, 1))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = TEX_SIZE
	tex.height = TEX_SIZE
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex
