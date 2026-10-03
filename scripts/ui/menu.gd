extends Control
## Main menu: filigree background, animated wordmark and buttons, and a sliding
## settings sheet.
##
## Settings are filled from the SaveManager on ready and pushed back through the
## `saveable_scenes` group contract when the window closes.

const UiMotion = preload("res://scripts/ui/ui_motion.gd")

const PLAY_SCENE := "res://scenes/game.tscn"

@onready var Background: ColorRect = get_node("Background")
@onready var Title: Label = get_node("Title")
@onready var Buttons: Control = get_node("Buttons")
@onready var SettingsPanel = get_node("SettingsPanel")

var _leaving := false
var _save: Node


func _ready() -> void:
	add_to_group("saveable_scenes")
	_save = get_node("/root/Savemanager")
	Background.material.set_shader_parameter("intensity", 0.0)

	var buttons := Buttons.get_children()
	for row in SettingsPanel.get_node("Rows").get_children():
		if row.has_method("set_value") and row.get("setting_name") != "":
			row.set_value(_save.get_setting(row.get("setting_name")))
	SettingsPanel.closed.connect(_restage_buttons)
	buttons[0].pressed.connect(_on_play)
	buttons[1].pressed.connect(_on_settings)
	buttons[2].pressed.connect(_on_quit)

	_entrance(buttons)


func _entrance(buttons: Array) -> void:
	var fade := create_tween()
	fade.tween_method(_set_intensity, 0.0, 1.0, 0.6)
	var home: Vector2 = Title.position
	Title.modulate.a = 0.0
	Title.position = home + Vector2(0, -22)
	var title := create_tween()
	title.tween_property(Title, "modulate:a", 1.0, 0.35)
	title.parallel().tween_property(Title, "position", home, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	title.tween_callback(_start_title_bob.bind(home))
	var i := 0
	for b in buttons:
		b.appear(0.14 + UiMotion.APPEAR_STAGGER * i)
		i += 1
	var wait: float = 0.14 + UiMotion.APPEAR_STAGGER * (buttons.size() - 1) + UiMotion.APPEAR_TIME
	await get_tree().create_timer(wait).timeout
	# A player can open settings before the entrance finishes; do not steal
	# focus back to Play behind the open sheet.
	if not _leaving and not SettingsPanel.visible:
		buttons[0].grab_focus()


func _set_intensity(v: float) -> void:
	Background.material.set_shader_parameter("intensity", v)


func _start_title_bob(home: Vector2) -> void:
	var t := UiMotion._track(Title, create_tween().set_loops())
	t.tween_property(Title, "position", home + Vector2(0, 8.0), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(Title, "position", home, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _restage_buttons() -> void:
	if _leaving:
		return
	var buttons := Buttons.get_children()
	var i := 0
	for b in buttons:
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.appear(UiMotion.APPEAR_STAGGER * i)
		i += 1
	# Hand focus back only once the fade-in has landed: grabbing it now fires
	# the button's hover tween, which kills the in-flight appear and strands its
	# alpha at zero, leaving the button invisible.
	await get_tree().create_timer(UiMotion.APPEAR_TIME + UiMotion.APPEAR_STAGGER * (buttons.size() - 1)).timeout
	if not _leaving and not SettingsPanel.visible:
		buttons[0].grab_focus()


func _dismiss_buttons(delay := 0.0) -> void:
	var i := 0
	for b in Buttons.get_children():
		# A button that is animating out must not stay focusable or clickable,
		# or ui_accept would fire it behind the settings panel.
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.dismiss(delay + UiMotion.DISMISS_STAGGER * i)
		i += 1


func _on_settings() -> void:
	if _leaving:
		return
	_dismiss_buttons()
	SettingsPanel.open()


func _on_play() -> void:
	if _leaving:
		return
	_leaving = true
	_dismiss_buttons()
	UiMotion.dismiss(Title, Vector2(0, 40), 0.0)
	await get_tree().create_timer(0.4).timeout
	var err := get_tree().change_scene_to_file(PLAY_SCENE)
	if err != OK:
		push_error("Failed to load %s (error %d)" % [PLAY_SCENE, err])


func _on_quit() -> void:
	if _leaving:
		return
	_leaving = true
	_dismiss_buttons()
	await get_tree().create_timer(0.45).timeout
	get_tree().quit()


func push_data_to_manager() -> void:
	var values: Dictionary = SettingsPanel.get_values()
	for key in values:
		_save.set_setting(key, values[key])
