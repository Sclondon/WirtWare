extends Microgame
## SLIDE! Belly-slide a penguin down the slope through every gate.
## A homage to Penguin Slide. Rocks sit beside the line on harder levels.

const PENGUIN_Y := 330.0
const STEER_SPEED := 820.0
const STEER_ACCEL := 5200.0
const BODY_RADIUS := 26.0
const ROCK_RADIUS := 40.0
const FISH_RADIUS := 64.0
var penguin_x := 360.0
var velocity_x := 0.0
var speed := 600.0
var gate_gap := 300.0
## Each gate: {x, y, passed}. Gates scroll up the screen as the penguin slides down.
var gates: Array[Dictionary] = []
var rocks: Array[Vector2] = []
var fish := Vector2(-999, -999)
var fish_taken := false
var trail: Array[Vector2] = []
var crashed_gate := -1
var spin := 0.0
var scrolled := 0.0
var theme: Dictionary


func _init() -> void:
	prompt = "SLIDE!"
	controls_hint = "ARROW KEYS"
	touch_hint = "STEER LEFT AND RIGHT"
	controls = Controls.LEFT_RIGHT
	duration = 4.5


func _on_start() -> void:
	theme = Stages.LOOKS.penguin
	speed = 480.0 + 80.0 * difficulty
	gate_gap = [300.0, 250.0, 215.0][difficulty - 1]
	var interval: float = [0.85, 0.75, 0.68][difficulty - 1]
	var max_shift: float = [200.0, 260.0, 300.0][difficulty - 1]
	# Keep both poles clear of the tree lines.
	var lo := gate_gap / 2.0 + 90.0
	var hi := SCREEN.x - lo
	var x := randf_range(lo + 40, hi - 40)
	var y := PENGUIN_Y + speed * 1.25
	for i in 2 + difficulty:
		gates.append({"x": x, "y": y, "passed": false})
		var shift := randf_range(110, max_shift) * (1.0 if randf() < 0.5 else -1.0)
		if x + shift < lo or x + shift > hi:
			shift = -shift
		x = clampf(x + shift, lo, hi)
		y += speed * interval
	# The fish sits on the line between the first two gates; rocks sit beside the line.
	fish = (Vector2(gates[0].x, gates[0].y) + Vector2(gates[1].x, gates[1].y)) / 2.0
	if difficulty >= 2:
		var first := 1 if difficulty == 2 else 0
		for i in range(first, gates.size() - 1):
			# Outside both gates, where only an overshoot would hit it.
			var low := minf(gates[i].x, gates[i + 1].x) - 150
			var high := maxf(gates[i].x, gates[i + 1].x) + 150
			var rock_y: float = (gates[i].y + gates[i + 1].y) / 2.0
			if low >= 90 and (high > 630 or randf() < 0.5):
				rocks.append(Vector2(low, rock_y))
			elif high <= 630:
				rocks.append(Vector2(high, rock_y))


func _process(delta: float) -> void:
	var crashed := is_resolved and not won
	if crashed:
		spin += delta * 14.0
		speed = move_toward(speed, 0.0, delta * 1600.0)
		velocity_x = move_toward(velocity_x, 0.0, delta * 2000.0)
	else:
		var steer := Input.get_axis("left", "right") if is_playing() else 0.0
		velocity_x = move_toward(velocity_x, steer * STEER_SPEED, STEER_ACCEL * delta)
		if steer != 0.0 and absf(velocity_x) > 500 and randf() < 0.4:
			burst(Vector2(penguin_x, PENGUIN_Y - 30), Color(1, 1, 1, 0.8), 2, 160, 7)
	penguin_x = clampf(penguin_x + velocity_x * delta, 60, 660)

	var scroll := speed * delta
	scrolled += scroll
	for gate in gates:
		var before: float = gate.y
		gate.y -= scroll
		if is_playing() and not gate.passed and before > PENGUIN_Y and gate.y <= PENGUIN_Y:
			_check_gate(gate)
	for i in rocks.size():
		rocks[i].y -= scroll
		if is_playing() and rocks[i].distance_to(Vector2(penguin_x, PENGUIN_Y)) < ROCK_RADIUS + BODY_RADIUS:
			_crash(rocks[i])
	fish.y -= scroll
	if is_playing() and not fish_taken and fish.distance_to(Vector2(penguin_x, PENGUIN_Y)) < FISH_RADIUS:
		fish_taken = true
		Sfx.play("coin")
		burst(fish, theme.glow, 14, 380, 9)
		popup("FISH!", fish + Vector2(0, -40), theme.glow, 56)

	for i in trail.size():
		trail[i].y -= scroll
	trail.append(Vector2(penguin_x, PENGUIN_Y - 40))
	if trail.size() > 40:
		trail.pop_front()
	queue_redraw()


func _check_gate(gate: Dictionary) -> void:
	if absf(penguin_x - gate.x) > gate_gap / 2.0:
		crashed_gate = gates.find(gate)
		var pole_side := signf(penguin_x - gate.x)
		_crash(Vector2(gate.x + pole_side * gate_gap / 2.0, PENGUIN_Y))
		return
	gate.passed = true
	var count := gates.filter(func(g: Dictionary) -> bool: return g.passed).size()
	Sfx.play("swish", 1.0, 0.9 + 0.12 * count)
	burst(Vector2(gate.x, PENGUIN_Y), theme.accent, 10, 360, 8)
	if count == gates.size():
		popup("SWOOSH!", Vector2(penguin_x, PENGUIN_Y + 140), theme.glow, 72)
		burst(Vector2(penguin_x, PENGUIN_Y), Color.WHITE, 24, 520, 10)
		win()


