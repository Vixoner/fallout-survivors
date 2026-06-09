extends Area2D

# Slow green gooey plasma projectile. On contact with an enemy, applies
# direct damage and spawns a short-lived DoT puddle at impact.

const DOT_SCRIPT := preload("res://scripts/plasma_dot_area.gd")

# Set by WeaponManager._spawn_bullet (same property names as bullet.gd).
var speed: float = 500.0
var damage: int = 60
var is_crit: bool = false

# DoT params handed off to the puddle on impact. Tweak in make_plasma()
# or override on the bullet instance via WeaponData if you later expose them.
var dot_radius: float = 90.0
var dot_duration: float = 2.5
var dot_tick_interval: float = 0.4
var dot_tick_damage: int = 8
var dot_slow: float = 0.0  # Lepka Plazma slow multiplier (e.g. 0.5 = halve speed)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 7
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	_draw_visual()

func _physics_process(delta: float) -> void:
	position += transform.x * speed * delta

func _on_body_entered(body) -> void:
	if not body.is_in_group("enemies"):
		return
	if body.has_method("take_damage"):
		body.take_damage(damage, is_crit)
	_spawn_dot()
	queue_free()

func _spawn_dot() -> void:
	var dot = DOT_SCRIPT.new()
	dot.configure(dot_radius, dot_duration, dot_tick_interval, dot_tick_damage)
	if "slow_amount" in dot:
		dot.slow_amount = dot_slow
	dot.global_position = global_position
	get_tree().current_scene.add_child(dot)

func _draw_visual() -> void:
	var n := 18

	# Outer translucent halo
	var glow := Polygon2D.new()
	var gpts := PackedVector2Array()
	var gr := 16.0
	for i in n:
		var a := TAU * float(i) / float(n)
		gpts.append(Vector2(cos(a), sin(a)) * gr)
	glow.polygon = gpts
	glow.color = Color(0.30, 0.95, 0.30, 0.45)
	add_child(glow)

	# Bright core
	var core := Polygon2D.new()
	var cpts := PackedVector2Array()
	var cr := 8.0
	for i in n:
		var a := TAU * float(i) / float(n)
		cpts.append(Vector2(cos(a), sin(a)) * cr)
	core.polygon = cpts
	core.color = Color(0.70, 1.0, 0.55, 0.95)
	add_child(core)

	# Subtle pulse so it reads as gooey/energy.
	var tw := create_tween().set_loops()
	tw.tween_property(glow, "scale", Vector2(1.15, 1.15), 0.22)
	tw.tween_property(glow, "scale", Vector2(1.0, 1.0), 0.22)
