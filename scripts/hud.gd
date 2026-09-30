extends CanvasLayer
## In-race HUD: position, lap, timers, speed, minimap, countdown, pause & results.

signal pause_toggled(paused: bool)
signal restart_pressed
signal menu_pressed

var race: RaceManager
var _msg_timer := 0.0
var _results_timer := 0.0
var _blink := 0.0

@onready var pos_label: Label = %PosLabel
@onready var lap_label: Label = %LapLabel
@onready var time_label: Label = %TimeLabel
@onready var last_label: Label = %LastLabel
@onready var best_label: Label = %BestLabel
@onready var speed_label: Label = %SpeedLabel
@onready var center_label: Label = %CenterLabel
@onready var message_label: Label = %MessageLabel
@onready var minimap: Control = %Minimap
@onready var pause_button: Button = %PauseButton
@onready var pause_panel: Control = %PausePanel
@onready var finish_panel: Control = %FinishPanel
@onready var place_label: Label = %PlaceLabel
@onready var results_grid: GridContainer = %ResultsGrid


func setup(r: RaceManager) -> void:
	race = r
	minimap.setup(r.track, r.cars, r.player)
	pause_button.pressed.connect(_on_pause)
	%ResumeButton.pressed.connect(_on_resume)
	%PauseRestartButton.pressed.connect(func(): restart_pressed.emit())
	%PauseMenuButton.pressed.connect(func(): menu_pressed.emit())
	%RestartButton.pressed.connect(func(): restart_pressed.emit())
	%MenuButton.pressed.connect(func(): menu_pressed.emit())
	pause_panel.visible = false
	finish_panel.visible = false
	center_label.text = ""
	message_label.text = ""


func _on_pause() -> void:
	if race.state == RaceManager.State.FINISHED:
		return
	pause_panel.visible = true
	pause_toggled.emit(true)
	%ResumeButton.grab_focus()


func _on_resume() -> void:
	pause_panel.visible = false
	pause_toggled.emit(false)


func _unhandled_input(event: InputEvent) -> void:
	if race and event.is_action_pressed("pause"):
		if pause_panel.visible:
			_on_resume()
		else:
			_on_pause()
		get_viewport().set_input_as_handled()


func show_center(text: String, color: Color = Color.WHITE) -> void:
	center_label.text = text
	center_label.modulate = color
	center_label.scale = Vector2.ONE
	if text != "":
		center_label.pivot_offset = center_label.size * 0.5
		center_label.scale = Vector2(1.6, 1.6)
		create_tween().tween_property(center_label, "scale", Vector2.ONE, 0.25)


func flash_message(text: String, duration: float = 2.0) -> void:
	message_label.text = text
	message_label.modulate = Color.WHITE
	_msg_timer = duration


func _process(delta: float) -> void:
	if race == null:
		return
	var p := race.player
	var total := race.cars.size()
	pos_label.text = "%s/%d" % [RaceManager.ordinal(p.rank), total]
	lap_label.text = "LAP %d/%d" % [clamp(max(p.lap, 1), 1, race.lap_count), race.lap_count]
	if p.has_finished:
		time_label.text = RaceManager.format_time(p.finish_time)
	elif race.state == RaceManager.State.RACING:
		time_label.text = RaceManager.format_time(race.race_time - p.lap_start_time)
	else:
		time_label.text = RaceManager.format_time(0.0)
	last_label.text = "LAST " + RaceManager.format_time(p.last_lap_time)
	best_label.text = "BEST " + RaceManager.format_time(p.best_lap_time)
	speed_label.text = "%d km/h" % int(p.velocity.length() / Car.PIXELS_PER_METER * 3.6)
	# Messages: WRONG WAY has priority.
	_blink += delta
	if p.wrong_way and race.state == RaceManager.State.RACING:
		message_label.text = "WRONG WAY!"
		message_label.modulate = Color(1, 0.3, 0.25) if int(_blink * 4.0) % 2 == 0 else Color(1, 1, 1)
	elif _msg_timer > 0.0:
		_msg_timer -= delta
		if _msg_timer <= 0.0:
			message_label.text = ""
	elif message_label.text == "WRONG WAY!":
		message_label.text = ""
	if finish_panel.visible:
		_results_timer -= delta
		if _results_timer <= 0.0:
			_results_timer = 0.3
			_refresh_results()


func show_finish() -> void:
	finish_panel.visible = true
	pause_button.visible = false
	_refresh_results()
	%RestartButton.grab_focus()


func _refresh_results() -> void:
	var p := race.player
	place_label.text = "You finished %s!" % RaceManager.ordinal(race.finish_order.find(p) + 1)
	for child in results_grid.get_children():
		child.queue_free()
	for h in ["POS", "DRIVER", "TIME", "BEST LAP"]:
		_add_cell(h, Color(1, 0.85, 0.3), 22)
	# Finished cars in finish order, then the rest by live position.
	var order: Array = race.finish_order.duplicate()
	for c in race.get_standings():
		if not order.has(c):
			order.append(c)
	for i in order.size():
		var c: Car = order[i]
		var col := Color(0.55, 0.85, 1.0) if c == p else Color.WHITE
		_add_cell(RaceManager.ordinal(i + 1), col)
		_add_cell(c.car_name, col)
		if c.has_finished:
			_add_cell(RaceManager.format_time(c.finish_time), col)
		else:
			_add_cell("lap %d/%d..." % [clamp(max(c.lap, 1), 1, race.lap_count), race.lap_count], Color(0.7, 0.7, 0.7))
		_add_cell(RaceManager.format_time(c.best_lap_time), col)


func _add_cell(text: String, color: Color, size: int = 26) -> void:
	var l := Label.new()
	l.text = text
	l.modulate = color
	l.add_theme_font_size_override("font_size", size)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_grid.add_child(l)
