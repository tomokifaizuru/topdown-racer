extends Control
## Options overlay: BGM and SFX volume sliders (0-100%) + Back.
## Used on the title screen and in the pause menu. Values are saved by the Settings autoload.

signal closed

var _preview_cooldown := 0.0

@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var music_value: Label = %MusicValue
@onready var sfx_value: Label = %SfxValue
@onready var back_button: Button = %BackButton
@onready var sfx_preview: AudioStreamPlayer = $SfxPreview


func _ready() -> void:
	visible = false
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	back_button.pressed.connect(close)


func open() -> void:
	music_slider.set_value_no_signal(Settings.music_volume)
	sfx_slider.set_value_no_signal(Settings.sfx_volume)
	_update_labels()
	visible = true
	back_button.grab_focus()


func close() -> void:
	if not visible:
		return
	Settings.save_settings()
	visible = false
	closed.emit()


func _process(delta: float) -> void:
	_preview_cooldown -= delta


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		close()
		get_viewport().set_input_as_handled()


func _on_music_changed(v: float) -> void:
	Settings.set_music_volume(int(round(v)))
	Settings.save_soon()
	_update_labels()


func _on_sfx_changed(v: float) -> void:
	Settings.set_sfx_volume(int(round(v)))
	Settings.save_soon()
	_update_labels()
	if _preview_cooldown <= 0.0 and v > 0.0:
		_preview_cooldown = 0.18
		sfx_preview.play()  # let the player hear the new SFX level


func _update_labels() -> void:
	music_value.text = "%d%%" % int(round(music_slider.value))
	sfx_value.text = "%d%%" % int(round(sfx_slider.value))
