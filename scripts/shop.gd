extends CanvasLayer

signal shop_closed

# Pip-Boy paleta kolorów
const C_BG       = Color(0.00, 0.04, 0.00)
const C_PANEL    = Color(0.02, 0.08, 0.02)
const C_CARD     = Color(0.03, 0.11, 0.03)
const C_BORDER   = Color(0.18, 0.55, 0.18)
const C_BRIGHT   = Color(0.42, 1.00, 0.42)
const C_MID      = Color(0.25, 0.72, 0.25)
const C_DIM      = Color(0.14, 0.42, 0.14)
const C_CAPS     = Color(0.55, 0.95, 0.55)
const C_BTN_BUY  = Color(0.05, 0.22, 0.05)
const C_BTN_HOV  = Color(0.08, 0.34, 0.08)
const C_BTN_CONT = Color(0.05, 0.28, 0.05)
const C_BTN_CONT_HOV = Color(0.08, 0.40, 0.08)
const C_BOUGHT   = Color(0.04, 0.12, 0.04)
const C_TAG      = Color(0.20, 0.60, 0.20)

const ALL_ITEMS = [
	{"name": "Talizman Szczęścia",  "type": "PRZEDMIOT", "desc": "Stara figurka znaleziona w gruzach kasyna. Mówią, że przynosi fart.",
		"cost": 5,  "stats": [["luck", 2]]},
	{"name": "Okulary Celownika",   "type": "PRZEDMIOT", "desc": "Wojskowe okulary z zoom x2. Dostrzegasz to, czego inni nie widzą.",
		"cost": 7,  "stats": [["perception", 2]]},
	{"name": "Zbroja Pustkowia",    "type": "PRZEDMIOT", "desc": "Połatana, ciężka, ale wytrzymała. Ogranicza ruchy, ale chroni skórę.",
		"cost": 8,  "stats": [["endurance", 3], ["agility", -1]]},
	{"name": "Pigułki Charyzmatu",  "type": "PRZEDMIOT", "desc": "Skład nieznany, działanie potwierdzone. Skutki uboczne: bóle głowy.",
		"cost": 5,  "stats": [["charisma", 2], ["perception", -1]]},
	{"name": "Nootrop",             "type": "PRZEDMIOT", "desc": "Preparat z przedwojennego laboratorium. Mózg przyspiesza, ciało zwalnia.",
		"cost": 8,  "stats": [["intelligence", 3], ["strength", -1]]},
	{"name": "Buty Kuriera",        "type": "PRZEDMIOT", "desc": "Przetarte, ale lekkie. Przeszły tysiąc mil po pustkowiach.",
		"cost": 7,  "stats": [["agility", 2]]},
	{"name": "Odżywka Siłacza",     "type": "PRZEDMIOT", "desc": "Proszek o wątpliwym smaku. Mięśnie rosną, inteligencja... mniej.",
		"cost": 8,  "stats": [["strength", 3], ["intelligence", -1]]},
	{"name": "Szczęśliwa Moneta",   "type": "PRZEDMIOT", "desc": "Złota moneta sprzed wojny. Przynosi szczęście, ale kradnie zmysły.",
		"cost": 8,  "stats": [["luck", 3], ["perception", -1]]},
	{"name": "Peryskop Zwiadowcy",  "type": "PRZEDMIOT", "desc": "Pozwala widzieć za rogiem. Niezbędne na każdym polu bitwy.",
		"cost": 15,  "stats": [["perception", 3]]},
	{"name": "Sterydy Pustkowi",    "type": "PRZEDMIOT", "desc": "Zakazane przed wojną. Teraz nikt nie zakazuje niczego nikomu.",
		"cost": 8,  "stats": [["strength", 3], ["luck", -1]]},
	{"name": "Apteczka Polowa",     "type": "PRZEDMIOT", "desc": "Wzmacnia ciało i wolę walki. Coś jednak musi ucierpieć.",
		"cost": 5,  "stats": [["endurance", 2], ["charisma", -1]]},
	{"name": "Podręcznik Taktyki",  "type": "PRZEDMIOT", "desc": "Przedwojenny poradnik wojskowy. Więcej myślenia, mniej siły brute.",
		"cost": 10,  "stats": [["intelligence", 2], ["perception", 1], ["strength", -1]]},
	{"name": "Brylantyna Pustkowia", "type": "PRZEDMIOT", "desc": "Puszka z przedwojennej fabryki. Jeden gest włosem — i już cię lubią.",
		"cost": 4,  "stats": [["charisma", 1]]},
	{"name": "Kurs Perswazji",       "type": "PRZEDMIOT", "desc": "Kaseta VHS. Oglądałeś ją pięćdziesiąt razy.",
		"cost": 7,  "stats": [["charisma", 2]]},
	{"name": "Garnitur Dyplomaty",   "type": "PRZEDMIOT", "desc": "Dobrze skrojony, ale krępuje ruchy. Wyglądasz lepiej niż się czujesz.",
		"cost": 9,  "stats": [["charisma", 2], ["agility", -1]]},
	{"name": "Mała Apteczka",        "type": "APTECZKA",  "desc": "Stimpak klasy C. Podstawowy środek medyczny.",
		"cost": 6,  "heal": 0.15},
	{"name": "Średnia Apteczka",     "type": "APTECZKA",  "desc": "Stimpak klasy B. Standardowy wojskowy zestaw medyczny.",
		"cost": 11,  "heal": 0.30},
	{"name": "Duża Apteczka",        "type": "APTECZKA",  "desc": "Stimpak klasy A. Zaawansowany preparat z przedwojennych zapasów.",
		"cost": 17, "heal": 0.50},
	{"name": "Granat Odłamkowy",     "type": "GRANAT",    "desc": "Stary, ale wciąż zabójczy. Wybucha z hukiem w sporym promieniu.",
		"cost": 22, "grenade_type": "frag", "grenade_count": 1},
]

