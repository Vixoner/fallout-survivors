extends Control

# Mode select screen — sits between the main menu and class select.
# Story is wired to the existing gameplay (class_select → main.tscn).
# Endless and Tutorial are mocked for now: they flash a "coming soon"
# feedback when clicked but don't transition anywhere.

const C_PANEL    = Color(0.02, 0.08, 0.02)
const C_BORDER   = Color(0.18, 0.55, 0.18)
const C_BRIGHT   = Color(0.42, 1.00, 0.42)
const C_DIM      = Color(0.20, 0.55, 0.20)
const C_BTN      = Color(0.05, 0.22, 0.05)
const C_BTN_HOV  = Color(0.08, 0.34, 0.08)

const CLASS_SELECT_SCENE  = "res://scenes/class_select.tscn"
const WEAPON_SELECT_SCENE = "res://scenes/weapon_select.tscn"
const MAIN_MENU_SCENE     = "res://scenes/main_menu.tscn"

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _build_ui():
	var overlay := ColorRect.new()
	overlay.color = Color(0.00, 0.02, 0.00, 1.0)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat(C_PANEL, C_BORDER, 2, 32))
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.custom_minimum_size = Vector2(440, 0)
	panel.add_child(vbox)

	var title := _label("// WYBÓR TRYBU //", 34, C_BRIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(_hsep())

	# Story — wired to current gameplay.
	var story_btn := _button("[ FABUŁA ]", 22, C_BTN, C_BTN_HOV)
	story_btn.custom_minimum_size = Vector2(0, 54)
	story_btn.pressed.connect(_on_story)
	vbox.add_child(story_btn)

	var story_desc := _label("Pięć fal, sklep między nimi, walka z bossem.", 13, C_DIM)
	story_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(story_desc)

	# Endless — mock.
	var endless_btn := _button("[ PUSTKOWIA BEZ KOŃCA ]", 22, C_BTN, C_BTN_HOV)
	endless_btn.custom_minimum_size = Vector2(0, 54)
	endless_btn.pressed.connect(_on_endless.bind(endless_btn))
	vbox.add_child(endless_btn)

	var endless_desc := _label("Nieskończone fale, inny system rozwoju i sklep.", 13, C_DIM)
	endless_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(endless_desc)

	# Tutorial — mock.
	var tutorial_btn := _button("[ SAMOUCZEK ]", 22, C_BTN, C_BTN_HOV)
	tutorial_btn.custom_minimum_size = Vector2(0, 54)
	tutorial_btn.pressed.connect(_on_tutorial.bind(tutorial_btn))
	vbox.add_child(tutorial_btn)

	var tutorial_desc := _label("Naucz się podstaw rozgrywki.", 13, C_DIM)
	tutorial_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(tutorial_desc)

	vbox.add_child(_hsep())

	var back_btn := _button("[ WRÓĆ ]", 20, C_BTN, C_BTN_HOV)
	back_btn.custom_minimum_size = Vector2(0, 50)
	back_btn.pressed.connect(_on_back)
	vbox.add_child(back_btn)

	# Scanlines overlay (matches main_menu / class_select aesthetic)
	var scanlines := ColorRect.new()
	scanlines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scanlines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scan_mat := ShaderMaterial.new()
	scan_mat.shader = _make_scanline_shader()
	scanlines.material = scan_mat
	add_child(scanlines)

func _on_story() -> void:
	# Ensure no stale endless flag leaks into story.
	GameState.endless_mode = false
	get_tree().change_scene_to_file(CLASS_SELECT_SCENE)

func _on_endless(_btn: Button) -> void:
	GameState.endless_mode = true
	get_tree().change_scene_to_file(WEAPON_SELECT_SCENE)

func _on_tutorial(btn: Button) -> void:
	_flash_coming_soon(btn)

func _on_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _flash_coming_soon(btn: Button) -> void:
	# Brief "coming soon" feedback on click without leaving the menu.
	var original_text := btn.text
	btn.text = "[ WKRÓTCE ]"
	btn.disabled = true
	var tween := create_tween()
	tween.tween_interval(0.9)
	tween.tween_callback(func() -> void:
		if is_instance_valid(btn):
			btn.text = original_text
			btn.disabled = false
	)

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
