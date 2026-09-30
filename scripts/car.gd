class_name Car
extends CharacterBody2D
## Arcade top-down car, used for BOTH the player and the AI opponents.
##
## Tweak: open scenes/race.tscn, select Cars > Player (or CPU1..CPU7) and edit
## the values in the Inspector. To change ALL cars at once, edit scenes/car.tscn.
## Units: pixels and seconds. About 12 px = 1 metre (HUD km/h uses PIXELS_PER_METER).

signal lap_completed(car: Car, lap_time: float)
signal race_finished(car: Car)
## Emitted when the car crosses the start line for the first time (Time Trial flying start).
signal lap_started(car: Car)

enum Driver { PLAYER, AI }
## CURVATURE = AI reads the track curvature ahead and brakes just enough (default, v0.3).
## SIMPLE = the old v0.2 heuristic (ai_corner_slowdown / ai_corner_angle_deg).
enum CornerModel { CURVATURE, SIMPLE }

const PIXELS_PER_METER := 12.0

@export_group("Driver & Look")
## PLAYER = keyboard / touch controls. AI = follows the track's racing line.
@export var driver: Driver = Driver.AI
## Name shown in the results table.
@export var car_name: String = "CPU"
@export var body_color: Color = Color(0.85, 0.2, 0.2)
@export var stripe_color: Color = Color(1, 1, 1)
@export var car_number: int = 1

@export_group("Engine & Brakes")
## Top speed on asphalt (px/s). 820 px/s ~ 246 km/h on the HUD.
@export var max_speed: float = 820.0
## Forward acceleration (px/s per second).
@export var acceleration: float = 440.0
## Braking deceleration (px/s per second).
@export var brake_force: float = 1000.0
## Top speed in reverse (px/s).
@export var reverse_max_speed: float = 240.0
## Reverse acceleration (px/s per second), when holding brake while stopped.
@export var reverse_acceleration: float = 320.0
## Speed lost per second when no pedal is pressed (engine braking / rolling drag).
@export var coast_drag: float = 170.0

@export_group("Steering")
## Maximum turn rate in degrees per second.
@export var steer_speed_deg: float = 175.0
## Below this speed steering is weaker, so the car can't spin on the spot.
@export var steer_full_speed: float = 230.0
## Turn-rate multiplier at top speed (lower = more stable at high speed).
@export_range(0.1, 1.0, 0.01) var high_speed_steer_factor: float = 0.6
## How quickly the steering input ramps in/out (higher = twitchier). Smooths buttons/keys.
@export var steer_smoothing: float = 9.0

@export_group("Grip & Drift")
## Sideways grip: how fast sideways sliding is removed (per second). Higher = on rails.
@export var grip: float = 7.5
## Grip while drifting (brake + steer at speed, or Space/handbrake). Lower = longer slides.
@export var drift_grip: float = 1.4
## Minimum speed for brake+steer to start a drift.
@export var drift_min_speed: float = 380.0
## While drifting, brake only applies this fraction of its force (so you keep speed).
@export_range(0.0, 1.0, 0.01) var drift_brake_factor: float = 0.3
## Extra turn rate while drifting (1.0 = none).
@export var drift_steer_boost: float = 1.3
## Speed lost per second while sliding sideways.
@export var slide_speed_loss: float = 70.0
## Sideways speed (px/s) above which skid marks and tyre squeal start.
@export var skid_threshold: float = 120.0

@export_group("Surface & Collisions")
## Top-speed multiplier on grass (0.45 = 45% of max speed).
@export_range(0.1, 1.0, 0.01) var offroad_max_speed_factor: float = 0.45
## How hard the grass slows you down when you arrive too fast (px/s per second).
@export var offroad_drag: float = 950.0
## Grip multiplier on grass.
@export_range(0.1, 1.0, 0.01) var offroad_grip_factor: float = 0.7
## Bounce off walls (0 = stick, 1 = full bounce).
@export_range(0.0, 1.0, 0.01) var wall_bounce: float = 0.35
## Fraction of speed kept after a hard wall hit.
@export_range(0.0, 1.0, 0.01) var wall_speed_keep: float = 0.7

