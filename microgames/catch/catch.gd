extends Microgame
## CATCH! Slide the basket under the falling apple.

const BASKET_Y := 600.0
const BASKET_W := 170.0
const BASKET_SPEED := 760.0
const APPLE_R := 32.0
const GROUND_Y := 680.0

var basket_x := SCREEN.x / 2
var apple := Vector2.ZERO
var apple_vel := Vector2.ZERO
var caught := false


func _init() -> void:
	prompt = "CATCH!"
	controls_hint = "ARROW KEYS"
	touch_hint = "LEFT / RIGHT"
	controls = Controls.LEFT_RIGHT
	duration = 4.0


func _on_start() -> void:
	apple = Vector2(randf_range(150, SCREEN.x - 150), 110)
	# Start the basket well away from the apple so the player has to move.
	basket_x = fposmod(apple.x - 100 + randf_range(400, 700), SCREEN.x - 200) + 100
	var fall_time := 2.6 - 0.35 * difficulty
	apple_vel.y = (BASKET_Y - apple.y) / fall_time
	if difficulty >= 2:
		apple_vel.x = randf_range(180, 360) * (1.0 if randf() < 0.5 else -1.0)


func _process(delta: float) -> void:
	if is_playing():
		var half := BASKET_W / 2
		basket_x = clampf(basket_x + Input.get_axis("left", "right") * BASKET_SPEED * delta, half, SCREEN.x - half)

	if caught:
		apple = Vector2(basket_x, BASKET_Y - 8)
	elif active and apple.y < GROUND_Y:
		apple += apple_vel * delta
		if apple.x < APPLE_R or apple.x > SCREEN.x - APPLE_R:
			apple_vel.x *= -1
			apple.x = clampf(apple.x, APPLE_R, SCREEN.x - APPLE_R)
		if not is_resolved and apple.y >= BASKET_Y - 8:
			if absf(apple.x - basket_x) < BASKET_W / 2:
				caught = true
				win()
			else:
				lose()
		apple.y = minf(apple.y, GROUND_Y)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("fefae0"))
	draw_rect(Rect2(0, GROUND_Y + APPLE_R - 10, SCREEN.x, 100), Color("a7c957"))
	# Tree canopy along the top.
	for i in 12:
		draw_circle(Vector2(i * 120 + 20, 20 + (i % 2) * 30), 90, Color("386641"))

	var splat := is_resolved and not won
	if splat:
		draw_circle(apple, APPLE_R * 1.2, Color("9d0208"))
	else:
		draw_line(apple + Vector2(0, -APPLE_R), apple + Vector2(4, -APPLE_R - 18), Color("5c4033"), 6)
		draw_circle(apple + Vector2(14, -APPLE_R - 10), 10, Color("70e000"))
		draw_circle(apple, APPLE_R, Color("d00000"))
		draw_circle(apple + Vector2(-10, -10), 8, Color(1, 1, 1, 0.5))

	var top := BASKET_Y - 10
	draw_colored_polygon(PackedVector2Array([
		Vector2(basket_x - BASKET_W / 2, top), Vector2(basket_x + BASKET_W / 2, top),
		Vector2(basket_x + BASKET_W / 2 - 20, top + 70), Vector2(basket_x - BASKET_W / 2 + 20, top + 70),
	]), Color("bc6c25"))
	for i in 3:
		var y := top + 18 + i * 20
		draw_line(Vector2(basket_x - BASKET_W / 2 + 5 + i * 7, y), Vector2(basket_x + BASKET_W / 2 - 5 - i * 7, y), Color("7f4f24"), 4)
	if is_resolved:
		draw_face(Vector2(basket_x, top + 38), 34, won)
