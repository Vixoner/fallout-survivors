extends CharacterBody2D

signal game_over

const BASE_SPEED = 500.0
const BASE_HP    = 20
const PLAYER_SIZE = 64

@onready var attack_range = $AttackRange
@onready var body_sprite = $BodySprite
@onready var weapon_sprite = $WeaponSprite
@onready var animation_player = $AnimationPlayer
@onready var weapon_anim_player = $WeaponAnimationPlayer

var caps: int = 0
var movement_blocked: bool = false
var is_dying: bool = false

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

# Statystyki SPECIAL
var strength: int = 5
var perception: int = 5
var endurance: int = 5
var charisma: int = 5
var intelligence: int = 5
var agility: int = 5
var luck: int = 5

func _ready():
	z_index = 6
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_apply_class()
	max_hp = get_max_hp()
	current_hp = max_hp
	_update_hp_bar()
	_setup_weapon_manager()

func _apply_class() -> void:
	var cls: Dictionary = GameState.selected_class
	if cls.is_empty():
		return
	var s: Dictionary = cls.get("stats", {})
	strength     = s.get("strength",     strength)
	perception   = s.get("perception",   perception)
	endurance    = s.get("endurance",    endurance)
	charisma     = s.get("charisma",     charisma)
	intelligence = s.get("intelligence", intelligence)
	agility      = s.get("agility",      agility)
	luck         = s.get("luck",         luck)

func _setup_weapon_manager():
	weapon_manager = WeaponManager.new()
	weapon_manager.name = "WeaponManager"
	add_child(weapon_manager)
	weapon_manager.equip(WeaponData.make_pistol())

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			_equip_weapon_by_id("pistol")
		elif event.keycode == KEY_2:
			_equip_weapon_by_id("laser")

func _equip_weapon_by_id(id: String):
	if not is_instance_valid(weapon_manager):
		return
	if weapon_manager.current_weapon and weapon_manager.current_weapon.name.to_lower() == id:
		return
	match id:
		"pistol":
			weapon_manager.equip(WeaponData.make_pistol())
		"laser":
			weapon_manager.equip(WeaponData.make_laser())

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
	#time_since_last_attack += delta
	#if time_since_last_attack >= attack_cooldown:
	#	var target = get_nearest_enemy()
	#	if target:
	#		attack_enemy(target)
	#		time_since_last_attack = 0.0
	
func handle_knife_autoattack(delta):
	knife_timer += delta
	if knife_timer >= knife_cooldown:
		var target = get_nearest_enemy()
		if target:
			var attack_direction = global_position.direction_to(target.global_position)
			
			# Odpalamy animację noża
			play_knife_animation(attack_direction)
			
			# Zadajemy obrażenia
			var is_crit = roll_crit()
			var base_dmg = get_melee_damage()
			var dmg = base_dmg * 2 if is_crit else base_dmg
			target.take_damage(dmg, is_crit)
			
			# Resetujemy tylko stoper noża
			knife_timer = 0.0

func handle_weapon_fire(delta: float):
	if not is_instance_valid(weapon_manager):
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
	return BASE_SPEED + (agility - 5) * 40.0

func get_max_hp() -> int:
	return BASE_HP + (endurance - 5) * 3

func get_damage_reduction() -> float:
	return clamp((endurance - 5) * 0.08, -0.5, 0.5)

func get_attract_radius() -> float:
	return 200.0 + (intelligence - 5) * 25.0

func get_price_mult() -> float:
	return clamp(1.0 - (charisma - 5) * 0.05, 0.4, 1.5)

func get_melee_damage() -> int:
	return 15 + strength * 3  # strength=5 → 40, każdy punkt = +3 dmg

func get_crit_chance() -> float:
	return luck * 0.03  # 3% na punkt, bazowo luck=5 → 15%

func get_ranged_damage_mult() -> float:
	return clamp(1.0 + (perception - 5) * 0.10, 0.5, 2.0)

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
	label.position = global_position + Vector2(-20, -80)
	get_tree().root.get_child(0).add_child(label)

	var tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 55, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)

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
	get_tree().root.get_child(0).add_child(canvas)
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
	var label = get_tree().get_first_node_in_group("caps_label")
	if label:
		label.text = "Kapsle: " + str(caps)
