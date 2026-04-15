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

var attack_damage = 10
var attack_cooldown = 0.5    
var attack_timer = 0.0
var is_attacking: bool = false
var trigger_distance: float = 65.0

@onready var sprite: Sprite2D = $BodySprite
@onready var animation_player = $AnimationPlayer 
@onready var attack_area: Area2D = $AttackRange
@onready var attack_collision: CollisionShape2D = $AttackRange/AttackCircle

func _ready():
	z_index = 2
	player = get_tree().get_first_node_in_group("player")
	animation_player.animation_finished.connect(_on_animation_finished)
	
func _physics_process(_delta):
	if is_dead:
		return
	attack_timer += _delta
		
	if player:
		var direction = global_position.direction_to(player.global_position)
		var distance_to_player = global_position.distance_to(player.global_position)
		if distance_to_player <= trigger_distance and attack_timer >= attack_cooldown:
			perform_attack(direction)			
		if not is_attacking:
			var move = direction * SPEED + get_separation_force()
			velocity = move
			move_and_slide()
			update_animation(direction)
		
func perform_attack(direction: Vector2):
	is_attacking = true
	attack_timer = 0.0
	if abs(direction.y) > abs(direction.x):
		if direction.y > 0: animation_player.play("attack_down")
		else: animation_player.play("attack_up")
	else:
		if direction.x < 0: animation_player.play("attack_left")
		else: animation_player.play("attack_right")
				
func deal_damage(): 
	var targets = attack_area.get_overlapping_bodies()
	print(player)
	for target in targets:
		print("W zasięgu jest: ", target.name)  
		if target.is_in_group("player"):
			target.take_damage(attack_damage)
			print("Wróg trafił gracza!")
		
func update_movement_animation(direction: Vector2):
	if abs(direction.y) > abs(direction.x):
		if direction.y > 0:
			animation_player.play("run_down")
		else:
			animation_player.play("run_up")
	else:
		animation_player.play("run_side")
		sprite.flip_h = direction.x < 0
		
<<<<<<< HEAD
=======
		update_animation(direction)

		if global_position.distance_to(player.global_position) < CONTACT_DISTANCE:
			player.take_damage(DAMAGE)

# DODANE: Funkcja zarządzająca animacją wroga
>>>>>>> 7e8506a5828b069b082ce2f4a91797b9b84e3c86
func update_animation(direction: Vector2):
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

func take_damage(amount):
	if is_dead:
		return
	
	health -= amount
	flash_hit()
	spawn_damage_number(amount)
	if health <= 0:
		die()

func flash_hit():
	var mat = ShaderMaterial.new()
	mat.shader = HIT_SHADER
	sprite.material = mat
	await get_tree().create_timer(0.12).timeout
	if is_instance_valid(sprite):
		sprite.material = null

func spawn_damage_number(amount: int):
	var label = Label.new()
	label.text = str(amount)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	label.z_index = 10
	label.position = global_position + Vector2(-16, -60)
	get_tree().root.get_child(0).add_child(label)

	var tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 50, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)

func die():
	#emit_signal("died", global_position)
	#queue_free()
	is_dead = true
	emit_signal("died", global_position)
	
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	
	animation_player.play("death_basic")

	
func _on_animation_finished(anim_name: String):
	if anim_name == "death_basic":
		await get_tree().create_timer(5.0).timeout
		queue_free()
	elif anim_name.contains("attack"):
		is_attacking = false
