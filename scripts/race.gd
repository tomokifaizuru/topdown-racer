class_name RaceManager
extends Node2D
## Race manager: loads the chosen track, start grid, 3-2-1-GO countdown, laps, live positions,
## finish/results, AI difficulty + rubber-band, and Time Trial (flying laps, best lap, ghost).
## Select the "Race" root node in scenes/race.tscn to tweak these values.

enum Mode { RACE, TIME_TRIAL }

@export_group("Race Rules")
## Number of laps in a race (only used when use_menu_settings is off; the menu offers 3-8).
@export_range(1, 20) var lap_count: int = 3
## Countdown length in seconds (3 = "3, 2, 1, GO!").
@export_range(1, 5) var countdown_seconds: int = 3
## Player's start grid slot in Race mode (0 = pole position, 7 = back of an 8-car grid).
@export_range(0, 11) var player_grid_slot: int = 7

@export_group("Menu Settings")
## Take mode / track / laps / difficulty from the menus (Settings autoload).
## Turn OFF to test the values below straight from the editor (F6 on race.tscn).
@export var use_menu_settings: bool = true
## Mode used when use_menu_settings is off.
@export var mode: Mode = Mode.RACE
## Track id used when use_menu_settings is off (see scripts/track_catalog.gd).
@export var track_id: String = "rookie_ring"
## Difficulty used when use_menu_settings is off (0 Easy, 1 Normal, 2 Hard, 3 WTF?!).
@export_range(0, 3) var difficulty_level: int = 1

@export_group("AI Opponents")
## Global multiplier on every AI car's speed, on top of the chosen difficulty (1.0 = off).
@export_range(0.5, 1.5, 0.01) var ai_difficulty: float = 1.0
## Random +/- variation applied to each AI's speed every race (0.03 = +/-3%).
@export_range(0.0, 0.2, 0.005) var ai_speed_variation: float = 0.03
## The difficulty levels, in menu order. Edit the .tres files in res://difficulty/.
@export var difficulty_profiles: Array[DifficultyProfile] = []
## Rubber-band reaches full strength when an AI car is this far (px) ahead/behind you.
@export var rubber_band_distance: float = 3000.0

@export_group("Time Trial")
## Ghost recording rate (samples per second). 20 is smooth and small (~1 KB per 5 s).
@export_range(5, 60) var ghost_sample_rate: int = 20
## Show the ghost of your best lap (only used when use_menu_settings is off).
@export var ghost_enabled: bool = true
## Your car starts this far (px) behind the line in Time Trial, so the timed lap is a flying lap.
@export var tt_run_up: float = 700.0

@export_group("Testing")
## Demo mode: the AI drives your car too (attract mode / quick testing).
## In the web build you can also add ?demo (and optionally &laps=N, &track=sepang,
## &mode=tt, &diff=0..3) to the page URL.
@export var demo_mode: bool = false

enum State { COUNTDOWN, RACING, FINISHED }

var state: State = State.COUNTDOWN
var race_time := 0.0
var cars: Array = []
var player: Car
var finish_order: Array = []
var profile: DifficultyProfile
var session_best := -1.0
var record_before := -1.0
var _countdown_left := 0.0
var _last_count_shown := -1
var _go_timer := 0.0
var _rb_timer := 0.0
var _rec := PackedFloat32Array()
var _rec_frame := 0
var _ghost_start := -1.0
var _online: Node

@onready var track: Track = $Track
@onready var skid_marks: Node2D = $SkidMarks
@onready var hud = $HUD
@onready var touch_controls = $TouchControls
@onready var camera = $Camera
@onready var beep: AudioStreamPlayer = $Beep
@onready var go_beep: AudioStreamPlayer = $GoBeep
@onready var ghost: GhostCar = $Ghost


