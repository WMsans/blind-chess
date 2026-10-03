extends Node2D

@onready var s = $menu/settings/settings_menu
func _ready() -> void:
	# Add this scene to a group so the SaveManager can call it right before closing
	add_to_group("saveable_scenes")

	# Settings are global preferences owned by the SaveManager; it fills in the
	# defaults for anything not present in the save file.
	s.mvolume = Savemanager.get_setting("Master Volume")
	s.bgmvolume = Savemanager.get_setting("BGM Volume")
	s.sfxvolume = Savemanager.get_setting("SFX Volume")
	s.brightness = Savemanager.get_setting("Brightness")

# Triggered automatically right before the application shuts down, so a value
# changed but never confirmed is still flushed.
func push_data_to_manager() -> void:
	Savemanager.set_setting("Master Volume", s.mvolume)
	Savemanager.set_setting("BGM Volume", s.bgmvolume)
	Savemanager.set_setting("SFX Volume", s.sfxvolume)
	Savemanager.set_setting("Brightness", s.brightness)
