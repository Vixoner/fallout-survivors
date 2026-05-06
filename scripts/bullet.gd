extends Area2D

var speed: float = 800.0
var damage: int = 10

func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 7
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _physics_process(delta):
	position += transform.x * speed * delta

func _on_body_entered(body):
	if body.is_in_group("enemies"):
		body.take_damage(damage, false)
		queue_free()
