extends Control
## Title screen and menus: Title -> Mode (Race / Time Trial) -> Setup (track, laps,
## difficulty or ghost/online) -> Start. Also Options (volume) and Fullscreen (web).
## All choices are saved by the Settings autoload.

static var _demo_started := false

## Number of online Time Trial entries shown in the setup page.
@export_range(1, 10) var online_top_count: int = 5

var _waiting_for_gesture := false
var _starting := false
var _track_index := 0
var _online: OnlineLeaderboard
static var _online_cache := {}

@onready var play_button: Button = %PlayButton
@onready var options_button: Button = %OptionsButton
@onready var fullscreen_button: Button = %FullscreenButton
@onready var version_label: Label = %VersionLabel
@onready var sound_hint: Label = %SoundHint
@onready var options_panel = %OptionsPanel
@onready var title_label: Label = %TitleLabel
@onready var hint_label: Label = %HintLabel
@onready var main_page: Control = %Center
@onready var mode_page: Control = %ModePage
@onready var setup_page: Control = %SetupPage
@onready var body: BoxContainer = %Body
@onready var track_preview: Control = %TrackPreview


func _ready() -> void:
	get_tree().paused = false
	version_label.text = "v" + str(ProjectSettings.get_setting("application/config/version", "0.3"))
	play_button.pressed.connect(_on_play)
	options_button.pressed.connect(_on_options)
	options_panel.closed.connect(func(): options_button.grab_focus())
	fullscreen_button.pressed.connect(_on_fullscreen)
	fullscreen_button.visible = OS.has_feature("web")
	%RaceButton.pressed.connect(_on_mode.bind(Settings.Mode.RACE))
	%TTButton.pressed.connect(_on_mode.bind(Settings.Mode.TIME_TRIAL))
	%ModeBackButton.pressed.connect(_show_page.bind(main_page))
	%SetupBack.pressed.connect(_show_page.bind(mode_page))
	%StartButton.pressed.connect(_on_start)
	%PrevTrack.pressed.connect(_change_track.bind(-1))
	%NextTrack.pressed.connect(_change_track.bind(1))
	%LapsMinus.pressed.connect(_change_laps.bind(-1))
	%LapsPlus.pressed.connect(_change_laps.bind(1))
	%DiffPrev.pressed.connect(_change_difficulty.bind(-1))
	%DiffNext.pressed.connect(_change_difficulty.bind(1))
	%GhostToggle.toggled.connect(_on_ghost_toggled)
	%OnlineToggle.toggled.connect(_on_online_toggled)
	%NameButton.pressed.connect(_on_name_pressed)
	%NameEdit.text_submitted.connect(func(_t): _finish_name_edit())
	%NameEdit.focus_exited.connect(_finish_name_edit)
	_online = OnlineLeaderboard.new()
	add_child(_online)
	_online.top_loaded.connect(_on_top_loaded)
	_track_index = TrackCatalog.index_of(Settings.track_id)
	_show_page(main_page)
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
		var q := str(JavaScriptBridge.eval("window.location.search", true))
		if q.contains("demo"):
			_demo_started = true
			get_tree().create_timer(0.5).timeout.connect(_on_start)
		elif q.contains("menu=setup"):
			# Screenshot/test helper: open the setup page directly (&track=<id> optional).
			var re := RegEx.new()
			re.compile("track=([a-z_]+)")
			var m := re.search(q)
			if m:
				_track_index = TrackCatalog.index_of(m.get_string(1))
				Settings.track_id = TrackCatalog.TRACKS[_track_index]["id"]
			_on_mode(Settings.Mode.TIME_TRIAL if q.contains("mode=tt") else Settings.Mode.RACE)


## Portrait vs landscape: shrink the title and lay the setup page out side by side.
func _layout() -> void:
	var sz := get_viewport_rect().size
	var landscape := sz.x > sz.y * 1.2
	title_label.text = "TOPDOWN RACER" if landscape else "TOPDOWN\nRACER"
	title_label.add_theme_font_size_override("font_size", 84 if landscape else 104)
	hint_label.add_theme_font_size_override("font_size", 20 if landscape else 22)
	hint_label.custom_minimum_size.x = 900.0 if landscape else 620.0
	body.vertical = not landscape
	%SetupTitle.add_theme_font_size_override("font_size", 38 if landscape else 48)
	var row_h := 60.0 if landscape else 70.0
	for b in [%LapsMinus, %LapsPlus, %DiffPrev, %DiffNext, %GhostToggle, %OnlineToggle, %NameButton, %NameEdit]:
		b.custom_minimum_size.y = row_h
	for b in [%SetupBack, %StartButton]:
		b.custom_minimum_size.y = 80.0 if landscape else 96.0
	%TrackPreview.custom_minimum_size = Vector2(240, 200) if landscape else Vector2(240, minf(520.0, sz.y * 0.36))
	# Portrait: fixed-height preview, options take the rest. Landscape: side by side.
	%TrackBox.size_flags_vertical = Control.SIZE_EXPAND_FILL if landscape else Control.SIZE_FILL
	%OptionsBox.size_flags_vertical = Control.SIZE_EXPAND_FILL


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


func _unhandled_input(event: InputEvent) -> void:
	if options_panel.visible or not event.is_action_pressed("ui_cancel"):
		return
	if setup_page.visible:
		_show_page(mode_page)
		get_viewport().set_input_as_handled()
	elif mode_page.visible:
		_show_page(main_page)
		get_viewport().set_input_as_handled()


