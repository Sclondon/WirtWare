extends Microgame
## DODGE! Survive the falling rocks until time runs out.

const FLOOR_Y := 620.0
const PLAYER_SIZE := Vector2(70, 80)
const PLAYER_SPEED := 720.0

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
			spawn_cooldown = randf_range(0.22, 0.4) / (0.7 + 0.3 * difficulty)
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
	rock.radius = randf_range(24, 40)
	# Aim some rocks at the player so standing still isn't safe.
	var x := player_x + randf_range(-60, 60) if randf() < 0.4 else randf_range(40, SCREEN.x - 40)
	rock.pos = Vector2(clampf(x, 40, SCREEN.x - 40), -rock.radius)
	rock.speed = randf_range(420, 560) * (0.85 + 0.15 * difficulty)
	rocks.append(rock)


func _player_rect() -> Rect2:
	return Rect2(player_x - PLAYER_SIZE.x / 2, FLOOR_Y - PLAYER_SIZE.y, PLAYER_SIZE.x, PLAYER_SIZE.y)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("8ecae6"))
	draw_rect(Rect2(0, FLOOR_Y, SCREEN.x, SCREEN.y - FLOOR_Y), Color("6a994e"))
	var hurt := is_resolved and not won
	var body := _player_rect()
	draw_rect(body, Color("777777") if hurt else Color("ff006e"))
	draw_face(body.get_center() + Vector2(0, -8), 40, not hurt)
	for rock in rocks:
		draw_circle(rock.pos, rock.radius, Color("5c4033"))
		draw_circle(rock.pos + Vector2(-rock.radius, -rock.radius) * 0.3, rock.radius * 0.3, Color("7f5f4a"))
