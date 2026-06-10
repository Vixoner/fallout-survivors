extends Node2D

# Endless mode main loop. Mirrors story's main.gd structure but with:
#   - Time/level-based tier spawning (no pre-defined WAVES)
#   - XP routing on every kill
#   - Level-up triggers stat-allocation panel (+ perk panel every 3rd level)
#   - Boss interruption every 10th level
#   - Boss death → full heal + shop with weapon upgrades → resume
#   - Bloody Mess + Mysterious Stranger perk hooks live here

const CAP_SCENE        = preload("res://scenes/cap.tscn")
const SHOP_SCRIPT      = preload("res://scripts/shop.gd")
const PAUSE_MENU_SCRIPT = preload("res://scripts/pause_menu.gd")
const GAME_OVER_SCRIPT = preload("res://scripts/game_over_screen.gd")
const LEVEL_UP_PANEL   = preload("res://scripts/level_up_panel.gd")
const PERK_PANEL       = preload("res://scripts/perk_panel.gd")
const LASER_BEAM       = preload("res://scripts/laser_beam.gd")

const SPAWN_MIN_DIST = 700.0
const SPAWN_MAX_DIST = 1100.0

const ENEMY_SCENES = {
	"rat":          preload("res://scenes/rat.tscn"),
	"zombie_small": preload("res://scenes/enemy.tscn"),
	"zombie_big":   preload("res://scenes/enemy_big.tscn"),
	"floater":      preload("res://scenes/floater.tscn"),
	"handy":        preload("res://scenes/handy.tscn"),
	"zombie_boss":  preload("res://scenes/enemy_boss.tscn"),
	"robot_boss":   preload("res://scenes/robot_boss.tscn"),
}

# Boss rotation. Indexed by (boss_count - 1) % len so the list cycles forever.
# Add new bosses to the end of this list to extend rotation.
const BOSS_POOL := ["zombie_boss", "robot_boss"]

# Era-based spawn pools. Each entry in ERAS is a list of tiers; tiers within
# an era unlock by player level / time RELATIVE to when that era started.
# Era advances on each boss kill (capped at ERAS.size()).
#   Era 1 — pre-zombie-boss   (rats / zombies / floater)
#   Era 2 — post-zombie-boss   (handy + future ranged robot)
#   Era 3+ — TODO when raider enemies exist
const ERAS = [
	# Era 1
	[
		{"level": 1,  "time": 0.0,   "pool": {"rat": 1.0}},
		{"level": 3,  "time": 90.0,  "pool": {"rat": 0.60, "zombie_small": 0.40}},
		{"level": 5,  "time": 200.0, "pool": {"rat": 0.30, "zombie_small": 0.50, "floater": 0.20}},
		{"level": 8,  "time": 360.0, "pool": {"rat": 0.15, "zombie_small": 0.35, "zombie_big": 0.20, "floater": 0.30}},
	],
	# Era 2 — handy filler robot. The ranged robot enemy will be added here
	# once authored; floater stays in era 1.
	[
		{"level": 1, "time": 0.0, "pool": {"handy": 1.0}},
	],
]

# XP awards per enemy type (champion ×2; boss applied below)
const XP_PER_ENEMY = {
	"rat": 8,
	"zombie_small": 12,
	"floater": 20,
	"handy": 22,
	"zombie_big": 25,
	"sentry_drone": 5,
	"zombie_boss": 300,
	"robot_boss": 500,
}

const PSYCHOPAT_BONUS := 0.10  # +10% XP from humanoid kills
const BLOODY_MESS_CHANCE := 0.05
const BLOODY_MESS_DAMAGE := 25
const BLOODY_MESS_RADIUS := 80.0
const MYSTERIOUS_STRANGER_INTERVAL := 30.0
const MYSTERIOUS_STRANGER_RANGE := 1500.0
const MYSTERIOUS_STRANGER_DAMAGE := 120

var player: Node2D = null

# Spawning state
var enemies_alive: int = 0
var _run_time: float = 0.0
var _spawn_timer: float = 0.0
var _kills: int = 0

# Era progression — advances each time a boss is killed (capped at ERAS.size()).
# Era-relative level/time tracked so each era's tiers ramp from the moment it starts.
var _era: int = 1
var _era_start_level: int = 1
var _era_start_time: float = 0.0
var _bosses_defeated: int = 0

# Boss state
var _boss_phase: bool = false       # true between "level hits multiple of 10" and "boss dead"
var _boss_pending: bool = false     # true while waiting for enemies_alive==0 before spawning boss
var _boss_instance: Node = null
var _boss_type_name: String = ""    # which boss is currently spawned (or "" if none)

