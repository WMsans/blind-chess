extends Node2D

@onready var scene_id: String = scene_file_path
@onready var s = $menu/settings/settings_menu
func _ready() -> void:
	# 1. Add this scene to a group so the SaveManager can call it right before closing
	add_to_group("saveable_scenes")
	
	# 2. Load this scene's specific data if it exists
	var saved_data = Savemanager.get_scene_data(scene_id)
	if not saved_data.is_empty():
		s.mvolume = saved_data.get("Master Volume",false)
		s.bgmvolume = saved_data.get("BGM Volume",false)
		s.sfxvolume = saved_data.get("SFX Volume",false)
		s.brightness = saved_data.get("Brightness",false)
	else:
		s.mvolume = 50;
		s.bgmvolume = 80;
		s.sfxvolume = 65;
		s.brightness = 100;
		var local_data = {
		"Master Volume" : s.mvolume,
		"BGM Volume": s.bgmvolume,
		"SFX Volume": s.sfxvolume,
		"Brightness": s.brightness
		}
		Savemanager.set_scene_data(scene_id, local_data)
		# (Optional) Apply loaded data to your level nodes here
		# e.g., if chest_opened: $Chest.open()

# This function is triggered automatically right before the application shuts down
func push_data_to_manager() -> void:
	var local_data = {
		"Master Volume" : s.mvolume,
		"BGM Volume": s.bgmvolume,
		"SFX Volume": s.sfxvolume,
		"Brightness": s.brightness
	}
	Savemanager.set_scene_data(scene_id, local_data)
