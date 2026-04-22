extends Node2D

const CAP_SCENE = preload("res://scenes/cap.tscn")
const ENEMY_SCENE = preload("res://scenes/enemy.tscn")
const SHOP_SCRIPT = preload("res://scripts/shop.gd")

const SPAWN_MIN_DIST = 700.0
const SPAWN_MAX_DIST = 1100.0

# Definicje fal: [liczba_przeciwnikow, cooldown_spawnu, rozmiar_grupy]
const WAVES = [
	[10, 3.0, 3],
	[15, 2.5, 3],
	[20, 2.0, 4],
	[25, 2.0, 4],
	[30, 1.5, 5],
]

var current_wave: int = 0
var enemies_to_spawn: int = 0
var enemies_spawned: int = 0
var enemies_alive: int = 0
var spawn_cooldown: float = 0.0
var spawn_timer: float = 0.0
var group_size: int = 3
var wave_active: bool = false

var player: Node2D = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = get_tree().get_first_node_in_group("player")
	start_wave(0)

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			enemy.die()

func _process(delta):
	if not wave_active:
		return

	# Jeśli nie ma żywych wrogów i są jeszcze do zrespienia, to skróć cooldown do zera
	if enemies_alive == 0 and enemies_spawned < enemies_to_spawn:
		spawn_timer = spawn_cooldown

	spawn_timer += delta
	if spawn_timer >= spawn_cooldown and enemies_spawned < enemies_to_spawn:
		spawn_timer = 0.0
		spawn_group()

func start_wave(wave_index: int):
	current_wave = wave_index
	var data = WAVES[wave_index]
	enemies_to_spawn = data[0]
	spawn_cooldown = data[1]
	group_size = data[2]
	enemies_spawned = 0
	enemies_alive = 0
	spawn_timer = spawn_cooldown  # Instant spawn na początku fali
	wave_active = true
	update_wave_label()
	print(">>> Fala ", current_wave + 1, " rozpoczęta, Wrogów: ", enemies_to_spawn)

func spawn_group():
	var to_spawn = min(group_size, enemies_to_spawn - enemies_spawned)
	for i in to_spawn:
		spawn_single_enemy()

func spawn_single_enemy():
	var enemy = ENEMY_SCENE.instantiate()
	enemy.global_position = get_spawn_position()
	enemy.died.connect(_on_enemy_died)
	add_child(enemy)
	enemies_spawned += 1
	enemies_alive += 1

func get_spawn_position() -> Vector2:
	var margin = 64.0
	var map_min = Vector2(-GameConstants.MAP_WIDTH / 2.0 + margin, -GameConstants.MAP_HEIGHT / 2.0 + margin)
	var map_max = Vector2(GameConstants.MAP_WIDTH / 2.0 - margin, GameConstants.MAP_HEIGHT / 2.0 - margin)

	if not player:
		return Vector2(randf_range(map_min.x, map_max.x), randf_range(map_min.y, map_max.y))

	# Próbuj losować kąt dopóki pozycja po clampie nie jest wystarczająco daleko od gracza
	var max_attempts = 32
	for i in max_attempts:
		var angle = randf() * TAU
		var dist = randf_range(SPAWN_MIN_DIST, SPAWN_MAX_DIST)
		var pos = player.global_position + Vector2(cos(angle), sin(angle)) * dist
		pos.x = clamp(pos.x, map_min.x, map_max.x)
		pos.y = clamp(pos.y, map_min.y, map_max.y)
		if pos.distance_to(player.global_position) >= SPAWN_MIN_DIST:
			return pos

	# Fallback: spawn po przeciwnej stronie mapy
	var fallback_angle = player.global_position.angle_to_point(Vector2.ZERO)
	var pos = player.global_position + Vector2(cos(fallback_angle), sin(fallback_angle)) * SPAWN_MIN_DIST
	pos.x = clamp(pos.x, map_min.x, map_max.x)
	pos.y = clamp(pos.y, map_min.y, map_max.y)
	return pos

func _on_enemy_died(pos: Vector2):
	enemies_alive -= 1
	spawn_caps(pos, 3, 1)
	check_wave_complete()

func check_wave_complete():
	if enemies_spawned >= enemies_to_spawn and enemies_alive <= 0:
		wave_active = false
		print(">>> Fala ", current_wave + 1, " zakończona!")
		if current_wave + 1 < WAVES.size():
			await get_tree().create_timer(1.2).timeout
			show_shop()
		else:
			print(">>> Wszystkie fale ukończone! Wygrałeś!")
			update_wave_label(true)

func show_shop():
	var shop = SHOP_SCRIPT.new()
	shop.setup(player)
	add_child(shop)
	await shop.shop_closed
	start_wave(current_wave + 1)

func update_wave_label(finished: bool = false):
	var label = get_tree().get_first_node_in_group("wave_label")
	if label:
		if finished:
			label.text = "Wygrałeś!"
		else:
			label.text = "Fala: " + str(current_wave + 1) + " / " + str(WAVES.size())

func spawn_caps(position: Vector2, count: int = 1, value: int = 1):
	for i in count:
		var cap = CAP_SCENE.instantiate()
		cap.value = value
		cap.global_position = position + Vector2(
			randf_range(-30, 30),
			randf_range(-30, 30)
		)
		add_child(cap)
