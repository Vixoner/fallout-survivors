extends Area2D

const POISON_DOT_SCRIPT := preload("res://scripts/poison_dot.gd")

var speed: float = 800.0
var damage: int = 10
var is_crit: bool = false
# What group this bullet damages. Default "enemies" for player-fired bullets;
# robot boss sets "player" to fire pistol shots back at the player.
var target_group: String = "enemies"

# Karabin Amunicja Wybuchowa — AoE przy trafieniu.
var explosive: bool = false
var explosive_radius: float = 90.0
var explosive_dmg_ratio: float = 0.5
# Karabin Zatrute Naboje — DoT na trafionym celu.
var poison: bool = false
var poison_duration: float = 5.0
var poison_tick_dmg: int = 1

func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 7
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	_apply_glow()

func _apply_glow():
	var main_sprite: Sprite2D = $Sprite2D
	var glow := Sprite2D.new()
	glow.texture = main_sprite.texture
	glow.scale = main_sprite.scale * Vector2(1.2, 1.8)
	glow.position = main_sprite.position
	glow.modulate = Color(0.55, 0.35, 0.0, 0.7)
	add_child(glow)
	move_child(glow, 0)

func _physics_process(delta):
	position += transform.x * speed * delta

func _on_body_entered(body):
	if not body.is_in_group(target_group):
		return
	if body.has_method("take_damage"):
		# Player's take_damage has just (amount); enemies use (amount, is_crit).
		if target_group == "player":
			body.take_damage(damage)
		else:
			body.take_damage(damage, is_crit)
	# Karabin upgrades — only meaningful when this is a player-fired bullet
	# (target_group == "enemies"). Boss-fired bullets never set these flags.
	if target_group == "enemies":
		if explosive:
			_apply_explosive_aoe(body)
		if poison:
			_apply_poison(body)
	queue_free()

func _apply_explosive_aoe(primary_target: Node) -> void:
	var aoe_dmg: int = int(round(damage * explosive_dmg_ratio))
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy == primary_target:
			continue
		if global_position.distance_to(enemy.global_position) > explosive_radius:
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(aoe_dmg, false)
	# Krótki pomarańczowy pierścień jako feedback.
	var fx := Node2D.new()
	fx.global_position = global_position
	fx.z_index = 4
	get_tree().current_scene.add_child(fx)
	var ring := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 20:
		var a: float = TAU * float(i) / 20.0
		pts.append(Vector2(cos(a), sin(a)) * explosive_radius)
	ring.polygon = pts
	ring.color = Color(1.0, 0.55, 0.20, 0.55)
	ring.scale = Vector2(0.25, 0.25)
	fx.add_child(ring)
	var tw := fx.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(1.0, 1.0), 0.25)
	tw.tween_property(ring, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(fx.queue_free)

func _apply_poison(target: Node) -> void:
	# Refresh if already poisoned, otherwise attach a fresh DoT child.
	var existing := target.get_node_or_null(POISON_DOT_SCRIPT.NODE_NAME)
	if existing:
		existing.refresh()
		return
	var dot := POISON_DOT_SCRIPT.new()
	dot.tick_dmg = poison_tick_dmg
	dot.duration = poison_duration
	target.add_child(dot)
