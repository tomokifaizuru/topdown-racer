@tool
class_name Track
extends Node2D
## Builds the whole race track (asphalt, curbs, run-off grass, walls, checkpoints,
## start grid) from the "RacingLine" Path2D child.
##
## To reshape the track: select Track/RacingLine in the editor and drag its points.
## The preview redraws live in the editor. The racing line is also the path the AI follows.
## Direction of travel = direction of the curve (point 0 -> 1 -> 2 ...).
## Point 0 is the start/finish line.

@export_group("Shape")
## Width of the asphalt road, in pixels (about 12 px = 1 m).
@export var road_width: float = 240.0
## Width of the grass run-off between the road edge and the walls (each side).
## Driving on grass slows the car down (see Car > Surface).
@export var grass_width: float = 110.0
## Width of the red/white curbs drawn on corners (curbs count as road).
@export var curb_width: float = 16.0
## Curbs are drawn where the corner radius is smaller than this (pixels).
@export var curb_max_radius: float = 900.0

@export_group("Walls")
## Visual thickness of the barrier walls (collision is along their inner face).
@export var wall_thickness: float = 22.0

@export_group("Checkpoints")
## Number of checkpoint gates around the lap (gate 0 = start/finish line).
## Cars must pass them in order for a lap to count, so shortcuts don't work.
@export_range(3, 40) var checkpoint_count: int = 10
## Draw the checkpoint gates in-game (debug aid).
@export var show_checkpoints: bool = false

@export_group("Start Grid")
## Distance from the start line back to grid slot 0 (pole position).
@export var grid_first_gap: float = 110.0
## Distance between consecutive grid slots.
@export var grid_slot_gap: float = 85.0
## Sideways offset of the grid slots from the centre (fraction of road width).
@export_range(0.0, 0.45) var grid_side_offset: float = 0.22

@export_group("Colors")
@export var grass_color: Color = Color(0.30, 0.58, 0.26)
@export var grass_stripe_color: Color = Color(0.28, 0.54, 0.24)
@export var asphalt_color: Color = Color(0.23, 0.23, 0.26)
@export var edge_line_color: Color = Color(0.93, 0.93, 0.93)
@export var curb_color_a: Color = Color(0.86, 0.12, 0.12)
@export var curb_color_b: Color = Color(0.96, 0.96, 0.96)
@export var wall_color: Color = Color(0.62, 0.63, 0.68)
@export var wall_stripe_color: Color = Color(0.95, 0.35, 0.12)
@export var tree_count: int = 160

var length: float = 1.0
var _center := PackedVector2Array()   # baked centre line (closed, no duplicate end point)
var _tangents := PackedVector2Array()
var _curb := PackedByteArray()
var _outer_walls: Array = []
var _inner_walls: Array = []
var _trees: Array = []
var _bounds := Rect2()
var _signature := ""
var _sig_timer := 0.0

@onready var racing_line: Path2D = $RacingLine


func _ready() -> void:
	rebuild()
	if not Engine.is_editor_hint():
		_build_physics()


func _process(delta: float) -> void:
	# Editor only: redraw live when the curve or any export value changes.
	if not Engine.is_editor_hint():
		set_process(false)
		return
	_sig_timer -= delta
	if _sig_timer > 0.0:
		return
	_sig_timer = 0.25
	var sig := _make_signature()
	if sig != _signature:
		rebuild()


func _make_signature() -> String:
	var c: Curve2D = racing_line.curve if racing_line else null
	var parts := [road_width, grass_width, curb_width, curb_max_radius, wall_thickness,
		checkpoint_count, show_checkpoints, grid_first_gap, grid_slot_gap, grid_side_offset,
		grass_color, asphalt_color, curb_color_a, curb_color_b, wall_color, tree_count]
	if c:
		for i in c.point_count:
			parts.append(c.get_point_position(i))
			parts.append(c.get_point_in(i))
			parts.append(c.get_point_out(i))
	return var_to_str(parts)


