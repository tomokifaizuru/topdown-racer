extends Node2D
## Draws tyre skid marks left by all cars.

## Maximum number of skid segments kept (older ones disappear).
@export var max_segments: int = 2500
@export var mark_color: Color = Color(0.06, 0.06, 0.07, 0.45)
@export var mark_width: float = 5.0

var _segs := PackedVector2Array()
var _dirty := false


func add_segment(a: Vector2, b: Vector2) -> void:
	if a.distance_squared_to(b) < 1.0:
		return
	_segs.append(a)
	_segs.append(b)
	if _segs.size() > max_segments * 2 + 400:
		_segs = _segs.slice(_segs.size() - max_segments * 2)
	_dirty = true


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		queue_redraw()


func _draw() -> void:
	if _segs.size() >= 2:
		draw_multiline(_segs, mark_color, mark_width)
