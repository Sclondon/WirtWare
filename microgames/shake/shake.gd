extends Microgame
## SHAKE! Rub back and forth on the snow globe until the snow fills it.
## Holding still lets the snow settle again. A homage to Snow Globe.
## Mashing left and right shakes it too, for keyboard players.

const GLOBE_POS := Vector2(360, 560)
const GLOBE_R := 230.0
const FLAKES := 80
const KEY_SHAKE := 300.0
const METER := Rect2(648, 330, 34, 460)

## 0 = all the snow lying in a heap, 1 = a full blizzard.
var swirl := 0.0
var needed_dist := 2000.0
var decay := 0.15
var wobble := 0.0
var last_dir := 0.0
var last_pointer := Vector2.ZERO
## Each flake: {pile (where it lies), angle, radius, spin, k (how much shaking lifts it)}.
var flakes: Array[Dictionary] = []
var theme: Dictionary


func _init() -> void:
	prompt = "SHAKE!"
	controls_hint = "DRAG BACK AND FORTH, OR MASH LEFT / RIGHT"
	touch_hint = "RUB IT BACK AND FORTH"
	controls = Controls.POINTER
	duration = 4.5


func _on_start() -> void:
	theme = Stages.theme(stage)
	# Real time shrinks as the game speeds up, so ease off the shaking needed.
	needed_dist = (1700.0 + 300.0 * difficulty) / sqrt(Engine.time_scale)
	decay = 0.05 + 0.04 * difficulty
	for i in FLAKES:
		var pile := Vector2(randf_range(-130, 130), randf_range(150, 190))
		pile = pile.limit_length(GLOBE_R - 24)
		flakes.append({
			"pile": pile, "angle": randf() * TAU, "radius": sqrt(randf()) * (GLOBE_R - 34),
			"spin": randf_range(0.6, 1.4) * (1.0 if randf() < 0.7 else -1.0), "k": randf(),
		})


func _process(delta: float) -> void:
	update_pointer()
	if is_playing():
		if pointer_down and not pointer_pressed:
			var drag := pointer - last_pointer
			_add_shake(minf(drag.length(), 120.0), drag.x)
		for side: String in ["left", "right"]:
			if Input.is_action_just_pressed(side):
				_add_shake(KEY_SHAKE, -60.0 if side == "left" else 60.0)
		if swirl >= 1.0:
			swirl = 1.0
			Sfx.play("spring", 0.8, 1.4)
			burst(GLOBE_POS, Color.WHITE, 30, 620, 10)
			popup("BLIZZARD!", GLOBE_POS + Vector2(0, -290), theme.glow, 76)
			win()
	last_pointer = pointer
	if not (is_resolved and won):
		swirl = maxf(swirl - decay * delta, 0.0)
	wobble = clampf(lerpf(wobble, 0.0, minf(delta * 8.0, 1.0)), -55.0, 55.0)
	for flake in flakes:
		flake.angle += delta * flake.spin * (0.6 + swirl * 2.4)
	queue_redraw()


func _add_shake(amount: float, dir: float) -> void:
	swirl += amount / needed_dist
	wobble += dir * 0.5
	var sign_now := signf(dir)
	if absf(dir) > 6.0 and sign_now != last_dir:
		last_dir = sign_now
		Sfx.play("swish", 0.7, 0.8 + swirl * 0.8, 90)
		burst(GLOBE_POS + Vector2(sign_now * GLOBE_R, 0), Color(1, 1, 1, 0.8), 3, 200, 6)


func _on_resolved(won_game: bool) -> void:
	if not won_game:
		Sfx.play("thud")
		popup("zzz...", GLOBE_POS + Vector2(0, -60), Color(1, 1, 1, 0.8), 60)


func _draw() -> void:
	for i in 16:
		draw_rect(Rect2(0, i * 80.0, SCREEN.x, 81), theme.sky.lerp(theme.sky_low, i / 15.0))
	draw_rect(Rect2(0, 880, SCREEN.x, SCREEN.y - 880), theme.ground)
	draw_rect(Rect2(0, 880, SCREEN.x, 10), theme.ground.lightened(0.25))

	var o := GLOBE_POS + Vector2(wobble, -absf(wobble) * 0.3)
	# Wooden base, banded in the stage's accent.
	var wood: Color = theme.accent.darkened(0.55)
	draw_colored_polygon(PackedVector2Array([o + Vector2(-190, 180), o + Vector2(190, 180), o + Vector2(240, 330), o + Vector2(-240, 330)]), wood)
	draw_rect(Rect2(o + Vector2(-222, 270), Vector2(444, 22)), theme.accent)

	# Inside the glass: the stage's little scene, the snow heap, and the flakes.
	draw_circle(o, GLOBE_R, theme.sky.lightened(0.12))
	draw_circle(o + Vector2(0, 40), GLOBE_R * 0.8, Color(theme.glow, 0.08))
	_draw_scene(o + Vector2(0, 95))
	# The heap: a mound on top, the curve of the glass underneath.
	var heap := lerpf(46.0, 6.0, swirl)
	var rim := GLOBE_R - 5.0
	var floor_y := 170.0
	var half := sqrt(rim * rim - floor_y * floor_y)
	var snow := PackedVector2Array()
	for i in 17:
		var x := lerpf(-half, half, i / 16.0)
		snow.append(o + Vector2(x, floor_y - heap * (1.0 - pow(x / half, 2))))
	var edge := atan2(floor_y, half)
	snow.append_array(ellipse_points(o, Vector2(rim, rim), edge, PI - edge, 16))
	draw_colored_polygon(snow, Color("f4f8ff"))
	for flake in flakes:
		var lift := clampf((swirl - float(flake.k) * 0.85) / 0.15, 0.0, 1.0)
		var orbit := Vector2.from_angle(flake.angle) * float(flake.radius)
		var pos: Vector2 = o + (flake.pile as Vector2).lerp(orbit, ease(lift, 0.5))
		draw_circle(pos, 7.0, Color.WHITE)
	# Glass rim and shine.
	draw_arc(o, GLOBE_R, 0, TAU, 64, Color(1, 1, 1, 0.55), 8)
	draw_arc(o, GLOBE_R - 30, PI * 1.05, PI * 1.45, 20, Color(1, 1, 1, 0.4), 14)
	draw_circle(o + Vector2(-120, -140), 12, Color(1, 1, 1, 0.5))

	# Snow meter.
	draw_rect(METER.grow(6), Color(0, 0, 0, 0.5))
	var fill := METER.size.y * swirl
	draw_rect(Rect2(METER.position.x, METER.end.y - fill, METER.size.x, fill), Color("f4f8ff"))
	var flake_icon := Vector2(METER.get_center().x, METER.position.y - 44)
	for i in 3:
		var a := i * PI / 3.0
		draw_line(flake_icon - Vector2.from_angle(a) * 22, flake_icon + Vector2.from_angle(a) * 22, theme.glow, 6)


func _draw_scene(at: Vector2) -> void:
	match posmod(stage, 3):
		Stages.GRAVEYARD:
			draw_sprite("graveyard/grave_2", 1, 0, at + Vector2(60, -10), 4.0)
			draw_sprite("graveyard/pumpkin", 6, anim_frame(6, 6), at + Vector2(-50, 30), 5.0)
		Stages.TEMPLE:
			draw_sprite("temple/t_totem_heads", 3, 0, at + Vector2(0, -10), 5.0)
		Stages.SWAMP:
			draw_sprite("swamp/h_frog", 1, 0, at + Vector2(0, 10), 7.0)
