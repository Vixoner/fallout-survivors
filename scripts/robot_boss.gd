extends "res://scripts/enemy.gd"

# Robot boss for endless mode (2nd boss appearing every other boss spawn).
# - Slow drift, maintains preferred distance from player.
# - No melee attack — all damage comes from attack patterns.
# - HP-driven phases switch attack pool and cooldown:
#     Phase 1 (100-66%):  X laser, missiles                | 2.5s cooldown
#     Phase 2 (66-33%):   + spinning beam                   | 1.5s cooldown
#     Phase 3 (<33%):     + sentry drones                   | 0.6s cooldown
# - Owns its own boss bar (// BOSS // label) same as zombie_boss.

const X_LASER_SCRIPT      := preload("res://scripts/x_laser.gd")
const MISSILE_SCRIPT      := preload("res://scripts/missile_strike.gd")
const SPINNING_BEAM_SCRIPT := preload("res://scripts/spinning_beam.gd")
const DRONE_SCENE         := preload("res://scenes/sentry_drone.tscn")
const BULLET_SCENE        := preload("res://scenes/bullet.tscn")

const C_BOSS_BRIGHT := Color(0.42, 1.00, 0.42)

const PHASE2_HP := 0.66
const PHASE3_HP := 0.33

const PHASE1_COOLDOWN := 2.0
const PHASE2_COOLDOWN := 1.3
const PHASE3_COOLDOWN := 0.5

# Per-attack durations — used to await before declaring the attack finished.
const X_LASER_INSTANCE_DURATION := 1.65   # one laser cycle: telegraph 1.2 + damage 0.4 + buffer
const CROSS_ATTACK_DURATION := X_LASER_INSTANCE_DURATION * 2.0 + 0.05  # X then + back-to-back
const MISSILE_IMPACT_WAIT := 1.55  # wait for the last missile's countdown to finish
const SPIN_BEAM_DURATION := 0.8 + 1.5 + 0.05  # telegraph + half-sweep + tiny buffer
const DRONE_DURATION     := 0.4    # near-instant; drones persist

const DRONE_MAX_ALIVE := 5
const DRONES_PER_ATTACK := 3
# Drones spawn at these HP fractions (in descending order). Only the FINAL
# threshold (last entry, 20%) spawns champion drones; earlier waves are regular.
# Independent of phase / attack pool — purely HP-threshold driven.
const DRONE_HP_THRESHOLDS := [0.80, 0.60, 0.40, 0.20]

# Constant pistol fire — runs in parallel with other attacks, never blocks them.
# Interval (seconds between shots) tightens per phase.
const PISTOL_INTERVAL_BY_PHASE := [1.0, 0.65, 0.4]
const PISTOL_DAMAGE := 10
const PISTOL_BULLET_SPEED := 900.0

const PREFERRED_DISTANCE := 500.0
const DISTANCE_BAND := 100.0

# Pick missile landing points within this radius of the player so the barrage
# pressures their current position.
const MISSILE_TARGET_RADIUS := 700.0
const MISSILE_COUNT_BY_PHASE := [10, 15, 20]  # phase 1 / 2 / 3
const MISSILE_INTERVAL := 0.10

var _phase: int = 1
var _attack_cooldown: float = PHASE1_COOLDOWN
var _attack_timer: float = 0.0
var _attack_in_progress: bool = false
var _alive_drones: int = 0
var _next_drone_threshold_idx: int = 0  # index into DRONE_HP_THRESHOLDS
var _pistol_timer: float = 0.0
var _boss_label: Label = null

func _ready() -> void:
	super._ready()
	_setup_boss_bar()
	_attack_timer = randf_range(0.0, _attack_cooldown * 0.4)

# Fully override enemy.gd's chase/melee loop — robot doesn't melee or run.
func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if player == null or not is_instance_valid(player):
		return

	_check_phase_transition()
	_maintain_distance()
	move_and_slide()

	# Constant pistol fire — runs alongside whatever the main attack pattern
	# is doing. Phase tightens the interval. Never blocks other attacks.
	_pistol_timer += delta
	var pistol_interval: float = PISTOL_INTERVAL_BY_PHASE[clamp(_phase - 1, 0, PISTOL_INTERVAL_BY_PHASE.size() - 1)]
	if _pistol_timer >= pistol_interval:
		_pistol_timer = 0.0
		_fire_pistol_at_player()

	if not _attack_in_progress:
		_attack_timer += delta
		if _attack_timer >= _attack_cooldown:
			_attack_timer = 0.0
			_start_next_attack()

