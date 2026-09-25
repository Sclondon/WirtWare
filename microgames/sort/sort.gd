extends Microgame
## SORT! Toss each falling item into the matching bin: circles left, squares right.

const COLORS: Array[Color] = [Color("e63946"), Color("457b9d")]
const BIN_X: Array[float] = [230.0, 1050.0]
const BIN_TOP := 540.0
const START_Y := 110.0
const FLOOR_Y := 500.0
const ITEM_SIZE := 45.0

class Tossed:
	var pos: Vector2
	var vel: Vector2
	var side: int

var remaining := 3
var item_side := 0
var item_pos := Vector2.ZERO
var item_speed := 450.0
var spawn_delay := 0.5
var tossed: Array[Tossed] = []


func _init() -> void:
	prompt = "SORT!"
	controls_hint = "LEFT / RIGHT"
	touch_hint = "LEFT / RIGHT"
	controls = Controls.LEFT_RIGHT
	duration = 4.5


func _on_start() -> void:
	remaining = 2 + difficulty
	item_speed = 380.0 + 90.0 * difficulty
	_next_item()


func _next_item() -> void:
	item_side = randi() % 2
	item_pos = Vector2(640, START_Y)


func _process(delta: float) -> void:
	if is_playing():
		spawn_delay -= delta
		if spawn_delay <= 0.0:
			item_pos.y += item_speed * delta
			var dir := 0
			if Input.is_action_just_pressed("left"):
				dir = -1
			elif Input.is_action_just_pressed("right"):
				dir = 1
			if dir != 0:
				_toss(dir)
			elif item_pos.y > FLOOR_Y:
				item_pos.y = FLOOR_Y
				lose()

	for t in tossed:
		t.vel.y += 1800.0 * delta
		t.pos += t.vel * delta
	for i in range(tossed.size() - 1, -1, -1):
		if tossed[i].pos.y > BIN_TOP + 40:
			tossed.remove_at(i)
	queue_redraw()


func _toss(dir: int) -> void:
	var t := Tossed.new()
	t.pos = item_pos
	t.side = item_side
	var target_x := BIN_X[0 if dir < 0 else 1]
	var flight_time := 0.5
	t.vel = Vector2((target_x - item_pos.x) / flight_time, (BIN_TOP - item_pos.y) / flight_time - 900.0 * flight_time)
	tossed.append(t)
	if (dir < 0) != (item_side == 0):
		item_pos = Vector2(-1000, -1000)
		lose()
		return
	remaining -= 1
	if remaining == 0:
		item_pos = Vector2(-1000, -1000)
		win()
	else:
		_next_item()


func _draw_item(pos: Vector2, side: int, happy: bool) -> void:
	if side == 0:
		draw_circle(pos, ITEM_SIZE, COLORS[0])
	else:
		draw_rect(Rect2(pos - Vector2(ITEM_SIZE, ITEM_SIZE), Vector2(ITEM_SIZE, ITEM_SIZE) * 2), COLORS[1])
	draw_face(pos, ITEM_SIZE, happy)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("f1faee"))
	draw_rect(Rect2(0, FLOOR_Y + ITEM_SIZE, SCREEN.x, SCREEN.y), Color("a8dadc"))
	var lost := is_resolved and not won
	for t in tossed:
		_draw_item(t.pos, t.side, not lost)
	if spawn_delay <= 0.0:
		_draw_item(item_pos, item_side, not lost)

	for side in 2:
		var x := BIN_X[side]
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 110, BIN_TOP), Vector2(x + 110, BIN_TOP), Vector2(x + 85, 680), Vector2(x - 85, 680),
		]), COLORS[side].darkened(0.3))
		var icon := Vector2(x, 610)
		if side == 0:
			draw_circle(icon, 28, Color.WHITE)
		else:
			draw_rect(Rect2(icon - Vector2(28, 28), Vector2(56, 56)), Color.WHITE)
