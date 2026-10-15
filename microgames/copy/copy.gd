extends Microgame
## COPY! Press the arrows in the order shown. One wrong key and you're out.
## Each right press lights its tile: tombstones glow in the graveyard, rune
## stones in the temple, mossy slabs in the swamp, while the stage's watcher
## (a ghost, Tlaloc, a swamp eye) reacts.

const DIRECTIONS := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}
const BOX := 112.0
const ROW_Y := 760.0
const FACE_POS := Vector2(360, 330)

var sequence: Array[String] = []
var progress := 0
var mistake := -1
## Per tile: 1 right after it lights (or fails), easing back to 0.
var pops: Array[float] = []
var elapsed := 0.0
var end_time := 0.0


func _init() -> void:
	prompt = "COPY!"
	controls_hint = "ARROW KEYS"
	touch_hint = "USE THE ARROWS"
	controls = Controls.ARROWS
	duration = 4.0


func _on_start() -> void:
	for i in 2 + difficulty:
		sequence.append(DIRECTIONS.keys().pick_random())
		pops.append(0.0)


func _process(delta: float) -> void:
	elapsed += delta
	if not is_playing():
		end_time += delta
	for i in pops.size():
		pops[i] = move_toward(pops[i], 0.0, delta * 4.0)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not is_playing() or event.is_echo():
		return
	for dir_name: String in DIRECTIONS:
		if event.is_action_pressed(dir_name):
			var center := _box_center(progress)
			pops[progress] = 1.0
			if dir_name == sequence[progress]:
				Sfx.play("beep", 0.8, 1.0 + 0.2 * progress)
				burst(center, _lit_color(), 10, 320.0, 9.0)
				progress += 1
				if progress == sequence.size():
					burst(FACE_POS, _lit_color(), 24, 520.0, 12.0)
					win()
			else:
				Sfx.play("thud")
				mistake = progress
				shake(8)
				lose()
			return


func _box_center(i: int) -> Vector2:
	return Vector2(SCREEN.x / 2 + (i - (sequence.size() - 1) / 2.0) * (BOX + 16), ROW_Y)


## The glow a lit tile takes in this stage.
func _lit_color() -> Color:
	match stage:
		Stages.TEMPLE:
			return Color("9ff0c8")
		Stages.SWAMP:
			return Color("d4ff7a")
	return Color("ff9a3c")


func _draw() -> void:
	var theme := Stages.theme(stage)
	_draw_scenery(theme)
	var failed := is_resolved and not won
	var cheer := -absf(sin(end_time * 12.0)) * 40.0 if is_resolved and won else 0.0
	var jitter := Vector2(sin(elapsed * 70.0) * 10.0, 0) if failed and end_time < 0.4 else Vector2.ZERO
	var face := FACE_POS + Vector2(0, cheer) + jitter + Vector2(0, sin(elapsed * 3.0) * 8.0)
	var tint := Color(1, 0.6, 0.6) if failed else Color.WHITE

	draw_circle(FACE_POS, 170, Color(_lit_color(), 0.12 + 0.05 * progress))
	match stage:
		Stages.TEMPLE:
			draw_sprite("temple/tlaloc", 2, 1 if failed else 0, face, 4.0, false, tint)
		Stages.SWAMP:
			# The eye glances about while you play.
			draw_sprite("swamp/eye_stalk", 4, anim_frame(3, 4), face, 9.0, false, tint)
		_:
			draw_sprite("graveyard/ghost", 6, anim_frame(8, 6), face, 8.0, false, tint)

	for i in sequence.size():
		_draw_tile(i)


