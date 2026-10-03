extends Node2D

@onready var up = 0;
@onready var down = 0;
@onready var font = load("res://pixel_font.ttf")
@onready var s = $settings_options
@onready var mvolume;
@onready var h_index = 0;
@onready var bgmvolume;
@onready var sfxvolume;
@onready var brightness;
@onready var font_size = 80;
@onready var pause_frames = 15;
@onready var max_setting_val = [100,100,100,100]
@onready var min_setting_val = [0,0,0,20]
@onready var input_hold_pause = pause_frames;
@onready var settings_options = []; #the hysical text nodes
@onready var settings_names = ["Master Volume", "BGM Volume", "SFX Volume","Brightness"]
@onready var h_col = Color.AQUA;
@onready var normal_col = Color.WHITE;
@onready var selected = 0;

@onready var settings_texts = ["Master Volume:   " + str(mvolume),
"BGM Volume:   " + str(bgmvolume),"SFX Volume:   " + str(sfxvolume), "Brightness:   " + str(brightness)]
func _ready() -> void:
	global_position.y = 700;
	for i in settings_texts.size():
		settings_options.append(RichTextLabel.new())
		settings_options[i].text = settings_texts[i]
		settings_options[i].size = Vector2(800,900)
		settings_options[i].add_theme_font_size_override("normal_font_size",80)
		settings_options[i].add_theme_font_override("normal_font",font)
		settings_options[i].global_position = Vector2(40, global_position.y + 100 + 100 * i)
		s.add_child(settings_options[i])
	s.get_children()[0].modulate = h_col;

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("cancel") and selected == 0:
		var data = {
			"Master Volume" : s.get("mvolume"),
			"BGM Volume": s.get("bgmvolume"),
			"SFX Volume": s.get("sfxvolume"),
			"Brightness": s.get("brightness")
		}
		Savemanager.set_scene_data(scene_file_path,data)
		find_parent("menu").set("in_settings",0)
		find_parent("menu").set("selected",0)
		down = 1;
	settings_texts = ["Master Volume:   " + str(mvolume),
"BGM Volume:   " + str(bgmvolume),"SFX Volume:   " + str(sfxvolume), "Brightness:   " + str(brightness)]

	for i in s.get_children().size():
		s.get_children()[i].position.y = global_position.y + 100 + 100 * i
		s.get_children()[i].text = settings_texts[i]
		
	if find_parent("menu").get("in_settings") == 1 and selected == 0:
		if h_index > 0:
				if Input.is_action_just_pressed("up"):
					h_index-=1;
					s.get_children()[h_index].modulate = h_col;
					for i in s.get_child_count():
						if i != h_index:
							s.get_children()[i].modulate = normal_col;
							
		if h_index < s.get_children().size()-1:
			if Input.is_action_just_pressed("down"):
				h_index+=1;
				s.get_children()[h_index].modulate = h_col;
				for i in s.get_children().size():
					if i != h_index:
						s.get_children()[i].modulate = normal_col;
		
		if Input.is_action_just_pressed("confirm") and find_parent("menu").get("in_settings") == 1:
			selected = 1;
			s.get_children()[h_index].modulate = Color.CADET_BLUE

	if selected == 1:
		if Input.is_action_just_pressed("left"):
			match h_index:
				0:
					if mvolume > min_setting_val[0]:
						mvolume-=1;
				1:
					if bgmvolume > min_setting_val[1]:
						bgmvolume-=1;
				2:
					if sfxvolume > min_setting_val[2]:
						sfxvolume-=1;
				3:
					if brightness > min_setting_val[3]:
						brightness-=1;
					
		if Input.is_action_pressed("left"):
			input_hold_pause-=1;
			if input_hold_pause <= 0:
				match h_index:
					0:
						if mvolume > min_setting_val[0]:
							mvolume-=1;
					1:
						if bgmvolume > min_setting_val[1]:
							bgmvolume-=1;
					2:
						if sfxvolume > min_setting_val[2]:
							sfxvolume-=1;
					3:
						if brightness > min_setting_val[3]:
							brightness-=1;
						
				input_hold_pause=pause_frames;
		if Input.is_action_just_pressed("right"):
			match h_index:
				0:
					if mvolume < max_setting_val[0]:
						mvolume+=1;
				1:
					if bgmvolume < max_setting_val[1]:
						bgmvolume+=1;
				2:
					if sfxvolume < max_setting_val[2]:
						sfxvolume+=1;
				3:
					if brightness < max_setting_val[3]:
						brightness+=1;
					
		if Input.is_action_pressed("right"):
			input_hold_pause-=1;
			if input_hold_pause <= 0:
				match h_index:
					0:
						if mvolume < max_setting_val[0]:
							mvolume+=1;
					1:
						if bgmvolume < max_setting_val[1]:
							bgmvolume+=1;
					2:
						if sfxvolume < max_setting_val[2]:
							sfxvolume+=1;
					3:
						if brightness < max_setting_val[3]:
							brightness+=1;
					
				input_hold_pause=pause_frames;
		
		if Input.is_action_just_pressed("cancel"):
			print("exit select")
			s.get_children()[h_index].modulate = Color.AQUA
			selected = 0;
	# menu pops UP
	if up == 1:
		var tween = create_tween();
		tween.tween_property(self,"global_position",Vector2(position.x,0),0.65)
		up = 0;
	#menu goes DOWN
	if down == 1:
		var tween = create_tween();
		tween.tween_property(self,"global_position",Vector2(position.x,700),0.65)
		down = 0;
	Brightness.alpha = float(brightness);
	
