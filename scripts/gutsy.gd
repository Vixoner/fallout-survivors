extends CharacterBody2D

# Floater — ranged enemy. Hovers at a preferred distance from the player and
# fires a single slow gooey ball aimed at the player on a cooldown. No animations,
# no melee attack. Death is a fade-out (no death animation either).

signal died(position: Vector2, caps_count: int)

const HIT_SHADER := preload("res://assets/shaders/hit_flash.gdshader")
const BALL_SCENE := preload("res://scenes/gutsy_projectile.tscn")
const SEPARATION_RADIUS := 100.0
const SEPARATION_STRENGTH := 140.0

@export var max_health: int = 160.0
@export var move_speed: float = 160.0
@export var preferred_distance: float = 450.0
@export var distance_band: float = 80.0  # tolerance around preferred_distance
@export var attack_cooldown: float = 2.6
@export var ball_damage: int = 15
@export var ball_speed: float = 300.0
@export var caps_drop_min: int = 8
@export var caps_drop_max: int = 16
@export var attack_sound: AudioStream
@export var death_sound: AudioStream

var health: int
var player = null
var is_dead: bool = false
var attack_timer: float = 0.0
var _champion_tween: Tween = null

@onready var sprite: Sprite2D = $BodySprite

func _ready() -> void:
	z_index = 5
	process_mode = Node.PROCESS_MODE_PAUSABLE
	health = max_health
	player = get_tree().get_first_node_in_group("player")
	# Stagger initial cooldown so a wave of floaters doesn't fire in sync.
	attack_timer = randf_range(0.0, attack_cooldown * 0.6)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if player == null or not is_instance_valid(player):
		return

	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()
	var dir: Vector2 = Vector2.ZERO

	# Hover at preferred_distance ± distance_band. If too close, back away.
	# If too far, drift in. Within the band, stand still.
	var fleeing: bool = player.get("is_dying")
	if fleeing:
		dir = -to_player.normalized()
	elif dist > preferred_distance + distance_band:
		dir = to_player.normalized()
	elif dist < preferred_distance - distance_band:
		dir = -to_player.normalized()

	velocity = dir * move_speed + _get_separation_force()
	move_and_slide()

	attack_timer += delta
	if not fleeing and attack_timer >= attack_cooldown:
		attack_timer = 0.0
		_shoot_at_player()

func _shoot_at_player() -> void:
	# Safety check in case the player gets destroyed right as we fire
	if player == null or not is_instance_valid(player):
		return

	_play_sfx_2d(attack_sound)
	var scene_root := get_tree().current_scene
	
	var ball = BALL_SCENE.instantiate()
	ball.global_position = global_position
	
	# Aim the projectile directly at the player
	ball.look_at(player.global_position)
	
	if "speed" in ball:
		ball.speed = ball_speed
	if "damage" in ball:
		ball.damage = ball_damage
		
	scene_root.add_child(ball)

func _get_separation_force() -> Vector2:
	var force := Vector2.ZERO
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self:
			continue
		var diff: Vector2 = global_position - other.global_position
		var d: float = diff.length()
		if d > 0.0 and d < SEPARATION_RADIUS:
			force += diff.normalized() * (1.0 - d / SEPARATION_RADIUS) * SEPARATION_STRENGTH
	return force

func take_damage(amount: int, is_crit: bool = false) -> void:
	if is_dead:
		return
	health -= amount
	flash_hit()
	spawn_damage_number(amount, is_crit)
	if health <= 0:
		die()

func flash_hit() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = HIT_SHADER
	sprite.material = mat
	await get_tree().create_timer(0.12).timeout
	if is_instance_valid(sprite):
		sprite.material = null

func spawn_damage_number(amount: int, is_crit: bool = false) -> void:
	var label := Label.new()
	label.text = str(amount) + ("!" if is_crit else "")
	label.add_theme_font_size_override("font_size", 32 if is_crit else 22)
	label.add_theme_color_override("font_color", Color(1, 0.35, 0.0) if is_crit else Color(1, 0.9, 0.1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 5 if is_crit else 4)
	label.z_index = 10
	label.position = global_position + Vector2(-16, -60)
	get_tree().root.get_child(0).add_child(label)

	var tween := label.create_tween()
	tween.set_parallel(true)
	var rise: int = 80 if is_crit else 50
	tween.tween_property(label, "position:y", label.position.y - rise, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)

func make_champion() -> void:
	max_health = int(max_health * 2.0)
	health = max_health
	ball_damage = int(ball_damage * 2.0)
	attack_cooldown *= 0.75
	caps_drop_min = int(caps_drop_min * 1.3)
	caps_drop_max = int(caps_drop_max * 1.3)
	scale *= 1.15
	_champion_tween = create_tween().set_loops()
	_champion_tween.tween_property(self, "modulate", Color(1.9, 0.25, 0.25), 0.45)
	_champion_tween.tween_property(self, "modulate", Color(1.3, 0.55, 0.55), 0.45)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	emit_signal("died", global_position, randi_range(caps_drop_min, caps_drop_max))
	z_index = 3
	$CollisionShape2D.set_deferred("disabled", true)
	set_physics_process(false)
	if _champion_tween:
		_champion_tween.kill()
		_champion_tween = null
	_play_sfx_2d(death_sound)
	# No death animation — just fade out.
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	await tween.finished
	queue_free()

func _play_sfx_2d(stream: AudioStream) -> void:
	if stream == null:
		return
	var p := AudioStreamPlayer2D.new()
	p.bus = "SFX"
	p.stream = stream
	p.autoplay = true
	p.global_position = global_position
	p.finished.connect(p.queue_free)
	get_tree().current_scene.add_child(p)
