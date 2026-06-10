extends Area2D

var speed: float = 800.0
var damage: int = 10
var is_crit: bool = false
# What group this bullet damages. Default "enemies" for player-fired bullets;
# robot boss sets "player" to fire pistol shots back at the player.
var target_group: String = "enemies"

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
	queue_free()
