extends Node2D

const CAP_SCENE       = preload("res://scenes/cap.tscn")
const SHOP_SCRIPT     = preload("res://scripts/shop.gd")
const TUTORIAL_SCRIPT = preload("res://scripts/tutorial.gd")
const PAUSE_MENU_SCRIPT = preload("res://scripts/pause_menu.gd")
const VICTORY_SCRIPT = preload("res://scripts/victory_screen.gd")
const GAME_OVER_SCRIPT = preload("res://scripts/game_over_screen.gd")

const SPAWN_MIN_DIST = 700.0
const SPAWN_MAX_DIST = 1100.0

@export var map_size_scale: float = 1.0

# Typy przeciwników
const ENEMY_SCENES = {
	"zombie_small": preload("res://scenes/enemy.tscn"),
	"zombie_big":   preload("res://scenes/enemy_big.tscn"),
	"zombie_boss":  preload("res://scenes/enemy_boss.tscn"),
	"rat":          preload("res://scenes/rat.tscn"),
	"floater":      preload("res://scenes/floater.tscn"),
}

# Definicje fal: cooldown spawnu, rozmiar grupy, typy i liczba przeciwników
# enemies: typ -> {count, champs}  (champs = ile z nich to czempioni)
const WAVES = [
	{"cooldown": 3.0, "group_size": 3, "enemies": {
		"zombie_small":  {"count": 10,  "champs": 0},
		"rat":           {"count": 7,   "champs": 0},
	}},
	{"cooldown": 2.5, "group_size": 3, "enemies": {
		"zombie_small": {"count": 15, "champs": 1},
		"zombie_big":   {"count": 3,  "champs": 0},
		"rat":          {"count": 12,  "champs": 0},
		"floater":      {"count": 2,  "champs": 0},
	}},
	{"cooldown": 2.0, "group_size": 4, "enemies": {
		"zombie_small": {"count": 25, "champs": 3},
		"zombie_big":   {"count": 6,  "champs": 1},
		"rat":          {"count": 18,  "champs": 0},
		"floater":      {"count": 5,  "champs": 0},
	}},
	{"cooldown": 2.0, "group_size": 4, "enemies": {
		"zombie_small": {"count": 30, "champs": 8},
		"zombie_big":   {"count": 10,  "champs": 2},
		"rat":          {"count": 20,  "champs": 1},
		"floater":      {"count": 8,  "champs": 1},
	}},
	{"cooldown": 1.5, "group_size": 5, "enemies": {
		"zombie_boss":  {"count": 1,  "champs": 0},
		"floater":      {"count": 4,  "champs": 0},
	}},
]

var current_wave: int = 0
var enemies_to_spawn: int = 0
var enemies_spawned: int = 0
var enemies_alive: int = 0
var spawn_cooldown: float = 0.0
var spawn_timer: float = 0.0
var group_size: int = 3
var wave_active: bool = false
var _spawn_queue: Array = []

var player: Node2D = null
var _pause_menu = null
var _in_shop: bool = false
var _zombies_killed: int = 0
var _run_time: float = 0.0
var _victory_shown: bool = false
var _game_over_shown: bool = false
var _wave_ending: bool = false
var _eggs_collected: int = 0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_navigation()
	player = get_tree().get_first_node_in_group("player")
	if player:
		player.game_over.connect(_on_player_game_over)
		if map_size_scale != 1.0:
			player.set_map_bounds(
				GameConstants.MAP_WIDTH * map_size_scale,
				GameConstants.MAP_HEIGHT * map_size_scale
			)
	_spawn_easter_eggs()
	_start_music()
	if GameState.tutorial_mode:
		var tutorial := TUTORIAL_SCRIPT.new()
		tutorial.setup(self, player)
		add_child(tutorial)
	else:
		start_wave(0)

