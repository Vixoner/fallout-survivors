extends CharacterBody2D

signal game_over
# Endless-mode signals — story mode never emits these.
signal xp_changed(xp: int, xp_to_next: int)
signal level_up_triggered(new_level: int, points_to_spend: int, show_perk_panel: bool, boss_phase: bool)

const BASE_SPEED = 500.0
const BASE_HP    = 20
const PLAYER_SIZE = 64
const BASE_GRENADE_CAP = 4

@onready var attack_range = $AttackRange
@onready var body_sprite = $BodySprite
@onready var weapon_sprite = $WeaponSprite
@onready var animation_player = $AnimationPlayer
@onready var weapon_anim_player = $WeaponAnimationPlayer

var caps: int = 0
var movement_blocked: bool = false
var is_dying: bool = false
var melee_locked: bool   = false
var ranged_locked: bool  = false
var grenade_locked: bool = false

var max_hp: int = 20
var current_hp: int = 20
var invincible: bool = false
const INVINCIBILITY_DURATION = 1.0
var _blink_tween: Tween = null
var attack_cooldown = 0.25 

#var time_since_last_attack = 0.0 Narazie zbędne, jak dodamy więcej broni to wróci
#var current_weapon: String = "none"
var knife_cooldown = 0.5 
var knife_timer = 0.0

var last_direction = "down"

var weapon_manager: WeaponManager = null

var _map_half_w: float = GameConstants.MAP_WIDTH / 2.0
var _map_half_h: float = GameConstants.MAP_HEIGHT / 2.0

const FRAG_GRENADE_SCRIPT := preload("res://scripts/frag_grenade.gd")
const GRENADE_THROW_COOLDOWN := 0.35
const MAX_THROW_RANGE := 900.0

var grenades: Dictionary = {"frag": 0}
var _grenade_throw_timer: float = 0.0

# Statystyki SPECIAL — story defaults to 5 each; endless starts all at 1.
var strength: int = 5
var perception: int = 5
var endurance: int = 5
var charisma: int = 5
var intelligence: int = 5
var agility: int = 5
var luck: int = 5

# ── Endless-mode state ────────────────────────────────────────────────────────
var _endless_mode: bool = false
var xp: int = 0
var level: int = 1
var xp_to_next: int = 150  # 100 + 50 * level
var pending_stat_points: int = 0
var perks: Array[String] = []
var weapon_upgrades: Array[String] = []
const STAT_CAP  := 99      # max value for any SPECIAL stat (both modes)
const SPEED_CAP := 600.0   # max movement speed in pixels/sec (both modes)

# Cached so perks scaling AttackRange always multiply against the .tscn baseline.
var _attack_range_base_scale: Vector2 = Vector2.ONE

func _ready():
	z_index = 6
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# Snapshot the AttackRange's CollisionShape2D base scale before any perk
	# tweaks it — used as the multiplier base for "Ale mam wielkiego kija" etc.
	if is_instance_valid(attack_range):
		var col := attack_range.get_node_or_null("CollisionShape2D")
		if col != null:
			_attack_range_base_scale = col.scale
	_apply_class()
	max_hp = get_max_hp()
	current_hp = max_hp
	_update_hp_bar()
	_setup_weapon_manager()
	_apply_melee_range_perks()

# Resize AttackRange's CollisionShape2D based on owned perks. Called from
# _ready after class is applied, and from add_perk so endless picks apply live.
func _apply_melee_range_perks() -> void:
	if not is_instance_valid(attack_range):
		return
	var col := attack_range.get_node_or_null("CollisionShape2D")
	if col == null:
		return
	var multiplier := 1.0
	if has_perk("wielki_kij"):
		multiplier *= 1.5
	col.scale = _attack_range_base_scale * multiplier

