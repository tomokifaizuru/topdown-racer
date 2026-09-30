class_name GhostCar
extends Node2D
## Semi-transparent replay of your best Time Trial lap on this track.
## Samples are [x, y, rotation] triples recorded at Race > Time Trial > ghost_sample_rate.

## Ghost body colour (alpha = transparency).
@export var ghost_color: Color = Color(0.8, 0.95, 1.0, 0.5)
## Fade the ghost out when your car is closer than this (px), so it doesn't hide your car.
@export var fade_distance: float = 70.0

var samples := PackedFloat32Array()
var sample_rate := 20.0
var lap_time := -1.0
var follow: Node2D  # the player's car (for the close-up fade)


func set_samples(s: PackedFloat32Array, hz: float, t: float) -> void:
	samples = s
	sample_rate = hz
	lap_time = t
	visible = false


func has_data() -> bool:
	return samples.size() >= 6


## Moves the ghost to where it was `t` seconds into its lap.
func show_at(t: float) -> void:
	var count := samples.size() / 3
	if count < 2 or t < 0.0:
		visible = false
		return
	var f := t * sample_rate
	var i := int(f)
	if i >= count - 1:
		visible = false
		return
	var a := i * 3
	var b := a + 3
	var u := f - i
	position = Vector2(lerpf(samples[a], samples[b], u), lerpf(samples[a + 1], samples[b + 1], u))
	rotation = lerp_angle(samples[a + 2], samples[b + 2], u)
	visible = true
	var alpha := 1.0
	if follow and fade_distance > 0.0:
		alpha = clampf(follow.global_position.distance_to(global_position) / fade_distance, 0.25, 1.0)
	modulate.a = alpha
	queue_redraw()


func _draw() -> void:
	var c := ghost_color
	var body := PackedVector2Array([Vector2(-25, -11), Vector2(12, -12), Vector2(21, -9.5), Vector2(25, -4),
		Vector2(25, 4), Vector2(21, 9.5), Vector2(12, 12), Vector2(-25, 11), Vector2(-26, 6), Vector2(-26, -6)])
	for wx in [-15.0, 15.0]:
		for wy in [-12.0, 12.0]:
			draw_rect(Rect2(wx - 6.5, wy - 3.5, 13, 7), Color(0.1, 0.1, 0.12, c.a * 0.8))
	draw_colored_polygon(body, c)
	var outline := body.duplicate()
	outline.append(body[0])
	draw_polyline(outline, Color(1, 1, 1, minf(c.a + 0.3, 1.0)), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(3, -9), Vector2(12, -8), Vector2(12, 8), Vector2(3, 9)]), Color(0.1, 0.13, 0.2, c.a))
	# Label stays upright on screen.
	draw_set_transform(Vector2.ZERO, -rotation)
	draw_string(ThemeDB.fallback_font, Vector2(-24, -24), "GHOST", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, minf(c.a + 0.35, 1.0)))
	draw_set_transform(Vector2.ZERO, 0.0)


# ------------------------------------------------------------ save / load
static func file_path(track_id: String) -> String:
	return "user://ghost_%s.dat" % track_id


static func save_ghost(track_id: String, s: PackedFloat32Array, hz: float, t: float) -> void:
	var f := FileAccess.open(file_path(track_id), FileAccess.WRITE)
	if f == null:
		return
	f.store_var({"version": 1, "track": track_id, "hz": hz, "lap_time": t, "samples": s})
	f.close()


## Returns {} when there is no saved ghost for this track.
static func load_ghost(track_id: String) -> Dictionary:
	if not FileAccess.file_exists(file_path(track_id)):
		return {}
	var f := FileAccess.open(file_path(track_id), FileAccess.READ)
	if f == null:
		return {}
	var d = f.get_var()
	f.close()
	if d is Dictionary and d.get("samples") is PackedFloat32Array and d.get("track") == track_id:
		return d
	return {}
