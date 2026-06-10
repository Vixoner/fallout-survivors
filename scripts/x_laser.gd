extends Node2D

# Robot boss attack: X-shaped laser anchored at spawn position.
# 1) Yellow telegraph phase (no damage) — player can pre-position.
# 2) Red damage phase — anyone inside the X cross-section takes one hit.
#
# Arms are fixed at 45° / 135° / 225° / 315° relative to world. The node
# stays put even if the boss moves during the telegraph (predictable dodge).

const TELEGRAPH_TIME := 1.0
const DAMAGE_TIME := 0.4
const ARM_LENGTH := 2400.0
const ARM_HALF_WIDTH := 45.0
const DAMAGE := 30

var _arm_dirs: Array = []
var _lines: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 6
	# Caller may have set rotation before add_child (e.g. PI/4 for a "+" shape
	# instead of "X"). Bake that rotation into the world-space arm directions,
	# then zero out node rotation so the Line2D visuals are already aligned.
	var rot: float = rotation
	for offset in [PI / 4.0, 3.0 * PI / 4.0, 5.0 * PI / 4.0, 7.0 * PI / 4.0]:
		var a: float = offset + rot
		_arm_dirs.append(Vector2(cos(a), sin(a)))
	rotation = 0.0
	_telegraph()

func _telegraph() -> void:
	_lines = _make_arm_visuals(Color(1.0, 0.95, 0.20, 0.45))
	await get_tree().create_timer(TELEGRAPH_TIME).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return
	for l in _lines:
		if is_instance_valid(l):
			l.queue_free()
	_damage_phase()

func _damage_phase() -> void:
	_lines = _make_arm_visuals(Color(1.0, 0.20, 0.15, 0.85))
	_apply_damage_to_player()
	await get_tree().create_timer(DAMAGE_TIME).timeout
	if is_instance_valid(self) and is_inside_tree():
		queue_free()

func _make_arm_visuals(color: Color) -> Array:
	var out: Array = []
	for dir in _arm_dirs:
		var line := Line2D.new()
		line.add_point(Vector2.ZERO)
		line.add_point(dir * ARM_LENGTH)
		line.width = ARM_HALF_WIDTH * 2.0
		line.default_color = color
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		add_child(line)
		out.append(line)
	return out

func _apply_damage_to_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		return
	var to_player: Vector2 = player.global_position - global_position
	for dir in _arm_dirs:
		var along: float = to_player.dot(dir)
		if along < 0.0 or along > ARM_LENGTH:
			continue
		var perp := Vector2(-dir.y, dir.x)
		if abs(to_player.dot(perp)) <= ARM_HALF_WIDTH:
			if player.has_method("take_damage"):
				player.take_damage(DAMAGE)
			return
