extends Microgame
## SCRUB! Hold the mouse button and wiggle the sponge until the plate is clean.

const PLATE_CENTER := Vector2(640, 370)
const PLATE_RADIUS := 270.0
const SPONGE_REACH := 70.0

class Blob:
	var pos: Vector2
	var radius: float
	var dirt := 1.0

var blobs: Array[Blob] = []
var scrub_needed := 240.0
var last_mouse := Vector2.ZERO
var scrubbing := false


func _init() -> void:
	prompt = "SCRUB!"
	controls_hint = "HOLD CLICK + SCRUB"
	touch_hint = "RUB WITH YOUR FINGER"
	controls = Controls.POINTER
	duration = 4.0


func _on_start() -> void:
	# Mouse movement isn't time-scaled, so need less scrubbing at high speed.
	scrub_needed = 240.0 / sqrt(Engine.time_scale)
	for i in 3 + 2 * difficulty:
		var blob := Blob.new()
		blob.radius = randf_range(28, 48)
		blob.pos = PLATE_CENTER + Vector2.from_angle(randf() * TAU) * sqrt(randf()) * (PLATE_RADIUS - 70)
		blobs.append(blob)
	last_mouse = get_local_mouse_position()


func _process(_delta: float) -> void:
	var mouse := get_local_mouse_position()
	var was_scrubbing := scrubbing
	scrubbing = is_playing() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if scrubbing:
		# A new press (or a finger landing) shouldn't count the jump from the last spot.
		var moved := mouse.distance_to(last_mouse) if was_scrubbing else 0.0
		for blob in blobs:
			if blob.dirt > 0.0 and blob.pos.distance_to(mouse) < SPONGE_REACH + blob.radius * 0.5:
				blob.dirt = maxf(blob.dirt - moved / scrub_needed, 0.0)
		if blobs.all(func(b: Blob) -> bool: return b.dirt <= 0.0):
			win()
	last_mouse = mouse
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("a8dadc"))
	for x in range(0, int(SCREEN.x), 80):
		draw_line(Vector2(x, 0), Vector2(x, SCREEN.y), Color(1, 1, 1, 0.35), 3)
	for y in range(0, int(SCREEN.y), 80):
		draw_line(Vector2(0, y), Vector2(SCREEN.x, y), Color(1, 1, 1, 0.35), 3)

	draw_circle(PLATE_CENTER + Vector2(0, 12), PLATE_RADIUS, Color(0, 0, 0, 0.15))
	draw_circle(PLATE_CENTER, PLATE_RADIUS, Color.WHITE)
	draw_arc(PLATE_CENTER, PLATE_RADIUS * 0.7, 0, TAU, 64, Color("e5e5e5"), 6)
	for blob in blobs:
		if blob.dirt > 0.0:
			draw_circle(blob.pos, blob.radius, Color(0.45, 0.3, 0.12, blob.dirt))
			draw_circle(blob.pos + Vector2(blob.radius * 0.6, blob.radius * 0.3), blob.radius * 0.5, Color(0.35, 0.4, 0.1, blob.dirt))
	if is_resolved:
		draw_face(PLATE_CENTER, 150, won)
	if is_resolved and won:
		for i in 6:
			var p := PLATE_CENTER + Vector2.from_angle(TAU * i / 6.0 + 0.3) * (PLATE_RADIUS + 20)
			draw_line(p - Vector2(22, 0), p + Vector2(22, 0), Color.WHITE, 6)
			draw_line(p - Vector2(0, 22), p + Vector2(0, 22), Color.WHITE, 6)

	if not is_resolved:
		var mouse := get_local_mouse_position()
		if scrubbing:
			for i in 5:
				draw_circle(mouse + Vector2(randf_range(-70, 70), randf_range(-50, 50)), randf_range(6, 14), Color(1, 1, 1, 0.8))
		draw_rect(Rect2(mouse - Vector2(50, 30), Vector2(100, 60)), Color("ffd60a"))
		draw_rect(Rect2(mouse - Vector2(50, 30), Vector2(100, 18)), Color("52b788"))
