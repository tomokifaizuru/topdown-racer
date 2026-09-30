extends Control
## Small track map in the HUD with a dot per car.

@export var background_color: Color = Color(0, 0, 0, 0.35)
@export var track_color: Color = Color(1, 1, 1, 0.8)
@export var track_line_width: float = 5.0
@export var dot_radius: float = 6.0

var _track: Track
var _cars: Array = []
var _player: Node
var _pts := PackedVector2Array()
var _scale := 1.0
var _offset := Vector2.ZERO


func setup(track: Track, cars: Array, player: Node) -> void:
	_track = track
	_cars = cars
	_player = player
	_rebuild()
	resized.connect(_rebuild)


func _rebuild() -> void:
	if _track == null:
		return
	var src := _track.get_center_points()
	if src.is_empty():
		return
	var r := Rect2(src[0], Vector2.ZERO)
	for p in src:
		r = r.expand(p)
	var pad := 14.0
	var avail := size - Vector2(pad, pad) * 2.0
	_scale = min(avail.x / max(r.size.x, 1.0), avail.y / max(r.size.y, 1.0))
	_offset = Vector2(pad, pad) + (avail - r.size * _scale) * 0.5 - r.position * _scale
	_pts = PackedVector2Array()
	for i in range(0, src.size(), 3):
		_pts.append(src[i] * _scale + _offset)
	if not _pts.is_empty():
		_pts.append(_pts[0])


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), background_color)
	if _pts.size() > 2:
		draw_polyline(_pts, track_color, track_line_width)
	for c in _cars:
		if c == _player:
			continue
		draw_circle(c.global_position * _scale + _offset, dot_radius, c.body_color)
	if _player:
		var pp: Vector2 = _player.global_position * _scale + _offset
		draw_circle(pp, dot_radius + 3.0, Color.WHITE)
		draw_circle(pp, dot_radius + 1.0, _player.body_color)