func _check_phase_transition() -> void:
	var frac: float = float(health) / float(max(1, max_health))
	var target_phase: int = 1
	if frac < PHASE3_HP:
		target_phase = 3
	elif frac < PHASE2_HP:
		target_phase = 2
	if target_phase != _phase:
		_phase = target_phase
		match _phase:
			1: _attack_cooldown = PHASE1_COOLDOWN
			2: _attack_cooldown = PHASE2_COOLDOWN
			3: _attack_cooldown = PHASE3_COOLDOWN

func _maintain_distance() -> void:
	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()
	var dir: Vector2 = Vector2.ZERO
	if dist > PREFERRED_DISTANCE + DISTANCE_BAND:
		dir = to_player.normalized()
	elif dist < PREFERRED_DISTANCE - DISTANCE_BAND:
		dir = -to_player.normalized()
	velocity = dir * move_speed

func _start_next_attack() -> void:
	var pool: Array[String] = ["cross_attack", "missiles"]
	# Spinning beam disabled for now — uncomment the line below to re-enable.
	# if _phase >= 2:
	# 	pool.append("spinning_beam")
	# Drones are NOT in this pool — they spawn at HP thresholds instead
	# (see _check_drone_thresholds, called from take_damage).
	var pick: String = pool[randi() % pool.size()]
	_attack_in_progress = true
	match pick:
		"cross_attack":  _perform_cross_attack()
		"missiles":      _perform_missiles()
		"spinning_beam": _perform_spinning_beam()

# Combined cross attack: first X (arms at 45° offsets), then + (rotated 45°).
# Each shape goes through its own telegraph → damage cycle independently,
# so the player gets two clear dodge windows in one attack.
func _perform_cross_attack() -> void:
	var x = X_LASER_SCRIPT.new()
	x.global_position = global_position
	get_tree().current_scene.add_child(x)
	await get_tree().create_timer(X_LASER_INSTANCE_DURATION).timeout
	if not is_instance_valid(self) or is_dead:
		return
	var plus = X_LASER_SCRIPT.new()
	plus.rotation = PI / 4.0  # turns X-arms into +-arms (up/right/down/left)
	plus.global_position = global_position
	get_tree().current_scene.add_child(plus)
	await get_tree().create_timer(X_LASER_INSTANCE_DURATION).timeout
	if not is_instance_valid(self) or is_dead:
		return
	_attack_in_progress = false

func _perform_missiles() -> void:
	if player == null or not is_instance_valid(player):
		_attack_in_progress = false
		return
	var center: Vector2 = player.global_position
	var missile_count: int = MISSILE_COUNT_BY_PHASE[clamp(_phase - 1, 0, MISSILE_COUNT_BY_PHASE.size() - 1)]
	for i in missile_count:
		if is_dead or not is_instance_valid(self):
			return
		var offset := Vector2(
			randf_range(-MISSILE_TARGET_RADIUS, MISSILE_TARGET_RADIUS),
			randf_range(-MISSILE_TARGET_RADIUS, MISSILE_TARGET_RADIUS),
		)
		var m = MISSILE_SCRIPT.new()
		m.global_position = center + offset
		get_tree().current_scene.add_child(m)
		await get_tree().create_timer(MISSILE_INTERVAL).timeout
	if is_dead or not is_instance_valid(self):
		return
	# Wait for the last missile's countdown to finish before scheduling next attack.
	await get_tree().create_timer(MISSILE_IMPACT_WAIT).timeout
	if not is_instance_valid(self) or is_dead:
		return
	_attack_in_progress = false

func _fire_pistol_at_player() -> void:
	if player == null or not is_instance_valid(player):
		return
	var direction: Vector2 = global_position.direction_to(player.global_position)
	var bullet = BULLET_SCENE.instantiate()
	bullet.global_position = global_position
	bullet.rotation = direction.angle()
	if "target_group" in bullet:
		bullet.target_group = "player"
	if "damage" in bullet:
		bullet.damage = PISTOL_DAMAGE
	if "speed" in bullet:
		bullet.speed = PISTOL_BULLET_SPEED
	get_tree().current_scene.add_child(bullet)

