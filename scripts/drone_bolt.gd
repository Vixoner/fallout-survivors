extends Area2D

# Sentry-drone projectile. Hurts only the player (other enemies pass through),
# same pattern as floater_ball.gd but tinted blue.

var speed: float = 280.0
var damage: int = 10

const LIFETIME := 5.0
var _life: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 7
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	_draw_visual()

func _physics_process(delta: float) -> void:
	position += transform.x * speed * delta
	_life += delta
	if _life >= LIFETIME:
		queue_free()

func _on_body_entered(body) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()

func _draw_visual() -> void:
	var n := 14
	var glow := Polygon2D.new()
	var gpts := PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		gpts.append(Vector2(cos(a), sin(a)) * 11.0)
	glow.polygon = gpts
	glow.color = Color(0.25, 0.55, 1.00, 0.45)
	add_child(glow)
	var core := Polygon2D.new()
	var cpts := PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		cpts.append(Vector2(cos(a), sin(a)) * 6.0)
	core.polygon = cpts
	core.color = Color(0.60, 0.85, 1.0, 0.95)
	add_child(core)