@export_group("AI")
## AI top speed = max_speed * ai_speed_factor (then Race.ai_difficulty and random variation).
@export_range(0.5, 1.2, 0.01) var ai_speed_factor: float = 0.93
## How far ahead on the racing line the AI aims (px), plus ai_lookahead_per_speed * speed.
@export var ai_lookahead: float = 130.0
@export var ai_lookahead_per_speed: float = 0.3
## Preferred sideways lane offset from the racing line (px, + = right).
@export var ai_lane_offset: float = 0.0
## Steering responsiveness of the AI.
@export var ai_steer_gain: float = 2.6
## How much the AI slows for corners (0 = never, 0.6 = a lot).
@export_range(0.0, 0.9, 0.01) var ai_corner_slowdown: float = 0.42
## Upcoming heading change (degrees) that counts as a "full" corner.
@export var ai_corner_angle_deg: float = 75.0
## Distance at which the AI starts steering around cars ahead of it.
@export var ai_avoid_distance: float = 170.0
## How far (px) the AI moves sideways to avoid a car ahead.
@export var ai_avoid_strength: float = 70.0
## How the AI decides its corner speed (see CornerModel above).
@export var ai_corner_model: CornerModel = CornerModel.CURVATURE
## CURVATURE model: fraction of the car's steering the AI dares to use in corners, on top of
## the difficulty setting (1.0 = as the difficulty says, lower = more careful/slower).
@export_range(0.5, 1.3, 0.01) var ai_corner_margin: float = 1.0
## CURVATURE model: fraction of brake_force the AI counts on when braking for a corner.
@export_range(0.3, 1.0, 0.01) var ai_brake_margin: float = 0.7
## Racing line: how much the AI cuts to the inside of corners (0 = follows the centre line,
## 1 = uses most of the road). Usually set by the difficulty.
@export_range(0.0, 1.0, 0.01) var ai_apex_cut: float = 0.0
## Seconds of slow driving before a stuck AI car is put back on the track.
@export var ai_respawn_after: float = 6.0

# ------------------------------------------------------------- runtime state
var track: Track
var race  # Race manager (scripts/race.gd)
var controls_enabled := false
## When true an AI drives this car (used for the player's cool-down lap).
var autopilot := false
var lap := 0
var next_checkpoint := 0
var checkpoints_passed := 0
var lap_start_time := 0.0
var last_lap_time := -1.0
var best_lap_time := -1.0
var lap_times: Array[float] = []
var has_finished := false
var finish_time := 0.0
var rank := 1
var wrong_way := false
var track_offset := 0.0
var on_grass := false
var is_skidding := false
## Per-race AI speed multiplier (difficulty * random variation). Set by the race.
var speed_jitter := 1.0
## Corner margin from the difficulty profile (multiplied with ai_corner_margin). Set by the race.
var difficulty_corner := 0.85
## Avoidance multiplier from the difficulty profile. Set by the race.
var difficulty_avoid := 1.0
## Rubber-band speed multiplier, updated by the race (1.0 = off).
var rubber_band := 1.0
## Number of times this car was put back on track (debug/tests).
var respawn_count := 0
## True in Time Trial: the lap timer starts when crossing the line (flying lap).
var flying_start := false

var _steer := 0.0
var _throttle := 0.0
var _brake := 0.0
var _handbrake := false
var _drifting := false
var _wrong_way_timer := 0.0
var _stuck_timer := 0.0
var _stuck_total := 0.0
var _reverse_timer := 0.0
var _reverse_steer := 0.0
var _avoid_offset := 0.0
var _prev_wheels: Array = [null, null]
var _bump_cooldown := 0.0

@onready var engine_sound: AudioStreamPlayer = $EngineSound
@onready var skid_sound: AudioStreamPlayer = $SkidSound
@onready var bump_sound: AudioStreamPlayer = $BumpSound