# Pause / shop / etc.
var _pause_menu = null
var _in_shop: bool = false
var _game_over_shown: bool = false
var _level_up_queue: int = 0        # how many pending level-up panels to process
var _showing_modal: bool = false    # any modal panel (level-up/perk/shop) open

# Mysterious Stranger timer
var _stranger_timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = get_tree().get_first_node_in_group("player")
	if player:
		player.game_over.connect(_on_player_game_over)
		player.level_up_triggered.connect(_on_level_up)
		player.xp_changed.connect(_on_xp_changed)
	_start_music()
	_update_xp_ui(0, int(player.xp_to_next) if player else 150)
	_update_level_label()

func _start_music() -> void:
	var candidate_paths := [
		"res://assets/audio/music/metal_on_metal.ogg",
		"res://assets/audio/music/metal_on_metal.mp3",
	]
	var stream: AudioStream = null
	for path in candidate_paths:
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	if stream == null:
		return
	if "loop" in stream:
		stream.loop = true
	var mp := AudioStreamPlayer.new()
	mp.name = "MusicPlayer"
	mp.bus = "Music"
	mp.stream = stream
	mp.autoplay = true
	add_child(mp)

func _input(event): # tylko do testów, trzeba usunac ltaer
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER:
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if enemy != _boss_instance:
					enemy.die()
		elif event.keycode == KEY_BACKSPACE: # debug: level 20
			if player and player.has_method("add_xp"):
				player.add_xp(10000)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		_handle_escape()

	if get_tree().paused or _showing_modal:
		return
	if player and player.get("is_dying"):
		return

	_run_time += delta

	# Mysterious Stranger tick
	if player and player.has_perk("tajemniczy_nieznajomy"):
		_stranger_timer += delta
		if _stranger_timer >= MYSTERIOUS_STRANGER_INTERVAL:
			_stranger_timer = 0.0
			_mysterious_stranger_fire()

	# Boss pending — stop spawning, wait for screen to clear.
	if _boss_pending:
		if enemies_alive == 0:
			_boss_pending = false
			_spawn_boss()
		return

	# Don't spawn regular enemies during boss fight; boss may summon its own.
	if _boss_phase:
		return

	_spawn_timer += delta
	if _spawn_timer >= _spawn_cooldown():
		_spawn_timer = 0.0
		_spawn_one_enemy()

func _spawn_cooldown() -> float:
	if player == null:
		return 1.5
	var level: int = int(player.level)
	return max(0.35, 1.5 - level * 0.025)

func _pick_tier() -> Dictionary:
	var era_idx: int = clamp(_era - 1, 0, ERAS.size() - 1)
	var era_tiers: Array = ERAS[era_idx]
	# Level / time relative to era start, so each era ramps from "fresh".
	var level_in_era: int = 1
	if player:
		level_in_era = max(1, int(player.level) - _era_start_level + 1)
	var time_in_era: float = max(0.0, _run_time - _era_start_time)
	var t: Dictionary = era_tiers[0]
	for tier in era_tiers:
		if level_in_era >= int(tier["level"]) or time_in_era >= float(tier["time"]):
			t = tier
	return t

func _pick_enemy_type() -> String:
	var pool: Dictionary = _pick_tier()["pool"]
	var total: float = 0.0
	for v in pool.values():
		total += float(v)
	var r := randf() * total
	var acc := 0.0
	for k in pool:
		acc += float(pool[k])
		if r <= acc:
			return k
	return pool.keys()[0]

func _spawn_one_enemy() -> void:
	var type_name := _pick_enemy_type()
	if not type_name in ENEMY_SCENES:
		return
	var enemy = ENEMY_SCENES[type_name].instantiate()
	enemy.global_position = _get_spawn_position()
	# Per-spawn level scaling: +3% HP, +2% dmg per player level.
	var lvl: int = int(player.level) if player else 1
	var hp_mult: float = 1.0 + lvl * 0.03
	var dmg_mult: float = 1.0 + lvl * 0.02
	if "max_health" in enemy:
		enemy.max_health = int(round(enemy.max_health * hp_mult))
	if "attack_damage" in enemy:
		enemy.attack_damage = int(round(enemy.attack_damage * dmg_mult))
	# Also scale ball/projectile damage for ranged enemies like floater.
	if "ball_damage" in enemy:
		enemy.ball_damage = int(round(enemy.ball_damage * dmg_mult))
	enemy.died.connect(_on_enemy_died.bind(type_name))
	add_child(enemy)
	# Champion roll once player has some progression.
	if lvl >= 5 and enemy.has_method("make_champion"):
		var champ_chance: float = clamp(lvl * 0.012, 0.0, 0.30)
		if randf() < champ_chance:
			enemy.make_champion()
	enemies_alive += 1