func _start_music() -> void:
	# Try .ogg first (best for looping), .mp3 as fallback. Bus = "Music" so
	# the "Głośność muzyki" slider in SettingsPanel controls volume.
	var candidate_paths := [
		"res://assets/audio/music/metal_on_metal.ogg",
		"res://assets/audio/music/metal_on_metal.mp3",
	]
	var stream: AudioStream = null
	for path in candidate_paths:
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	if stream == null:
		push_warning("Background music not found at assets/audio/music/metal_on_metal.(ogg|mp3)")
		return
	if "loop" in stream:
		stream.loop = true
	var music_player := AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Music"
	music_player.stream = stream
	music_player.autoplay = true
	add_child(music_player)

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER:
			for enemy in get_tree().get_nodes_in_group("enemies"):
				enemy.die()

func _process(delta):
	if Input.is_action_just_pressed("ui_cancel"):
		_handle_escape()

	if get_tree().paused or not wave_active:
		return
	if player and player.get("is_dying"):
		return

	_run_time += delta

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
	spawn_cooldown = data["cooldown"]
	group_size = data["group_size"]
	enemies_spawned = 0
	enemies_alive = 0

	_spawn_queue = []
	for type_name in data["enemies"]:
		var entry = data["enemies"][type_name]
		var scene = ENEMY_SCENES[type_name]
		var champs: int = entry["champs"]
		for i in entry["count"]:
			_spawn_queue.append({"scene": scene, "champion": i < champs})
	_spawn_queue.shuffle()
	enemies_to_spawn = _spawn_queue.size()

	spawn_timer = spawn_cooldown
	wave_active = true
	update_wave_label()
	print(">>> Fala ", current_wave + 1, " — Wrogów: ", enemies_to_spawn)

func spawn_group():
	var to_spawn = min(group_size, enemies_to_spawn - enemies_spawned)
	for i in to_spawn:
		spawn_single_enemy()

func spawn_single_enemy():
	if _spawn_queue.is_empty():
		return
	var data = _spawn_queue.pop_back()
	var enemy = data["scene"].instantiate()
	enemy.global_position = get_spawn_position()
	enemy.died.connect(_on_enemy_died)
	add_child(enemy)
	if data["champion"]:
		enemy.make_champion()
	enemies_spawned += 1
	enemies_alive += 1

func get_spawn_position() -> Vector2:
	var margin = 64.0
	var map_w := GameConstants.MAP_WIDTH * map_size_scale
	var map_h := GameConstants.MAP_HEIGHT * map_size_scale
	var map_min = Vector2(-map_w / 2.0 + margin, -map_h / 2.0 + margin)
	var map_max = Vector2( map_w / 2.0 - margin,  map_h / 2.0 - margin)

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
	var fallback_pos = player.global_position + Vector2(cos(fallback_angle), sin(fallback_angle)) * SPAWN_MIN_DIST
	fallback_pos.x = clamp(fallback_pos.x, map_min.x, map_max.x)
	fallback_pos.y = clamp(fallback_pos.y, map_min.y, map_max.y)
	return fallback_pos

func _on_enemy_died(pos: Vector2, caps_count: int):
	enemies_alive -= 1
	_zombies_killed += 1
	spawn_caps(pos, caps_count, 1)
	check_wave_complete()

func check_wave_complete():
	if player and player.get("is_dying"):
		return
	if enemies_spawned >= enemies_to_spawn and enemies_alive <= 0:
		wave_active = false
		_wave_ending = true
		print(">>> Fala ", current_wave + 1, " zakończona!")
		if current_wave + 1 < WAVES.size():
			await get_tree().create_timer(1.2).timeout
			_wave_ending = false
			show_shop()
		else:
			await get_tree().create_timer(1.2).timeout
			show_victory_screen()

func _on_player_game_over():
	_game_over_shown = true
	var screen = GAME_OVER_SCRIPT.new()
	screen.zombies_killed = _zombies_killed
	screen.elapsed_time = _run_time
	add_child(screen)

func _handle_escape():
	if _in_shop or _victory_shown or _game_over_shown or _wave_ending or (player and player.get("is_dying")):
		return
	if is_instance_valid(_pause_menu):
		_pause_menu._on_continue()
	else:
		_pause_menu = PAUSE_MENU_SCRIPT.new()
		_pause_menu.resumed.connect(func(): _pause_menu = null)
		add_child(_pause_menu)

