extends Control
## Track select preview: the circuit outline, start line and a dot lapping it.

@export var background_color: Color = Color(0, 0, 0, 0.35)
@export var road_color: Color = Color(0.16, 0.16, 0.19)
@export var edge_color: Color = Color(0.95, 0.95, 0.95)
@export var dot_color: Color = Color(0.12, 0.53, 0.9)
## Seconds for the dot to go once around.
@export var dot_lap_time: float = 6.0

var _info := {}
var _pts := PackedVector2Array()
var _t := 0.0


func set_track(info: Dictionary) -> void:
	_info = info
	_rebuild()


func _ready() -> void:
	resized.connect(_rebuild)


func _rebuild() -> void:
	_pts = PackedVector2Array()
	if _info.is_empty():
		queue_redraw()
		return
	var src: PackedVector2Array = _info["outline"]
	if src.size() < 3:
		return
	var r := Rect2(src[0], Vector2.ZERO)
	for p in src:
		r = r.expand(p)
	var pad := 26.0
	var avail := size - Vector2(pad, pad) * 2.0
	var sc: float = min(avail.x / max(r.size.x, 1.0), avail.y / max(r.size.y, 1.0))
	var off := Vector2(pad, pad) + (avail - r.size * sc) * 0.5 - r.position * sc
	for p in src:
		_pts.append(p * sc + off)
	_pts.append(_pts[0])
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var bg: Color = _info.get("color", Color(0.3, 0.58, 0.26))
	draw_rect(Rect2(Vector2.ZERO, size), bg.darkened(0.25))
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.25), false, 3.0)
	if _pts.size() < 3:
		return
	draw_polyline(_pts, edge_color, 13.0, true)
	draw_polyline(_pts, road_color, 8.0, true)
	# Start/finish line.
	var t0 := (_pts[1] - _pts[0]).normalized()
	var n0 := Vector2(-t0.y, t0.x)
	draw_line(_pts[0] - n0 * 11.0, _pts[0] + n0 * 11.0, Color.WHITE, 5.0)
	draw_line(_pts[0] - n0 * 11.0, _pts[0] + n0 * 11.0, Color(0.1, 0.1, 0.1), 2.0)
	# Direction arrow near the start.
	var k := mini(8, _pts.size() - 2)
	var a := _pts[k]
	var d := (_pts[k + 1] - _pts[k]).normalized()
	var accent: Color = _info.get("accent", Color(1, 0.85, 0.2))
	draw_colored_polygon(PackedVector2Array([a + d * 12.0, a - d * 6.0 + d.orthogonal() * 8.0, a - d * 6.0 - d.orthogonal() * 8.0]), accent)
	# Lapping dot.
	var f := fposmod(_t / maxf(dot_lap_time, 0.5), 1.0) * (_pts.size() - 1)
	var i := int(f)
	var p := _pts[i].lerp(_pts[mini(i + 1, _pts.size() - 1)], f - i)
	draw_circle(p, 8.0, Color.WHITE)
	draw_circle(p, 6.0, dot_color)
