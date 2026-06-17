extends CanvasLayer

const ENEMY_SCENE = preload("res://scenes/enemy.tscn")
const CAP_SCENE   = preload("res://scenes/cap.tscn")

const C_BG     = Color(0.01, 0.05, 0.01, 0.93)
const C_BORDER = Color(0.18, 0.55, 0.18)
const C_BRIGHT = Color(0.42, 1.00, 0.42)
const C_MID    = Color(0.25, 0.72, 0.25)
const C_DIM    = Color(0.14, 0.42, 0.14)

const TOTAL_STEPS = 6

var _main: Node   = null
var _player: Node = null

var _panel: PanelContainer = null
var _step_label: Label     = null
var _title_label: Label    = null
var _text_label: Label     = null
var _wait_label: Label     = null

var _dot_timer: float        = 0.0
var _dot_count: int          = 0
var _feedback_active: bool   = false
var _waiting_for_click: bool = false
var _aborted: bool           = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		_aborted = true
		GameState.tutorial_mode = false
		_set_melee_lock(false)
		_set_ranged_lock(false)
		_set_grenade_lock(false)

func setup(main: Node, player: Node) -> void:
	_main   = main
	_player = player

func _ready() -> void:
	layer        = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_run_tutorial()

func _process(delta: float) -> void:
	if _feedback_active or _waiting_for_click:
		return
	if not is_instance_valid(_wait_label) or not _wait_label.visible:
		return
	_dot_timer += delta
	if _dot_timer >= 0.35:
		_dot_timer = 0.0
		_dot_count = (_dot_count + 1) % 4
		_wait_label.text = "▶  Czekam na twoje działanie" + ".".repeat(_dot_count)

# ── Tutorial flow ─────────────────────────────────────────────────────────────

func _run_tutorial() -> void:
	_set_ranged_lock(true)
	_set_grenade_lock(true)

	# Krok 1 — Ruch
	_set_step(1, "Poruszanie się",
		"Witaj na Pustkowiach!\n" +
		"Użyj klawiszy  [W] [A] [S] [D]  lub strzałek kierunkowych, aby się poruszać.\n" +
		"Spróbuj ruszyć się z miejsca.")
	await _wait_moved(130.0)
	if _aborted: return
	await _feedback("✓  Ruch opanowany!")
	if _aborted: return
	await _wait_continue()
	if _aborted: return

	# Krok 2 — Walka wręcz
	_set_step(2, "Walka wręcz — atak automatyczny",
		"Trzy zombie pojawiły się w pobliżu. Atak nożem jest całkowicie automatyczny — wystarczy podejść.\n" +
		"Zbliż się i wyeliminuj wszystkich trzech!")
	var e_melee := _spawn_enemies([Vector2(380, -110), Vector2(415, 0), Vector2(380, 110)], 100)
	await _wait_all_dead(e_melee)
	if _aborted: return
	await _feedback("✓  Wszyscy wrogowie pokonani!")
	if _aborted: return
	await _wait_continue()
	if _aborted: return

	# Krok 3 — Broń palna
	_set_ranged_lock(false)
	_set_melee_lock(true)
	_set_step(3, "Broń palna — strzela automatycznie",
		"Zawsze masz dwie bronie: automatyczny nóż z bliska i aktywna broń palna z dystansu.\n" +
		"Broń palna strzela sama w kierunku kursora — po prostu celuj w przeciwnika.\n" +
		"Wyeliminuj trzy zombie przed sobą!")
	var e_ranged := _spawn_enemies([Vector2(720, -120), Vector2(760, 0), Vector2(720, 120)], 100)
	await _wait_all_dead(e_ranged)
	if _aborted: return
	await _feedback("✓  Doskonałe!")
	if _aborted: return
	_set_melee_lock(false)
	await _wait_continue()
	if _aborted: return

	# Krok 4 — Granaty
	_set_melee_lock(true)
	_set_ranged_lock(true)
	_set_grenade_lock(false)
	if is_instance_valid(_player) and int(_player.grenades.get("frag", 0)) < 1:
		_player.add_grenade("frag", 1)
	_set_step(4, "Granaty — wybuchowa siła",
		"Masz przy sobie granaty odłamkowe! Wciśnij  [G]  aby rzucić granat w kierunku kursora.\n" +
		"Granat wybucha w dużym promieniu — wyceluj w środek grupy.\n" +
		"Wysadź wszystkich trzech zombie jednym lub dwoma granatami!")
	var e_gren := _spawn_enemies([Vector2(320, -55), Vector2(355, 0), Vector2(320, 55)], 60)
	await _wait_all_dead_refill_grenades(e_gren)
	if _aborted: return
	await _feedback("✓  Spektakularny wybuch!")
	if _aborted: return
	_set_melee_lock(false)
	_set_ranged_lock(false)
	await _wait_continue()
	if _aborted: return

	# Krok 5 — Zmiana broni
	_set_step(5, "Zmiana aktywnej broni palnej",
		"Masz do dyspozycji cztery bronie — zmieniaj je klawiszami numerycznymi:\n" +
		"[1] Pistolet     [2] Laser     [3] Plazma     [4] Strzelba\n" +
		"Wciśnij dowolny klawisz, aby zmienić aktywną broń.")
	await _wait_weapon_switched()
	if _aborted: return
	await _feedback("✓  Broń zmieniona!")
	if _aborted: return
	await _wait_continue()
	if _aborted: return

	# Krok 6 — Kapsle
	_set_step(6, "Kapsle — waluta sklepu",
		"Pokonani wrogowie upuszczają kapsle — zbieraj ich jak najwięcej!\n" +
		"Między falami otwiera się sklep, gdzie kapsle wymieniasz na ulepszenia.\n" +
		"Zbierz kapsle które pojawiły się wokół ciebie!")
	_spawn_caps(8)
	await _wait_caps(4)
	if _aborted: return
	await _feedback("✓  Kapsle zebrane!")
	if _aborted: return
	await _wait_continue()
	if _aborted: return

	# Koniec — info i start
	_set_done(
		"Wiesz już wszystko! Pamiętaj: unikaj obrażeń, nie daj się otoczyć,\n" +
		"zbieraj kapsle i zmieniaj broń zależnie od sytuacji.\n" +
		"Powodzenia, Ocalały — pierwsza fala jest w drodze!")
	await _wait_continue("[ Kliknij LPM aby rozpocząć grę ]")
	if _aborted: return

	# Wyzeruj kapsle zebrane podczas tutoriala
	if is_instance_valid(_player):
		_player.caps = 0
		_player.add_caps(0)

	# Przywróć granaty do wartości startowych klasy
	if is_instance_valid(_player):
		var starting: Dictionary = GameState.selected_class.get("starting_grenades", {})
		for gtype in starting:
			_player.grenades[gtype] = clamp(int(starting[gtype]), 0, _player.get_grenade_cap())
		_player.add_grenade("frag", 0)

	# Usuń kapsle pozostałe z sekcji tutorialowej
	if is_inside_tree():
		for cap in get_tree().get_nodes_in_group("caps"):
			cap.queue_free()

	_set_melee_lock(false)
	_set_ranged_lock(false)
	_set_grenade_lock(false)
	GameState.tutorial_mode = false
	GameState.mark_tutorial_completed()
	if is_instance_valid(_main):
		_main.start_wave(0)
	queue_free()

