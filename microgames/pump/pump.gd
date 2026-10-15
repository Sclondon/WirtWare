extends Microgame
## PUMP IT! Mash the button to pump air into the thing until it pops. What you
## pump depends on the stage: a jack-o'-lantern in the graveyard, a temple torch
## fanned with bellows until it blazes, or a swamp toad that puffs up and bursts.

const OBJECT_BASE := Vector2(290, 960)
const PUMP_POS := Vector2(585, 900)
const BELLOWS_TIP := Vector2(420, 800)
const GROUND_Y := 960.0
## Where the torch's bowl sits (the flame grows up from here).
const BOWL_Y := 795.0

var air := 0.0
var needed := 10.0
var pump_kick := 0.0
var elapsed := 0.0
var end_time := 0.0


func _init() -> void:
	prompt = "PUMP IT!"
	controls_hint = "MASH SPACE"
	touch_hint = "MASH THE BUTTON"
	controls = Controls.BUTTON
	duration = 4.0


func _on_start() -> void:
	# Real time shrinks as the game speeds up, so ease off the press count.
	needed = roundf((6.0 + 2.0 * difficulty) / sqrt(Engine.time_scale))


func _process(delta: float) -> void:
	elapsed += delta
	if is_playing():
		if Input.is_action_just_pressed("action"):
			air += 1.0
			pump_kick = 1.0
			var fill := _fill()
			if stage == Stages.TEMPLE:
				Sfx.play("whoosh", 0.6, 0.9 + 0.6 * fill)
				burst(BELLOWS_TIP, Color(1, 1, 1, 0.6), 4, 260.0, 8.0)
			else:
				Sfx.play("squish" if stage == Stages.SWAMP else "tap", 0.8, 0.8 + 0.8 * fill)
			if air >= needed:
				win()
		air = maxf(air - delta * 0.45 * difficulty, 0.0)
	else:
		end_time += delta
	pump_kick = move_toward(pump_kick, 0.0, delta * 6.0)
	queue_redraw()


func _fill() -> float:
	return clampf(air / needed, 0.0, 1.0)


## Middle of the pumped thing, for sparks and words.
func _center() -> Vector2:
	match stage:
		Stages.TEMPLE:
			return Vector2(OBJECT_BASE.x, BOWL_Y - 160)
		Stages.SWAMP:
			return OBJECT_BASE + Vector2(0, -(6.0 + 11.0 * _fill()) * 12.0)
	return OBJECT_BASE + Vector2(0, -(7.0 + 15.0 * _fill()) * 8.0)


func _on_resolved(result: bool) -> void:
	var c := _center()
	if not result:
		popup("PFFT...", c + Vector2(0, -120), Color("cccccc"), 56)
		return
	shake(14)
	match stage:
		Stages.TEMPLE:
			Sfx.play("boom", 0.8, 1.3)
			burst(c, Color("ff8c1a"), 30, 700.0, 16.0)
			burst(c, Color("ffe066"), 20, 500.0, 12.0)
			popup("BLAZE!", c + Vector2(0, -60), Color("ffe066"), 96)
		Stages.SWAMP:
			Sfx.play("squish", 1.0, 0.6)
			Sfx.play("boom", 0.7, 1.4)
			burst(c, Color("8fd14f"), 34, 800.0, 18.0)
			burst(c, Color("d4ff7a"), 16, 500.0, 10.0)
			popup("SPLAT!", c, Color("d4ff7a"), 110)
		_:
			Sfx.play("boom", 0.8, 1.2)
			burst(c, Color("ff9a3c"), 30, 800.0, 18.0)
			burst(c, Color("5b8c3a"), 10, 600.0, 12.0)
			burst(c, Color("ffe066"), 12, 400.0, 10.0)
			popup("POP!", c, Color("ffe066"), 120)


