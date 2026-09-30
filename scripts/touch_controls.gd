extends CanvasLayer
## On-screen touch controls: steer left/right (bottom-left), gas/brake (bottom-right).
## Multi-touch: each TouchScreenButton tracks its own finger. Buttons trigger the same
## input actions as the keyboard (steer_left, steer_right, accelerate, brake).

enum ShowMode { AUTO, ALWAYS, NEVER }

## AUTO = show on touch devices (or as soon as the screen is touched).
@export var show_mode: ShowMode = ShowMode.AUTO
## Radius of the steering and gas buttons (in UI pixels; the UI is 720 px on the short side).
@export var button_radius: float = 92.0
## Brake button size relative to the others.
@export_range(0.5, 1.2, 0.01) var brake_scale: float = 0.85
## Distance from the screen edges.
@export var edge_margin: float = 26.0
## Space between buttons.
@export var button_gap: float = 18.0
## Overall opacity of the controls.
@export_range(0.1, 1.0, 0.01) var opacity: float = 0.9

var _active := true
var _wanted := false

@onready var left_btn: TouchScreenButton = $Left
@onready var right_btn: TouchScreenButton = $Right
@onready var gas_btn: TouchScreenButton = $Gas
@onready var brake_btn: TouchScreenButton = $Brake


func _ready() -> void:
	get_viewport().size_changed.connect(_layout)
	for b in [left_btn, right_btn, gas_btn, brake_btn]:
		b.modulate.a = opacity
	_layout()
	_update_visibility(false)


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	var r := button_radius
	var br := r * brake_scale
	left_btn.radius = r
	right_btn.radius = r
	gas_btn.radius = r
	brake_btn.radius = br
	var y := size.y - edge_margin - r
	left_btn.position = Vector2(edge_margin + r, y)
	right_btn.position = Vector2(edge_margin + 3.0 * r + button_gap, y)
	gas_btn.position = Vector2(size.x - edge_margin - r, y)
	if size.x < size.y * 1.1:
		# Portrait / square: brake above gas so everything fits the width.
		brake_btn.position = Vector2(size.x - edge_margin - r, y - r - br - button_gap)
	else:
		brake_btn.position = Vector2(size.x - edge_margin - 2.0 * r - br - button_gap, y + r - br)


func _update_visibility(touched: bool) -> void:
	match show_mode:
		ShowMode.ALWAYS: _wanted = true
		ShowMode.NEVER: _wanted = false
		ShowMode.AUTO: _wanted = touched or _wanted or DisplayServer.is_touchscreen_available() \
				or OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	visible = _wanted and _active


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not _wanted and show_mode == ShowMode.AUTO:
		_update_visibility(true)


## Hide controls during pause / results.
func set_active(active: bool) -> void:
	_active = active
	visible = _wanted and _active
