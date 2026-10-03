extends Node

const save_file_name : String = "user://save.json"
const default_dictionary : Dictionary = {
	"Master Volume": 50,
	"BGM Volume": 80,
	"SFX Volume": 65,
	"Brightness": 100,
}
var game_data : Dictionary = {}

func _ready() -> void:
	load_data()

# Layers a parsed save over the defaults, so a missing key always falls back and
# an unknown key never leaks into the running game.
static func merge_with_defaults(saved: Dictionary) -> Dictionary:
	var merged : Dictionary = {"Scenes": {}}
	for key in default_dictionary:
		merged[key] = saved.get(key, default_dictionary[key])
	if saved.get("Scenes") is Dictionary:
		merged["Scenes"] = saved["Scenes"]
	return merged

func save_data() -> void:
	var save_file : FileAccess = FileAccess.open(save_file_name,FileAccess.WRITE);
	if save_file == null:
		push_error("Error Opening File")
		return
	var string_data : String = JSON.stringify(game_data)
	save_file.store_string(string_data);
	save_file.close();

func load_data() -> void:
	var saved : Dictionary = {}
	if FileAccess.file_exists(save_file_name):
		var save_file : FileAccess = FileAccess.open(save_file_name,FileAccess.READ);
		if save_file == null:
			push_error("Error Reading File")
		else:
			var json = JSON.new()
			if json.parse(save_file.get_as_text()) == OK and typeof(json.data) == TYPE_DICTIONARY:
				saved = json.data
			else:
				push_error("Corrupted save data")
			save_file.close();
	game_data = merge_with_defaults(saved)

# Global preferences. get_setting always resolves through default_dictionary.
func get_setting(setting: String) -> int:
	return game_data.get(setting, default_dictionary.get(setting, 0))

func set_setting(setting: String, value: int) -> void:
	game_data[setting] = value

func get_scene_data(scene_id: String) -> Dictionary:
	return game_data["Scenes"].get(scene_id, {})

func set_scene_data(scene_id: String, data: Dictionary) -> void:
	game_data["Scenes"][scene_id] = data;

func _notification(what: int) -> void:
	# This notification is sent when the player clicks the 'X' button or closes the window
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Give currently active scenes a chance to push their data before final save
		get_tree().call_group("saveable_scenes", "push_data_to_manager")
		save_data();
		get_tree().quit();
