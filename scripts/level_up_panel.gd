extends CanvasLayer

# Endless level-up: player gets 5 points to distribute across SPECIAL stats.
# Pauses the tree while open. Emits `closed` after the player commits.

signal closed

const C_PANEL    = Color(0.02, 0.08, 0.02)
const C_CARD     = Color(0.03, 0.11, 0.03)
const C_BORDER   = Color(0.18, 0.55, 0.18)
const C_BRIGHT   = Color(0.42, 1.00, 0.42)
const C_MID      = Color(0.25, 0.72, 0.25)
const C_DIM      = Color(0.15, 0.42, 0.15)
const C_BTN      = Color(0.05, 0.22, 0.05)
const C_BTN_HOV  = Color(0.08, 0.34, 0.08)

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

var _player: Node = null
var _new_level: int = 1
# Snapshot of stats at the moment the panel opens — used as a floor when refunding.
var _baseline: Dictionary = {}
var _value_labels: Dictionary = {}
var _points_label: Label = null
var _ok_btn: Button = null

func setup(player: Node, new_level: int) -> void:
	_player = player
	_new_level = new_level

func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_snapshot_baseline()
	_build_ui()

func _snapshot_baseline() -> void:
	for s in STAT_ORDER:
		_baseline[s] = _player.get(s)

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
	vbox.custom_minimum_size = Vector2(560, 0)
	panel.add_child(vbox)

	var title := _label("// POZIOM %d //" % _new_level, 34, C_BRIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_points_label = _label("PUNKTY DO ROZDANIA: %d" % _player.pending_stat_points, 20, C_BRIGHT)
	_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_points_label)

	vbox.add_child(_hsep())

	for stat in STAT_ORDER:
		vbox.add_child(_build_stat_row(stat))

	vbox.add_child(_hsep())

	_ok_btn = _button("[ ZATWIERDŹ ]", 22, C_BTN, C_BTN_HOV)
	_ok_btn.custom_minimum_size = Vector2(0, 54)
	_ok_btn.pressed.connect(_on_confirm)
	vbox.add_child(_ok_btn)
	_refresh_ok_btn()

func _build_stat_row(stat: String) -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _flat(C_CARD, C_BORDER, 1, 4))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row.add_child(hbox)

	var name_lbl := _label(STAT_LABELS[stat], 17, C_MID)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_lbl)

	var minus := _stat_btn("−")
	minus.pressed.connect(_on_minus.bind(stat))
	hbox.add_child(minus)

	var value_lbl := _label(str(_player.get(stat)), 20, C_BRIGHT)
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_lbl.custom_minimum_size = Vector2(60, 0)
	hbox.add_child(value_lbl)
	_value_labels[stat] = value_lbl

	var plus := _stat_btn("+")
	plus.pressed.connect(_on_plus.bind(stat))
	hbox.add_child(plus)

	return row

func _on_plus(stat: String) -> void:
	if _player.spend_stat_point(stat):
		_refresh_after_change(stat)

func _on_minus(stat: String) -> void:
	if _player.refund_stat_point(stat, int(_baseline.get(stat, 0))):
		_refresh_after_change(stat)

func _refresh_after_change(stat: String) -> void:
	_value_labels[stat].text = str(_player.get(stat))
	_points_label.text = "PUNKTY DO ROZDANIA: %d" % _player.pending_stat_points
	_refresh_ok_btn()

func _refresh_ok_btn() -> void:
	# Only allow closing once all points are spent — keeps the player from
	# accidentally banking points (they don't carry over and can't be re-spent).
	var ready_to_close: bool = _player.pending_stat_points == 0
	_ok_btn.disabled = not ready_to_close
	if ready_to_close:
		_ok_btn.text = "[ ZATWIERDŹ ]"
	else:
		_ok_btn.text = "[ ROZDAJ WSZYSTKIE PUNKTY ]"

func _on_confirm() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()

# ── helpers ──────────────────────────────────────────────────────────────────

func _stat_btn(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", C_BRIGHT)
	btn.add_theme_stylebox_override("normal", _flat(C_BTN, C_BORDER, 1, 4))
	btn.add_theme_stylebox_override("hover",  _flat(C_BTN_HOV, C_BRIGHT, 1, 4))
	btn.add_theme_stylebox_override("focus",  _flat(C_BTN, C_BRIGHT, 2, 4))
	btn.custom_minimum_size = Vector2(44, 38)
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
