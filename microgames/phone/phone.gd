extends Microgame
## PHONE HOME! Mash to pedal the BMX up to speed and fly across the full moon
## before the van catches you. A homage to Phone Home.

const ROAD_Y := 960.0
const WHEEL_R := 32.0
const MOON_POS := Vector2(420, 540)
const MOON_R := 250.0
const FLY_TIME := 0.9
const SILHOUETTE := Color("0b0912")
## A point in the bike's flight curve (with the lift-off point as the start).
const FLY_CONTROL := Vector2(380, 560)
const FLY_END := Vector2(840, 280)

var power := 0.0
var needed := 10.0
var decay := 0.5
var elapsed := 0.0
var bike_pos := Vector2(250, ROAD_Y - WHEEL_R)
var bike_tilt := 0.0
var wheel_angle := 0.0
var scroll := 0.0
var flying := false
var fly_t := 0.0
var lift_pos := Vector2.ZERO
var van_front := 40.0
var caught_t := -1.0
var theme: Dictionary


func _init() -> void:
	prompt = "PHONE HOME!"
	controls_hint = "MASH SPACE"
	touch_hint = "MASH THE BUTTON"
	controls = Controls.BUTTON
	duration = 4.5


func _on_start() -> void:
	theme = Stages.theme(stage)
	# Real time shrinks as the game speeds up, so ease off the press count.
	needed = roundf((5.0 + 3.0 * difficulty) / sqrt(Engine.time_scale))
	decay = 0.4 * difficulty


func _ratio() -> float:
	return clampf(power / needed, 0.0, 1.0)


func _process(delta: float) -> void:
	elapsed += delta
	if is_playing() and not flying:
		if Input.is_action_just_pressed("action"):
			power += 1.0
			Sfx.play("tap", 0.8, 0.8 + _ratio() * 0.9)
			burst(bike_pos + Vector2(-50, WHEEL_R - 4), theme.ground.lightened(0.3), 4, 220, 8)
			if power >= needed:
				_lift_off()
		power = maxf(power - decay * delta, 0.0)

	var speed := 150.0 + _ratio() * 900.0
	if flying:
		fly_t += delta
		var k := minf(fly_t / FLY_TIME, 1.0)
		bike_pos = lift_pos.lerp(FLY_CONTROL, k).lerp(FLY_CONTROL.lerp(FLY_END, k), k)
		bike_tilt = lerpf(bike_tilt, -0.35, delta * 6.0)
		if fly_t >= 0.3 and is_playing():
			win()
	elif caught_t >= 0.0:
		caught_t += delta
		speed = 0.0
		bike_pos += Vector2(260, -300 + caught_t * 1400.0) * delta
		bike_pos.y = minf(bike_pos.y, ROAD_Y - 16)
		bike_tilt = minf(bike_tilt + delta * 7.0, 1.6)
	else:
		bike_pos.x = lerpf(bike_pos.x, 250.0 + 120.0 * _ratio(), delta * 5.0)
		bike_pos.y = ROAD_Y - WHEEL_R - absf(sin(scroll * 0.02)) * 3.0 * _ratio()
		# The van creeps up on you as the fuse burns.
		var chase := pow(clampf(elapsed / duration, 0.0, 1.0), 1.6)
		van_front = lerpf(40.0, bike_pos.x - 70.0, chase)
	if not flying or fly_t < 0.1:
		scroll += speed * delta
	wheel_angle += speed * delta / WHEEL_R
	queue_redraw()


func _lift_off() -> void:
	flying = true
	lift_pos = bike_pos
	Sfx.play("whoosh")
	Sfx.play("spring", 0.7, 1.3)
	burst(bike_pos, theme.glow, 24, 520, 10)
	popup("LIFT OFF!", Vector2(360, 300), theme.glow, 72)


func _on_resolved(won_game: bool) -> void:
	if won_game:
		return
	caught_t = 0.0
	van_front = bike_pos.x - 40.0
	Sfx.play("hit")
	burst(bike_pos, Color.WHITE, 18, 460, 10)
	shake(14)
	popup("CAUGHT!", Vector2(360, 760), Color("ff5d73"), 72)


func _draw() -> void:
	for i in 16:
		draw_rect(Rect2(0, i * 80.0, SCREEN.x, 81), theme.sky.lerp(theme.sky_low, i / 15.0))
	for i in 40:
		var p := Vector2(fmod(i * 137.0, 720.0), 100.0 + fmod(i * 251.0, 700.0))
		draw_circle(p, 2.0 + (i % 3), Color(1, 1, 1, 0.35 + 0.3 * sin(_clock * 3.0 + i)))

	# The big full moon, in the stage's glow colour.
	var moon: Color = theme.glow.lightened(0.35)
	draw_circle(MOON_POS, MOON_R + 30, Color(moon, 0.15))
	draw_circle(MOON_POS, MOON_R, moon)
	for c: Vector3 in [Vector3(-80, -60, 46), Vector3(70, 40, 34), Vector3(-30, 110, 26), Vector3(110, -120, 22)]:
		draw_circle(MOON_POS + Vector2(c.x, c.y), c.z, moon.darkened(0.08))

	# Far hill with the stage's skyline, then the road.
	var hill := PackedVector2Array([Vector2(0, 880)])
	for i in 13:
		var x := i * 60.0
		hill.append(Vector2(x, 850 - sin(i * 0.9 + scroll * 0.0004) * 26.0))
	hill.append_array([Vector2(720, 880), Vector2(720, ROAD_Y), Vector2(0, ROAD_Y)])
	var dark: Color = theme.ground.darkened(0.55)
	draw_colored_polygon(hill, dark)
	_draw_skyline(dark)
	draw_rect(Rect2(0, ROAD_Y, SCREEN.x, SCREEN.y - ROAD_Y), theme.ground.darkened(0.25))
	for i in 9:
		var x := fposmod(i * 100.0 - scroll, 900.0) - 90.0
		draw_line(Vector2(x, ROAD_Y + 20), Vector2(x + 50, ROAD_Y + 20), theme.ground.lightened(0.1), 6)

	# Speed meter: fill it to lift off.
	var bar := Rect2(120, 1000, 480, 34)
	draw_rect(bar.grow(5), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _ratio(), bar.size.y)), theme.accent)
	draw_circle(Vector2(bar.end.x + 34, bar.get_center().y), 20, moon)
	draw_circle(Vector2(bar.end.x + 34, bar.get_center().y), 26, Color(moon, 0.3))

	_draw_van()
	_draw_bike(bike_pos, bike_tilt)


