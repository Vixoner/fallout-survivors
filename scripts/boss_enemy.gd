extends "res://scripts/enemy.gd"

const AXE_SCENE = preload("res://scenes/axe_projectile.tscn")
const MINION_SCENE = preload("res://scenes/enemy.tscn")

@export var ranged_range: float = 800.0
@export var ranged_cooldown: float = 3.0
@export var summon_interval: float = 8.0

var ranged_timer: float = 0.0
var summon_timer: float = 0.0
var _is_ranged_attacking: bool = false
var _minions: Array = []

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

func die():
	for minion in _minions:
		if is_instance_valid(minion) and not minion.is_dead:
			minion.die()
	super.die()

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
