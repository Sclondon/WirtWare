extends Microgame
## PET IT! Rub the gremlin to fill its happy meter, but stop when it puffs up or it bites.
## A homage to Cryptlins.

const HOME := Vector2(360, 700)
const BODY_R := 150.0
## Seconds of shivering before it puffs up.
const WARN := [0.5, 0.42, 0.36]
## Seconds it stays puffed up.
const GRUMP := [0.75, 0.7, 0.65]
## A moment after puffing up before rubbing counts as a bite, for reaction time.
const GRACE := 0.12

enum Mood { CALM, WARN, GRUMPY }

var happy := 0.0
var goal := 1800.0
var mood := Mood.CALM
var mood_time := 0.0
## Clock times when the gremlin starts shivering.
var grumps: Array[float] = []
var elapsed := 0.0
var last_pointer := Vector2.ZERO
var rubbing := false
var bit := false
var hearts: Array[Dictionary] = []
var heart_budget := 0.0
var purr_timer := 0.0
var theme := {}


func _init() -> void:
	prompt = "PET IT!"
	controls_hint = "HOLD CLICK AND RUB"
	touch_hint = "RUB IT WITH YOUR FINGER"
	controls = Controls.POINTER
	duration = 5.0


func _on_start() -> void:
	theme = Stages.theme(stage)
	goal = [1800.0, 2300.0, 2600.0][difficulty - 1]
	match difficulty:
		1:
			grumps = [randf_range(1.0, 1.4)]
		2:
			grumps = [randf_range(0.9, 1.1), randf_range(2.4, 2.7)]
		_:
			grumps = [randf_range(0.8, 1.0), randf_range(2.0, 2.3)]


func _process(delta: float) -> void:
	update_pointer()
	elapsed += delta
	mood_time += delta
	purr_timer -= delta
	var d := difficulty - 1
	if is_playing():
		match mood:
			Mood.CALM:
				if not grumps.is_empty() and elapsed >= grumps[0]:
					grumps.pop_front()
					mood = Mood.WARN
					mood_time = 0.0
					Sfx.play("beep", 0.6, 0.7)
			Mood.WARN:
				if mood_time >= WARN[d]:
					mood = Mood.GRUMPY
					mood_time = 0.0
					Sfx.play("buzz", 0.5, 1.6)
					shake(5)
			Mood.GRUMPY:
				if mood_time >= GRUMP[d]:
					mood = Mood.CALM
					mood_time = 0.0

		var moved := pointer.distance_to(last_pointer)
		rubbing = pointer_down and not pointer_pressed and pointer.distance_to(_center()) < touch_size(BODY_R * 1.1, 60) and moved > 0.5
		if rubbing:
			if mood == Mood.GRUMPY and mood_time > GRACE:
				_bite()
			elif mood != Mood.GRUMPY:
				happy += minf(moved, 60.0)
				heart_budget += minf(moved, 60.0)
				if heart_budget > 260.0:
					heart_budget = 0.0
					hearts.append({"pos": pointer + Vector2(randf_range(-30, 30), -40), "age": 0.0})
					Sfx.play("pop", 0.35, randf_range(1.3, 1.6))
				if purr_timer <= 0.0:
					purr_timer = 0.25
					Sfx.play("squish", 0.25, 1.8)
				if happy >= goal:
					happy = goal
					Sfx.play("spring", 0.7, 1.3)
					for i in 8:
						hearts.append({"pos": _center() + Vector2(randf_range(-140, 140), randf_range(-120, 40)), "age": -i * 0.04})
					burst(_center(), Color("ff70a6"), 20, 480, 12)
					popup("PURRR!", _center() + Vector2(0, -200), Color("ff70a6"), 56)
					win()
	last_pointer = pointer

	for heart in hearts:
		heart.age += delta
		if heart.age > 0.0:
			heart.pos += Vector2(sin(heart.age * 9.0) * 60.0, -260.0) * delta
	hearts = hearts.filter(func(h: Dictionary) -> bool: return h.age < 0.9)
	queue_redraw()