func _draw_skyline(color: Color) -> void:
	match posmod(stage, 3):
		Stages.GRAVEYARD:
			for x in [90.0, 210.0, 600.0]:
				draw_sprite("graveyard/grave_2", 1, 0, Vector2(x, 818), 3.0, false, color)
		Stages.TEMPLE:
			var base := Vector2(130, 850)
			for step in 4:
				var w := 220.0 - step * 50.0
				draw_rect(Rect2(base.x - w / 2, base.y - (step + 1) * 34.0, w, 36), color)
		Stages.SWAMP:
			draw_sprite("swamp/tree_5", 1, 0, Vector2(110, 720), 2.5, false, color)
			draw_sprite("swamp/tree_5", 1, 0, Vector2(640, 740), 2.0, true, color)


func _draw_van() -> void:
	var f := van_front
	var body := Color("1a1626")
	# Headlight beam on the road ahead.
	draw_colored_polygon(PackedVector2Array([Vector2(f, 905), Vector2(f + 460, 860), Vector2(f + 460, ROAD_Y + 30)]), Color(theme.glow, 0.16))
	draw_rect(Rect2(f - 270, 820, 210, 120), body)
	draw_colored_polygon(PackedVector2Array([Vector2(f - 60, 820), Vector2(f - 20, 860), Vector2(f, 870), Vector2(f, 940), Vector2(f - 60, 940)]), body)
	draw_colored_polygon(PackedVector2Array([Vector2(f - 54, 832), Vector2(f - 26, 864), Vector2(f - 54, 864)]), Color(theme.glow, 0.4))
	draw_circle(Vector2(f - 4, 905), 9, theme.glow)
	var siren := Color("ff3b4e") if int(_clock * 8.0) % 2 == 0 else Color("3a86ff")
	draw_rect(Rect2(f - 170, 806, 40, 14), siren)
	draw_circle(Vector2(f - 150, 810), 30, Color(siren, 0.25))
	for x in [f - 220.0, f - 90.0]:
		draw_circle(Vector2(x, ROAD_Y - 24), 24, Color.BLACK)
		draw_circle(Vector2(x, ROAD_Y - 24), 9, Color("444444"))


## The kid on the BMX, with a little hooded alien in the basket, all in silhouette.
func _draw_bike(pos: Vector2, tilt: float) -> void:
	draw_set_transform(pos, tilt)
	var s := SILHOUETTE
	var rear := Vector2(-48, 0)
	var front := Vector2(48, 0)
	var crank := Vector2(0, 4)
	var seat := Vector2(-18, -46)
	var head_tube := Vector2(32, -44)
	for w: Vector2 in [rear, front]:
		draw_arc(w, WHEEL_R, 0, TAU, 24, s, 7)
		for k in 3:
			var a := wheel_angle + k * PI / 3.0
			draw_line(w - Vector2.from_angle(a) * WHEEL_R, w + Vector2.from_angle(a) * WHEEL_R, s, 2)
	for seg: Array in [[rear, crank], [rear, seat], [seat, crank], [crank, head_tube], [seat, head_tube], [head_tube, front]]:
		draw_line(seg[0], seg[1], s, 6)
	draw_line(head_tube, Vector2(28, -62), s, 6)
	draw_line(Vector2(18, -64), Vector2(40, -60), s, 7)
	# Basket and the alien peeking out under its blanket hood.
	draw_colored_polygon(PackedVector2Array([Vector2(34, -60), Vector2(80, -60), Vector2(74, -30), Vector2(40, -30)]), s)
	draw_colored_polygon(ellipse_points(Vector2(58, -72), Vector2(17, 15)), s)
	draw_colored_polygon(PackedVector2Array([Vector2(38, -66), Vector2(56, -96), Vector2(78, -66)]), s)
	draw_circle(Vector2(52, -72), 3.5, theme.glow)
	draw_circle(Vector2(63, -72), 3.5, theme.glow)
	# The kid: legs on the pedals, leaning over the bars in a hoodie.
	var hip := Vector2(-16, -54)
	var pedal_a := wheel_angle * 0.5
	for k in 2:
		var pedal := crank + Vector2.from_angle(pedal_a + k * PI) * 18.0
		var d := pedal - hip
		var bend := sqrt(maxf(38.0 * 38.0 - d.length_squared() / 4.0, 0.0))
		var knee := (hip + pedal) / 2.0 + d.normalized().rotated(-PI / 2) * bend
		draw_polyline(PackedVector2Array([hip, knee, pedal]), s, 10)
	var shoulder := Vector2(8, -96)
	draw_line(hip, shoulder, s, 22)
	draw_line(shoulder, Vector2(30, -64), s, 9)
	draw_circle(Vector2(18, -116), 18, s)
	draw_colored_polygon(PackedVector2Array([Vector2(4, -130), Vector2(-14, -116), Vector2(4, -104)]), s)
	draw_set_transform(Vector2.ZERO)
