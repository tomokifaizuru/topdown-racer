@tool
class_name Track
extends Node2D
## Builds the whole race track (asphalt, curbs, run-off grass, walls, checkpoints,
## start grid, trees/decor) from the "RacingLine" Path2D child.
##
## To reshape the track: select Track/RacingLine in the editor and drag its points.
## The preview redraws live in the editor. The racing line is also the path the AI follows.
## Direction of travel = direction of the curve (point 0 -> 1 -> 2 ...).
## Point 0 is the start/finish line.
##
## Each track is its own scene in scenes/tracks/ (rookie_ring, sepang, monza) and is listed in
## scripts/track_catalog.gd. Drawing is split into small chunks so the renderer can skip
## everything that is off-screen (keeps big tracks fast on phones).

enum TreeStyle { ROUND, PALM }

@export_group("Info")
## Short id used for save data (best laps, ghosts) and the online ranking. Keep it unique.
@export var track_id: String = "rookie_ring"
## Name shown in the menus.
@export var track_name: String = "Rookie Ring"
## Length shown in the track select (km). 0 = compute from the curve (12 px = 1 m).
@export var real_length_km: float = 0.0
## One-line description shown in the track select.
@export var track_blurb: String = ""

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
## Distance between consecutive grid slots (slots alternate left/right, so cars in the
## same column are 2x this apart).
@export var grid_slot_gap: float = 85.0
## Sideways offset of the grid slots from the centre (fraction of road width).
@export_range(0.0, 0.45) var grid_side_offset: float = 0.22
## Number of painted grid boxes (the race uses up to this many cars).
@export_range(1, 12) var grid_slots: int = 8

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

@export_group("Decor")
## ROUND = leafy park trees, PALM = tropical palms.
@export var tree_style: TreeStyle = TreeStyle.ROUND
## Main foliage colours (dark outer / lighter top).
@export var tree_color_dark: Color = Color(0.13, 0.36, 0.16)
@export var tree_color_light: Color = Color(0.18, 0.45, 0.2)
## Tree radius range in pixels.
@export var tree_min_size: float = 26.0
@export var tree_max_size: float = 52.0
## How far beyond the walls the trees spread (pixels).
@export var tree_spread: float = 700.0
## Fraction of the trees scattered randomly (the rest line the circuit).
@export_range(0.0, 1.0, 0.05) var tree_scatter_fraction: float = 0.25
## Random seed for tree placement (change it to reshuffle the trees).
@export var tree_seed: int = 7
## Draw a grandstand with a crowd next to the start/finish straight.
@export var grandstand: bool = true
@export var grandstand_color: Color = Color(0.55, 0.57, 0.62)

@export_group("Performance")
## Road drawing is split into chunks of this many baked points (smaller = finer culling).
@export_range(10, 200) var chunk_points: int = 40
## Trees are grouped into square cells of this size (pixels) for culling.
@export var tree_cell_size: float = 1400.0

var length: float = 1.0
var _center := PackedVector2Array()   # baked centre line (closed, no duplicate end point)
var _tangents := PackedVector2Array()
var _curv := PackedFloat32Array()      # signed curvature (1/radius), + = turning right
var _curb := PackedByteArray()
var _outer_walls: Array = []
var _inner_walls: Array = []
var _trees: Array = []
var _stand := PackedVector2Array()
var _bounds := Rect2()
var _signature := ""
var _sig_timer := 0.0
var _chunks: Array[Node2D] = []

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
		checkpoint_count, show_checkpoints, grid_first_gap, grid_slot_gap, grid_side_offset, grid_slots,
		grass_color, grass_stripe_color, asphalt_color, edge_line_color, curb_color_a, curb_color_b,
		wall_color, wall_stripe_color, tree_count, tree_style, tree_color_dark, tree_color_light,
		tree_min_size, tree_max_size, tree_spread, tree_scatter_fraction, tree_seed, grandstand,
		grandstand_color, chunk_points, tree_cell_size, track_blurb]
	if c:
		parts.append(c.point_count)
		for i in c.point_count:
			parts.append(c.get_point_position(i))
			parts.append(c.get_point_in(i))
			parts.append(c.get_point_out(i))
	return var_to_str(parts)


## Length for the menus, in km.
func get_length_km() -> float:
	if real_length_km > 0.0:
		return real_length_km
	return length / 12.0 / 1000.0


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
	# Curvature (smoothed) + curbs where the corner is tight enough.
	var raw_k := PackedFloat32Array()
	raw_k.resize(n)
	var raw := PackedByteArray()
	raw.resize(n)
	for i in n:
		var t0 := _tangents[(i - 3 + n) % n]
		var t1 := _tangents[(i + 3) % n]
		var arc := _center[(i - 3 + n) % n].distance_to(_center[i]) + _center[i].distance_to(_center[(i + 3) % n])
		var ang := t0.angle_to(t1)
		raw_k[i] = ang / maxf(arc, 0.001)
		var radius := arc / maxf(absf(ang), 0.0001)
		raw[i] = 1 if radius < curb_max_radius else 0
	_curv.resize(n)
	for i in n:
		var s := 0.0
		for k in range(-2, 3):
			s += raw_k[(i + k + n) % n]
		_curv[i] = s / 5.0
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
	_bounds = _bounds.grow(wall_dist + tree_spread + 700.0)
	_make_stand()
	_make_trees()
	_build_chunks()
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


