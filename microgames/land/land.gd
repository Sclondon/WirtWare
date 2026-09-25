extends Microgame
## LAND! Hold the button to fire the thruster and touch down gently.

const GROUND_Y := 1000.0
const THRUST := 1000.0
const METER := Rect2(640, 260, 40, 560)
const METER_MAX_SPEED := 700.0

var ship := Vector2(330, 140)
var velocity := 100.0
var gravity := 380.0
var safe_speed := 180.0
var thrusting := false
var stars := PackedVector2Array()


func _init() -> void:
	prompt = "LAND!"
	controls_hint = "HOLD SPACE"
	touch_hint = "HOLD THE BUTTON"
	controls = Controls.BUTTON
	duration = 5.0


func _ready() -> void:
	for i in 70:
		stars.append(Vector2(randf() * SCREEN.x, randf() * GROUND_Y))


func _on_start() -> void:
	gravity = 300.0 + 80.0 * difficulty
	safe_speed = 200.0 - 20.0 * difficulty


func _process(delta: float) -> void:
	thrusting = is_playing() and Input.is_action_pressed("action")
	if is_playing():
		velocity += (gravity - (THRUST if thrusting else 0.0)) * delta
		ship.y += velocity * delta
		if ship.y < 90:
			ship.y = 90
			velocity = maxf(velocity, 0.0)
		if ship.y >= GROUND_Y:
			ship.y = GROUND_Y
			if velocity <= safe_speed:
				win()
			else:
				lose()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("0b132b"))
	for star in stars:
		draw_circle(star, 2, Color(1, 1, 1, 0.7))
	draw_circle(Vector2(140, 260), 60, Color("e9ecef"))
	draw_circle(Vector2(120, 245), 12, Color("ced4da"))
	draw_rect(Rect2(0, GROUND_Y, SCREEN.x, SCREEN.y - GROUND_Y), Color("adb5bd"))
	draw_rect(Rect2(ship.x - 100, GROUND_Y - 6, 200, 12), Color("ffd60a"))

	var crashed := is_resolved and not won
	var body := ship + Vector2(0, -60)
	if crashed:
		for i in 12:
			var dir := Vector2.from_angle(TAU * i / 12.0 + 0.2)
			draw_line(body + dir * 30, body + dir * 150, Color("fb8500"), 12)
		draw_circle(body, 50, Color("ffb703"))
	else:
		if thrusting:
			draw_colored_polygon(PackedVector2Array([
				body + Vector2(-18, 30), body + Vector2(18, 30), body + Vector2(0, 90 + randf() * 20),
			]), Color("fb8500"))
		draw_line(body + Vector2(-20, 20), ship + Vector2(-42, 0), Color("dddddd"), 6)
		draw_line(body + Vector2(20, 20), ship + Vector2(42, 0), Color("dddddd"), 6)
		draw_circle(body, 38, Color.WHITE)
		draw_circle(body + Vector2(0, -6), 18, Color("4cc9f0"))
		if is_resolved:
			draw_face(body + Vector2(0, -6), 24, true)

	# Speed meter: green while slow enough to land safely.
	draw_rect(METER.grow(4), Color("333333"))
	var speed_ratio := clampf(velocity / METER_MAX_SPEED, 0.0, 1.0)
	var fill_h := METER.size.y * speed_ratio
	var safe := velocity <= safe_speed
	draw_rect(Rect2(METER.position.x, METER.end.y - fill_h, METER.size.x, fill_h), Color("06d6a0") if safe else Color("ef476f"))
	var safe_y := METER.end.y - METER.size.y * safe_speed / METER_MAX_SPEED
	draw_line(Vector2(METER.position.x - 10, safe_y), Vector2(METER.end.x + 10, safe_y), Color.WHITE, 4)
	draw_text_centered("SPEED", Vector2(METER.get_center().x - 10, METER.end.y + 40), 26)
