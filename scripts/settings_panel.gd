class_name SettingsPanel extends Control

signal closed

const SAVE_PATH = "user://settings.cfg"

const C_PANEL   = Color(0.02, 0.08, 0.02)
const C_CARD    = Color(0.03, 0.11, 0.03)
const C_BORDER  = Color(0.18, 0.55, 0.18)
const C_BRIGHT  = Color(0.42, 1.00, 0.42)
const C_MID     = Color(0.25, 0.72, 0.25)
const C_BTN     = Color(0.05, 0.22, 0.05)
const C_BTN_HOV = Color(0.08, 0.34, 0.08)

static func load_and_apply() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx != -1:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(cfg.get_value("audio", "sfx", 1.0)))
	var music_idx := AudioServer.get_bus_index("Music")
	if music_idx != -1:
		AudioServer.set_bus_volume_db(music_idx, linear_to_db(cfg.get_value("audio", "music", 1.0)))

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui():
	var bg := ColorRect.new()
	bg.color = Color(0.00, 0.02, 0.00, 0.82)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

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
	vbox.custom_minimum_size = Vector2(420, 0)
	margin.add_child(vbox)

	var title := _label("// OPCJE //", 32, C_BRIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(_hsep())
	vbox.add_child(_slider_row("GŁOŚNOŚĆ EFEKTÓW", _get_bus_volume("SFX"),   "SFX"))
	vbox.add_child(_hsep())
	vbox.add_child(_slider_row("GŁOŚNOŚĆ MUZYKI",   _get_bus_volume("Music"), "Music"))
	vbox.add_child(_hsep())

	var back_btn := _button("[ WRÓĆ ]", 20, C_BTN, C_BTN_HOV)
	back_btn.custom_minimum_size = Vector2(0, 50)
	back_btn.pressed.connect(_on_back)
	vbox.add_child(back_btn)

func _on_back() -> void:
	closed.emit()
	queue_free()

func _slider_row(label_text: String, initial_value: float, bus: String) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var lbl := _label(label_text, 16, C_MID)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(lbl)

	var pct_lbl := _label("%d%%" % int(initial_value * 100), 16, C_BRIGHT)
	pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(pct_lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = initial_value
	slider.custom_minimum_size = Vector2(0, 28)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_slider(slider)

	slider.value_changed.connect(func(val: float) -> void:
		pct_lbl.text = "%d%%" % int(val * 100)
		_set_bus_volume(bus, val)
	)
	slider.drag_ended.connect(func(_changed: bool) -> void:
		_save()
	)
	vbox.add_child(slider)
	return vbox

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sfx",   _get_bus_volume("SFX"))
	cfg.set_value("audio", "music", _get_bus_volume("Music"))
	cfg.save(SAVE_PATH)

func _get_bus_volume(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return 1.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))

func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(linear))

func _style_slider(slider: HSlider) -> void:
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = C_BRIGHT
	grabber.set_corner_radius_all(3)
	grabber.set_content_margin_all(6)
	slider.add_theme_stylebox_override("grabber_area", grabber)

	var track := StyleBoxFlat.new()
	track.bg_color = C_CARD
	track.border_color = C_BORDER
	track.set_border_width_all(1)
	track.set_corner_radius_all(2)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	slider.add_theme_stylebox_override("slider", track)

	var img := Image.create(14, 22, false, Image.FORMAT_RGBA8)
	img.fill(C_BRIGHT)
	slider.add_theme_icon_override("grabber", ImageTexture.create_from_image(img))

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
