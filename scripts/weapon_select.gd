extends Control

# Endless mode entry point — pick a starting weapon. All SPECIAL stats begin at 1
# in endless, so there's no class. Writes the choice into GameState and loads
# the endless scene.

const ENDLESS_SCENE   = "res://scenes/endless.tscn"
const MODE_SELECT_SCENE = "res://scenes/mode_select.tscn"

const C_PANEL    = Color(0.02, 0.08, 0.02)
const C_CARD     = Color(0.03, 0.11, 0.03)
const C_BORDER   = Color(0.18, 0.55, 0.18)
const C_BRIGHT   = Color(0.42, 1.00, 0.42)
const C_MID      = Color(0.25, 0.72, 0.25)
const C_DIM      = Color(0.20, 0.55, 0.20)
const C_BTN      = Color(0.05, 0.22, 0.05)
const C_BTN_HOV  = Color(0.08, 0.34, 0.08)

const WEAPONS := [
	{
		"id": "pistol",
		"name": "PISTOLET 10MM",
		"desc": "Szybki ogień, niskie obrażenia, bez kosztu krytyków. Niezawodny.",
	},
	{
		"id": "laser",
		"name": "KARABIN LASEROWY",
		"desc": "Przeszywająca wiązka. Trafia każdego wroga na linii.",
	},
	{
		"id": "plasma",
		"name": "KARABIN PLAZMOWY",
		"desc": "Powolny, ciężki pocisk z obszarem rażenia po uderzeniu.",
	},
	{
		"id": "shotgun",
		"name": "STRZELBA",
		"desc": "Wachlarz śrutów. Niszczycielska z bliska, słaba z daleka.",
	},
]

var _current_index: int = 0
var _name_label: Label = null
var _desc_label: Label = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file(MODE_SELECT_SCENE)

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.00, 0.02, 0.00, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat(C_PANEL, C_BORDER, 2, 32))
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.custom_minimum_size = Vector2(720, 0)
	panel.add_child(vbox)

	var title := _label("// WYBÓR BRONI //", 32, C_BRIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(_hsep())

	# Nav row
	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 18)
	vbox.add_child(nav)

	var left := _nav_button("[ < ]")
	left.pressed.connect(_on_prev)
	nav.add_child(left)

	var name_panel := PanelContainer.new()
	name_panel.add_theme_stylebox_override("panel", _flat(C_CARD, C_BORDER, 1, 24))
	name_panel.custom_minimum_size = Vector2(400, 90)
	nav.add_child(name_panel)

	_name_label = _label("", 26, C_BRIGHT)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_panel.add_child(_name_label)

	var right := _nav_button("[ > ]")
	right.pressed.connect(_on_next)
	nav.add_child(right)

	_desc_label = _label("", 16, C_MID)
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_desc_label)

	vbox.add_child(_hsep())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	vbox.add_child(row)

	var back := _button("[ WRÓĆ ]", 20, C_BTN, C_BTN_HOV)
	back.custom_minimum_size = Vector2(180, 56)
	back.pressed.connect(_on_back)
	row.add_child(back)

	var start := _button("[ ZACZNIJ ]", 22, C_BTN, C_BTN_HOV)
	start.custom_minimum_size = Vector2(0, 56)
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start.pressed.connect(_on_start)
	row.add_child(start)

	_update_display()

func _update_display() -> void:
	var w: Dictionary = WEAPONS[_current_index]
	_name_label.text = w["name"]
	_desc_label.text = w["desc"]

func _on_prev() -> void:
	_current_index = (_current_index - 1 + WEAPONS.size()) % WEAPONS.size()
	_update_display()

func _on_next() -> void:
	_current_index = (_current_index + 1) % WEAPONS.size()
	_update_display()

func _on_back() -> void:
	get_tree().change_scene_to_file(MODE_SELECT_SCENE)

func _on_start() -> void:
	GameState.endless_mode = true
	GameState.endless_starting_weapon = WEAPONS[_current_index]["id"]
	GameState.selected_class = {}  # ensure no stale class data
	get_tree().change_scene_to_file(ENDLESS_SCENE)

# ── UI helpers (mirror class_select.gd / mode_select.gd) ──────────────────────

func _nav_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color", C_BRIGHT)
	btn.add_theme_stylebox_override("normal", _flat(C_BTN, C_BORDER, 1, 10))
	btn.add_theme_stylebox_override("hover",  _flat(C_BTN_HOV, C_BRIGHT, 1, 10))
	btn.add_theme_stylebox_override("focus",  _flat(C_BTN, C_BRIGHT, 2, 10))
	btn.custom_minimum_size = Vector2(72, 60)
	return btn

func _label(text: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl

func _button(text: String, font_size: int, bg: Color, bg_hover: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", C_BRIGHT)
	btn.add_theme_stylebox_override("normal", _flat(bg, C_BORDER, 1, 2))
	btn.add_theme_stylebox_override("hover",  _flat(bg_hover, C_BRIGHT, 1, 2))
	btn.add_theme_stylebox_override("focus",  _flat(bg, C_BRIGHT, 2, 2))
	return btn

func _flat(bg: Color, border: Color, bw: int = 1, margin: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(2)
	s.set_content_margin_all(margin)
	return s

func _hsep() -> HSeparator:
	var sep := HSeparator.new()
	var ss := StyleBoxFlat.new()
	ss.bg_color = C_BORDER
	ss.content_margin_top = 1
	sep.add_theme_stylebox_override("separator", ss)
	return sep
