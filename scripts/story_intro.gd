extends Control

# Story mode intro splash. Shown for INTRO_DURATION seconds after the
# player picks a class, then auto-advances to main.tscn. Player can skip
# with Esc / Space / Enter / mouse click.

# Map scenes — mirror of map_select.gd's list. Story intro routes the player
# to whichever map they picked. Keep these in sync if you add a third map.
const MAP_SCENES := [
	"res://scenes/main.tscn",
	"res://scenes/main_map2.tscn",
]
const INTRO_DURATION := 15.0
const INTRO_TEX_PATH := "res://assets/story/intro.png"

const C_MID := Color(0.25, 0.72, 0.25)

var _elapsed: float = 0.0
var _transitioning: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	# Soft fade-in.
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.5)

func _build_ui() -> void:
	# Black backing in case the image has letterboxing.
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var tex_rect := TextureRect.new()
	tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(INTRO_TEX_PATH):
		tex_rect.texture = load(INTRO_TEX_PATH)
	else:
		push_warning("Story intro texture missing at %s" % INTRO_TEX_PATH)
	add_child(tex_rect)

	# Skip hint pinned to the bottom, outlined for legibility over any image.
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
	add_child(hint)

func _process(delta: float) -> void:
	if _transitioning:
		return
	_elapsed += delta
	if _elapsed >= INTRO_DURATION:
		_advance()

func _input(event: InputEvent) -> void:
	if _transitioning:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			_advance()
	elif event is InputEventMouseButton and event.pressed:
		_advance()

func _advance() -> void:
	if _transitioning:
		return
	_transitioning = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	await tw.finished
	if not is_inside_tree():
		return
	var idx: int = clamp(GameState.selected_map, 0, MAP_SCENES.size() - 1)
	get_tree().change_scene_to_file(MAP_SCENES[idx])
