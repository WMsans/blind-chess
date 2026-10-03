extends Node2D
## One-shot board FX: screen-space shockwaves and particle bursts.
##
## Everything here is fire-and-forget. A wave frees itself when its tween ends
## and a burst frees itself when its particles run out, so the move path never
## awaits an effect - the board just unlocks on its own timer as before.

const SHOCKWAVE_SHADER := preload("res://assets/shaders/shockwave.gdshader")

# The ring expands past the screen corner while its push eases off to nothing.
# Tune force here: it is a fraction of the screen, so 0.02 is ~23px on a 1152
# wide window. Reach scales the end radius for smaller, local waves.
const WAVE_TIME := 0.46
const WAVE_START := 0.03
const WAVE_END := 1.35
const WAVE_THICKNESS := 0.12
const WAVE_SOFTNESS := 0.06

# A wave is a full-viewport quad; this overhang keeps it covering the screen
# while the board shakes underneath it.
const WAVE_MARGIN := 64.0

static var _dot_texture: GradientTexture2D


## A refraction ring centred on a board-space point. `strength` is the radial
## push in screen-UV units, `reach` scales how far the ring travels.
func shockwave(pos: Vector2, strength: float, color: Color, reach := 1.0) -> void:
	var view := get_viewport_rect()
	var wave := ColorRect.new()
	wave.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave.position = -Vector2(WAVE_MARGIN, WAVE_MARGIN)
	wave.size = view.size + Vector2(WAVE_MARGIN, WAVE_MARGIN) * 2.0
	var mat := ShaderMaterial.new()
	mat.shader = SHOCKWAVE_SHADER
	mat.set_shader_parameter("center", (pos - view.position) / view.size)
	mat.set_shader_parameter("aspect", view.size.x / view.size.y)
	mat.set_shader_parameter("radius", WAVE_START)
	mat.set_shader_parameter("thickness", WAVE_THICKNESS)
	mat.set_shader_parameter("softness", WAVE_SOFTNESS)
	mat.set_shader_parameter("force", strength)
	mat.set_shader_parameter("rim", 1.0)
	mat.set_shader_parameter("rim_color", color)
	wave.material = mat
	add_child(wave)

	# All three run the same duration so the chained free lands after the
	# longest of them no matter how the tween orders parallel steps.
	var t := wave.create_tween()
	t.set_parallel(true)
	t.tween_property(mat, "shader_parameter/radius", WAVE_END * reach, WAVE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(mat, "shader_parameter/force", 0.0, WAVE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(mat, "shader_parameter/rim", 0.0, WAVE_TIME)
	t.chain().tween_callback(wave.queue_free)


## A one-shot burst of soft dots. `speed` is the launch velocity in px/s and
## `size` is the dot scale at a 16px texture, so 0.5 is roughly an 8px speck.
func burst(pos: Vector2, color: Color, amount: int, speed := 260.0, gravity := 420.0, spread := 180.0, size := 0.5) -> void:
	var p := CPUParticles2D.new()
	p.texture = _dot()
	p.one_shot = true
	p.emitting = false
	p.lifetime = 0.6
	p.explosiveness = 1.0
	p.amount = amount
	p.direction = Vector2(0, -1)
	p.spread = spread
	p.gravity = Vector2(0, gravity)
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.7
	p.damping_max = speed * 1.2
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	p.color = color
	add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)


# A soft radial dot, built once and shared by every burst - no image asset.
static func _dot() -> GradientTexture2D:
	if _dot_texture != null:
		return _dot_texture
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.4, Color(1, 1, 1, 0.9))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 16
	tex.height = 16
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	_dot_texture = tex
	return tex
