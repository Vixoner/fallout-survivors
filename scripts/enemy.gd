extends CharacterBody2D

signal died(position: Vector2, caps_count: int)

const SEPARATION_RADIUS = 80.0
const SEPARATION_STRENGTH = 180.0
const HIT_SHADER = preload("res://assets/shaders/hit_flash.gdshader")

@export var max_health: int       = 100
@export var move_speed: float     = 300.0
@export var attack_damage: int    = 2
@export var attack_cooldown: float = 1.0
@export var contact_distance: float = 65.0
@export var caps_drop_min: int = 2
@export var caps_drop_max: int = 4
@export var attack_sound: AudioStream
@export var death_sound: AudioStream
# When true, enemy only has side-facing run/attack animations — they get
# flipped horizontally for left and reused even when moving purely up/down.
# Lets a variant ship with just 3 animations (run_side, attack_side, death_basic).
@export var side_only_animations: bool = false

var health: int
var player = null
var is_dead: bool = false
var attack_timer: float = 0.0
var _champion_tween: Tween = null
var _nav_agent: NavigationAgent2D = null
var _last_position: Vector2 = Vector2.ZERO
var _stuck_timer: float = 0.0
var _stuck_nudge_side: float = 1.0

@onready var sprite: Sprite2D = $BodySprite
@onready var animation_player = $AnimationPlayer
# Ciemna obramówka wysuwana w dół — kopia sprita przesunięta niżej i przyciemniona,
# rysowana za BodySprite, więc wystaje tylko u dołu. Nie każdy enemy ją ma.
@onready var _outline: Sprite2D = get_node_or_null("Outline")

func _ready():
	z_index = 5
	process_mode = Node.PROCESS_MODE_PAUSABLE
	health = max_health
	player = get_tree().get_first_node_in_group("player")
	_nav_agent = NavigationAgent2D.new()
	_nav_agent.path_desired_distance = 40.0
	_nav_agent.target_desired_distance = 48.0
	_nav_agent.path_max_distance = 96.0
	_nav_agent.avoidance_enabled = false
	add_child(_nav_agent)
	_last_position = global_position

func _process(_delta):
	# Synchronizuj obramówkę z aktualną klatką animacji sprita (jeśli enemy ją ma).
	if _outline and is_instance_valid(sprite):
		_outline.texture = sprite.texture
		_outline.hframes = sprite.hframes
		_outline.vframes = sprite.vframes
		_outline.frame   = sprite.frame
		_outline.flip_h  = sprite.flip_h

func _physics_process(delta):
	if is_dead:
		return
	
	if player:
		var direction = global_position.direction_to(player.global_position)
		var fleeing: bool = player.get("is_dying")
		if fleeing:
			direction = -direction
		var distance = global_position.distance_to(player.global_position)
		attack_timer += delta

		# 2. Logika ataku (tylko gdy gracz żywy)
		if not fleeing and distance < contact_distance:
			if attack_timer >= attack_cooldown:
				play_attack_animation(direction)
				_play_attack_sound()
				player.take_damage(attack_damage)
				attack_timer = 0.0

		# 3. Ruch i animacja biegu (tylko gdy nie atakuje)
		if not is_currently_attacking():
			var move_dir: Vector2 = direction
			if not fleeing and is_instance_valid(_nav_agent):
				_nav_agent.set_target_position(player.global_position)
				if not _nav_agent.is_navigation_finished():
					var next_pos := _nav_agent.get_next_path_position()
					var nav_dir := global_position.direction_to(next_pos)
					if nav_dir.length_squared() > 0.01:
						move_dir = nav_dir
			var move = move_dir * move_speed + get_separation_force()
			velocity = move
			move_and_slide()
			# Odpychanie od ściany przez normalną kolizji — natychmiastowe, bez timera
			for i in get_slide_collision_count():
				var col := get_slide_collision(i)
				if col.get_collider() is StaticBody2D:
					velocity += col.get_normal() * move_speed * 0.9
					move_and_slide()
					break
			# Fallback unstuck: gdy nawet normalna nie pomaga, impuls boczny
			var dist_moved := global_position.distance_to(_last_position)
			if dist_moved < move_speed * delta * 0.1 and distance > contact_distance:
				_stuck_timer += delta
				if _stuck_timer > 0.2:
					velocity = move_dir.rotated(PI / 2.0 * _stuck_nudge_side) * move_speed * 1.5
					move_and_slide()
					_stuck_nudge_side = -_stuck_nudge_side
					_stuck_timer = 0.0
			else:
				_stuck_timer = 0.0
			_last_position = global_position
			update_run_animation(move_dir)
			