func _bite() -> void:
	bit = true
	Sfx.play("crunch")
	Sfx.play("hit", 0.8, 0.7)
	burst(pointer, Color("ef476f"), 16, 420, 10)
	popup("CHOMP!", pointer + Vector2(0, -90), Color("ef476f"), 64)
	shake(16)
	lose()


## Where the gremlin is, with a little shiver while it warns.
func _center() -> Vector2:
	if mood == Mood.WARN and is_playing():
		return HOME + Vector2(sin(elapsed * 90.0) * 6.0, 0)
	return HOME


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("0a0a10").lerp(theme.sky, 0.25))
	# Spotlight cone and the lit floor patch.
	var light: Color = Color(theme.glow).lerp(Color.WHITE, 0.4)
	draw_colored_polygon(PackedVector2Array([Vector2(310, 0), Vector2(410, 0), Vector2(640, 900), Vector2(80, 900)]), Color(light, 0.1))
	draw_colored_polygon(ellipse_points(Vector2(360, 880), Vector2(300, 70)), Color(light, 0.22))
	draw_rect(Rect2(270, 0, 180, 40), Color("333344"))

	_draw_props()
	_draw_gremlin()

	for heart in hearts:
		if heart.age >= 0.0:
			_draw_heart(heart.pos, 22.0 * minf(1.0 + heart.age, (0.9 - heart.age) * 6.0), Color("ff70a6"))

	# Happy meter.
	var bar := Rect2(110, 1100, 500, 44)
	draw_rect(bar.grow(6), Color("1b1b1b"))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * happy / goal, bar.size.y)), Color("ff70a6"))
	_draw_heart(Vector2(bar.position.x - 40, bar.get_center().y), 26, Color("ff70a6"))

	if rubbing and is_playing():
		draw_circle(pointer, 18, Color(1, 1, 1, 0.5))
	if mood == Mood.WARN and is_playing():
		draw_text_centered("!", _center() + Vector2(150, -190), 96, Color("ffd166"))
	if bit:
		draw_text_centered("IT BIT YOU!", Vector2(360, 150), 64, Color("ef476f"))
	elif is_resolved and won:
		draw_text_centered("SO HAPPY!", Vector2(360, 150), 64, Color("ff70a6"))
	elif is_resolved:
		draw_text_centered("STILL GRUMPY...", Vector2(360, 150), 56, Color("ef476f"))


