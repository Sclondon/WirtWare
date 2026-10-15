extends Microgame
## DRAW! Wait for the signal, then throw first. Fire too early, or too late,
## and the rival gets you. Jon faces a zombie or the reaper at midnight in the
## graveyard, a jaguar warrior in the temple, and the swamp thing in the swamp.

const GROUND_Y := 900.0
const PLAYER_X := 160.0
const RIVAL_X := 560.0
const SIGN_POS := Vector2(360, 300)
const STAKE_TIME := 0.12

var elapsed := 0.0
var signal_time := 1.5
var window := 0.5
var too_soon := false
## Time since the duel was decided.
var end_time := 0.0
var stake_hit := false
## Graveyard only: 0 = zombie, 1 = the reaper.
var rival_kind := 0


func _init() -> void:
	prompt = "DRAW!"
	controls_hint = "SPACE WHEN IT SAYS FIRE"
	touch_hint = "TAP WHEN IT SAYS FIRE"
	controls = Controls.BUTTON
	duration = 3.5


func _on_start() -> void:
	signal_time = randf_range(1.1, 2.0)
	rival_kind = randi() % 2
	# The window is in game time, so widen it with the speed-up to keep the
	# real-time reaction window fair.
	window = [0.6, 0.45, 0.38][difficulty - 1] * Engine.time_scale


func _process(delta: float) -> void:
	if is_playing():
		var before := elapsed < signal_time
		elapsed += delta
		if before and elapsed >= signal_time:
			Sfx.play("zap", 0.9, 1.4)
		if Input.is_action_just_pressed("action"):
			if elapsed < signal_time:
				too_soon = true
				lose()
			else:
				win()
		elif elapsed > signal_time + window:
			lose()
	elif is_resolved:
		end_time += delta
		if won and not stake_hit and end_time >= STAKE_TIME:
			stake_hit = true
			Sfx.play("hit")
			burst(_rival_center(0.0), Color.WHITE, 18, 520.0, 12.0)
			burst(_rival_center(0.0), Stages.theme(stage).accent, 10, 380.0, 10.0)
			shake(10)
	queue_redraw()


func _on_resolved(result: bool) -> void:
	if result:
		Sfx.play("swish")
		return
	# The rival strikes.
	match stage:
		Stages.SWAMP:
			Sfx.play("squish")
		Stages.TEMPLE:
			Sfx.play("hit", 1.0, 0.8)
		_:
			Sfx.play("munch" if rival_kind == 0 else "swish", 1.0, 0.8)
	var at := Vector2(PLAYER_X, GROUND_Y - 100)
	burst(at, Color("ef476f"), 12, 380.0, 10.0)



## Rival sprite: [path, frames, frame, scale, flip, half size (x, y)].
func _rival_sprite() -> Array:
	match stage:
		Stages.TEMPLE:
			return ["temple/t_warrior", 5, 3, 10.0, false, Vector2(85, 115)]
		Stages.SWAMP:
			return ["swamp/swampthing", 6, anim_frame(6, 6), 5.0, true, Vector2(85, 145)]
	if rival_kind == 1:
		return ["graveyard/reaper", 4, anim_frame(5, 4), 6.0, true, Vector2(108, 120)]
	return ["graveyard/zombie", 6, anim_frame(6, 6), 10.0, true, Vector2(80, 120)]


## Where the rival's middle is, lying down by [param fall] (0..1).
func _rival_center(fall: float) -> Vector2:
	var half: Vector2 = _rival_sprite()[5]
	var lunge := 0.0
	if is_resolved and not won:
		lunge = -minf(end_time / 0.12, 1.0) * 200.0
	return Vector2(RIVAL_X + lunge, GROUND_Y - lerpf(half.y, half.x, fall))


