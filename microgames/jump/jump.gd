extends Microgame
## JUMP! Hop over the things rushing toward you.
## Graveyard: Jon runs over graves. Temple: a warrior leaps dart traps.
## Swamp: a frog hops over toxic barrels.

const GROUND_Y := 900.0
const PLAYER_X := 160.0
const GRAVITY := 2800.0
const JUMP_VELOCITY := -1300.0
## A press this long before landing still jumps, so quick double hops are fair.
const BUFFER := 0.15
## Per stage: hitbox of the runner and of an obstacle.
const PLAYER_SIZE: Array[Vector2] = [Vector2(60, 124), Vector2(66, 120), Vector2(92, 86)]
const OBSTACLE_SIZE: Array[Vector2] = [Vector2(76, 96), Vector2(84, 84), Vector2(76, 90)]

var player_y := GROUND_Y
var velocity_y := 0.0
## X positions of the obstacles.
var obstacles: Array[float] = []
var kinds: Array[int] = []
var scroll_speed := 700.0
var scroll := 0.0
var buffered := 0.0
var land_squash := 0.0
var tumble := 0.0
var cleared := 0


func _init() -> void:
	prompt = "JUMP!"
	controls_hint = "PRESS SPACE"
	touch_hint = "TAP THE BUTTON"
	controls = Controls.BUTTON
	duration = 3.5
	win_on_timeout = true


func _on_start() -> void:
	scroll_speed = 600.0 + 120.0 * difficulty
	var x := SCREEN.x + randf_range(350, 600)
	obstacles.append(x)
	if difficulty >= 2:
		# Far enough apart to land from the first jump before the second.
		obstacles.append(x + scroll_speed * randf_range(1.15, 1.35))
	for i in obstacles.size():
		kinds.append(randi() % 2)


func _process(delta: float) -> void:
	var stopped := is_resolved and not won
	buffered = maxf(buffered - delta, 0.0)
	land_squash = maxf(land_squash - delta * 5.0, 0.0)
	if is_playing() and Input.is_action_just_pressed("action"):
		buffered = BUFFER
	if is_playing() and player_y >= GROUND_Y and buffered > 0.0:
		buffered = 0.0
		velocity_y = JUMP_VELOCITY
		Sfx.play("spring" if stage == Stages.SWAMP else "jump")
		burst(Vector2(PLAYER_X, GROUND_Y), _dust(), 6, 200.0, 7.0)
	if stopped:
		tumble += delta
	else:
		var was_up := player_y < GROUND_Y
		velocity_y += GRAVITY * delta
		player_y = minf(player_y + velocity_y * delta, GROUND_Y)
		if player_y >= GROUND_Y:
			velocity_y = 0.0
			if was_up:
				land_squash = 1.0
				Sfx.play("thud", 0.4)
				burst(Vector2(PLAYER_X, GROUND_Y), _dust(), 6, 200.0, 7.0)
		scroll += scroll_speed * delta
		var body := _player_rect().grow(-8)
		for i in obstacles.size():
			var before := obstacles[i]
			obstacles[i] -= scroll_speed * delta
			if not is_resolved and body.intersects(_obstacle_rect(obstacles[i])):
				lose()
			elif before >= PLAYER_X - 40 and obstacles[i] < PLAYER_X - 40 and not is_resolved:
				cleared += 1
				popup("NICE!", Vector2(PLAYER_X + 40, player_y - 160), Stages.theme(stage).glow, 44)
	queue_redraw()


func _on_resolved(result: bool) -> void:
	if result:
		popup("MADE IT!", Vector2(360, 500), Stages.theme(stage).glow, 64)
	else:
		burst(Vector2(PLAYER_X + 30, player_y - 40), _dust(), 16, 420.0, 10.0)
		Sfx.play("hit")
		shake(12.0)


func _dust() -> Color:
	return [Color("8a7ea3"), Color("a39a85"), Color("8ee04a")][stage]


func _player_rect() -> Rect2:
	var size := PLAYER_SIZE[stage]
	return Rect2(PLAYER_X - size.x / 2, player_y - size.y, size.x, size.y)


func _obstacle_rect(x: float) -> Rect2:
	var size := OBSTACLE_SIZE[stage]
	return Rect2(x - size.x / 2, GROUND_Y - size.y, size.x, size.y)


