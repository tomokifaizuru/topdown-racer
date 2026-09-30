class_name DifficultyProfile
extends Resource
## One AI difficulty level (Easy / Normal / Hard / WTF?!). The four profiles live in
## res://difficulty/*.tres and are listed on the Race node (scenes/race.tscn > Difficulty).
## Edit the .tres files in the Inspector to rebalance the AI.

## Name shown in the setup menu.
@export var display_name: String = "Normal"
## AI top speed multiplier (1.0 = same top speed as the player's car).
@export_range(0.5, 1.5, 0.01) var speed: float = 0.92
## How much of the car's steering the AI uses in bends (higher = faster, riskier corners).
@export_range(0.3, 1.3, 0.01) var corner_margin: float = 0.8
## AI acceleration multiplier.
@export_range(0.5, 1.5, 0.01) var acceleration: float = 1.0
## AI steering speed multiplier.
@export_range(0.5, 1.5, 0.01) var steering: float = 1.0
## AI sideways grip multiplier (more grip = less sliding wide).
@export_range(0.5, 2.0, 0.01) var grip: float = 1.0
## Racing line quality: how much the AI cuts to the inside of bends (0-1).
@export_range(0.0, 1.0, 0.01) var apex_cut: float = 0.3
## How strongly AI cars steer around each other (lower = more aggressive).
@export_range(0.2, 2.0, 0.01) var avoidance: float = 1.0
## Rubber-band: max slow-down of AI cars that are far AHEAD of you (0.08 = up to 8% slower).
@export_range(0.0, 0.3, 0.01) var rubber_band_ahead: float = 0.04
## Rubber-band: max speed-up of AI cars that are far BEHIND you (0.05 = up to 5% faster).
@export_range(0.0, 0.3, 0.01) var rubber_band_behind: float = 0.02