func _draw() -> void:
	var theme := Stages.theme(stage)
	_draw_scenery(theme)

	var fill := _fill()
	var popped := is_resolved and won
	var limp := is_resolved and not won
	# Bulge on each pump, and tremble when nearly full.
	var bulge := Vector2(1.0 + 0.1 * pump_kick, 1.0 - 0.06 * pump_kick)
	if limp:
		bulge = Vector2(1.15, 0.8)
	var wobble := Vector2(sin(elapsed * 60.0) * 7.0 * maxf(fill - 0.6, 0.0) / 0.4, 0) if is_playing() else Vector2.ZERO
	var base := OBJECT_BASE + wobble
	var sad_tint := Color(0.6, 0.6, 0.7) if limp else Color.WHITE

	if stage == Stages.TEMPLE:
		_draw_bellows()
		draw_sprite("temple/t_torch", 12, 7 + anim_frame(8, 5), base + Vector2(0, -156), 13.0)
		if popped:
			var roar := 0.85 + 0.15 * sin(elapsed * 20.0)
			draw_circle(Vector2(base.x, BOWL_Y - 200), 260 * roar, Color(1, 0.7, 0.2, 0.25))
			_draw_flame(Vector2(base.x, BOWL_Y), 260, 560 * roar)
		elif not limp:
			draw_circle(Vector2(base.x, BOWL_Y - 60), 60 + 160 * fill, Color(1, 0.7, 0.2, 0.15 + 0.15 * fill))
			_draw_flame(Vector2(base.x, BOWL_Y), 50 + 120 * fill * bulge.x, 50 + 300 * fill * bulge.x)
		if limp:
			for i in 3:
				var p := Vector2(base.x - 20 + i * 20, BOWL_Y - 40 - fmod(elapsed * 120.0 + i * 40.0, 160.0))
				draw_circle(p, 18, Color(0.5, 0.5, 0.5, 0.5))
		return

	_draw_pump(theme)
	if popped:
		if end_time < 0.35:
			var c := _center()
			for i in 14:
				var dir := Vector2.from_angle(TAU * i / 14.0)
				draw_line(c + dir * 90, c + dir * (180 + 400 * end_time), Color(theme.glow), 10)
		return

	if stage == Stages.SWAMP:
		var size := (6.0 + 11.0 * fill) * bulge
		var frame := 2 if pump_kick > 0.3 else anim_frame(3, 2)
		var tint := Color.WHITE.lerp(Color(1.0, 0.75, 0.75), maxf(fill - 0.5, 0.0) * 2.0) * sad_tint
		_sprite_on("swamp/sludge_toad", 4, frame, base + Vector2(0, 2 * size.y), size, tint)
	else:
		var size := (7.0 + 15.0 * fill) * bulge
		draw_circle(base + Vector2(0, -7 * size.y), 9 * size.x, Color(1, 0.6, 0.1, 0.12 + 0.2 * fill))
		var frame: int = [0, 2, 3, 4][mini(int(fill * 4.0), 3)]
		_sprite_on("graveyard/pumpkin", 6, frame, base + Vector2(0, 2 * size.y), size, sad_tint)


## The stage's sky, ground and a few props.
func _draw_scenery(theme: Dictionary) -> void:
	var top: Color = theme.sky
	var low: Color = theme.sky_low
	for i in 12:
		draw_rect(Rect2(0, GROUND_Y * i / 12.0, SCREEN.x, GROUND_Y / 12.0 + 1), top.lerp(low, i / 11.0))
	var ground: Color = theme.ground
	draw_rect(Rect2(0, GROUND_Y, SCREEN.x, SCREEN.y - GROUND_Y), ground)
	draw_rect(Rect2(0, GROUND_Y, SCREEN.x, 10), ground.lightened(0.25))
	match stage:
		Stages.GRAVEYARD:
			draw_circle(Vector2(580, 200), 70, Color("fff2c4"))
			draw_circle(Vector2(555, 185), 70, top)
			draw_sprite("graveyard/grave_2", 1, 0, Vector2(70, GROUND_Y - 44), 3.0, false, Color(0.7, 0.65, 0.8))
			draw_sprite("graveyard/grave_1_small", 1, 0, Vector2(470, GROUND_Y - 40), 2.5, false, Color(0.55, 0.5, 0.65))
			draw_sprite("graveyard/tree_3", 1, 0, Vector2(560, GROUND_Y - 190), 3.0, false, Color(0.5, 0.45, 0.6))
			draw_sprite("graveyard/bat", 4, anim_frame(10, 4), Vector2(120 + sin(elapsed * 2.0) * 60.0, 220), 3.0)
		Stages.TEMPLE:
			for row in 8:
				for col in 6:
					var x := col * 140.0 + (70.0 if row % 2 else 0.0) - 70.0
					draw_rect(Rect2(x, 380 + row * 72, 136, 68), Color("4d5a4f").lerp(Color("2f3a33"), row / 8.0))
			draw_sprite("temple/t_totem_heads", 3, 1, Vector2(110, 300), 8.0)
			draw_sprite("temple/t_totem_heads", 3, 2, Vector2(610, 300), 8.0)
		Stages.SWAMP:
			draw_circle(Vector2(560, 220), 70, Color(0.85, 1.0, 0.6, 0.3))
			draw_sprite("swamp/tree_5", 1, 0, Vector2(610, GROUND_Y - 330), 3.0, false, Color(0.45, 0.6, 0.45))
			for i in 4:
				var y := GROUND_Y - 30.0 + i * 24.0
				draw_rect(Rect2(-60 + sin(elapsed * 0.7 + i) * 50.0, y, 840, 28), Color(0.7, 0.95, 0.6, 0.08))