func _ready() -> void:
	_make_loop(engine_sound.stream)
	_make_loop(skid_sound.stream)
	queue_redraw()


static func _make_loop(s: AudioStream) -> void:
	if s is AudioStreamWAV and s.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate) - 1


func is_player() -> bool:
	return driver == Driver.PLAYER


func start_sounds() -> void:
	if is_player():
		engine_sound.play()
		skid_sound.volume_db = -60.0
		skid_sound.play()


func stop_sounds() -> void:
	engine_sound.stop()
	skid_sound.stop()


func _physics_process(delta: float) -> void:
	if track == null:
		return
	track_offset = track.get_offset_of(global_position)
	on_grass = not track.is_on_road_at(global_position, track_offset)
	_bump_cooldown -= delta
	_read_inputs(delta)
	_apply_physics(delta)
	_update_skids()
	if is_player():
		_update_wrong_way(delta)
		_update_sounds()
	queue_redraw()


# ------------------------------------------------------------- inputs
func _read_inputs(delta: float) -> void:
	var steer_target := 0.0
	_throttle = 0.0
	_brake = 0.0
	_handbrake = false
	if controls_enabled:
		if is_player() and not autopilot:
			_throttle = Input.get_action_strength("accelerate")
			_brake = Input.get_action_strength("brake")
			steer_target = Input.get_axis("steer_left", "steer_right")
			_handbrake = Input.is_action_pressed("handbrake")
		else:
			var ai := _ai_inputs(delta)
			steer_target = ai.x
			_throttle = ai.y
			_brake = ai.z
	_steer = move_toward(_steer, steer_target, steer_smoothing * delta)


func _ai_inputs(delta: float) -> Vector3:
	var spd := velocity.length()
	var fwd := transform.x
	var right := transform.y
	# Stuck recovery: back up for a moment, respawn on the track if really stuck.
	if _reverse_timer > 0.0:
		_reverse_timer -= delta
		return Vector3(_reverse_steer, 0.0, 1.0)
	if spd < 40.0:
		_stuck_timer += delta
		_stuck_total += delta
	else:
		_stuck_timer = 0.0
		if spd > 150.0:
			_stuck_total = 0.0
	if _stuck_total > ai_respawn_after:
		_respawn_on_track()
		return Vector3.ZERO
	var look := ai_lookahead + spd * ai_lookahead_per_speed
	var target_off := track_offset + look
	# Collision avoidance-lite: shift sideways around cars just ahead.
	var avoid := 0.0
	var must_slow := false
	if race:
		for other in race.cars:
			if other == self:
				continue
			var rel: Vector2 = other.global_position - global_position
			var d := rel.length()
			if d > ai_avoid_distance or d < 1.0:
				continue
			var ahead := rel.dot(fwd)
			if ahead <= 0.0:
				continue
			var side := rel.dot(right)
			if abs(side) < 60.0:
				var dir := -1.0 if side > 0.0 else 1.0
				avoid += dir * ai_avoid_strength * difficulty_avoid * (1.0 - d / ai_avoid_distance)
				if ahead < 80.0 and other.velocity.length() < spd:
					must_slow = true
	_avoid_offset = lerp(_avoid_offset, avoid, clamp(4.0 * delta, 0.0, 1.0))
	var max_lat := track.road_width * 0.36
	var apex := 0.0
	if ai_apex_cut > 0.0:
		# Aim for the inside of the coming bend (+curvature = right-hand bend = +right side).
		var k_ahead := track.get_curvature(target_off + 40.0)
		apex = signf(k_ahead) * clampf(absf(k_ahead) * 350.0, 0.0, 1.0) * ai_apex_cut * track.road_width * 0.3
	var lateral: float = clamp(ai_lane_offset + _avoid_offset + apex, -max_lat, max_lat)
	var target := track.sample_position(target_off) + track.get_right(target_off) * lateral
	var ang := fwd.angle_to(target - global_position)
	var steer: float = clamp(ang * ai_steer_gain, -1.0, 1.0)
	var target_speed := max_speed * ai_speed_factor * speed_jitter * rubber_band
	if ai_corner_model == CornerModel.SIMPLE:
		# v0.2 model: compare track direction just ahead vs further ahead.
		var t1 := track.get_tangent(track_offset + 60.0)
		var t2 := track.get_tangent(track_offset + 260.0 + spd * 0.45)
		var corner: float = abs(t1.angle_to(t2))
		var corner_amt: float = clamp(corner / deg_to_rad(ai_corner_angle_deg), 0.0, 1.0)
		target_speed *= 1.0 - ai_corner_slowdown * corner_amt
	else:
		target_speed = minf(target_speed, _corner_speed_limit(spd))
	if on_grass:
		target_speed = min(target_speed, max_speed * offroad_max_speed_factor)
	if must_slow:
		target_speed = min(target_speed, spd * 0.9)
	var fs := velocity.dot(fwd)
	# Facing the wrong way / stuck against a wall: reverse out.
	if _stuck_timer > 1.0 or (abs(ang) > 2.2 and spd < 120.0):
		_stuck_timer = 0.0
		_reverse_timer = 0.9
		_reverse_steer = -sign(ang) if ang != 0.0 else 1.0
	var thr := 1.0 if fs < target_speed else 0.0
	var brk := 1.0 if fs > target_speed + 70.0 else 0.0
	return Vector3(steer, thr, brk)