func _draw() -> void:
	var theme := Stages.theme(stage)
	for i in 12:
		draw_rect(Rect2(0, GROUND_Y * i / 12.0, SCREEN.x, GROUND_Y / 12.0 + 1), (theme.sky as Color).lerp(theme.sky_low, i / 11.0))
	# Far scenery scrolls slower than the ground.
	var far := scroll * 0.3
	match stage:
		Stages.GRAVEYARD:
			draw_circle(Vector2(540, 240), 80, Color("fff2c4"))
			draw_circle(Vector2(510, 222), 80, (theme.sky as Color).lerp(theme.sky_low, 2.5 / 11.0))
			for i in 3:
				var x := fposmod(i * 330.0 - far, SCREEN.x + 330) - 160
				draw_sprite("graveyard/tree", 1, 0, Vector2(x, GROUND_Y - 170), 3.0, i % 2 == 1, Color(0.45, 0.4, 0.55))
		Stages.TEMPLE:
			for i in 4:
				var x := fposmod(i * 260.0 - far, SCREEN.x + 260) - 130
				draw_colored_polygon(PackedVector2Array([
					Vector2(x - 120, GROUND_Y), Vector2(x - 70, GROUND_Y - 260), Vector2(x + 70, GROUND_Y - 260), Vector2(x + 120, GROUND_Y),
				]), Color("2f4a40"))
				draw_rect(Rect2(x - 70, GROUND_Y - 280, 140, 22), Color("3d5c4f"))
			for i in 30:
				var p := Vector2(fmod(i * 97.0 + _clock * 40.0, 760.0) - 20, fmod(i * 173.0 + _clock * 900.0, GROUND_Y))
				draw_line(p, p + Vector2(-4, 26), Color(0.7, 0.9, 1.0, 0.3), 2.0)
		_:
			# A sickly moon glowing through the fog.
			draw_circle(Vector2(170, 220), 95, Color(theme.glow, 0.08))
			draw_circle(Vector2(170, 220), 55, Color(theme.glow, 0.4))
			for i in 3:
				var x := fposmod(i * 330.0 - far, SCREEN.x + 330) - 160
				draw_sprite("swamp/tree_5", 1, 0, Vector2(x, GROUND_Y - 170), 3.0, i % 2 == 1, Color(0.4, 0.55, 0.4))
	var ground: Color = theme.ground
	draw_rect(Rect2(0, GROUND_Y, SCREEN.x, SCREEN.y - GROUND_Y), ground)
	draw_rect(Rect2(0, GROUND_Y, SCREEN.x, 14), ground.lightened(0.3))
	for i in 11:
		var x := fposmod(i * 90.0 - scroll, SCREEN.x + 90) - 45
		draw_line(Vector2(x, GROUND_Y + 40), Vector2(x + 30, GROUND_Y + 40), ground.darkened(0.3), 5)

	for i in obstacles.size():
		_draw_obstacle(obstacles[i], kinds[i])
	_draw_runner()


func _draw_obstacle(x: float, kind: int) -> void:
	var foot := Vector2(x, GROUND_Y)
	match stage:
		Stages.GRAVEYARD:
			draw_sprite(["graveyard/grave_2", "graveyard/grave_1_small"][kind], 1, 0, foot + Vector2(0, -62), 4.0)
		Stages.TEMPLE:
			# A stone base bristling with darts.
			draw_rect(Rect2(x - 52, GROUND_Y - 24, 104, 24), Color("6b6355"))
			draw_rect(Rect2(x - 52, GROUND_Y - 24, 104, 6), Color("8c836f"))
			for k in 3:
				draw_sprite("temple/t_dart_stuck", 2, k % 2, foot + Vector2(-30 + k * 30, -57), 6.0, k == 2)
		_:
			draw_circle(foot + Vector2(0, -48), 62, Color(Stages.theme(stage).glow, 0.15))
			draw_sprite("swamp/toxic_barrel", 1, 0, foot + Vector2(0, -48), 6.0)


func _draw_runner() -> void:
	var hurt := is_resolved and not won
	var feet := Vector2(PLAYER_X, player_y)
	var tint := Color(1, 0.45, 0.45) if hurt else Color.WHITE
	var air := player_y < GROUND_Y - 1.0
	var spin := -clampf(tumble * 6.0, 0.0, 1.0) * PI / 2 if hurt else 0.0
	var shadow := clampf(1.0 - (GROUND_Y - player_y) / 400.0, 0.3, 1.0)
	draw_colored_polygon(ellipse_points(Vector2(PLAYER_X, GROUND_Y + 6), Vector2(40 * shadow, 9 * shadow)), Color(0, 0, 0, 0.35))
	# Stretch going up, squash on landing.
	var stretch := Vector2.ONE
	if air:
		var k := clampf(-velocity_y / 1300.0, -1.0, 1.0)
		stretch = Vector2(1.0 - 0.12 * k, 1.0 + 0.15 * k)
	elif land_squash > 0.0:
		stretch = Vector2(1.0 + 0.25 * land_squash, 1.0 - 0.2 * land_squash)
	var frame := 1 if air else anim_frame(12, 4)
	match stage:
		Stages.GRAVEYARD:
			if hurt:
				frame = 0
			_draw_scaled("graveyard/run_jon", 4, frame, feet, Vector2(16, 24), stretch * 6.0, tint, spin)
		Stages.TEMPLE:
			var bob := 0.0 if air or hurt else absf(sin(_clock * 16.0)) * 6.0
			_draw_scaled("temple/warrior", 5, 3, feet + Vector2(0, -bob), Vector2(17, 23), stretch * 6.0, tint, spin)
		_:
			# The frog hops along even on the ground.
			var hop := 0.0 if air or hurt else absf(sin(_clock * 12.0)) * 14.0
			draw_circle(feet + Vector2(0, -60 - hop), 74, Color(Stages.theme(stage).glow, 0.12))
			_draw_scaled("swamp/h_frog", 1, 0, feet + Vector2(0, -hop), Vector2(16, 16), stretch * 8.0, tint, spin)


## Draws one frame standing on [param feet], scaled from the feet so squash keeps it grounded.
func _draw_scaled(path: String, frames: int, frame: int, feet: Vector2, size: Vector2, scale: Vector2, tint: Color, rotation: float) -> void:
	draw_set_transform(feet, rotation, scale)
	draw_texture_rect_region(art(path), Rect2(-size.x / 2, -size.y, size.x, size.y), Rect2(size.x * frame, 0, size.x, size.y), tint)
	draw_set_transform(Vector2.ZERO)
