extends Microgame
## DODGE! Survive the stuff falling from the sky until time runs out.
## Graveyard: Jon dodges skulls and pumpkins. Temple: a warrior dodges darts and
## stone relics in the rain. Swamp: a frog dodges goo globs and toxic barrels.

const FLOOR_Y := 1000.0
const PLAYER_SPEED := 640.0
## Hitbox per stage, a bit narrower than the sprite so grazes feel fair.
const PLAYER_SIZE: Array[Vector2] = [Vector2(60, 124), Vector2(66, 120), Vector2(80, 76)]

class Rock:
	var pos: Vector2
	var radius: float
	var speed: float
	## Darts are long: they hit along a line of this length, not just a circle.
	var length := 0.0
	var art: String
	var frames := 1
	var frame := 0
	var scale := 5.0
	var spin := 0.0
	var angle := 0.0

var player_x := SCREEN.x / 2
var facing := 1.0
var moving := false
var hop := 0.0
var rocks: Array[Rock] = []
var spawn_cooldown := 0.35
var hit_pos := Vector2.ZERO
var end_time := 0.0


func _init() -> void:
	prompt = "DODGE!"
	controls_hint = "ARROW KEYS"
	touch_hint = "LEFT / RIGHT"
	controls = Controls.LEFT_RIGHT
	duration = 4.5
	win_on_timeout = true


func _process(delta: float) -> void:
	moving = false
	if is_playing():
		var half := PLAYER_SIZE[stage].x / 2
		var axis := Input.get_axis("left", "right")
		player_x = clampf(player_x + axis * PLAYER_SPEED * delta, half, SCREEN.x - half)
		if absf(axis) > 0.1:
			facing = signf(axis)
			moving = true
		spawn_cooldown -= delta
		if spawn_cooldown <= 0.0:
			# Spaced for a 720-wide screen: about as many rocks per unit of width as feels fair.
			spawn_cooldown = randf_range(0.42, 0.68) / (0.7 + 0.3 * difficulty)
			_spawn_rock()
	# The frog hops as it moves; everyone hops for joy on a win.
	if moving and stage == Stages.SWAMP or (is_resolved and won):
		hop += delta * (9.0 if won else 12.0)
	else:
		hop = 0.0
	if is_resolved:
		end_time += delta

	var body := _player_rect()
	for rock in rocks:
		rock.pos.y += rock.speed * delta
		rock.angle += rock.spin * delta
		if not is_resolved and _rock_hits(rock, body):
			hit_pos = rock.pos
			lose()
	for i in range(rocks.size() - 1, -1, -1):
		var rock := rocks[i]
		if rock.pos.y > FLOOR_Y - rock.radius * 0.5:
			# Smash into the ground.
			burst(Vector2(rock.pos.x, FLOOR_Y), _splash_color(), 6, 260.0, 7.0)
			Sfx.play("splash" if stage == Stages.SWAMP else "thud", 0.25)
			rocks.remove_at(i)
	queue_redraw()


func _rock_hits(rock: Rock, body: Rect2) -> bool:
	if rock.length <= 0.0:
		return circle_hits_rect(rock.pos, rock.radius * 0.85, body)
	for k in 3:
		var p := rock.pos + Vector2(0, (k - 1) * rock.length / 2)
		if circle_hits_rect(p, rock.radius, body):
			return true
	return false


func _spawn_rock() -> void:
	var rock := Rock.new()
	match stage:
		Stages.GRAVEYARD:
			rock.scale = [5.0, 6.0].pick_random()
			rock.radius = rock.scale * 7.0
			if randf() < 0.5:
				rock.art = "graveyard/skull"
				rock.spin = randf_range(-4, 4)
			else:
				# The pumpkin fills less of its frame than the skull, so draw it bigger.
				rock.art = "graveyard/pumpkin"
				rock.frames = 6
				rock.frame = randi() % 6
				rock.scale += 1.0
		Stages.TEMPLE:
			if randf() < 0.55:
				rock.art = "temple/t_dart_falling"
				rock.scale = 7.0
				rock.radius = 16.0
				rock.length = 80.0
			else:
				rock.art = "temple/t_relics"
				rock.frames = 8
				rock.frame = randi() % 4  # the stone ones
				rock.scale = [7.0, 8.0].pick_random()
				rock.radius = rock.scale * 4.6
				rock.spin = randf_range(-3, 3)
		_:
			if randf() < 0.55:
				rock.art = "swamp/goo_glob"
				rock.frames = 2
				rock.scale = [8.0, 9.0].pick_random()
				rock.radius = rock.scale * 3.5
			else:
				rock.art = "swamp/toxic_barrel"
				rock.scale = 5.0
				rock.radius = 36.0
				rock.spin = randf_range(-2.5, 2.5)
	# Aim some rocks at the player so standing still isn't safe.
	var x := player_x + randf_range(-50, 50) if randf() < 0.35 else randf_range(40, SCREEN.x - 40)
	rock.pos = Vector2(clampf(x, 40, SCREEN.x - 40), -rock.radius - rock.length)
	rock.speed = randf_range(600, 760) * (0.85 + 0.15 * difficulty)
	rocks.append(rock)


func _player_rect() -> Rect2:
	var size := PLAYER_SIZE[stage]
	return Rect2(player_x - size.x / 2, FLOOR_Y - size.y, size.x, size.y)


func _splash_color() -> Color:
	return [Color("c9c2d6"), Color("8a8270"), Color("8ee04a")][stage]


