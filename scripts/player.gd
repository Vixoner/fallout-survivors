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
const STAT_CAP_ENDLESS := 99
const SPEED_CAP_ENDLESS := 600.0

func _ready():
	z_index = 6
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_apply_class()
	max_hp = get_max_hp()
	current_hp = max_hp
	_update_hp_bar()
	_setup_weapon_manager()

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
	_update_grenades_ui()

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
	if cur >= STAT_CAP_ENDLESS:
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
	# Endless lets the player pick a starting weapon; story always starts with pistol.
	var starting: String = "pistol"
	if _endless_mode and GameState.endless_starting_weapon != "":
		starting = GameState.endless_starting_weapon
	weapon_manager.equip(_build_weapon_data(starting))

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
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			_equip_weapon_by_id("pistol")
		elif event.keycode == KEY_2:
			_equip_weapon_by_id("laser")
		elif event.keycode == KEY_3:
			_equip_weapon_by_id("plasma")
		elif event.keycode == KEY_4:
			_equip_weapon_by_id("shotgun")
		elif event.keycode == KEY_G:
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
	if id in ["pistol", "laser", "plasma", "shotgun"]:
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
	
	position.x = clamp(position.x, -GameConstants.MAP_WIDTH / 2.0 + PLAYER_SIZE, GameConstants.MAP_WIDTH / 2.0 - PLAYER_SIZE)
	position.y = clamp(position.y, -GameConstants.MAP_HEIGHT / 2.0 + PLAYER_SIZE, GameConstants.MAP_HEIGHT / 2.0 - PLAYER_SIZE)
	
	
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
			
			# Resetujemy tylko stoper noża
			knife_timer = 0.0

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
	
func get_move_speed() -> float:
	if _endless_mode:
		var raw_speed: float = min(SPEED_CAP_ENDLESS, 400.0 + (agility - 1) * 10.0)
		if has_perk("lekka_stopa"):
			raw_speed *= 1.2
		return raw_speed
	return BASE_SPEED + (agility - 5) * 40.0

func get_max_hp() -> int:
	if _endless_mode:
		return BASE_HP + (endurance - 1) * 2
	return BASE_HP + (endurance - 5) * 3

func get_damage_reduction() -> float:
	if _endless_mode:
		var dr: float = clamp((endurance - 1) * 0.008, 0.0, 0.75)
		if has_perk("twardziel"):
			dr = min(0.90, dr + 0.15)
		return dr
	return clamp((endurance - 5) * 0.08, -0.5, 0.5)

func get_attract_radius() -> float:
	if _endless_mode:
		return 150.0 + (intelligence - 1) * 15.0
	return 200.0 + (intelligence - 5) * 25.0

func get_price_mult() -> float:
	if _endless_mode:
		return clamp(1.0 - (charisma - 1) * 0.01, 0.3, 1.5)
	return clamp(1.0 - (charisma - 5) * 0.05, 0.4, 1.5)

func get_melee_damage() -> int:
	var base: float
	if _endless_mode:
		base = 10.0 + strength * 2.5
	else:
		base = 15.0 + strength * 3.0
	if has_perk("rzeznik"):
		base *= 1.30
	return int(round(base))

func get_crit_chance() -> float:
	if _endless_mode:
		return clamp(luck * 0.005, 0.0, 0.5)
	return luck * 0.03

func get_ranged_damage_mult() -> float:
	var mult: float
	if _endless_mode:
		mult = clamp(1.0 + (perception - 1) * 0.025, 1.0, 3.5)
	else:
		mult = clamp(1.0 + (perception - 5) * 0.10, 0.5, 2.0)
	if has_perk("strzelec_wyborowy"):
		mult *= 1.25
	return mult

# Multiplier used when a crit lands. Lepsze Krytyki bumps from 2× to 3×.
func get_crit_mult() -> float:
	return 3.0 if has_perk("lepsze_krytyki") else 2.0

# Endless only: chance to fully dodge an incoming hit. 0 in story.
func get_dodge_chance() -> float:
	if not _endless_mode:
		return 0.0
	return clamp((agility - 1) * 0.003, 0.0, 0.25)

func roll_crit() -> bool:
	return randf() < get_crit_chance()

func recalculate_stats():
	var new_max = get_max_hp()
	var diff = new_max - max_hp
	max_hp = new_max
	current_hp = clamp(current_hp + diff, 1, max_hp)
	_update_hp_bar()

func take_damage(amount: int):
	if invincible or is_dying:
		return
	# Endless: agility-based dodge — full skip of incoming hit.
	if _endless_mode and randf() < get_dodge_chance():
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
