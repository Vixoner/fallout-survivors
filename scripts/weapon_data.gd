class_name WeaponData extends Resource

@export var name: String = ""
@export var damage: int = 10
@export var fire_rate: float = 0.4
@export var bullet_speed: float = 800.0
@export var bullet_scene: PackedScene
@export var spread_angle: float = 0.0
@export var projectile_count: int = 1
@export var is_beam: bool = false
@export var beam_length: float = 700.0
@export var beam_width: float = 28.0
@export var fire_sound: AudioStream

static func make_pistol() -> WeaponData:
	var w := WeaponData.new()
	w.name = "Pistol"
	w.damage = 12
	w.fire_rate = 0.4
	w.bullet_speed = 1350.0
	w.bullet_scene = load("res://scenes/bullet.tscn")
	w.fire_sound = load("res://assets/audio/weapons/pistol_fire.wav")
	return w

static func make_laser() -> WeaponData:
	var w := WeaponData.new()
	w.name = "Laser"
	w.damage = 24
	w.fire_rate = 0.6
	w.is_beam = true
	w.beam_length = 1050.0
	w.beam_width = 52.0
	w.fire_sound = load("res://assets/audio/weapons/laser_fire.wav")
	return w

static func make_plasma() -> WeaponData:
	var w := WeaponData.new()
	w.name = "Plasma"
	w.damage = 60
	w.fire_rate = 1.1
	w.bullet_speed = 520.0
	w.bullet_scene = load("res://scenes/plasma_bolt.tscn")
	w.fire_sound = load("res://assets/audio/weapons/plasma_fire.wav")
	return w