## A plunger pump with a hose running to the pumped thing.
func _draw_pump(theme: Dictionary) -> void:
	var body: Color = theme.accent
	var hose := PackedVector2Array([PUMP_POS + Vector2(-55, 40), Vector2(OBJECT_BASE.x + 60, PUMP_POS.y + 40), OBJECT_BASE + Vector2(40, -20)])
	draw_polyline(hose, Color("222222"), 10)
	var handle_y := PUMP_POS.y - 170 + pump_kick * 60
	draw_line(Vector2(PUMP_POS.x, handle_y), PUMP_POS, Color("888888"), 12)
	draw_line(Vector2(PUMP_POS.x - 65, handle_y), Vector2(PUMP_POS.x + 65, handle_y), Color("222222"), 22)
	draw_rect(Rect2(PUMP_POS - Vector2(59, 34), Vector2(118, 98)), Color.BLACK)
	draw_rect(Rect2(PUMP_POS - Vector2(55, 30), Vector2(110, 90)), body)
	draw_rect(Rect2(PUMP_POS - Vector2(55, 30), Vector2(110, 16)), body.lightened(0.3))


## Wooden bellows on a stone block, nozzle aimed at the torch. Squeezes on each pump.
func _draw_bellows() -> void:
	draw_rect(Rect2(500, 870, 200, 90), Color("5c5a4c"))
	draw_rect(Rect2(500, 870, 200, 12), Color("7d7a66"))
	var hinge := BELLOWS_TIP + Vector2(70, 0)
	var open := 0.38 - 0.3 * pump_kick
	var length := 200.0
	var upper := hinge + Vector2.from_angle(-open) * length
	var lower := hinge + Vector2.from_angle(open) * length
	draw_colored_polygon(PackedVector2Array([hinge, upper, lower]), Color("8a4b2a"))
	draw_line(hinge, upper, Color("6f4518"), 22)
	draw_line(hinge, lower, Color("6f4518"), 22)
	draw_line(upper, upper + Vector2(50, -20), Color("6f4518"), 14)
	draw_line(lower, lower + Vector2(50, 20), Color("6f4518"), 14)
	draw_colored_polygon(PackedVector2Array([
		BELLOWS_TIP + Vector2(0, -8), hinge + Vector2(0, -16), hinge + Vector2(0, 16), BELLOWS_TIP + Vector2(0, 8),
	]), Color("c9a227"))


## A flickering three-layer flame growing up from [param base].
func _draw_flame(base: Vector2, width: float, height: float) -> void:
	var colors: Array[Color] = [Color("e63b1f"), Color("ff8c1a"), Color("ffe066")]
	for layer in 3:
		var k := 1.0 - layer * 0.3
		var r := width * k * 0.5
		var points := ellipse_points(base + Vector2(0, -r), Vector2(r, r), 0.0, PI, 12)
		points.append(base + Vector2(sin(elapsed * 17.0 + layer * 2.0) * width * 0.15, -height * k))
		draw_colored_polygon(points, colors[layer])


## One frame of a sprite strip with separate x/y scales, standing on [param base].
func _sprite_on(path: String, frames: int, frame: int, base: Vector2, size: Vector2, tint := Color.WHITE) -> void:
	var tex := art(path)
	var w := tex.get_width() / float(frames)
	var h := float(tex.get_height())
	draw_set_transform(base, 0.0, size)
	draw_texture_rect_region(tex, Rect2(-w / 2, -h, w, h), Rect2(w * posmod(frame, frames), 0, w, h), tint)
	draw_set_transform(Vector2.ZERO)
