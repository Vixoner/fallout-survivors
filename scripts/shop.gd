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
]

var _player: Node = null
var _stat_labels: Dictionary = {}  # stat_name -> Label

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

	var caps_label = _label("KAPSLE: %d" % _player.caps, 19, C_CAPS)
	caps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(caps_label)

	var cards_hbox = HBoxContainer.new()
	cards_hbox.add_theme_constant_override("separation", 16)
	cards_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(cards_hbox)

	var pool = ALL_ITEMS.duplicate()
	pool.shuffle()
	for item in pool.slice(0, 3):
		cards_hbox.add_child(_make_card(item, caps_label))

	root_vbox.add_child(_hsep())

	var bottom = HBoxContainer.new()
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)
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

	var title = _label("// S.P.E.C.I.A.L. //", 18, C_BRIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(_hsep())

	var stats = [
		["STRENGTH",     "strength"],
		["PERCEPTION",   "perception"],
		["ENDURANCE",    "endurance"],
		["CHARISMA",     "charisma"],
		["INTELLIGENCE", "intelligence"],
		["AGILITY",      "agility"],
		["LUCK",         "luck"],
	]

	for entry in stats:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		vbox.add_child(row)

		var name_lbl = _label(entry[0], 14, C_MID)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		var val = _player.get(entry[1]) if _player else 0
		var val_lbl = _label(str(val), 16, C_BRIGHT)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val_lbl)
		_stat_labels[entry[1]] = val_lbl

		vbox.add_child(_hsep())

	return panel

func _make_card(item: Dictionary, caps_label: Label) -> Control:
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
	for entry in item["stats"]:
		var stat: String = entry[0]
		var val: int = entry[1]
		var prefix = "+" if val > 0 else ""
		var color = C_BRIGHT if val > 0 else Color(1.0, 0.35, 0.35)
		var s = _label("%s%d  %s" % [prefix, val, stat.to_upper()], 15, color)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(s)

	# Koszt
	var cost_lbl = _label("KOSZT: %d KAPSLI" % item["cost"], 13, C_CAPS)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(cost_lbl)

	vbox.add_child(_hsep())

	# Buy button
	var buy_btn = _button("[ KUP ]", 17, C_BTN_BUY, C_BTN_HOV)
	buy_btn.custom_minimum_size = Vector2(0, 42)
	buy_btn.pressed.connect(_on_buy.bind(item, buy_btn, cost_lbl, caps_label))
	vbox.add_child(buy_btn)

	# Padding pod przyciskiem
	var pad = Control.new()
	pad.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(pad)

	return card

func _on_buy(item: Dictionary, btn: Button, cost_lbl: Label, caps_label: Label):
	if _player == null or btn.disabled:
		return
	if _player.caps < item["cost"]:
		var tween = create_tween()
		tween.tween_property(cost_lbl, "modulate", Color(1, 0.2, 0.2), 0.08)
		tween.tween_property(cost_lbl, "modulate", Color(1, 1, 1), 0.25)
		return

	_player.caps -= item["cost"]
	for entry in item["stats"]:
		var stat: String = entry[0]
		_player.set(stat, _player.get(stat) + entry[1])
		if _stat_labels.has(stat):
			_stat_labels[stat].text = str(_player.get(stat))
	_player.add_caps(0)
	caps_label.text = "KAPSLE: %d" % _player.caps

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