func _draw() -> void:
	var theme := Stages.theme(stage)
	_draw_scenery(theme)
	var fired := elapsed >= signal_time and not too_soon

	# Jon: steady, then leaning into the throw, or knocked flat.
	var jon_fall := 0.0
	var jon_lean := 0.0
	if is_resolved and won:
		jon_lean = 0.25
	elif is_resolved:
		jon_fall = minf(maxf(end_time - 0.1, 0.0) / 0.15, 1.0)
	var jon := Vector2(PLAYER_X, GROUND_Y - lerpf(120.0, 80.0, jon_fall))
	draw_colored_polygon(ellipse_points(Vector2(PLAYER_X, GROUND_Y), Vector2(70, 14)), Color(0, 0, 0, 0.35))
	draw_sprite("graveyard/idle_jon", 5, anim_frame(6, 5), jon, 10.0, false,
		Color(1, 0.7, 0.7) if jon_fall > 0.0 else Color.WHITE, jon_lean - jon_fall * PI / 2)

	# The rival: goes down when the stake lands, lunges when you blow it.
	var r := _rival_sprite()
	var rival_fall := minf((end_time - STAKE_TIME) / 0.15, 1.0) if stake_hit else 0.0
	var rival := _rival_center(rival_fall)
	var rival_tint := Color.WHITE
	if stake_hit and end_time < STAKE_TIME + 0.1:
		rival_tint = Color(3, 3, 3)
	draw_colored_polygon(ellipse_points(Vector2(rival.x, GROUND_Y), Vector2(80, 14)), Color(0, 0, 0, 0.35))
	draw_sprite(r[0], r[1], r[2], rival, r[3], r[4], rival_tint, rival_fall * PI / 2)

	# The stake in flight.
	if is_resolved and won and not stake_hit:
		var k := end_time / STAKE_TIME
		var p := Vector2(lerpf(PLAYER_X + 60, RIVAL_X - 40, k), GROUND_Y - 130)
		draw_line(p - Vector2(80, 0), p, Color(1, 1, 1, 0.5), 6)
		draw_sprite("graveyard/wood_stake_shot", 1, 0, p, 5.0, false, Color.WHITE, PI / 2)

	if too_soon:
		draw_text_centered("TOO SOON!", SIGN_POS, 96, Color("ef476f"))
	elif fired and not (is_resolved and not won):
		var flash := 1.0 + 0.3 * maxf(1.0 - (elapsed - signal_time) * 6.0, 0.0)
		draw_text_centered("FIRE!", SIGN_POS, int(150 * flash), Color("ef476f") if not is_resolved else Color.WHITE)
	elif is_resolved and not won:
		draw_text_centered("TOO SLOW!", SIGN_POS, 96, Color("ef476f"))
	elif elapsed > 0.9:
		draw_text_centered("WAIT...", SIGN_POS, 64, Color(1, 1, 1, 0.6))


## Night sky, a big moon behind the duel, and the stage's props.
func _draw_scenery(theme: Dictionary) -> void:
	var top: Color = theme.sky
	var low: Color = theme.sky_low
	var fired := elapsed >= signal_time and not too_soon and not is_resolved
	for i in 12:
		var c := top.lerp(low, i / 11.0)
		draw_rect(Rect2(0, GROUND_Y * i / 12.0, SCREEN.x, GROUND_Y / 12.0 + 1), c.lightened(0.15) if fired else c)
	var moon: Color = [Color("fff2c4"), Color("f2c14e"), Color("d9f7a0")][stage]
	draw_circle(Vector2(360, GROUND_Y - 260), 230, Color(moon, 0.15))
	draw_circle(Vector2(360, GROUND_Y - 260), 180, Color(moon, 0.85))
	var ground: Color = theme.ground
	match stage:
		Stages.GRAVEYARD:
			draw_sprite("graveyard/tree_3", 1, 0, Vector2(730, GROUND_Y - 190), 3.0, false, Color(0.35, 0.3, 0.45))
			draw_sprite("graveyard/grave_2", 1, 0, Vector2(300, GROUND_Y - 40), 3.0, false, Color(0.55, 0.5, 0.65))
			draw_sprite("graveyard/grave_1_small", 1, 0, Vector2(420, GROUND_Y - 36), 2.5, false, Color(0.55, 0.5, 0.65))
		Stages.TEMPLE:
			for row in 4:
				for col in 6:
					var x := col * 140.0 + (70.0 if row % 2 else 0.0) - 70.0
					draw_rect(Rect2(x, GROUND_Y - 4 * 72 + row * 72, 136, 68), Color("4d5a4f").lerp(Color("3a463e"), row / 4.0))
			for x in [40.0, 680.0]:
				draw_sprite("temple/t_torch", 12, anim_frame(10, 4, x), Vector2(x, GROUND_Y - 360), 6.0)
		Stages.SWAMP:
			draw_sprite("swamp/tree_5", 1, 0, Vector2(70, GROUND_Y - 190), 3.0, false, Color(0.3, 0.42, 0.32))
			draw_sprite("graveyard/tree", 1, 0, Vector2(660, GROUND_Y - 190), 3.0, false, Color(0.3, 0.42, 0.32))
	draw_rect(Rect2(0, GROUND_Y, SCREEN.x, SCREEN.y - GROUND_Y), ground)
	draw_rect(Rect2(0, GROUND_Y, SCREEN.x, 10), ground.lightened(0.25))
	if stage == Stages.SWAMP:
		for i in 4:
			draw_rect(Rect2(-60 + sin(elapsed * 0.7 + i) * 50.0, GROUND_Y - 40 + i * 26, 840, 30), Color(0.7, 0.95, 0.6, 0.07))