func _get_spawn_position() -> Vector2:
	var margin := 64.0
	var map_min := Vector2(-GameConstants.MAP_WIDTH / 2.0 + margin, -GameConstants.MAP_HEIGHT / 2.0 + margin)
	var map_max := Vector2(GameConstants.MAP_WIDTH / 2.0 - margin, GameConstants.MAP_HEIGHT / 2.0 - margin)
	if player == null:
		return Vector2(randf_range(map_min.x, map_max.x), randf_range(map_min.y, map_max.y))
	for i in 32:
		var angle := randf() * TAU
		var dist := randf_range(SPAWN_MIN_DIST, SPAWN_MAX_DIST)
		var pos = player.global_position + Vector2(cos(angle), sin(angle)) * dist
		pos.x = clamp(pos.x, map_min.x, map_max.x)
		pos.y = clamp(pos.y, map_min.y, map_max.y)
		if pos.distance_to(player.global_position) >= SPAWN_MIN_DIST:
			return pos
	return Vector2(randf_range(map_min.x, map_max.x), randf_range(map_min.y, map_max.y))

# ── Kill processing ──────────────────────────────────────────────────────────

func _on_enemy_died(pos: Vector2, caps_count: int, type_name: String) -> void:
	enemies_alive = max(0, enemies_alive - 1)
	_kills += 1
	_spawn_caps(pos, caps_count)
	# XP — base value × Psychopata bonus if humanoid
	var base_xp: int = int(XP_PER_ENEMY.get(type_name, 10))
	var xp_amount: float = float(base_xp)
	if player.has_perk("psychopata") and Perks.is_humanoid(type_name):
		xp_amount *= 1.0 + PSYCHOPAT_BONUS
	if player and player.has_method("add_xp"):
		player.add_xp(int(round(xp_amount)))
		player.on_enemy_killed(type_name)
	# Bloody Mess: 5% chance to spawn a small AoE on death.
	if player.has_perk("krwawa_laznia") and randf() < BLOODY_MESS_CHANCE:
		_spawn_bloody_mess(pos)
	# Boss-specific cleanup — any boss type that's currently the active boss triggers
	# the post-fight flow. _boss_type_name was set at spawn.
	if type_name != "" and type_name == _boss_type_name:
		_boss_type_name = ""
		_on_boss_died()

func _spawn_caps(spawn_pos: Vector2, count: int) -> void:
	for i in count:
		var cap = CAP_SCENE.instantiate()
		cap.value = 1
		cap.position = spawn_pos + Vector2(randf_range(-30, 30), randf_range(-30, 30))
		add_child.call_deferred(cap)

