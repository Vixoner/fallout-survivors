extends Node2D

# Short-lived gooey green puddle left after a plasma bolt impacts.
# Damages every enemy inside its radius on a fixed tick interval, using
# distance checks (same pattern as laser_beam.gd) so there's no
# physics-frame delay before the first tick can land.

var radius: float = 80.0
var duration: float = 2.5
var tick_interval: float = 0.4
var tick_damage: int = 8

var _elapsed: float = 0.0
var _next_tick: float = 0.0

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
	if _elapsed >= _next_tick:
		_next_tick += tick_interval
		_apply_tick()
	if _elapsed >= duration:
		queue_free()

func _apply_tick() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) > radius:
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(tick_damage, false)

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
