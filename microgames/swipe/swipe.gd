extends Microgame
## SWIPE! Swipe the way each arrow points. Red arrows mean the opposite way.
## Arrow keys work too, for desktop players. Each right swipe flings the
## stage's critter (a ghost, a golden ball, a will-o'-wisp) off that way.

const DIRECTIONS := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}
const OPPOSITE := {"up": "down", "down": "up", "left": "right", "right": "left"}
const ARROW_CENTER := Vector2(360, 640)
const CRITTER_POS := Vector2(360, 1090)

class Flung:
	var pos: Vector2
	var vel: Vector2
	var spin: float

var sequence: Array[String] = []
var flipped: Array[bool] = []
var progress := 0
var swipe_start := Vector2.ZERO
var swipe_used := false
var pop := 0.0
var elapsed := 0.0
var flung: Array[Flung] = []
## The next critter grows in after one is flung.
var critter_grow := 1.0


func _init() -> void:
	prompt = "SWIPE!"
	controls_hint = "SWIPE THE MOUSE OR USE ARROWS"
	touch_hint = "SWIPE THE WAY IT POINTS"
	controls = Controls.POINTER
	duration = 4.5


func _on_start() -> void:
	for i in 2 + difficulty:
		sequence.append(DIRECTIONS.keys().pick_random())
		flipped.append(difficulty >= 2 and randf() < 0.35)


func _process(delta: float) -> void:
	elapsed += delta
	update_pointer()
	pop = maxf(pop - delta * 5.0, 0.0)
	critter_grow = minf(critter_grow + delta * 5.0, 1.0)
	if is_playing():
		if pointer_pressed:
			swipe_start = pointer
			swipe_used = false
		if pointer_down and not swipe_used:
			var drag := pointer - swipe_start
			if drag.length() > touch_size(110, 35):
				swipe_used = true
				_answer(_direction_of(drag))
		for dir: String in DIRECTIONS:
			if is_playing() and Input.is_action_just_pressed(dir):
				_answer(dir)
	for f in flung:
		f.pos += f.vel * delta
	flung = flung.filter(func(f: Flung) -> bool: return Rect2(-200, -200, 1120, 1680).has_point(f.pos))
	queue_redraw()


func _direction_of(v: Vector2) -> String:
	if absf(v.x) > absf(v.y):
		return "right" if v.x > 0 else "left"
	return "down" if v.y > 0 else "up"


func _answer(dir: String) -> void:
	var want: String = OPPOSITE[sequence[progress]] if flipped[progress] else sequence[progress]
	if dir != want:
		Sfx.play("thud")
		shake(8)
		burst(CRITTER_POS, Color("ef476f"), 12, 360.0, 10.0)
		lose()
		return
	Sfx.play("swish", 1.0, 1.0 + 0.12 * progress)
	var f := Flung.new()
	f.pos = CRITTER_POS
	f.vel = DIRECTIONS[dir] * 2600.0
	f.spin = 12.0 if dir != "left" else -12.0
	flung.append(f)
	critter_grow = 0.0
	burst(CRITTER_POS, Stages.theme(stage).glow, 10, 420.0, 9.0)
	progress += 1
	pop = 1.0
	if progress == sequence.size():
		win()


func _draw_critter(pos: Vector2, size: float, spin: float, tint := Color.WHITE) -> void:
	match stage:
		Stages.TEMPLE:
			draw_sprite("temple/golden_Ball", 16, anim_frame(16, 16), pos, 7.0 * size, false, tint, spin)
		Stages.SWAMP:
			draw_sprite("swamp/willOWisp", 6, anim_frame(10, 6), pos, 5.0 * size, false, tint, spin)
		_:
			draw_sprite("graveyard/ghost", 6, anim_frame(8, 6), pos, 5.0 * size, false, tint, spin)


func _draw() -> void:
	var theme := Stages.theme(stage)
	var top: Color = theme.sky
	var low: Color = theme.sky_low
	for i in 16:
		draw_rect(Rect2(0, SCREEN.y * i / 16.0, SCREEN.x, SCREEN.y / 16.0 + 1), top.lerp(low, i / 15.0))
	var glow: Color = theme.glow
	var lost := is_resolved and not won

	# Ring of light the arrows sit in, with stage trim.
	draw_circle(ARROW_CENTER, 240, Color(glow, 0.10))
	draw_arc(ARROW_CENTER, 240, 0, TAU, 64, Color(theme.accent, 0.5), 8)
	if stage == Stages.TEMPLE:
		for i in 8:
			var p := ARROW_CENTER + Vector2.from_angle(i * TAU / 8.0) * 240
			draw_texture_rect_region(art("temple/t_glyph_tile"), Rect2(p - Vector2(24, 24), Vector2(48, 48)), Rect2(0, 0, 8, 8))

	if progress < sequence.size():
		var red := flipped[progress]
		var size := 340.0 * (1.0 + pop * 0.15)
		draw_arrow(ARROW_CENTER + Vector2(0, 8), DIRECTIONS[sequence[progress]], size, Color(0, 0, 0, 0.4))
		draw_arrow(ARROW_CENTER, DIRECTIONS[sequence[progress]], size, Color("ef476f") if red else Color.WHITE)
		if red:
			draw_text_centered("OPPOSITE!", ARROW_CENTER + Vector2(0, 290), 54, Color("ef476f"))
		if lost:
			draw_text_centered("WRONG WAY!", Vector2(360, 310), 70, Color("ef476f"))
	else:
		draw_text_centered("PERFECT!", ARROW_CENTER, 110, glow)

	# The critter waits below for the next fling.
	if progress < sequence.size():
		var wobble := Vector2(sin(elapsed * 70.0) * 12.0, 0) if lost else Vector2(0, sin(elapsed * 4.0) * 10.0)
		_draw_critter(CRITTER_POS + wobble, ease(critter_grow, 0.5), 0.0, Color(1, 0.5, 0.5) if lost else Color.WHITE)
	for f in flung:
		_draw_critter(f.pos, 1.0, elapsed * f.spin)

	# The whole sequence along the top, finished ones in the stage glow.
	var count := sequence.size()
	for i in count:
		var center := Vector2(SCREEN.x / 2 + (i - (count - 1) / 2.0) * 100, 180)
		if lost and i == progress:
			continue
		var color := glow if i < progress else (Color("ef476f") if flipped[i] else Color(1, 1, 1, 0.6))
		draw_arrow(center, DIRECTIONS[sequence[i]], 70, color)

	if pointer_down and not swipe_used and is_playing():
		draw_line(swipe_start, pointer, Color(1, 1, 1, 0.5), 10)
