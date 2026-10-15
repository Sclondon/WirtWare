extends Microgame
## CLIMB! Pull up the cursed tower hand over hand: LEFT, RIGHT, LEFT...
## The same hand twice slips you down, and crows swoop past on harder levels.
## A homage to Hemlock's Tower.

const CLIMBER_X := 360.0
const START_Y := 930.0
const GOAL_Y := 340.0
const GROUND_Y := 1030.0
const TOWER := Rect2(150, 0, 420, GROUND_Y)
const WINDOW_POS := Vector2(360, 215)
const CROW_SPEED := 650.0
const CROW_WARNING := 0.6
## Tints for Hemlock's brick wall in each stage.
const WALL_TINTS := [Color(0.78, 0.66, 0.98), Color(1.0, 0.95, 0.62), Color(1, 1, 1)]

var steps := 0
var needed := 10
var last_side := ""
var stun := 0.0
var climber_y := START_Y
var fall_speed := 0.0
var landed := false
var elapsed := 0.0
## Each crow: {at (spawn time), y, dir, x, hit}.
var crows: Array[Dictionary] = []
var theme: Dictionary


func _init() -> void:
	prompt = "CLIMB!"
	controls_hint = "LEFT, RIGHT, LEFT, RIGHT..."
	touch_hint = "TAP LEFT, RIGHT, LEFT..."
	controls = Controls.LEFT_RIGHT
	duration = 4.5


func _on_start() -> void:
	theme = Stages.theme(stage)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	# Real time shrinks as the game speeds up, so ease off the pull count.
	needed = roundi([10.0, 11.0, 12.0][difficulty - 1] / sqrt(Engine.time_scale))
	var times: Array = [[], [1.5], [1.2, 2.4]][difficulty - 1]
	var dir := 1.0 if randf() < 0.5 else -1.0
	for at: float in times:
		crows.append({"at": at, "y": -999.0, "dir": dir, "x": -999.0, "hit": false, "swooped": false})
		dir = -dir


func _step_height() -> float:
	return (START_Y - GOAL_Y) / needed


func _process(delta: float) -> void:
	elapsed += delta
	stun = maxf(stun - delta, 0.0)
	if is_playing() and stun <= 0.0:
		for side: String in ["left", "right"]:
			if is_playing() and Input.is_action_just_pressed(side):
				_pull(side)

	if is_resolved and not won:
		# Lost the grip: fall to the ground.
		if not landed:
			fall_speed += 5200.0 * delta
			climber_y += fall_speed * delta
			if climber_y >= GROUND_Y - 60:
				climber_y = GROUND_Y - 60
				landed = true
				Sfx.play("thud")
				burst(Vector2(CLIMBER_X, GROUND_Y), theme.ground.lightened(0.4), 18, 420, 10)
				shake(12)
	elif is_resolved and won:
		climber_y = lerpf(climber_y, WINDOW_POS.y + 60, minf(delta * 10.0, 1.0))
	else:
		climber_y = lerpf(climber_y, START_Y - steps * _step_height(), minf(delta * 14.0, 1.0))

	for crow in crows:
		_update_crow(crow, delta)
	queue_redraw()


func _pull(side: String) -> void:
	if side == last_side:
		steps = maxi(steps - 1, 0)
		stun = 0.15
		Sfx.play("swish")
		popup("SLIP!", Vector2(CLIMBER_X + 150, climber_y - 40), Color("ff5d73"), 48)
		shake(6)
		return
	last_side = side
	steps += 1
	var hand := Vector2(CLIMBER_X + (-46.0 if side == "left" else 46.0), climber_y - 120)
	Sfx.play("tap", 0.9, 0.8 + 0.6 * steps / needed)
	burst(hand, theme.ground.lightened(0.5), 4, 200, 6)
	if steps >= needed:
		Sfx.play("coin")
		burst(WINDOW_POS, theme.glow, 26, 520, 11)
		popup("MADE IT!", WINDOW_POS + Vector2(0, 190), theme.glow, 70)
		win()


func _update_crow(crow: Dictionary, delta: float) -> void:
	var since := elapsed - float(crow.at)
	if since < 0.0:
		return
	if crow.y < -900.0:
		# Aim just above the climber's head, where the next pulls would take them.
		crow.y = clampf(climber_y - 150.0, GOAL_Y - 40, START_Y - 100)
		crow.x = -90.0 if crow.dir > 0 else SCREEN.x + 90
	if since < CROW_WARNING:
		return
	if crow.hit:
		crow.x += crow.dir * CROW_SPEED * delta
		crow.y -= 500.0 * delta
		return
	if not crow.swooped:
		crow.swooped = true
		Sfx.play("whoosh", 0.7)
	crow.x += crow.dir * CROW_SPEED * delta
	var body := Rect2(CLIMBER_X - 46, climber_y - 90, 92, 180)
	if is_playing() and circle_hits_rect(Vector2(crow.x, crow.y), 34.0, body):
		crow.hit = true
		steps = maxi(steps - 2, 0)
		last_side = ""
		stun = 0.3
		Sfx.play("hit")
		burst(Vector2(crow.x, crow.y), Color("1d1a24"), 16, 380, 9)
		popup("CAW!", Vector2(crow.x, crow.y - 70), Color.WHITE, 56)
		shake(10)


