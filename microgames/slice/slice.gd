extends Microgame
## SLICE! Swipe through every fruit before it falls back down.

const GRAVITY := 1600.0
const MIN_SWIPE := 12.0
const RADIUS := 50.0
const TRAIL_LENGTH := 8
const COLORS: Array[Color] = [Color("fb8500"), Color("80b918"), Color("7209b7"), Color("ffd60a"), Color("e63946")]

class Fruit:
	var pos: Vector2
	var vel: Vector2
	var color: Color
	var launch_at := 0.0
	var launched := false
	var sliced := false
	var slice_angle := 0.0
	var split := 0.0

var fruits: Array[Fruit] = []
var elapsed := 0.0
var trail: Array[Vector2] = []
var last_pointer := Vector2.ZERO


func _init() -> void:
	prompt = "SLICE!"
	controls_hint = "SWIPE THE MOUSE"
	touch_hint = "SWIPE YOUR FINGER"
	controls = Controls.POINTER
	duration = 4.5


func _on_start() -> void:
	# Tossed from below the screen; they peak somewhere in the middle third.
	for i in 1 + difficulty:
		var fruit := Fruit.new()
		fruit.color = COLORS[i % COLORS.size()]
		fruit.pos = Vector2(randf_range(140, SCREEN.x - 140), SCREEN.y + RADIUS)
		fruit.vel = Vector2((SCREEN.x / 2 - fruit.pos.x) * randf_range(0.2, 0.5), -randf_range(1550, 1750))
		fruit.launch_at = 0.4 + i * 0.35 + randf() * 0.2
		fruits.append(fruit)


func _process(delta: float) -> void:
	update_pointer()
	if pointer_pressed:
		# A finger landing starts a new swipe instead of drawing a line from where the last one lifted.
		last_pointer = pointer
	var swiping := pointer.distance_to(last_pointer) >= MIN_SWIPE
	elapsed += delta
	for fruit in fruits:
		if not fruit.launched:
			fruit.launched = elapsed >= fruit.launch_at
			continue
		fruit.vel.y += GRAVITY * delta
		fruit.pos += fruit.vel * delta
		if fruit.sliced:
			fruit.split += delta
		elif is_playing():
			var closest := Geometry2D.get_closest_point_to_segment(fruit.pos, last_pointer, pointer)
			if swiping and closest.distance_to(fruit.pos) < touch_size(RADIUS, 24):
				fruit.sliced = true
				fruit.slice_angle = (pointer - last_pointer).angle()
			elif fruit.pos.y > SCREEN.y + RADIUS and fruit.vel.y > 0.0:
				lose()
	if is_playing() and fruits.all(func(f: Fruit) -> bool: return f.sliced):
		win()

	if swiping:
		trail.append(pointer)
	if trail.size() > TRAIL_LENGTH or (not swiping and not trail.is_empty()):
		trail.pop_front()
	last_pointer = pointer
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("6f4518"))
	for y in range(0, int(SCREEN.y), 120):
		draw_line(Vector2(0, y), Vector2(SCREEN.x, y), Color("5a3714"), 6)

	for fruit in fruits:
		if not fruit.launched:
			continue
		if not fruit.sliced:
			draw_circle(fruit.pos, RADIUS, fruit.color)
			draw_circle(fruit.pos + Vector2(-15, -15), 10, Color(1, 1, 1, 0.45))
			draw_line(fruit.pos + Vector2(0, -RADIUS), fruit.pos + Vector2(6, -RADIUS - 16), Color("3e2723"), 6)
			continue
		# Two halves drifting apart along the cut.
		var apart := Vector2.from_angle(fruit.slice_angle + PI / 2) * fruit.split * 140.0
		for half in 2:
			var from := fruit.slice_angle + PI * half
			var center := fruit.pos + (apart if half == 0 else -apart)
			draw_colored_polygon(ellipse_points(center, Vector2(RADIUS, RADIUS), from, from + PI, 16), fruit.color)
			draw_colored_polygon(ellipse_points(center, Vector2(RADIUS, RADIUS) * 0.75, from, from + PI, 16), fruit.color.lightened(0.5))

	if trail.size() >= 2:
		draw_polyline(PackedVector2Array(trail), Color.WHITE, 8, true)
