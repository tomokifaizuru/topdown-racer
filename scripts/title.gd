extends Control
## Title screen.

static var _demo_started := false

@onready var play_button: Button = %PlayButton
@onready var fullscreen_button: Button = %FullscreenButton
@onready var version_label: Label = %VersionLabel


func _ready() -> void:
	get_tree().paused = false
	version_label.text = "v" + str(ProjectSettings.get_setting("application/config/version", "0.1"))
	play_button.pressed.connect(_on_play)
	fullscreen_button.pressed.connect(_on_fullscreen)
	fullscreen_button.visible = OS.has_feature("web")
	play_button.grab_focus()
	# Web: ?demo in the URL starts a demo race straight away (once per page load).
	if OS.has_feature("web") and not _demo_started:
		if str(JavaScriptBridge.eval("window.location.search", true)).contains("demo"):
			_demo_started = true
			get_tree().create_timer(0.5).timeout.connect(_on_play)


func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/race.tscn")


func _on_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
