extends SceneTree
# Headless simulation: all cars AI-driven (your car on autopilot), prints lap progress.
#   godot --headless --path . --fixed-fps 60 -s tools/sim_test.gd -- track=sepang diff=3 laps=3 mode=race
# mode=tt runs a Time Trial (ghost recording/playback check, laps = number of timed laps).
var race
var frames := 0
var grass := {}
var slow := {}
var opts := {"track": "rookie_ring", "diff": "1", "laps": "3", "mode": "race", "limit": "900"}
var wall_start := 0
var ghost_seen := 0
var ghost_frames := 0
var ghost_dist := 0.0

func _initialize():
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			opts[kv[0]] = kv[1]

var S

func _start():
	S = root.get_node("/root/Settings")
	S.track_id = opts["track"]
	S.difficulty = int(opts["diff"])
	S.laps = int(opts["laps"])
	S.mode = 1 if opts["mode"] == "tt" else 0
	S.ghost_enabled = true
	race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	wall_start = Time.get_ticks_msec()

func _physics_process(_d):
	frames += 1
	if frames == 1:
		_start()
		return false
	if race == null or race.player == null: return false
	race.player.autopilot = true
	for c in race.cars:
		if c.controls_enabled and not c.has_finished:
			if c.on_grass: grass[c.car_name] = grass.get(c.car_name, 0) + 1
			if race.race_time > 5.0 and c.velocity.length() < 60.0: slow[c.car_name] = slow.get(c.car_name, 0) + 1
	if race.is_time_trial():
		ghost_frames += 1
		if race.ghost.visible:
			ghost_seen += 1
			ghost_dist += race.ghost.global_position.distance_to(race.player.global_position)
	if frames % 1200 == 0:
		var s := "t=%.0f " % race.race_time
		for c in race.cars:
			s += "| %s L%d r%d v%d " % [c.car_name, c.lap, c.rank, int(c.velocity.length())]
		print(s)
	var all_done := true
	for c in race.cars:
		if not c.has_finished: all_done = false
	if race.is_time_trial():
		all_done = race.player.lap_times.size() >= int(opts["laps"])
	if all_done or race.race_time > float(opts["limit"]):
		print("== ", opts, " race_time=%.1f wall=%.1fs" % [race.race_time, (Time.get_ticks_msec() - wall_start) / 1000.0])
		for c in race.cars:
			var laps := []
			for t in c.lap_times: laps.append("%.2f" % t)
			print("%-6s finished=%s pos=%d time=%.2f laps=%s grass=%.1fs slow=%.1fs respawns=%d" % [c.car_name, c.has_finished, race.finish_order.find(c) + 1, c.finish_time, laps, grass.get(c.car_name, 0) / 60.0, slow.get(c.car_name, 0) / 60.0, c.respawn_count])
		if race.is_time_trial():
			print("TT record=", S.get_best_lap(opts["track"]), " ghost file=", FileAccess.file_exists(GhostCar.file_path(opts["track"])), " ghost samples=", race.ghost.samples.size() / 3, " ghost visible frames=", ghost_seen, "/", ghost_frames, " mean ghost-player distance=%.1f px" % (ghost_dist / max(ghost_seen, 1)))
		quit()
	return false
