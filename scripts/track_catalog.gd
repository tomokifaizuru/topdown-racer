class_name TrackCatalog
extends RefCounted
## List of the tracks shown in the track select. To add a track: make a scene in
## scenes/tracks/ (root node uses scripts/track.gd, with a RacingLine Path2D) and add it here.

const TRACKS := [
	{"id": "rookie_ring", "scene": "res://scenes/tracks/rookie_ring.tscn"},
	{"id": "sepang", "scene": "res://scenes/tracks/sepang.tscn"},
	{"id": "monza", "scene": "res://scenes/tracks/monza.tscn"},
]

static var _info_cache := {}


static func count() -> int:
	return TRACKS.size()


static func index_of(id: String) -> int:
	for i in TRACKS.size():
		if TRACKS[i]["id"] == id:
			return i
	return 0


static func scene_path(id: String) -> String:
	return TRACKS[index_of(id)]["scene"]


## Name, length and a simplified outline for menus (built once, then cached).
static func get_info(id: String) -> Dictionary:
	if _info_cache.has(id):
		return _info_cache[id]
	var info := {"id": id, "name": id, "km": 0.0, "outline": PackedVector2Array()}
	var ps: PackedScene = load(scene_path(id))
	if ps:
		var t = ps.instantiate()
		if t is Track:
			var curve: Curve2D = t.get_node("RacingLine").curve
			var pts := curve.get_baked_points()
			var outline := PackedVector2Array()
			var step := maxi(1, pts.size() / 240)
			for i in range(0, pts.size(), step):
				outline.append(pts[i])
			info["name"] = t.track_name
			info["blurb"] = t.track_blurb
			info["km"] = t.real_length_km if t.real_length_km > 0.0 else curve.get_baked_length() / 12000.0
			info["outline"] = outline
			info["color"] = t.grass_color
			info["accent"] = t.curb_color_a
		t.free()
	_info_cache[id] = info
	return info