func rebuild() -> void:
	if racing_line == null:
		racing_line = get_node_or_null("RacingLine")
	if racing_line == null or racing_line.curve == null or racing_line.curve.point_count < 3:
		return
	_signature = _make_signature()
	var curve := racing_line.curve
	length = max(curve.get_baked_length(), 1.0)
	var pts := curve.get_baked_points()
	if pts.size() > 2 and pts[0].distance_to(pts[pts.size() - 1]) < 1.0:
		pts.remove_at(pts.size() - 1)
	_center = pts
	var n := _center.size()
	_tangents.resize(n)
	for i in n:
		var a := _center[(i - 1 + n) % n]
		var b := _center[(i + 1) % n]
		_tangents[i] = (b - a).normalized()
	# Curbs where the corner is tight enough.
	var raw := PackedByteArray()
	raw.resize(n)
	for i in n:
		var t0 := _tangents[(i - 3 + n) % n]
		var t1 := _tangents[(i + 3) % n]
		var arc := _center[(i - 3 + n) % n].distance_to(_center[i]) + _center[i].distance_to(_center[(i + 3) % n])
		var ang: float = abs(t0.angle_to(t1))
		var radius := arc / maxf(ang, 0.0001)
		raw[i] = 1 if radius < curb_max_radius else 0
	_curb.resize(n)
	for i in n:
		var on := 0
		for k in range(-4, 5):
			if raw[(i + k + n) % n] == 1:
				on = 1
		_curb[i] = on
	# Walls (Clipper offsets handle tight corners cleanly).
	var wall_dist := road_width * 0.5 + grass_width
	_outer_walls = _sorted_by_area(Geometry2D.offset_polygon(_center, wall_dist, Geometry2D.JOIN_ROUND))
	_inner_walls = _sorted_by_area(Geometry2D.offset_polygon(_center, -wall_dist, Geometry2D.JOIN_ROUND))
	if _outer_walls.size() > 1:
		_outer_walls = [_outer_walls[0]]
	# Bounds + decorative trees.
	_bounds = Rect2(_center[0], Vector2.ZERO)
	for p in _center:
		_bounds = _bounds.expand(p)
	_bounds = _bounds.grow(wall_dist + 900.0)
	_make_trees()
	queue_redraw()


func _sorted_by_area(polys: Array) -> Array:
	var out := []
	for p in polys:
		if p.size() >= 3:
			out.append(p)
	out.sort_custom(func(a, b): return _poly_area(a) > _poly_area(b))
	return out


static func _poly_area(p: PackedVector2Array) -> float:
	var s := 0.0
	for i in p.size():
		var a := p[i]
		var b := p[(i + 1) % p.size()]
		s += a.x * b.y - b.x * a.y
	return abs(s) * 0.5


func _make_trees() -> void:
	_trees.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var min_dist := road_width * 0.5 + grass_width + wall_thickness + 50.0
	var tries := 0
	while _trees.size() < tree_count and tries < tree_count * 20:
		tries += 1
		var p := Vector2(rng.randf_range(_bounds.position.x, _bounds.end.x), rng.randf_range(_bounds.position.y, _bounds.end.y))
		if p.distance_to(_closest_center_point(p)) < min_dist + rng.randf_range(0.0, 60.0):
			continue
		_trees.append([p, rng.randf_range(26.0, 52.0), rng.randf_range(-0.06, 0.06)])


func _closest_center_point(p: Vector2) -> Vector2:
	var best := INF
	var bp := Vector2.ZERO
	for i in range(0, _center.size(), 2):
		var d := p.distance_squared_to(_center[i])
		if d < best:
			best = d
			bp = _center[i]
	return bp