func _on_resolved(won_game: bool) -> void:
	if not won_game:
		fall_speed = 300.0
		Sfx.play("whoosh")
		popup("WAAAH!", Vector2(CLIMBER_X, climber_y - 150), Color("ff5d73"), 64)


func _draw() -> void:
	for i in 16:
		draw_rect(Rect2(0, i * 80.0, SCREEN.x, 81), theme.sky.lerp(theme.sky_low, i / 15.0))
	draw_circle(Vector2(640, 150), 60, Color(theme.glow, 0.5))
	draw_rect(Rect2(0, GROUND_Y, SCREEN.x, SCREEN.y - GROUND_Y), theme.ground)

	# The tower, in Hemlock's bricks tinted for the stage.
	var tint: Color = WALL_TINTS[posmod(stage, 3)]
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(3, 3))
	draw_texture_rect(art("swamp/h_brickwall"), Rect2(TOWER.position / 3.0, TOWER.size / 3.0), true, tint)
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(TOWER.position, Vector2(26, TOWER.size.y)), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(TOWER.end.x - 26, 0, 26, TOWER.size.y), Color(0, 0, 0, 0.35))
	# Progress marks up the wall, so it reads as a race to the top.
	for i in range(1, needed):
		var y := START_Y - i * _step_height()
		var done := i <= steps
		draw_line(Vector2(TOWER.position.x + 34, y), Vector2(TOWER.position.x + 58, y), theme.glow if done else Color(1, 1, 1, 0.25), 5)

	# The lit window at the top.
	var w := WINDOW_POS
	draw_circle(w, 120, Color(theme.glow, 0.15))
	draw_rect(Rect2(w + Vector2(-78, -40), Vector2(156, 130)), Color("2a2420"))
	draw_circle(w + Vector2(0, -40), 78, Color("2a2420"))
	var light: Color = theme.glow if not (is_resolved and won) else Color.WHITE
	draw_rect(Rect2(w + Vector2(-60, -40), Vector2(120, 116)), light)
	draw_circle(w + Vector2(0, -40), 60, light)
	draw_line(w + Vector2(0, -100), w + Vector2(0, 76), Color("2a2420"), 8)
	draw_line(w + Vector2(-60, 10), w + Vector2(60, 10), Color("2a2420"), 8)
	draw_rect(Rect2(w + Vector2(-96, 76), Vector2(192, 22)), Color("4a4038"))

	_draw_climber()

	for crow in crows:
		var since := elapsed - float(crow.at)
		if since < 0.0 or crow.y < -900.0:
			continue
		if since < CROW_WARNING:
			if int(since * 10.0) % 2 == 0:
				var edge := 40.0 if crow.dir > 0 else SCREEN.x - 40
				draw_text_centered("!", Vector2(edge, crow.y), 90, Color("ff5d73"))
			continue
		draw_sprite("swamp/h_crowFlap", 4, anim_frame(14, 4), Vector2(crow.x, crow.y), 4.0, crow.dir < 0)


func _draw_climber() -> void:
	var c := Vector2(CLIMBER_X, climber_y)
	var falling := is_resolved and not won
	var cloak: Color = theme.curtains[1]
	var skin := Color("f1c27d")
	# Which hand is up: the last one pulled. Both up while falling.
	var left_up := last_side == "left" or falling
	var right_up := last_side == "right" or falling
	var left_hand := c + (Vector2(-46, -120) if left_up else Vector2(-56, -20))
	var right_hand := c + (Vector2(46, -120) if right_up else Vector2(56, -20))
	var left_foot := c + (Vector2(-34, 70) if right_up else Vector2(-30, 104))
	var right_foot := c + (Vector2(34, 70) if left_up else Vector2(30, 104))
	if falling:
		left_foot = c + Vector2(-60, 60)
		right_foot = c + Vector2(60, 60)
	draw_line(c + Vector2(-18, 30), left_foot, Color("2b2d42"), 18)
	draw_line(c + Vector2(18, 30), right_foot, Color("2b2d42"), 18)
	draw_line(c + Vector2(-30, -34), left_hand, cloak.darkened(0.2), 18)
	draw_line(c + Vector2(30, -34), right_hand, cloak.darkened(0.2), 18)
	draw_circle(left_hand, 13, skin)
	draw_circle(right_hand, 13, skin)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-36, -44), c + Vector2(36, -44), c + Vector2(46, 44), c + Vector2(-46, 44)]), cloak)
	draw_rect(Rect2(c + Vector2(-22, -26), Vector2(44, 46)), cloak.darkened(0.35))
	# Back of the head under a pointed hood.
	draw_circle(c + Vector2(0, -66), 28, cloak.darkened(0.1))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-24, -80), c + Vector2(0, -122), c + Vector2(24, -80)]), cloak.darkened(0.1))
	if falling:
		draw_face(c + Vector2(0, -60), 34, false)