# ── Lock helpers ──────────────────────────────────────────────────────────────

func _set_melee_lock(locked: bool) -> void:
	if is_instance_valid(_player):
		_player.melee_locked = locked

func _set_ranged_lock(locked: bool) -> void:
	if is_instance_valid(_player):
		_player.ranged_locked = locked

func _set_grenade_lock(locked: bool) -> void:
	if is_instance_valid(_player):
		_player.grenade_locked = locked

# ── Waiter helpers ────────────────────────────────────────────────────────────

func _wait_moved(dist: float) -> void:
	if not is_instance_valid(_player):
		return
	var origin: Vector2 = _player.global_position
	while is_instance_valid(_player) and _player.global_position.distance_to(origin) < dist:
		if not is_inside_tree(): return
		await get_tree().process_frame

func _wait_all_dead(enemies: Array) -> void:
	var remaining := [enemies.size()]
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.died.connect(func(_p: Vector2, _c: int) -> void:
				remaining[0] -= 1
			)
	while remaining[0] > 0:
		if not is_inside_tree(): return
		await get_tree().process_frame

func _wait_all_dead_refill_grenades(enemies: Array) -> void:
	var remaining := [enemies.size()]
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.died.connect(func(_p: Vector2, _c: int) -> void:
				remaining[0] -= 1
			)
	while remaining[0] > 0:
		if not is_inside_tree(): return
		await get_tree().process_frame
		if is_instance_valid(_player) and int(_player.grenades.get("frag", 0)) <= 0:
			_player.add_grenade("frag", 1)

func _wait_weapon_switched() -> void:
	if not is_instance_valid(_player):
		return
	var wm = _player.weapon_manager
	if not is_instance_valid(wm):
		return
	var start_name: String = wm.current_weapon.name if wm.current_weapon else ""
	while true:
		if not is_inside_tree(): return
		await get_tree().process_frame
		if not is_instance_valid(_player) or not is_instance_valid(_player.weapon_manager):
			break
		var wm2 = _player.weapon_manager
		var cur: String = wm2.current_weapon.name if wm2.current_weapon else ""
		if cur != start_name:
			break

