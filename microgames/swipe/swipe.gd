extends Microgame
## SWIPE! Swipe the way each arrow points. Red arrows mean the opposite way.
## Arrow keys work too, for desktop players.

const DIRECTIONS := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}
const OPPOSITE := {"up": "down", "down": "up", "left": "right", "right": "left"}
const ARROW_CENTER := Vector2(640, 400)

var sequence: Array[String] = []
var flipped: Array[bool] = []
var progress := 0
var swipe_start := Vector2.ZERO
var swipe_used := false
var pop := 0.0


func _init() -> void:
	prompt = "SWIPE!"
	controls_hint = "SWIPE THE MOUSE OR USE ARROWS"
	touch_hint = "SWIPE THE WAY IT POINTS"
	controls = Controls.POINTER
	duration = 4.5


func _on_start() -> void:
	for i in 2 + difficulty:
		sequence.append(DIRECTIONS.keys().pick_random())
		flipped.append(difficulty >= 2 and randf() < 0.35)


func _process(delta: float) -> void:
	update_pointer()
	pop = maxf(pop - delta * 5.0, 0.0)
	if is_playing():
		if pointer_pressed:
			swipe_start = pointer
			swipe_used = false
		if pointer_down and not swipe_used:
			var drag := pointer - swipe_start
			if drag.length() > touch_size(110, 35):
				swipe_used = true
				_answer(_direction_of(drag))
		for dir: String in DIRECTIONS:
			if is_playing() and Input.is_action_just_pressed(dir):
				_answer(dir)
	queue_redraw()


func _direction_of(v: Vector2) -> String:
	if absf(v.x) > absf(v.y):
		return "right" if v.x > 0 else "left"
	return "down" if v.y > 0 else "up"


func _answer(dir: String) -> void:
	var want: String = OPPOSITE[sequence[progress]] if flipped[progress] else sequence[progress]
	if dir != want:
		lose()
		return
	progress += 1
	pop = 1.0
	if progress == sequence.size():
		win()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("3a0ca3"))
	if progress < sequence.size():
		var red := flipped[progress]
		var size := 300.0 * (1.0 + pop * 0.15)
		draw_circle(ARROW_CENTER, 190, Color(1, 1, 1, 0.08))
		draw_arrow(ARROW_CENTER, DIRECTIONS[sequence[progress]], size, Color("ef476f") if red else Color.WHITE)
		if red:
			draw_text_centered("OPPOSITE!", ARROW_CENTER + Vector2(0, 230), 44, Color("ef476f"))
		if is_resolved and not won:
			draw_text_centered("WRONG WAY!", Vector2(640, 110), 70, Color("ef476f"))
	else:
		draw_text_centered("PERFECT!", ARROW_CENTER, 110, Color("06d6a0"))

	# The whole sequence along the top, finished ones in green.
	var count := sequence.size()
	for i in count:
		var center := Vector2(640 + (i - (count - 1) / 2.0) * 90, 110)
		if is_resolved and not won and i == progress:
			continue
		var color := Color("06d6a0") if i < progress else (Color("ef476f") if flipped[i] else Color(1, 1, 1, 0.6))
		draw_arrow(center, DIRECTIONS[sequence[i]], 60, color)

	if pointer_down and not swipe_used and is_playing():
		draw_line(swipe_start, pointer, Color(1, 1, 1, 0.5), 10)
