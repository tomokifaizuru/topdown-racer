extends SceneTree
# Headless simulation: all cars AI-driven, prints lap progress. Run with:
# godot --headless --path . --fixed-fps 60 -s tools/sim_test.gd
var race
var frames := 0
var grass := {}
func _initialize():
	race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
func _physics_process(_d):
	frames += 1
	if race == null or race.player == null: return false
	race.player.autopilot = true
	for c in race.cars:
		if c.on_grass and c.controls_enabled: grass[c.car_name] = grass.get(c.car_name, 0) + 1
	if frames % 300 == 0:
		var s := "t=%.1f " % race.race_time
		for c in race.cars:
			s += "| %s L%d cp%d r%d v%d %s " % [c.car_name, c.lap, c.next_checkpoint, c.rank, int(c.velocity.length()), "G" if c.on_grass else ""]
		print(s)
	var all_done := true
	for c in race.cars:
		if not c.has_finished: all_done = false
	if all_done or race.race_time > 240.0:
		for c in race.cars:
			print(c.car_name, " finished=", c.has_finished, " time=", "%.2f" % c.finish_time, " laps=", c.lap_times, " grass_frames=", grass.get(c.car_name, 0))
		quit()
	return false
