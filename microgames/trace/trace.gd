extends Microgame
## TRACE! Drag down the wiggly path from start to finish without straying off
## it. You guide a ghost to the candy in the graveyard, roll a golden ball down
## a temple rail to the idol, and lead a will-o'-wisp to a frog in the swamp.

const SAMPLES := 96
const LOOKAHEAD := 12
const TOP := 200.0
const BOTTOM := 1120.0

var path := PackedVector2Array()
## How far from the centre line the pointer may be.
var width := 60.0
## Index of the furthest path point reached.
var progress := 0
var tracing := false
var strayed := false
var elapsed := 0.0
var last_tick := 0


func _init() -> void:
	prompt = "TRACE!"
	controls_hint = "DRAG ALONG THE PATH"
	touch_hint = "DRAG YOUR FINGER ALONG IT"
	controls = Controls.POINTER
	duration = 5.0


func _on_start() -> void:
	# The finger isn't sped up with the game, so the path gets fewer wiggles at speed.
	var waves := (1.0 + 0.6 * difficulty) / sqrt(Engine.time_scale)
	var amplitude := 130.0 + 25.0 * difficulty
	var phase := randf() * TAU
	for i in SAMPLES:
		var t := float(i) / (SAMPLES - 1)
		path.append(Vector2(SCREEN.x / 2 + sin(t * waves * TAU + phase) * amplitude, lerpf(TOP, BOTTOM, t)))
	width = touch_size([65.0, 54.0, 46.0][difficulty - 1], 22)


func _process(delta: float) -> void:
	elapsed += delta
	update_pointer()
	if is_playing():
		if pointer_pressed and pointer.distance_to(path[progress]) < width * 1.5:
			if not tracing:
				Sfx.play("tap")
			tracing = true
		elif not pointer_down:
			tracing = false  # Lifting pauses; press again where you left off.
		if tracing:
			for i in range(progress + 1, mini(progress + LOOKAHEAD, SAMPLES)):
				if pointer.distance_to(path[i]) < width:
					progress = i
			if progress >= last_tick + 8:
				last_tick = progress
				Sfx.play("beep", 0.35, 0.8 + progress / float(SAMPLES))
			if _distance_to_path() > width * 1.25:
				strayed = true
				Sfx.play("thud")
				burst(pointer, Color("ef476f"), 14, 360.0, 10.0)
				lose()
			elif progress == SAMPLES - 1:
				var goal := path[SAMPLES - 1]
				Sfx.play("coin")
				burst(goal, Stages.theme(stage).glow, 26, 520.0, 12.0)
				win()
	queue_redraw()


## Distance from the pointer to the path near where the player is.
func _distance_to_path() -> float:
	var best := INF
	for i in range(maxi(progress - 2, 0), mini(progress + LOOKAHEAD, SAMPLES - 1)):
		var closest := Geometry2D.get_closest_point_to_segment(pointer, path[i], path[i + 1])
		best = minf(best, pointer.distance_to(closest))
	return best


func _draw() -> void:
	var theme := Stages.theme(stage)
	_draw_scenery(theme)
	var glow: Color = theme.glow
	var accent: Color = theme.accent

	# The track: a band as wide as the safe zone, an edge, and a centre line.
	var band: Color = [Color("6b5a80"), Color("8a7d62"), Color("3c5a32")][posmod(stage, 3)]
	for p in path:
		draw_circle(p, width + 6, band.darkened(0.45))
	for p in path:
		draw_circle(p, width, band)
	if stage == Stages.TEMPLE:
		# A golden rail with gems set along it.
		draw_polyline(path, Color("5a4520"), 14, true)
		draw_polyline(path, Color("f2c14e"), 8, true)
		for i in range(6, SAMPLES - 6, 14):
			draw_sprite("temple/t_rail_gem", 4, anim_frame(6, 4, i * 0.1), path[i], 3.0)
	else:
		for i in range(0, SAMPLES, 3):
			draw_circle(path[i], 5, Color(1, 1, 1, 0.45))
	if progress > 0:
		draw_polyline(path.slice(0, progress + 1), Color(glow, 0.9), 16, true)

	var start := path[0]
	draw_circle(start, width * 0.8, accent)
	draw_text_centered("GO", start, 30)
	var goal := path[SAMPLES - 1]
	draw_circle(goal, width + 14, Color(glow, 0.35 + 0.15 * sin(elapsed * 8.0)))
	var cheer := -absf(sin(elapsed * 14.0)) * 24.0 if is_resolved and won else 0.0
	match stage:
		Stages.TEMPLE:
			draw_texture_rect_region(art("temple/t_idol"), Rect2(goal + Vector2(-66, -120 + cheer), Vector2(132, 132)), Rect2(0, 44, 22, 22))
		Stages.SWAMP:
			draw_sprite("swamp/h_frog", 1, 0, goal + Vector2(0, -30 + cheer), 7.0)
		_:
			draw_sprite("graveyard/candybasket", 1, 0, goal + Vector2(0, -30 + cheer), 4.0)

	# The traveller rides your finger (or waits at the start).
	var rider := pointer if tracing and not is_resolved else path[progress]
	if strayed:
		rider = pointer
	var tint := Color(1, 0.5, 0.5) if strayed else Color.WHITE
	match stage:
		Stages.TEMPLE:
			draw_sprite("temple/golden_Ball", 16, anim_frame(24, 16), rider, 4.0, false, tint)
		Stages.SWAMP:
			draw_sprite("swamp/willOWisp", 6, anim_frame(10, 6), rider, 3.0, false, tint)
		_:
			draw_sprite("graveyard/ghost", 6, anim_frame(8, 6), rider + Vector2(0, -40), 4.0, false, tint)

	if strayed:
		draw_text_centered("OFF THE PATH!", Vector2(360, 120), 64, Color("ef476f"))
	elif is_resolved and won:
		draw_text_centered("NAILED IT!", Vector2(360, 120), 64, glow)


## The stage's sky and a few props in the margins.
func _draw_scenery(theme: Dictionary) -> void:
	var top: Color = theme.sky
	var low: Color = theme.sky_low
	for i in 16:
		draw_rect(Rect2(0, SCREEN.y * i / 16.0, SCREEN.x, SCREEN.y / 16.0 + 1), top.lerp(low, i / 15.0))
	match stage:
		Stages.GRAVEYARD:
			for p: Vector2 in [Vector2(60, 420), Vector2(660, 700), Vector2(60, 960)]:
				draw_sprite("graveyard/grave_1_small", 1, 0, p, 3.0, false, Color(0.6, 0.55, 0.7))
		Stages.TEMPLE:
			for y in range(0, 1280, 160):
				draw_rect(Rect2(0, y, 50, 150), Color("41503f"))
				draw_rect(Rect2(670, y + 80, 50, 150), Color("41503f"))
		Stages.SWAMP:
			for i in 6:
				var y := 160.0 + i * 200.0
				draw_rect(Rect2(-60 + sin(elapsed * 0.6 + i) * 60.0, y, 840, 40), Color(0.7, 0.95, 0.6, 0.06))
