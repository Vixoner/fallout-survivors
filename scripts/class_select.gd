extends Control

const GAME_SCENE      = "res://scenes/main.tscn"
const MAIN_MENU_SCENE = "res://scenes/main_menu.tscn"

const C_PANEL   = Color(0.02, 0.08, 0.02)
const C_CARD    = Color(0.03, 0.11, 0.03)
const C_BORDER  = Color(0.18, 0.55, 0.18)
const C_BRIGHT  = Color(0.42, 1.00, 0.42)
const C_MID     = Color(0.25, 0.72, 0.25)
const C_BTN     = Color(0.05, 0.22, 0.05)
const C_BTN_HOV = Color(0.08, 0.34, 0.08)

const IDLE_DOWN_TEX    = preload("res://assets/sprites/Character/Main/Idle/Character_down_idle-Sheet6.png")
const IDLE_FRAME_COUNT = 6
const IDLE_FRAMES      = [0, 2, 3, 4, 5]
const FRAME_DURATION   = 0.1

# ── Definicje klas ────────────────────────────────────────────────────────────
# Suma statystyk każdej klasy = 35 (bazowo tyle samo punktów co domyślne 7×5).
const CLASSES = [
	{
		"id": "survivor",
		"name": "OCALAŁY",
		"description": "Wszechstronny bojownik pustkowi.",
		"stats": {"strength":5,"perception":5,"endurance":5,"charisma":5,"intelligence":5,"agility":5,"luck":5},
		"starting_grenades": {"frag": 2}
	},
	{
		"id": "raider",
		"name": "RAIDER",
		"description": "Siła ponad wszystko.",
		"stats": {"strength":9,"perception":3,"endurance":6,"charisma":3,"intelligence":3,"agility":6,"luck":5},
		"starting_grenades": {"frag": 3}
	},
	{
		"id": "gunslinger",
		"name": "STRZELEC",
		"description": "Precyzja ponad wszystko.",
		"stats": {"strength":3,"perception":9,"endurance":4,"charisma":4,"intelligence":6,"agility":6,"luck":3},
		"starting_grenades": {"frag": 1}
	},
	{
		"id": "gambler",
		"name": "HAZARDZISTA",
		"description": "Fortuna sprzyja śmiałym.",
		"stats": {"strength":3,"perception":3,"endurance":4,"charisma":7,"intelligence":5,"agility":5,"luck":8},
		"starting_grenades": {"frag": 1}
	},
]

const STAT_LABELS = {
	"strength":     "SIŁA",
	"perception":   "PERCEPCJA",
	"endurance":    "WYTRZYMAŁOŚĆ",
	"charisma":     "CHARYZMA",
	"intelligence": "INTELIGENCJA",
	"agility":      "ZWINNOŚĆ",
	"luck":         "SZCZĘŚCIE",
}
const STAT_ORDER = ["strength","perception","endurance","charisma","intelligence","agility","luck"]

var _current_index: int = 0
var _frame_timer: float = 0.0
var _frame_idx: int = 0
var _idle_atlas_frames: Array = []

var _preview_rect: TextureRect = null
var _name_label: Label = null
var _desc_label: Label = null
var _stat_value_labels: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_prebuild_frames()
	_build_ui()

func _prebuild_frames() -> void:
	var total_w: int = IDLE_DOWN_TEX.get_width()
	var frame_w: float = total_w / float(IDLE_FRAME_COUNT)
	var frame_h: int = IDLE_DOWN_TEX.get_height()
	for i in IDLE_FRAMES:
		var atlas := AtlasTexture.new()
		atlas.atlas = IDLE_DOWN_TEX
		atlas.region = Rect2(i * frame_w, 0, frame_w, frame_h)
		_idle_atlas_frames.append(atlas)

