extends Microgame
## FOLLOW! Keep your finger on the wandering light until time runs out.
## Graveyard: a flaming jack-o'-lantern. Temple: a firefly. Swamp: a will-o'-wisp.

## Seconds to get your finger on it before it starts to count.
const GRACE := 1.3
## How long you can slip off it before it escapes.
const SLIP := 0.25
## Starts below the middle so the prompt word doesn't cover it.
const HOME := Vector2(360, 800)
const WANDER := Vector2(250, 380)

var fly := HOME
var radius := 90.0
var speed := 1.0
var phase := Vector2.ZERO
var elapsed := 0.0
var off_time := 0.0
var on_it := false
var was_on := false
var sparkle := 0.0
var stars := PackedVector2Array()


func _init() -> void:
	prompt = "FOLLOW!"
	controls_hint = "HOLD CLICK ON THE LIGHT"
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
	if is_playing():
		if on_it and not was_on:
			Sfx.play("zap", 0.5, 1.4)
		elif was_on and not on_it:
			Sfx.play("beep", 0.4, 0.7)
		if on_it:
			sparkle -= delta
			if sparkle <= 0.0:
				sparkle = 0.12
				burst(fly, Stages.theme(stage).glow, 2, 140.0, 6.0)
		if elapsed > GRACE:
			off_time = 0.0 if on_it else off_time + delta
			if off_time > SLIP:
				lose()
	was_on = on_it
	queue_redraw()


func _on_resolved(result: bool) -> void:
	if result:
		burst(fly, Stages.theme(stage).glow, 20, 420.0, 9.0)
		Sfx.play("coin")
	else:
		Sfx.play("whoosh")


func _draw() -> void:
	var theme := Stages.theme(stage)
	for i in 16:
		draw_rect(Rect2(0, SCREEN.y * i / 16.0, SCREEN.x, SCREEN.y / 16.0 + 1), (theme.sky as Color).lerp(theme.sky_low, i / 15.0))
	match stage:
		Stages.GRAVEYARD:
			for star in stars:
				draw_circle(star, 2, Color(1, 1, 1, 0.5))
			for i in 5:
				draw_sprite(["graveyard/grave_2", "graveyard/grave_1_small"][i % 2], 1, 0, Vector2(70 + i * 145, 1150 + (i % 2) * 20), 4.0, false, Color(0.4, 0.35, 0.5))
		Stages.TEMPLE:
			for row in 18:
				for col in 6:
					var x := col * 150.0 + (75.0 if row % 2 else 0.0) - 60.0
					draw_rect(Rect2(x, row * 72.0, 146, 68), Color("33423a").lerp(Color("1f2a24"), row / 18.0))
			for i in 30:
				var p := Vector2(fmod(i * 97.0 + _clock * 40.0, 760.0) - 20, fmod(i * 173.0 + _clock * 900.0, SCREEN.y))
				draw_line(p, p + Vector2(-4, 26), Color(0.7, 0.9, 1.0, 0.25), 2.0)
		_:
			for i in 5:
				draw_rect(Rect2(-60 + sin(_clock * 0.6 + i) * 60.0, 300 + i * 200, 840, 90), Color(0.7, 0.95, 0.6, 0.05))
			draw_sprite("swamp/tree_5", 1, 0, Vector2(100, 1100), 4.0, false, Color(0.3, 0.45, 0.3))
			draw_sprite("graveyard/tree", 1, 0, Vector2(640, 1120), 4.0, true, Color(0.3, 0.45, 0.3))
	draw_rect(Rect2(0, 1220, SCREEN.x, 60), theme.ground)

	var ring := Color("06d6a0") if on_it else Color(1, 1, 1, 0.5)
	if elapsed < GRACE and not on_it:
		ring.a = 0.4 + 0.4 * absf(sin(elapsed * 8.0))
	elif elapsed >= GRACE and not on_it and not is_resolved:
		ring = Color("ef476f")
	draw_arc(fly, radius, 0, TAU, 48, ring, 5)
	var glow: Color = theme.glow
	for i in 4:
		draw_circle(fly, 46.0 - i * 9.0, Color(glow, 0.1 + i * 0.12))
	match stage:
		Stages.GRAVEYARD:
			draw_sprite("graveyard/jack_flame", 4, anim_frame(10, 4), fly + Vector2(0, -6), 6.0)
		Stages.TEMPLE:
			for i in 4:
				draw_circle(fly, 34.0 - i * 7.0, Color(0.85, 1.0, 0.4, 0.12 + i * 0.2))
			var wing := 10.0 + 6.0 * sin(_clock * 50.0)
			for side in [-1.0, 1.0]:
				draw_colored_polygon(ellipse_points(fly + Vector2(side * 14, -10), Vector2(14, wing)), Color(1, 1, 1, 0.5))
			draw_circle(fly, 10, Color("fcf6bd"))
		_:
			draw_sprite("swamp/willOWisp", 6, anim_frame(10, 6), fly, 6.0)

	if is_resolved:
		draw_text_centered("GOT IT!" if won else "IT GOT AWAY!", Vector2(360, 110), 64, Color("06d6a0") if won else Color("ef476f"))