## Highest speed that still lets the car brake in time for every bend in braking range.
## The car's turn rate at speed v is steer * (1 - (1 - high_speed_steer_factor) * v / max_speed),
## so a bend of curvature k can be taken at v = s / (k + s * (1 - h) / max_speed).
func _corner_speed_limit(spd: float) -> float:
	var s0 := deg_to_rad(steer_speed_deg) * difficulty_corner * ai_corner_margin
	var hs := (1.0 - high_speed_steer_factor) / max_speed
	var bdec := brake_force * ai_brake_margin
	var horizon := spd * spd / (2.0 * bdec) + 140.0
	var limit := INF
	var d := 0.0
	while d <= horizon:
		var k := absf(track.get_curvature(track_offset + d))
		var vc := s0 / (k + s0 * hs)
		limit = minf(limit, sqrt(vc * vc + 2.0 * bdec * maxf(d - 30.0, 0.0)))
		d += 40.0
	return limit


func _respawn_on_track() -> void:
	respawn_count += 1
	_stuck_total = 0.0
	_stuck_timer = 0.0
	global_position = track.sample_position(track_offset)
	rotation = track.get_tangent(track_offset).angle()
	velocity = Vector2.ZERO


# ------------------------------------------------------------- physics
func _apply_physics(delta: float) -> void:
	var fs0 := velocity.dot(transform.x)
	var spd_abs: float = abs(fs0)
	var low_factor: float = clamp(spd_abs / steer_full_speed, 0.0, 1.0)
	var high_factor: float = lerp(1.0, high_speed_steer_factor, clamp(spd_abs / max_speed, 0.0, 1.0))
	var dir := 1.0 if fs0 >= 0.0 else -1.0
	var manual := is_player() and not autopilot
	_drifting = fs0 > 150.0 and (_handbrake or (manual and _brake > 0.5 and abs(_steer) > 0.3 and fs0 > drift_min_speed))
	var boost := drift_steer_boost if _drifting else 1.0
	rotation += deg_to_rad(steer_speed_deg) * _steer * low_factor * high_factor * dir * boost * delta

	var fwd := transform.x
	var right := transform.y
	var fs := velocity.dot(fwd)
	var ls := velocity.dot(right)
	var top := max_speed * (offroad_max_speed_factor if on_grass else 1.0) * maxf(rubber_band, 1.0)

	if _throttle > 0.0:
		if fs < -5.0:
			fs = move_toward(fs, 0.0, brake_force * delta)
		elif fs < top:
			fs = min(fs + acceleration * _throttle * delta, top)
	if _brake > 0.0:
		if fs > 5.0:
			var bf := brake_force * (drift_brake_factor if _drifting else 1.0)
			fs = max(fs - bf * _brake * delta, 0.0)
		elif _throttle <= 0.0:
			fs = max(fs - reverse_acceleration * _brake * delta, -reverse_max_speed)
	if _handbrake and fs > 0.0:
		fs = move_toward(fs, 0.0, brake_force * 0.25 * delta)
	if _throttle <= 0.0 and _brake <= 0.0:
		fs = move_toward(fs, 0.0, coast_drag * delta)
	if fs > top:
		fs = move_toward(fs, top, offroad_drag * delta)  # grass slows you down
	if fs < -reverse_max_speed:
		fs = move_toward(fs, -reverse_max_speed, offroad_drag * delta)

	var g := drift_grip if _drifting else grip
	if on_grass:
		g *= offroad_grip_factor
	ls *= exp(-g * delta)
	if abs(ls) > skid_threshold:
		fs = move_toward(fs, 0.0, slide_speed_loss * delta)
	is_skidding = abs(ls) > skid_threshold or (_brake > 0.5 and fs > 300.0 and not _drifting and manual)

	velocity = fwd * fs + right * ls
	var pre := velocity
	move_and_slide()
	_handle_collisions(pre)


