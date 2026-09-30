extends TouchScreenButton
## Round on-screen button drawn with shapes (no texture needed). Multi-touch safe.

enum Icon { LEFT, RIGHT, GAS, BRAKE }

@export var icon: Icon = Icon.LEFT
## Button radius in pixels (TouchControls overrides this on layout).
@export var radius: float = 80.0:
	set(v):
		radius = v
		_update_shape()
@export var fill_color: Color = Color(1, 1, 1, 0.14)
@export var pressed_color: Color = Color(1, 0.95, 0.6, 0.55)
@export var accent_color: Color = Color(1, 1, 1, 0.9)


func _ready() -> void:
	shape_centered = true
	_update_shape()
	pressed.connect(queue_redraw)
	released.connect(queue_redraw)


func _update_shape() -> void:
	var s := CircleShape2D.new()
	s.radius = radius
	shape = s
	queue_redraw()


func _draw() -> void:
	var down := is_pressed()
	draw_circle(Vector2.ZERO, radius, pressed_color if down else fill_color)
	draw_arc(Vector2.ZERO, radius - 2.0, 0.0, TAU, 48, Color(1, 1, 1, 0.55), 4.0, true)
	var r := radius * 0.42
	var col := accent_color
	match icon:
		Icon.LEFT:
			draw_colored_polygon(PackedVector2Array([Vector2(-r, 0), Vector2(r * 0.6, -r), Vector2(r * 0.6, r)]), col)
		Icon.RIGHT:
			draw_colored_polygon(PackedVector2Array([Vector2(r, 0), Vector2(-r * 0.6, -r), Vector2(-r * 0.6, r)]), col)
		Icon.GAS:
			draw_colored_polygon(PackedVector2Array([Vector2(0, -r * 1.05), Vector2(r * 0.85, -r * 0.1), Vector2(-r * 0.85, -r * 0.1)]), Color(0.45, 1, 0.5, 0.95))
			_label("GAS", r * 0.75)
		Icon.BRAKE:
			draw_rect(Rect2(-r * 0.7, -r * 0.8, r * 1.4, r * 0.55), Color(1, 0.4, 0.35, 0.95))
			_label("BRAKE", r * 0.62)


func _label(text: String, y: float) -> void:
	var font := ThemeDB.fallback_font
	var fs := int(radius * 0.3)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(font, Vector2(-w * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.6))
	draw_string(font, Vector2(-w * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
