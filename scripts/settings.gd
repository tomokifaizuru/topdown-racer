extends Node
## Autoload "Settings": BGM / SFX volume, race setup (mode, track, laps, difficulty, ghost,
## online ranking, player name) and local best laps, saved to user://settings.cfg
## (on the web build user:// is stored in the browser's IndexedDB).

const PATH := "user://settings.cfg"
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"

## Volumes in percent (0-100).
var music_volume: int = 80
var sfx_volume: int = 80

enum Mode { RACE, TIME_TRIAL }
const DIFFICULTY_NAMES := ["Easy", "Normal", "Hard", "WTF?!"]
const MIN_LAPS := 3
const MAX_LAPS := 8

## Race setup chosen in the menus (remembered between sessions).
var mode: int = Mode.RACE
var track_id: String = "rookie_ring"
var laps: int = 3
var difficulty: int = 1  # index into DIFFICULTY_NAMES
var ghost_enabled: bool = true
var online_ranking: bool = false
var player_name: String = ""
## Best Time Trial lap per track id (seconds).
var best_laps := {}

var _save_timer: SceneTreeTimer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		music_volume = clampi(int(cfg.get_value("audio", "music_volume", music_volume)), 0, 100)
		sfx_volume = clampi(int(cfg.get_value("audio", "sfx_volume", sfx_volume)), 0, 100)
		mode = clampi(int(cfg.get_value("race", "mode", mode)), 0, 1)
		track_id = str(cfg.get_value("race", "track", track_id))
		laps = clampi(int(cfg.get_value("race", "laps", laps)), MIN_LAPS, MAX_LAPS)
		difficulty = clampi(int(cfg.get_value("race", "difficulty", difficulty)), 0, DIFFICULTY_NAMES.size() - 1)
		ghost_enabled = bool(cfg.get_value("race", "ghost", ghost_enabled))
		online_ranking = bool(cfg.get_value("online", "enabled", online_ranking))
		player_name = str(cfg.get_value("online", "player_name", player_name))
		var rec = cfg.get_value("records", "best_laps", {})
		if rec is Dictionary:
			best_laps = rec


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("race", "mode", mode)
	cfg.set_value("race", "track", track_id)
	cfg.set_value("race", "laps", laps)
	cfg.set_value("race", "difficulty", difficulty)
	cfg.set_value("race", "ghost", ghost_enabled)
	cfg.set_value("online", "enabled", online_ranking)
	cfg.set_value("online", "player_name", player_name)
	cfg.set_value("records", "best_laps", best_laps)
	cfg.save(PATH)


## Save shortly after the last change (avoids writing on every slider step).
func save_soon() -> void:
	_save_timer = get_tree().create_timer(0.6, true)
	var t := _save_timer
	t.timeout.connect(func():
		if t == _save_timer:
			save_settings())


func set_music_volume(percent: int) -> void:
	music_volume = clampi(percent, 0, 100)
	_apply_bus(MUSIC_BUS, music_volume)


func set_sfx_volume(percent: int) -> void:
	sfx_volume = clampi(percent, 0, 100)
	_apply_bus(SFX_BUS, sfx_volume)


func apply() -> void:
	_apply_bus(MUSIC_BUS, music_volume)
	_apply_bus(SFX_BUS, sfx_volume)


static func _apply_bus(bus_name: StringName, percent: int) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var lin := percent / 100.0
	# Squared curve feels more even to the ear than a straight linear slider.
	AudioServer.set_bus_mute(idx, percent <= 0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(lin * lin, 0.0001)))


## Local best Time Trial lap for a track (-1 = none yet).
func get_best_lap(id: String) -> float:
	return float(best_laps.get(id, -1.0))


## Stores a new best lap if it beats the old one. Returns true if it was a new record.
func submit_lap(id: String, t: float) -> bool:
	var old := get_best_lap(id)
	if old > 0.0 and t >= old:
		return false
	best_laps[id] = t
	save_settings()
	return true