func show_shop():
	_in_shop = true
	var shop = SHOP_SCRIPT.new()
	shop.setup(player)
	add_child(shop)
	await shop.shop_closed
	_in_shop = false
	start_wave(current_wave + 1)

func show_victory_screen():
	_victory_shown = true
	GameState.save_record(GameState.selected_class.get("id", ""), _run_time)
	GameState.mark_level_completed(GameState.selected_map)
	var screen = VICTORY_SCRIPT.new()
	screen.zombies_killed = _zombies_killed
	screen.elapsed_time = _run_time
	add_child(screen)

func update_wave_label():
	var label = get_tree().get_first_node_in_group("wave_label")
	if label:
		label.text = "Fala: " + str(current_wave + 1) + " / " + str(WAVES.size())

func spawn_caps(spawn_pos: Vector2, count: int = 1, value: int = 1):
	for i in count:
		var cap = CAP_SCENE.instantiate()
		cap.value = value
		cap.position = spawn_pos + Vector2(randf_range(-30, 30), randf_range(-30, 30))
		add_child.call_deferred(cap)

func _setup_navigation() -> void:
	var walls: Node = get_node_or_null("Walls")
	if walls != null:
		# Tag Walls so the bake can find it — default mode only scans NavRegion's
		# own children, groups mode scans any tagged node and its children.
		walls.add_to_group(&"nav_obstacle")

	var nav_region := NavigationRegion2D.new()
	nav_region.name = "NavRegion"
	add_child(nav_region)

	var nav_poly := NavigationPolygon.new()
	nav_poly.parsed_geometry_type  = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_poly.parsed_collision_mask = 2
	nav_poly.agent_radius          = 60.0
	nav_poly.source_geometry_mode  = NavigationPolygon.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav_poly.source_geometry_group_name = &"nav_obstacle"

	var half := maxf(GameConstants.MAP_WIDTH, GameConstants.MAP_HEIGHT) * map_size_scale
	nav_poly.add_outline(PackedVector2Array([
		Vector2(-half, -half),
		Vector2( half, -half),
		Vector2( half,  half),
		Vector2(-half,  half),
	]))

	nav_region.navigation_polygon = nav_poly
	nav_region.bake_navigation_polygon(false)

func _spawn_easter_eggs() -> void:
	var hw := GameConstants.MAP_WIDTH  * map_size_scale - 180.0
	var hh := GameConstants.MAP_HEIGHT * map_size_scale - 180.0
	for corner in [Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(-hw, hh), Vector2(hw, hh)]:
		_spawn_single_egg(corner)

func _spawn_single_egg(pos: Vector2) -> void:
	var egg := Area2D.new()
	egg.position = pos
	egg.collision_layer = 0
	egg.collision_mask  = 1
	egg.process_mode    = Node.PROCESS_MODE_PAUSABLE

	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/sprites/Egg_JE2_BE2.png")
	sprite.scale = Vector2(0.3, 0.3)
	sprite.z_index = 4
	egg.add_child(sprite)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 24.0
	shape.shape = circle
	egg.add_child(shape)

	add_child(egg)

	egg.body_entered.connect(func(body: Node) -> void:
		if body.is_in_group("player") and is_instance_valid(egg):
			egg.queue_free()
			_eggs_collected += 1
			if _eggs_collected >= 4:
				_on_all_eggs_collected()
	)

	var tween := egg.create_tween().set_loops()
	tween.tween_property(sprite, "position:y", -8.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "position:y",  8.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_all_eggs_collected() -> void:
	spawn_caps(Vector2.ZERO, 30, 1)
	var label := Label.new()
	label.text = "EASTER EGG!  +30 kapsli czeka na środku!"
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	label.z_index = 10
	var start_pos := (player.global_position if player else Vector2.ZERO) + Vector2(-80, -60)
	label.position = start_pos
	add_child(label)
	var t := label.create_tween()
	t.set_parallel(true)
	t.tween_property(label, "position:y", start_pos.y - 50, 2.0)
	t.tween_property(label, "modulate:a", 0.0, 2.0).set_delay(0.8)
	t.chain().tween_callback(label.queue_free)
