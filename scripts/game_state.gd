class_name GameState

static var selected_class: Dictionary = {}

# Endless mode handoff: set by weapon_select / mode_select, read by player and endless.
static var endless_mode: bool = false
static var endless_starting_weapon: String = "pistol"