static func _signed_area(p: PackedVector2Array) -> float:
	var s := 0.0
	for i in p.size():
		var a := p[i]
		var b := p[(i + 1) % p.size()]
		s += a.x * b.y - b.x * a.y
	return s * 0.5


# ---------------------------------------------------------------- decor
## Keep-out test: true if p is closer than `dist` to the centre line (using Clipper offsets).
class KeepOut:
	var outer: Array = []
	var inner: Array = []
	func _init(center: PackedVector2Array, dist: float) -> void:
		outer = Geometry2D.offset_polygon(center, dist, Geometry2D.JOIN_ROUND)
		inner = Geometry2D.offset_polygon(center, -dist, Geometry2D.JOIN_ROUND)
	func blocked(p: Vector2) -> bool:
		var inside := 0
		for poly in outer:
			if Geometry2D.is_point_in_polygon(p, poly):
				inside += 1
		if inside % 2 == 0:
			return false
		for poly in inner:
			if Geometry2D.is_point_in_polygon(p, poly):
				return false
		return true


func _outside_sign() -> float:
	# Clockwise on screen (positive signed area) = infield on the right-hand side.
	return -1.0 if _signed_area(_center) > 0.0 else 1.0


func _make_stand() -> void:
	_stand = PackedVector2Array()
	if not grandstand or _center.size() < 10:
		return
	var t := get_tangent(0.0)
	var r := Vector2(-t.y, t.x) * _outside_sign()
	var c := sample_position(0.0) - global_position
	var d0 := road_width * 0.5 + grass_width + wall_thickness + 30.0
	var poly := PackedVector2Array([c + r * d0 - t * 320.0, c + r * d0 + t * 320.0,
		c + r * (d0 + 130.0) + t * 320.0, c + r * (d0 + 130.0) - t * 320.0])
	var keep := KeepOut.new(_center, road_width * 0.5 + grass_width + wall_thickness + 10.0)
	for p in poly:
		if keep.blocked(p):
			return
	_stand = poly


func _make_trees() -> void:
	_trees.clear()
	if _center.size() < 10 or tree_count <= 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = tree_seed
	var keep_dist := road_width * 0.5 + grass_width + wall_thickness + tree_max_size * 0.6 + 20.0
	var keep := KeepOut.new(_center, keep_dist)
	var stand_rect := Rect2()
	if _stand.size() == 4:
		stand_rect = Rect2(_stand[0], Vector2.ZERO)
		for p in _stand:
			stand_rect = stand_rect.expand(p)
		stand_rect = stand_rect.grow(tree_max_size)
	var n := _center.size()
	var tries := 0
	while _trees.size() < tree_count and tries < tree_count * 12:
		tries += 1
		var p: Vector2
		if rng.randf() < tree_scatter_fraction:
			p = Vector2(rng.randf_range(_bounds.position.x, _bounds.end.x), rng.randf_range(_bounds.position.y, _bounds.end.y))
		else:
			var i := rng.randi_range(0, n - 1)
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var nrm := Vector2(-_tangents[i].y, _tangents[i].x) * side
			p = _center[i] + nrm * (keep_dist + pow(rng.randf(), 1.6) * tree_spread)
		if keep.blocked(p) or (stand_rect.size != Vector2.ZERO and stand_rect.has_point(p)):
			continue
		_trees.append([p, rng.randf_range(tree_min_size, tree_max_size), rng.randf_range(-0.06, 0.06), rng.randf() * TAU])


# ---------------------------------------------------------------- chunked drawing
func _clear_chunks() -> void:
	for c in _chunks:
		if is_instance_valid(c):
			remove_child(c)
			c.queue_free()
	_chunks.clear()


func _add_chunk(cb: Callable) -> void:
	var c := Node2D.new()
	c.draw.connect(func(): cb.call(c))
	add_child(c, false, Node.INTERNAL_MODE_FRONT)
	_chunks.append(c)


