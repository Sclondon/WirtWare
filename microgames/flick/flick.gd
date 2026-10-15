extends Microgame
## FLICK! Swipe the ball up into the target. You get one shot.
## Graveyard: a lollipop into the candy basket. Temple: a gold ball into
## Tlaloc's mouth. Swamp: a potion into the witch's cauldron.

const BALL_START := Vector2(360, 1080)
const BALL_RADIUS := 36.0
const SPEED := 1700.0
const BIN_Y := 300.0
## A drag this long launches without waiting for the release.
const MAX_DRAG := 260.0
const HORIZON := 410.0

var ball := BALL_START
var velocity := Vector2.ZERO
var launched := false
var aiming := false
var aim_start := Vector2.ZERO
var bin := Vector2(360, BIN_Y)
var bin_base_x := 360.0
var bin_radius := 80.0
var bin_swing := 0.0
var elapsed := 0.0
var spin := 0.0
var gulp := 0.0


func _init() -> void:
	prompt = "FLICK!"
	controls_hint = "SWIPE THE BALL UP"
	touch_hint = "FLICK THE BALL UP"
	controls = Controls.POINTER
	duration = 4.0


func _on_start() -> void:
	bin_base_x = randf_range(180, SCREEN.x - 180)
	bin_radius = [95.0, 80.0, 68.0][difficulty - 1]
	bin_swing = [0.0, 110.0, 170.0][difficulty - 1]


func _process(delta: float) -> void:
	update_pointer()
	elapsed += delta
	gulp = maxf(gulp - delta * 3.0, 0.0)
	if not is_resolved:
		bin.x = clampf(bin_base_x + sin(elapsed * 2.2) * bin_swing, 130, SCREEN.x - 130)

	if is_playing() and not launched:
		if pointer_pressed and pointer.distance_to(ball) < touch_size(130, 50):
			aiming = true
			aim_start = pointer
			Sfx.play("tap")
		if aiming:
			var drag := pointer - aim_start
			if pointer_released or drag.length() > MAX_DRAG:
				aiming = false
				if drag.length() > touch_size(40, 12):
					launched = true
					velocity = drag.normalized() * SPEED
					Sfx.play("whoosh")

	if launched and not is_resolved:
		ball += velocity * delta
		spin += delta * 12.0
		if ball.distance_to(bin) < bin_radius - BALL_RADIUS * 0.3:
			ball = bin
			win()
		elif not Rect2(Vector2(-60, -60), SCREEN + Vector2(120, 120)).has_point(ball):
			lose()
	if is_resolved and won:
		ball = bin
	queue_redraw()


func _on_resolved(result: bool) -> void:
	if result:
		gulp = 1.0
		Sfx.play(["coin", "munch", "splash"][stage])
		burst(bin, Stages.theme(stage).glow, 18, 420.0, 10.0)
		shake(6.0)
	else:
		Sfx.play("thud", 0.6)


func _ball_radius() -> float:
	# Shrinks as it flies "away" up the screen.
	return BALL_RADIUS * lerpf(1.0, 0.6, clampf((BALL_START.y - ball.y) / (BALL_START.y - BIN_Y), 0.0, 1.0))