func _handle_collisions(pre: Vector2) -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var n := c.get_normal()
		var impact := -pre.dot(n)
		if impact <= 0.0:
			continue
		var other = c.get_collider()
		if other is Car:
			other.velocity -= n * impact * 0.45
			velocity += n * impact * 0.15
		else:
			velocity += n * impact * wall_bounce
			velocity *= lerp(1.0, wall_speed_keep, clamp(impact / 450.0, 0.0, 1.0))
		if is_player() and impact > 110.0 and _bump_cooldown <= 0.0:
			_bump_cooldown = 0.3
			bump_sound.volume_db = linear_to_db(clamp(impact / 600.0, 0.25, 1.0)) - 4.0
			bump_sound.play()


func _update_skids() -> void:
	var marks = race.skid_marks if race else null
	if marks == null:
		return
	var wheels := [to_global(Vector2(-15, -11)), to_global(Vector2(-15, 11))]
	if is_skidding and not on_grass:
		for i in 2:
			if _prev_wheels[i] != null:
				marks.add_segment(_prev_wheels[i], wheels[i])
			_prev_wheels[i] = wheels[i]
	else:
		_prev_wheels = [null, null]


func _update_wrong_way(delta: float) -> void:
	var t := track.get_tangent(track_offset)
	var bad := false
	if controls_enabled and not has_finished:
		if velocity.length() > 100.0:
			bad = velocity.normalized().dot(t) < -0.3
		else:
			bad = transform.x.dot(t) < -0.5
	_wrong_way_timer = _wrong_way_timer + delta if bad else 0.0
	wrong_way = _wrong_way_timer > 1.0


func _update_sounds() -> void:
	if not engine_sound.playing:
		return
	var s: float = clamp(velocity.length() / max_speed, 0.0, 1.3)
	var pitch := 0.65 + s * 1.35 + (0.08 if _throttle > 0.0 else 0.0)
	if abs(engine_sound.pitch_scale - pitch) > 0.02:
		engine_sound.pitch_scale = pitch
	var vol: float = lerp(-20.0, -10.0, clamp(s + _throttle * 0.25, 0.0, 1.0))
	engine_sound.volume_db = vol
	var skid_target := -12.0 if (is_skidding and not on_grass and velocity.length() > 80.0) else -60.0
	skid_sound.volume_db = move_toward(skid_sound.volume_db, skid_target, 240.0 * get_physics_process_delta_time())


