extends Microgame
## LAND! Hold the button to slow your fall and touch down gently. A bat
## flaps down onto a tombstone in the graveyard, a golden idol is lowered on
## its rope onto a pedestal in the temple, and a crow lands on a swamp branch.

const GROUND_Y := 1000.0
const THRUST := 1250.0
const METER := Rect2(640, 260, 40, 560)
const METER_MAX_SPEED := 700.0

## The bottom of the falling thing (its feet, or the idol's base).
var ship := Vector2(330, 140)
var velocity := 40.0
var gravity := 380.0
var safe_speed := 180.0
var thrusting := false
var elapsed := 0.0
var end_time := 0.0
var flap_timer := 0.0
## Temple only: which of the four idols (rows of the idol sheet).
var idol := 0


func _init() -> void:
	prompt = "LAND!"
	controls_hint = "HOLD SPACE"
	touch_hint = "HOLD THE BUTTON"
	controls = Controls.BUTTON
	duration = 5.0


func _on_start() -> void:
	gravity = 300.0 + 80.0 * difficulty
	safe_speed = 200.0 - 20.0 * difficulty
	idol = randi() % 4


func _process(delta: float) -> void:
	elapsed += delta
	thrusting = is_playing() and Input.is_action_pressed("action")
	if is_playing():
		velocity += (gravity - (THRUST if thrusting else 0.0)) * delta
		ship.y += velocity * delta
		if ship.y < 90:
			ship.y = 90
			velocity = maxf(velocity, 0.0)
		if thrusting:
			flap_timer -= delta
			if flap_timer <= 0.0:
				flap_timer = 0.16
				if stage == Stages.TEMPLE:
					Sfx.play("tap", 0.5, 0.6)
				else:
					Sfx.play("swish", 0.5, 1.3)
		else:
			flap_timer = 0.0
		if ship.y >= GROUND_Y:
			ship.y = GROUND_Y
			if velocity <= safe_speed:
				win()
			else:
				lose()
	else:
		end_time += delta
	queue_redraw()


func _on_resolved(result: bool) -> void:
	if ship.y < GROUND_Y:
		popup("TOO SLOW!", Vector2(330, 520), Color("ef476f"), 72)
		return  # Ran out of time in the air.
	var theme := Stages.theme(stage)
	if result:
		Sfx.play("thud", 0.7)
		burst(ship, (theme.ground as Color).lightened(0.4), 12, 300.0, 9.0)
		var word: String = ["PERCHED!", "SET!", "PERCHED!"][stage]
		popup(word, ship + Vector2(0, -260), theme.glow, 72)
		return
	Sfx.play("crunch")
	shake(14)
	match stage:
		Stages.TEMPLE:
			burst(ship + Vector2(0, -80), Color("f2c14e"), 30, 600.0, 14.0)
			popup("CRACK!", ship + Vector2(0, -260), Color("ef476f"), 80)
		Stages.SWAMP:
			burst(ship + Vector2(0, -50), Color("22263a"), 24, 500.0, 14.0)
			popup("SQUAWK!", ship + Vector2(0, -240), Color("ef476f"), 72)
		_:
			burst(ship + Vector2(0, -50), Color("0c1a26"), 24, 500.0, 14.0)
			popup("SPLAT!", ship + Vector2(0, -240), Color("ef476f"), 80)


func _draw() -> void:
	var theme := Stages.theme(stage)
	_draw_scenery(theme)
	var crashed := is_resolved and not won and ship.y >= GROUND_Y
	var landed := is_resolved and won

	# A soft glow keeps the dark creatures readable against the night.
	var glow: Color = theme.glow
	if stage != Stages.TEMPLE:
		draw_circle(ship + Vector2(0, -60), 110, Color(glow, 0.14))

	match stage:
		Stages.TEMPLE:
			_draw_idol(crashed)
		Stages.SWAMP:
			var center := ship + Vector2(0, -66)
			if crashed:
				draw_sprite("swamp/h_crow_fall", 2, anim_frame(8, 2), ship + Vector2(0, -40), 6.0, false, Color.WHITE, PI * 0.6)
			elif landed:
				draw_sprite("swamp/h_crow", 8, anim_frame(10, 8), ship + Vector2(0, -44), 6.0, true)
			else:
				var frame := anim_frame(14, 4) if thrusting else 2
				draw_sprite("swamp/h_crowFlap", 4, frame, center, 6.0)
				if thrusting:
					_draw_wind(center)
		_:
			var center := ship + Vector2(0, -70)
			if crashed:
				draw_sprite("graveyard/bat", 4, 0, ship + Vector2(0, -30), 6.0, false, Color(0.8, 0.6, 0.6), PI)
			else:
				var frame := anim_frame(14, 4) if thrusting else 3
				if landed:
					frame = 3
				draw_sprite("graveyard/bat", 4, frame, center, 6.0)
				if thrusting:
					_draw_wind(center)

	# Speed meter: green while slow enough to land safely.
	draw_rect(METER.grow(6), Color.BLACK)
	draw_rect(METER, Color(0, 0, 0, 0.4))
	var speed_ratio := clampf(velocity / METER_MAX_SPEED, 0.0, 1.0)
	var fill_h := METER.size.y * speed_ratio
	var safe := velocity <= safe_speed
	draw_rect(Rect2(METER.position.x, METER.end.y - fill_h, METER.size.x, fill_h), Color("06d6a0") if safe else Color("ef476f"))
	var safe_y := METER.end.y - METER.size.y * safe_speed / METER_MAX_SPEED
	draw_line(Vector2(METER.position.x - 12, safe_y), Vector2(METER.end.x + 12, safe_y), Color.WHITE, 5)
	draw_text_centered("SPEED", Vector2(METER.get_center().x - 10, METER.end.y + 40), 26)


