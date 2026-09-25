extends Microgame
## DRAW! Wait for the signal, then shoot first. Fire too early and you lose.

const GROUND_Y := 540.0
const PLAYER_X := 260.0
const RIVAL_X := 1020.0

var elapsed := 0.0
var signal_time := 1.5
var window := 0.5
var too_soon := false


func _init() -> void:
	prompt = "DRAW!"
	controls_hint = "SPACE WHEN IT SAYS FIRE"
	touch_hint = "TAP WHEN IT SAYS FIRE"
	controls = Controls.BUTTON
	duration = 3.5


func _on_start() -> void:
	signal_time = randf_range(1.1, 2.0)
	# The window is in game time, so widen it with the speed-up to keep the
	# real-time reaction window fair.
	window = [0.6, 0.45, 0.35][difficulty - 1] * Engine.time_scale


func _process(delta: float) -> void:
	if is_playing():
		elapsed += delta
		if Input.is_action_just_pressed("action"):
			if elapsed < signal_time:
				too_soon = true
				lose()
			else:
				win()
		elif elapsed > signal_time + window:
			lose()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("f4a261"))
	draw_circle(Vector2(640, 470), 150, Color("ffd166"))
	draw_rect(Rect2(0, GROUND_Y, SCREEN.x, SCREEN.y - GROUND_Y), Color("e9c46a"))

	var player_state := 0
	var rival_state := 0
	if is_resolved:
		if won:
			player_state = 1
			rival_state = 2
		elif not too_soon:
			player_state = 2
			rival_state = 1
	_draw_cowboy(PLAYER_X, 1.0, Color("264653"), player_state)
	_draw_cowboy(RIVAL_X, -1.0, Color("9b2226"), rival_state)

	if too_soon:
		draw_text_centered("TOO SOON!", Vector2(640, 200), 110, Color("ef476f"))
	elif elapsed >= signal_time and not (is_resolved and not won):
		draw_text_centered("FIRE!", Vector2(640, 200), 150, Color("ef476f") if not is_resolved else Color.WHITE)
	elif is_resolved and not won:
		draw_text_centered("TOO SLOW!", Vector2(640, 200), 110, Color("ef476f"))


## state: 0 = standing, 1 = shooting, 2 = down.
func _draw_cowboy(x: float, facing: float, color: Color, state: int) -> void:
	if state == 2:
		draw_rect(Rect2(x - 60, GROUND_Y - 30, 120, 30), color)
		var fallen_head := Vector2(x - facing * 85, GROUND_Y - 22)
		draw_circle(fallen_head, 24, Color("f1c27d"))
		draw_face(fallen_head, 30, false)
		draw_rect(Rect2(x - facing * 150 - 25, GROUND_Y - 12, 50, 12), Color("6f4518"))
		return

	draw_rect(Rect2(x - 22, GROUND_Y - 120, 44, 120), color)
	var head := Vector2(x, GROUND_Y - 145)
	draw_circle(head, 26, Color("f1c27d"))
	draw_face(head, 32, true)
	draw_rect(Rect2(x - 42, GROUND_Y - 172, 84, 9), Color("6f4518"))
	draw_rect(Rect2(x - 22, GROUND_Y - 200, 44, 30), Color("6f4518"))
	if state == 1:
		var hand := Vector2(x + facing * 80, GROUND_Y - 95)
		draw_line(Vector2(x, GROUND_Y - 95), hand, color, 12)
		draw_rect(Rect2(hand - Vector2(0 if facing > 0 else 30, 8), Vector2(30, 14)), Color("333333"))
		draw_circle(hand + Vector2(facing * 50, 0), 18, Color("ffbe0b"))
	else:
		draw_line(Vector2(x + facing * 10, GROUND_Y - 100), Vector2(x + facing * 30, GROUND_Y - 50), color, 12)
