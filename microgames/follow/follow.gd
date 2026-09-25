extends Microgame
## FOLLOW! Keep your finger on the firefly until time runs out.

## Seconds to get your finger on it before it starts to count.
const GRACE := 1.3
## How long you can slip off it before it escapes.
const SLIP := 0.25
const HOME := Vector2(360, 640)
const WANDER := Vector2(250, 450)

var fly := HOME
var radius := 90.0
var speed := 1.0
var phase := Vector2.ZERO
var elapsed := 0.0
var off_time := 0.0
var on_it := false
var stars := PackedVector2Array()


func _init() -> void:
	prompt = "FOLLOW!"
	controls_hint = "HOLD CLICK ON THE FIREFLY"
	touch_hint = "KEEP YOUR FINGER ON IT"
	controls = Controls.POINTER
	duration = 4.5
	win_on_timeout = true


func _ready() -> void:
	for i in 60:
		stars.append(Vector2(randf() * SCREEN.x, randf() * 900))


func _on_start() -> void:
	radius = touch_size([95.0, 80.0, 68.0][difficulty - 1], 34)
	speed = 0.8 + 0.3 * difficulty
	phase = Vector2(randf() * TAU, randf() * TAU)


func _fly_position(t: float) -> Vector2:
	# Two sine waves at odd ratios so it wanders instead of looping. It starts
	# still and widens its path over the grace period.
	var spread := clampf(t / GRACE, 0.0, 1.0)
	return HOME + Vector2(sin(t * speed * 1.9 + phase.x), sin(t * speed * 1.3 + phase.y)) * WANDER * spread


func _process(delta: float) -> void:
	update_pointer()
	elapsed += delta
	if not (is_resolved and not won):
		fly = _fly_position(elapsed)
	else:
		fly += Vector2(400, -700) * delta  # It got away.
	on_it = pointer_down and pointer.distance_to(fly) < radius
	if is_playing() and elapsed > GRACE:
		off_time = 0.0 if on_it else off_time + delta
		if off_time > SLIP:
			lose()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("0d1b2a"))
	for star in stars:
		draw_circle(star, 2, Color(1, 1, 1, 0.6))
	for i in 6:
		draw_circle(Vector2(i * 150, SCREEN.y + 60), 170, Color("1b263b"))

	var ring := Color("06d6a0") if on_it else Color(1, 1, 1, 0.5)
	if elapsed < GRACE and not on_it:
		ring.a = 0.4 + 0.4 * absf(sin(elapsed * 8.0))
	draw_arc(fly, radius, 0, TAU, 48, ring, 5)
	for i in 4:
		draw_circle(fly, 40.0 - i * 9.0, Color(0.85, 1.0, 0.4, 0.12 + i * 0.2))
	draw_circle(fly, 9, Color("fcf6bd"))

	if is_resolved:
		draw_text_centered("GOT IT!" if won else "IT GOT AWAY!", Vector2(360, 110), 64, Color("06d6a0") if won else Color("ef476f"))
