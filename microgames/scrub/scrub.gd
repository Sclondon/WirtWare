extends Microgame
## SCRUB! Hold the mouse button (or your finger) down and scrub until it's clean.
## Graveyard: mud off a headstone. Temple: moss off Tlaloc's stone face.
## Swamp: goo off a frog.

const PLATE_CENTER := Vector2(360, 640)
const SPONGE_REACH := 75.0
## How far from the centre dirt can land, per stage.
const SPREAD: Array[float] = [210.0, 220.0, 180.0]
const DIRT: Array[Color] = [Color("5a3d22"), Color("6fbf3a"), Color("c05ce8")]
const DIRT_DARK: Array[Color] = [Color("3b2614"), Color("3d7a28"), Color("7a2fb0")]

class Blob:
	var pos: Vector2
	var radius: float
	var dirt := 1.0
	var clean := false

var blobs: Array[Blob] = []
var scrub_needed := 240.0
var last_pointer := Vector2.ZERO
var end_time := 0.0


func _init() -> void:
	prompt = "SCRUB!"
	controls_hint = "HOLD CLICK + SCRUB"
	touch_hint = "RUB WITH YOUR FINGER"
	controls = Controls.POINTER
	duration = 4.0


func _on_start() -> void:
	# Pointer movement isn't time-scaled, so need less scrubbing at high speed.
	scrub_needed = 240.0 / sqrt(Engine.time_scale)
	for i in 3 + 2 * difficulty:
		var blob := Blob.new()
		blob.radius = randf_range(30, 52)
		blob.pos = PLATE_CENTER + Vector2.from_angle(randf() * TAU) * sqrt(randf()) * SPREAD[stage]
		blobs.append(blob)


func _process(delta: float) -> void:
	update_pointer()
	if is_resolved:
		end_time += delta
	if is_playing() and pointer_down:
		# A new press (or a finger landing) shouldn't count the jump from the last spot.
		var moved := 0.0 if pointer_pressed else pointer.distance_to(last_pointer)
		var rubbing := false
		for blob in blobs:
			if blob.dirt > 0.0 and blob.pos.distance_to(pointer) < SPONGE_REACH + blob.radius * 0.5:
				blob.dirt = maxf(blob.dirt - moved / scrub_needed, 0.0)
				rubbing = rubbing or moved > 2.0
		if rubbing:
			Sfx.play("squish", 0.35, 1.3, 140)
	for blob in blobs:
		if blob.dirt <= 0.0 and not blob.clean:
			blob.clean = true
			burst(blob.pos, Color.WHITE, 10, 300.0, 8.0)
			Sfx.play("pop", 0.6, 1.4)
	if is_playing() and blobs.all(func(b: Blob) -> bool: return b.dirt <= 0.0):
		win()
	last_pointer = pointer
	queue_redraw()


func _on_resolved(result: bool) -> void:
	if result:
		popup("SPARKLING!", PLATE_CENTER + Vector2(0, -380), Stages.theme(stage).glow, 64)
		burst(PLATE_CENTER, Color.WHITE, 24, 600.0, 10.0)
	else:
		popup(["STILL DIRTY...", "TLALOC IS ANGRY!", "STILL SLIMY..."][stage], PLATE_CENTER + Vector2(0, -380), Color("ef476f"), 48)
		if stage == Stages.TEMPLE:
			Sfx.play("boom", 0.6)
			shake(10.0)


func _draw() -> void:
	var theme := Stages.theme(stage)
	for i in 16:
		draw_rect(Rect2(0, SCREEN.y * i / 16.0, SCREEN.x, SCREEN.y / 16.0 + 1), (theme.sky as Color).lerp(theme.sky_low, i / 15.0))
	draw_rect(Rect2(0, 1040, SCREEN.x, SCREEN.y - 1040), theme.ground)
	draw_rect(Rect2(0, 1040, SCREEN.x, 12), (theme.ground as Color).lightened(0.3))

	var lost := is_resolved and not won
	match stage:
		Stages.GRAVEYARD:
			_draw_headstone()
			if lost:
				# A grumpy ghost drifts up out of the grave.
				var rise := minf(end_time * 260.0, 300.0)
				draw_sprite("graveyard/ghost", 6, anim_frame(8, 6), PLATE_CENTER + Vector2(170, 120 - rise), 6.0)
		Stages.TEMPLE:
			draw_circle(PLATE_CENTER, 300, Color(theme.glow, 0.12))
			draw_sprite("temple/tlaloc", 2, 1 if lost else 0, PLATE_CENTER, 9.0)
		_:
			draw_circle(PLATE_CENTER + Vector2(0, 30), 270, Color(theme.glow, 0.1))
			var tint := Color(0.75, 1.0, 0.5) if lost else Color.WHITE
			draw_sprite("swamp/h_frog", 1, 0, PLATE_CENTER + Vector2(0, -20), 32.0, false, tint)

	for blob in blobs:
		if blob.dirt > 0.0:
			var a := blob.dirt
			draw_circle(blob.pos, blob.radius, Color(DIRT[stage], a))
			draw_circle(blob.pos + Vector2(blob.radius * 0.6, blob.radius * 0.3), blob.radius * 0.55, Color(DIRT_DARK[stage], a))
			draw_circle(blob.pos + Vector2(-blob.radius * 0.5, -blob.radius * 0.4), blob.radius * 0.4, Color(DIRT[stage].darkened(0.2), a))
	if is_resolved and won:
		for i in 6:
			var p := PLATE_CENTER + Vector2.from_angle(TAU * i / 6.0 + 0.3) * 300.0
			var s := 22.0 + 6.0 * sin(_clock * 12.0 + i)
			draw_line(p - Vector2(s, 0), p + Vector2(s, 0), Color.WHITE, 6)
			draw_line(p - Vector2(0, s), p + Vector2(0, s), Color.WHITE, 6)

	if not is_resolved:
		if pointer_down:
			for i in 5:
				draw_circle(pointer + Vector2(randf_range(-70, 70), randf_range(-50, 50)), randf_range(6, 14), Color(1, 1, 1, 0.8))
		draw_rect(Rect2(pointer - Vector2(50, 30), Vector2(100, 60)), Color("ffd60a"))
		draw_rect(Rect2(pointer - Vector2(50, 30), Vector2(100, 18)), Color("52b788"))


func _draw_headstone() -> void:
	var stone := Color("8d87a0")
	var top := PLATE_CENTER + Vector2(0, -150)
	draw_rect(Rect2(PLATE_CENTER.x - 250, PLATE_CENTER.y + 330, 500, 70), Color("5c4433"))
	draw_circle(top, 240, stone)
	draw_rect(Rect2(PLATE_CENTER.x - 240, top.y, 480, 490), stone)
	draw_arc(top, 205, PI, TAU, 32, stone.darkened(0.15), 8)
	draw_text_centered("R.I.P.", top + Vector2(0, 40), 110, stone.darkened(0.35))
	draw_rect(Rect2(PLATE_CENTER.x - 120, PLATE_CENTER.y + 60, 240, 10), stone.darkened(0.25))
	draw_rect(Rect2(PLATE_CENTER.x - 90, PLATE_CENTER.y + 120, 180, 10), stone.darkened(0.25))
