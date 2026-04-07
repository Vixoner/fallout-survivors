extends CharacterBody2D

const SPEED = 500.0
const PLAYER_SIZE = 64

func _ready():
	z_index = 2

var caps: int = 0
var movement_blocked: bool = false

# Statystyki SPECIAL
var strength: int = 5
var perception: int = 5
var endurance: int = 5
var charisma: int = 5
var intelligence: int = 5
var agility: int = 5
var luck: int = 5

func _physics_process(delta):
	if movement_blocked:
		velocity = Vector2.ZERO
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
	
	# Normalizacja żeby ukosem nie szło szybciej
	if direction != Vector2.ZERO:
		direction = direction.normalized()
	
	velocity = direction * SPEED
	move_and_slide()
	
	position.x = clamp(position.x, -GameConstants.MAP_WIDTH / 2 + PLAYER_SIZE, GameConstants.MAP_WIDTH / 2 - PLAYER_SIZE)
	position.y = clamp(position.y, -GameConstants.MAP_HEIGHT / 2 + PLAYER_SIZE, GameConstants.MAP_HEIGHT / 2 - PLAYER_SIZE)
	time_since_last_attack += delta
	if time_since_last_attack >= attack_cooldown:
		var target = get_nearest_enemy()
		if target:
			attack_enemy(target)
			time_since_last_attack = 0.0
	
@onready var attack_range = $AttackRange # Ścieżka do Twojego Area2D
var attack_cooldown = 0.25 # Sekundy między atakami
var time_since_last_attack = 0.0

func get_nearest_enemy():
	var enemies = attack_range.get_overlapping_bodies()
	var nearest_enemy = null
	var shortest_distance = INF 
	
	for body in enemies:
		if body.is_in_group("enemies"):
			# Obliczamy dystans: $$d = \sqrt{(x_2-x_1)^2 + (y_2-y_1)^2}$$
			var distance = global_position.distance_to(body.global_position)
			if distance < shortest_distance:
				shortest_distance = distance
				nearest_enemy = body
  
	return nearest_enemy

func attack_enemy(target):
	# Prosty efekt: "strzał" w konsoli i zadanie obrażeń
	print("Atakuję: ", target.name)
	target.take_damage(40)
	# Tutaj możesz dodać animację pocisku lub błysk
	
func add_caps(amount: int):
	caps += amount
	# Update label'a
	var label = get_tree().get_first_node_in_group("caps_label")
	if label:
		label.text = "Kapsle: " + str(caps)
