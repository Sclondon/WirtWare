extends Microgame
## LEAP! Time the surge meter to leap the salmon up the waterfall, step by step.
## A homage to Salmon Run 2.

const POOL_Y := 985.0
const TOP_Y := 235.0
const FALLS := Rect2(170, 160, 380, 880)
const METER := Rect2(42, 300, 46, 620)
const LEAP_TIME := 0.34

## Ledge heights, from the bottom pool (0) to the top pool (last).
var ledges: Array[float] = []
var step := 0
## Surge meter, 0..1, bouncing up and down; press while it is in the zone.
var level := 0.0
var level_dir := 1.0
## Seconds for the meter to sweep from empty to full.
var sweep := 0.9
var zone := Vector2(0.7, 0.9)
var fish := Vector2(360, POOL_Y)
var leap_from := Vector2.ZERO
var leap_to := Vector2.ZERO
var leap_t := -1.0
var smacked := false
var fall_vel := Vector2.ZERO
var spin := 0.0
var flow := 0.0
var theme := {}


func _init() -> void:
	prompt = "LEAP!"
	controls_hint = "PRESS SPACE IN THE GOLD"
	touch_hint = "TAP IN THE GOLD"
	controls = Controls.BUTTON
	duration = 5.0


func _on_start() -> void:
	theme = Stages.LOOKS.salmon_run
	var steps: int = [2, 3, 4][difficulty - 1]
	sweep = [0.95, 0.75, 0.62][difficulty - 1]
	for i in steps + 1:
		ledges.append(lerpf(POOL_Y, TOP_Y, float(i) / steps))
	fish = _spot(0)
	_new_zone()


## Where the salmon rests on ledge [param i]; it zig-zags up the falls.
func _spot(i: int) -> Vector2:
	var x := 360.0 if i == 0 or i == ledges.size() - 1 else (290.0 if i % 2 == 1 else 430.0)
	return Vector2(x, ledges[i] - 18)


func _new_zone() -> void:
	var size: float = [0.26, 0.22, 0.2][difficulty - 1]
	var low := randf_range(0.5, 0.95 - size)
	zone = Vector2(low, low + size)
	level = 0.0
	level_dir = 1.0


func _process(delta: float) -> void:
	flow += delta
	if smacked:
		fall_vel.y += 2600.0 * delta
		fish += fall_vel * delta
		spin += 9.0 * delta
	elif leap_t >= 0.0:
		leap_t += delta / LEAP_TIME
		var t := minf(leap_t, 1.0)
		fish = leap_from.lerp(leap_to, t) + Vector2(0, -120 * sin(t * PI))
		if leap_t >= 1.0:
			leap_t = -1.0
			fish = leap_to
			step += 1
			burst(fish + Vector2(0, 10), Color("bde0fe"), 10, 300, 8)
			Sfx.play("splash", 0.6, 1.0 + step * 0.1)
			if step == ledges.size() - 1:
				popup("TOP!", fish + Vector2(0, -60), theme.glow, 64)
				burst(fish, theme.accent, 20, 520, 12)
				win()
			else:
				_new_zone()
	elif is_playing():
		level += level_dir * delta / sweep
		if level >= 1.0:
			level = 1.0
			level_dir = -1.0
		elif level <= 0.0:
			level = 0.0
			level_dir = 1.0
		if Input.is_action_just_pressed("action"):
			if level >= zone.x and level <= zone.y:
				leap_from = fish
				leap_to = _spot(step + 1)
				leap_t = 0.0
				Sfx.play("jump", 0.8, 1.0 + step * 0.08)
				popup("NICE!" if absf(level - (zone.x + zone.y) / 2) > 0.04 else "PERFECT!", fish + Vector2(110, -40), theme.accent, 40)
			else:
				_smack()
	queue_redraw()


func _smack() -> void:
	smacked = true
	# Leap half way and slam into the rock lip above.
	fish.y -= 40
	fall_vel = Vector2(randf_range(-160, 160), -260)
	Sfx.play("thud")
	Sfx.play("hit", 0.7, 0.8)
	burst(fish + Vector2(0, -30), Color("d9d9d9"), 14, 380, 9)
	popup("SMACK!", fish + Vector2(0, -80), Color("ef476f"), 60)
	shake(14)
	lose()