var _player: Node = null
var _stat_labels: Dictionary = {}
var _reroll_cost: int = 5
var _cards_hbox: HBoxContainer = null
var _caps_label: Label = null
var _reroll_cost_lbl: Label = null

# Endless mode adds an extra card row for weapon upgrades. Set by endless.gd
# before adding the shop as a child.
var endless_mode: bool = false

# Weapon upgrades catalogue: id → metadata. `exclusive_with` lists upgrade ids
# that can't be owned simultaneously (mutually-exclusive mechanic changes).
const WEAPON_UPGRADES = [
	{"id": "pistol_long_barrel",  "weapon": "pistol",  "name": "WYDŁUŻONA LUFA",
		"desc": "+30% prędkości pocisku, +25% obrażeń pistoletu.",
		"cost": 30, "exclusive_with": []},
	{"id": "pistol_magnum",       "weapon": "pistol",  "name": "MAGNUM",
		"desc": "+50% obrażeń pistoletu, szybkostrzelność ÷ 1.4.",
		"cost": 35, "exclusive_with": []},
	{"id": "laser_splitter",      "weapon": "laser",   "name": "DZIELNIK WIĄZKI",
		"desc": "Dwie dodatkowe wiązki pod kątem ±45° (60% obrażeń każda).",
		"cost": 45, "exclusive_with": ["laser_focused"]},
	{"id": "laser_focused",       "weapon": "laser",   "name": "SKUPIONA SOCZEWKA",
		"desc": "Wiązka 2× dłuższa, +25% obrażeń, węższy obszar trafienia.",
		"cost": 45, "exclusive_with": ["laser_splitter"]},
	{"id": "plasma_stabilizer",   "weapon": "plasma",  "name": "STABILIZATOR",
		"desc": "Obrażenia bezpośrednie 60 → 110, +30% prędkości pocisku, AoE bez zmian.",
		"cost": 40, "exclusive_with": []},
	{"id": "plasma_sticky",       "weapon": "plasma",  "name": "LEPKA PLAZMA",
		"desc": "AoE 90 → 160, czas 2.5 → 4.0s, -50% prędkości wrogów w obszarze.",
		"cost": 40, "exclusive_with": []},
	{"id": "shotgun_choke",       "weapon": "shotgun", "name": "ZWĘŻKA",
		"desc": "Stożek 32° → 18°, +35% obrażeń śrutu.",
		"cost": 38, "exclusive_with": ["shotgun_autoload"]},
	{"id": "shotgun_autoload",    "weapon": "shotgun", "name": "AUTOŁADOWANIE",
		"desc": "Szybkostrzelność 1.0 → 0.6s, liczba śrutów 12 → 8.",
		"cost": 38, "exclusive_with": ["shotgun_choke"]},
]