func _build_chunks() -> void:
	_clear_chunks()
	var n := _center.size()
	# Road segments (curbs, asphalt, lines).
	var arc := 0.0
	var i0 := 0
	while i0 < n:
		var i1 := mini(i0 + chunk_points, n)
		_add_chunk(_draw_road_chunk.bind(i0, i1, arc))
		for i in range(i0, i1):
			arc += _center[i].distance_to(_center[(i + 1) % n])
		i0 = i1
	# Start line + grid boxes.
	_add_chunk(_draw_start_chunk)
	# Walls, split into runs.
	for poly in _outer_walls:
		_add_wall_chunks(poly, 1.0)
	for poly in _inner_walls:
		_add_wall_chunks(poly, -1.0)
	# Grandstand.
	if _stand.size() == 4:
		_add_chunk(_draw_stand_chunk)
	# Trees grouped per cell.
	var cells := {}
	for tr in _trees:
		var key := Vector2i((tr[0] / tree_cell_size).floor())
		if not cells.has(key):
			cells[key] = []
		cells[key].append(tr)
	for key in cells:
		_add_chunk(_draw_tree_chunk.bind(cells[key]))


func _add_wall_chunks(poly: PackedVector2Array, outward: float) -> void:
	# Offset the drawn barrier outwards so its inner face matches the collision line.
	var grown: Array = Geometry2D.offset_polygon(poly, wall_thickness * 0.5 * outward, Geometry2D.JOIN_ROUND)
	for g in grown:
		var m: int = g.size()
		var run := 60
		var a := 0
		var arc := 0.0
		while a < m:
			var b := mini(a + run, m)
			var pts := PackedVector2Array()
			for k in range(a, b + 1):
				pts.append(g[k % m])
			_add_chunk(_draw_wall_chunk.bind(pts, arc))
			for k in range(pts.size() - 1):
				arc += pts[k].distance_to(pts[k + 1])
			a = b


func _draw() -> void:
	if _center.size() < 3:
		return
	# Grass with mowing stripes (one big rect + stripes; everything else is in chunks).
	draw_rect(_bounds, grass_color)
	var x := _bounds.position.x
	var stripe := 0
	while x < _bounds.end.x:
		if stripe % 2 == 0:
			draw_rect(Rect2(x, _bounds.position.y, 160.0, _bounds.size.y), grass_stripe_color)
		x += 160.0
		stripe += 1
	# Checkpoint debug.
	if show_checkpoints or Engine.is_editor_hint():
		var half := road_width * 0.5
		for i in checkpoint_count:
			var off := get_checkpoint_offset(i)
			var c := sample_position(off) - global_position
			var rr2 := get_right(off)
			var w := half + grass_width
			draw_line(c - rr2 * w, c + rr2 * w, Color(1, 1, 0, 0.6), 4.0)


func _draw_road_chunk(ci: Node2D, i0: int, i1: int, arc0: float) -> void:
	var n := _center.size()
	var half := road_width * 0.5
	# Curbs (drawn first, the road covers their inner half).
	var arc := arc0
	for i in range(i0, i1):
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
				ci.draw_colored_polygon(PackedVector2Array([a0, a1, b1, b0]), col)
		arc += seg
	# Asphalt strip.
	for i in range(i0, i1):
		var j := (i + 1) % n
		var ri := Vector2(-_tangents[i].y, _tangents[i].x)
		var rj := Vector2(-_tangents[j].y, _tangents[j].x)
		ci.draw_colored_polygon(PackedVector2Array([
			_center[i] - ri * half, _center[j] - rj * half,
			_center[j] + rj * half, _center[i] + ri * half]), asphalt_color)
	# White edge lines + dashed centre line.
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in range(i0, i1 + 1):
		var k := i % n
		var r := Vector2(-_tangents[k].y, _tangents[k].x)
		left.append(_center[k] - r * (half - 8.0))
		right.append(_center[k] + r * (half - 8.0))
	ci.draw_polyline(left, edge_line_color, 4.0)
	ci.draw_polyline(right, edge_line_color, 4.0)
	arc = arc0
	var dashes := PackedVector2Array()
	for i in range(i0, i1):
		var j := (i + 1) % n
		if int(arc / 60.0) % 2 == 0:
			dashes.append(_center[i])
			dashes.append(_center[j])
		arc += _center[i].distance_to(_center[j])
	if dashes.size() >= 2:
		ci.draw_multiline(dashes, Color(1, 1, 1, 0.35), 3.0)


