extends CharacterBody2D

signal died(position: Vector2)

const SPEED = 300.0
const SEPARATION_RADIUS = 80.0
const SEPARATION_STRENGTH = 180.0

const HIT_SHADER = preload("res://assets/shaders/hit_flash.gdshader")

var health = 100
var player = null

@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	z_index = 2
	player = get_tree().get_first_node_in_group("player")

func _physics_process(_delta):
	if player:
		var direction = global_position.direction_to(player.global_position)
		var move = direction * SPEED + get_separation_force()
		velocity = move
		move_and_slide()

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
	emit_signal("died", global_position)
	queue_free()