func _apply_class() -> void:
	# Endless overrides classes entirely — all SPECIAL start at 1, no starting grenades.
	if GameState.endless_mode:
		_endless_mode = true
		strength = 1
		perception = 1
		endurance = 1
		charisma = 1
		intelligence = 1
		agility = 1
		luck = 1
		xp = 0
		level = 1
		xp_to_next = 100 + 50 * level
		pending_stat_points = 0
		perks = []
		grenades = {"frag": 0}
		_update_grenades_ui()
		return
	var cls: Dictionary = GameState.selected_class
	if cls.is_empty():
		_update_grenades_ui()
		return
	var s: Dictionary = cls.get("stats", {})
	strength     = s.get("strength",     strength)
	perception   = s.get("perception",   perception)
	endurance    = s.get("endurance",    endurance)
	charisma     = s.get("charisma",     charisma)
	intelligence = s.get("intelligence", intelligence)
	agility      = s.get("agility",      agility)
	luck         = s.get("luck",         luck)
	var starting_grenades: Dictionary = cls.get("starting_grenades", {})
	for gtype in starting_grenades:
		grenades[gtype] = clamp(int(starting_grenades[gtype]), 0, get_grenade_cap())
	# Class-granted perks (e.g. Raider → ooga_booga). Bypass requirement checks
	# since these are intentionally part of the class identity.
	for perk_id in cls.get("starting_perks", []):
		if not perk_id in perks:
			perks.append(perk_id)
	# Persisted stats from a previous map (map 1 → map 2 handoff) override
	# class defaults. Cleared after use so a fresh map 1 run starts clean.
	_apply_persisted_stats()
	_update_grenades_ui()

func _apply_persisted_stats() -> void:
	if GameState.persisted_stats.is_empty():
		return
	var p: Dictionary = GameState.persisted_stats
	strength     = int(p.get("strength",     strength))
	perception   = int(p.get("perception",   perception))
	endurance    = int(p.get("endurance",    endurance))
	charisma     = int(p.get("charisma",     charisma))
	intelligence = int(p.get("intelligence", intelligence))
	agility      = int(p.get("agility",      agility))
	luck         = int(p.get("luck",         luck))
	caps         = int(p.get("caps", caps))
	var pg: Dictionary = p.get("grenades", {})
	for gtype in pg:
		grenades[gtype] = clamp(int(pg[gtype]), 0, get_grenade_cap())
	# Use-once — clear so re-entering map 1 (e.g. after dying on map 2) starts fresh.
	GameState.persisted_stats = {}
	# Refresh caps label since add_caps wasn't called.
	var label = get_tree().get_first_node_in_group("caps_label")
	if label:
		label.text = "Kapsle: " + str(caps)

# ── Endless XP / level-up plumbing ────────────────────────────────────────────
# Called by endless.gd whenever an enemy dies. Amount already includes
# per-enemy XP value and any Psychopath multiplier.
func add_xp(amount: int) -> void:
	if not _endless_mode or is_dying:
		return
	xp += amount
	while xp >= xp_to_next:
		xp -= xp_to_next
		_level_up()
	emit_signal("xp_changed", xp, xp_to_next)

func _level_up() -> void:
	level += 1
	pending_stat_points += 5
	xp_to_next = 100 + 50 * level
	# Full heal on level-up. Recompute max in case endurance just changed
	# (though normally stats change after the panel opens — this is a safety net).
	max_hp = get_max_hp()
	current_hp = max_hp
	_update_hp_bar()
	var show_perk: bool = (level % 3 == 0)
	var boss_phase: bool = (level % 10 == 0)
	emit_signal("level_up_triggered", level, 5, show_perk, boss_phase)

# Spend a single allocated point. Returns true if applied.
func spend_stat_point(stat: String) -> bool:
	if pending_stat_points <= 0:
		return false
	if not stat in ["strength", "perception", "endurance", "charisma", "intelligence", "agility", "luck"]:
		return false
	var cur: int = get(stat)
	if cur >= STAT_CAP:
		return false
	set(stat, cur + 1)
	pending_stat_points -= 1
	recalculate_stats()
	return true

# Refund an unconfirmed allocation (used by the panel's − button).
func refund_stat_point(stat: String, baseline: int) -> bool:
	var cur: int = get(stat)
	if cur <= baseline:
		return false
	set(stat, cur - 1)
	pending_stat_points += 1
	recalculate_stats()
	return true

func add_perk(perk_id: String) -> void:
	if perk_id in perks:
		return
	perks.append(perk_id)
	# Some perks change passive values immediately.
	recalculate_stats()
	# Auto-attack range perks resize AttackRange now so the buff is live.
	if perk_id == "wielki_kij":
		_apply_melee_range_perks()
	# Pistol fire-rate halving via Desperado applies on next equip — re-equip
	# now to apply instantly if pistol is currently held.
	if perk_id == "desperado" and is_instance_valid(weapon_manager):
		var cw = weapon_manager.current_weapon
		if cw != null and str(cw.name).to_lower() == "pistol":
			weapon_manager.equip(_build_weapon_data("pistol"))