# ---------------------------------------------------------------- physics
func _build_physics() -> void:
	# Walls: one static body with a segment shape per wall loop (collision layer 1).
	var body := StaticBody2D.new()
	body.name = "Walls"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for poly in _outer_walls + _inner_walls:
		var segs := PackedVector2Array()
		for i in poly.size():
			segs.append(poly[i])
			segs.append(poly[(i + 1) % poly.size()])
		var shape := ConcavePolygonShape2D.new()
		shape.segments = segs
		var cs := CollisionShape2D.new()
		cs.shape = shape
		body.add_child(cs)
	# Checkpoint gates (Area2D, detect cars on layer 2).
	for i in checkpoint_count:
		var off := get_checkpoint_offset(i)
		var area := Area2D.new()
		area.name = "Checkpoint%d" % i
		area.collision_layer = 0
		area.collision_mask = 2
		area.monitorable = false
		area.position = sample_position(off)
		area.rotation = get_tangent(off).angle()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(36.0, (road_width * 0.5 + grass_width) * 2.0 + 40.0)
		var cs := CollisionShape2D.new()
		cs.shape = rect
		area.add_child(cs)
		area.body_entered.connect(_on_gate_body_entered.bind(i))
		add_child(area)


func _on_gate_body_entered(body: Node, index: int) -> void:
	if body.has_method("on_checkpoint"):
		body.on_checkpoint(index)


# ---------------------------------------------------------------- queries
func get_offset_of(global_pos: Vector2) -> float:
	return racing_line.curve.get_closest_offset(racing_line.to_local(global_pos))


func sample_position(offset: float) -> Vector2:
	return racing_line.to_global(racing_line.curve.sample_baked(fposmod(offset, length)))


func get_tangent(offset: float) -> Vector2:
	var a := sample_position(offset - 12.0)
	var b := sample_position(offset + 12.0)
	return (b - a).normalized()


## Unit vector pointing to the right-hand side of the track at this offset.
func get_right(offset: float) -> Vector2:
	var t := get_tangent(offset)
	return Vector2(-t.y, t.x)


func distance_from_center(global_pos: Vector2, offset: float) -> float:
	return global_pos.distance_to(sample_position(offset))


## True on asphalt or curbs; false on the grass run-off.
func is_on_road_at(global_pos: Vector2, offset: float) -> bool:
	return distance_from_center(global_pos, offset) <= road_width * 0.5 + curb_width * 0.6


func get_checkpoint_offset(index: int) -> float:
	return length * float(index) / float(checkpoint_count)


func get_center_points() -> PackedVector2Array:
	return _center


## Position + rotation for start grid slot (0 = pole position).
func get_grid_transform(slot: int) -> Transform2D:
	var off := length - grid_first_gap - slot * grid_slot_gap
	var side := -1.0 if slot % 2 == 0 else 1.0
	var pos := sample_position(off) + get_right(off) * side * road_width * grid_side_offset
	return Transform2D(get_tangent(off).angle(), pos)


