extends Microgame
## STOP! Hit the button while the needle is inside the green zone.

const BAR := Rect2(430, 200, 120, 800)
const FACE_POS := Vector2(210, 600)

var needle_y := BAR.end.y
var needle_dir := -1.0
var needle_speed := 800.0
var zone := Rect2()


func _init() -> void:
	prompt = "STOP!"
	controls_hint = "PRESS SPACE"
	touch_hint = "TAP THE BUTTON"
	controls = Controls.BUTTON
	duration = 3.5


func _on_start() -> void:
	var height: float = [200.0, 140.0, 90.0][difficulty - 1]
	# Keep the zone away from the needle's starting end (the bottom).
	var y := randf_range(BAR.position.y, BAR.end.y - BAR.size.y * 0.3 - height)
	zone = Rect2(BAR.position.x, y, BAR.size.x, height)
	needle_speed = 650.0 + 200.0 * difficulty


func _process(delta: float) -> void:
	if is_playing():
		needle_y += needle_dir * needle_speed * delta
		if needle_y < BAR.position.y or needle_y > BAR.end.y:
			needle_dir *= -1
			needle_y = clampf(needle_y, BAR.position.y, BAR.end.y)
		if Input.is_action_just_pressed("action"):
			if needle_y >= zone.position.y and needle_y <= zone.end.y:
				win()
			else:
				lose()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("2b2d42"))
	draw_circle(FACE_POS, 125, Color("ffd166"))
	draw_face(FACE_POS, 125, not is_resolved or won)

	draw_rect(BAR.grow(8), Color.BLACK)
	draw_rect(BAR, Color("ef476f"))
	draw_rect(zone, Color("06d6a0"))
	draw_line(Vector2(BAR.position.x - 34, needle_y), Vector2(BAR.end.x + 34, needle_y), Color.WHITE, 10)
	draw_colored_polygon(PackedVector2Array([
		Vector2(BAR.position.x - 60, needle_y - 22), Vector2(BAR.position.x - 60, needle_y + 22), Vector2(BAR.position.x - 26, needle_y),
	]), Color.WHITE)
	if is_resolved:
		draw_text_centered("PERFECT!" if won else "MISS!", Vector2(360, 120), 80, Color("06d6a0") if won else Color("ef476f"))
