class_name WeaponData extends Resource

@export var name: String = ""
@export var damage: int = 10
@export var fire_rate: float = 0.4
@export var bullet_speed: float = 800.0
@export var bullet_scene: PackedScene
@export var spread_angle: float = 0.0
@export var projectile_count: int = 1

static func make_pistol() -> WeaponData:
	var w := WeaponData.new()
	w.name = "Pistol"
	w.damage = 12
	w.fire_rate = 0.4
	w.bullet_speed = 900.0
	w.bullet_scene = load("res://scenes/bullet.tscn")
	return w