func setup(player: Node):
	_player = player

func _ready():
	layer = 10
	if _player:
		_player.movement_blocked = true
		_collect_all_caps()
	_build_ui()

# funkcja która zbiera instant wszystkie kapsle które są w trakcie przyciągania
func _collect_all_caps():
	for cap in get_tree().get_nodes_in_group("caps"):
		if cap.has_method("_collect") and cap._attracting:
			cap._collect()

func _build_ui():
	var overlay = ColorRect.new()
	overlay.color = Color(0.00, 0.02, 0.00, 0.85)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Poziomy podział: sklep i statystyki
	var hbox_main = HBoxContainer.new()
	hbox_main.add_theme_constant_override("separation", 20)
	hbox_main.custom_minimum_size = Vector2(1500, 680)
	center.add_child(hbox_main)

	# Panel sklepu
	var shop_panel = PanelContainer.new()
	shop_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_panel.add_theme_stylebox_override("panel", _flat(C_PANEL, C_BORDER, 2, 4))
	hbox_main.add_child(shop_panel)

	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 18)
	shop_panel.add_child(root_vbox)

	var header = _label("// SKLEP //", 36, C_BRIGHT)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(header)

	root_vbox.add_child(_hsep())

	_caps_label = _label("KAPSLE: %d" % _player.caps, 19, C_CAPS)
	_caps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(_caps_label)

	_cards_hbox = HBoxContainer.new()
	_cards_hbox.add_theme_constant_override("separation", 16)
	_cards_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_cards_hbox)
	_spawn_cards()

	root_vbox.add_child(_hsep())

	var bottom = HBoxContainer.new()

	# Reroll (lewa strona)
	var reroll_vbox = VBoxContainer.new()
	reroll_vbox.add_theme_constant_override("separation", 4)
	var reroll_btn = _button("[ ODŚWIEŻ ]", 17, C_BTN_BUY, C_BTN_HOV)
	reroll_btn.custom_minimum_size = Vector2(180, 42)
	reroll_btn.pressed.connect(_on_reroll.bind(reroll_btn))
	reroll_vbox.add_child(reroll_btn)
	_reroll_cost_lbl = _label("KOSZT: %d KAPSLI" % _reroll_cost, 12, C_CAPS)
	_reroll_cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reroll_vbox.add_child(_reroll_cost_lbl)
	var reroll_margin = MarginContainer.new()
	reroll_margin.add_theme_constant_override("margin_left", 12)
	reroll_margin.add_theme_constant_override("margin_bottom", 8)
	reroll_margin.add_child(reroll_vbox)
	bottom.add_child(reroll_margin)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)

	# Kontynuuj (prawa strona)
	var cont_btn = _button("[ KONTYNUUJ > ]", 20, C_BTN_CONT, C_BTN_CONT_HOV)
	cont_btn.custom_minimum_size = Vector2(220, 50)
	cont_btn.pressed.connect(_on_continue)
	var btn_margin = MarginContainer.new()
	btn_margin.add_theme_constant_override("margin_right", 12)
	btn_margin.add_theme_constant_override("margin_bottom", 8)
	btn_margin.add_child(cont_btn)
	bottom.add_child(btn_margin)
	root_vbox.add_child(bottom)

	# Panel statystyk
	hbox_main.add_child(_build_stats_panel())

	# Scanlines na samej górze
	var scanlines = ColorRect.new()
	scanlines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scanlines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scan_mat = ShaderMaterial.new()
	scan_mat.shader = _make_scanline_shader()
	scanlines.material = scan_mat
	add_child(scanlines)