func has_perk(perk_id: String) -> bool:
	return perk_id in perks

func has_weapon_upgrade(id: String) -> bool:
	return id in weapon_upgrades

func add_weapon_upgrade(id: String) -> void:
	if id in weapon_upgrades:
		return
	weapon_upgrades.append(id)
	# Re-equip the currently held weapon to pick up the new modifiers (if it's
	# the same kind the upgrade applies to).
	if is_instance_valid(weapon_manager) and weapon_manager.current_weapon:
		var cur_id: String = str(weapon_manager.current_weapon.name).to_lower()
		weapon_manager.equip(_build_weapon_data(cur_id))

# Endless: called by endless.gd on every enemy kill for Wampir.
func on_enemy_killed(_enemy_type: String) -> void:
	if has_perk("wampir") and current_hp < int(max_hp * 0.5):
		current_hp = min(current_hp + 1, max_hp)
		_update_hp_bar()

func get_grenade_cap() -> int:
	return BASE_GRENADE_CAP + (2 if has_perk("hodowca_granatow") else 0)

func _setup_weapon_manager():
	weapon_manager = WeaponManager.new()
	weapon_manager.name = "WeaponManager"
	add_child(weapon_manager)
	# Slot 1 is always pistol (story + endless). Endless's chosen weapon
	# (slot 2) only equips when KEY_2 is pressed.
	weapon_manager.equip(_build_weapon_data("pistol"))

# Builds a WeaponData instance for the given id and applies any active perks
# + endless weapon upgrades that modify weapon parameters.
func _build_weapon_data(id: String) -> WeaponData:
	var w: WeaponData = null
	match id:
		"pistol":
			w = WeaponData.make_pistol()
			if has_perk("desperado"):
				w.fire_rate *= 0.5
			if has_weapon_upgrade("pistol_long_barrel"):
				w.bullet_speed *= 1.3
				w.damage = int(round(w.damage * 1.25))
			if has_weapon_upgrade("pistol_magnum"):
				w.damage = int(round(w.damage * 1.5))
				w.fire_rate *= 1.4
		"karabin":
			w = WeaponData.make_karabin()
			# Desperado is pistol-only by design — karabin doesn't benefit from it.
			# Karabin has its OWN upgrade path distinct from the pistol's.
			if has_weapon_upgrade("karabin_drum_mag"):
				w.fire_rate *= 0.7  # ~43% szybszy: 0.20s → 0.14s
			if has_weapon_upgrade("karabin_ap_rounds"):
				w.damage = int(round(w.damage * 1.4))
				w.bullet_speed *= 0.8
			# Mutually exclusive: explosive vs poison ammo.
			if has_weapon_upgrade("karabin_explosive"):
				w.damage = int(round(w.damage * 1.25))
				w.explosive = true
			elif has_weapon_upgrade("karabin_poison"):
				w.poison = true
		"laser":
			w = WeaponData.make_laser()
			if has_weapon_upgrade("laser_focused"):
				w.beam_length *= 2.0
				w.damage = int(round(w.damage * 1.25))
				w.beam_width *= 0.6
			if has_weapon_upgrade("laser_splitter"):
				w.splitter = true
		"plasma":
			w = WeaponData.make_plasma()
			if has_weapon_upgrade("plasma_stabilizer"):
				w.damage = 110
				w.bullet_speed *= 1.3
			if has_weapon_upgrade("plasma_sticky"):
				w.dot_radius = 160.0
				w.dot_duration = 4.0
				w.dot_slow = 0.5
		"shotgun":
			w = WeaponData.make_shotgun()
			if has_weapon_upgrade("shotgun_choke"):
				w.spread_angle = 0.31  # ~18°
				w.damage = int(round(w.damage * 1.35))
			if has_weapon_upgrade("shotgun_autoload"):
				w.fire_rate = 0.6
				w.projectile_count = 8
		_:
			w = WeaponData.make_pistol()
	return w

