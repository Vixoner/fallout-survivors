extends Node2D

# Short-lived piercing laser beam: damages every enemy along a straight line
# from the player, then fades out. Spawned by WeaponManager for beam weapons.

var _origin: Vector2 = Vector2.ZERO
var _direction: Vector2 = Vector2.RIGHT
var _length: float = 700.0
var _damage: int = 10
var _width: float = 40.0
var _is_crit: bool = false

const FADE_TIME := 0.14

func configure(origin: Vector2, direction: Vector2, length: float, damage: int, width: float, is_crit: bool = false) -> void:
	_origin = origin
	_direction = direction if direction != Vector2.ZERO else Vector2.RIGHT
	_length = length
	_damage = damage
	_width = width
	_is_crit = is_crit

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 7
	global_position = _origin
	rotation = _direction.angle()
	_apply_damage()
	_draw_beam()

func _apply_damage() -> void:
	# Perpendicular axis used to measure how far an enemy sits off the beam line.
	var perp := Vector2(-_direction.y, _direction.x)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var to_enemy: Vector2 = enemy.global_position - _origin
		var along := to_enemy.dot(_direction)
		if along < 0.0 or along > _length:
			continue
		if abs(to_enemy.dot(perp)) > _width * 0.5:
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(_damage, _is_crit)

func _draw_beam() -> void:
	# Beam is drawn in local space; the node is rotated to face _direction.
	var glow := Line2D.new()
	glow.add_point(Vector2.ZERO)
	glow.add_point(Vector2(_length, 0.0))
	glow.width = _width
	glow.default_color = Color(1.0, 0.15, 0.1, 0.30)
	glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(glow)

	var core := Line2D.new()
	core.add_point(Vector2.ZERO)
	core.add_point(Vector2(_length, 0.0))
	core.width = _width * 0.35
	core.default_color = Color(1.0, 0.4, 0.35, 0.95)
	core.begin_cap_mode = Line2D.LINE_CAP_ROUND
	core.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(core)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(glow, "modulate:a", 0.0, FADE_TIME)
	tween.tween_property(core, "modulate:a", 0.0, FADE_TIME)
	tween.tween_property(core, "width", 0.0, FADE_TIME)
	tween.chain().tween_callback(queue_free)
