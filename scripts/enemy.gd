extends CharacterBody2D

# Przeciwnik musi być wolniejszy od gracza
const SPEED = 300.0 
var health = 100
var player = null

func _ready():
	# Szukamy gracza w grupie
	player = get_tree().get_first_node_in_group("player")
	
	if player:
		
		print("Przeciwnik ", name, " goni obiekt: ", player.name)
	else:
		print("Nie ma kogo gonić, bo nie ma grupy player")
		
func _physics_process(_delta):
	if player:
		var current_player_pos = player.global_position
		var direction = global_position.direction_to(current_player_pos)
		velocity = direction * SPEED
		move_and_slide()
func take_damage(amount):
		health -= amount
		print("Przeciwnik oberwał! Zostało HP: ", health)
		if health <= 0:
			die()
func die():
	#Tu się kiedyś doda dropanie kapsli
	queue_free() # Usuwa przeciwnika z gry