func _build_stats_panel() -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(260, 0)
	panel.add_theme_stylebox_override("panel", _flat(C_PANEL, C_BORDER, 2, 4))

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title = _label("// STATYSTYKI //", 18, C_BRIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(_hsep())

	var stats = [
		["SIŁA",           "strength",     "Wpływa na obrażenia w walce wręcz."],
		["PERCEPCJA",      "perception",   "Wpływa na obrażenia ataku broni palnej."],
		["WYTRZYMAŁOŚĆ",   "endurance",    "Wpływa na maksymalną liczbę punktów zdrowia i odporność na obrażenia."],
		["CHARYZMA",       "charisma",     "Wpływa na ceny w sklepie."],
		["INTELIGENCJA",   "intelligence", "Wpływa na odległość przyciągania kapsli które wypadają z przeciwników."],
		["ZWINNOŚĆ",       "agility",      "Wpływa na prędkość poruszania się."],
		["SZCZĘŚCIE",      "luck",         "Wpływa na szansę obrażeń krytycznych."],
	]

	# Tooltip z wyjaśnieniem statystyk
	var tooltip = _build_tooltip()
	add_child(tooltip)

	for entry in stats:
		var row = PanelContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row_style_normal = _flat(C_CARD, Color(0,0,0,0), 0, 6)
		var row_style_hover  = _flat(Color(0.06, 0.20, 0.06), C_BORDER, 1, 6)
		row.add_theme_stylebox_override("panel", row_style_normal)
		row.mouse_entered.connect(_on_stat_hover.bind(entry[0], entry[2], tooltip, row, row_style_hover))
		row.mouse_exited.connect(_on_stat_exit.bind(tooltip, row, row_style_normal))
		vbox.add_child(row)

		var inner = HBoxContainer.new()
		inner.add_theme_constant_override("separation", 8)
		row.add_child(inner)

		var name_lbl = _label(entry[0], 14, C_MID)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner.add_child(name_lbl)

		var val = _player.get(entry[1]) if _player else 0
		var val_lbl = _label(str(val), 16, C_BRIGHT)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		inner.add_child(val_lbl)
		_stat_labels[entry[1]] = val_lbl

		vbox.add_child(_hsep())

	return panel

func _spawn_cards():
	var pool = ALL_ITEMS.duplicate()
	pool.shuffle()
	for item in pool.slice(0, 3):
		_cards_hbox.add_child(_make_card(item))
	if endless_mode:
		_spawn_upgrade_cards()

func _spawn_upgrade_cards():
	# A second row of weapon-upgrade cards. Filter to upgrades the player
	# doesn't yet own and isn't blocked from owning by exclusivity.
	if _player == null or not "weapon_upgrades" in _player:
		return
	var owned: Array = _player.weapon_upgrades
	var available: Array = []
	for upg in WEAPON_UPGRADES:
		if upg["id"] in owned:
			continue
		var blocked := false
		for ex in upg.get("exclusive_with", []):
			if ex in owned:
				blocked = true
				break
		if blocked:
			continue
		available.append(upg)
	available.shuffle()
	if available.is_empty():
		return
	# Header separator
	var sep_lbl := _label("// MODYFIKACJE BRONI //", 17, C_BRIGHT)
	sep_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cards_hbox.get_parent().add_child(sep_lbl)
	var upg_hbox := HBoxContainer.new()
	upg_hbox.add_theme_constant_override("separation", 16)
	upg_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_hbox.get_parent().add_child(upg_hbox)
	for upg in available.slice(0, 3):
		upg_hbox.add_child(_make_upgrade_card(upg))

func _make_upgrade_card(upg: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _flat(C_CARD, C_BORDER, 1, 2, 14, 14))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var type_lbl := _label("[ %s ]" % str(upg["weapon"]).to_upper(), 11, C_TAG)
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(type_lbl)

	var name_lbl := _label(upg["name"], 17, C_BRIGHT)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_lbl)

	vbox.add_child(_hsep())

	var desc_lbl := _label(upg["desc"], 12, C_MID)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_lbl)

	var actual_cost: int = _get_actual_cost(int(upg["cost"]))
	var cost_text := "KOSZT: %d KAPSLI" % actual_cost
	var cost_lbl := _label(cost_text, 13, C_CAPS)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(cost_lbl)

	vbox.add_child(_hsep())

	var buy_btn := _button("[ KUP ]", 16, C_BTN_BUY, C_BTN_HOV)
	buy_btn.custom_minimum_size = Vector2(0, 40)
	buy_btn.pressed.connect(_on_buy_upgrade.bind(upg, buy_btn, cost_lbl, actual_cost))
	vbox.add_child(buy_btn)
	return card