func _input(event):
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var kc: int = event.keycode
	# Weapon switching:
	#   - Story:   keys 1–4 give pistol / laser / plasma / shotgun (full arsenal).
	#   - Endless: only key 1 (pistol) and key 2 (weapon picked at startup);
	#             keys 3/4 are no-ops because the player doesn't own those weapons.
	if _endless_mode:
		if kc == KEY_1:
			_equip_weapon_by_id("pistol")
		elif kc == KEY_2:
			var chosen: String = GameState.endless_starting_weapon
			if chosen != "":
				_equip_weapon_by_id(chosen)
	else:
		if kc == KEY_1:
			_equip_weapon_by_id("pistol")
		elif kc == KEY_2:
			_equip_weapon_by_id("laser")
		elif kc == KEY_3:
			_equip_weapon_by_id("plasma")
		elif kc == KEY_4:
			_equip_weapon_by_id("shotgun")
	# Grenade throw — same in both modes.
	if kc == KEY_G:
		if not movement_blocked and not is_dying and not grenade_locked:
			_throw_grenade("frag")

func _throw_grenade(grenade_type: String) -> void:
	if _grenade_throw_timer > 0.0:
		return
	if int(grenades.get(grenade_type, 0)) <= 0:
		return
	var target := get_global_mouse_position()
	var to_target := target - global_position
	if to_target.length() > MAX_THROW_RANGE:
		target = global_position + to_target.normalized() * MAX_THROW_RANGE
	grenades[grenade_type] = int(grenades[grenade_type]) - 1
	_grenade_throw_timer = GRENADE_THROW_COOLDOWN
	_update_grenades_ui()
	match grenade_type:
		"frag":
			var g = FRAG_GRENADE_SCRIPT.new()
			g.setup(global_position, target)
			get_tree().current_scene.add_child(g)

func add_grenade(grenade_type: String, amount: int) -> int:
	# Returns how many were actually added after clamping to grenade cap.
	var cur := int(grenades.get(grenade_type, 0))
	var new_val: int = clamp(cur + amount, 0, get_grenade_cap())
	var added := new_val - cur
	grenades[grenade_type] = new_val
	_update_grenades_ui()
	return added

func _update_grenades_ui() -> void:
	if not is_inside_tree():
		return
	var label = get_tree().get_first_node_in_group("grenades_label")
	if label:
		label.text = "Granaty: %d / %d" % [int(grenades.get("frag", 0)), get_grenade_cap()]

func _equip_weapon_by_id(id: String):
	if not is_instance_valid(weapon_manager):
		return
	if weapon_manager.current_weapon and weapon_manager.current_weapon.name.to_lower() == id:
		return
	if id in ["pistol", "karabin", "laser", "plasma", "shotgun"]:
		weapon_manager.equip(_build_weapon_data(id))

func _physics_process(delta):
	if movement_blocked:
		velocity = Vector2.ZERO
		if not is_dying:
			play_idle_animation()
		return

	var direction = Vector2.ZERO

	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1
	
	if direction != Vector2.ZERO:
		direction = direction.normalized()
		update_animation_and_direction(direction)
	else:
		play_idle_animation()
		
	velocity = direction * get_move_speed()
	move_and_slide()
	
	position.x = clamp(position.x, -_map_half_w + PLAYER_SIZE, _map_half_w - PLAYER_SIZE)
	position.y = clamp(position.y, -_map_half_h + PLAYER_SIZE, _map_half_h - PLAYER_SIZE)
	
	
	handle_knife_autoattack(delta)
	handle_weapon_fire(delta)
	if _grenade_throw_timer > 0.0:
		_grenade_throw_timer = max(0.0, _grenade_throw_timer - delta)
	#time_since_last_attack += delta
	#if time_since_last_attack >= attack_cooldown:
	#	var target = get_nearest_enemy()
	#	if target:
	#		attack_enemy(target)
	#		time_since_last_attack = 0.0
	
func handle_knife_autoattack(delta):
	knife_timer += delta
	if melee_locked:
		return
	if knife_timer >= knife_cooldown:
		var target = get_nearest_enemy()
		if target:
			var attack_direction = global_position.direction_to(target.global_position)
			
			# Odpalamy animację noża
			play_knife_animation(attack_direction)
			
			# Zadajemy obrażenia
			var is_crit = roll_crit()
			var base_dmg = get_melee_damage()
			var dmg = int(round(base_dmg * get_crit_mult())) if is_crit else base_dmg
			target.take_damage(dmg, is_crit)

			# Ooga Booga — atak AoE wokół trafionego wroga, 50% dmg, ~120 px.
			if has_perk("ooga_booga"):
				_apply_ooga_booga_aoe(target, target.global_position, dmg)

			# Resetujemy tylko stoper noża
			knife_timer = 0.0