func _perform_spinning_beam() -> void:
	var beam = SPINNING_BEAM_SCRIPT.new()
	# Randomly start from top (-PI/2) or bottom (PI/2), and sweep CW or CCW.
	# Half-circle so the opposite side stays safe — player must read which arc
	# is dangerous and dodge to the safe half.
	var start_angle: float = -PI / 2.0 if randf() < 0.5 else PI / 2.0
	var sweep_dir: float = 1.0 if randf() < 0.5 else -1.0
	beam.setup(self, start_angle, sweep_dir)
	get_tree().current_scene.add_child(beam)
	await get_tree().create_timer(SPIN_BEAM_DURATION).timeout
	if not is_instance_valid(self) or is_dead:
		return
	_attack_in_progress = false

# Spawn a wave of drones — called by _check_drone_thresholds when HP crosses
# one of DRONE_HP_THRESHOLDS. Only the FINAL threshold (the last index, i.e.
# 20% HP) spawns champion drones; earlier waves are regular drones.
# Doesn't touch _attack_in_progress so it can fire mid-attack without
# disrupting the current pattern.
func _spawn_drone_wave(as_champion: bool) -> void:
	for i in DRONES_PER_ATTACK:
		if _alive_drones >= DRONE_MAX_ALIVE:
			break
		var drift := Vector2.RIGHT.rotated(TAU * float(i) / float(DRONES_PER_ATTACK) + randf_range(-0.3, 0.3))
		var drone = DRONE_SCENE.instantiate()
		drone.global_position = global_position + drift * 60.0
		drone.died.connect(_on_drone_died)
		if drone.has_method("setup"):
			drone.setup(drift)
		get_tree().current_scene.add_child(drone)
		if as_champion and drone.has_method("make_champion"):
			drone.make_champion()
		_alive_drones += 1

# Called from take_damage. Uses `while` so a single big hit that crosses
# multiple thresholds (e.g. plasma crit) fires every threshold it skipped.
# Only the final threshold (index = size-1, i.e. 20%) spawns champions.
func _check_drone_thresholds() -> void:
	while _next_drone_threshold_idx < DRONE_HP_THRESHOLDS.size():
		var frac: float = float(health) / float(max(1, max_health))
		if frac <= DRONE_HP_THRESHOLDS[_next_drone_threshold_idx]:
			var is_final_threshold: bool = _next_drone_threshold_idx == DRONE_HP_THRESHOLDS.size() - 1
			_spawn_drone_wave(is_final_threshold)
			_next_drone_threshold_idx += 1
		else:
			break

func _on_drone_died(pos: Vector2, caps_count: int) -> void:
	_alive_drones = max(0, _alive_drones - 1)
	# Forward the kill to endless so XP, caps, and on-kill perks still trigger.
	var scene_root := get_tree().current_scene
	if scene_root and scene_root.has_method("_on_enemy_died"):
		scene_root._on_enemy_died(pos, caps_count, "sentry_drone")

func die() -> void:
	# Take any surviving drones with the boss — keeps the post-boss shop clean.
	for d in get_tree().get_nodes_in_group("sentry_drones"):
		if is_instance_valid(d) and d.has_method("die"):
			d.die()
	if is_instance_valid(_boss_label):
		_boss_label.visible = false
	super.die()

# ── Boss bar (mirrors boss_enemy.gd) ────────────────────────────────────────

func _setup_boss_bar() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "BossBarCanvas"
	canvas.layer = 5
	add_child(canvas)

	_boss_label = Label.new()
	_boss_label.add_theme_font_size_override("font_size", 40)
	_boss_label.add_theme_color_override("font_color", C_BOSS_BRIGHT)
	_boss_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_boss_label.add_theme_constant_override("outline_size", 5)
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_label.anchor_left = 0.5
	_boss_label.anchor_right = 0.5
	_boss_label.anchor_top = 0.0
	_boss_label.anchor_bottom = 0.0
	_boss_label.offset_left = -400.0
	_boss_label.offset_right = 400.0
	_boss_label.offset_top = 30.0
	_boss_label.offset_bottom = 90.0
	_boss_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_boss_label)
	_update_boss_label()

func _update_boss_label() -> void:
	if is_instance_valid(_boss_label):
		_boss_label.text = "// ROBOT //   %d / %d" % [max(0, health), max_health]

func take_damage(amount, is_crit: bool = false) -> void:
	super.take_damage(amount, is_crit)
	_update_boss_label()
	_check_drone_thresholds()