func _draw_tile(i: int) -> void:
	var size := BOX * (1.0 + 0.18 * pops[i])
	var center := _box_center(i)
	if i == mistake:
		center.x += sin(elapsed * 60.0) * 8.0 * pops[i]
	var box := Rect2(center - Vector2(size, size) / 2, Vector2(size, size))
	var lit := i < progress
	var glow := _lit_color()
	if i == progress and is_playing():
		draw_rect(box.grow(12), Color(1, 1, 1, 0.5 + 0.3 * sin(elapsed * 14.0)))
	if lit:
		draw_circle(center, size * 0.8, Color(glow, 0.3))

	var carve := Color("2b2233")
	match stage:
		Stages.TEMPLE:
			draw_texture_rect_region(art("temple/t_glyph_tile"), box, Rect2(0, 0, 8, 8),
				Color(1.4, 1.5, 1.3) if lit else Color.WHITE)
			carve = Color("3a2610")
		Stages.SWAMP:
			draw_rect(box.grow(4), Color("10200f"))
			draw_rect(box, Color("4f7a3a") if not lit else Color("8fcf5a"))
			draw_rect(Rect2(box.position, Vector2(box.size.x, size * 0.18)), Color("6fa04a"))
			carve = Color("1a2e14")
		_:
			# A little tombstone with a rounded top.
			var stone := Color("9a93a8") if not lit else Color("ffd08a")
			draw_circle(Vector2(center.x, box.position.y + size * 0.3), size * 0.5 + 4, Color.BLACK)
			draw_rect(Rect2(box.position + Vector2(-4, size * 0.3), Vector2(size + 8, size * 0.7 + 4)), Color.BLACK)
			draw_circle(Vector2(center.x, box.position.y + size * 0.3), size * 0.5, stone)
			draw_rect(Rect2(box.position + Vector2(0, size * 0.3), Vector2(size, size * 0.7)), stone)
	if i == mistake:
		draw_rect(box, Color(0.9, 0.2, 0.25, 0.6))
	var arrow_color := carve if not lit else Color.WHITE
	if lit:
		draw_arrow(center + Vector2(0, 4), DIRECTIONS[sequence[i]], size * 0.78, Color(0, 0, 0, 0.5))
	draw_arrow(center, DIRECTIONS[sequence[i]], size * 0.75, arrow_color)


## The stage's sky, ground and a few props.
func _draw_scenery(theme: Dictionary) -> void:
	var top: Color = theme.sky
	var low: Color = theme.sky_low
	var floor_y := 960.0
	for i in 12:
		draw_rect(Rect2(0, floor_y * i / 12.0, SCREEN.x, floor_y / 12.0 + 1), top.lerp(low, i / 11.0))
	var ground: Color = theme.ground
	draw_rect(Rect2(0, floor_y, SCREEN.x, SCREEN.y - floor_y), ground)
	draw_rect(Rect2(0, floor_y, SCREEN.x, 10), ground.lightened(0.25))
	match stage:
		Stages.GRAVEYARD:
			draw_circle(Vector2(600, 170), 60, Color("fff2c4"))
			draw_circle(Vector2(578, 156), 60, top)
			draw_sprite("graveyard/grave_2", 1, 0, Vector2(90, floor_y - 44), 3.0, false, Color(0.7, 0.65, 0.8))
			draw_sprite("graveyard/grave_1_small", 1, 0, Vector2(630, floor_y - 40), 3.0, false, Color(0.7, 0.65, 0.8))
		Stages.TEMPLE:
			for row in 6:
				for col in 6:
					var x := col * 140.0 + (70.0 if row % 2 else 0.0) - 70.0
					draw_rect(Rect2(x, 560 + row * 72, 136, 68), Color("4d5a4f").lerp(Color("2f3a33"), row / 6.0))
			for x in [70.0, 650.0]:
				draw_sprite("temple/t_torch", 12, anim_frame(10, 4, x), Vector2(x, 430), 6.0)
		Stages.SWAMP:
			draw_sprite("swamp/tree_5", 1, 0, Vector2(80, floor_y - 190), 3.0, false, Color(0.35, 0.5, 0.38))
			for i in 3:
				var p := Vector2(560 + i * 50 + sin(elapsed * 1.3 + i) * 30.0, 200 + cos(elapsed * 1.7 + i * 2.0) * 40.0 + i * 90)
				draw_sprite("swamp/willOWisp", 6, anim_frame(8, 6, i), p, 2.0)