func _draw_start_chunk(ci: Node2D) -> void:
	var half := road_width * 0.5
	var t0 := get_tangent(0.0)
	var r0 := Vector2(-t0.y, t0.x)
	var c0 := sample_position(0.0) - global_position
	var cells := 12
	var s := road_width / cells
	for row in 3:
		for k in cells:
			var col2 := Color.WHITE if (k + row) % 2 == 0 else Color(0.08, 0.08, 0.08)
			var o := c0 + r0 * (-half + k * s) + t0 * ((row - 1.5) * s)
			ci.draw_colored_polygon(PackedVector2Array([o, o + r0 * s, o + r0 * s + t0 * s, o + t0 * s]), col2)
	# Grid slots.
	for slot in grid_slots:
		var tf := get_grid_transform(slot)
		var fwd := tf.x.normalized()
		var rr := tf.y.normalized()
		var front := tf.origin - global_position + fwd * 34.0
		ci.draw_line(front - rr * 22.0, front + rr * 22.0, Color(1, 1, 1, 0.8), 4.0)
		ci.draw_line(front - rr * 22.0, front - rr * 22.0 - fwd * 30.0, Color(1, 1, 1, 0.8), 3.0)
		ci.draw_line(front + rr * 22.0, front + rr * 22.0 - fwd * 30.0, Color(1, 1, 1, 0.8), 3.0)


func _draw_wall_chunk(ci: Node2D, pts: PackedVector2Array, arc0: float) -> void:
	ci.draw_polyline(pts, wall_color, wall_thickness)
	var arc := arc0
	var stripes := PackedVector2Array()
	for i in pts.size() - 1:
		if int(arc / 50.0) % 2 == 0:
			stripes.append(pts[i])
			stripes.append(pts[i + 1])
		arc += pts[i].distance_to(pts[i + 1])
	if stripes.size() >= 2:
		ci.draw_multiline(stripes, wall_stripe_color, wall_thickness * 0.55)


func _draw_stand_chunk(ci: Node2D) -> void:
	var p := _stand
	ci.draw_colored_polygon(PackedVector2Array([p[0] + Vector2(12, 14), p[1] + Vector2(12, 14), p[2] + Vector2(12, 14), p[3] + Vector2(12, 14)]), Color(0, 0, 0, 0.2))
	ci.draw_colored_polygon(p, grandstand_color)
	var along := (p[1] - p[0])
	var across := (p[3] - p[0])
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var crowd := [Color(0.9, 0.2, 0.2), Color(0.95, 0.85, 0.2), Color(0.2, 0.5, 0.95), Color.WHITE, Color(0.2, 0.7, 0.3), Color(0.95, 0.5, 0.15)]
	for row in 5:
		var v := (row + 0.7) / 5.6
		ci.draw_line(p[0] + across * (v - 0.08), p[1] + across * (v - 0.08), grandstand_color.darkened(0.25), 3.0)
		for k in 30:
			var u := (k + 0.5) / 30.0
			ci.draw_rect(Rect2(p[0] + along * u + across * v - Vector2(4, 4), Vector2(8, 8)), crowd[rng.randi() % crowd.size()])
	# Roof edge.
	ci.draw_line(p[3], p[2], grandstand_color.darkened(0.45), 10.0)


func _draw_tree_chunk(ci: Node2D, trees: Array) -> void:
	for tr in trees:
		ci.draw_circle(tr[0] + Vector2(10, 12), tr[1] * (0.8 if tree_style == TreeStyle.PALM else 1.0), Color(0, 0, 0, 0.18))
	for tr in trees:
		var p: Vector2 = tr[0]
		var rad: float = tr[1]
		if tree_style == TreeStyle.PALM:
			var a0: float = tr[3]
			for k in 7:
				var dir := Vector2.from_angle(a0 + k * TAU / 7.0)
				var col := tree_color_dark if k % 2 == 0 else tree_color_light
				col = col.lightened(tr[2])
				ci.draw_colored_polygon(PackedVector2Array([p, p + dir.rotated(0.32) * rad * 0.55,
					p + dir * rad, p + dir.rotated(-0.32) * rad * 0.55]), col)
			ci.draw_circle(p, rad * 0.16, Color(0.45, 0.32, 0.18))
		else:
			ci.draw_circle(p, rad, tree_color_dark)
			ci.draw_circle(p + Vector2(-rad * 0.2, -rad * 0.2), rad * 0.72, tree_color_light.lightened(tr[2]))
			ci.draw_circle(p + Vector2(-rad * 0.35, -rad * 0.35), rad * 0.35, tree_color_light.lightened(0.18))


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
	# Checkpoint gates (Area2D, detect cars on layer 2). They reach just past the walls
	# so they never overlap another part of the circuit.
	for i in checkpoint_count:
		var off := get_checkpoint_offset(i)
		var area := Area2D.new()
		area.name = "Checkpoint%d" % i
		area.collision_layer = 0
		area.collision_mask = 2
		area.monitorable = false
		area.position = sample_position(off) - global_position
		area.rotation = get_tangent(off).angle()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(36.0, (road_width * 0.5 + grass_width) * 2.0 + 10.0)
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


## Signed curvature (1 / radius in px) of the centre line; + = right-hand bend.
func get_curvature(offset: float) -> float:
	var n := _curv.size()
	if n == 0:
		return 0.0
	return _curv[int(fposmod(offset, length) / length * n) % n]


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
