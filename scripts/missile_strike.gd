extends Node2D

# Single missile landing-zone indicator. Drawn as a shrinking black circle.
# When it fully contracts (1.5s), deals AoE damage at the position.

const WIND_TIME := 1.5
const INDICATOR_RADIUS := 80.0
const DAMAGE_RADIUS := 80.0
const DAMAGE := 35

var _indicator: Polygon2D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 4
	_draw_indicator()
	_start_countdown()

func _draw_indicator() -> void:
	_indicator = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 32:
		var a: float = TAU * float(i) / 32.0
		pts.append(Vector2(cos(a), sin(a)) * INDICATOR_RADIUS)
	_indicator.polygon = pts
	_indicator.color = Color(0.0, 0.0, 0.0, 0.70)
	add_child(_indicator)
	# Thin red rim so it stands out against dirt tiles.
	var rim := Line2D.new()
	for i in range(33):
		var a: float = TAU * float(i) / 32.0
		rim.add_point(Vector2(cos(a), sin(a)) * INDICATOR_RADIUS)
	rim.width = 3.0
	rim.default_color = Color(0.85, 0.25, 0.20, 0.85)
	_indicator.add_child(rim)

func _start_countdown() -> void:
	var tw := create_tween()
	tw.tween_property(_indicator, "scale", Vector2(0.05, 0.05), WIND_TIME).set_trans(Tween.TRANS_QUART)
	await tw.finished
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_impact()

func _impact() -> void:
	# Damage application — distance to landing point, player only.
	var player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		if global_position.distance_to(player.global_position) <= DAMAGE_RADIUS:
			if player.has_method("take_damage"):
				player.take_damage(DAMAGE)
	# Flash visual
	if is_instance_valid(_indicator):
		_indicator.queue_free()
	var flash := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 32:
		var a: float = TAU * float(i) / 32.0
		pts.append(Vector2(cos(a), sin(a)) * DAMAGE_RADIUS)
	flash.polygon = pts
	flash.color = Color(1.0, 0.55, 0.20, 0.85)
	flash.scale = Vector2(0.4, 0.4)
	add_child(flash)
	var ftw := flash.create_tween()
	ftw.set_parallel(true)
	ftw.tween_property(flash, "scale", Vector2(1.4, 1.4), 0.30)
	ftw.tween_property(flash, "modulate:a", 0.0, 0.30)
	ftw.chain().tween_callback(queue_free)
