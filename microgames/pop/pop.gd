extends Microgame
## POP 'EM! Tap every balloon before time runs out.

const RADIUS := 62.0
const PLAY_AREA := Rect2(90, 190, 540, 960)
const COLORS: Array[Color] = [Color("ff006e"), Color("fb5607"), Color("ffbe0b"), Color("8338ec"), Color("3a86ff")]

class Balloon:
	var pos: Vector2
	var vel: Vector2
	var color: Color
	var popped := false

var balloons: Array[Balloon] = []


func _init() -> void:
	prompt = "POP 'EM!"
	controls_hint = "CLICK"
	touch_hint = "TAP THEM"
	controls = Controls.POINTER
	duration = 4.0


func _on_start() -> void:
	for i in 2 + difficulty:
		var b := Balloon.new()
		b.color = COLORS[i % COLORS.size()]
		b.pos = _free_spot()
		if difficulty >= 2:
			b.vel = Vector2.from_angle(randf() * TAU) * randf_range(120, 220) * (difficulty - 1)
		balloons.append(b)


func _free_spot() -> Vector2:
	var spot := Vector2.ZERO
	for attempt in 30:
		spot = Vector2(randf_range(PLAY_AREA.position.x, PLAY_AREA.end.x), randf_range(PLAY_AREA.position.y, PLAY_AREA.end.y))
		if balloons.all(func(b: Balloon) -> bool: return b.pos.distance_to(spot) > RADIUS * 3):
			break
	return spot


# Taps are read as events rather than polled, so a quick tap that goes down and
# up within one frame still counts.
func _unhandled_input(event: InputEvent) -> void:
	if not is_playing():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var tap := get_local_mouse_position()
		var reach := touch_size(RADIUS * 1.15, 32)
		for b in balloons:
			if not b.popped and b.pos.distance_to(tap) < reach:
				b.popped = true
				break
		if balloons.all(func(b: Balloon) -> bool: return b.popped):
			win()


func _process(delta: float) -> void:
	if not is_resolved:
		for b in balloons:
			b.pos += b.vel * delta
			if b.pos.x < PLAY_AREA.position.x or b.pos.x > PLAY_AREA.end.x:
				b.vel.x *= -1
			if b.pos.y < PLAY_AREA.position.y or b.pos.y > PLAY_AREA.end.y:
				b.vel.y *= -1
			b.pos = b.pos.clamp(PLAY_AREA.position, PLAY_AREA.end)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("caf0f8"))
	for i in 4:
		var cloud := Vector2(fposmod(i * 260.0 + 80, SCREEN.x), 260 + i * 270)
		for j in 3:
			draw_circle(cloud + Vector2(j * 50 - 50, (j % 2) * -20), 45, Color(1, 1, 1, 0.8))
	for b in balloons:
		if b.popped:
			for i in 8:
				var dir := Vector2.from_angle(TAU * i / 8.0)
				draw_line(b.pos + dir * 20, b.pos + dir * 55, b.color, 6)
			continue
		draw_line(b.pos + Vector2(0, RADIUS), b.pos + Vector2(8, RADIUS + 80), Color("555555"), 3)
		draw_circle(b.pos, RADIUS, b.color)
		draw_circle(b.pos + Vector2(-20, -20), 11, Color(1, 1, 1, 0.5))
		draw_face(b.pos, 56, not (is_resolved and not won))