func _draw_gremlin() -> void:
	var c := _center()
	var grumpy := (mood == Mood.GRUMPY and is_playing()) or bit
	var puff := 1.22 if grumpy else 1.0
	var fur: Color = Color("6b5b95").lerp(theme.sky_low, 0.35)
	if grumpy:
		fur = fur.lerp(Color("c0392b"), 0.35)
	var r := BODY_R * puff
	# Shadow, spiky fur when puffed, body.
	draw_colored_polygon(ellipse_points(c + Vector2(0, 170), Vector2(170, 34)), Color(0, 0, 0, 0.4))
	if grumpy:
		var spikes := PackedVector2Array()
		for i in 28:
			var a := TAU * i / 28.0
			var reach := r * (1.18 if i % 2 == 0 else 0.95)
			spikes.append(c + Vector2(cos(a), sin(a)) * reach)
		draw_colored_polygon(spikes, fur.darkened(0.25))
	# Ears.
	for side in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(side * r * 0.45, -r * 0.7), c + Vector2(side * r * 1.35, -r * (1.25 if grumpy else 0.95)), c + Vector2(side * r * 0.9, -r * 0.25),
		]), fur.darkened(0.15))
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(side * r * 0.6, -r * 0.6), c + Vector2(side * r * 1.15, -r * (1.1 if grumpy else 0.85)), c + Vector2(side * r * 0.88, -r * 0.35),
		]), Color("ff9eb5"))
	draw_circle(c, r, fur)
	draw_colored_polygon(ellipse_points(c + Vector2(0, r * 0.35), Vector2(r * 0.6, r * 0.5)), fur.lightened(0.25))
	# Little feet.
	for side in [-1.0, 1.0]:
		draw_colored_polygon(ellipse_points(c + Vector2(side * 70, r * 0.95), Vector2(40, 22)), fur.darkened(0.2))

	# Face: content squints, big eyes when warning, angry eyes and teeth when puffed.
	var eye_y := -r * 0.2
	for side in [-1.0, 1.0]:
		var e := c + Vector2(side * r * 0.36, eye_y)
		if grumpy:
			draw_circle(e, 26, Color("ffd166"))
			draw_circle(e, 11, Color("c0392b"))
			draw_line(e + Vector2(side * 40, -50), e + Vector2(-side * 30, -24), Color.BLACK, 9)
		elif mood == Mood.WARN and is_playing():
			draw_circle(e, 34, Color.WHITE)
			draw_circle(e, 12, Color.BLACK)
		elif rubbing or (is_resolved and won):
			draw_arc(e + Vector2(0, 8), 22, PI + 0.3, TAU - 0.3, 10, Color.BLACK, 7)
		else:
			draw_circle(e, 28, Color("fff7d6"))
			draw_circle(e + Vector2(0, 4), 14, Color.BLACK)
			draw_circle(e + Vector2(-5, -3), 5, Color.WHITE)
	var mouth := c + Vector2(0, r * 0.22)
	if grumpy:
		var open := PackedVector2Array([mouth + Vector2(-70, -12), mouth + Vector2(70, -12), mouth + Vector2(50, 40), mouth + Vector2(-50, 40)])
		draw_colored_polygon(open, Color("3a0d12"))
		for i in 5:
			var x := -56.0 + i * 28.0
			draw_colored_polygon(PackedVector2Array([mouth + Vector2(x, -12), mouth + Vector2(x + 24, -12), mouth + Vector2(x + 12, 14)]), Color.WHITE)
			draw_colored_polygon(PackedVector2Array([mouth + Vector2(x + 4, 40), mouth + Vector2(x + 24, 40), mouth + Vector2(x + 14, 20)]), Color.WHITE)
	elif mood == Mood.WARN and is_playing():
		draw_circle(mouth + Vector2(0, 10), 14, Color("3a0d12"))
	else:
		draw_arc(mouth, 30, 0.3, PI - 0.3, 12, Color.BLACK, 6)
		draw_colored_polygon(PackedVector2Array([mouth + Vector2(-18, 18), mouth + Vector2(-6, 18), mouth + Vector2(-12, 30)]), Color.WHITE)
	if rubbing and not grumpy:
		for side in [-1.0, 1.0]:
			draw_circle(c + Vector2(side * r * 0.62, r * 0.12), 18, Color(1, 0.45, 0.6, 0.6))


## The gremlin's room, half lost in the dark: a few things from the stage.
func _draw_props() -> void:
	var dim := Color(0.55, 0.55, 0.6)
	match stage:
		Stages.GRAVEYARD:
			draw_sprite("graveyard/prop_pumpkin_pile", 1, 0, Vector2(105, 930), 5.0, false, dim)
			draw_sprite("graveyard/candybasket", 1, 0, Vector2(620, 920), 5.0, false, dim)
		Stages.TEMPLE:
			draw_sprite("temple/t_torch", 12, anim_frame(10, 6), Vector2(70, 330), 6.0)
			draw_sprite("temple/t_torch", 12, anim_frame(10, 6, 0.15), Vector2(650, 330), 6.0, true)
		_:
			draw_sprite("swamp/willOWisp", 6, anim_frame(8, 6), Vector2(90, 380 + sin(elapsed * 3.0) * 14), 4.0)
			draw_sprite("swamp/toxic_barrel", 1, 0, Vector2(620, 920), 6.0, false, dim)


func _draw_heart(at: Vector2, size: float, color: Color) -> void:
	if size < 3.0:
		return
	draw_circle(at + Vector2(-size * 0.5, -size * 0.2), size * 0.55, color)
	draw_circle(at + Vector2(size * 0.5, -size * 0.2), size * 0.55, color)
	draw_colored_polygon(PackedVector2Array([at + Vector2(-size * 1.02, 0), at + Vector2(size * 1.02, 0), at + Vector2(0, size * 1.1)]), color)
