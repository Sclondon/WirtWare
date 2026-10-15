extends Microgame
## BLAST! The toy robot slides along the table; fire up to hit the saucer before it abducts Denver.
## A homage to Denver Vs The Universe.

const TABLE_Y := 960.0
const ROBOT_Y := 885.0
const SHOT_SPEED := 2200.0
const COOLDOWN := 0.22
## Saucer height where its tractor beam grabs a building.
const ABDUCT_Y := 560.0
const SAUCER_HALF := Vector2(66, 32)
## The blaster arm sits to the right of the robot's middle.
const GUN := 58.0

var robot_x := 120.0
var robot_dir := 1.0
var robot_speed := 380.0
var ammo := 3
var cooldown := 0.0
var shots := PackedVector2Array()
## Each saucer: {"pos": Vector2, "dir": float, "speed": float, "drop": float, "alive": bool, "fall": float}.
var saucers: Array[Dictionary] = []
## Each building: {"x", "w", "h", "kind" (0 block, 1 arch top, 2 spire), "lift" (pixels raised by a beam)}.
var buildings: Array[Dictionary] = []
var abductor := -1
var target := -1
var out_of_ammo := false
var theme := {}


func _init() -> void:
	prompt = "BLAST!"
	controls_hint = "PRESS SPACE TO FIRE"
	touch_hint = "TAP TO FIRE"
	controls = Controls.BUTTON
	duration = 5.0


func _on_start() -> void:
	theme = Stages.LOOKS.denver
	robot_speed = [360.0, 420.0, 470.0][difficulty - 1]
	robot_x = randf_range(100, 560)
	robot_dir = 1.0 if randf() < 0.5 else -1.0
	ammo = [3, 3, 4][difficulty - 1]
	var count := 2 if difficulty == 3 else 1
	var speed: float = [230.0, 310.0, 270.0][difficulty - 1]
	for i in count:
		var start_y := 210.0 + i * 90.0
		saucers.append({
			"pos": Vector2(randf_range(140, 580), start_y),
			"dir": 1.0 if (i + randi()) % 2 == 0 else -1.0,
			"speed": speed * randf_range(0.9, 1.1),
			# Each reaches the skyline in about 4.3 s.
			"drop": (ABDUCT_Y - start_y) / 4.3,
			"alive": true,
			"fall": 0.0,
		})
	var xs := [70.0, 175.0, 290.0, 405.0, 520.0, 640.0]
	for i in xs.size():
		buildings.append({"x": xs[i], "w": randf_range(70, 96), "h": randf_range(130, 250), "kind": i % 3, "lift": 0.0})


func _process(delta: float) -> void:
	cooldown -= delta
	if is_playing():
		robot_x += robot_dir * robot_speed * delta
		if robot_x < 60 or robot_x > SCREEN.x - 120:
			robot_dir = -robot_dir
			robot_x = clampf(robot_x, 60, SCREEN.x - 120)
		if Input.is_action_just_pressed("action"):
			_fire()

	for i in range(shots.size() - 1, -1, -1):
		shots[i].y -= SHOT_SPEED * delta
		if not is_resolved:
			for saucer in saucers:
				if saucer.alive and _hits(shots[i], saucer.pos):
					_down(saucer)
					shots[i].y = -100
					break
		if shots[i].y < -40:
			shots.remove_at(i)
	if is_playing() and ammo == 0 and shots.is_empty() and saucers.any(func(s: Dictionary) -> bool: return s.alive):
		out_of_ammo = true
		Sfx.play("buzz", 0.5, 1.4)
		# With nothing left to stop it, the nearest saucer swoops in and takes a building.
		for i in saucers.size():
			if saucers[i].alive:
				_abduct(i)
				break

	for i in saucers.size():
		var saucer: Dictionary = saucers[i]
		if not saucer.alive:
			saucer.fall += delta
			saucer.pos += Vector2(saucer.dir * 120.0, 900.0 * saucer.fall) * delta
			continue
		if abductor == i:
			continue
		if is_resolved:
			continue
		saucer.pos.x += saucer.dir * saucer.speed * delta
		if saucer.pos.x < 90 or saucer.pos.x > SCREEN.x - 90:
			saucer.dir = -saucer.dir
			saucer.pos.x = clampf(saucer.pos.x, 90, SCREEN.x - 90)
		saucer.pos.y += saucer.drop * delta
		if saucer.pos.y >= ABDUCT_Y:
			_abduct(i)
	if target >= 0:
		buildings[target].lift = minf(buildings[target].lift + 600.0 * delta, 260.0)
	queue_redraw()


func _fire() -> void:
	if ammo <= 0 or cooldown > 0.0:
		return
	ammo -= 1
	cooldown = COOLDOWN
	shots.append(Vector2(robot_x + GUN, ROBOT_Y - 70))
	Sfx.play("zap", 0.7, randf_range(1.1, 1.3))


