extends Microgame
## JUMP! Hop over the cacti rushing toward you.

const GROUND_Y := 900.0
const PLAYER_X := 160.0
const PLAYER_SIZE := Vector2(64, 76)
const CACTUS_SIZE := Vector2(50, 100)
const GRAVITY := 2800.0
const JUMP_VELOCITY := -1300.0

var player_y := GROUND_Y
var velocity_y := 0.0
var cacti: Array[float] = []
var scroll_speed := 700.0
var scroll := 0.0


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
	cacti.append(x)
	if difficulty >= 2:
		# Far enough apart to land from the first jump before the second.
		cacti.append(x + scroll_speed * randf_range(1.15, 1.35))


func _process(delta: float) -> void:
	var stopped := is_resolved and not won
	if is_playing() and player_y >= GROUND_Y and Input.is_action_just_pressed("action"):
		velocity_y = JUMP_VELOCITY
	if not stopped:
		velocity_y += GRAVITY * delta
		player_y = minf(player_y + velocity_y * delta, GROUND_Y)
		if player_y >= GROUND_Y:
			velocity_y = 0.0
		scroll += scroll_speed * delta
		var body := _player_rect().grow(-8)
		for i in cacti.size():
			cacti[i] -= scroll_speed * delta
			if not is_resolved and body.intersects(_cactus_rect(cacti[i])):
				lose()
	queue_redraw()


func _player_rect() -> Rect2:
	return Rect2(PLAYER_X - PLAYER_SIZE.x / 2, player_y - PLAYER_SIZE.y, PLAYER_SIZE.x, PLAYER_SIZE.y)


func _cactus_rect(x: float) -> Rect2:
	return Rect2(x - CACTUS_SIZE.x / 2, GROUND_Y - CACTUS_SIZE.y, CACTUS_SIZE.x, CACTUS_SIZE.y)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("ffe8d6"))
	draw_circle(Vector2(540, 260), 90, Color("ffb703"))
	for i in 3:
		draw_colored_polygon(PackedVector2Array([
			Vector2(i * 300 - 100, GROUND_Y), Vector2(i * 300 + 60, GROUND_Y - 220 - i * 40), Vector2(i * 300 + 220, GROUND_Y),
		]), Color("f4c7a8"))
	draw_rect(Rect2(0, GROUND_Y, SCREEN.x, SCREEN.y - GROUND_Y), Color("cb997e"))
	for i in 11:
		var x := fposmod(i * 90.0 - scroll, SCREEN.x + 90) - 45
		draw_line(Vector2(x, GROUND_Y + 30), Vector2(x + 30, GROUND_Y + 30), Color("a47148"), 4)

	for x in cacti:
		var r := _cactus_rect(x)
		var green := Color("2d6a4f")
		draw_rect(r, green)
		draw_rect(Rect2(r.position + Vector2(-20, 30), Vector2(20, 12)), green)
		draw_rect(Rect2(r.position + Vector2(-20, 8), Vector2(12, 34)), green)
		draw_rect(Rect2(r.position + Vector2(r.size.x, 40), Vector2(20, 12)), green)
		draw_rect(Rect2(r.position + Vector2(r.size.x + 8, 18), Vector2(12, 34)), green)

	var hurt := is_resolved and not won
	var body := _player_rect()
	draw_rect(body, Color("777777") if hurt else Color("3a86ff"))
	draw_face(body.get_center() + Vector2(0, -6), 38, not hurt)
