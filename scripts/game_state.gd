extends Node

static var selected_class: Dictionary = {}
static var selected_map: int = 0

# Endless mode handoff: set by weapon_select / mode_select, read by player and endless.
static var endless_mode: bool = false
static var endless_starting_weapon: String = "pistol"
static var tutorial_mode: bool = false

const STAT_ORDER = ["strength","perception","endurance","charisma","intelligence","agility","luck"]
const STAT_INFO = {
	"strength":     {"label": "SIŁA",         "desc": "Wpływa na obrażenia w walce wręcz."},
	"perception":   {"label": "PERCEPCJA",    "desc": "Wpływa na obrażenia ataku broni palnej."},
	"endurance":    {"label": "WYTRZYMAŁOŚĆ", "desc": "Wpływa na maksymalną liczbę punktów zdrowia i odporność na obrażenia."},
	"charisma":     {"label": "CHARYZMA",     "desc": "Wpływa na ceny w sklepie."},
	"intelligence": {"label": "INTELIGENCJA", "desc": "Wpływa na odległość przyciągania kapsli które wypadają z przeciwników."},
	"agility":      {"label": "ZWINNOŚĆ",     "desc": "Wpływa na prędkość poruszania się."},
	"luck":         {"label": "SZCZĘŚCIE",    "desc": "Wpływa na szansę obrażeń krytycznych."},
}

const _RECORDS_PATH = "user://records.cfg"

func save_record(class_id: String, time_seconds: float) -> void:
	if class_id.is_empty():
		return
	var cfg := ConfigFile.new()
	cfg.load(_RECORDS_PATH)
	var existing: float = cfg.get_value("records", class_id, INF)
	if time_seconds < existing:
		cfg.set_value("records", class_id, time_seconds)
		cfg.save(_RECORDS_PATH)

func get_record(class_id: String) -> float:
	var cfg := ConfigFile.new()
	if cfg.load(_RECORDS_PATH) != OK:
		return INF
	return cfg.get_value("records", class_id, INF)

func is_level_completed(level_index: int) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(_RECORDS_PATH) != OK:
		return false
	return cfg.get_value("levels", "completed_" + str(level_index), false)

func mark_level_completed(level_index: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(_RECORDS_PATH)
	cfg.set_value("levels", "completed_" + str(level_index), true)
	cfg.save(_RECORDS_PATH)

func is_tutorial_completed() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(_RECORDS_PATH) != OK:
		return false
	return cfg.get_value("tutorial", "completed", false)

func mark_tutorial_completed() -> void:
	var cfg := ConfigFile.new()
	cfg.load(_RECORDS_PATH)
	cfg.set_value("tutorial", "completed", true)
	cfg.save(_RECORDS_PATH)

func build_stat_tooltip(parent: Node) -> Control:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.08, 0.02)
	sb.border_color = Color(0.42, 1.00, 0.42)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(6)

	var panel := PanelContainer.new()
	panel.visible = false
	panel.custom_minimum_size = Vector2(150, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.z_index = 20
	panel.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	panel.add_child(vbox)

	var title := Label.new()
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.42, 1.00, 0.42))
	vbox.add_child(title)

	var sep := HSeparator.new()
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(0.18, 0.55, 0.18)
	ss.content_margin_top = 1
	sep.add_theme_stylebox_override("separator", ss)
	vbox.add_child(sep)

	var desc := Label.new()
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.25, 0.72, 0.25))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(140, 0)
	desc.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vbox.add_child(desc)

	panel.set_meta("title_lbl", title)
	panel.set_meta("desc_lbl", desc)

	parent.add_child(panel)
	return panel

func show_stat_tooltip(stat_key: String, tooltip: Control, row: Control, hover_style: StyleBoxFlat) -> void:
	row.add_theme_stylebox_override("panel", hover_style)
	var info: Dictionary = STAT_INFO.get(stat_key, {})
	tooltip.get_meta("title_lbl").text = info.get("label", stat_key.to_upper())
	tooltip.get_meta("desc_lbl").text = info.get("desc", "")
	tooltip.reset_size()
	tooltip.visible = true
	var row_rect: Rect2 = row.get_global_rect()
	tooltip.set_position(Vector2(row_rect.end.x + 20, row_rect.position.y))

func hide_stat_tooltip(tooltip: Control, row: Control, normal_style: StyleBoxFlat) -> void:
	row.add_theme_stylebox_override("panel", normal_style)
	tooltip.visible = false
