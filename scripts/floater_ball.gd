extends Area2D

# Slow gooey projectile fired by the Floater. Only damages the player —
# any other body (other enemies, etc.) is ignored so cross-fire between
# Floaters doesn't friendly-kill the swarm.

var speed: float = 240.0
var damage: int = 5

const LIFETIME := 6.0
var _life_elapsed: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 7
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	_draw_visual()

func _physics_process(delta: float) -> void:
	position += transform.x * speed * delta
	_life_elapsed += delta
	if _life_elapsed >= LIFETIME:
		queue_free()

func _on_body_entered(body) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()

func _draw_visual() -> void:
	var n := 14

	# Outer translucent halo
	var glow := Polygon2D.new()
	var gpts := PackedVector2Array()
	var gr := 13.0
	for i in n:
		var a := TAU * float(i) / float(n)
		gpts.append(Vector2(cos(a), sin(a)) * gr)
	glow.polygon = gpts
	glow.color = Color(0.25, 0.55, 1.00, 0.45)
	add_child(glow)

	# Bright core
	var core := Polygon2D.new()
	var cpts := PackedVector2Array()
	var cr := 7.0
	for i in n:
		var a := TAU * float(i) / float(n)
		cpts.append(Vector2(cos(a), sin(a)) * cr)
	core.polygon = cpts
	core.color = Color(0.55, 0.85, 1.0, 0.95)
	add_child(core)

	# Subtle gooey pulse
	var tw := create_tween().set_loops()
	tw.tween_property(glow, "scale", Vector2(1.18, 1.18), 0.22)
	tw.tween_property(glow, "scale", Vector2(1.0, 1.0), 0.22)
