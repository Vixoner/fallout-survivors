extends Control

const CLASS_SELECT_SCENE = "res://scenes/class_select.tscn"
const MAP_SCENES = [
	"res://scenes/main.tscn",
	"res://scenes/main_map2.tscn",
]

const C_PANEL   = Color(0.02, 0.08, 0.02)
const C_CARD    = Color(0.03, 0.11, 0.03)
const C_BORDER  = Color(0.18, 0.55, 0.18)
const C_BRIGHT  = Color(0.42, 1.00, 0.42)
const C_MID     = Color(0.25, 0.72, 0.25)
const C_BTN     = Color(0.05, 0.22, 0.05)
const C_BTN_HOV = Color(0.08, 0.34, 0.08)
const C_LOCKED  = Color(0.35, 0.35, 0.35)

const MAPS = [
	{
		"name": "PUSTKOWIA",
		"subtitle": "Opuszczone przedmieścia",
		"description": "Wyludnione dzielnice na skraju miasta.\nRozsypujące się domy, zarośnięte ulice.\nTu zaczął się koniec.",
	},
	{
		"name": "RUINY",
		"subtitle": "Martwe serce miasta",
		"description": "Niegdyś tętniące życiem ulice dziś\npełne gruzów i cieni.\nGęsta zabudowa nie wybacza błędów.",
	},
]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file(CLASS_SELECT_SCENE)

func _build_ui() -> void:
	var bg := TextureRect.new()
	bg.texture = preload("res://assets/sprites/background.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_mat := ShaderMaterial.new()
	bg_mat.shader = preload("res://assets/shaders/bg_pan.gdshader")
	bg.material = bg_mat
	add_child(bg)

	var overlay := ColorRect.new()
	overlay.color = Color(0.00, 0.02, 0.00, 0.68)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat(C_PANEL, C_BORDER, 2, 32))
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 28)
	vbox.custom_minimum_size = Vector2(860, 0)
	panel.add_child(vbox)

	var title := _label("// WYBÓR MAPY //", 36, C_BRIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sub := _label("Wybierz teren operacji", 16, C_MID)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	vbox.add_child(_hsep())

	var cards_hbox := HBoxContainer.new()
	cards_hbox.add_theme_constant_override("separation", 28)
	cards_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(cards_hbox)

	for i in MAPS.size():
		var locked: bool = i > 0 and not GameState.is_level_completed(i - 1)
		cards_hbox.add_child(_build_map_card(i, MAPS[i], locked))

	vbox.add_child(_hsep())

	var back_btn := _button("[ WRÓĆ ]", 20, C_BTN, C_BTN_HOV)
	back_btn.custom_minimum_size = Vector2(220, 52)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file(CLASS_SELECT_SCENE))
	vbox.add_child(back_btn)

	var scanlines := ColorRect.new()
	scanlines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scanlines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scan_mat := ShaderMaterial.new()
	scan_mat.shader = _make_scanline_shader()
	scanlines.material = scan_mat
	add_child(scanlines)

func _build_map_card(index: int, data: Dictionary, locked: bool) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(370, 280)
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	if locked:
		card.add_theme_stylebox_override("panel", _flat(Color(0.015, 0.015, 0.015), Color(0.22, 0.22, 0.22), 1, 24))
	else:
		card.add_theme_stylebox_override("panel", _flat(C_CARD, C_BORDER, 1, 24))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	var badge_col := C_MID if not locked else C_LOCKED
	var level_lbl := _label("-- POZIOM " + str(index + 1) + " --", 13, badge_col)
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(level_lbl)

	var name_col := C_BRIGHT if not locked else C_LOCKED
	var name_lbl := _label(data["name"], 30, name_col)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	var sub_col := C_MID if not locked else Color(0.38, 0.38, 0.38)
	var sub_lbl := _label(data["subtitle"], 14, sub_col)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub_lbl)

	vbox.add_child(_hsep_color(C_BORDER if not locked else Color(0.18, 0.18, 0.18)))

	var desc_col := C_MID if not locked else Color(0.38, 0.38, 0.38)
	var desc_lbl := _label(data["description"], 14, desc_col)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	vbox.add_child(_hsep_color(C_BORDER if not locked else Color(0.18, 0.18, 0.18)))

	if locked:
		var lock_lbl := _label("[[ ZABLOKOWANE ]]", 18, Color(0.65, 0.18, 0.18))
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(lock_lbl)
		var req_lbl := _label("Ukończ Poziom 1, aby odblokować", 13, Color(0.45, 0.45, 0.45))
		req_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		req_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(req_lbl)
	else:
		var completed: bool = GameState.is_level_completed(index)
		if completed:
			var done_lbl := _label("✓ UKOŃCZONO", 13, Color(0.3, 0.9, 0.3))
			done_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(done_lbl)
		var btn := _button("[ WYBIERZ ]", 20, C_BTN, C_BTN_HOV)
		btn.custom_minimum_size = Vector2(0, 52)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_map_selected.bind(index))
		vbox.add_child(btn)

	return card

func _on_map_selected(index: int) -> void:
	GameState.selected_map = index
	get_tree().change_scene_to_file(MAP_SCENES[index])

# ── Pomocnicze ────────────────────────────────────────────────────────────────

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
	return _hsep_color(C_BORDER)

func _hsep_color(color: Color) -> HSeparator:
	var sep := HSeparator.new()
	var ss := StyleBoxFlat.new()
	ss.bg_color = color
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
