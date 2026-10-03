extends Node2D
@onready var h_index = 0; 
@onready var hovered:Array;
@onready var selected = 0;
@onready var selected_size = Vector2(0.4,0.4);
@onready var normal_size = Vector2(0.3,0.3);
@onready var in_settings = 0;
func _ready():
	for i in get_children().size():
		get_children()[i].global_position.x = 0
		get_children()[i].global_position.y = 360 + 105 * i
		hovered.append(0)
	hovered[0] = 1;
	var tween = create_tween();
	tween.tween_property(get_children()[0],"global_scale",selected_size,0.3)
				
		
func _process(_delta):
	for i in get_child_count()-1:
		if i != h_index:
			hovered[i] = 0;
		else:
			hovered[i] = 1
	
	if selected == 0 and in_settings == 0:
		if h_index > 0:
			if Input.is_action_just_pressed("up"):
				h_index-=1;
				var tween = create_tween();
				tween.tween_property(get_children()[h_index],"global_scale",selected_size,0.3)
				for i in get_child_count():
					if i != h_index:
						tween.parallel().tween_property(get_children()[i],"global_scale",normal_size,0.3)

		if h_index < get_children().size()-1:
			if Input.is_action_just_pressed("down"):
				h_index+=1;
				var tween = create_tween();
				tween.tween_property(get_children()[h_index],"global_scale",selected_size,0.3)
				for i in get_children().size():
					if i != h_index:
						tween.parallel().tween_property(get_children()[i],"global_scale",normal_size,0.3)

	if Input.is_action_just_pressed("confirm"):
			selected = 1;
			match h_index:
				0:
					get_tree().change_scene_to_file("res://scenes/board.tscn")
				1:
					in_settings = 1;
					$settings/settings_menu.up = 1;
				2:
					get_tree().quit();
					
					
#CHECKING IF AN ARRAY HAS ANY INSTANCE OF A VALUE
func array_has_value(arr:Array,val):
	for i in arr.size():
		if arr[i] == val:
			return true;
		if i == arr.size() and arr[i] != val:
			return false;
	# WAS GONNA MAKE A SYSTEM TO DETECT ANY VALUE WITHIN AN ARRAY BUT I GOT LAZY :(
		#else:
			#for v in val.size():
				#if arr[i] == val[v]:
					#return true;
				#if i == arr.size() and arr[i] != val[v]:
						#return false;
					