# ---------------------------------------------------------------- drawing
func _draw() -> void:
	var n := _center.size()
	if n < 3:
		return
	# Grass with mowing stripes.
	draw_rect(_bounds, grass_color)
	var x := _bounds.position.x
	var stripe := 0
	while x < _bounds.end.x:
		if stripe % 2 == 0:
			draw_rect(Rect2(x, _bounds.position.y, 160.0, _bounds.size.y), grass_stripe_color)
		x += 160.0
		stripe += 1
	# Tree shadows (below walls/road not needed: trees are away from track).
	for tr in _trees:
		draw_circle(tr[0] + Vector2(10, 12), tr[1], Color(0, 0, 0, 0.18))
	var half := road_width * 0.5
	# Curbs (drawn first, the road covers their inner half).
	var arc := 0.0
	for i in n:
		var j := (i + 1) % n
		var seg := _center[i].distance_to(_center[j])
		if _curb[i] == 1:
			var col := curb_color_a if int(arc / 36.0) % 2 == 0 else curb_color_b
			var ri := Vector2(-_tangents[i].y, _tangents[i].x)
			var rj := Vector2(-_tangents[j].y, _tangents[j].x)
			for side in [-1.0, 1.0]:
				var a0: Vector2 = _center[i] + ri * side * (half - 2.0)
				var a1: Vector2 = _center[i] + ri * side * (half + curb_width)
				var b0: Vector2 = _center[j] + rj * side * (half - 2.0)
				var b1: Vector2 = _center[j] + rj * side * (half + curb_width)
				draw_colored_polygon(PackedVector2Array([a0, a1, b1, b0]), col)
		arc += seg
	# Asphalt strip.
	for i in n:
		var j := (i + 1) % n
		var ri := Vector2(-_tangents[i].y, _tangents[i].x)
		var rj := Vector2(-_tangents[j].y, _tangents[j].x)
		draw_colored_polygon(PackedVector2Array([
			_center[i] - ri * half, _center[j] - rj * half,
			_center[j] + rj * half, _center[i] + ri * half]), asphalt_color)
	# White edge lines + dashed centre line.
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in n + 1:
		var k := i % n
		var r := Vector2(-_tangents[k].y, _tangents[k].x)
		left.append(_center[k] - r * (half - 8.0))
		right.append(_center[k] + r * (half - 8.0))
	draw_polyline(left, edge_line_color, 4.0)
	draw_polyline(right, edge_line_color, 4.0)
	arc = 0.0
	for i in n:
		var j := (i + 1) % n
		if int(arc / 60.0) % 2 == 0:
			draw_line(_center[i], _center[j], Color(1, 1, 1, 0.35), 3.0)
		arc += _center[i].distance_to(_center[j])
	# Start / finish line (checkered).
	var t0 := get_tangent(0.0)
	var r0 := Vector2(-t0.y, t0.x)
	var c0 := sample_position(0.0)
	var cells := 12
	var s := road_width / cells
	for row in 3:
		for k in cells:
			var col2 := Color.WHITE if (k + row) % 2 == 0 else Color(0.08, 0.08, 0.08)
			var o := c0 + r0 * (-half + k * s) + t0 * ((row - 1.5) * s)
			draw_colored_polygon(PackedVector2Array([o, o + r0 * s, o + r0 * s + t0 * s, o + t0 * s]), col2)
	# Grid slots.
	for slot in 4:
		var tf := get_grid_transform(slot)
		var fwd := tf.x.normalized()
		var rr := tf.y.normalized()
		var front := tf.origin + fwd * 34.0
		draw_line(front - rr * 22.0, front + rr * 22.0, Color(1, 1, 1, 0.8), 4.0)
		draw_line(front - rr * 22.0, front - rr * 22.0 - fwd * 30.0, Color(1, 1, 1, 0.8), 3.0)
		draw_line(front + rr * 22.0, front + rr * 22.0 - fwd * 30.0, Color(1, 1, 1, 0.8), 3.0)
	# Walls (tyre barriers).
	for poly in _outer_walls:
		_draw_wall(poly, 1.0)
	for poly in _inner_walls:
		_draw_wall(poly, -1.0)
	# Trees.
	for tr in _trees:
		var p: Vector2 = tr[0]
		var rad: float = tr[1]
		draw_circle(p, rad, Color(0.13, 0.36, 0.16))
		draw_circle(p + Vector2(-rad * 0.2, -rad * 0.2), rad * 0.72, Color(0.18 + tr[2], 0.45, 0.2))
		draw_circle(p + Vector2(-rad * 0.35, -rad * 0.35), rad * 0.35, Color(0.26, 0.55, 0.26))
	# Checkpoint debug.
	if show_checkpoints or Engine.is_editor_hint():
		for i in checkpoint_count:
			var off := get_checkpoint_offset(i)
			var c := sample_position(off)
			var rr2 := get_right(off)
			var w := half + grass_width
			draw_line(c - rr2 * w, c + rr2 * w, Color(1, 1, 0, 0.6), 4.0)


func _draw_wall(poly: PackedVector2Array, outward: float) -> void:
	# Offset the drawn barrier outwards so its inner face matches the collision line.
	var grown: Array = Geometry2D.offset_polygon(poly, wall_thickness * 0.5 * outward, Geometry2D.JOIN_ROUND)
	for g in grown:
		var closed: PackedVector2Array = g.duplicate()
		closed.append(g[0])
		draw_polyline(closed, wall_color, wall_thickness)
		# Stripes every ~50 px.
		var arc := 0.0
		for i in g.size():
			var a: Vector2 = g[i]
			var b: Vector2 = g[(i + 1) % g.size()]
			if int(arc / 50.0) % 2 == 0:
				draw_line(a, b, wall_stripe_color, wall_thickness * 0.55)
			arc += a.distance_to(b)