func is_currently_attacking() -> bool:
	return animation_player.is_playing() and animation_player.current_animation.contains("attack")
	
func play_attack_animation(direction: Vector2):
	sprite.flip_h = false
	if side_only_animations:
		animation_player.play("attack_side")
		sprite.flip_h = direction.x < 0
		return
	if abs(direction.y) > abs(direction.x):
		if direction.y > 0:
			animation_player.play("attack_down")
		else:
			animation_player.play("attack_up")
	else:
		if direction.x < 0:
			animation_player.play("attack_left")
		else:
			animation_player.play("attack_right")
			
# DODANE: Funkcja zarządzająca animacją wroga
func update_run_animation(direction: Vector2):
	if side_only_animations:
		animation_player.play("run_side")
		sprite.flip_h = direction.x < 0
		return
	if abs(direction.y) > abs(direction.x):
		sprite.flip_h = false
		if direction.y > 0:
			animation_player.play("run_down")
		else:
			animation_player.play("run_up")
	else:
		animation_player.play("run_side")
		sprite.flip_h = direction.x < 0

func get_separation_force() -> Vector2:
	var force = Vector2.ZERO
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self:
			continue
		var diff = global_position - other.global_position
		var dist = diff.length()
		if dist > 0.0 and dist < SEPARATION_RADIUS:
			force += diff.normalized() * (1.0 - dist / SEPARATION_RADIUS) * SEPARATION_STRENGTH
	return force

func take_damage(amount, is_crit: bool = false):
	if is_dead:
		return
	health -= amount
	flash_hit()
	spawn_damage_number(amount, is_crit)
	if health <= 0:
		die()

func flash_hit():
	var mat = ShaderMaterial.new()
	mat.shader = HIT_SHADER
	sprite.material = mat
	if _outline:
		_outline.material = mat
	await get_tree().create_timer(0.12).timeout
	if is_instance_valid(sprite):
		sprite.material = null
	if is_instance_valid(_outline):
		_outline.material = null

func spawn_damage_number(amount: int, is_crit: bool = false):
	var label = Label.new()
	label.text = str(amount) + ("!" if is_crit else "")
	label.add_theme_font_size_override("font_size", 32 if is_crit else 22)
	label.add_theme_color_override("font_color", Color(1, 0.35, 0.0) if is_crit else Color(1, 0.9, 0.1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 5 if is_crit else 4)
	label.z_index = 10
	label.position = global_position + Vector2(-16 + randf_range(-10, 10), -60 + randf_range(-10, 10))
	get_tree().current_scene.add_child(label)

	var tween = label.create_tween()
	tween.set_parallel(true)
	var rise = 80 if is_crit else 50
	tween.tween_property(label, "position:y", label.position.y - rise, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)

func make_champion():
	max_health = int(max_health  * 2.0)
	health = max_health
	move_speed *= 1.3
	attack_damage = int(attack_damage  * 2.0)
	caps_drop_min = int(caps_drop_min  * 1.3)
	caps_drop_max = int(caps_drop_max  * 1.3)
	scale *= 1.15
	_champion_tween = create_tween().set_loops()
	_champion_tween.tween_property(self, "modulate", Color(1.9, 0.25, 0.25), 0.45)
	_champion_tween.tween_property(self, "modulate", Color(1.3, 0.55, 0.55), 0.45)

func die():
	if is_dead:
		return
	is_dead = true
	emit_signal("died", global_position, randi_range(caps_drop_min, caps_drop_max))
	z_index = 3
	$CollisionShape2D.set_deferred("disabled", true)
	set_physics_process(false)
	if _champion_tween:
		_champion_tween.kill()
		_champion_tween = null
	_play_sfx_2d(death_sound)
	animation_player.play("death_basic")
	await get_tree().create_timer(1.2).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	await tween.finished
	queue_free()

func _play_attack_sound() -> void:
	_play_sfx_2d(attack_sound)

func _play_sfx_2d(stream: AudioStream) -> void:
	# 2D positional player parented to current_scene so the sound survives if
	# the enemy despawns (e.g. dies mid-bite, or queue_free finishes before the
	# death scream does). Routes through the SFX bus → respects the "Głośność
	# efektów" slider. Null stream means this variant has no SFX assigned.
	if stream == null:
		return
	var p := AudioStreamPlayer2D.new()
	p.bus = "SFX"
	p.stream = stream
	p.autoplay = true
	p.global_position = global_position
	p.finished.connect(p.queue_free)
	get_tree().current_scene.add_child(p)
	
	# TYMCZASOWE -------------------------------------------------------------
