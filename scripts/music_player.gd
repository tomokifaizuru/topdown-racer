extends AudioStreamPlayer
## Autoload "Music" (scenes/music_player.tscn): menu background music on the "Music" bus.
## Keeps playing across menu screens, fades out when a race starts.
## Tweak the base loudness with this node's volume_db in scenes/music_player.tscn.

## Fade-out time when a race starts (seconds).
@export var fade_out_time: float = 0.8

var _base_db := 0.0
var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bus = &"Music"
	_base_db = volume_db


## Start (or keep) the menu music. Safe to call repeatedly.
func play_menu() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	volume_db = _base_db
	if not playing:
		play()


func fade_out(time: float = -1.0) -> void:
	if not playing:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "volume_db", -50.0, fade_out_time if time < 0.0 else time)
	_tween.tween_callback(stop)
