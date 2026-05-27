extends CanvasLayer

signal resumed

const MENU_SCENE = "res://scenes/main_menu.tscn"

const C_PANEL   = Color(0.02, 0.08, 0.02)
const C_BORDER  = Color(0.18, 0.55, 0.18)
const C_BRIGHT  = Color(0.42, 1.00, 0.42)
const C_MID     = Color(0.25, 0.72, 0.25)
const C_BTN     = Color(0.05, 0.22, 0.05)
const C_BTN_HOV = Color(0.08, 0.34, 0.08)

var _settings_panel = null
var _confirm_panel: Control = null

func _ready():
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_build_ui()

func _process(_delta):
	if Input.is_action_just_pressed("ui_cancel"):
		if is_instance_valid(_confirm_panel):
			_confirm_panel.queue_free()
			_confirm_panel = null
		elif is_instance_valid(_settings_panel):
			_settings_panel.queue_free()
			_settings_panel = null
		else:
			_on_continue()

func _build_ui():
	var overlay := ColorRect.new()
	overlay.color = Color(0.00, 0.02, 0.00, 0.75)
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
	vbox.custom_minimum_size = Vector2(340, 0)
	panel.add_child(vbox)

	var title := _label("// PAUZA //", 38, C_BRIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(_hsep())

	var cont_btn := _button("[ KONTYNUUJ ]", 22, C_BTN, C_BTN_HOV)
	cont_btn.custom_minimum_size = Vector2(0, 54)
	cont_btn.pressed.connect(_on_continue)
	vbox.add_child(cont_btn)

	var options_btn := _button("[ OPCJE ]", 22, C_BTN, C_BTN_HOV)
	options_btn.custom_minimum_size = Vector2(0, 54)
	options_btn.pressed.connect(_on_options)
	vbox.add_child(options_btn)

	var menu_btn := _button("[ MENU GŁÓWNE ]", 22, C_BTN, C_BTN_HOV)
	menu_btn.custom_minimum_size = Vector2(0, 54)
	menu_btn.pressed.connect(_on_menu)
	vbox.add_child(menu_btn)

func _on_continue():
	get_tree().paused = false
	emit_signal("resumed")
	queue_free()

func _on_options():
	if is_instance_valid(_settings_panel):
		return
	_settings_panel = SettingsPanel.new()
	_settings_panel.closed.connect(func(): _settings_panel = null)
	add_child(_settings_panel)

func _on_menu():
	if is_instance_valid(_confirm_panel):
		return
	_confirm_panel = _build_confirm_panel(
		"Czy na pewno chcesz opuścić to podejście?",
		func():
			get_tree().paused = false
			get_tree().change_scene_to_file(MENU_SCENE)
	)
	add_child(_confirm_panel)

func _build_confirm_panel(question: String, on_confirm: Callable) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.00, 0.02, 0.00, 0.82)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat(C_PANEL, C_BORDER, 2, 4))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.custom_minimum_size = Vector2(440, 0)
	margin.add_child(vbox)

	var q_lbl := _label(question, 20, C_MID)
	q_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(q_lbl)

	vbox.add_child(_hsep())

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(hbox)

	var yes_btn := _button("[ TAK ]", 22, C_BTN, C_BTN_HOV)
	yes_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes_btn.custom_minimum_size = Vector2(0, 54)
	yes_btn.pressed.connect(on_confirm)
	hbox.add_child(yes_btn)

	var no_btn := _button("[ NIE ]", 22, C_BTN, C_BTN_HOV)
	no_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no_btn.custom_minimum_size = Vector2(0, 54)
	no_btn.pressed.connect(func():
		_confirm_panel.queue_free()
		_confirm_panel = null
	)
	hbox.add_child(no_btn)

	return root

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
