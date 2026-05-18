extends Area2D

var fly_speed: float = 800.0
const FLY_TIME = 1.4

var direction: Vector2 = Vector2.RIGHT
var _fly_timer: float = 0.0
var _landed: bool = false

@onready var anim: AnimationPlayer = $AnimationPlayer

func _ready():
	z_index = 4
	process_mode = Node.PROCESS_MODE_PAUSABLE
	body_entered.connect(_on_body_entered)
	if direction.x >= 0:
		anim.play("thrown_right")
	else:
		anim.play("thrown_left")

func _process(delta):
	if _landed:
		return
	_fly_timer += delta
	position += direction * fly_speed * delta
	if _fly_timer >= FLY_TIME:
		_land()

func _on_body_entered(body):
	if _landed:
		return
	if body.is_in_group("player"):
		body.take_damage(10)
		_land()

func _land():
	_landed = true
	set_process(false)
	$CollisionShape2D.set_deferred("disabled", true)
	if direction.x >= 0:
		anim.play("landing_right")
	else:
		anim.play("landing_left")
	await anim.animation_finished
	if not is_instance_valid(self) or not is_inside_tree():
		return
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	await tween.finished
	queue_free()