func _ready() -> void:
	get_tree().paused = false
	randomize()
	if use_menu_settings:
		mode = Settings.mode as Mode
		track_id = Settings.track_id
		lap_count = Settings.laps
		difficulty_level = Settings.difficulty
		ghost_enabled = Settings.ghost_enabled
	_read_url_options()
	_load_track()
	if not difficulty_profiles.is_empty():
		profile = difficulty_profiles[clampi(difficulty_level, 0, difficulty_profiles.size() - 1)]
	for c in $Cars.get_children():
		if c is Car:
			cars.append(c)
			if c.driver == Car.Driver.PLAYER and player == null:
				player = c
	if player == null and not cars.is_empty():
		player = cars[0]
		player.driver = Car.Driver.PLAYER
	if mode == Mode.TIME_TRIAL:
		# Solo: remove the AI cars, unlimited flying laps.
		for c in cars.duplicate():
			if c != player:
				cars.erase(c)
				c.get_parent().remove_child(c)
				c.queue_free()
		lap_count = 0
		player.flying_start = true
		var off := track.length - tt_run_up
		player.global_position = track.sample_position(off)
		player.rotation = track.get_tangent(off).angle()
		player.velocity = Vector2.ZERO
	else:
		# Start grid: player in its chosen slot, AI cars fill the rest in node order.
		var pslot: int = clamp(player_grid_slot, 0, cars.size() - 1)
		var slot := 0
		for c in cars:
			if c == player:
				continue
			if slot == pslot:
				slot += 1
			_place_on_grid(c, slot)
			slot += 1
		_place_on_grid(player, pslot)
	for c in cars:
		c.track = track
		c.race = self
		if c != player:
			_apply_difficulty(c)
		c.lap_completed.connect(_on_lap_completed)
		c.race_finished.connect(_on_car_finished)
	player.lap_started.connect(_on_player_lap_started)
	_setup_ghost()
	camera.target = player
	camera.snap_to_target()
	hud.setup(self)
	hud.pause_toggled.connect(set_paused)
	hud.restart_pressed.connect(restart)
	hud.menu_pressed.connect(go_to_menu)
	player.start_sounds()
	_countdown_left = countdown_seconds + 0.7


func is_time_trial() -> bool:
	return mode == Mode.TIME_TRIAL


func get_difficulty_name() -> String:
	return profile.display_name if profile else ""


func _read_url_options() -> void:
	if not OS.has_feature("web"):
		return
	var q := str(JavaScriptBridge.eval("window.location.search", true))
	if q.contains("demo"):
		demo_mode = true
	var re := RegEx.new()
	re.compile("laps=(\\d+)")
	var m := re.search(q)
	if m:
		lap_count = clampi(int(m.get_string(1)), 1, 20)
	re.compile("track=([a-z_]+)")
	m = re.search(q)
	if m:
		track_id = m.get_string(1)
	re.compile("diff=(\\d)")
	m = re.search(q)
	if m:
		difficulty_level = clampi(int(m.get_string(1)), 0, 3)
	if q.contains("mode=tt"):
		mode = Mode.TIME_TRIAL
	elif q.contains("mode=race"):
		mode = Mode.RACE


## Swaps the Track node for the selected track scene.
func _load_track() -> void:
	var path := TrackCatalog.scene_path(track_id)
	track_id = TrackCatalog.TRACKS[TrackCatalog.index_of(track_id)]["id"]
	if track.scene_file_path != path:
		var ps: PackedScene = load(path)
		var t: Track = ps.instantiate()
		var idx := track.get_index()
		remove_child(track)
		track.queue_free()
		t.name = "Track"
		add_child(t)
		move_child(t, idx)
		track = t
	RenderingServer.set_default_clear_color(track.grass_color)


