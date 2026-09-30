# Circuit outlines

`my-1999.geojson` (Sepang International Circuit) and `it-1922.geojson` (Autodromo Nazionale Monza)
come from **bacinger/f1-circuits** — https://github.com/bacinger/f1-circuits
(MIT License, Copyright (c) 2022 Tomislav Bacinger).

They are only used as a reference: `make_circuit.py` projects the lat/lon centre line to metres,
scales it to 7 px = 1 m, smooths corners tighter than ~140 px radius and resamples it into the
game's Curve2D (`*.points`), then `make_track_scenes.py` writes `scenes/tracks/sepang.tscn` and
`scenes/tracks/monza.tscn`. The in-game tracks are simplified, "inspired by" versions; no official
names/logos/branding of the circuits are used.