## Wind pushed down by flapping wings.
func _draw_wind(center: Vector2) -> void:
	for i in 3:
		var x := center.x - 60 + i * 60
		var y := center.y + 70 + fmod(elapsed * 600.0 + i * 37.0, 90.0)
		draw_line(Vector2(x, y), Vector2(x, y + 36), Color(1, 1, 1, 0.45), 6)


## The golden idol on its rope, with brake sparks at the pulley while held.
func _draw_idol(crashed: bool) -> void:
	var pulley := Vector2(ship.x, 96)
	var top := ship + Vector2(0, -176)
	draw_line(Vector2(0, 92), Vector2(SCREEN.x, 92), Color("3a2a1a"), 14)
	if not crashed:
		draw_line(pulley, top, Color("c9a26b"), 6)
	draw_circle(pulley, 26, Color("2b2b2b"))
	draw_circle(pulley, 14, Color("8a7a5a"))
	if thrusting:
		for i in 5:
			var dir := Vector2.from_angle(randf_range(0.2, PI - 0.2))
			draw_line(pulley + dir * 20, pulley + dir * randf_range(40, 80), Color("ffe066"), 4)
	# The idol sheet is a grid: 6 columns of 22px cells, one row per idol.
	var tex := art("temple/t_idol")
	var cell := Rect2(22 * (1 if landed_glint() else 0), 22 * idol, 22, 22)
	var center := ship + Vector2(0, -88)
	var tint := Color(0.55, 0.45, 0.4) if crashed else Color.WHITE
	var rot := 0.35 if crashed else sin(elapsed * 3.0) * 0.04
	draw_set_transform(center + (Vector2(30, 20) if crashed else Vector2.ZERO), rot, Vector2(8, 8))
	draw_texture_rect_region(tex, Rect2(-11, -11, 22, 22), cell, tint)
	draw_set_transform(Vector2.ZERO)


## The idol glints the moment it settles.
func landed_glint() -> bool:
	return is_resolved and won and fmod(end_time, 0.3) < 0.15


## The sky, the landing spot and the stage's props.
func _draw_scenery(theme: Dictionary) -> void:
	var top: Color = theme.sky
	var low: Color = theme.sky_low
	for i in 14:
		draw_rect(Rect2(0, 1120.0 * i / 14.0, SCREEN.x, 1120.0 / 14.0 + 1), top.lerp(low, i / 13.0))
	var ground: Color = theme.ground
	var pad_x := ship.x
	match stage:
		Stages.TEMPLE:
			for row in 12:
				for col in 6:
					var x := col * 140.0 + (70.0 if row % 2 else 0.0) - 70.0
					draw_rect(Rect2(x, 140 + row * 72, 136, 68), Color("41503f").lerp(Color("2f3a33"), row / 12.0))
			for x in [60.0, 560.0]:
				draw_sprite("temple/t_torch", 12, anim_frame(10, 4, x), Vector2(x, 560), 6.0)
			draw_rect(Rect2(0, 1120, SCREEN.x, SCREEN.y - 1120), ground)
			# The pedestal.
			draw_rect(Rect2(pad_x - 110, GROUND_Y, 220, 34), Color("b9ad8f"))
			draw_rect(Rect2(pad_x - 90, GROUND_Y + 34, 180, 120), Color("8f856c"))
			draw_rect(Rect2(pad_x - 120, GROUND_Y + 150, 240, 40), Color("b9ad8f"))
			draw_rect(Rect2(pad_x - 110, GROUND_Y, 220, 8), Color("f2c14e"))
		Stages.SWAMP:
			draw_circle(Vector2(140, 220), 80, Color(0.85, 1.0, 0.6, 0.35))
			draw_sprite("swamp/tree_5", 1, 0, Vector2(570, 930), 3.0, false, Color(0.3, 0.42, 0.32))
			draw_rect(Rect2(0, 1120, SCREEN.x, SCREEN.y - 1120), ground)
			# A crooked branch reaching in from the left.
			var branch := PackedVector2Array([Vector2(-20, GROUND_Y + 40), Vector2(pad_x - 60, GROUND_Y + 12), Vector2(pad_x + 140, GROUND_Y + 6)])
			draw_polyline(branch, Color("2a1d14"), 40)
			draw_polyline(branch, Color("5a3d28"), 26)
			draw_line(Vector2(pad_x + 60, GROUND_Y + 8), Vector2(pad_x + 120, GROUND_Y - 40), Color("5a3d28"), 12)
		_:
			draw_circle(Vector2(140, 230), 80, Color("fff2c4"))
			draw_circle(Vector2(170, 210), 80, top)
			draw_sprite("graveyard/tree_3", 1, 0, Vector2(570, 930), 3.0, false, Color(0.4, 0.35, 0.5))
			draw_rect(Rect2(0, 1120, SCREEN.x, SCREEN.y - 1120), ground)
			draw_rect(Rect2(0, 1120, SCREEN.x, 10), ground.lightened(0.25))
			# A big tombstone to perch on.
			draw_rect(Rect2(pad_x - 96, GROUND_Y, 192, 140), Color("2a2238"))
			draw_rect(Rect2(pad_x - 88, GROUND_Y, 176, 132), Color("8d86a0"))
			draw_rect(Rect2(pad_x - 88, GROUND_Y, 176, 10), Color("b8b0cc"))
			draw_text_centered("R.I.P", Vector2(pad_x, GROUND_Y + 60), 40, Color("4a4560"))