func _on_buy_upgrade(upg: Dictionary, btn: Button, cost_lbl: Label, actual_cost: int):
	if _player == null or btn.disabled:
		return
	if _player.caps < actual_cost:
		var tween = create_tween()
		tween.tween_property(cost_lbl, "modulate", Color(1, 0.2, 0.2), 0.08)
		tween.tween_property(cost_lbl, "modulate", Color(1, 1, 1), 0.25)
		return
	_player.caps -= actual_cost
	_player.add_caps(0)
	if _player.has_method("add_weapon_upgrade"):
		_player.add_weapon_upgrade(str(upg["id"]))
	_caps_label.text = "KAPSLE: %d" % _player.caps
	btn.text = "[ KUPIONO ]"
	btn.disabled = true
	btn.add_theme_stylebox_override("normal", _flat(C_BOUGHT, C_DIM, 1, 2))
	btn.add_theme_stylebox_override("hover",  _flat(C_BOUGHT, C_DIM, 1, 2))

func _on_reroll(_btn: Button):
	if _player == null:
		return
	if _player.caps < _reroll_cost:
		var tween = create_tween()
		tween.tween_property(_reroll_cost_lbl, "modulate", Color(1, 0.2, 0.2), 0.08)
		tween.tween_property(_reroll_cost_lbl, "modulate", Color(1, 1, 1), 0.25)
		return
	_player.caps -= _reroll_cost
	_player.add_caps(0)
	_caps_label.text = "KAPSLE: %d" % _player.caps
	_reroll_cost = int(_reroll_cost * 1.25)
	_reroll_cost_lbl.text = "KOSZT: %d KAPSLI" % _reroll_cost
	for child in _cards_hbox.get_children():
		child.queue_free()
	_spawn_cards()