func _show_page(page: Control) -> void:
	main_page.visible = page == main_page
	mode_page.visible = page == mode_page
	setup_page.visible = page == setup_page
	%Shade.color.a = 0.35 if page == main_page else 0.7
	if page == main_page:
		play_button.grab_focus()
	elif page == mode_page:
		(%TTButton if Settings.mode == Settings.Mode.TIME_TRIAL else %RaceButton).grab_focus()
	else:
		%StartButton.grab_focus()


func _on_play() -> void:
	_show_page(mode_page)


func _on_mode(m: int) -> void:
	Settings.mode = m
	Settings.save_soon()
	var tt := m == Settings.Mode.TIME_TRIAL
	%SetupTitle.text = "TIME TRIAL SETUP" if tt else "RACE SETUP"
	%LapsRow.visible = not tt
	%CarsInfo.visible = not tt
	%DiffRow.visible = not tt
	%GhostRow.visible = tt
	%OnlineRow.visible = tt
	%NameRow.visible = tt
	%BestLabel.visible = tt
	%OnlineList.visible = tt
	_refresh_setup()
	_show_page(setup_page)


# ------------------------------------------------------------ setup page
func _refresh_setup() -> void:
	var id: String = TrackCatalog.TRACKS[_track_index]["id"]
	var info := TrackCatalog.get_info(id)
	track_preview.set_track(info)
	%TrackName.text = info["name"]
	%TrackInfo.text = "Track %d/%d  -  %.2f km" % [_track_index + 1, TrackCatalog.count(), info["km"]]
	%TrackBlurb.text = info.get("blurb", "")
	%LapsValue.text = str(Settings.laps)
	%DiffValue.text = Settings.DIFFICULTY_NAMES[Settings.difficulty]
	%DiffValue.modulate = [Color(0.6, 1, 0.6), Color.WHITE, Color(1, 0.75, 0.4), Color(1, 0.35, 0.35)][Settings.difficulty]
	%GhostToggle.set_pressed_no_signal(Settings.ghost_enabled)
	%GhostToggle.text = "ON" if Settings.ghost_enabled else "OFF"
	%OnlineToggle.set_pressed_no_signal(Settings.online_ranking)
	%OnlineToggle.text = "ON  (send best laps)" if Settings.online_ranking else "OFF"
	%NameButton.text = Settings.player_name if Settings.player_name != "" else "Set name"
	var best := Settings.get_best_lap(id)
	var has_ghost := FileAccess.file_exists(GhostCar.file_path(id))
	%BestLabel.text = "Your best: %s%s" % [RaceManager.format_time(best), "  (ghost saved)" if has_ghost else ""]
	if Settings.mode == Settings.Mode.TIME_TRIAL:
		_show_online(id)


func _change_track(d: int) -> void:
	_track_index = posmod(_track_index + d, TrackCatalog.count())
	Settings.track_id = TrackCatalog.TRACKS[_track_index]["id"]
	Settings.save_soon()
	_refresh_setup()


func _change_laps(d: int) -> void:
	Settings.laps = clampi(Settings.laps + d, Settings.MIN_LAPS, Settings.MAX_LAPS)
	Settings.save_soon()
	_refresh_setup()


func _change_difficulty(d: int) -> void:
	Settings.difficulty = posmod(Settings.difficulty + d, Settings.DIFFICULTY_NAMES.size())
	Settings.save_soon()
	_refresh_setup()


func _on_ghost_toggled(on: bool) -> void:
	Settings.ghost_enabled = on
	Settings.save_soon()
	_refresh_setup()


func _on_online_toggled(on: bool) -> void:
	Settings.online_ranking = on
	Settings.save_soon()
	if on and Settings.player_name == "":
		_on_name_pressed()
	_refresh_setup()


func _on_name_pressed() -> void:
	if OS.has_feature("web"):
		var cur := Settings.player_name.replace("\\", "").replace("'", "")
		var v = JavaScriptBridge.eval("prompt('Your name for the online ranking (letters, numbers, - _ . @)', '%s')" % cur, true)
		if v is String:
			_set_name(v)
	else:
		%NameButton.visible = false
		%NameEdit.visible = true
		%NameEdit.text = Settings.player_name
		%NameEdit.grab_focus()


func _finish_name_edit() -> void:
	if not %NameEdit.visible:
		return
	%NameEdit.visible = false
	%NameButton.visible = true
	_set_name(%NameEdit.text)


func _set_name(n: String) -> void:
	Settings.player_name = OnlineLeaderboard.clean_name(n)
	Settings.save_soon()
	_refresh_setup()


func _show_online(id: String) -> void:
	if not OnlineLeaderboard.has_board(id):
		%OnlineList.text = ""
		return
	if _online_cache.has(id):
		_render_online(id, _online_cache[id], "")
	else:
		%OnlineList.text = "Online top %d: loading..." % online_top_count
		_online.fetch_top(id, online_top_count)


func _on_top_loaded(id: String, entries: Array, error: String) -> void:
	if error == "":
		_online_cache[id] = entries
	if TrackCatalog.TRACKS[_track_index]["id"] == id and Settings.mode == Settings.Mode.TIME_TRIAL:
		_render_online(id, entries, error)


func _render_online(_id: String, entries: Array, error: String) -> void:
	if error != "":
		%OnlineList.text = "Online top %d: %s" % [online_top_count, error]
		return
	if entries.is_empty():
		%OnlineList.text = "Online top %d: no laps yet - be the first!" % online_top_count
		return
	var lines := PackedStringArray(["Online top %d:" % online_top_count])
	for i in entries.size():
		lines.append("%d. %s  %s" % [i + 1, entries[i]["name"], RaceManager.format_time(entries[i]["time"])])
	%OnlineList.text = "\n".join(lines)


func _on_start() -> void:
	if _starting:
		return
	_starting = true
	%StartButton.disabled = true
	play_button.disabled = true
	Settings.save_settings()
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
