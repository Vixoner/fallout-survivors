extends Node2D

# Short-lived gooey green puddle left after a plasma bolt impacts.
# Damages every enemy inside its radius on a fixed tick interval, using
# distance checks (same pattern as laser_beam.gd) so there's no
# physics-frame delay before the first tick can land.

var radius: float = 80.0
var duration: float = 2.5
var tick_interval: float = 0.4
var tick_damage: int = 8
var slow_amount: float = 0.0  # Lepka Plazma slow (0 = no slow, 0.5 = halve speed)

var _elapsed: float = 0.0
var _next_tick: float = 0.0
# Tracks enemies we slowed and their original move_speed so we restore them on exit.
var _slowed: Dictionary = {}

func configure(rad: float, dur: float, interval: float, dmg: int) -> void:
	radius = rad
	duration = dur
	tick_interval = interval
	tick_damage = dmg

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 4
	_draw_visual()
	_next_tick = tick_interval

func _process(delta: float) -> void:
	_elapsed += delta
	if slow_amount > 0.0:
		_apply_slow_field()
	if _elapsed >= _next_tick:
		_next_tick += tick_interval
		_apply_tick()
	if _elapsed >= duration:
		_restore_all_slows()
		queue_free()

func _apply_tick() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) > radius:
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(tick_damage, false)

# Lepka Plazma — keep enemies inside the puddle slowed; restore as they leave.
func _apply_slow_field() -> void:
	# Mark currently inside enemies, apply slow on first entry.
	var seen := {}
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if "move_speed" not in enemy:
			continue
		if global_position.distance_to(enemy.global_position) <= radius:
			seen[enemy] = true
			if not _slowed.has(enemy):
				_slowed[enemy] = enemy.move_speed
				enemy.move_speed *= (1.0 - slow_amount)
	# Anyone we previously slowed but isn't here anymore → restore.
	for prev in _slowed.keys():
		if not seen.has(prev):
			if is_instance_valid(prev) and "move_speed" in prev:
				prev.move_speed = _slowed[prev]
			_slowed.erase(prev)

func _restore_all_slows() -> void:
	for prev in _slowed.keys():
		if is_instance_valid(prev) and "move_speed" in prev:
			prev.move_speed = _slowed[prev]
	_slowed.clear()

func _draw_visual() -> void:
	var n := 28
	var outer := Polygon2D.new()
	var opts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		opts.append(Vector2(cos(a), sin(a)) * radius)
	outer.polygon = opts
	outer.color = Color(0.25, 0.95, 0.30, 0.30)
	add_child(outer)

	var inner := Polygon2D.new()
	var ipts := PackedVector2Array()
	var ir := radius * 0.55
	for i in n:
		var a := TAU * float(i) / float(n)
		ipts.append(Vector2(cos(a), sin(a)) * ir)
	inner.polygon = ipts
	inner.color = Color(0.55, 1.0, 0.45, 0.55)
	add_child(inner)

	# Gentle fade-out near the end of the lifetime.
	var tw := create_tween()
	tw.tween_interval(max(0.0, duration - 0.5))
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