func _apply_ooga_booga_aoe(primary_target: Node, center: Vector2, primary_dmg: int) -> void:
	const AOE_RADIUS := 120.0
	var aoe_damage: int = int(round(primary_dmg * 0.5))
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy == primary_target:
			continue
		if center.distance_to(enemy.global_position) > AOE_RADIUS:
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(aoe_damage, false)
	# Krótki, brązowy pierścień wokół trafionego wroga jako feedback.
	var fx := Node2D.new()
	fx.global_position = center
	fx.z_index = 4
	get_tree().current_scene.add_child(fx)
	var ring := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 24:
		var a: float = TAU * float(i) / 24.0
		pts.append(Vector2(cos(a), sin(a)) * AOE_RADIUS)
	ring.polygon = pts
	ring.color = Color(0.85, 0.55, 0.25, 0.45)
	ring.scale = Vector2(0.25, 0.25)
	fx.add_child(ring)
	var tw := fx.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(1.0, 1.0), 0.28)
	tw.tween_property(ring, "modulate:a", 0.0, 0.28)
	tw.chain().tween_callback(fx.queue_free)

func handle_weapon_fire(delta: float):
	if not is_instance_valid(weapon_manager):
		return
	if ranged_locked:
		weapon_manager.tick(delta)
		return
	weapon_manager.tick(delta)
	if not weapon_manager.can_fire():
		return
	var aim_dir = global_position.direction_to(get_global_mouse_position())
	if aim_dir == Vector2.ZERO:
		return
	weapon_manager.fire(aim_dir)

# Zmiana nazwy funkcji dla porządku
func play_knife_animation(direction: Vector2):
	if abs(direction.y) > abs(direction.x):
		if direction.y > 0:
			weapon_anim_player.play("bat_attack_down")
		else:
			weapon_anim_player.play("bat_attack_up")
	else:
		if direction.x < 0:
			weapon_anim_player.play("bat_attack_side")
		else:
			weapon_anim_player.play("bat_attack_right")
# Funkcja zarządzająca ruchem
func update_animation_and_direction(direction: Vector2):
	if direction.y > 0:
		animation_player.play("run_down")
		last_direction = "down"
	elif direction.y < 0:
		animation_player.play("run_up")
		last_direction = "up"
	elif direction.x != 0:
		animation_player.play("run_side")
		last_direction = "side"
		
		
		var is_flipped = direction.x < 0
		body_sprite.flip_h = is_flipped
		weapon_sprite.flip_h = is_flipped

# Funkcja od stania w miejscu
func play_idle_animation():
	if last_direction == "down":
		animation_player.play("idle_down")
	elif last_direction == "up":
		animation_player.play("idle_up")
	elif last_direction == "side":
		animation_player.play("idle_side")

func get_nearest_enemy():
	var enemies = attack_range.get_overlapping_bodies()
	var nearest_enemy = null
	var shortest_distance = INF 
	
	for body in enemies:
		if body.is_in_group("enemies"):
			var distance = global_position.distance_to(body.global_position)
			if distance < shortest_distance:
				shortest_distance = distance
				nearest_enemy = body
  
	return nearest_enemy

#func attack_enemy(target):
	#print("Atakuję: ", target.name)
	#target.take_damage(40)
	
# SPECIAL → effect getters. Formulas unified across story + endless.
# Caps (STAT_CAP, SPEED_CAP) apply everywhere; perks add their effect on top
# only when owned (story players never own perks, so it's a no-op there).

func get_move_speed() -> float:
	var raw_speed: float = min(SPEED_CAP, 400.0 + (agility - 1) * 10.0)
	if has_perk("lekka_stopa"):
		raw_speed *= 1.2
	return raw_speed

func get_max_hp() -> int:
	return BASE_HP + (endurance - 1) * 2

func get_damage_reduction() -> float:
	var dr: float = clamp((endurance - 1) * 0.008, 0.0, 0.75)
	if has_perk("twardziel"):
		dr = min(0.90, dr + 0.15)
	return dr

func get_attract_radius() -> float:
	return 150.0 + (intelligence - 1) * 15.0

func get_price_mult() -> float:
	return clamp(1.0 - (charisma - 1) * 0.01, 0.3, 1.5)

func get_melee_damage() -> int:
	var base: float = 10.0 + strength * 2.5
	if has_perk("rzeznik"):
		base *= 1.30
	if has_perk("ooga_booga"):
		base *= 1.25
	return int(round(base))

