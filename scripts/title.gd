extends Control
## Title screen: Play, Options (volume), Fullscreen (web). Starts the menu music.

static var _demo_started := false

var _waiting_for_gesture := false
var _starting := false

@onready var play_button: Button = %PlayButton
@onready var options_button: Button = %OptionsButton
@onready var fullscreen_button: Button = %FullscreenButton
@onready var version_label: Label = %VersionLabel
@onready var sound_hint: Label = %SoundHint
@onready var options_panel = %OptionsPanel
@onready var title_label: Label = %TitleLabel
@onready var hint_label: Label = %HintLabel


func _ready() -> void:
	get_tree().paused = false
	version_label.text = "v" + str(ProjectSettings.get_setting("application/config/version", "0.2"))
	play_button.pressed.connect(_on_play)
	options_button.pressed.connect(_on_options)
	options_panel.closed.connect(func(): options_button.grab_focus())
	fullscreen_button.pressed.connect(_on_fullscreen)
	fullscreen_button.visible = OS.has_feature("web")
	play_button.grab_focus()
	get_viewport().size_changed.connect(_layout)
	_layout()
	# Menu music. On the web, browsers block audio until the first tap/click/key press:
	# Godot resumes its audio context on that first input and the music starts then.
	Music.play_menu()
	if OS.has_feature("web") and not _user_has_interacted():
		_waiting_for_gesture = true
		sound_hint.visible = true
	# Web: ?demo in the URL starts a demo race straight away (once per page load).
	if OS.has_feature("web") and not _demo_started:
		if str(JavaScriptBridge.eval("window.location.search", true)).contains("demo"):
			_demo_started = true
			get_tree().create_timer(0.5).timeout.connect(_on_play)


## Portrait vs landscape: shrink the title so everything fits a short screen.
func _layout() -> void:
	var sz := get_viewport_rect().size
	var landscape := sz.x > sz.y * 1.2
	title_label.text = "TOPDOWN RACER" if landscape else "TOPDOWN\nRACER"
	title_label.add_theme_font_size_override("font_size", 84 if landscape else 104)
	hint_label.add_theme_font_size_override("font_size", 20 if landscape else 22)
	hint_label.custom_minimum_size.x = 900.0 if landscape else 620.0


func _user_has_interacted() -> bool:
	var v = JavaScriptBridge.eval("(navigator.userActivation ? navigator.userActivation.hasBeenActive : true)", true)
	return v == true


func _input(event: InputEvent) -> void:
	if not _waiting_for_gesture:
		return
	var pressed := (event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey) and event.is_pressed()
	if pressed:
		_waiting_for_gesture = false
		sound_hint.visible = false
		if not _starting:
			Music.play_menu()  # make sure it's (still) playing now that audio is allowed


func _on_play() -> void:
	if _starting:
		return
	_starting = true
	play_button.disabled = true
	Music.fade_out()
	# Small delay lets the touch/mouse release finish before the title is freed.
	await get_tree().create_timer(0.08).timeout
	get_tree().change_scene_to_file("res://scenes/race.tscn")


func _on_options() -> void:
	options_panel.open()


func _on_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