# ------------------------------------------------------------- laps
## Called by the Track's checkpoint gates.
func on_checkpoint(index: int) -> void:
	if track == null or has_finished or index != next_checkpoint or not controls_enabled:
		return
	checkpoints_passed += 1
	if index == 0:
		if lap == 0:
			lap = 1  # crossed the line after the standing start
			if flying_start:
				lap_start_time = race.race_time if race else 0.0
			lap_started.emit(self)
		else:
			var now: float = race.race_time if race else 0.0
			var lt := now - lap_start_time
			last_lap_time = lt
			lap_times.append(lt)
			if best_lap_time < 0.0 or lt < best_lap_time:
				best_lap_time = lt
			lap_start_time = now
			var total_laps: int = race.lap_count if race else 3
			if total_laps > 0 and lap >= total_laps:
				has_finished = true
				finish_time = now
				race_finished.emit(self)
			else:
				lap += 1
			lap_completed.emit(self, lt)
	next_checkpoint = (index + 1) % track.checkpoint_count


## Race distance covered, used for live positions (bigger = further ahead).
func get_progress() -> float:
	if has_finished:
		return 1.0e9 - finish_time
	var n := track.checkpoint_count
	var seg := track.length / n
	var last := posmod(next_checkpoint - 1, n)
	var frac := fposmod(track_offset - track.get_checkpoint_offset(last), track.length)
	if frac > track.length * 0.5:
		frac -= track.length
	return (checkpoints_passed - 1) * seg + frac


# ------------------------------------------------------------- drawing
func _draw() -> void:
	# Shadow
	draw_rect(Rect2(-24, -10, 50, 26), Color(0, 0, 0, 0.25))
	# Wheels (front wheels turn with steering)
	var wc := Color(0.07, 0.07, 0.08)
	for wx in [-15.0, 15.0]:
		for wy in [-12.0, 12.0]:
			var a: float = _steer * 0.45 if wx > 0.0 else 0.0
			draw_set_transform(Vector2(wx, wy), a)
			draw_rect(Rect2(-6.5, -3.5, 13, 7), wc)
	draw_set_transform(Vector2.ZERO, 0.0)
	# Body
	var body := PackedVector2Array([Vector2(-25, -11), Vector2(12, -12), Vector2(21, -9.5), Vector2(25, -4),
		Vector2(25, 4), Vector2(21, 9.5), Vector2(12, 12), Vector2(-25, 11), Vector2(-26, 6), Vector2(-26, -6)])
	draw_colored_polygon(body, body_color)
	var outline := body.duplicate()
	outline.append(body[0])
	draw_polyline(outline, body_color.darkened(0.45), 1.5)
	# Racing stripe
	draw_rect(Rect2(-26, -2.5, 51, 5), stripe_color)
	# Windscreen, roof, rear window
	draw_colored_polygon(PackedVector2Array([Vector2(3, -9), Vector2(12, -8), Vector2(12, 8), Vector2(3, 9)]), Color(0.1, 0.13, 0.2))
	draw_rect(Rect2(-11, -8.5, 14, 17), body_color.lightened(0.12))
	draw_rect(Rect2(-11, -2.5, 14, 5), stripe_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-17, -8), Vector2(-11, -8.5), Vector2(-11, 8.5), Vector2(-17, 8)]), Color(0.1, 0.13, 0.2))
	# Rear wing
	draw_rect(Rect2(-28, -12, 4, 24), body_color.darkened(0.35))
	# Lights
	draw_rect(Rect2(22, -8, 3, 4), Color(1, 1, 0.75))
	draw_rect(Rect2(22, 4, 3, 4), Color(1, 1, 0.75))
	var bl := Color(1, 0.15, 0.1) if _brake > 0.1 else Color(0.45, 0.05, 0.05)
	draw_rect(Rect2(-26.5, -10, 2.5, 4), bl)
	draw_rect(Rect2(-26.5, 6, 2.5, 4), bl)
	# Number on the roof
	var font := ThemeDB.fallback_font
	draw_set_transform(Vector2(-4, 0), PI * 0.5)
	draw_string(font, Vector2(-10, 5), str(car_number), HORIZONTAL_ALIGNMENT_CENTER, 20, 13, Color(0.05, 0.05, 0.05))
	draw_set_transform(Vector2.ZERO, 0.0)
