extends CharacterBody2D

# Sentry drone summoned by the robot boss in phase 3.
# Drifts outward from spawn for a bit, then hovers in place and fires blue
# bolts at the player every SHOT_INTERVAL seconds. Killable (50 HP).
# Lives in the "enemies" group so player weapons damage it. Not tracked by
# endless's enemies_alive counter (it's spawned by the boss, not the
# spawner), so it doesn't gate boss-phase clearance.

signal died(position: Vector2, caps_count: int)

const BOLT_SCENE := preload("res://scenes/drone_bolt.tscn")

const SHOT_INTERVAL := 1.5
const DRIFT_TIME := 1.0
const DRIFT_SPEED := 220.0
const HEALTH := 50
const BOLT_DAMAGE := 10

@export var max_health: int = HEALTH
@export var move_speed: float = 0.0  # static after drift completes

# Mutable runtime values — make_champion() doubles HP/damage, speeds up shots.
var shot_interval: float = SHOT_INTERVAL
var bolt_damage: int = BOLT_DAMAGE
var health: int = HEALTH
var player: Node2D = null
var is_dead: bool = false

var _drift_direction: Vector2 = Vector2.RIGHT
var _drift_elapsed: float = 0.0
var _shot_timer: float = 0.0
var _is_champion: bool = false
var _champion_tween: Tween = null

func setup(drift_direction: Vector2) -> void:
	_drift_direction = drift_direction.normalized() if drift_direction != Vector2.ZERO else Vector2.RIGHT

func _ready() -> void:
	z_index = 5
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("enemies")
	add_to_group("sentry_drones")
	health = max_health
	player = get_tree().get_first_node_in_group("player")
	# Stagger shots so a wave of drones doesn't fire on the same beat.
	_shot_timer = randf_range(0.0, shot_interval * 0.6)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	# Drift outward briefly so the trio fans out from boss spawn point.
	if _drift_elapsed < DRIFT_TIME:
		_drift_elapsed += delta
		velocity = _drift_direction * DRIFT_SPEED
		move_and_slide()
	else:
		velocity = Vector2.ZERO
	_shot_timer += delta
	if _shot_timer >= shot_interval:
		_shot_timer = 0.0
		_fire_at_player()

func _fire_at_player() -> void:
	if player == null or not is_instance_valid(player):
		return
	var direction: Vector2 = global_position.direction_to(player.global_position)
	var bolt = BOLT_SCENE.instantiate()
	bolt.global_position = global_position
	bolt.rotation = direction.angle()
	if "damage" in bolt:
		bolt.damage = bolt_damage
	get_tree().current_scene.add_child(bolt)

func take_damage(amount: int, _is_crit: bool = false) -> void:
	if is_dead:
		return
	health -= amount
	if health <= 0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	if _champion_tween:
		_champion_tween.kill()
		_champion_tween = null
	emit_signal("died", global_position, 1)
	queue_free()

# Boss spawns drones as champions at HP thresholds. Mirrors enemy.gd's
# make_champion pattern: double HP/damage, faster shots, slightly bigger,
# red pulsing tint for visual distinction.
func make_champion() -> void:
	if _is_champion:
		return
	_is_champion = true
	max_health = int(max_health * 2)
	health = max_health
	bolt_damage = int(bolt_damage * 2)
	shot_interval *= 0.7  # ~30% faster shots
	scale *= 1.15
	_champion_tween = create_tween().set_loops()
	_champion_tween.tween_property(self, "modulate", Color(1.9, 0.25, 0.25), 0.45)
	_champion_tween.tween_property(self, "modulate", Color(1.3, 0.55, 0.55), 0.45)
