extends CharacterBody2D

signal died(position: Vector2)

const SPEED = 300.0
const SEPARATION_RADIUS = 80.0
const SEPARATION_STRENGTH = 180.0
const CONTACT_DISTANCE = 65.0
const DAMAGE = 2

const HIT_SHADER = preload("res://assets/shaders/hit_flash.gdshader")

var health = 100
var player = null
var is_dead: bool = false

var attack_cooldown = 1.0  # Jak często wróg ma zadawać obrażenia
var attack_timer = 0.0

@onready var sprite: Sprite2D = $BodySprite
@onready var animation_player = $AnimationPlayer 

func _ready():
	z_index = 2
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	if is_dead: 
		return
	
	if player:
		var direction = global_position.direction_to(player.global_position)
		var distance = global_position.distance_to(player.global_position)
		attack_timer += delta
		
		# 2. Logika ataku
		if distance < CONTACT_DISTANCE:
			if attack_timer >= attack_cooldown:
				play_attack_animation(direction)
				player.take_damage(DAMAGE)
				attack_timer = 0.0
		
		# 3. Ruch i animacja biegu (tylko gdy nie atakuje)
		if not is_currently_attacking():
			var move = direction * SPEED + get_separation_force()
			velocity = move
			move_and_slide()
			update_run_animation(direction)

		if global_position.distance_to(player.global_position) < CONTACT_DISTANCE:
			player.take_damage(DAMAGE)
			
func is_currently_attacking() -> bool:
	return animation_player.is_playing() and animation_player.current_animation.contains("attack")
	
func play_attack_animation(direction: Vector2):
	if abs(direction.y) > abs(direction.x):
		if direction.y > 0:
			animation_player.play("attack_down")
		else:
			animation_player.play("attack_up")
	else:
		if direction.x < 0:
			animation_player.play("attack_left")
		else:
			animation_player.play("attack_right")
			
# DODANE: Funkcja zarządzająca animacją wroga
func update_run_animation(direction: Vector2):
	if abs(direction.y) > abs(direction.x):
		if direction.y > 0:
			animation_player.play("run_down")
		else:
			animation_player.play("run_up")
	else:
		animation_player.play("run_side")
		sprite.flip_h = direction.x < 0

func get_separation_force() -> Vector2:
	var force = Vector2.ZERO
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self:
			continue
		var diff = global_position - other.global_position
		var dist = diff.length()
		if dist > 0.0 and dist < SEPARATION_RADIUS:
			force += diff.normalized() * (1.0 - dist / SEPARATION_RADIUS) * SEPARATION_STRENGTH
	return force

func take_damage(amount, is_crit: bool = false):
	health -= amount
	flash_hit()
	spawn_damage_number(amount, is_crit)
	if health <= 0:
		die()

func flash_hit():
	var mat = ShaderMaterial.new()
	mat.shader = HIT_SHADER
	sprite.material = mat
	await get_tree().create_timer(0.12).timeout
	if is_instance_valid(sprite):
		sprite.material = null

func spawn_damage_number(amount: int, is_crit: bool = false):
	var label = Label.new()
	label.text = str(amount) + ("!" if is_crit else "")
	label.add_theme_font_size_override("font_size", 32 if is_crit else 22)
	label.add_theme_color_override("font_color", Color(1, 0.35, 0.0) if is_crit else Color(1, 0.9, 0.1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 5 if is_crit else 4)
	label.z_index = 10
	label.position = global_position + Vector2(-16, -60)
	get_tree().root.get_child(0).add_child(label)

	var tween = label.create_tween()
	tween.set_parallel(true)
	var rise = 80 if is_crit else 50
	tween.tween_property(label, "position:y", label.position.y - rise, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)

func die():
	emit_signal("died", global_position)
	$CollisionShape2D.set_deferred("disabled", true)
	set_physics_process(false)
	animation_player.play("death_basic")
	await get_tree().create_timer(2.0).timeout
	queue_free()