func get_crit_chance() -> float:
	return clamp(luck * 0.005, 0.0, 0.5)

func get_ranged_damage_mult() -> float:
	var mult: float = clamp(1.0 + (perception - 1) * 0.025, 1.0, 3.5)
	if has_perk("strzelec_wyborowy"):
		mult *= 1.25
	return mult

# Multiplier used when a crit lands. Lepsze Krytyki bumps from 2× to 3×.
func get_crit_mult() -> float:
	return 3.0 if has_perk("lepsze_krytyki") else 2.0

# Agility-based dodge — applied in take_damage as a full skip. Works in both
# modes (was endless-only before unification).
func get_dodge_chance() -> float:
	return clamp((agility - 1) * 0.003, 0.0, 0.25)

func roll_crit() -> bool:
	return randf() < get_crit_chance()

func set_map_bounds(width: float, height: float) -> void:
	_map_half_w = width / 2.0
	_map_half_h = height / 2.0
	var cam := $Camera2D as Camera2D
	cam.limit_left   = -int(width)
	cam.limit_right  =  int(width)
	cam.limit_top    = -int(height)
	cam.limit_bottom =  int(height)

func recalculate_stats():
	var new_max = get_max_hp()
	var diff = new_max - max_hp
	max_hp = new_max
	current_hp = clamp(current_hp + diff, 1, max_hp)
	_update_hp_bar()

func take_damage(amount: int):
	if invincible or is_dying:
		return
	# Agility-based dodge — full skip of incoming hit. Works in both modes.
	if randf() < get_dodge_chance():
		_spawn_dodge_indicator()
		return
	var reduction = get_damage_reduction()
	var final_amount = max(1, int(round(amount * (1.0 - reduction))))
	current_hp -= final_amount
	current_hp = max(0, current_hp)
	_update_hp_bar()
	_spawn_damage_number(final_amount)
	if current_hp <= 0:
		_die()
		return
	invincible = true
	_start_blink()
	await get_tree().create_timer(INVINCIBILITY_DURATION).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return
	invincible = false
	_stop_blink()

func _start_blink():
	if _blink_tween:
		_blink_tween.kill()
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_property(self, "modulate:a", 0.15, 0.07)
	_blink_tween.tween_property(self, "modulate:a", 1.0,  0.07)

func _stop_blink():
	if _blink_tween:
		_blink_tween.kill()
		_blink_tween = null
	modulate.a = 1.0

func _update_hp_bar():
	var bar = get_tree().get_first_node_in_group("hp_bar")
	if bar:
		bar.max_value = max_hp
		bar.value = current_hp
	var label = get_tree().get_first_node_in_group("hp_label")
	if label:
		label.text = "%d / %d" % [current_hp, max_hp]

func _spawn_damage_number(amount: int):
	var label = Label.new()
	label.text = "-%d" % amount
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(1, 0.15, 0.15))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 5)
	label.z_index = 10
	label.position = global_position + Vector2(-20 + randf_range(-10, 10), -80 + randf_range(-10, 10))
	get_tree().root.get_child(0).add_child(label)

	var tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 55, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)

func _spawn_dodge_indicator() -> void:
	# Endless-only feedback when an agility-dodge skips a hit.
	var label = Label.new()
	label.text = "UNIK"
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.95))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 5)
	label.z_index = 10
	label.position = global_position + Vector2(-24, -80)
	get_tree().root.get_child(0).add_child(label)
	var tw = label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 50, 0.6)
	tw.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.15)
	tw.chain().tween_callback(label.queue_free)

func _die():
	if is_dying:
		return
	is_dying = true
	movement_blocked = true
	invincible = true
	_stop_blink()
	weapon_sprite.visible = false

	if body_sprite.flip_h:
		animation_player.play("death_left")
	else:
		animation_player.play("death_right")

	await animation_player.animation_finished
	if not is_instance_valid(self) or not is_inside_tree():
		return

	var canvas = CanvasLayer.new()
	canvas.layer = 100
	get_tree().current_scene.add_child(canvas)
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(overlay)

	var tween = overlay.create_tween()
	tween.tween_property(overlay, "color:a", 1.0, 1.5)
	await tween.finished
	game_over.emit()

func add_caps(amount: int):
	caps += amount
	if not is_inside_tree():
		return
	var label = get_tree().get_first_node_in_group("caps_label")
	if label:
		label.text = "Kapsle: " + str(caps)
