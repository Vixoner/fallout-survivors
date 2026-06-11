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
		"cost": 7,  "stats": [["luck", 4]]},
	{"name": "Okulary Celownika",   "type": "PRZEDMIOT", "desc": "Wojskowe okulary z zoom x2. Dostrzegasz to, czego inni nie widzą.",
		"cost": 9,  "stats": [["perception", 4]]},
	{"name": "Zbroja Pustkowia",    "type": "PRZEDMIOT", "desc": "Połatana, ciężka, ale wytrzymała. Ogranicza ruchy, ale chroni skórę.",
		"cost": 10,  "stats": [["endurance", 6], ["agility", -3]]},
	{"name": "Pigułki Charyzmatu",  "type": "PRZEDMIOT", "desc": "Skład nieznany, działanie potwierdzone. Skutki uboczne: bóle głowy.",
		"cost": 7,  "stats": [["charisma", 5], ["perception", -2]]},
	{"name": "Nootrop",             "type": "PRZEDMIOT", "desc": "Preparat z przedwojennego laboratorium. Mózg przyspiesza, ciało zwalnia.",
		"cost": 10,  "stats": [["intelligence", 6], ["strength", -3]]},
	{"name": "Buty Kuriera",        "type": "PRZEDMIOT", "desc": "Przetarte, ale lekkie. Przeszły tysiąc mil po pustkowiach.",
		"cost": 8,  "stats": [["agility", 4]]},
	{"name": "Odżywka Siłacza",     "type": "PRZEDMIOT", "desc": "Proszek o wątpliwym smaku. Mięśnie rosną, inteligencja... mniej.",
		"cost": 10,  "stats": [["strength", 6], ["intelligence", -3]]},
	{"name": "Szczęśliwa Moneta",   "type": "PRZEDMIOT", "desc": "Złota moneta sprzed wojny. Przynosi szczęście, ale kradnie zmysły.",
		"cost": 10,  "stats": [["luck", 6], ["perception", -3]]},
	{"name": "Peryskop Zwiadowcy",  "type": "PRZEDMIOT", "desc": "Pozwala widzieć za rogiem. Niezbędne na każdym polu bitwy.",
		"cost": 18,  "stats": [["perception", 6]]},
	{"name": "Sterydy Pustkowi",    "type": "PRZEDMIOT", "desc": "Zakazane przed wojną. Teraz nikt nie zakazuje niczego nikomu.",
		"cost": 10,  "stats": [["strength", 6], ["luck", -3]]},
	{"name": "Apteczka Polowa",     "type": "PRZEDMIOT", "desc": "Wzmacnia ciało i wolę walki. Coś jednak musi ucierpieć.",
		"cost": 7,  "stats": [["endurance", 5], ["charisma", -3]]},
	{"name": "Podręcznik Taktyki",  "type": "PRZEDMIOT", "desc": "Przedwojenny poradnik wojskowy. Więcej myślenia, mniej siły brute.",
		"cost": 12,  "stats": [["intelligence", 4], ["perception", 3], ["strength", -3]]},
	{"name": "Brylantyna Pustkowia", "type": "PRZEDMIOT", "desc": "Puszka z przedwojennej fabryki. Jeden gest włosem — i już cię lubią.",
		"cost": 5,  "stats": [["charisma", 3]]},
	{"name": "Kurs Perswazji",       "type": "PRZEDMIOT", "desc": "Kaseta VHS. Oglądałeś ją pięćdziesiąt razy.",
		"cost": 9,  "stats": [["charisma", 5]]},
	{"name": "Garnitur Dyplomaty",   "type": "PRZEDMIOT", "desc": "Dobrze skrojony, ale krępuje ruchy. Wyglądasz lepiej niż się czujesz.",
		"cost": 11,  "stats": [["charisma", 5], ["agility", -3]]},
	{"name": "Eksperymentalny Booster", "type": "PRZEDMIOT", "desc": "Niemal sztuka alchemii. Daje ci moc, ale niszczy resztę.",
		"cost": 20,  "stats": [["strength", 8], ["endurance", -5]]},
	{"name": "Wszczep Cybernetyczny", "type": "PRZEDMIOT", "desc": "Nielegalna implantacja prosto z czarnego rynku. Tańsze niż prawdziwe oko.",
		"cost": 25,  "stats": [["perception", 8], ["charisma", -4]]},
	{"name": "Mieszanka Wojownika",  "type": "PRZEDMIOT", "desc": "Nieznany koktajl z laboratorium. Strzeż się skutków ubocznych.",
		"cost": 22,  "stats": [["endurance", 7], ["agility", 3], ["intelligence", -5]]},
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
# Refresh cap (endless only): base 1 + 1 per 5 charisma. Story has no refresh
# at all so this is never consulted.
var _refresh_cap: int = 1
var _refresh_used: int = 0
var _cards_hbox: HBoxContainer = null
var _caps_label: Label = null
var _reroll_cost_lbl: Label = null
var _reroll_btn: Button = null
var _tooltip: Control = null

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
	{"id": "karabin_drum_mag",    "weapon": "karabin", "name": "MAGAZYNEK BĘBNOWY",
		"desc": "Szybkostrzelność karabinu × 1.43 (0.20s → 0.14s).",
		"cost": 35, "exclusive_with": []},
	{"id": "karabin_ap_rounds",   "weapon": "karabin", "name": "POCISKI PRZECIWPANCERNE",
		"desc": "+40% obrażeń karabinu, -20% prędkości pocisku.",
		"cost": 40, "exclusive_with": []},
	{"id": "karabin_explosive",   "weapon": "karabin", "name": "AMUNICJA WYBUCHOWA",
		"desc": "+25% obrażeń bazowych. Każdy pocisk wybucha przy trafieniu (50% obrażeń w obszarze).",
		"cost": 50, "exclusive_with": ["karabin_poison"]},
	{"id": "karabin_poison",      "weapon": "karabin", "name": "ZATRUTE NABOJE",
		"desc": "Trafienia nakładają zatrucie: 1 obr / sek przez 5 sek. Kolejne trafienia odświeżają.",
		"cost": 50, "exclusive_with": ["karabin_explosive"]},
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
		# Endless: refresh budget = 1 + floor(charisma/5). Story doesn't refresh.
		_refresh_cap = 1 + int(_player.charisma / 5)
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

	_tooltip = GameState.build_stat_tooltip(self)

	_cards_hbox = HBoxContainer.new()
	_cards_hbox.add_theme_constant_override("separation", 16)
	_cards_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_cards_hbox)
	_spawn_cards()

	root_vbox.add_child(_hsep())

	var bottom = HBoxContainer.new()

	# Reroll (lewa strona) — endless only. Story shop has no refresh.
	if endless_mode:
		var reroll_vbox = VBoxContainer.new()
		reroll_vbox.add_theme_constant_override("separation", 4)
		_reroll_btn = _button("[ ODŚWIEŻ ]", 17, C_BTN_BUY, C_BTN_HOV)
		_reroll_btn.custom_minimum_size = Vector2(180, 42)
		_reroll_btn.pressed.connect(_on_reroll.bind(_reroll_btn))
		reroll_vbox.add_child(_reroll_btn)
		_reroll_cost_lbl = _label(_refresh_status_text(), 12, C_CAPS)
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

	# Tooltip z wyjaśnieniem statystyk (tworzony wcześniej w _build_ui)
	var tooltip = _tooltip

	for stat_key in GameState.STAT_ORDER:
		var row = PanelContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row_style_normal = _flat(C_CARD, Color(0,0,0,0), 0, 6)
		var row_style_hover  = _flat(Color(0.06, 0.20, 0.06), C_BORDER, 1, 6)
		row.add_theme_stylebox_override("panel", row_style_normal)
		row.mouse_entered.connect(GameState.show_stat_tooltip.bind(stat_key, tooltip, row, row_style_hover))
		row.mouse_exited.connect(GameState.hide_stat_tooltip.bind(tooltip, row, row_style_normal))
		vbox.add_child(row)

		var inner = HBoxContainer.new()
		inner.add_theme_constant_override("separation", 8)
		row.add_child(inner)

		var name_lbl = _label(GameState.STAT_INFO[stat_key]["label"], 14, C_MID)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner.add_child(name_lbl)

		var val = _player.get(stat_key) if _player else 0
		var val_lbl = _label(str(val), 16, C_BRIGHT)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		inner.add_child(val_lbl)
		_stat_labels[stat_key] = val_lbl

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
	# In endless mode, restrict further: only upgrades for pistol + the
	# weapon the player picked at startup are shown (the only two weapons
	# they own in that mode).
	if _player == null or not "weapon_upgrades" in _player:
		return
	var allowed_weapons: Array = []
	if endless_mode:
		allowed_weapons = ["pistol"]
		var chosen: String = GameState.endless_starting_weapon
		if chosen != "" and not chosen in allowed_weapons:
			allowed_weapons.append(chosen)
	var owned: Array = _player.weapon_upgrades
	var available: Array = []
	for upg in WEAPON_UPGRADES:
		if upg["id"] in owned:
			continue
		if not allowed_weapons.is_empty() and not upg["weapon"] in allowed_weapons:
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
	if _refresh_used >= _refresh_cap:
		_flash_reroll_label_red()
		return
	if _player.caps < _reroll_cost:
		_flash_reroll_label_red()
		return
	_player.caps -= _reroll_cost
	_player.add_caps(0)
	_caps_label.text = "KAPSLE: %d" % _player.caps
	_refresh_used += 1
	_reroll_cost = int(_reroll_cost * 1.25)
	_reroll_cost_lbl.text = _refresh_status_text()
	if _refresh_used >= _refresh_cap and is_instance_valid(_reroll_btn):
		_reroll_btn.disabled = true
		_reroll_btn.text = "[ WYCZERPANE ]"
	for child in _cards_hbox.get_children():
		child.queue_free()
	_spawn_cards()