func _draw() -> void:
	var sky: Color = theme.sky
	var low: Color = theme.sky_low
	var rock: Color = theme.ground
	draw_rect(Rect2(Vector2.ZERO, SCREEN), sky)
	draw_rect(Rect2(0, 640, SCREEN.x, 640), low)

	# Jungle walls either side of the falls.
	var leaf := Color("40916c").lerp(low, 0.3)
	var leaf_dark := leaf.darkened(0.35)
	for i in 9:
		var y := 140.0 + i * 115.0
		draw_circle(Vector2(40 + (i % 2) * 50, y), 110, leaf_dark)
		draw_circle(Vector2(SCREEN.x - 40 - (i % 2) * 50, y + 50), 110, leaf_dark)
	for i in 9:
		var y := 180.0 + i * 115.0
		draw_circle(Vector2(110 + (i % 3) * 20, y), 60, leaf)
		draw_circle(Vector2(SCREEN.x - 110 - (i % 3) * 20, y + 40), 60, leaf)

	# Rock cliff and the water sheet.
	draw_rect(FALLS.grow(40), rock.darkened(0.25))
	var water := Color("4ea8de").lerp(low, 0.3).lerp(theme.glow, 0.12)
	draw_rect(FALLS, water)
	for i in 14:
		var x := FALLS.position.x + 14 + i * 27.0
		var y := fposmod(flow * 620.0 + i * 97.0, FALLS.size.y + 200) + FALLS.position.y - 200
		draw_line(Vector2(x, maxf(y, FALLS.position.y)), Vector2(x, minf(y + 140, FALLS.end.y)), Color(1, 1, 1, 0.35), 6)

	# Ledges: rock steps the salmon lands on.
	for i in ledges.size():
		var y := ledges[i]
		if i == ledges.size() - 1:
			draw_rect(Rect2(FALLS.position.x - 40, y - 50, FALLS.size.x + 80, 70), water.lightened(0.15))
			draw_rect(Rect2(FALLS.position.x - 40, y + 14, FALLS.size.x + 80, 26), rock)
			continue
		if i == 0:
			continue
		var spot := _spot(i)
		draw_colored_polygon(PackedVector2Array([
			Vector2(spot.x - 110, y), Vector2(spot.x + 110, y), Vector2(spot.x + 90, y + 46), Vector2(spot.x - 90, y + 46),
		]), rock)
		draw_rect(Rect2(spot.x - 110, y - 6, 220, 12), rock.lightened(0.25))
	# Bottom pool with foam.
	draw_rect(Rect2(0, POOL_Y - 20, SCREEN.x, SCREEN.y - POOL_Y + 20), water.darkened(0.15))
	for i in 8:
		draw_circle(Vector2(FALLS.position.x + 30 + i * 46, POOL_Y - 16 + sin(flow * 9 + i) * 5), 22, Color(1, 1, 1, 0.75))

	# The surge: white water swelling under the salmon as the meter fills.
	if is_playing() and leap_t < 0.0:
		var swell := 18.0 + level * 46.0
		draw_colored_polygon(ellipse_points(fish + Vector2(0, 22), Vector2(60 + level * 40, swell), PI, TAU, 16), Color(1, 1, 1, 0.35 + level * 0.4))
	_draw_props()
	_draw_salmon(fish, smacked, spin)
	_draw_meter()

	if is_resolved and won:
		draw_text_centered("TOP POOL!", Vector2(360, 120), 64, theme.glow)
	elif smacked:
		draw_text_centered("SMACK!", Vector2(360, 120), 64, Color("ef476f"))
	elif is_resolved:
		draw_text_centered("TOO SLOW!", Vector2(360, 120), 64, Color("ef476f"))


## Jungle leaves hanging into the top corners.
func _draw_props() -> void:
	var leaf := Color("2e8b57")
	for side: float in [1.0, -1.0]:
		var root := Vector2(360 - side * 360, 60)
		for i in 4:
			var a := 0.35 + i * 0.32 + sin(flow * 2.0 + i) * 0.04
			var tip := root + Vector2(side * cos(a), sin(a)) * (150.0 - i * 18.0)
			var mid := root.lerp(tip, 0.5)
			var n := Vector2(-(tip - root).y, (tip - root).x).normalized() * 22.0
			draw_colored_polygon(PackedVector2Array([root, mid + n, tip, mid - n]), leaf.lightened(i * 0.06))


func _draw_salmon(pos: Vector2, hurt: bool, angle: float) -> void:
	var leaping := leap_t >= 0.0
	var tilt := angle if hurt else (-1.2 if leaping else -0.25 + sin(flow * 10) * 0.08)
	draw_set_transform(pos, tilt, Vector2(1.3, 1.3))
	var body := Color("ff6b6b")
	draw_colored_polygon(PackedVector2Array([Vector2(-44, 0), Vector2(-78, -24), Vector2(-70, 0), Vector2(-78, 24)]), body.darkened(0.2))
	draw_colored_polygon(ellipse_points(Vector2.ZERO, Vector2(56, 24)), body)
	draw_colored_polygon(ellipse_points(Vector2(4, 8), Vector2(42, 12), 0, PI), Color("ffd6a5"))
	for i in 3:
		draw_circle(Vector2(-18 + i * 14, -8), 3, body.darkened(0.35))
	if hurt:
		draw_line(Vector2(28, -12), Vector2(40, 0), Color.BLACK, 4)
		draw_line(Vector2(40, -12), Vector2(28, 0), Color.BLACK, 4)
	else:
		draw_circle(Vector2(34, -6), 8, Color.WHITE)
		draw_circle(Vector2(36, -6), 4, Color.BLACK)
	draw_set_transform(Vector2.ZERO)


func _draw_meter() -> void:
	draw_rect(METER.grow(8), Color("1b1b1b"))
	draw_rect(METER, Color("0b3954"))
	var zone_rect := Rect2(METER.position.x, METER.end.y - zone.y * METER.size.y, METER.size.x, (zone.y - zone.x) * METER.size.y)
	var lit := level >= zone.x and level <= zone.y and is_playing() and leap_t < 0.0
	draw_rect(zone_rect, theme.accent.lightened(0.3) if lit else theme.accent)
	var fill_h := level * METER.size.y
	draw_rect(Rect2(METER.position.x + 10, METER.end.y - fill_h, METER.size.x - 20, fill_h), Color(0.75, 0.92, 1.0, 0.8))
	var y := METER.end.y - fill_h
	draw_colored_polygon(PackedVector2Array([Vector2(METER.end.x + 8, y), Vector2(METER.end.x + 34, y - 16), Vector2(METER.end.x + 34, y + 16)]), Color.WHITE)
	draw_line(Vector2(METER.position.x - 6, y), Vector2(METER.end.x + 6, y), Color.WHITE, 6)
	draw_text_centered("%d/%d" % [step, ledges.size() - 1], Vector2(METER.get_center().x + 6, METER.position.y - 40), 36, Color.WHITE)
