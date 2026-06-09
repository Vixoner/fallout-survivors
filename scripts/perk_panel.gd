extends CanvasLayer

# Endless perk selection: shows 3 random unowned perks. Player picks one.
# Pauses the tree while open. Emits `closed` after a choice (or pool-empty).

signal closed

const C_PANEL    = Color(0.02, 0.08, 0.02)
const C_CARD     = Color(0.03, 0.11, 0.03)
const C_BORDER   = Color(0.18, 0.55, 0.18)
const C_BRIGHT   = Color(0.42, 1.00, 0.42)
const C_MID      = Color(0.25, 0.72, 0.25)
const C_BTN      = Color(0.05, 0.22, 0.05)
const C_BTN_HOV  = Color(0.08, 0.34, 0.08)

var _player: Node = null
var _options: Array = []

func setup(player: Node) -> void:
	_player = player
	# Show every perk the player doesn't already own — requirements (level,
	# stat minimums) just grey out the card without removing it from view.
	_options = Perks.available_for(player.perks)

func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_build_ui()

func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.00, 0.02, 0.00, 0.85)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat(C_PANEL, C_BORDER, 2, 32))
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.custom_minimum_size = Vector2(1120, 0)
	panel.add_child(vbox)

	var title := _label("// WYBIERZ PERK //", 34, C_BRIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(_hsep())

	if _options.is_empty():
		var none_lbl := _label("Wszystkie perki już zdobyte.", 18, C_MID)
		none_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(none_lbl)
		var skip := _button("[ DALEJ ]", 22, C_BTN, C_BTN_HOV)
		skip.custom_minimum_size = Vector2(0, 54)
		skip.pressed.connect(_on_skip)
		vbox.add_child(skip)
		return

	# Scrollable grid — keeps the panel a fixed height regardless of pool size
	# (currently 11 perks; will grow as we add more).
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 540)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for opt in _options:
		grid.add_child(_build_card(opt))

	# Always-available skip — fallback when every visible perk is
	# requirement-gated, or the player just doesn't want any of the options.
	vbox.add_child(_hsep())
	var skip_btn := _button("[ POMIŃ ]", 18, C_BTN, C_BTN_HOV)
	skip_btn.custom_minimum_size = Vector2(0, 44)
	skip_btn.pressed.connect(_on_skip)
	vbox.add_child(skip_btn)

func _build_card(perk: Dictionary) -> Control:
	var req := Perks.check_requirements(perk, _player)
	var met: bool = bool(req["met"])

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _flat(C_CARD, C_BORDER, 1, 16))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(340, 220)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)

	var name_color: Color = C_BRIGHT if met else Color(0.50, 0.65, 0.50)
	var name_lbl := _label(perk["name"], 20, name_color)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(name_lbl)

	v.add_child(_hsep())

	var desc_color: Color = C_MID if met else Color(0.35, 0.50, 0.35)
	var desc_lbl := _label(perk["desc"], 14, desc_color)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(desc_lbl)

	# Requirements line — only rendered if the perk has any, so cards without
	# requirements stay clean.
	if not met:
		var req_lbl := _label("WYMAGA: %s" % str(req["missing"]), 12, Color(1.0, 0.45, 0.45))
		req_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(req_lbl)

	v.add_child(_hsep())

	var btn := _button("[ WYBIERZ ]" if met else "[ ZABLOKOWANE ]", 18, C_BTN, C_BTN_HOV)
	btn.custom_minimum_size = Vector2(0, 44)
	btn.disabled = not met
	if met:
		btn.pressed.connect(_on_pick.bind(perk["id"]))
	v.add_child(btn)
	return card

func _on_pick(perk_id: String) -> void:
	_player.add_perk(perk_id)
	get_tree().paused = false
	closed.emit()
	queue_free()

func _on_skip() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()

# helpers
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
