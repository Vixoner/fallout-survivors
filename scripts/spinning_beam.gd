extends Node2D

# Robot boss attack: a single laser beam anchored to the boss that sweeps
# 360° around it. Yellow telegraph at the starting angle (no damage), then
# red sweep with periodic damage ticks. Follows the boss in case it moves.

const TELEGRAPH_TIME := 0.8
const SPIN_TIME := 1.5             # half-arc sweep, slightly faster overall pace
const SWEEP_ARC := PI              # 180° (half circle, not full)
const BEAM_LENGTH := 1500.0
const BEAM_HALF_WIDTH := 150.0
const DAMAGE_PER_TICK := 25
const DAMAGE_TICK_INTERVAL := 0.15
const PLAYER_HIT_REUSE := 0.5  # min seconds between consecutive hits on player

var _boss_ref: Node2D = null
var _beam: Line2D = null
var _start_angle: float = 0.0
var _sweep_direction: float = 1.0  # +1 = CW, -1 = CCW
var _spinning: bool = false
var _spin_elapsed: float = 0.0
var _tick_timer: float = 0.0
var _last_hit_at: float = -1000.0

func setup(boss: Node2D, start_angle: float = 0.0, sweep_direction: float = 1.0) -> void:
	_boss_ref = boss
	_start_angle = start_angle
	_sweep_direction = sign(sweep_direction)
	if _sweep_direction == 0.0:
		_sweep_direction = 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 6
	_follow_boss()
	rotation = _start_angle
	_draw_beam(Color(1.0, 0.95, 0.20, 0.50))
	await get_tree().create_timer(TELEGRAPH_TIME).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_beam.default_color = Color(1.0, 0.20, 0.15, 0.85)
	_spinning = true

func _follow_boss() -> void:
	if is_instance_valid(_boss_ref):
		global_position = _boss_ref.global_position

func _process(delta: float) -> void:
	_follow_boss()
	if not _spinning:
		return
	_spin_elapsed += delta
	var t: float = clamp(_spin_elapsed / SPIN_TIME, 0.0, 1.0)
	rotation = _start_angle + t * _sweep_direction * SWEEP_ARC
	_tick_timer += delta
	if _tick_timer >= DAMAGE_TICK_INTERVAL:
		_tick_timer = 0.0
		_apply_damage_tick()
	if _spin_elapsed >= SPIN_TIME:
		queue_free()

func _draw_beam(color: Color) -> void:
	_beam = Line2D.new()
	_beam.add_point(Vector2.ZERO)
	_beam.add_point(Vector2(BEAM_LENGTH, 0.0))
	_beam.width = BEAM_HALF_WIDTH * 2.0
	_beam.default_color = color
	_beam.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_beam.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_beam)

func _apply_damage_tick() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		return
	# Limit how often the player can be hit by the sweep — otherwise standing
	# in the path drains health unrealistically fast.
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_hit_at < PLAYER_HIT_REUSE:
		return
	var beam_dir := Vector2.RIGHT.rotated(rotation)
	var to_player: Vector2 = player.global_position - global_position
	var along: float = to_player.dot(beam_dir)
	if along < 0.0 or along > BEAM_LENGTH:
		return
	var perp := Vector2(-beam_dir.y, beam_dir.x)
	if abs(to_player.dot(perp)) <= BEAM_HALF_WIDTH:
		if player.has_method("take_damage"):
			player.take_damage(DAMAGE_PER_TICK)
		_last_hit_at = now