func _on_resolved(result: bool) -> void:
	if result:
		popup("SAFE!", Vector2(player_x, FLOOR_Y - 200), Stages.theme(stage).glow, 64)
		Sfx.play("jump", 0.6)
	else:
		burst(hit_pos, _splash_color(), 18, 520.0, 12.0)
		Sfx.play("splash" if stage == Stages.SWAMP else "crunch")
		Sfx.play("hit", 0.8)
		popup("OUCH!", Vector2(player_x, FLOOR_Y - 220), Color("ef476f"), 64)


func _draw() -> void:
	var theme := Stages.theme(stage)
	for i in 12:
		draw_rect(Rect2(0, FLOOR_Y * i / 12.0, SCREEN.x, FLOOR_Y / 12.0 + 1), (theme.sky as Color).lerp(theme.sky_low, i / 11.0))
	match stage:
		Stages.GRAVEYARD:
			draw_circle(Vector2(580, 190), 70, Color("fff2c4"))
			draw_circle(Vector2(552, 172), 70, (theme.sky as Color).lerp(theme.sky_low, 2.0 / 11.0))
			draw_sprite("graveyard/grave_2", 1, 0, Vector2(120, FLOOR_Y - 44), 3.0, false, Color(0.6, 0.55, 0.7))
			draw_sprite("graveyard/grave_1_small", 1, 0, Vector2(600, FLOOR_Y - 44), 3.0, false, Color(0.6, 0.55, 0.7))
		Stages.TEMPLE:
			for row in 5:
				for col in 6:
					var x := col * 150.0 + (75.0 if row % 2 else 0.0) - 60.0
					draw_rect(Rect2(x, 640 + row * 72, 146, 68), Color("4d5a4f").lerp(Color("2f3a33"), row / 5.0))
			for i in 34:
				var p := Vector2(fmod(i * 97.0 + _clock * 40.0, 760.0) - 20, fmod(i * 173.0 + _clock * 900.0, FLOOR_Y))
				draw_line(p, p + Vector2(-4, 26), Color(0.7, 0.9, 1.0, 0.35), 2.0)
		_:
			# A sickly moon glowing through the fog.
			draw_circle(Vector2(170, 200), 95, Color(theme.glow, 0.08))
			draw_circle(Vector2(170, 200), 55, Color(theme.glow, 0.4))
			draw_sprite("swamp/tree_5", 1, 0, Vector2(610, FLOOR_Y - 170), 2.8, false, Color(0.45, 0.6, 0.45))
			for i in 4:
				draw_rect(Rect2(-60 + sin(_clock * 0.7 + i) * 50.0, FLOOR_Y - 120 + i * 26, 840, 30), Color(0.7, 0.95, 0.6, 0.07))
	var ground: Color = theme.ground
	draw_rect(Rect2(0, FLOOR_Y, SCREEN.x, SCREEN.y - FLOOR_Y), ground)
	draw_rect(Rect2(0, FLOOR_Y, SCREEN.x, 14), ground.lightened(0.3))

	# Shadows grow as things get close, so you can see where they'll land.
	for rock in rocks:
		var closeness := clampf(rock.pos.y / FLOOR_Y, 0.0, 1.0)
		if closeness > 0.05:
			draw_colored_polygon(ellipse_points(Vector2(rock.pos.x, FLOOR_Y + 8), Vector2(rock.radius * 1.2 * closeness, 10 * closeness)), Color(0, 0, 0, 0.45 * closeness))

	_draw_player()

	for rock in rocks:
		if stage == Stages.SWAMP:
			# Toxic glow, so dark green things read against the dark green fog.
			draw_circle(rock.pos, rock.radius * 1.35, Color(theme.glow, 0.2))
		var frame := rock.frame
		if rock.art == "swamp/goo_glob":
			frame = anim_frame(8, 2, rock.pos.x)
		draw_sprite(rock.art, rock.frames, frame, rock.pos, rock.scale, false, Color.WHITE, rock.angle)


func _draw_player() -> void:
	var hurt := is_resolved and not won
	var feet := Vector2(player_x, FLOOR_Y)
	var tint := Color(1, 0.45, 0.45) if hurt else Color.WHITE
	var lift := absf(sin(hop)) * (40.0 if won else 22.0)
	# Knocked flat when hit.
	var fall := clampf(end_time * 8.0, 0.0, 1.0) * (PI / 2) * -facing if hurt else 0.0
	draw_colored_polygon(ellipse_points(feet + Vector2(0, 6), Vector2(44, 10)), Color(0, 0, 0, 0.35))
	match stage:
		Stages.GRAVEYARD:
			var center := feet + Vector2(0, -72 - lift)
			if moving:
				draw_sprite("graveyard/run_jon", 4, anim_frame(12, 4), center, 6.0, facing < 0, tint, fall)
			else:
				draw_sprite("graveyard/idle_jon", 5, anim_frame(6, 5), center, 6.0, facing < 0, tint, fall)
		Stages.TEMPLE:
			var bob := absf(sin(_clock * 14.0)) * 6.0 if moving else 0.0
			var frame := (1 if facing < 0 else 3) if moving else 0
			draw_sprite("temple/warrior", 5, frame, feet + Vector2(0, -69 - lift - bob), 6.0, false, tint, fall)
		_:
			draw_circle(feet + Vector2(0, -50 - lift), 70, Color(Stages.theme(stage).glow, 0.12))
			# Squash on landing, stretch in the air.
			var s := sin(hop)
			var squash := Vector2(1.0 - 0.15 * s, 1.0 + 0.2 * s) if lift > 2.0 else Vector2(1.12, 0.88) if moving else Vector2.ONE
			draw_set_transform(feet + Vector2(0, -lift), fall, squash * 7.0)
			var tex := art("swamp/h_frog")
			draw_texture_rect(tex, Rect2(-8, -16, 16, 16), false, tint)
			draw_set_transform(Vector2.ZERO)
