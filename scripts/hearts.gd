extends Control
## Draws the row of lives shown between microgames.

var max_count := 4:
	set(value):
		max_count = value
		queue_redraw()
var count := 4:
	set(value):
		count = value
		queue_redraw()

const HEART_SIZE := 90.0
const SPACING := 120.0


func _draw() -> void:
	var start_x := size.x / 2 - SPACING * (max_count - 1) / 2.0
	for i in max_count:
		var color := Color("ff2e63") if i < count else Color(0, 0, 0, 0.3)
		_draw_heart(Vector2(start_x + i * SPACING, 70), HEART_SIZE, color)


func _draw_heart(c: Vector2, s: float, color: Color) -> void:
	draw_circle(c + Vector2(-s * 0.25, -s * 0.1), s * 0.28, color)
	draw_circle(c + Vector2(s * 0.25, -s * 0.1), s * 0.28, color)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-s * 0.52, 0), c + Vector2(s * 0.52, 0), c + Vector2(0, s * 0.5),
	]), color)