func _wait_caps(amount: int) -> void:
	if not is_instance_valid(_player):
		return
	var start_caps: int = _player.caps
	while is_instance_valid(_player) and _player.caps < start_caps + amount:
		if not is_inside_tree(): return
		await get_tree().process_frame

func _wait_continue(prompt: String = "[ Kliknij LPM aby kontynuować ]") -> void:
	_waiting_for_click = true
	_wait_label.text = prompt
	_wait_label.add_theme_color_override("font_color", C_BRIGHT)
	_wait_label.visible = true
	# Poczekaj aż LPM zostanie zwolniony (zapobiega przypadkowemu pominięciu)
	while Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not is_inside_tree(): return
		await get_tree().process_frame
	# Czekaj na świeże kliknięcie
	while not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not is_inside_tree(): return
		await get_tree().process_frame
	_waiting_for_click = false

func _delay(seconds: float) -> void:
	if not is_inside_tree(): return
	await get_tree().create_timer(seconds).timeout

func _feedback(msg: String) -> void:
	_feedback_active = true
	_wait_label.text = msg
	_wait_label.add_theme_color_override("font_color", C_BRIGHT)
	_wait_label.visible = true
	await _delay(0.8)
	if is_instance_valid(_wait_label):
		_wait_label.add_theme_color_override("font_color", C_DIM)
		_feedback_active = false

# ── Spawn helpers ─────────────────────────────────────────────────────────────

func _spawn_enemies(offsets: Array, hp: int) -> Array:
	var result: Array = []
	for off in offsets:
		result.append(_spawn_enemy(off, hp))
	return result

func _spawn_enemy(vec: Vector2, hp: int) -> Node:
	if not is_instance_valid(_player) or not is_instance_valid(_main):
		return Node.new()
	var enemy := ENEMY_SCENE.instantiate()
	enemy.global_position = _player.global_position + vec
	if "max_health"       in enemy: enemy.max_health       = hp
	if "move_speed"       in enemy: enemy.move_speed       = 0.0
	if "attack_damage"    in enemy: enemy.attack_damage    = 0
	if "contact_distance" in enemy: enemy.contact_distance = 0.0
	_main.add_child(enemy)
	return enemy

func _spawn_caps(count: int) -> void:
	if not is_instance_valid(_player) or not is_instance_valid(_main):
		return
	for i in count:
		var angle := randf() * TAU
		var dist := randf_range(300, 520)
		var cap := CAP_SCENE.instantiate()
		cap.value = 1
		cap.position = _player.global_position + Vector2(cos(angle), sin(angle)) * dist
		_main.add_child(cap)

# ── UI ────────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _flat(C_BG, C_BORDER, 2, 16))
	_panel.anchor_left   = 0.5
	_panel.anchor_top    = 1.0
	_panel.anchor_right  = 0.5
	_panel.anchor_bottom = 1.0
	_panel.offset_left   = -510
	_panel.offset_right  =  510
	_panel.offset_top    = -340
	_panel.offset_bottom = -82
	root.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 7)
	_panel.add_child(vbox)

	var hdr_row := HBoxContainer.new()
	vbox.add_child(hdr_row)

	var hdr := _label("// SAMOUCZEK //", 19, C_BRIGHT)
	hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_row.add_child(hdr)

	_step_label = _label("", 16, C_DIM)
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hdr_row.add_child(_step_label)

	vbox.add_child(_hsep())

	_title_label = _label("", 24, C_BRIGHT)
	vbox.add_child(_title_label)

	_text_label = _label("", 18, C_MID)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(960, 0)
	vbox.add_child(_text_label)

	_wait_label = _label("", 16, C_DIM)
	vbox.add_child(_wait_label)

func _set_step(step: int, title: String, text: String) -> void:
	_step_label.text    = "Krok %d / %d" % [step, TOTAL_STEPS]
	_title_label.text   = title
	_text_label.text    = text
	_wait_label.text    = "▶  Czekam na twoje działanie"
	_wait_label.add_theme_color_override("font_color", C_DIM)
	_wait_label.visible = true
	_panel.visible      = true
	_feedback_active    = false
	_waiting_for_click  = false

func _set_done(text: String) -> void:
	_step_label.text    = "✓  Ukończono!"
	_title_label.text   = "Samouczek zakończony"
	_text_label.text    = text
	_wait_label.visible = false
	_panel.visible      = true

func _label(text: String, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	return lbl

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
