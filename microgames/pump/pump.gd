extends Microgame
## PUMP IT! Mash the button to inflate the balloon until it pops.

const BALLOON_POS := Vector2(330, 440)
const PUMP_POS := Vector2(560, 900)
const GROUND_Y := 960.0

var air := 0.0
var needed := 10.0
var pump_kick := 0.0


func _init() -> void:
	prompt = "PUMP IT!"
	controls_hint = "MASH SPACE"
	touch_hint = "MASH THE BUTTON"
	controls = Controls.BUTTON
	duration = 4.0


func _on_start() -> void:
	# Real time shrinks as the game speeds up, so ease off the press count.
	needed = roundf((6.0 + 2.0 * difficulty) / sqrt(Engine.time_scale))


func _process(delta: float) -> void:
	if is_playing():
		if Input.is_action_just_pressed("action"):
			air += 1.0
			pump_kick = 1.0
			if air >= needed:
				win()
		air = maxf(air - delta * 0.6 * difficulty, 0.0)
	pump_kick = move_toward(pump_kick, 0.0, delta * 6.0)
	queue_redraw()


func _balloon_radius() -> float:
	return 60.0 + 200.0 * clampf(air / needed, 0.0, 1.0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("ffd6e0"))
	draw_rect(Rect2(0, GROUND_Y, SCREEN.x, SCREEN.y - GROUND_Y), Color("c9a0dc"))

	# Pump: box, handle that dips on each press, and a hose to the balloon.
	var handle_y := PUMP_POS.y - 170 + pump_kick * 60
	draw_line(Vector2(PUMP_POS.x, handle_y), PUMP_POS, Color("444444"), 12)
	draw_line(Vector2(PUMP_POS.x - 65, handle_y), Vector2(PUMP_POS.x + 65, handle_y), Color("222222"), 22)
	draw_rect(Rect2(PUMP_POS - Vector2(55, 30), Vector2(110, 90)), Color("3a86ff"))

	var r := _balloon_radius()
	var knot := BALLOON_POS + Vector2(0, r)
	var hose := PackedVector2Array([PUMP_POS + Vector2(-55, 40), Vector2(BALLOON_POS.x, PUMP_POS.y + 40), knot])
	draw_polyline(hose, Color("333333"), 6)

	if is_resolved and won:
		for i in 14:
			var dir := Vector2.from_angle(TAU * i / 14.0)
			draw_line(BALLOON_POS + dir * 90, BALLOON_POS + dir * 260, Color("ffbe0b"), 10)
		draw_text_centered("POP!", BALLOON_POS, 120, Color("ff006e"))
	else:
		draw_circle(BALLOON_POS, r, Color("e63946"))
		draw_circle(BALLOON_POS + Vector2(-r, -r) * 0.4, r * 0.15, Color(1, 1, 1, 0.5))
		draw_colored_polygon(PackedVector2Array([knot + Vector2(-12, 14), knot + Vector2(12, 14), knot]), Color("e63946"))
		draw_face(BALLOON_POS, r * 0.8, not is_resolved)
