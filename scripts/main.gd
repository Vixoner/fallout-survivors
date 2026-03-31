extends Node2D

const CAP_SCENE = preload("res://scenes/cap.tscn")
const ENEMY_SCENE = preload("res://scenes/enemy.tscn")

func spawn_caps(position: Vector2, count: int = 1, value: int = 1):
	for i in count:
		var cap = CAP_SCENE.instantiate()
		cap.value = value
		# Losowe rozrzucenie wokół pozycji przeciwnika
		cap.global_position = position + Vector2(
			randf_range(-30, 30),
			randf_range(-30, 30)
		)
		add_child(cap)
func spawn_enemy():
	var enemy = ENEMY_SCENE.instantiate()
	# Ustawiamy mu pozycję, żeby nie od razu na graczu nie spawnic
	enemy.global_position = get_global_mouse_position() + Vector2(200, 0)
	add_child(enemy)
	
func _input(event):
	if event is InputEventMouseButton and event.pressed:
		spawn_caps(get_global_mouse_position(), 5)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			spawn_enemy()	