func _refresh_status_text() -> String:
	return "KOSZT: %d KAPSLI   [%d/%d]" % [_reroll_cost, _refresh_used, _refresh_cap]

func _flash_reroll_label_red() -> void:
	if not is_instance_valid(_reroll_cost_lbl):
		return
	var tween = create_tween()
	tween.tween_property(_reroll_cost_lbl, "modulate", Color(1, 0.2, 0.2), 0.08)
	tween.tween_property(_reroll_cost_lbl, "modulate", Color(1, 1, 1), 0.25)

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
			var stat_name: String = GameState.STAT_INFO.get(stat, {}).get("label", stat.to_upper())
			var s = _label("%s%d  %s" % [prefix, val, stat_name], 15, color)
			s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			if _tooltip != null and GameState.STAT_INFO.has(stat):
				var row := PanelContainer.new()
				var row_normal := _flat(C_CARD, Color(0, 0, 0, 0), 0, 2)
				var row_hover := _flat(Color(0.06, 0.20, 0.06), C_BORDER, 1, 2)
				row.add_theme_stylebox_override("panel", row_normal)
				row.mouse_entered.connect(GameState.show_stat_tooltip.bind(stat, _tooltip, row, row_hover))
				row.mouse_exited.connect(GameState.hide_stat_tooltip.bind(_tooltip, row, row_normal))
				row.add_child(s)
				vbox.add_child(row)
			else:
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
		# Clamp to STAT_CAP so shop spam can't push past 99. Floor at 0 too
		# (in case multiple negative-tradeoff items stack).
		var stat_cap: int = int(_player.STAT_CAP) if "STAT_CAP" in _player else 99
		for entry in item.get("stats", []):
			var stat: String = entry[0]
			var new_value: int = clamp(int(_player.get(stat)) + int(entry[1]), 0, stat_cap)
			_player.set(stat, new_value)
			if _stat_labels.has(stat):
				_stat_labels[stat].text = str(_player.get(stat))
		if _player.has_method("recalculate_stats"):
			_player.recalculate_stats()
	_caps_label.text = "KAPSLE: %d" % _player.caps

	btn.text = "[ KUPIONO ]"
	btn.disabled = true
	btn.add_theme_stylebox_override("normal", _flat(C_BOUGHT, C_DIM, 1, 2))
	btn.add_theme_stylebox_override("hover",  _flat(C_BOUGHT, C_DIM, 1, 2))

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
