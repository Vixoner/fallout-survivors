extends CharacterBody2D

const SPEED = 500.0
const MAP_WIDTH = 3000
const MAP_HEIGHT = 2000
const PLAYER_SIZE = 64

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
