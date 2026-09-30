class_name RaceManager
extends Node2D
## Race manager: start grid, 3-2-1-GO countdown, laps, live positions, finish/results.
## Select the "Race" root node in scenes/race.tscn to tweak these values.

@export_group("Race Rules")
## Number of laps in a race.
@export_range(1, 20) var lap_count: int = 3
## Countdown length in seconds (3 = "3, 2, 1, GO!").
@export_range(1, 5) var countdown_seconds: int = 3
## Player's start grid slot (0 = pole position, 3 = back of the grid).
@export_range(0, 3) var player_grid_slot: int = 3

@export_group("AI Opponents")
## Global multiplier on every AI car's speed (1.0 = as set on each car). Quick difficulty knob.
@export_range(0.5, 1.5, 0.01) var ai_difficulty: float = 1.0
## Random +/- variation applied to each AI's speed every race (0.03 = +/-3%).
@export_range(0.0, 0.2, 0.005) var ai_speed_variation: float = 0.03

@export_group("Testing")
## Demo mode: the AI drives your car too (attract mode / quick testing).
## In the web build you can also add ?demo (and optionally &laps=1) to the page URL.
@export var demo_mode: bool = false

enum State { COUNTDOWN, RACING, FINISHED }

var state: State = State.COUNTDOWN
var race_time := 0.0
var cars: Array = []
var player: Car
var finish_order: Array = []
var _countdown_left := 0.0
var _last_count_shown := -1
var _go_timer := 0.0

@onready var track: Track = $Track
@onready var skid_marks: Node2D = $SkidMarks
@onready var hud = $HUD
@onready var touch_controls = $TouchControls
@onready var camera = $Camera
@onready var beep: AudioStreamPlayer = $Beep
@onready var go_beep: AudioStreamPlayer = $GoBeep


func _ready() -> void:
	get_tree().paused = false
	randomize()
	_read_url_options()
	for c in $Cars.get_children():
		if c is Car:
			cars.append(c)
			if c.driver == Car.Driver.PLAYER and player == null:
				player = c
	if player == null and not cars.is_empty():
		player = cars[0]
		player.driver = Car.Driver.PLAYER
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
			c.speed_jitter = ai_difficulty * (1.0 + randf_range(-ai_speed_variation, ai_speed_variation))
		c.lap_completed.connect(_on_lap_completed)
		c.race_finished.connect(_on_car_finished)
	camera.target = player
	camera.snap_to_target()
	hud.setup(self)
	hud.pause_toggled.connect(set_paused)
	hud.restart_pressed.connect(restart)
	hud.menu_pressed.connect(go_to_menu)
	player.start_sounds()
	_countdown_left = countdown_seconds + 0.7


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


func _update_ranks() -> void:
	var sorted := cars.duplicate()
	sorted.sort_custom(func(a, b): return a.get_progress() > b.get_progress())
	for i in sorted.size():
		sorted[i].rank = i + 1


func get_standings() -> Array:
	var sorted := cars.duplicate()
	sorted.sort_custom(func(a, b): return a.rank < b.rank)
	return sorted


func _on_lap_completed(car: Car, lap_time: float) -> void:
	if car != player or car.has_finished:
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

