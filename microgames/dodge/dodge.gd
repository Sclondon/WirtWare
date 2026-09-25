extends Microgame
## DODGE! Survive the falling rocks until time runs out.

const FLOOR_Y := 1000.0
const PLAYER_SIZE := Vector2(80, 90)
const PLAYER_SPEED := 640.0

class Rock:
	var pos: Vector2
	var radius: float
	var speed: float

var player_x := SCREEN.x / 2
var rocks: Array[Rock] = []
var spawn_cooldown := 0.0


func _init() -> void:
	prompt = "DODGE!"
	controls_hint = "ARROW KEYS"
	touch_hint = "LEFT / RIGHT"
	controls = Controls.LEFT_RIGHT
	duration = 4.5
	win_on_timeout = true


func _process(delta: float) -> void:
	if is_playing():
		var half := PLAYER_SIZE.x / 2
		player_x = clampf(player_x + Input.get_axis("left", "right") * PLAYER_SPEED * delta, half, SCREEN.x - half)
		spawn_cooldown -= delta
		if spawn_cooldown <= 0.0:
			# Spaced for a 720-wide screen: about as many rocks per unit of width as feels fair.
			spawn_cooldown = randf_range(0.42, 0.68) / (0.7 + 0.3 * difficulty)
			_spawn_rock()

	var body := _player_rect()
	for rock in rocks:
		rock.pos.y += rock.speed * delta
		if not is_resolved and circle_hits_rect(rock.pos, rock.radius * 0.9, body):
			lose()
	for i in range(rocks.size() - 1, -1, -1):
		if rocks[i].pos.y > SCREEN.y + 80:
			rocks.remove_at(i)
	queue_redraw()


func _spawn_rock() -> void:
	var rock := Rock.new()
	rock.radius = randf_range(26, 44)
	# Aim some rocks at the player so standing still isn't safe.
	var x := player_x + randf_range(-50, 50) if randf() < 0.35 else randf_range(40, SCREEN.x - 40)
	rock.pos = Vector2(clampf(x, 40, SCREEN.x - 40), -rock.radius)
	rock.speed = randf_range(600, 760) * (0.85 + 0.15 * difficulty)
	rocks.append(rock)


func _player_rect() -> Rect2:
	return Rect2(player_x - PLAYER_SIZE.x / 2, FLOOR_Y - PLAYER_SIZE.y, PLAYER_SIZE.x, PLAYER_SIZE.y)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("8ecae6"))
	draw_circle(Vector2(590, 170), 70, Color("ffd166"))
	draw_rect(Rect2(0, FLOOR_Y, SCREEN.x, SCREEN.y - FLOOR_Y), Color("6a994e"))
	draw_rect(Rect2(0, FLOOR_Y, SCREEN.x, 18), Color("80b918"))
	# Shadows grow as rocks get close, so you can see where they'll land.
	for rock in rocks:
		var closeness := clampf(rock.pos.y / FLOOR_Y, 0.0, 1.0)
		if closeness > 0.05 and closeness < 1.0:
			draw_colored_polygon(ellipse_points(Vector2(rock.pos.x, FLOOR_Y + 8), Vector2(rock.radius * closeness, 9 * closeness)), Color(0, 0, 0, 0.35 * closeness))
	var hurt := is_resolved and not won
	var body := _player_rect()
	draw_rect(body, Color("777777") if hurt else Color("ff006e"))
	draw_face(body.get_center() + Vector2(0, -8), 44, not hurt)
	for rock in rocks:
		draw_circle(rock.pos, rock.radius, Color("5c4033"))
		draw_circle(rock.pos + Vector2(-rock.radius, -rock.radius) * 0.3, rock.radius * 0.3, Color("7f5f4a"))
