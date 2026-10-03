extends Button
## A Button with the shared UI juice: hover, press and hold states.
##
## Mouse hover and keyboard focus drive the same animation, so the widget feels
## the same whichever way it is driven. Press and hold are separate: a short
## tap springs back, while a held button pulses until it is released.

const UiMotion = preload("res://scripts/ui/ui_motion.gd")

signal hold_started
signal hold_released

## Seconds a press must be held before the hold state begins.
@export var hold_delay := UiMotion.HOLD_DELAY

var _mouse_over := false
var _focused := false
var _hovered := false
var _holding := false
var _hold_began := false
var _held_time := 0.0


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	resized.connect(_prepare)
	mouse_entered.connect(_set_mouse.bind(true))
	mouse_exited.connect(_set_mouse.bind(false))
	focus_entered.connect(_set_focus.bind(true))
	focus_exited.connect(_set_focus.bind(false))
	button_down.connect(_down)
	button_up.connect(_up)
	call_deferred("_prepare")


func _prepare() -> void:
	UiMotion.prepare(self)


func _process(delta: float) -> void:
	if not _holding:
		set_process(false)
		return
	_held_time += delta
	# The squash from press_down owns the first moments of the press; the pulse
	# only takes over once the player has clearly settled into a hold.
	if not _hold_began and _held_time >= hold_delay:
		_hold_began = true
		hold_started.emit()
		UiMotion.hold_pulse(self)


func is_holding() -> bool:
	return _holding


func appear(delay := 0.0) -> Tween:
	_prepare()
	return UiMotion.appear(self, Vector2(-24, 0), delay)


func dismiss(delay := 0.0) -> Tween:
	return UiMotion.dismiss(self, Vector2(0, 24), delay)


func reject() -> Tween:
	return UiMotion.reject(self)


func _set_mouse(over: bool) -> void:
	_mouse_over = over
	_sync_hover()


func _set_focus(focused: bool) -> void:
	_focused = focused
	_sync_hover()


func _sync_hover() -> void:
	var now := _mouse_over or _focused
	if now == _hovered:
		return
	_hovered = now
	# A held button owns its own animation; hover waits until release.
	if _holding:
		return
	if _hovered:
		UiMotion.hover_in(self)
	else:
		UiMotion.hover_out(self)


func _down() -> void:
	_holding = true
	_hold_began = false
	_held_time = 0.0
	UiMotion.press_down(self)
	set_process(true)


func _up() -> void:
	if not _holding:
		return
	if _hold_began:
		hold_released.emit()
	_holding = false
	_hold_began = false
	set_process(false)
	UiMotion.press_up(self, _hovered)
