extends CharacterBody2D

const SPEED = 500.0
const MAP_WIDTH = 3000
const MAP_HEIGHT = 2000
const PLAYER_SIZE = 64

var caps: int = 0

func _physics_process(delta):
	var direction = Vector2.ZERO
	
	if Input.is_action_pressed("ui_right"):
		direction.x += 1
	if Input.is_action_pressed("ui_left"):
		direction.x -= 1
	if Input.is_action_pressed("ui_down"):
		direction.y += 1
	if Input.is_action_pressed("ui_up"):
		direction.y -= 1
	
	# Normalizacja żeby ukosem nie szło szybciej
	if direction != Vector2.ZERO:
		direction = direction.normalized()
	
	velocity = direction * SPEED
	move_and_slide()
	
	position.x = clamp(position.x, -MAP_WIDTH / 2 + PLAYER_SIZE, MAP_WIDTH / 2 - PLAYER_SIZE)
	position.y = clamp(position.y, -MAP_HEIGHT / 2 + PLAYER_SIZE, MAP_HEIGHT / 2 - PLAYER_SIZE)
	time_since_last_attack += delta
	if time_since_last_attack >= attack_cooldown:
		var target = get_nearest_enemy()
		if target:
			attack_enemy(target)
			time_since_last_attack = 0.0
	
@onready var attack_range = $AttackRange # Ścieżka do Twojego Area2D
var attack_cooldown = 0.5 # Sekundy między atakami
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
	target.take_damage(50)
	# Tutaj możesz dodać animację pocisku lub błysk
	
func add_caps(amount: int):
	caps += amount
	# Update label'a
	var label = get_tree().get_first_node_in_group("caps_label")
	if label:
		label.text = "Kapsle: " + str(caps)
