extends Area2D

# Single shotgun pellet. Round visual drawn programmatically. Same
# speed / damage / is_crit handshake as bullet.gd so WeaponManager
# can spawn it through the existing projectile path.

var speed: float = 1100.0
var damage: int = 8
var is_crit: bool = false

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
	queue_free()

func _draw_visual() -> void:
	var n := 12

	# Soft halo
	var glow := Polygon2D.new()
	var gpts := PackedVector2Array()
	var gr := 7.0
	for i in n:
		var a := TAU * float(i) / float(n)
		gpts.append(Vector2(cos(a), sin(a)) * gr)
	glow.polygon = gpts
	glow.color = Color(0.95, 0.75, 0.30, 0.45)
	add_child(glow)

	# Bright core
	var core := Polygon2D.new()
	var cpts := PackedVector2Array()
	var cr := 3.5
	for i in n:
		var a := TAU * float(i) / float(n)
		cpts.append(Vector2(cos(a), sin(a)) * cr)
	core.polygon = cpts
	core.color = Color(1.0, 0.95, 0.70, 1.0)
	add_child(core)
