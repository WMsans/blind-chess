extends RefCounted
## Tween helpers for the board's juice.
##
## Every helper is pure: hand it a node, it kills that node's previous juice
## tweens, starts new ones and returns the one worth awaiting. All the timing
## and overshoot tuning lives in the constants below - tune here only.

const SELECT_SCALE := Vector2(1.18, 1.18)

const ANTICIPATE := 0.07
const HOP_UP := 0.15
const HOP_DOWN := 0.17
const SETTLE_TIME := 0.34

const SQUASH_SELECT := Vector2(0.86, 1.14)
const SQUASH_ANTICIPATE := Vector2(1.14, 0.84)
const SQUASH_LAUNCH := Vector2(0.9, 1.14)
const SQUASH_DESCEND := Vector2(1.08, 0.92)
const IMPACT_SQUASH := Vector2(1.4, 0.64)

const REJECT_COLOR := Color(1.0, 0.35, 0.35)
const REJECT_TILT := 0.2


static func _kill(node: Object) -> void:
	if not is_instance_valid(node):
		return
	for tween in node.get_meta("juice", []):
		if is_instance_valid(tween):
			tween.kill()
	node.set_meta("juice", [])


static func _track(node: Object, tween: Tween) -> Tween:
	node.get_meta("juice").append(tween)
	return tween


# A tween that got killed part-way (a rejection interrupted by the next tap)
# would leave the piece tilted and tinted, so putting it back is a hard reset.
static func _settle_rest(node: CanvasItem) -> void:
	if not is_instance_valid(node):
		return
	if node.has_meta("juice_rest"):
		node.modulate = node.get_meta("juice_rest")
		node.remove_meta("juice_rest")
	node.rotation = 0.0


