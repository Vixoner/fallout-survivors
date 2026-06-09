class_name Perks

# Canonical perk pool for endless mode. Perk effects are applied where they
# make sense (player.gd's getters for stat-tweak perks; endless.gd for hooks
# like Bloody Mess and Mysterious Stranger). This file is the single source
# of truth for perk ids, names, and descriptions.

const POOL := [
	{
		"id": "krwawa_laznia",
		"name": "KRWAWA ŁAŹNIA",
		"desc": "5% szansa, że wróg eksploduje po śmierci, raniąc innych w pobliżu.",
	},
	{
		"id": "desperado",
		"name": "DESPERADO",
		"desc": "Pistolet strzela dwukrotnie szybciej.",
	},
	{
		"id": "psychopata",
		"name": "PSYCHOPATA",
		"desc": "Zabicie zombie daje +10% PD.",
	},
	{
		"id": "twardziel",
		"name": "TWARDZIEL",
		"desc": "+15% redukcji obrażeń.",
	},
	{
		"id": "lepsze_krytyki",
		"name": "LEPSZE KRYTYKI",
		"desc": "Trafienia krytyczne zadają x3 obrażeń zamiast x2.",
	},
	{
		"id": "wampir",
		"name": "WAMPIR",
		"desc": "Każde zabicie leczy 1 PŻ, gdy zdrowie poniżej 50%.",
	},
	{
		"id": "lekka_stopa",
		"name": "LEKKA STOPA",
		"desc": "+20% prędkości ruchu.",
	},
	{
		"id": "strzelec_wyborowy",
		"name": "STRZELEC WYBOROWY",
		"desc": "+25% obrażeń bronią palną.",
	},
	{
		"id": "rzeznik",
		"name": "RZEŹNIK",
		"desc": "+30% obrażeń w walce wręcz.",
	},
	{
		"id": "hodowca_granatow",
		"name": "HODOWCA GRANATÓW",
		"desc": "Maksymalna liczba granatów: 4 → 6.",
	},
	{
		"id": "tajemniczy_nieznajomy",
		"name": "TAJEMNICZY NIEZNAJOMY",
		"desc": "Co ~30s zaprzyjaźniona wiązka laserowa razi losowego wroga (120 obr).",
	},
]

# All unowned perks, in pool order. Used by the level-up panel — the player
# sees every option they don't already have, then later we'll grey out the
# ones whose requirements aren't met.
static func available_for(owned: Array) -> Array:
	var out := []
	for entry in POOL:
		if not entry["id"] in owned:
			out.append(entry)
	return out

# Placeholder requirements check. Each perk entry can later carry a
# "requirements" Dictionary (e.g. {"luck": 20, "level": 5}); this returns
# (met: bool, missing: String) so the panel can disable + label the card.
static func check_requirements(perk: Dictionary, player: Node) -> Dictionary:
	var reqs: Dictionary = perk.get("requirements", {})
	if reqs.is_empty():
		return {"met": true, "missing": ""}
	var missing_parts: Array = []
	for key in reqs:
		var needed: int = int(reqs[key])
		var have: int = 0
		if key == "level":
			have = int(player.level)
		elif player and key in player:
			have = int(player.get(key))
		if have < needed:
			missing_parts.append("%s %d" % [str(key).to_upper(), needed])
	if missing_parts.is_empty():
		return {"met": true, "missing": ""}
	return {"met": false, "missing": ", ".join(missing_parts)}

# Returns 'count' random unowned perks from the pool (kept for compatibility).
static func roll(owned: Array, count: int = 3) -> Array:
	var pool := available_for(owned)
	pool.shuffle()
	return pool.slice(0, min(count, pool.size()))

static func get_by_id(id: String) -> Dictionary:
	for entry in POOL:
		if entry["id"] == id:
			return entry
	return {}

# Returns enemy type names that count as humanoids for Psychopata's XP bonus.
const HUMANOID_TYPES := ["zombie_small", "zombie_big", "zombie_boss"]

static func is_humanoid(enemy_type: String) -> bool:
	return enemy_type in HUMANOID_TYPES
