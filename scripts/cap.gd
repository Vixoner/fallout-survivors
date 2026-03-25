extends Area2D

@export var value: int = 1          # ile kapsel jest wart
@export var attract_radius: float = 200.0   # z jakiej odległości przyciąga
@export var attract_speed: float = 600.0   # prędkość przyciągania

var _player: Node2D = null
var _attracting: bool = false

func _ready():
	_player = get_tree().get_first_node_in_group("player")
	# gdy gracz wejdzie w Area2D zbieramy kapsel
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	if _player == null:
		return

	var distance = global_position.distance_to(_player.global_position)

	# Włącz przyciąganie gdy gracz wystarczająco blisko
	if distance < attract_radius:
		_attracting = true

	if _attracting:
		_move_towards_player(delta)

func _move_towards_player(delta):
	var direction = global_position.direction_to(_player.global_position)
	global_position += direction * attract_speed * delta

func _on_body_entered(body):
	if body.is_in_group("player"):
		_collect()

func _collect():
	# tu dodać logike zbierania w przyszlosci
	print("Zebrano kapsel! Wartość: ", value)
	queue_free()
