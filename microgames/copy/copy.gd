extends Microgame
## COPY! Press the arrows in the order shown. One wrong key and you're out.

const DIRECTIONS := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}
const BOX := 120.0
const ROW_Y := 470.0

var sequence: Array[String] = []
var progress := 0
var mistake := -1


func _init() -> void:
	prompt = "COPY!"
	controls_hint = "ARROW KEYS"
	touch_hint = "USE THE ARROWS"
	controls = Controls.ARROWS
	duration = 4.0


func _on_start() -> void:
	for i in 2 + difficulty:
		sequence.append(DIRECTIONS.keys().pick_random())


func _unhandled_input(event: InputEvent) -> void:
	if not is_playing() or event.is_echo():
		return
	for dir_name: String in DIRECTIONS:
		if event.is_action_pressed(dir_name):
			if dir_name == sequence[progress]:
				progress += 1
				if progress == sequence.size():
					win()
			else:
				mistake = progress
				lose()
			queue_redraw()
			return


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("3d405b"))
	draw_circle(Vector2(640, 190), 100, Color("f2cc8f"))
	draw_face(Vector2(640, 190), 100, not (is_resolved and not won))

	var count := sequence.size()
	for i in count:
		var center := Vector2(640 + (i - (count - 1) / 2.0) * (BOX + 24), ROW_Y)
		var box := Rect2(center - Vector2(BOX, BOX) / 2, Vector2(BOX, BOX))
		var fill := Color("f4f1de")
		if i < progress:
			fill = Color("81b29a")
		elif i == mistake:
			fill = Color("e07a5f")
		if i == progress and is_playing():
			draw_rect(box.grow(10), Color("f2cc8f"))
		draw_rect(box, fill)
		draw_arrow(center, DIRECTIONS[sequence[i]], BOX * 0.8, Color("3d405b"))