func _process(delta: float) -> void:
	_frame_timer += delta
	if _frame_timer >= FRAME_DURATION:
		_frame_timer -= FRAME_DURATION
		_frame_idx = (_frame_idx + 1) % _idle_atlas_frames.size()
		if is_instance_valid(_preview_rect):
			_preview_rect.texture = _idle_atlas_frames[_frame_idx]

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file(MAIN_MENU_SCENE)

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
	vbox.add_theme_constant_override("separation", 20)
	vbox.custom_minimum_size = Vector2(920, 0)
	panel.add_child(vbox)

	var title := _label("// WYBÓR KLASY STARTOWEJ //", 36, C_BRIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	vbox.add_child(_hsep())

	# ── Główna zawartość: karta + statystyki ─────────────────────────
	var content_hbox := HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 28)
	vbox.add_child(content_hbox)

	# Lewa kolumna: nawigacja + podgląd + opis
	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 14)
	card_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hbox.add_child(card_vbox)

	_name_label = _label("", 30, C_BRIGHT)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_vbox.add_child(_name_label)

	# Wiersz nawigacji: < podgląd >
	var nav_hbox := HBoxContainer.new()
	nav_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_hbox.add_theme_constant_override("separation", 14)
	card_vbox.add_child(nav_hbox)

	var left_btn := _nav_button("[ < ]")
	left_btn.pressed.connect(_on_prev)
	nav_hbox.add_child(left_btn)

	var preview_panel := PanelContainer.new()
	preview_panel.add_theme_stylebox_override("panel", _flat(C_CARD, C_BORDER, 1, 4))
	nav_hbox.add_child(preview_panel)

	_preview_rect = TextureRect.new()
	_preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_rect.custom_minimum_size = Vector2(200, 200)
	preview_panel.add_child(_preview_rect)

	var right_btn := _nav_button("[ > ]")
	right_btn.pressed.connect(_on_next)
	nav_hbox.add_child(right_btn)

	# Opis klasy
	_desc_label = _label("", 16, C_MID)
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_vbox.add_child(_desc_label)

	# Prawa kolumna: panel statystyk
	var stats_panel := PanelContainer.new()
	stats_panel.add_theme_stylebox_override("panel", _flat(C_CARD, C_BORDER, 1, 4))
	stats_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content_hbox.add_child(stats_panel)

	var stats_margin := MarginContainer.new()
	stats_margin.add_theme_constant_override("margin_left", 20)
	stats_margin.add_theme_constant_override("margin_right", 20)
	stats_margin.add_theme_constant_override("margin_top", 16)
	stats_margin.add_theme_constant_override("margin_bottom", 16)
	stats_panel.add_child(stats_margin)

	var stats_vbox := VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 10)
	stats_vbox.custom_minimum_size = Vector2(270, 0)
	stats_margin.add_child(stats_vbox)

	var stats_title := _label(">> STATYSTYKI <<", 18, C_MID)
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_vbox.add_child(stats_title)
	stats_vbox.add_child(_hsep())

	_stat_value_labels.clear()
	for stat_key in STAT_ORDER:
		var row := HBoxContainer.new()
		var name_lbl := _label(STAT_LABELS[stat_key], 15, C_MID)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)
		var val_lbl := _label("5", 17, C_BRIGHT)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_lbl.custom_minimum_size = Vector2(28, 0)
		row.add_child(val_lbl)
		stats_vbox.add_child(row)
		_stat_value_labels[stat_key] = val_lbl

	# ── Dolne przyciski ───────────────────────────────────────────────
	vbox.add_child(_hsep())

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var back_btn := _button("[ WRÓĆ ]", 20, C_BTN, C_BTN_HOV)
	back_btn.custom_minimum_size = Vector2(220, 56)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file(MAIN_MENU_SCENE))
	btn_row.add_child(back_btn)

	var start_btn := _button("[ ZACZNIJ PODEJŚCIE ]", 22, C_BTN, C_BTN_HOV)
	start_btn.custom_minimum_size = Vector2(0, 56)
	start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_btn.pressed.connect(_on_start)
	btn_row.add_child(start_btn)

	# Nakładka scanlines
	var scanlines := ColorRect.new()
	scanlines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scanlines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scan_mat := ShaderMaterial.new()
	scan_mat.shader = _make_scanline_shader()
	scanlines.material = scan_mat
	add_child(scanlines)

	_update_display()

func _update_display() -> void:
	var cls: Dictionary = CLASSES[_current_index]
	_name_label.text = cls["name"]
	_desc_label.text = cls["description"]
	for stat_key in _stat_value_labels:
		_stat_value_labels[stat_key].text = str(cls["stats"].get(stat_key, 5))

func _on_prev() -> void:
	_current_index = (_current_index - 1 + CLASSES.size()) % CLASSES.size()
	_update_display()

func _on_next() -> void:
	_current_index = (_current_index + 1) % CLASSES.size()
	_update_display()

func _on_start() -> void:
	GameState.selected_class = CLASSES[_current_index]
	get_tree().change_scene_to_file(GAME_SCENE)

# ── Pomocnicze ────────────────────────────────────────────────────────────────

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

func _make_scanline_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float scroll_speed = 30.0;
uniform float flicker_speed = 8.0;
uniform float flicker_strength = 0.08;

void fragment() {
	float line = mod(FRAGCOORD.y + TIME * scroll_speed, 3.0);
	float scanline = line < 1.0 ? 0.1 : 0.0;
	float flicker = 1.0 - flicker_strength * (0.5 + 0.5 * sin(TIME * flicker_speed));
	float sweep_y = mod(FRAGCOORD.y - TIME * 120.0, 800.0);
	float sweep = exp(-sweep_y * 0.04) * 0.06;
	COLOR = vec4(0.0, sweep, 0.0, scanline * flicker);
}
"""
	return sh