func _hits(shot: Vector2, at: Vector2) -> bool:
	return absf(shot.x - at.x) < SAUCER_HALF.x + 6 and absf(shot.y - at.y) < SAUCER_HALF.y + 18


func _down(saucer: Dictionary) -> void:
	saucer.alive = false
	Sfx.play("boom", 0.8)
	burst(saucer.pos, theme.accent, 22, 520, 12)
	burst(saucer.pos, Color("9ef01a"), 8, 300, 8)
	popup("ZAP!", saucer.pos + Vector2(0, -60), Color.WHITE, 56)
	shake(12)
	if saucers.all(func(s: Dictionary) -> bool: return not s.alive):
		win()


func _abduct(index: int) -> void:
	abductor = index
	var x: float = saucers[index].pos.x
	var best := 0
	for i in buildings.size():
		if absf(buildings[i].x - x) < absf(buildings[best].x - x):
			best = i
	target = best
	saucers[index].pos.x = buildings[best].x
	Sfx.play("spring", 0.8, 0.6)
	burst(Vector2(buildings[best].x, 800), theme.glow, 14, 300, 8)
	lose()


func _draw() -> void:
	var wall: Color = theme.sky
	draw_rect(Rect2(Vector2.ZERO, SCREEN), wall)
	# Wallpaper stripes so it reads as a room, not the sky.
	for i in 10:
		draw_rect(Rect2(i * 80.0, 0, 40, TABLE_Y), Color(1, 1, 1, 0.03))

	# Cardboard mountains behind the city.
	var card := Color("c9a46a").lerp(theme.accent, 0.12)
	var mountain := Color("8fa3b8").lerp(theme.sky_low, 0.4)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 930), Vector2(0, 720), Vector2(110, 640), Vector2(220, 730), Vector2(330, 610),
		Vector2(470, 720), Vector2(580, 650), Vector2(720, 740), Vector2(720, 930),
	]), mountain)
	draw_polyline(PackedVector2Array([Vector2(80, 662), Vector2(110, 640), Vector2(140, 662)]), Color.WHITE, 6)
	draw_polyline(PackedVector2Array([Vector2(296, 636), Vector2(330, 610), Vector2(364, 636)]), Color.WHITE, 6)

	# Tractor beam behind the buildings.
	for saucer in saucers:
		var p: Vector2 = saucer.pos
		if saucer.alive and abductor < 0 and p.y > ABDUCT_Y - 90 and anim_frame(12, 2) == 0:
			# The beam sputters on as it gets close: a warning.
			draw_colored_polygon(PackedVector2Array([p + Vector2(-24, 10), p + Vector2(24, 10), Vector2(p.x + 60, 930), Vector2(p.x - 60, 930)]), Color(theme.glow, 0.15))
	if abductor >= 0:
		var s: Vector2 = saucers[abductor].pos
		draw_colored_polygon(PackedVector2Array([s + Vector2(-30, 10), s + Vector2(30, 10), Vector2(s.x + 90, 930), Vector2(s.x - 90, 930)]), Color(theme.glow, 0.35))

	for b in buildings:
		_draw_building(b, card)

	# The table top and its front edge.
	var table: Color = Color("8b5a2b").lerp(theme.ground, 0.35)
	draw_rect(Rect2(0, 930, SCREEN.x, TABLE_Y - 930), table.lightened(0.2))
	draw_rect(Rect2(0, TABLE_Y, SCREEN.x, SCREEN.y - TABLE_Y), table)
	draw_rect(Rect2(0, TABLE_Y, SCREEN.x, 10), table.darkened(0.3))

	for saucer in saucers:
		if saucer.pos.y < SCREEN.y + 100:
			_draw_saucer(saucer.pos, saucer.alive, saucer.fall)

	# Aim guide straight up from the robot.
	if is_playing() and ammo > 0:
		var y := ROBOT_Y - 90
		while y > 120:
			draw_line(Vector2(robot_x + GUN, y), Vector2(robot_x + GUN, y - 14), Color(1, 1, 1, 0.25), 4)
			y -= 34
	for shot in shots:
		draw_rect(Rect2(shot.x - 6, shot.y - 22, 12, 44), Color("fff3b0"))
		draw_rect(Rect2(shot.x - 3, shot.y - 30, 6, 60), Color(theme.glow, 0.6))

	_draw_robot()
	# Shots left, as little bolts under the robot's track.
	for i in ammo:
		var at := Vector2(360 - (ammo - 1) * 26 + i * 52, 1010)
		draw_rect(Rect2(at.x - 8, at.y - 18, 16, 36), Color("fff3b0"))
		draw_rect(Rect2(at.x - 8, at.y - 18, 16, 36), Color.BLACK, false, 3)

	if is_resolved and won:
		draw_text_centered("DENVER SAVED!", Vector2(360, 130), 60, theme.glow)
	elif is_resolved:
		draw_text_centered("OUT OF SHOTS!" if out_of_ammo else "ABDUCTED!", Vector2(360, 130), 60, Color("ef476f"))


