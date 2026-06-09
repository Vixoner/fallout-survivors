extends Area2D

@export var value: int = 1
@export var attract_radius: float = 200.0
@export var attract_speed: float = 600.0

const TRAIL_LENGTH = 14
const SPRITE_BASE_SCALE = Vector2(0.1, 0.1)

var _player: Node2D = null
var _attracting: bool = false
var _attract_speed: float = 0.0
var _bob_time: float = 0.0
var _trail: Line2D = null
var _trail_positions: Array = []

@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	z_index = 1
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("caps")
	_player = get_tree().get_first_node_in_group("player")
	if _player and _player.has_method("get_attract_radius"):
		attract_radius = _player.get_attract_radius()
	body_entered.connect(_on_body_entered)
	_setup_trail()
	_play_spawn_animation()

func _setup_trail():
	_trail = Line2D.new()
	_trail.width = 5.0
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.z_index = 1
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 0.15, 0.15, 0.85))
	gradient.set_color(1, Color(1.0, 0.15, 0.15, 0.0))
	_trail.gradient = gradient
	get_parent().add_child(_trail)

func _play_spawn_animation():
	sprite.scale = Vector2.ZERO
	sprite.rotation = randf_range(-0.5, 0.5)
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", SPRITE_BASE_SCALE, 0.25)

func _physics_process(delta):
	if _player == null:
		return

	_bob_time += delta

	var distance = global_position.distance_to(_player.global_position)
	if distance < attract_radius and not _attracting:
		_attracting = true
		_attract_speed = attract_speed * 0.3

	if _attracting:
		_attract_speed = move_toward(_attract_speed, attract_speed * 4.0, attract_speed * 5.0 * delta)
		_move_towards_player(delta)
		var dir = global_position.direction_to(_player.global_position)
		sprite.rotation = dir.angle() + PI / 2.0
		_update_trail()
	else:
		sprite.position.y = sin(_bob_time * 2.5) * 4.0
		_clear_trail()

func _move_towards_player(delta):
	var direction = global_position.direction_to(_player.global_position)
	global_position += direction * _attract_speed * delta

func _update_trail():
	_trail_positions.push_front(global_position)
	if _trail_positions.size() > TRAIL_LENGTH:
		_trail_positions.pop_back()
	_trail.clear_points()
	for p in _trail_positions:
		_trail.add_point(p)

func _clear_trail():
	if _trail_positions.size() > 0:
		_trail_positions.clear()
		_trail.clear_points()

func _on_body_entered(body):
	if body.is_in_group("player"):
		_collect()

func _collect():
	_play_pickup_sound()
	if _player.has_method("add_caps"):
		_player.add_caps(value)
	if is_instance_valid(_trail):
		_trail.queue_free()
	queue_free()

func _play_pickup_sound():
	var sound = AudioStreamPlayer.new()
	sound.stream = preload("res://assets/audio/cap_pickup.wav")
	sound.volume_db = -6.0
	sound.bus = "SFX"
	get_tree().current_scene.add_child(sound)
	sound.play()
	sound.finished.connect(sound.queue_free)

func _exit_tree():
	if is_instance_valid(_trail):
		_trail.queue_free()
