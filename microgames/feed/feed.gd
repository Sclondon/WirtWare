extends Microgame
## FEED! Drag each snack up into the monster's mouth.

const MONSTER_RADIUS := 150.0
const MOUTH_RADIUS := 72.0
const FOOD_RADIUS := 44.0
const MONSTER_HOME := Vector2(360, 330)
const SPAWN_AWAY := Vector2(-1000, -1000)

var monster := MONSTER_HOME
var food := Vector2.ZERO
var food_kind := 0
var holding := false
var total := 2
var eaten := 0
var chomp := 0.0
var elapsed := 0.0


func _init() -> void:
	prompt = "FEED!"
	controls_hint = "DRAG FOOD TO THE MOUTH"
	touch_hint = "DRAG FOOD TO THE MOUTH"
	controls = Controls.POINTER
	duration = 4.5


func _on_start() -> void:
	total = 1 + difficulty
	_spawn_food()


func _spawn_food() -> void:
	food_kind = randi() % 3
	food = Vector2(randf_range(110, SCREEN.x - 110), randf_range(780, 1130))
	holding = false


func _mouth() -> Vector2:
	return monster + Vector2(0, 45)


func _process(delta: float) -> void:
	update_pointer()
	elapsed += delta
	chomp = maxf(chomp - delta * 4.0, 0.0)
	if difficulty == 3:
		monster.x = MONSTER_HOME.x + sin(elapsed * 2.5) * 170

	if is_playing():
		if pointer_pressed and pointer.distance_to(food) < touch_size(FOOD_RADIUS * 1.4, 40):
			holding = true
		elif not pointer_down:
			holding = false
		if holding:
			food = pointer
		if food.distance_to(_mouth()) < MOUTH_RADIUS:
			eaten += 1
			chomp = 1.0
			if eaten == total:
				food = SPAWN_AWAY
				win()
			else:
				_spawn_food()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("ffe5ec"))
	draw_rect(Rect2(0, 700, SCREEN.x, SCREEN.y - 700), Color("ffc2d1"))
	draw_text_centered("%d / %d" % [eaten, total], Vector2(360, 610), 56)

	# Monster: horns, body, eyes that watch the food, and a chomping mouth.
	var body := Color("7209b7")
	for side in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			monster + Vector2(side * 70, -120), monster + Vector2(side * 120, -200), monster + Vector2(side * 125, -95),
		]), Color("f9c74f"))
	draw_circle(monster, MONSTER_RADIUS, body)
	for side in [-1.0, 1.0]:
		var eye := monster + Vector2(side * 55, -50)
		draw_circle(eye, 30, Color.WHITE)
		var look := (food - eye).limit_length(12) if food != SPAWN_AWAY else Vector2.ZERO
		draw_circle(eye + look, 13, Color.BLACK)
	var open := 1.0 - chomp
	if is_resolved and not won:
		open = 0.25
	var mouth := _mouth()
	draw_colored_polygon(ellipse_points(mouth, Vector2(85, maxf(55.0 * open, 6.0))), Color("240046"))
	if open > 0.3:
		for i in 4:
			var tooth := mouth + Vector2(-54 + i * 36, -55.0 * open + 4)
			draw_colored_polygon(PackedVector2Array([tooth + Vector2(-12, 0), tooth + Vector2(12, 0), tooth + Vector2(0, 18)]), Color.WHITE)
	if is_resolved and not won:
		draw_text_centered("STILL HUNGRY...", Vector2(360, 110), 50, Color("7209b7"))

	if food == SPAWN_AWAY:
		return
	match food_kind:
		0:
			draw_line(food + Vector2(0, -FOOD_RADIUS), food + Vector2(5, -FOOD_RADIUS - 18), Color("5c4033"), 6)
			draw_circle(food, FOOD_RADIUS, Color("e63946"))
			draw_circle(food + Vector2(-12, -12), 9, Color(1, 1, 1, 0.5))
		1:
			draw_circle(food, FOOD_RADIUS, Color("d4a373"))
			for p in [Vector2(-14, -10), Vector2(12, -16), Vector2(4, 12), Vector2(-16, 16), Vector2(20, 8)]:
				draw_circle(food + p, 6, Color("5c4033"))
		2:
			draw_circle(food, FOOD_RADIUS, Color("ff8fab"))
			draw_circle(food, FOOD_RADIUS * 0.35, Color("ffc2d1"))
	if holding:
		draw_arc(food, FOOD_RADIUS + 10, 0, TAU, 32, Color(1, 1, 1, 0.8), 4)
