extends CanvasLayer

# Final-map ending cutscene. Spawned by main.gd over the still-running scene
# after the player defeats the last boss — that way the kill/time stats stay
# in main.gd's vars and the victory screen receives them unchanged once the
# cutscene closes. Pauses the tree to freeze any leftover animations.

signal closed

const ENDING_TEX_PATH := "res://assets/story/ending.png"
const DURATION := 15.0

const C_MID := Color(0.25, 0.72, 0.25)

var _elapsed: float = 0.0
var _closing: bool = false
var _root: Control = null

func _ready() -> void:
	layer = 100  # above HUD/shop/pause; below game_over_screen (110)
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_build_ui()
	_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.5)

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)

	var tex_rect := TextureRect.new()
	tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(ENDING_TEX_PATH):
		tex_rect.texture = load(ENDING_TEX_PATH)
	else:
		push_warning("Ending cutscene texture missing at %s" % ENDING_TEX_PATH)
	_root.add_child(tex_rect)

	var hint := Label.new()
	hint.text = "[ Naciśnij ESC, Spację lub kliknij aby pominąć ]"
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", C_MID)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hint.add_theme_constant_override("outline_size", 4)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.anchor_left = 0.0
	hint.anchor_right = 1.0
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_top = -54
	hint.offset_bottom = -18
	_root.add_child(hint)

func _process(delta: float) -> void:
	if _closing:
		return
	_elapsed += delta
	if _elapsed >= DURATION:
		_advance()

func _input(event: InputEvent) -> void:
	if _closing:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			_advance()
	elif event is InputEventMouseButton and event.pressed:
		_advance()

func _advance() -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.35)
	await tw.finished
	get_tree().paused = false
	closed.emit()
	queue_free()
