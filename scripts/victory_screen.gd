extends CanvasLayer

const C_PANEL   = Color(0.02, 0.08, 0.02)
const C_CARD    = Color(0.03, 0.11, 0.03)
const C_BORDER  = Color(0.18, 0.55, 0.18)
const C_BRIGHT  = Color(0.42, 1.00, 0.42)
const C_MID     = Color(0.25, 0.72, 0.25)
const C_BTN     = Color(0.05, 0.22, 0.05)
const C_BTN_HOV = Color(0.08, 0.34, 0.08)

var zombies_killed: int = 0
var elapsed_time: float = 0.0

func _ready():
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_build_ui()

func _build_ui():
	var overlay = ColorRect.new()
	overlay.color = Color(0.00, 0.02, 0.00, 0.0)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var ov_tween = overlay.create_tween()
	ov_tween.tween_property(overlay, "color:a", 0.88, 1.0)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.modulate.a = 0.0
	add_child(center)
	var ct_tween = center.create_tween()
	ct_tween.tween_interval(0.55)
	ct_tween.tween_property(center, "modulate:a", 1.0, 0.45)

	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat(C_PANEL, C_BORDER, 2, 4))
	center.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 36)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.custom_minimum_size = Vector2(480, 0)
	margin.add_child(vbox)

	var title = _label("// WYGRAŁEŚ! //", 46, C_BRIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle = _label("WSZYSTKIE FALE ODPARTE", 15, C_MID)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	vbox.add_child(_hsep())

	var stats_hdr = _label(">> STATYSTYKI <<", 17, C_MID)
	stats_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_hdr)

	var stats_panel = PanelContainer.new()
	stats_panel.add_theme_stylebox_override("panel", _flat(C_CARD, C_BORDER, 1, 4))
	vbox.add_child(stats_panel)

	var stats_margin = MarginContainer.new()
	stats_margin.add_theme_constant_override("margin_left", 16)
	stats_margin.add_theme_constant_override("margin_right", 16)
	stats_margin.add_theme_constant_override("margin_top", 12)
	stats_margin.add_theme_constant_override("margin_bottom", 12)
	stats_panel.add_child(stats_margin)

	var stats_vbox = VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 10)
	stats_margin.add_child(stats_vbox)

	stats_vbox.add_child(_stat_row("CZAS UKOŃCZENIA", _format_time(elapsed_time)))
	stats_vbox.add_child(_hsep())
	stats_vbox.add_child(_stat_row("POKONANYCH ZOMBIE", str(zombies_killed)))

	vbox.add_child(_hsep())

	var menu_btn = _button("[ MENU GŁÓWNE ]", 22, C_BTN, C_BTN_HOV)
	menu_btn.custom_minimum_size = Vector2(0, 56)
	menu_btn.pressed.connect(_on_menu)
	vbox.add_child(menu_btn)

	var scanlines = ColorRect.new()
	scanlines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scanlines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scan_mat = ShaderMaterial.new()
	scan_mat.shader = _make_scanline_shader()
	scanlines.material = scan_mat
	add_child(scanlines)

func _stat_row(label_text: String, value_text: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	var lbl = _label(label_text, 16, C_MID)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var val = _label(value_text, 20, C_BRIGHT)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)
	return row

func _format_time(seconds: float) -> String:
	var total: int = int(seconds)
	var mins: int = int(total / 60.0)
	var secs: int = total % 60
	return "%02d:%02d" % [mins, secs]

func _on_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred("res://scenes/main_menu.tscn")

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

func _flat(bg: Color, border: Color, bw: int = 1, margin: int = 12) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(2)
	s.set_content_margin_all(margin)
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
	float line = mod(FRAGCOORD.y + TIME * scroll_speed, 3.0);
	float scanline = line < 1.0 ? 0.1 : 0.0;
	float flicker = 1.0 - flicker_strength * (0.5 + 0.5 * sin(TIME * flicker_speed));
	float sweep_y = mod(FRAGCOORD.y - TIME * 120.0, 800.0);
	float sweep = exp(-sweep_y * 0.04) * 0.06;
	COLOR = vec4(0.0, sweep, 0.0, scanline * flicker);
}
"""
	return sh
