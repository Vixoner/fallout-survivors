extends "res://scripts/enemy.gd"

const AXE_SCENE = preload("res://scenes/axe_projectile.tscn")
const MINION_SCENE = preload("res://scenes/enemy.tscn")

# Boss banner color palette (matches Pip-Boy / existing UI)
const C_BOSS_BRIGHT := Color(0.42, 1.00, 0.42)

@export var ranged_range: float = 800.0
@export var ranged_cooldown: float = 3.0
@export var summon_interval: float = 8.0

var ranged_timer: float = 0.0
var summon_timer: float = 0.0
var _is_ranged_attacking: bool = false
var _minions: Array = []

var _boss_label: Label = null

func _ready() -> void:
	super._ready()
	_setup_boss_bar()

func _physics_process(delta):
	if is_dead:
		return
	if not player:
		return

	var direction = global_position.direction_to(player.global_position)
	var distance = global_position.distance_to(player.global_position)

	attack_timer += delta
	ranged_timer += delta
	summon_timer += delta
	if summon_timer >= summon_interval:
		summon_timer = 0.0
		_summon_minions()

	if distance < contact_distance:
		if attack_timer >= attack_cooldown and not _is_ranged_attacking:
			play_attack_animation(direction)
			player.take_damage(attack_damage)
			attack_timer = 0.0
	elif distance <= ranged_range and ranged_timer >= _effective_ranged_cooldown() and not _is_ranged_attacking and not is_currently_attacking():
		_start_ranged_attack(direction)
		ranged_timer = 0.0

	if not is_currently_attacking() and not _is_ranged_attacking:
		var move = direction * move_speed + get_separation_force()
		velocity = move
		move_and_slide()
		update_run_animation(direction)

func _start_ranged_attack(direction: Vector2):
	_is_ranged_attacking = true
	sprite.flip_h = false
	if abs(direction.y) > abs(direction.x):
		if direction.y > 0:
			animation_player.play("second_attack_down")
		else:
			animation_player.play("second_attack_up")
	else:
		if direction.x < 0:
			animation_player.play("second_attack_left")
		else:
			animation_player.play("second_attack_right")
	await get_tree().create_timer(0.9 * 0.50, false).timeout
	if not is_instance_valid(self) or is_dead:
		_is_ranged_attacking = false
		return
	_throw_axe(global_position.direction_to(player.global_position))
	await get_tree().create_timer(0.9 * 0.50, false).timeout
	if not is_instance_valid(self) or is_dead:
		_is_ranged_attacking = false
		return
	_is_ranged_attacking = false

func take_damage(amount, is_crit: bool = false):
	super.take_damage(amount, is_crit)
	_update_boss_bar()

func die():
	for minion in _minions:
		if is_instance_valid(minion) and not minion.is_dead:
			minion.die()
	if is_instance_valid(_boss_label):
		_boss_label.visible = false
	super.die()

func _setup_boss_bar() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "BossBarCanvas"
	# Above the gameplay HUD (layer 1) but below the shop (10) / pause (20).
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
	_update_boss_bar()

func _update_boss_bar() -> void:
	if is_instance_valid(_boss_label):
		_boss_label.text = "// BOSS //   %d / %d" % [max(0, health), max_health]

func _health_pct() -> float:
	return clamp(float(health) / float(max_health), 0.0, 1.0)

func _effective_ranged_cooldown() -> float:
	return lerp(1.0, ranged_cooldown, _health_pct())

func _effective_fly_speed() -> float:
	return lerp(1600.0, 800.0, _health_pct())

func _throw_axe(direction: Vector2):
	var axe = AXE_SCENE.instantiate()
	axe.direction = direction
	axe.fly_speed = _effective_fly_speed()
	axe.global_position = global_position
	get_tree().root.get_child(0).add_child(axe)

func _summon_minions():
	var main = get_tree().root.get_child(0)
	for i in 4:
		var angle = (TAU / 4.0) * i
		var zombie = MINION_SCENE.instantiate()
		zombie.global_position = global_position + Vector2(cos(angle), sin(angle)) * 50.0
		zombie.caps_drop_min = 0
		zombie.caps_drop_max = 0
		main.add_child(zombie)
		if randf() < 0.25:
			zombie.make_champion()
		_minions.append(zombie)