func _spawn_bloody_mess(pos: Vector2) -> void:
	# Visual: brief expanding red ring; damage to nearby enemies via distance.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if pos.distance_to(enemy.global_position) <= BLOODY_MESS_RADIUS:
			if enemy.has_method("take_damage"):
				enemy.take_damage(BLOODY_MESS_DAMAGE, false)
	var fx := Node2D.new()
	fx.global_position = pos
	fx.z_index = 4
	add_child(fx)
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(Vector2(cos(a), sin(a)) * BLOODY_MESS_RADIUS)
	poly.polygon = pts
	poly.color = Color(1.0, 0.15, 0.10, 0.55)
	poly.scale = Vector2(0.2, 0.2)
	fx.add_child(poly)
	var tw := fx.create_tween()
	tw.set_parallel(true)
	tw.tween_property(poly, "scale", Vector2(1.0, 1.0), 0.35)
	tw.tween_property(poly, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(fx.queue_free)

func _mysterious_stranger_fire() -> void:
	# Pick a random enemy within range and fire a laser beam at them.
	var candidates: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if player.global_position.distance_to(enemy.global_position) <= MYSTERIOUS_STRANGER_RANGE:
			candidates.append(enemy)
	if candidates.is_empty():
		return
	var target = candidates[randi() % candidates.size()]
	var target_pos: Vector2 = target.global_position
	# Origin sits off-screen along a random angle from the target.
	var angle := randf() * TAU
	var origin: Vector2 = target_pos + Vector2(cos(angle), sin(angle)) * 900.0
	var direction: Vector2 = (target_pos - origin).normalized()
	var beam = LASER_BEAM.new()
	beam.configure(origin, direction, 900.0, MYSTERIOUS_STRANGER_DAMAGE, 38.0, false)
	get_tree().current_scene.add_child(beam)

# ── Level-up flow ────────────────────────────────────────────────────────────

func _on_level_up(new_level: int, _points: int, show_perk: bool, boss_phase_signal: bool) -> void:
	_level_up_queue += 1
	# Enqueue request; if not already showing modal, drive the chain.
	if boss_phase_signal:
		# Mark that a boss should spawn once the current enemies clear (after panels close).
		_boss_pending = true
		_boss_phase = true
	if not _showing_modal:
		_show_level_up_panel(new_level, show_perk)

func _show_level_up_panel(new_level: int, show_perk: bool) -> void:
	_showing_modal = true
	var panel = LEVEL_UP_PANEL.new()
	panel.setup(player, new_level)
	add_child(panel)
	await panel.closed
	if show_perk:
		_show_perk_panel()
	else:
		_after_modal_closed()

func _show_perk_panel() -> void:
	var perk = PERK_PANEL.new()
	perk.setup(player)
	add_child(perk)
	await perk.closed
	_after_modal_closed()

func _after_modal_closed() -> void:
	_level_up_queue -= 1
	_update_level_label()
	if _level_up_queue > 0:
		# Player leveled up twice quickly (rare) — drive the next chain.
		_show_level_up_panel(int(player.level), int(player.level) % 3 == 0)
		return
	_showing_modal = false
	# Boss phase signaled by an earlier level-up — _boss_pending will spawn the boss
	# once existing enemies clear (handled in _process).

# ── Boss flow ────────────────────────────────────────────────────────────────

func _spawn_boss() -> void:
	var boss_type: String = _pick_boss_type_for_level()
	_boss_type_name = boss_type
	var boss = ENEMY_SCENES[boss_type].instantiate()
	boss.global_position = _get_spawn_position()
	var lvl: int = int(player.level)
	if "max_health" in boss:
		boss.max_health = int(round(boss.max_health * (1.0 + lvl * 0.03)))
	if "attack_damage" in boss:
		boss.attack_damage = int(round(boss.attack_damage * (1.0 + lvl * 0.02)))
	boss.died.connect(_on_enemy_died.bind(boss_type))
	add_child(boss)
	_boss_instance = boss
	enemies_alive += 1

func _pick_boss_type_for_level() -> String:
	# Boss spawns at level 10, 20, 30, ... — boss_count = level/10.
	var boss_count: int = int(player.level) / 10
	if boss_count <= 0:
		boss_count = 1
	var idx: int = (boss_count - 1) % BOSS_POOL.size()
	return BOSS_POOL[idx]

func _on_boss_died() -> void:
	_boss_phase = false
	_boss_instance = null
	# Heal player fully.
	if player:
		player.current_hp = player.max_hp
		player._update_hp_bar()
	# Advance era — spawn pool switches to the next era starting now.
	_bosses_defeated += 1
	var new_era: int = min(_bosses_defeated + 1, ERAS.size())
	if new_era != _era:
		_era = new_era
		_era_start_level = int(player.level) if player else 1
		_era_start_time = _run_time
	# Wait for any in-progress level-up / perk panel from the boss-kill XP
	# before stacking the shop on top.
	while _showing_modal:
		await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout
	if not is_instance_valid(self):
		return
	_show_shop()

func _show_shop() -> void:
	_in_shop = true
	_showing_modal = true
	var shop = SHOP_SCRIPT.new()
	shop.setup(player)
	if "endless_mode" in shop:
		shop.endless_mode = true
	add_child(shop)
	await shop.shop_closed
	_in_shop = false
	_showing_modal = false

# ── Game over + pause ────────────────────────────────────────────────────────

func _on_player_game_over() -> void:
	_game_over_shown = true
	var screen = GAME_OVER_SCRIPT.new()
	screen.zombies_killed = _kills
	screen.elapsed_time = _run_time
	if "level_reached" in screen:
		screen.level_reached = int(player.level)
	if "perks_taken" in screen:
		screen.perks_taken = player.perks.duplicate()
	add_child(screen)

func _on_xp_changed(current_xp: int, xp_to_next: int) -> void:
	_update_xp_ui(current_xp, xp_to_next)

func _update_xp_ui(current_xp: int, xp_to_next: int) -> void:
	var bar = get_tree().get_first_node_in_group("xp_bar")
	if bar:
		bar.max_value = xp_to_next
		bar.value = current_xp
	var lbl = get_tree().get_first_node_in_group("xp_label")
	if lbl:
		lbl.text = "PD: %d / %d" % [current_xp, xp_to_next]

func _update_level_label() -> void:
	var lbl = get_tree().get_first_node_in_group("level_label")
	if lbl and player:
		lbl.text = "Poziom: %d" % int(player.level)

func _handle_escape() -> void:
	if _in_shop or _game_over_shown or _showing_modal or (player and player.get("is_dying")):
		return
	if is_instance_valid(_pause_menu):
		_pause_menu._on_continue()
	else:
		_pause_menu = PAUSE_MENU_SCRIPT.new()
		_pause_menu.resumed.connect(func(): _pause_menu = null)
		add_child(_pause_menu)
