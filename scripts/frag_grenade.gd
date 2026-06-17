extends Node2D

# Frag grenade: arcs from thrower to target over TRAVEL_TIME, then explodes —
# damaging every enemy within `radius` of the impact point. All visuals are
# drawn programmatically (no .tscn needed).

const TRAVEL_TIME := 0.55
const ARC_HEIGHT  := 90.0
const EXPLOSION_VIS_TIME := 0.4

const THROW_SOUND_PATH := "res://assets/audio/weapons/grenade_throw.wav"
const EXPLODE_SOUND_PATH := "res://assets/audio/weapons/frag_explode.wav"

var _start: Vector2 = Vector2.ZERO
var _target: Vector2 = Vector2.ZERO
var _elapsed: float = 0.0
var _exploded: bool = false

# Tunables, settable via setup() so future grenade variants can reuse this node.
var damage: int = 150
var radius: float = 180.0

var _grenade_sprite: Node2D = null

func setup(start_pos: Vector2, target_pos: Vector2, dmg: int = 150, rad: float = 180.0) -> void:
	_start = start_pos
	_target = target_pos
	damage = dmg
	radius = rad

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 6
	global_position = _start
	_draw_grenade()
	_play_oneshot(load(THROW_SOUND_PATH))

func _process(delta: float) -> void:
	if _exploded:
		return
	_elapsed += delta
	if _elapsed >= TRAVEL_TIME:
		_explode()
		return
	var t: float = _elapsed / TRAVEL_TIME
	var base := _start.lerp(_target, t)
	var lift := sin(t * PI) * ARC_HEIGHT
	global_position = Vector2(base.x, base.y - lift)
	if is_instance_valid(_grenade_sprite):
		_grenade_sprite.rotation = TAU * t * 1.8

func _draw_grenade() -> void:
	_grenade_sprite = Node2D.new()
	add_child(_grenade_sprite)

	var n := 14
	var glow := Polygon2D.new()
	var gpts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		gpts.append(Vector2(cos(a), sin(a)) * 10.0)
	glow.polygon = gpts
	glow.color = Color(0.30, 0.30, 0.24, 0.55)
	_grenade_sprite.add_child(glow)

	var core := Polygon2D.new()
	var cpts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		cpts.append(Vector2(cos(a), sin(a)) * 6.5)
	core.polygon = cpts
	core.color = Color(0.18, 0.20, 0.16, 1.0)
	_grenade_sprite.add_child(core)

	# A small lighter "stripe" so the tumble is visible.
	var stripe := Polygon2D.new()
	stripe.polygon = PackedVector2Array([
		Vector2(-6.5, -1.2), Vector2(6.5, -1.2),
		Vector2(6.5, 1.2),   Vector2(-6.5, 1.2),
	])
	stripe.color = Color(0.45, 0.45, 0.35, 1.0)
	_grenade_sprite.add_child(stripe)

func _explode() -> void:
	_exploded = true
	global_position = _target
	rotation = 0.0
	if is_instance_valid(_grenade_sprite):
		_grenade_sprite.queue_free()
		_grenade_sprite = null

	_play_oneshot(load(EXPLODE_SOUND_PATH))

	# Damage every enemy within radius — distance-based, same pattern as
	# laser_beam / plasma_dot_area, so no Area2D physics-frame delay.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if _target.distance_to(enemy.global_position) <= radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage, false)

	# Expanding flash (orange ring + bright core)
	var n := 32
	var outer := Polygon2D.new()
	var opts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		opts.append(Vector2(cos(a), sin(a)) * radius)
	outer.polygon = opts
	outer.color = Color(1.0, 0.45, 0.10, 0.55)
	outer.scale = Vector2(0.2, 0.2)
	add_child(outer)

	var core := Polygon2D.new()
	var cpts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		cpts.append(Vector2(cos(a), sin(a)) * radius * 0.5)
	core.polygon = cpts
	core.color = Color(1.0, 0.95, 0.70, 0.95)
	core.scale = Vector2(0.2, 0.2)
	add_child(core)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(outer, "scale", Vector2(1.0, 1.0), EXPLOSION_VIS_TIME)
	tw.tween_property(outer, "modulate:a", 0.0, EXPLOSION_VIS_TIME)
	tw.tween_property(core, "scale", Vector2(1.3, 1.3), EXPLOSION_VIS_TIME * 0.6)
	tw.tween_property(core, "modulate:a", 0.0, EXPLOSION_VIS_TIME * 0.6)
	tw.chain().tween_callback(queue_free)

func _play_oneshot(stream: AudioStream) -> void:
	# Spawns a self-cleaning AudioStreamPlayer parented to the scene root so
	# the sound keeps playing even after this grenade queue_free()s itself
	# (the explosion sound otherwise gets cut off when the grenade despawns).
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	p.stream = stream
	p.autoplay = true
	p.finished.connect(p.queue_free)
	get_tree().current_scene.add_child(p)