func _apply_difficulty(c: Car) -> void:
	var p := profile
	var jitter := ai_difficulty * (1.0 + randf_range(-ai_speed_variation, ai_speed_variation))
	c.speed_jitter = jitter
	if p == null:
		return
	c.max_speed *= p.speed
	c.acceleration *= p.acceleration
	c.steer_speed_deg *= p.steering
	c.grip *= p.grip
	c.difficulty_corner = p.corner_margin
	c.difficulty_avoid = p.avoidance
	c.ai_apex_cut = maxf(c.ai_apex_cut, p.apex_cut)


func _place_on_grid(car: Car, slot: int) -> void:
	var tf := track.get_grid_transform(slot)
	car.global_position = tf.origin
	car.rotation = tf.get_rotation()
	car.velocity = Vector2.ZERO


func _process(delta: float) -> void:
	if state == State.COUNTDOWN:
		_countdown_left -= delta
		var n := int(ceil(_countdown_left))
		if n >= 1 and n <= countdown_seconds and n != _last_count_shown:
			_last_count_shown = n
			hud.show_center(str(n), Color(1, 0.85, 0.2))
			beep.play()
		if _countdown_left <= 0.0:
			_start_race()
	elif _go_timer > 0.0:
		_go_timer -= delta
		if _go_timer <= 0.0:
			hud.show_center("")


func _start_race() -> void:
	state = State.RACING
	race_time = 0.0
	hud.show_center("GO!", Color(0.3, 1, 0.4))
	go_beep.play()
	_go_timer = 0.9
	for c in cars:
		c.controls_enabled = true
		c.lap_start_time = 0.0
	if demo_mode:
		player.autopilot = true


func _physics_process(delta: float) -> void:
	if state != State.COUNTDOWN:
		race_time += delta
	_update_ranks()
	if is_time_trial():
		_update_time_trial()
	elif state != State.COUNTDOWN:
		_rb_timer -= delta
		if _rb_timer <= 0.0:
			_rb_timer = 0.5
			_update_rubber_band()


func _update_ranks() -> void:
	var sorted := cars.duplicate()
	sorted.sort_custom(func(a, b): return a.get_progress() > b.get_progress())
	for i in sorted.size():
		sorted[i].rank = i + 1


## AI far ahead of you ease off a little, AI far behind push a little (per difficulty).
func _update_rubber_band() -> void:
	var pp := player.get_progress()
	for c in cars:
		if c == player:
			continue
		if profile == null or player.has_finished or c.has_finished:
			c.rubber_band = 1.0
			continue
		var gap: float = c.get_progress() - pp
		var f := clampf(absf(gap) / maxf(rubber_band_distance, 1.0), 0.0, 1.0)
		c.rubber_band = 1.0 - profile.rubber_band_ahead * f if gap > 0.0 else 1.0 + profile.rubber_band_behind * f


func get_standings() -> Array:
	var sorted := cars.duplicate()
	sorted.sort_custom(func(a, b): return a.rank < b.rank)
	return sorted


# ------------------------------------------------------------ Time Trial + ghost
func _setup_ghost() -> void:
	ghost.follow = player
	ghost.visible = false
	record_before = Settings.get_best_lap(track_id)
	if not is_time_trial() or not ghost_enabled:
		return
	var d := GhostCar.load_ghost(track_id)
	if not d.is_empty():
		ghost.set_samples(d["samples"], float(d.get("hz", ghost_sample_rate)), float(d.get("lap_time", -1.0)))


func _update_time_trial() -> void:
	if state == State.RACING and player.lap >= 1:
		var step := maxi(1, int(round(Engine.physics_ticks_per_second / float(ghost_sample_rate))))
		if _rec_frame % step == 0:
			_rec.append(player.global_position.x)
			_rec.append(player.global_position.y)
			_rec.append(player.rotation)
		_rec_frame += 1
	if ghost.has_data() and _ghost_start >= 0.0:
		ghost.show_at(race_time - _ghost_start)


func _begin_lap_recording() -> void:
	_rec = PackedFloat32Array()
	_rec_frame = 0
	_ghost_start = race_time
	if ghost.has_data():
		ghost.show_at(0.0)