func _crash(at: Vector2) -> void:
	Sfx.play("crunch")
	Sfx.play("thud")
	burst(at, Color.WHITE, 22, 480, 12)
	shake(14)
	popup("WIPEOUT!", Vector2(penguin_x, PENGUIN_Y + 150), Color("ff5d73"), 64)
	lose()


func _draw() -> void:
	# Snow, with a hint of sky in it.
	var snow := Color("eef4ff").lerp(theme.sky_low, 0.18)
	draw_rect(Rect2(Vector2.ZERO, SCREEN), snow)
	for i in 10:
		var y := fposmod(i * 160.0 - scrolled, 1600.0) - 80
		draw_line(Vector2(90, y), Vector2(130, y + 30), snow.darkened(0.07), 4)
		draw_line(Vector2(560, y + 80), Vector2(610, y + 110), snow.darkened(0.07), 4)
	for i in 12:
		var y := fposmod(i * 130.0 - scrolled, 1560.0) - 60
		for x: float in [26.0, 694.0]:
			_draw_tree(Vector2(x + (14.0 if i % 2 else -10.0), y))

	# Trail of slid snow behind the penguin.
	if trail.size() > 1:
		draw_polyline(PackedVector2Array(trail), snow.darkened(0.12), 30)

	if not fish_taken:
		_draw_fish(fish)
	for r in rocks:
		_draw_rock(r)

	for i in gates.size():
		var gate := gates[i]
		var color: Color = theme.accent if not gate.passed else Color(theme.glow, 0.5)
		for side in [-1.0, 1.0]:
			var pole := Vector2(gate.x + side * gate_gap / 2.0, gate.y)
			var knocked: bool = i == crashed_gate and signf(penguin_x - gate.x) == side
			var lean: float = 1.1 * side if knocked else 0.0
			var top := pole + Vector2(0, -70).rotated(lean)
			draw_line(pole, top, Color("3b3b3b"), 7)
			var flag := PackedVector2Array([top, top + Vector2(-side * 46, 16).rotated(lean), top + Vector2(0, 32).rotated(lean)])
			draw_colored_polygon(flag, color)
			flag.append(top)
			draw_polyline(flag, color.darkened(0.5), 3)
			draw_circle(pole, 7, Color("3b3b3b"))
		if not gate.passed and gate.y > PENGUIN_Y:
			draw_line(Vector2(gate.x - gate_gap / 2 + 14, gate.y), Vector2(gate.x + gate_gap / 2 - 14, gate.y), Color(theme.accent, 0.35), 4)

	_draw_penguin()


func _draw_tree(base: Vector2) -> void:
	var green: Color = theme.ground.lightened(0.1)
	draw_colored_polygon(PackedVector2Array([base + Vector2(-38, 30), base + Vector2(0, -70), base + Vector2(38, 30)]), green)
	draw_colored_polygon(PackedVector2Array([base + Vector2(-18, -30), base + Vector2(0, -70), base + Vector2(18, -30)]), Color.WHITE)


func _draw_fish(at: Vector2) -> void:
	var bob := sin(_clock * 8.0) * 6.0
	var p := at + Vector2(0, bob)
	draw_circle(p, 46, Color(theme.glow, 0.3))
	draw_colored_polygon(ellipse_points(p, Vector2(30, 16)), Color("5fb7ff"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(24, 0), p + Vector2(46, -16), p + Vector2(46, 16)]), Color("3d8fd9"))
	draw_circle(p + Vector2(-16, -4), 4, Color.BLACK)


func _draw_penguin() -> void:
	var crashed := is_resolved and not won
	var lean := -velocity_x / STEER_SPEED * 0.35 + (spin if crashed else 0.0)
	draw_set_transform(Vector2(penguin_x, PENGUIN_Y), lean)
	var black := Color("1d1d2b")
	var flap := sin(_clock * 20.0) * 0.25
	for side in [-1.0, 1.0]:
		var root := Vector2(side * 30, -6)
		var tip := root + Vector2(side * 34, 26).rotated(flap * side)
		draw_line(root, tip, black, 16)
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -54), Vector2(-26, -72), Vector2(-4, -60)]), Color("ff9f1c"))
	draw_colored_polygon(PackedVector2Array([Vector2(14, -54), Vector2(26, -72), Vector2(4, -60)]), Color("ff9f1c"))
	draw_colored_polygon(ellipse_points(Vector2(0, -6), Vector2(36, 54)), black)
	draw_colored_polygon(ellipse_points(Vector2(0, 0), Vector2(22, 38)), Color("fafafa"))
	draw_circle(Vector2(0, 40), 28, black)
	draw_colored_polygon(ellipse_points(Vector2(0, 44), Vector2(20, 16)), Color("fafafa"))
	draw_face(Vector2(0, 42), 30, not crashed)
	draw_colored_polygon(PackedVector2Array([Vector2(-9, 58), Vector2(9, 58), Vector2(0, 74)]), Color("ff9f1c"))
	draw_set_transform(Vector2.ZERO)


## A grey boulder with snow on top.
func _draw_rock(at: Vector2) -> void:
	draw_colored_polygon(ellipse_points(at + Vector2(0, 6), Vector2(46, 30)), Color("6e7b8a"))
	draw_colored_polygon(ellipse_points(at + Vector2(-8, 0), Vector2(30, 20)), Color("8a97a6"))
	draw_colored_polygon(ellipse_points(at + Vector2(-4, -16), Vector2(28, 10)), Color("f4f8ff"))
