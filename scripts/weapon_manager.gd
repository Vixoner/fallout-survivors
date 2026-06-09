class_name WeaponManager extends Node

const LASER_BEAM_SCRIPT := preload("res://scripts/laser_beam.gd")

signal weapon_fired(weapon: WeaponData)

var current_weapon: WeaponData = null
var _cooldown: float = 0.0
var _audio: AudioStreamPlayer = null

func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_audio = AudioStreamPlayer.new()
	_audio.bus = "SFX"
	add_child(_audio)

func equip(weapon: WeaponData) -> void:
	current_weapon = weapon
	_cooldown = 0.0

func tick(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

func can_fire() -> bool:
	return current_weapon != null and _cooldown <= 0.0

func fire(direction: Vector2) -> void:
	if not can_fire() or direction == Vector2.ZERO:
		return
	if current_weapon.is_beam:
		_fire_beam(direction)
	elif current_weapon.bullet_scene != null:
		var origin := _get_muzzle_position()
		var base_angle := direction.angle()
		var count: int = max(1, current_weapon.projectile_count)
		for i in count:
			var angle := base_angle
			if count > 1:
				if current_weapon.spread_random:
					angle += randf_range(-current_weapon.spread_angle * 0.5, current_weapon.spread_angle * 0.5)
				else:
					var t := float(i) / float(count - 1) - 0.5
					angle += t * current_weapon.spread_angle
			elif current_weapon.spread_angle > 0.0:
				angle += randf_range(-current_weapon.spread_angle * 0.5, current_weapon.spread_angle * 0.5)
			_spawn_bullet(origin, angle)
	else:
		return
	_cooldown = current_weapon.fire_rate
	_play_fire_sound()
	weapon_fired.emit(current_weapon)

func _play_fire_sound() -> void:
	if _audio == null or current_weapon == null or current_weapon.fire_sound == null:
		return
	_audio.stream = current_weapon.fire_sound
	_audio.play()

func _fire_beam(direction: Vector2) -> void:
	var owner_node = get_parent()
	var crit_mult: float = 2.0
	if owner_node and owner_node.has_method("get_crit_mult"):
		crit_mult = float(owner_node.get_crit_mult())
	var crit: bool = owner_node and owner_node.has_method("roll_crit") and owner_node.roll_crit()
	var dmg := current_weapon.damage
	if owner_node and owner_node.has_method("get_ranged_damage_mult"):
		dmg = int(round(dmg * owner_node.get_ranged_damage_mult()))
	if crit:
		dmg = int(round(dmg * crit_mult))

	var base_dir: Vector2 = direction.normalized()
	var origin: Vector2 = _get_muzzle_position()
	var scene_root := get_tree().current_scene

	if current_weapon.splitter:
		# Main beam at full damage, two angled beams at ±45° with 60% damage.
		_spawn_beam(scene_root, origin, base_dir, dmg, crit)
		var side_dmg: int = int(round(dmg * 0.6))
		_spawn_beam(scene_root, origin, base_dir.rotated(deg_to_rad(45.0)), side_dmg, crit)
		_spawn_beam(scene_root, origin, base_dir.rotated(deg_to_rad(-45.0)), side_dmg, crit)
	else:
		_spawn_beam(scene_root, origin, base_dir, dmg, crit)

func _spawn_beam(scene_root: Node, origin: Vector2, direction: Vector2, dmg: int, crit: bool) -> void:
	var beam = LASER_BEAM_SCRIPT.new()
	beam.configure(origin, direction, current_weapon.beam_length, dmg, current_weapon.beam_width, crit)
	scene_root.add_child(beam)

func _get_muzzle_position() -> Vector2:
	var owner_node = get_parent()
	if owner_node is Node2D:
		var muzzle = owner_node.get_node_or_null("GunPivot/GunMuzzle")
		if muzzle:
			return muzzle.global_position
		return owner_node.global_position
	return Vector2.ZERO

func _spawn_bullet(origin: Vector2, angle: float) -> void:
	var bullet = current_weapon.bullet_scene.instantiate()
	bullet.global_position = origin
	bullet.rotation = angle
	var owner_node = get_parent()
	var crit_mult: float = 2.0
	if owner_node and owner_node.has_method("get_crit_mult"):
		crit_mult = float(owner_node.get_crit_mult())
	if "speed" in bullet:
		bullet.speed = current_weapon.bullet_speed
	if "damage" in bullet:
		var crit: bool = owner_node and owner_node.has_method("roll_crit") and owner_node.roll_crit()
		var dmg := current_weapon.damage
		if owner_node and owner_node.has_method("get_ranged_damage_mult"):
			dmg = int(round(dmg * owner_node.get_ranged_damage_mult()))
		if crit:
			dmg = int(round(dmg * crit_mult))
		bullet.damage = dmg
		if "is_crit" in bullet:
			bullet.is_crit = crit
	# Plasma DoT override from WeaponData (Lepka Plazma upgrade tweaks these).
	if "dot_radius" in bullet:
		bullet.dot_radius = current_weapon.dot_radius
	if "dot_duration" in bullet:
		bullet.dot_duration = current_weapon.dot_duration
	if "dot_tick_interval" in bullet:
		bullet.dot_tick_interval = current_weapon.dot_tick_interval
	if "dot_tick_damage" in bullet:
		bullet.dot_tick_damage = current_weapon.dot_tick_damage
	if "dot_slow" in bullet:
		bullet.dot_slow = current_weapon.dot_slow
	var scene_root = get_tree().current_scene
	scene_root.add_child(bullet)
