extends Control

const C_PANEL    = Color(0.02, 0.08, 0.02)
const C_BORDER   = Color(0.18, 0.55, 0.18)
const C_BRIGHT   = Color(0.42, 1.00, 0.42)
const C_BTN      = Color(0.05, 0.22, 0.05)
const C_BTN_HOV  = Color(0.08, 0.34, 0.08)

const MODE_SELECT_SCENE = "res://scenes/mode_select.tscn"

var _settings_panel = null

func _ready():
	get_tree().paused = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	SettingsPanel.load_and_apply()
	_build_ui()

func _build_ui():
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
	vbox.add_theme_constant_override("separation", 16)
	vbox.custom_minimum_size = Vector2(360, 0)
	panel.add_child(vbox)

	var title := _label("// FALLOUT SURVIVORS //", 38, C_BRIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(_hsep())

	var start_btn := _button("[ START ]", 22, C_BTN, C_BTN_HOV)
	start_btn.custom_minimum_size = Vector2(0, 54)
	start_btn.pressed.connect(_on_start)
	vbox.add_child(start_btn)

	var options_btn := _button("[ OPCJE ]", 22, C_BTN, C_BTN_HOV)
	options_btn.custom_minimum_size = Vector2(0, 54)
	options_btn.pressed.connect(_on_options)
	vbox.add_child(options_btn)

	var exit_btn := _button("[ WYJŚCIE ]", 22, C_BTN, C_BTN_HOV)
	exit_btn.custom_minimum_size = Vector2(0, 54)
	exit_btn.pressed.connect(_on_exit)
	vbox.add_child(exit_btn)

	var scanlines := ColorRect.new()
	scanlines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scanlines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scan_mat := ShaderMaterial.new()
	scan_mat.shader = _make_scanline_shader()
	scanlines.material = scan_mat
	add_child(scanlines)

func _on_start():
	get_tree().change_scene_to_file(MODE_SELECT_SCENE)

func _on_options():
	if is_instance_valid(_settings_panel):
		return
	_settings_panel = SettingsPanel.new()
	_settings_panel.closed.connect(func(): _settings_panel = null)
	add_child(_settings_panel)

func _on_exit():
	get_tree().quit()

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

func _make_bg_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float blur_amount = 3.5;
uniform float zoom = 1.14;
uniform float pan_speed = 0.03;

void fragment() {
	// Zoom in so there's room to pan without showing edges
	vec2 uv = (UV - 0.5) / zoom + 0.5;
	// Slow sinusoidal drift
	uv.x += sin(TIME * pan_speed) * 0.045;
	uv.y += sin(TIME * pan_speed * 0.65 + 1.8) * 0.03;

	// 5x5 Gaussian blur
	vec2 px = blur_amount / vec2(textureSize(TEXTURE, 0));
	vec4 col = vec4(0.0);
	float total = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			float w = exp(-float(x * x + y * y) * 0.4);
			col += texture(TEXTURE, uv + vec2(float(x), float(y)) * px) * w;
			total += w;
		}
	}
	COLOR = col / total;
}
"""
	return sh

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