func _draw() -> void:
	var theme := Stages.theme(stage)
	for i in 10:
		draw_rect(Rect2(0, HORIZON * i / 10.0, SCREEN.x, HORIZON / 10.0 + 1), (theme.sky as Color).lerp(theme.sky_low, i / 9.0))
	var ground: Color = theme.ground
	draw_rect(Rect2(0, HORIZON, SCREEN.x, SCREEN.y - HORIZON), ground)
	match stage:
		Stages.GRAVEYARD:
			draw_circle(Vector2(600, 130), 50, Color("fff2c4"))
			draw_circle(Vector2(580, 118), 50, (theme.sky as Color).lerp(theme.sky_low, 2.5 / 9.0))
			for x in [70.0, 650.0]:
				draw_sprite("graveyard/grave_1_small", 1, 0, Vector2(x, HORIZON - 40), 3.0, false, Color(0.6, 0.55, 0.7))
		Stages.TEMPLE:
			for row in 4:
				for col in 6:
					var x := col * 150.0 + (75.0 if row % 2 else 0.0) - 60.0
					draw_rect(Rect2(x, 120 + row * 72, 146, 68), Color("4d5a4f").lerp(Color("2f3a33"), row / 4.0))
			for x in [50.0, 670.0]:
				draw_sprite("temple/t_torch", 12, anim_frame(10, 4, x), Vector2(x, HORIZON - 70), 5.0)
		_:
			draw_sprite("swamp/tree_5", 1, 0, Vector2(80, HORIZON - 150), 3.0, false, Color(0.4, 0.55, 0.4))
			draw_sprite("graveyard/tree", 1, 0, Vector2(650, HORIZON - 150), 3.0, true, Color(0.4, 0.55, 0.4))
	# Floor lines narrowing toward the target, for a bit of depth.
	for i in 9:
		var x := i * 90.0
		draw_line(Vector2(x, SCREEN.y), Vector2(SCREEN.x / 2 + (x - SCREEN.x / 2) * 0.45, HORIZON), ground.lightened(0.12), 3)

	_draw_target()

	if aiming:
		var dir := (pointer - aim_start).normalized()
		for i in 7:
			draw_circle(ball + dir * (60 + i * 40), 7, Color(1, 1, 1, 0.45))
	elif not launched and not is_resolved:
		var bounce := absf(sin(elapsed * 6.0)) * 14
		draw_arrow(ball + Vector2(0, -90 - bounce), Vector2.UP, 64, Color(1, 1, 1, 0.5))

	if not (is_resolved and won):
		var scale := 6.0 * _ball_radius() / BALL_RADIUS
		match stage:
			Stages.GRAVEYARD:
				draw_sprite("graveyard/lollipop", 4, int(spin) % 4, ball, scale)
			Stages.TEMPLE:
				draw_sprite("temple/golden_Ball", 16, int(spin * 1.5) % 16, ball, scale * 0.75)
			_:
				draw_circle(ball, _ball_radius() * 1.2, Color(theme.glow, 0.2))
				draw_sprite("swamp/acid_potion", 4, anim_frame(8, 4), ball, scale * 0.75, false, Color.WHITE, spin * 0.5)

	if is_resolved:
		draw_text_centered("SWISH!" if won else "MISSED!", Vector2(360, 760), 90, theme.glow if won else Color("ef476f"))


func _draw_target() -> void:
	var lost := is_resolved and not won
	var s := 1.0 + 0.2 * gulp
	match stage:
		Stages.GRAVEYARD:
			draw_colored_polygon(ellipse_points(bin + Vector2(0, 100), Vector2(90, 16)), Color(0, 0, 0, 0.3))
			draw_set_transform(bin + Vector2(0, 108), 0.0, Vector2(s, 1.0 / s) * 6.0)
			draw_texture_rect(art("graveyard/candybasket"), Rect2(-16, -32, 32, 32), false)
			draw_set_transform(Vector2.ZERO)
		Stages.TEMPLE:
			# The ball has to go in Tlaloc's mouth. He glares when you miss.
			draw_circle(bin + Vector2(0, -40), 140, Color(Stages.theme(stage).glow, 0.15))
			draw_sprite("temple/tlaloc", 2, 1 if lost else 0, bin + Vector2(0, -40), 4.0 * s)
		_:
			draw_colored_polygon(ellipse_points(bin + Vector2(0, 30), Vector2(bin_radius + 20, 78)), Color("1c1c24"))
			draw_colored_polygon(ellipse_points(bin + Vector2(0, -8), Vector2(bin_radius + 22, 24)), Color("33334a"))
			draw_colored_polygon(ellipse_points(bin + Vector2(0, -6), Vector2(bin_radius + 4, 17)), Color("8ee04a"))
			for i in 3:
				var b := bin + Vector2(-40 + i * 40, -8 - fmod(_clock * 60.0 + i * 13.0, 26.0 + 30.0 * gulp))
				draw_circle(b, 8.0 - i + 8.0 * gulp, Color("b6f24e"))
	if not is_resolved:
		# A faint ring shows where the ball has to land.
		draw_arc(bin, bin_radius, 0, TAU, 40, Color(1, 1, 1, 0.25), 3)
