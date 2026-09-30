extends Control
## Animated title background: asphalt, scrolling curbs and a few cars zooming past.

var _t := 0.0
var _cars := [
	[Color(0.12, 0.53, 0.9), 0.30, 520.0, 0.0],
	[Color(0.9, 0.2, 0.18), 0.42, 430.0, 350.0],
	[Color(0.98, 0.78, 0.15), 0.58, 610.0, 700.0],
	[Color(0.2, 0.75, 0.45), 0.70, 480.0, 1100.0],
]


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.3, 0.58, 0.26))
	var road := Rect2(0, s.y * 0.22, s.x, s.y * 0.56)
	draw_rect(road, Color(0.2, 0.2, 0.23))
	var cw := 48.0
	var off := fmod(_t * 220.0, cw * 2.0)
	var x := -cw * 2.0 + off
	var i := 0
	while x < s.x + cw:
		var col := Color(0.86, 0.12, 0.12) if i % 2 == 0 else Color(0.96, 0.96, 0.96)
		draw_rect(Rect2(x, road.position.y - 16.0, cw, 16.0), col)
		draw_rect(Rect2(x, road.end.y, cw, 16.0), col)
		if i % 2 == 0:
			draw_rect(Rect2(x, road.get_center().y - 3.0, cw, 6.0), Color(1, 1, 1, 0.3))
		x += cw
		i += 1
	# Checkered band on the left.
	var sq := road.size.y / 10.0
	for row in 10:
		for col2 in 2:
			var c := Color.WHITE if (row + col2) % 2 == 0 else Color(0.08, 0.08, 0.08)
			draw_rect(Rect2(s.x * 0.12 + col2 * sq, road.position.y + row * sq, sq, sq), c)
	for car in _cars:
		var span := s.x + 300.0
		var cx: float = fmod(car[3] + _t * car[2], span) - 150.0
		var cy: float = road.position.y + road.size.y * car[1]
		_draw_car(Vector2(cx, cy), car[0])


func _draw_car(p: Vector2, color: Color) -> void:
	var k := 1.6
	draw_rect(Rect2(p + Vector2(-24, -10) * k + Vector2(4, 6), Vector2(50, 26) * k), Color(0, 0, 0, 0.25))
	for wx in [-15.0, 15.0]:
		for wy in [-12.0, 12.0]:
			draw_rect(Rect2(p + (Vector2(wx, wy) + Vector2(-6.5, -3.5)) * k, Vector2(13, 7) * k), Color(0.07, 0.07, 0.08))
	draw_rect(Rect2(p + Vector2(-26, -11.5) * k, Vector2(51, 23) * k), color)
	draw_rect(Rect2(p + Vector2(-26, -2.5) * k, Vector2(51, 5) * k), Color.WHITE)
	draw_rect(Rect2(p + Vector2(3, -9) * k, Vector2(9, 18) * k), Color(0.1, 0.13, 0.2))
	draw_rect(Rect2(p + Vector2(-17, -8) * k, Vector2(6, 16) * k), Color(0.1, 0.13, 0.2))
