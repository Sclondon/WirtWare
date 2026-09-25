extends Microgame
## FLICK! Swipe the paper ball into the bin. You get one shot.

const BALL_START := Vector2(640, 590)
const BALL_RADIUS := 34.0
const SPEED := 1400.0
## A drag this long launches without waiting for the release.
const MAX_DRAG := 260.0

var ball := BALL_START
var velocity := Vector2.ZERO
var launched := false
var aiming := false
var aim_start := Vector2.ZERO
var bin := Vector2(640, 190)
var bin_base_x := 640.0
var bin_radius := 80.0
var bin_swing := 0.0
var elapsed := 0.0


func _init() -> void:
	prompt = "FLICK!"
	controls_hint = "SWIPE THE BALL"
	touch_hint = "FLICK THE BALL"
	controls = Controls.POINTER
	duration = 4.0


func _on_start() -> void:
	bin_base_x = randf_range(330, 950)
	bin_radius = [95.0, 80.0, 68.0][difficulty - 1]
	bin_swing = [0.0, 150.0, 240.0][difficulty - 1]


func _process(delta: float) -> void:
	update_pointer()
	elapsed += delta
	bin.x = clampf(bin_base_x + sin(elapsed * 2.2) * bin_swing, 100, SCREEN.x - 100)

	if is_playing() and not launched:
		if pointer_pressed and pointer.distance_to(ball) < touch_size(120, 50):
			aiming = true
			aim_start = pointer
		if aiming:
			var drag := pointer - aim_start
			if pointer_released or drag.length() > MAX_DRAG:
				aiming = false
				if drag.length() > touch_size(40, 12):
					launched = true
					velocity = drag.normalized() * SPEED

	if launched and not is_resolved:
		ball += velocity * delta
		if ball.distance_to(bin) < bin_radius - BALL_RADIUS * 0.3:
			ball = bin
			win()
		elif not Rect2(Vector2(-60, -60), SCREEN + Vector2(120, 120)).has_point(ball):
			lose()
	if is_resolved and won:
		ball = bin
	queue_redraw()


func _ball_radius() -> float:
	# Shrinks as it flies "away" up the screen.
	return BALL_RADIUS * lerpf(1.0, 0.65, clampf((BALL_START.y - ball.y) / 420.0, 0.0, 1.0))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("dde5b6"))
	for y in range(40, int(SCREEN.y), 90):
		draw_line(Vector2(0, y), Vector2(SCREEN.x, y), Color("c9d1a0"), 3)

	draw_circle(bin, bin_radius + 12, Color("495057"))
	draw_circle(bin, bin_radius, Color("212529"))

	if aiming:
		var dir := (pointer - aim_start).normalized()
		for i in 6:
			draw_circle(ball + dir * (60 + i * 38), 7, Color(0, 0, 0, 0.35))
	elif not launched and not is_resolved:
		var bounce := absf(sin(elapsed * 6.0)) * 12
		draw_arrow(ball + Vector2(0, -80 - bounce), Vector2.UP, 60, Color(0, 0, 0, 0.35))

	var r := _ball_radius() * (0.8 if is_resolved and won else 1.0)
	draw_circle(ball, r, Color.WHITE)
	draw_arc(ball + Vector2(-6, -4), r * 0.55, 0.3, 2.4, 8, Color("adb5bd"), 3)
	draw_arc(ball + Vector2(8, 6), r * 0.45, 3.4, 5.6, 8, Color("adb5bd"), 3)

	if is_resolved:
		draw_text_centered("SWISH!" if won else "MISSED!", Vector2(640, 420), 90, Color("06d6a0") if won else Color("ef476f"))
