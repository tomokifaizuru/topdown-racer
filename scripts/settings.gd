extends Node
## Autoload "Settings": BGM / SFX volume, saved to user://settings.cfg
## (on the web build user:// is stored in the browser's IndexedDB).

const PATH := "user://settings.cfg"
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"

## Volumes in percent (0-100).
var music_volume: int = 80
var sfx_volume: int = 80

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


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
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
