extends Sprite2D
@onready var a:float = 4.0;
func _process(_delta) -> void:
	a+=_delta;
	global_position.x = 1152/1.5
	global_position.y = 405 + sin(a*1.5) * 15
	#global_rotation_degrees = rad_to_deg(sin(a*2)/9)

	# Slowly spin it
	var current_angle = material.get_shader_parameter("rotation_angle")
	current_angle =  rad_to_deg(sin(a)/15)
	material.set_shader_parameter("rotation_angle", current_angle)
