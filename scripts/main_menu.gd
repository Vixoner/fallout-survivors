extends Control

const C_PANEL   = Color(0.02, 0.08, 0.02)
const C_BORDER  = Color(0.18, 0.55, 0.18)
const C_BRIGHT  = Color(0.42, 1.00, 0.42)
const C_MID     = Color(0.25, 0.72, 0.25)
const C_BTN     = Color(0.05, 0.22, 0.05)
const C_BTN_HOV = Color(0.08, 0.34, 0.08)

const GAME_SCENE = "res://scenes/main.tscn"

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui():
	var overlay = ColorRect.new()
	overlay.color = Color(0.00, 0.02, 0.00, 1.0)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat(C_PANEL, C_BORDER, 2, 32))
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.custom_minimum_size = Vector2(360, 0)
	panel.add_child(vbox)

	var title = _label("// FALLOUT SURVIVORS //", 38, C_BRIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(_hsep())

	var continue_btn = _button("[ KONTYNUUJ ]", 22, C_BTN, C_BTN_HOV)
	continue_btn.custom_minimum_size = Vector2(0, 54)
	continue_btn.pressed.connect(_on_continue)
	vbox.add_child(continue_btn)

	var options_btn = _button("[ OPCJE ]", 22, C_BTN, C_BTN_HOV)
	options_btn.custom_minimum_size = Vector2(0, 54)
	options_btn.pressed.connect(_on_options)
	vbox.add_child(options_btn)

	var exit_btn = _button("[ WYJŚCIE ]", 22, C_BTN, C_BTN_HOV)
	exit_btn.custom_minimum_size = Vector2(0, 54)
	exit_btn.pressed.connect(_on_exit)
	vbox.add_child(exit_btn)

func _on_continue():
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_options():
	pass  # Placeholder — options menu not implemented yet

func _on_exit():
	get_tree().quit()

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
