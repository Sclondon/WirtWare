extends Microgame
## STOP! Hit the button while the needle is inside the green zone.

const BAR := Rect2(190, 400, 900, 70)

var needle_x := BAR.position.x
var needle_dir := 1.0
var needle_speed := 800.0
var zone := Rect2()


func _init() -> void:
	prompt = "STOP!"
	controls_hint = "PRESS SPACE"
	touch_hint = "TAP THE BUTTON"
	controls = Controls.BUTTON
	duration = 3.5


func _on_start() -> void:
	var width: float = [200.0, 140.0, 90.0][difficulty - 1]
	# Keep the zone away from the needle's starting edge.
	var x := randf_range(BAR.position.x + BAR.size.x * 0.3, BAR.end.x - width)
	zone = Rect2(x, BAR.position.y, width, BAR.size.y)
	needle_speed = 650.0 + 200.0 * difficulty


func _process(delta: float) -> void:
	if is_playing():
		needle_x += needle_dir * needle_speed * delta
		if needle_x > BAR.end.x or needle_x < BAR.position.x:
			needle_dir *= -1
			needle_x = clampf(needle_x, BAR.position.x, BAR.end.x)
		if Input.is_action_just_pressed("action"):
			if needle_x >= zone.position.x and needle_x <= zone.end.x:
				win()
			else:
				lose()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("2b2d42"))
	draw_circle(Vector2(640, 230), 110, Color("ffd166"))
	draw_face(Vector2(640, 230), 110, not is_resolved or won)

	draw_rect(BAR.grow(8), Color.BLACK)
	draw_rect(BAR, Color("ef476f"))
	draw_rect(zone, Color("06d6a0"))
	draw_line(Vector2(needle_x, BAR.position.y - 30), Vector2(needle_x, BAR.end.y + 30), Color.WHITE, 10)
	draw_colored_polygon(PackedVector2Array([
		Vector2(needle_x - 20, BAR.position.y - 50), Vector2(needle_x + 20, BAR.position.y - 50), Vector2(needle_x, BAR.position.y - 20),
	]), Color.WHITE)
	if is_resolved:
		draw_text_centered("PERFECT!" if won else "MISS!", Vector2(640, 570), 80, Color("06d6a0") if won else Color("ef476f"))
