extends RefCounted
class_name UiMotion
## Shared tween recipes for the UI kit.
##
## Every helper is pure: hand it a Control, it kills that control's previous
## UI tweens, starts new ones and returns the one worth awaiting. All the
## timing and overshoot tuning lives in the constants below - tune here only.

const META := "ui_motion"

# Palette - mirrors themes/blind_chess.tres so code can tint to match.
const BG_DEEP := Color("#232a20")
const BG_BASE := Color("#2e3727")
const BG_RAISED := Color("#3d4a33")
const BORDER := Color("#6b7a58")
const CREAM := Color("#f0f2e6")
const MUTED := Color("#c9d2b8")
const GOLD := Color("#ffd76a")
const DENY := Color("#f24a4a")
const DISABLED := Color("#1c2117")

const HOVER_SCALE := Vector2(1.06, 1.06)
const HOVER_LIFT := 4.0
const HOVER_TIME := 0.14
const HOVER_OUT_TIME := 0.18

const PRESS_SQUASH := Vector2(0.94, 0.86)
const PRESS_TIME := 0.06
const PRESS_RELEASE_SCALE := Vector2(1.10, 1.10)
const PRESS_RELEASE_TIME := 0.20

const HOLD_PULSE_MIN := Vector2(0.98, 0.98)
const HOLD_PULSE_MAX := Vector2(1.02, 1.02)
const HOLD_PULSE_TIME := 0.3
const HOLD_DELAY := 0.35
const REPEAT_INTERVAL := 0.18

const APPEAR_SCALE := Vector2(0.7, 0.7)
const APPEAR_TIME := 0.32
const APPEAR_STAGGER := 0.06
const DISMISS_SCALE := Vector2(0.5, 0.5)
const DISMISS_TIME := 0.18
const DISMISS_STAGGER := 0.04

const REJECT_SHAKE := 10.0
const REJECT_TIME := 0.22


static func _kill(node: Object) -> void:
	if not is_instance_valid(node):
		return
	for tween in node.get_meta(META, []):
		if is_instance_valid(tween):
			tween.kill()
	node.set_meta(META, [])
	var ctrl := node as Control
	if ctrl != null:
		ctrl.rotation = 0.0
		if ctrl.has_meta(META + "_rest_mod"):
			ctrl.modulate = ctrl.get_meta(META + "_rest_mod")
			ctrl.remove_meta(META + "_rest_mod")


static func _track(node: Object, tween: Tween) -> Tween:
	var list: Array = node.get_meta(META, [])
	list.append(tween)
	node.set_meta(META, list)
	return tween


static func _store_rest(ctrl: Control) -> void:
	if not ctrl.has_meta(META + "_rest_mod"):
		ctrl.set_meta(META + "_rest_mod", ctrl.modulate)


static func _rest_color(ctrl: Control) -> Color:
	return ctrl.get_meta(META + "_rest_mod", CREAM)


## The resting spot a control should return to. Recorded on first use, so a
## hover or a rejected shake never drifts it away from where it started.
static func _home(ctrl: Control) -> Vector2:
	if not ctrl.has_meta(META + "_home"):
		ctrl.set_meta(META + "_home", ctrl.position)
	return ctrl.get_meta(META + "_home")


## Centre the pivot so scale tweens grow from the middle, not the top-left.
static func prepare(ctrl: Control) -> void:
	if ctrl.size != Vector2.ZERO:
		ctrl.pivot_offset = ctrl.size / 2.0


static func hover_in(ctrl: Control) -> Tween:
	_kill(ctrl)
	var home := _home(ctrl)
	var t := _track(ctrl, ctrl.create_tween())
	t.tween_property(ctrl, "position", home - Vector2(0, HOVER_LIFT), HOVER_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(ctrl, "scale", HOVER_SCALE, HOVER_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return t


static func hover_out(ctrl: Control) -> Tween:
	_kill(ctrl)
	var t := _track(ctrl, ctrl.create_tween())
	t.tween_property(ctrl, "position", _home(ctrl), HOVER_OUT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(ctrl, "scale", Vector2.ONE, HOVER_OUT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return t


static func press_down(ctrl: Control) -> Tween:
	_kill(ctrl)
	var t := _track(ctrl, ctrl.create_tween())
	t.tween_property(ctrl, "scale", PRESS_SQUASH, PRESS_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return t


static func press_up(ctrl: Control, hovered: bool) -> Tween:
	_kill(ctrl)
	var target := HOVER_SCALE if hovered else Vector2.ONE
	var t := _track(ctrl, ctrl.create_tween())
	t.tween_property(ctrl, "scale", PRESS_RELEASE_SCALE, PRESS_RELEASE_TIME * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(ctrl, "scale", target, PRESS_RELEASE_TIME * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return t


static func hold_pulse(ctrl: Control) -> Tween:
	_kill(ctrl)
	_store_rest(ctrl)
	var rest := _rest_color(ctrl)
	var t := _track(ctrl, ctrl.create_tween().set_loops())
	t.tween_property(ctrl, "scale", HOLD_PULSE_MAX, HOLD_PULSE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(ctrl, "modulate", GOLD, HOLD_PULSE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(ctrl, "scale", HOLD_PULSE_MIN, HOLD_PULSE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(ctrl, "modulate", rest, HOLD_PULSE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return t


static func appear(ctrl: Control, from_offset := Vector2.ZERO, delay := 0.0) -> Tween:
	_kill(ctrl)
	var home := _home(ctrl)
	ctrl.position = home + from_offset
	ctrl.scale = APPEAR_SCALE
	ctrl.modulate.a = 0.0
	var t := _track(ctrl, ctrl.create_tween())
	t.tween_interval(delay)
	t.tween_property(ctrl, "position", home, APPEAR_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(ctrl, "scale", Vector2.ONE, APPEAR_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(ctrl, "modulate:a", 1.0, APPEAR_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return t


static func dismiss(ctrl: Control, to_offset := Vector2.ZERO, delay := 0.0) -> Tween:
	_kill(ctrl)
	var home := _home(ctrl)
	var t := _track(ctrl, ctrl.create_tween())
	t.tween_interval(delay)
	t.tween_property(ctrl, "position", home + to_offset, DISMISS_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(ctrl, "scale", DISMISS_SCALE, DISMISS_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(ctrl, "modulate:a", 0.0, DISMISS_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	return t


static func reject(ctrl: Control) -> Tween:
	_kill(ctrl)
	_store_rest(ctrl)
	var rest := _rest_color(ctrl)
	var home := _home(ctrl)
	var t := _track(ctrl, ctrl.create_tween())
	t.tween_property(ctrl, "position", home + Vector2(REJECT_SHAKE, 0), REJECT_TIME * 0.2)
	t.tween_property(ctrl, "position", home - Vector2(REJECT_SHAKE, 0), REJECT_TIME * 0.3)
	t.tween_property(ctrl, "position", home, REJECT_TIME * 0.5)
	ctrl.modulate = DENY
	var m := _track(ctrl, ctrl.create_tween())
	m.tween_property(ctrl, "modulate", rest, REJECT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return t
