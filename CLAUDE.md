# CLAUDE.md — Project Guidelines

## Project Overview

A top-down 2D survival shooter in **Godot 4 (GDScript)**. The player fights waves of zombies using a melee auto-attack and (planned) player-aimed projectile weapons. Between waves a shop opens where the player can upgrade SPECIAL stats or buy weapons.

---

## Project Structure

```
res://
├── scenes/
│   ├── main.tscn         # Root scene, manages waves and game state
│   ├── player.tscn       # Player character (CharacterBody2D)
│   ├── enemy.tscn        # Standard zombie (CharacterBody2D)
│   ├── enemy_big.tscn    # Big zombie variant
│   ├── bullet.tscn       # Projectile scene (used by ranged weapons)
│   └── cap.tscn          # Currency pickup (bottle caps)
└── scripts/
    ├── main.gd           # Wave spawning, shop trigger, pause menu
    ├── player.gd         # Player movement, auto-attack, stats, HP
    ├── enemy.gd          # Enemy AI, animations, death, champion mode
    ├── bullet.gd         # Projectile movement and hit logic
    ├── cap.gd            # Cap pickup logic
    ├── game_constants.gd # Autoload — MAP_WIDTH, MAP_HEIGHT, etc.
    ├── shop.gd           # Shop UI and stat/weapon upgrades
    └── pause_menu.gd     # Pause overlay
```

---

## Architecture Decisions

- **No EventBus** — nodes communicate via direct references or signals.
- **Groups used**: `"player"`, `"enemies"`, `"hp_bar"`, `"hp_label"`, `"caps_label"`, `"wave_label"`.
- **GameConstants** is an autoload (`game_constants.gd`) — access as `GameConstants.MAP_WIDTH` etc.
- **Z-index conventions**: player = 6, enemies = 5, dead enemies = 3, UI labels = 10.
- **process_mode = PAUSABLE** on all gameplay nodes; main.gd uses `PROCESS_MODE_ALWAYS`.
- Damage numbers are spawned as temporary `Label` nodes directly on the root scene child.

---

## Player (player.gd / player.tscn)

**Node structure:**
- `CharacterBody2D` (player.gd)
  - `BodySprite` — Sprite2D, body animations
  - `WeaponSprite` — Sprite2D, weapon visual
  - `AnimationPlayer` — body animations (run_down/up/side, idle_down/up/side)
  - `WeaponAnimationPlayer` — weapon animations (bat_attack_down/up/side/right)
  - `AttackRange` — Area2D, used by auto-attack to find nearest enemy

**Movement:** WASD / arrow keys. Speed scales with `agility` stat.

**Auto-attack (MUST ALWAYS REMAIN ACTIVE):**
- `handle_knife_autoattack(delta)` — fires every `knife_cooldown` (0.5s) at nearest enemy in `AttackRange`.
- Damage via `get_melee_damage()` with crit via `roll_crit()`.
- Do NOT remove or disable this system when adding new weapons.

**SPECIAL stats** (all start at 5):
| Stat | Effect |
|------|--------|
| strength | melee damage (`25 + strength * 3`) |
| perception | (reserved for future use) |
| endurance | max HP, damage reduction |
| charisma | shop price multiplier |
| intelligence | cap attract radius |
| agility | move speed |
| luck | crit chance (`luck * 3%`) |

**HP system:** `take_damage()` applies damage reduction, triggers 1s invincibility + blink tween. Call `recalculate_stats()` after changing SPECIAL stats.

---

## Enemy (enemy.gd / enemy.tscn / enemy_big.tscn)

- Chases player, attacks on contact (`contact_distance`).
- Separation force prevents stacking (`SEPARATION_RADIUS = 80`, `SEPARATION_STRENGTH = 180`).
- `make_champion()` — doubles HP/damage, scales size, adds red pulsing tween.
- `take_damage(amount, is_crit)` — triggers hit flash shader + damage number label.
- On death: emits `died(position, caps_count)` signal, plays death animation, fades out, `queue_free()`.
- Must be in group `"enemies"`.

---

## Main (main.gd)

- Manages wave progression via `WAVES` array (5 waves defined).
- Each wave: `cooldown`, `group_size`, enemy type counts + champion counts.
- After each wave: `show_shop()` → awaits `shop.shop_closed` → `start_wave(next)`.
- `spawn_caps(position, count, value)` — spawns cap pickups on enemy death.
- Pressing **Enter** kills all enemies instantly (debug shortcut).

---

## Weapon System — Implementation Goal

### Design Intent
The player should be able to equip one **active weapon** at a time (in addition to the always-on knife auto-attack). Active weapons fire projectiles **toward the mouse cursor** on some trigger (e.g. auto-fire, or on click).

### Planned Weapon Architecture

Add a `WeaponManager` to the player (or as a child node) that:
1. Holds the currently equipped active weapon as a resource/data object.
2. Exposes `fire(direction: Vector2)` which the player calls.
3. Is completely separate from `handle_knife_autoattack()` — do NOT merge them.

**Suggested weapon data structure (Resource):**
```gdscript
# weapon_data.gd
class_name WeaponData extends Resource

@export var name: String
@export var damage: int
@export var fire_rate: float       # seconds between shots
@export var bullet_speed: float
@export var bullet_scene: PackedScene
@export var spread_angle: float = 0.0   # for shotgun-type weapons
@export var projectile_count: int = 1
```

**Firing direction:**
```gdscript
# In player.gd — get aim direction toward mouse
var aim_dir = global_position.direction_to(get_global_mouse_position())
```

**Bullet spawning:** Bullets should be added to the main scene (not player), so they persist after player death. Pass the main node or use `get_tree().root.get_child(0).add_child(bullet)`.

### Weapon IDs (planned, align with shop.gd)
- `"pistol"` — single shot, moderate damage, fast fire rate
- `"shotgun"` — spread of 3–5 pellets, slow fire rate
- `"rifle"` — single shot, high damage, medium fire rate

### What NOT to do
- Do not rename or remove `handle_knife_autoattack()`.
- Do not add weapon logic to enemy.gd or main.gd.
- Do not use `_input()` in player.gd for weapon firing if it conflicts with pause handling — prefer checking `Input.is_action_pressed()` in `_physics_process`.

---

## Bullet (bullet.gd / bullet.tscn)

- Moves in a set direction at fixed speed.
- On hit: call `enemy.take_damage(damage, is_crit)` then `queue_free()`.
- Should have a `CollisionShape2D` and belong to appropriate collision layers.

---

## Coding Conventions

- **GDScript 4** — use typed variables where practical (`var x: float`).
- Comments in **Polish** are fine (existing code uses Polish comments) — new code can use English.
- Animations are named `action_direction` (e.g. `"run_down"`, `"attack_left"`).
- Always guard `is_instance_valid()` before accessing nodes after `await`.
- Use `set_deferred("disabled", true)` for collision shape changes during physics.
- Tweens: always kill existing tween before creating a new one on the same property.

---

## Known Constraints / Do Not Touch

- `game_constants.gd` is an autoload — do not restructure it without updating all references.
- `WeaponAnimationPlayer` plays `bat_attack_*` animations — keep these working for the knife.
- The shop is instantiated dynamically via script (`SHOP_SCRIPT.new()`) — it is not in the scene tree at start.
- `_in_shop` flag in main.gd blocks escape/pause while shop is open — respect this when adding UI.
