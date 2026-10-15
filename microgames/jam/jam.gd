extends Microgame
## JAM! Hit the button as each note crosses the line, and the one-man band plays it.
## A homage to One Man Band, the five-note loop station.

const HIT_X := 170.0
const STAFF_TOP := 300.0
const LINE_GAP := 50.0
const BAND_POS := Vector2(360, 820)
const FLOOR_Y := 990.0
## C D E G A, the five pads of the loop station, as semitones from C4.
const SCALE := [0, 2, 4, 7, 9]

static var _tones: Array[AudioStreamWAV] = []

## Each note: {t, pitch, state (0 waiting, 1 hit, 2 missed), when}.
var notes: Array[Dictionary] = []
var song_time := 0.0
var note_speed := 520.0
var window := 0.14
var misses := 0
var allowed := 2
var kick := 0.0
var player: AudioStreamPlayer
var theme: Dictionary
var colors: Array[Color] = []


func _init() -> void:
	prompt = "JAM!"
	controls_hint = "SPACE ON THE BEAT"
	touch_hint = "TAP ON THE BEAT"
	controls = Controls.BUTTON
	duration = 4.5


func _on_start() -> void:
	theme = Stages.theme(stage)
	colors = [theme.accent]
	for c: Color in theme.curtains:
		colors.append(c)
	allowed = 2 if difficulty == 1 else 1
	note_speed = 440.0 + 80.0 * difficulty
	# The window is in game time; widen it a little at speed-ups so it stays fair in real time.
	window = [0.14, 0.12, 0.1][difficulty - 1] * sqrt(Engine.time_scale)
	var beat: float = [0.62, 0.52, 0.44][difficulty - 1]
	var pitch := randi_range(1, 3)
	for i in 3 + difficulty:
		notes.append({"t": 1.3 + i * beat, "pitch": pitch, "state": 0, "when": 0.0})
		pitch = clampi(pitch + [-2, -1, 1, 2].pick_random(), 0, 4)
	player = AudioStreamPlayer.new()
	player.max_polyphony = 4
	player.volume_db = -8.0
	add_child(player)
	if _tones.is_empty():
		for semi: int in SCALE:
			_tones.append(_make_tone(261.63 * pow(2.0, semi / 12.0)))


func _process(delta: float) -> void:
	song_time += delta
	kick = move_toward(kick, 0.0, delta * 5.0)
	if is_playing():
		if Input.is_action_just_pressed("action"):
			_strum()
		for note in notes:
			if is_playing() and note.state == 0 and song_time > note.t + window:
				_miss(note)
		if is_playing() and notes.all(func(n: Dictionary) -> bool: return n.state != 0):
			popup("ENCORE!", Vector2(360, 600), theme.glow, 80)
			burst(BAND_POS + Vector2(0, -60), theme.accent, 26, 560, 12)
			win()
	queue_redraw()


func _strum() -> void:
	kick = 1.0
	Sfx.play("thud", 0.5)
	var best: Dictionary = {}
	var best_dt := 99.0
	for note in notes:
		var dt := absf(song_time - float(note.t))
		if note.state == 0 and dt < best_dt:
			best = note
			best_dt = dt
	if best.is_empty():
		return
	if best_dt <= window:
		best.state = 1
		best.when = song_time
		_play_note(best.pitch)
		var at := _note_pos(best)
		burst(at, colors[best.pitch], 14, 420, 10)
		popup("PERFECT!" if best_dt < window * 0.4 else "GOOD", at + Vector2(90, -70), Color.WHITE, 40)
	elif best_dt <= 0.3:
		# A swing near a note that misses the beat counts as missing it, so mashing doesn't work.
		_miss(best)


func _miss(note: Dictionary) -> void:
	note.state = 2
	note.when = song_time
	misses += 1
	Sfx.play("squish")
	popup("MISS", Vector2(HIT_X + 60, STAFF_TOP - 60), Color("ff5d73"), 48)
	if misses >= allowed:
		Sfx.play("crunch")
		burst(BAND_POS + Vector2(0, -20), Color("f3e9d2"), 20, 480, 12)
		shake(14)
		lose()