func _on_player_lap_started(_car: Car) -> void:
	if is_time_trial():
		_begin_lap_recording()
		hud.flash_message("TIMED LAP!", 1.2)


func _finish_time_trial_lap(lap_time: float) -> void:
	var old := Settings.get_best_lap(track_id)
	var delta_txt := ""
	if old > 0.0:
		delta_txt = "   %s%.3f" % ["+" if lap_time >= old else "-", absf(lap_time - old)]
	if session_best < 0.0 or lap_time < session_best:
		session_best = lap_time
	var valid := lap_time > track.length / (player.max_speed * 1.05) and not demo_mode
	if valid and Settings.submit_lap(track_id, lap_time):
		GhostCar.save_ghost(track_id, _rec, ghost_sample_rate, lap_time)
		if ghost_enabled:
			ghost.set_samples(_rec, ghost_sample_rate, lap_time)
		hud.flash_message("NEW RECORD!  %s%s" % [format_time(lap_time), delta_txt], 3.0)
		_submit_online(lap_time)
	else:
		hud.flash_message("LAP %s%s" % [format_time(lap_time), delta_txt], 2.5)
		if demo_mode and ghost_enabled and (not ghost.has_data() or lap_time < ghost.lap_time):
			# Demo only: keep the lap as an in-memory ghost (never saved) and make the
			# autopilot drive a little differently each lap so the ghost is visible.
			ghost.set_samples(_rec, ghost_sample_rate, lap_time)
	if demo_mode:
		player.difficulty_corner = 0.72 if player.lap % 2 == 0 else 0.85
	_begin_lap_recording()


func _submit_online(lap_time: float) -> void:
	if not Settings.online_ranking or Settings.player_name.strip_edges() == "" or player.autopilot:
		return
	if not OnlineLeaderboard.has_board(track_id):
		return
	_online = OnlineLeaderboard.new()
	add_child(_online)
	_online.submitted.connect(func(ok: bool, msg: String):
		hud.flash_message("Online ranking: sent!" if ok else "Online ranking: " + msg, 2.5))
	_online.submit_lap(track_id, Settings.player_name, lap_time)


# ------------------------------------------------------------ laps / finish
func _on_lap_completed(car: Car, lap_time: float) -> void:
	if car != player or car.has_finished:
		return
	if is_time_trial():
		_finish_time_trial_lap(lap_time)
		return
	var txt := "LAP %d/%d   %s" % [car.lap, lap_count, format_time(lap_time)]
	if car.lap == lap_count:
		txt = "FINAL LAP!   %s" % format_time(lap_time)
	hud.flash_message(txt, 2.2)


func _on_car_finished(car: Car) -> void:
	finish_order.append(car)
	if car == player:
		state = State.FINISHED
		player.autopilot = true  # AI drives the cool-down lap
		touch_controls.set_active(false)
		hud.flash_message("FINISH!", 1.5)
		get_tree().create_timer(1.3).timeout.connect(hud.show_finish)


func set_paused(p: bool) -> void:
	if state == State.FINISHED and p:
		return
	get_tree().paused = p
	touch_controls.set_active(not p)


func restart() -> void:
	get_tree().paused = false
	# Small delay lets the touch/mouse release finish before the scene is freed.
	await get_tree().create_timer(0.08).timeout
	get_tree().reload_current_scene()


func go_to_menu() -> void:
	get_tree().paused = false
	await get_tree().create_timer(0.08).timeout
	get_tree().change_scene_to_file("res://scenes/title.tscn")


static func format_time(t: float) -> String:
	if t < 0.0:
		return "--:--.---"
	var m := int(t / 60.0)
	var s := fmod(t, 60.0)
	return "%d:%06.3f" % [m, s]


static func ordinal(n: int) -> String:
	match n:
		1: return "1st"
		2: return "2nd"
		3: return "3rd"
	return "%dth" % n
