extends Node2D
@onready var alpha = 100

func _process(_delta: float) -> void:
	$Control/game_darkener.modulate.a = 1.0 - alpha/100.0
