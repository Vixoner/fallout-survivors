extends Node

# Combat music controller. Plays through MUSIC_TRACKS in order, advancing to
# the next track when the current one finishes. Wraps back to track 0 after
# the last one — strict alternation, not shuffle.
#
# Usage: add an instance as a child of a gameplay scene root (main.gd / map2.gd
# / endless.gd already call _start_music for this).

const MUSIC_TRACKS := [
	"res://assets/audio/music/track1.mp3",
	"res://assets/audio/music/track2.mp3",
]

var _player: AudioStreamPlayer = null
var _track_idx: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = "Music"
	_player.finished.connect(_play_next)
	add_child(_player)
	_play_next()

func _play_next() -> void:
	if MUSIC_TRACKS.is_empty():
		return
	# Try at most TRACKS.size() entries — if all are missing we give up
	# instead of recursing forever via the warning path.
	for _attempt in MUSIC_TRACKS.size():
		var path: String = MUSIC_TRACKS[_track_idx % MUSIC_TRACKS.size()]
		_track_idx += 1
		if not ResourceLoader.exists(path):
			push_warning("Combat music track missing at %s" % path)
			continue
		var stream: AudioStream = load(path)
		# Disable loop so the `finished` signal fires and we can advance.
		if "loop" in stream:
			stream.loop = false
		_player.stream = stream
		_player.play()
		return
