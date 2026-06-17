class_name WeaponData extends Resource

@export var name: String = ""
@export var damage: int = 10
@export var fire_rate: float = 0.4
@export var bullet_speed: float = 800.0
@export var bullet_scene: PackedScene
@export var spread_angle: float = 0.0
@export var projectile_count: int = 1
@export var spread_random: bool = false
@export var is_beam: bool = false
@export var beam_length: float = 700.0
@export var beam_width: float = 28.0
@export var fire_sound: AudioStream

# Endless-mode upgrade flags / DoT params (applied by player._build_weapon_data).
@export var splitter: bool = false           # Laser: also fire ±45° side beams at 60% damage
@export var dot_radius: float = 90.0          # Plasma DoT puddle radius
@export var dot_duration: float = 2.5         # Plasma DoT puddle duration
@export var dot_tick_interval: float = 0.4
@export var dot_tick_damage: int = 8
@export var dot_slow: float = 0.0             # Plasma Lepka: slow multiplier in AoE (0 = none, 0.5 = halve)

# Karabin Amunicja Wybuchowa — eksplozja przy trafieniu z 50% obrażeń pocisku w obszarze.
@export var explosive: bool = false
@export var explosive_radius: float = 90.0
@export var explosive_dmg_ratio: float = 0.5

# Karabin Zatrute Naboje — DoT 1 obr/sek na trafionym celu, kolejne trafienia odświeżają.
@export var poison: bool = false
@export var poison_duration: float = 5.0
@export var poison_tick_dmg: int = 1

static func make_pistol() -> WeaponData:
	var w := WeaponData.new()
	w.name = "Pistol"
	w.damage = 14
	w.fire_rate = 0.4
	w.bullet_speed = 1350.0
	w.bullet_scene = load("res://scenes/bullet.tscn")
	w.fire_sound = load("res://assets/audio/weapons/pistol_fire.mp3")
	return w

# Endless mode's slot-1 default. Functionally same as pistol but faster fire rate
# and slightly more damage — it's the "starter weapon" you always have.
static func make_karabin() -> WeaponData:
	var w := WeaponData.new()
	w.name = "Karabin"
	w.damage = 14
	w.fire_rate = 0.20
	w.bullet_speed = 1450.0
	w.bullet_scene = load("res://scenes/bullet.tscn")
	w.fire_sound = load("res://assets/audio/weapons/karabin_fire.mp3")
	return w

static func make_laser() -> WeaponData:
	var w := WeaponData.new()
	w.name = "Laser"
	w.damage = 24
	w.fire_rate = 0.6
	w.is_beam = true
	w.beam_length = 1050.0
	w.beam_width = 52.0
	w.fire_sound = load("res://assets/audio/weapons/laser_fire.mp3")
	return w

static func make_plasma() -> WeaponData:
	var w := WeaponData.new()
	w.name = "Plasma"
	w.damage = 60
	w.fire_rate = 1.1
	w.bullet_speed = 520.0
	w.bullet_scene = load("res://scenes/plasma_bolt.tscn")
	w.fire_sound = load("res://assets/audio/weapons/plasma_fire.mp3")
	return w

static func make_shotgun() -> WeaponData:
	var w := WeaponData.new()
	w.name = "Shotgun"
	w.damage = 7
	w.fire_rate = 1.0
	w.bullet_speed = 1150.0
	w.bullet_scene = load("res://scenes/pellet.tscn")
	w.projectile_count = 10
	w.spread_angle = 0.90     # ~32° cone 0.55
	w.spread_random = true    # random scatter within the cone per shot
	w.fire_sound = load("res://assets/audio/weapons/shotgun_fire.mp3")
	return w