func _draw_building(b: Dictionary, card: Color) -> void:
	var x: float = b.x
	var w: float = b.w
	var h: float = b.h
	var base: float = 930.0 - b.lift
	var rect := Rect2(x - w / 2, base - h, w, h)
	var side := card.darkened(0.25)
	draw_rect(Rect2(rect.position + Vector2(6, 6), rect.size), side)
	match int(b.kind):
		1:  # Arched top, like the "cash register" tower.
			draw_colored_polygon(ellipse_points(Vector2(x, rect.position.y), Vector2(w / 2, 30), PI, TAU, 12), card)
		2:  # Clock spire.
			draw_colored_polygon(PackedVector2Array([rect.position, Vector2(x, rect.position.y - 60), Vector2(rect.end.x, rect.position.y)]), card)
	draw_rect(rect, card)
	# Marker-drawn windows.
	var ink := card.darkened(0.45)
	var rows := int(h / 34)
	for r in rows:
		for c in 2:
			draw_rect(Rect2(rect.position.x + 12 + c * (w - 36) / 1.0, rect.position.y + 16 + r * 34, 12, 16), ink)
	if int(b.kind) == 2:
		draw_circle(Vector2(x, rect.position.y + 8), 10, Color("fdf0d5"))
		draw_arc(Vector2(x, rect.position.y + 8), 10, 0, TAU, 12, ink, 3)


func _draw_saucer(at: Vector2, alive: bool, fall: float) -> void:
	draw_set_transform(at, fall * 8.0, Vector2.ONE)
	# Glass dome with a little alien inside.
	draw_circle(Vector2(0, -14), 30, Color(0.7, 0.95, 1.0, 0.55))
	draw_circle(Vector2(0, -16), 14, Color("9ef01a"))
	draw_circle(Vector2(-5, -18), 4, Color.BLACK)
	draw_circle(Vector2(5, -18), 4, Color.BLACK)
	draw_line(Vector2(-6, -30), Vector2(-12, -42), Color("9ef01a"), 3)
	draw_line(Vector2(6, -30), Vector2(12, -42), Color("9ef01a"), 3)
	var hull := Color("adb5bd") if alive else Color("495057")
	draw_colored_polygon(ellipse_points(Vector2.ZERO, Vector2(SAUCER_HALF.x, 20)), hull)
	draw_colored_polygon(ellipse_points(Vector2(0, -4), Vector2(SAUCER_HALF.x - 8, 9)), hull.lightened(0.25))
	for i in 5:
		var on := alive and anim_frame(10, 5) == i
		draw_circle(Vector2(-44 + i * 22, 6), 6, theme.accent if on else Color(theme.accent).darkened(0.5))
	draw_set_transform(Vector2.ZERO)


func _draw_robot() -> void:
	var tin := Color("ced4da")
	var at := Vector2.ZERO
	draw_set_transform(Vector2(robot_x, ROBOT_Y), 0.0, Vector2(1.3, 1.3))
	var wobble := sin(robot_x * 0.08) * 3.0
	# Wheels, boxy body with a dial, head with eyes and antenna.
	draw_circle(at + Vector2(-26, 44), 14, Color("343a40"))
	draw_circle(at + Vector2(26, 44), 14, Color("343a40"))
	draw_rect(Rect2(at + Vector2(-42, -20), Vector2(84, 62)), tin)
	draw_rect(Rect2(at + Vector2(-42, -20), Vector2(84, 62)), tin.darkened(0.4), false, 4)
	draw_circle(at + Vector2(0, 10), 13, theme.accent)
	draw_rect(Rect2(at + Vector2(-28, -64 + wobble), Vector2(56, 44)), tin)
	draw_rect(Rect2(at + Vector2(-28, -64 + wobble), Vector2(56, 44)), tin.darkened(0.4), false, 4)
	var lost := is_resolved and not won
	for side in [-1.0, 1.0]:
		var e := at + Vector2(side * 12, -44 + wobble)
		if lost:
			draw_line(e - Vector2(6, 6), e + Vector2(6, 6), Color.BLACK, 4)
			draw_line(e + Vector2(-6, 6), e + Vector2(6, -6), Color.BLACK, 4)
		else:
			draw_circle(e, 7, Color("ffd166") if cooldown > 0.0 else Color.BLACK)
	draw_line(at + Vector2(0, -64 + wobble), at + Vector2(0, -84 + wobble), tin.darkened(0.4), 4)
	draw_circle(at + Vector2(0, -88 + wobble), 7, Color("ef476f"))
	# Blaster arm pointing up.
	draw_rect(Rect2(at + Vector2(38, -46), Vector2(14, 44)), tin.darkened(0.2))
	draw_rect(Rect2(at + Vector2(36, -54), Vector2(18, 10)), Color("343a40"))
	if cooldown > 0.08:
		draw_circle(at + Vector2(45, -62), 12, Color("fff3b0"))
	draw_set_transform(Vector2.ZERO)