## The piece the player just picked up: squash, then spring up to SELECT_SCALE.
static func select(piece: CanvasItem) -> Tween:
	_kill(piece)
	_settle_rest(piece)
	var t := _track(piece, piece.create_tween())
	t.tween_property(piece, "scale", SQUASH_SELECT, 0.08)
	t.tween_property(piece, "scale", SELECT_SCALE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return t


## Let a piece go back to its resting size.
static func release(piece: CanvasItem) -> Tween:
	_kill(piece)
	_settle_rest(piece)
	var t := _track(piece, piece.create_tween())
	t.tween_property(piece, "scale", SQUASH_DESCEND, 0.06)
	t.tween_property(piece, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return t


## Anticipate, arc over the board, stretch on the way down. Await .finished.
static func hop(piece: Node2D, from: Vector2, to: Vector2) -> Tween:
	_kill(piece)
	_settle_rest(piece)
	var height := clampf(from.distance_to(to) * 0.3, 24.0, 90.0)
	var apex := from.lerp(to, 0.5) + Vector2(0, -height)
	var move := _track(piece, piece.create_tween())
	move.tween_interval(ANTICIPATE)
	move.tween_property(piece, "global_position", apex, HOP_UP).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	move.tween_property(piece, "global_position", to, HOP_DOWN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var squash := _track(piece, piece.create_tween())
	squash.tween_property(piece, "scale", SQUASH_ANTICIPATE, ANTICIPATE)
	squash.tween_property(piece, "scale", SQUASH_LAUNCH, HOP_UP).set_trans(Tween.TRANS_SINE)
	squash.tween_property(piece, "scale", SQUASH_DESCEND, HOP_DOWN).set_trans(Tween.TRANS_SINE)
	return move


## The landing beat: hard flatten, a wobble, then spring back to rest.
static func impact(piece: Node2D) -> Tween:
	_kill(piece)
	var t := _track(piece, piece.create_tween())
	t.set_parallel(true)
	t.tween_property(piece, "scale", IMPACT_SQUASH, 0.05).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(piece, "scale", Vector2.ONE, SETTLE_TIME).from(IMPACT_SQUASH).set_delay(0.05).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_property(piece, "rotation", REJECT_TILT, 0.05)
	t.tween_property(piece, "rotation", -0.12, 0.07).set_delay(0.05)
	t.tween_property(piece, "rotation", 0.06, 0.07).set_delay(0.12)
	t.tween_property(piece, "rotation", 0.0, 0.08).set_delay(0.19)
	return t


## Illegal move: the piece shakes its head and flashes red.
static func reject(piece: CanvasItem) -> Tween:
	_kill(piece)
	var rest: Color = piece.modulate
	piece.set_meta("juice_rest", rest)
	var t := _track(piece, piece.create_tween())
	t.set_parallel(true)
	t.tween_property(piece, "rotation", REJECT_TILT, 0.05)
	t.tween_property(piece, "rotation", -REJECT_TILT, 0.08).set_delay(0.05)
	t.tween_property(piece, "rotation", REJECT_TILT * 0.6, 0.07).set_delay(0.13)
	t.tween_property(piece, "rotation", 0.0, 0.07).set_delay(0.20)
	t.tween_property(piece, "modulate", REJECT_COLOR, 0.04)
	t.tween_property(piece, "modulate", rest, 0.24).set_delay(0.10)
	return t


## A freshly created marker bouncing into place, then idling.
static func marker_in(marker: CanvasItem) -> Tween:
	_kill(marker)
	marker.pivot_offset = marker.size / 2.0
	marker.scale = Vector2.ZERO
	var t := _track(marker, marker.create_tween())
	t.tween_property(marker, "scale", Vector2(1.15, 1.15), 0.24).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_callback(_marker_idle.bind(marker))
	return t


static func _marker_idle(marker: CanvasItem) -> void:
	if not is_instance_valid(marker):
		return
	var t := _track(marker, marker.create_tween().set_loops())
	t.tween_property(marker, "scale", Vector2(1.14, 1.14), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(marker, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## One-shot ring that blooms and fades, then frees itself.
static func flash_out(node: CanvasItem) -> Tween:
	_kill(node)
	var t := _track(node, node.create_tween())
	t.set_parallel(true)
	t.tween_property(node, "scale", Vector2(1.6, 1.6), 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "modulate", Color(1, 1, 1, 0), 0.26).set_trans(Tween.TRANS_QUAD)
	t.chain().tween_callback(node.queue_free)
	return t


## A captured piece: pop, spin, fade, gone.
static func pop_out(piece: Node2D) -> Tween:
	_kill(piece)
	var t := _track(piece, piece.create_tween())
	t.set_parallel(true)
	t.tween_property(piece, "scale", Vector2(1.5, 1.5), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(piece, "scale", Vector2.ZERO, 0.26).set_delay(0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_property(piece, "rotation", 0.9, 0.38)
	t.tween_property(piece, "modulate:a", 0.0, 0.24).set_delay(0.14)
	t.chain().tween_callback(piece.queue_free)
	return t


## A promoted piece landing on the board with a pop.
static func spawn(piece: Node2D) -> Tween:
	_kill(piece)
	piece.scale = Vector2.ZERO
	var t := _track(piece, piece.create_tween())
	t.tween_property(piece, "scale", Vector2(1.28, 1.28), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(piece, "scale", Vector2.ONE, 0.14)
	return t


## A panel appearing, e.g. the promotion picker.
static func panel_in(panel: Control) -> Tween:
	_kill(panel)
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.7, 0.7)
	panel.modulate.a = 0.0
	var t := _track(panel, panel.create_tween())
	t.set_parallel(true)
	t.tween_property(panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(panel, "modulate:a", 1.0, 0.16)
	return t


## Every tap on a square gets a press pop.
static func tap(cell: Control) -> Tween:
	_kill(cell)
	cell.pivot_offset = cell.size / 2.0
	var t := _track(cell, cell.create_tween())
	t.tween_property(cell, "scale", Vector2(0.94, 0.94), 0.05)
	t.tween_property(cell, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	return t
