extends Node

# Per-enemy poison DoT — attached as a child of an enemy when a poisoned
# karabin bullet hits. Ticks `tick_dmg` damage every second for `duration`.
# Subsequent hits call `refresh()` to reset the elapsed timer (so spammy
# fire keeps the poison alive indefinitely without stacking infinitely).

const NODE_NAME := "PoisonDot"

var tick_dmg: int = 1
var duration: float = 5.0

var _elapsed: float = 0.0
var _tick_timer: float = 0.0
var _tint_tween: Tween = null

func _ready() -> void:
	name = NODE_NAME
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# Subtle green tint on the host enemy while poisoned, restored on cleanup.
	var enemy: Node = get_parent()
	if enemy and "modulate" in enemy:
		_tint_tween = create_tween().set_loops()
		_tint_tween.tween_property(enemy, "modulate", Color(0.65, 1.05, 0.65, 1.0), 0.35)
		_tint_tween.tween_property(enemy, "modulate", Color(0.9, 1.0, 0.9, 1.0), 0.35)

func refresh() -> void:
	_elapsed = 0.0

func _process(delta: float) -> void:
	_elapsed += delta
	_tick_timer += delta
	if _tick_timer >= 1.0:
		_tick_timer -= 1.0
		var enemy: Node = get_parent()
		if enemy and enemy.has_method("take_damage") and not enemy.get("is_dead"):
			enemy.take_damage(tick_dmg, false)
	if _elapsed >= duration:
		_cleanup()

func _cleanup() -> void:
	if _tint_tween:
		_tint_tween.kill()
		_tint_tween = null
	var enemy: Node = get_parent()
	if enemy and "modulate" in enemy:
		enemy.modulate = Color(1, 1, 1, 1)
	queue_free()
