extends Node

const save_file_name : String = "user://save.json"
const default_dictionary : Dictionary = {"Scenes" : {},"Master Volume" : 50, "BGM Volume": 80, "SFX Volume": 65,"Brightness": 100};
var game_data : Dictionary = {"Scenes" : {}};

func _ready() -> void:
	load_data();
func save_data():
	var save_file : FileAccess = FileAccess.open(save_file_name,FileAccess.WRITE);
	if save_file == null:
		push_error("Error Opening File")
		return
	var string_data : String = JSON.stringify(game_data)
	save_file.store_string(string_data);
	save_file.close();
	
func load_data() -> Dictionary:
	if FileAccess.file_exists(save_file_name):
		var save_file : FileAccess = FileAccess.open(save_file_name,FileAccess.READ);
		if save_file == null:
			push_error("Error Reading File")
			return default_dictionary
		var json = JSON.new()
		if json.parse(save_file.get_as_text()) == OK and typeof(json.data) == TYPE_DICTIONARY:
			for key in json.data.keys():
				if key == "Scenes":
					game_data["Scenes"] = json.data["Scenes"]
				else:
					game_data[key] = json.data[key]
			
			save_file.close();

		#push_error("Corrupted Data")
	return default_dictionary
	
func _notification(what: int) -> void:
	# This notification is sent when the player clicks the 'X' button or closes the window
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Give currently active scenes a chance to push their data before final save
		get_tree().call_group("saveable_scenes", "push_data_to_manager")
		save_data();
		get_tree().quit();

func get_scene_data(scene_id: String) -> Dictionary:
	if game_data["Scenes"].has(scene_id):
		print("SCENES")
		return game_data["Scenes"][scene_id];
	return {} # Return empty if no save data exists yet

func set_scene_data(scene_id: String,data:Dictionary):
	game_data["Scenes"][scene_id] = data;

#func reset_data():
	