func _make_card(item: Dictionary) -> Control:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _flat(C_CARD, C_BORDER, 1, 2, 14, 14))

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	# Tag typu
	var type_lbl = _label("[ " + item.get("type", "PRZEDMIOT") + " ]", 11, C_TAG)
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(type_lbl)

	# Nazwa
	var name_lbl = _label(item["name"].to_upper(), 19, C_BRIGHT)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_lbl)

	vbox.add_child(_hsep())

	# Opis
	var desc_lbl = _label(item["desc"], 13, C_MID)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_lbl)

	# Stat bonuses
	const STAT_NAMES = {
		"strength": "SIŁA", "perception": "PERCEPCJA", "endurance": "WYTRZYMAŁOŚĆ",
		"charisma": "CHARYZMA", "intelligence": "INTELIGENCJA",
		"agility": "ZWINNOŚĆ", "luck": "SZCZĘŚCIE",
	}
	if item.has("heal"):
		var pct = int(item["heal"] * 100)
		var s = _label("+%d%%  HP" % pct, 15, Color(0.3, 1.0, 0.4))
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(s)
	elif item.has("grenade_type"):
		var count: int = int(item.get("grenade_count", 1))
		var s = _label("+%d  GRANAT" % count, 15, Color(1.0, 0.6, 0.3))
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(s)
	else:
		for entry in item.get("stats", []):
			var stat: String = entry[0]
			var val: int = entry[1]
			var prefix = "+" if val > 0 else ""
			var color = C_BRIGHT if val > 0 else Color(1.0, 0.35, 0.35)
			var stat_name = STAT_NAMES.get(stat, stat.to_upper())
			var s = _label("%s%d  %s" % [prefix, val, stat_name], 15, color)
			s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(s)

	# Koszt z uwzględnieniem charyzmy
	var actual_cost = _get_actual_cost(item["cost"])
	var cost_text = "KOSZT: %d KAPSLI" % actual_cost
	if actual_cost != item["cost"]:
		cost_text += "  [%d]" % item["cost"]
	var cost_lbl = _label(cost_text, 13, C_CAPS)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(cost_lbl)

	vbox.add_child(_hsep())

	# Buy button
	var buy_btn = _button("[ KUP ]", 17, C_BTN_BUY, C_BTN_HOV)
	buy_btn.custom_minimum_size = Vector2(0, 42)
	buy_btn.pressed.connect(_on_buy.bind(item, buy_btn, cost_lbl, actual_cost))
	vbox.add_child(buy_btn)

	# Padding pod przyciskiem
	var pad = Control.new()
	pad.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(pad)

	return card

func _get_actual_cost(base_cost: int) -> int:
	if _player and _player.has_method("get_price_mult"):
		return max(1, int(round(base_cost * _player.get_price_mult())))
	return base_cost

func _on_buy(item: Dictionary, btn: Button, cost_lbl: Label, actual_cost: int):
	if _player == null or btn.disabled:
		return
	if _player.caps < actual_cost:
		var tween = create_tween()
		tween.tween_property(cost_lbl, "modulate", Color(1, 0.2, 0.2), 0.08)
		tween.tween_property(cost_lbl, "modulate", Color(1, 1, 1), 0.25)
		return

	# Grenade items: refuse purchase (no deduction yet) if at the per-type cap.
	# 4 mirrors player.MAX_GRENADES_PER_TYPE — if you tune that, update here too.
	if item.has("grenade_type"):
		var gtype: String = item["grenade_type"]
		var cur_count: int = 0
		if "grenades" in _player:
			cur_count = int(_player.grenades.get(gtype, 0))
		if cur_count >= 4:
			var tween = create_tween()
			tween.tween_property(cost_lbl, "modulate", Color(1, 0.2, 0.2), 0.08)
			tween.tween_property(cost_lbl, "modulate", Color(1, 1, 1), 0.25)
			return

	_player.caps -= actual_cost
	_player.add_caps(0)
	if item.has("heal"):
		var heal_amount = int(_player.max_hp * item["heal"])
		_player.current_hp = min(_player.current_hp + heal_amount, _player.max_hp)
		_player._update_hp_bar()
	elif item.has("grenade_type"):
		_player.add_grenade(item["grenade_type"], int(item.get("grenade_count", 1)))
	else:
		for entry in item.get("stats", []):
			var stat: String = entry[0]
			_player.set(stat, _player.get(stat) + entry[1])
			if _stat_labels.has(stat):
				_stat_labels[stat].text = str(_player.get(stat))
		if _player.has_method("recalculate_stats"):
			_player.recalculate_stats()
	_caps_label.text = "KAPSLE: %d" % _player.caps

	btn.text = "[ KUPIONO ]"
	btn.disabled = true
	btn.add_theme_stylebox_override("normal", _flat(C_BOUGHT, C_DIM, 1, 2))
	btn.add_theme_stylebox_override("hover",  _flat(C_BOUGHT, C_DIM, 1, 2))

