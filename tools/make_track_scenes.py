"""Writes scenes/tracks/sepang.tscn and monza.tscn from tools/circuits/*.points
(produced by make_circuit.py). Run from the tools/ folder:
  python3 make_circuit.py circuits/my-1999.geojson 7 6 circuits/sepang 0 140
  python3 make_circuit.py circuits/it-1922.geojson 7 6 circuits/monza 0 140
  python3 make_track_scenes.py
Track outlines: bacinger/f1-circuits (MIT). Simplified and scaled (7 px = 1 m)."""
import json

def c(r, g, b, a=1.0):
    return f"Color({r}, {g}, {b}, {a})"

TRACKS = {
    "sepang": dict(points="circuits/sepang.points", props={
        "track_id": '"sepang"', "track_name": '"Sepang (MY)"', "real_length_km": "5.543",
        "track_blurb": '"Malaysia: double-apex T1-T2, fast esses, long back straight into the final hairpin"',
        "road_width": "200.0", "grass_width": "80.0", "curb_width": "14.0", "curb_max_radius": "800.0",
        "checkpoint_count": "16", "grid_first_gap": "110.0", "grid_slot_gap": "75.0",
        "grass_color": c(0.23, 0.6, 0.22), "grass_stripe_color": c(0.21, 0.56, 0.2),
        "asphalt_color": c(0.21, 0.21, 0.24), "curb_color_a": c(0.98, 0.8, 0.1), "curb_color_b": c(0.12, 0.25, 0.7),
        "wall_color": c(0.2, 0.36, 0.78), "wall_stripe_color": c(0.98, 0.84, 0.15), "tree_count": "460",
        "tree_style": "1", "tree_color_dark": c(0.08, 0.42, 0.16), "tree_color_light": c(0.2, 0.62, 0.22),
        "tree_min_size": "30.0", "tree_max_size": "56.0", "tree_spread": "900.0", "tree_seed": "11",
        "grandstand_color": c(0.75, 0.75, 0.78),
    }),
    "monza": dict(points="circuits/monza.points", props={
        "track_id": '"monza"', "track_name": '"Monza (IT)"', "real_length_km": "5.793",
        "track_blurb": '"Italy: long straights, Rettifilo and Roggia chicanes, Lesmos, Ascari, Parabolica"',
        "road_width": "200.0", "grass_width": "80.0", "curb_width": "14.0", "curb_max_radius": "800.0",
        "checkpoint_count": "16", "grid_first_gap": "110.0", "grid_slot_gap": "75.0",
        "grass_color": c(0.27, 0.5, 0.23), "grass_stripe_color": c(0.25, 0.47, 0.21),
        "asphalt_color": c(0.26, 0.26, 0.28), "curb_color_a": c(0.82, 0.1, 0.1), "curb_color_b": c(0.96, 0.96, 0.96),
        "wall_color": c(0.16, 0.45, 0.26), "wall_stripe_color": c(0.95, 0.95, 0.95), "tree_count": "700",
        "tree_style": "0", "tree_color_dark": c(0.1, 0.3, 0.12), "tree_color_light": c(0.17, 0.41, 0.17),
        "tree_min_size": "34.0", "tree_max_size": "70.0", "tree_spread": "1100.0", "tree_seed": "5",
        "tree_scatter_fraction": "0.35", "grandstand_color": c(0.6, 0.55, 0.5),
    }),
}

for name, t in TRACKS.items():
    d = json.load(open(t["points"]))
    pts = ", ".join(f"{v:g}" for v in d["points"])
    props = "\n".join(f"{k} = {v}" for k, v in t["props"].items())
    out = f"""[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/track.gd" id="1_track"]

[sub_resource type="Curve2D" id="Curve2D_line"]
bake_interval = 20.0
_data = {{
"points": PackedVector2Array({pts})
}}
point_count = {d["count"]}

[node name="Track" type="Node2D"]
script = ExtResource("1_track")
{props}

[node name="RacingLine" type="Path2D" parent="."]
curve = SubResource("Curve2D_line")
"""
    open(f"../scenes/tracks/{name}.tscn", "w").write(out)
    print(name, d["count"], "points")
