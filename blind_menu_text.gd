extends AnimatedSprite2D

@onready var a : float =  -4.0;

func _process(_delta) -> void:
	a+=_delta;
	global_position.x = 1152/1.5
	global_position.y = 175 + sin(a*1.5) * 15