func _build_tooltip() -> Control:
	var panel = PanelContainer.new()
	panel.visible = false
	panel.custom_minimum_size = Vector2(150, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.z_index = 20
	panel.add_theme_stylebox_override("panel", _flat(C_PANEL, C_BRIGHT, 1, 6))

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	panel.add_child(vbox)

	var title = _label("", 12, C_BRIGHT)
	vbox.add_child(title)
	vbox.add_child(_hsep())
	var desc = _label("", 11, C_MID)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(140, 0)
	desc.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vbox.add_child(desc)

	# Przechowaj referencje jako metadane na panelu
	panel.set_meta("title_lbl", title)
	panel.set_meta("desc_lbl", desc)

	return panel

func _on_stat_hover(stat_name: String, desc: String, tooltip: Control, row: Control, hover_style: StyleBoxFlat):
	row.add_theme_stylebox_override("panel", hover_style)
	tooltip.get_meta("title_lbl").text = stat_name
	tooltip.get_meta("desc_lbl").text = desc
	tooltip.reset_size()
	tooltip.visible = true
	var row_rect = row.get_global_rect()
	tooltip.set_position(Vector2(row_rect.end.x + 20, row_rect.position.y))

func _on_stat_exit(tooltip: Control, row: Control, normal_style: StyleBoxFlat):
	row.add_theme_stylebox_override("panel", normal_style)
	tooltip.visible = false

func _on_continue():
	if _player:
		_player.movement_blocked = false
	emit_signal("shop_closed")
	queue_free()

# --- Helpers ---

func _label(text: String, size: int, color: Color) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	return lbl

func _button(text: String, size: int, bg: Color, bg_hover: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", size)
	btn.add_theme_color_override("font_color", C_BRIGHT)
	btn.add_theme_stylebox_override("normal", _flat(bg, C_BORDER, 1, 2))
	btn.add_theme_stylebox_override("hover",  _flat(bg_hover, C_BRIGHT, 1, 2))
	btn.add_theme_stylebox_override("focus",  _flat(bg, C_BRIGHT, 2, 2))
	return btn

func _flat(bg: Color, border: Color, bw: int = 1, margin: int = 12, ml: int = -1, mr: int = -1) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(2)
	var m = margin if ml == -1 else ml
	s.content_margin_left   = m
	s.content_margin_right  = mr if mr != -1 else m
	s.content_margin_top    = margin
	s.content_margin_bottom = margin
	return s

func _hsep() -> HSeparator:
	var sep = HSeparator.new()
	var ss = StyleBoxFlat.new()
	ss.bg_color = C_BORDER
	ss.content_margin_top = 1
	sep.add_theme_stylebox_override("separator", ss)
	return sep

func _make_scanline_shader() -> Shader:
	var sh = Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float scroll_speed = 30.0;
uniform float flicker_speed = 8.0;
uniform float flicker_strength = 0.08;

void fragment() {
	// Przesuwające się paski
	float line = mod(FRAGCOORD.y + TIME * scroll_speed, 3.0);
	float scanline = line < 1.0 ? 0.1 : 0.0;

	// Bardzo subtelne globalne miganie całego ekranu
	float flicker = 1.0 - flicker_strength * (0.5 + 0.5 * sin(TIME * flicker_speed));

	// Rzadka jasna linia która przesuwa się w dół
	float sweep_y = mod(FRAGCOORD.y - TIME * 120.0, 800.0);
	float sweep = exp(-sweep_y * 0.04) * 0.06;

	COLOR = vec4(0.0, sweep, 0.0, scanline * flicker);
}
"""
	return sh