func _play_note(pitch: int) -> void:
	if Sfx.muted:
		return
	player.stream = _tones[pitch]
	player.play()


func _make_tone(freq: float) -> AudioStreamWAV:
	var rate := 22050
	var count := int(0.45 * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var t := float(i) / rate
		phase = fmod(phase + freq / rate, 1.0)
		var square := 1.0 if phase < 0.5 else -1.0
		var tri := 4.0 * absf(phase - 0.5) - 1.0
		var env := minf(t * 300.0, 1.0) * exp(-t * 7.0)
		data.encode_s16(i * 2, int((square * 0.18 + tri * 0.45) * env * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav


func _note_pos(note: Dictionary) -> Vector2:
	var y := STAFF_TOP + (4 - int(note.pitch)) * LINE_GAP
	if note.state == 0:
		return Vector2(HIT_X + (float(note.t) - song_time) * note_speed, y)
	var since := song_time - float(note.when)
	if note.state == 1:
		return Vector2(HIT_X, y - since * 500.0)
	return Vector2(HIT_X - since * note_speed * 0.5, y + since * since * 1800.0)


func _draw() -> void:
	for i in 16:
		draw_rect(Rect2(0, i * 80.0, SCREEN.x, 81), theme.sky.lerp(theme.sky_low, i / 15.0))
	# Spotlight and stage floor.
	draw_colored_polygon(PackedVector2Array([Vector2(300, 0), Vector2(420, 0), Vector2(600, FLOOR_Y), Vector2(120, FLOOR_Y)]), Color(theme.glow, 0.1))
	draw_rect(Rect2(0, FLOOR_Y, SCREEN.x, SCREEN.y - FLOOR_Y), theme.ground)
	draw_rect(Rect2(0, FLOOR_Y, SCREEN.x, 10), theme.ground.lightened(0.25))

	# The staff, the hit line, and how many misses are left.
	draw_rect(Rect2(30, STAFF_TOP - 70, 660, LINE_GAP * 4 + 140), Color(0, 0, 0, 0.35))
	for i in 5:
		var y := STAFF_TOP + i * LINE_GAP
		draw_line(Vector2(40, y), Vector2(680, y), Color(1, 1, 1, 0.3), 4)
	var glow: Color = theme.glow
	draw_line(Vector2(HIT_X, STAFF_TOP - 50), Vector2(HIT_X, STAFF_TOP + LINE_GAP * 4 + 50), Color(glow, 0.35 + kick * 0.5), 34 + kick * 16)
	draw_line(Vector2(HIT_X, STAFF_TOP - 50), Vector2(HIT_X, STAFF_TOP + LINE_GAP * 4 + 50), glow, 8)
	for i in allowed:
		var p := Vector2(640 - i * 48, STAFF_TOP - 40)
		if i < allowed - misses:
			draw_circle(p, 14, Color("ff5d73"))
		else:
			draw_arc(p, 14, 0, TAU, 16, Color(1, 1, 1, 0.4), 3)

	for note in notes:
		var pos := _note_pos(note)
		if pos.x > 720 or pos.y > SCREEN.y:
			continue
		var color: Color = colors[note.pitch] if note.state != 2 else Color("777777")
		var alpha := 1.0 if note.state == 0 else clampf(1.0 - (song_time - float(note.when)) * 2.0, 0.0, 1.0)
		_draw_note(pos, Color(color, alpha))

	_draw_band()


func _draw_note(pos: Vector2, color: Color) -> void:
	var outline := Color(0, 0, 0, color.a)
	draw_set_transform(pos, -0.35)
	draw_colored_polygon(ellipse_points(Vector2.ZERO, Vector2(32, 23)), outline)
	draw_colored_polygon(ellipse_points(Vector2.ZERO, Vector2(26, 17)), color)
	draw_set_transform(Vector2.ZERO)
	draw_line(pos + Vector2(26, -6), pos + Vector2(26, -86), outline, 9)
	draw_line(pos + Vector2(26, -6), pos + Vector2(26, -86), color, 5)
	draw_colored_polygon(PackedVector2Array([pos + Vector2(26, -86), pos + Vector2(56, -58), pos + Vector2(28, -66)]), color)


func _draw_band() -> void:
	var sad := is_resolved and not won
	var bounce := -kick * 14.0 + (sin(_clock * 18.0) * 6.0 if is_resolved and won else 0.0)
	var c := BAND_POS + Vector2(0, bounce)
	var drum := c + Vector2(0, -10)
	# Bass drum strapped on his back, with the stage's colours on the rim.
	draw_circle(drum, 128, Color("2b2b2b"))
	draw_circle(drum, 118, theme.accent.darkened(0.2))
	draw_circle(drum, 98, Color("f3e9d2"))
	if sad:
		draw_polyline(PackedVector2Array([drum + Vector2(-60, -40), drum + Vector2(-10, 0), drum + Vector2(-40, 30), drum + Vector2(20, 50), drum + Vector2(50, 10)]), Color("2b2b2b"), 8)
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		draw_line(drum + Vector2.from_angle(a) * 98, drum + Vector2.from_angle(a + 0.5) * 118, Color("ffd166"), 6)
	# Cymbals on a pole, clashing when he hits a note.
	var pole_top := drum + Vector2(150, -170)
	draw_line(drum + Vector2(110, -40), pole_top, Color("555555"), 8)
	var tilt := kick * 0.4 if not sad else 0.9
	for i in 2:
		var y := pole_top.y - 4 + i * (14 - kick * 10)
		draw_set_transform(Vector2(pole_top.x, y), tilt * (1 if i == 0 else -1))
		draw_colored_polygon(ellipse_points(Vector2.ZERO, Vector2(66, 12)), Color("e9c46a"))
		draw_set_transform(Vector2.ZERO)
	# Body, legs (one kicks the drum pedal), arms with mallets.
	var shirt: Color = theme.curtains[0]
	draw_line(c + Vector2(-30, 90), c + Vector2(-40, FLOOR_Y - BAND_POS.y), Color("2b2d42"), 26)
	draw_line(c + Vector2(30, 90), c + Vector2(44, FLOOR_Y - BAND_POS.y - kick * 40), Color("2b2d42"), 26)
	draw_rect(Rect2(c + Vector2(-60, -40), Vector2(120, 140)), shirt)
	draw_line(c + Vector2(-60, -40), c + Vector2(60, 100), Color("ffd166"), 10)
	var swing := kick * 1.2
	var hand_l := c + Vector2(-110, -40) + Vector2(0, -50).rotated(-swing)
	var hand_r := c + Vector2(110, -40) + Vector2(0, -50).rotated(swing)
	if sad:
		hand_l = c + Vector2(-80, 80)
		hand_r = c + Vector2(80, 80)
	draw_line(c + Vector2(-55, -30), hand_l, shirt, 22)
	draw_line(c + Vector2(55, -30), hand_r, shirt, 22)
	draw_line(hand_r, hand_r + Vector2(40, -40).rotated(swing), Color("8d5524"), 8)
	draw_circle(hand_r + Vector2(40, -40).rotated(swing), 12, Color("ff5d73"))
	draw_circle(hand_l, 13, Color("f1c27d"))
	draw_circle(hand_r, 13, Color("f1c27d"))
	# Head, harmonica and bandleader hat.
	var head := c + Vector2(0, -100)
	draw_circle(head, 54, Color("f1c27d"))
	draw_face(head + Vector2(0, -4), 52, not sad)
	draw_rect(Rect2(head + Vector2(-34, 30), Vector2(68, 16)), Color("bfc0c0"))
	draw_line(head + Vector2(-48, 34), head + Vector2(-48, 100), Color("777777"), 4)
	draw_rect(Rect2(head + Vector2(-60, -58), Vector2(120, 16)), Color("2b2b2b"))
	draw_rect(Rect2(head + Vector2(-40, -110), Vector2(80, 56)), Color("2b2b2b"))
	draw_rect(Rect2(head + Vector2(-40, -72), Vector2(80, 10)), theme.accent)
