extends Microgame
## SLICE! Swipe through everything that's tossed up before it falls back down.
## Graveyard: pumpkins and skulls. Temple: gold and jade balls. Swamp: potions and toxic barrels.

const GRAVITY := 1600.0
const MIN_SWIPE := 12.0
const RADIUS := 50.0
const TRAIL_LENGTH := 8
## Per stage: [sprite, frames, scale, juice colour] for each kind of thing tossed.
const KINDS: Array[Array] = [
	[["graveyard/pumpkin", 6, 7.0, Color("ffb347")], ["graveyard/skull", 1, 6.0, Color("e8e4f0")]],
	[["temple/golden_Ball", 16, 6.0, Color("f2c14e")], ["temple/emerald_Ball", 16, 6.0, Color("5fe0a0")]],
	[["swamp/acid_potion", 4, 6.0, Color("8ee04a")], ["swamp/toxic_barrel", 1, 6.0, Color("b6f24e")]],
]

class Fruit:
	var pos: Vector2
	var vel: Vector2
	var kind := 0
	var launch_at := 0.0
	var launched := false
	var sliced := false
	var slice_angle := 0.0
	var split := 0.0
	var spin := 0.0
	var spin_speed := 0.0
	## Set once the slice has been celebrated (the autopilot slices by poking `sliced`).
	var juiced := false

var fruits: Array[Fruit] = []
var elapsed := 0.0
var trail: Array[Vector2] = []
var last_pointer := Vector2.ZERO
var sliced_count := 0


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
		fruit.kind = i % 2
		fruit.pos = Vector2(randf_range(140, SCREEN.x - 140), SCREEN.y + RADIUS)
		fruit.vel = Vector2((SCREEN.x / 2 - fruit.pos.x) * randf_range(0.2, 0.5), -randf_range(1550, 1750))
		fruit.launch_at = 0.4 + i * 0.35 + randf() * 0.2
		fruit.spin_speed = randf_range(-4.0, 4.0)
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
			if fruit.launched:
				Sfx.play("whoosh", 0.35)
			continue
		fruit.vel.y += GRAVITY * delta
		fruit.pos += fruit.vel * delta
		fruit.spin += fruit.spin_speed * delta
		if fruit.sliced:
			if not fruit.juiced:
				_on_sliced(fruit)
			fruit.split += delta
		elif is_playing():
			var closest := Geometry2D.get_closest_point_to_segment(fruit.pos, last_pointer, pointer)
			if swiping and closest.distance_to(fruit.pos) < touch_size(RADIUS, 24):
				fruit.sliced = true
				fruit.slice_angle = (pointer - last_pointer).angle()
				_on_sliced(fruit)
			elif fruit.pos.y > SCREEN.y + RADIUS and fruit.vel.y > 0.0:
				popup("MISSED!", Vector2(clampf(fruit.pos.x, 160, SCREEN.x - 160), SCREEN.y - 160), Color("ef476f"), 56)
				lose()
	if is_playing() and fruits.all(func(f: Fruit) -> bool: return f.sliced):
		win()

	if swiping:
		trail.append(pointer)
	if trail.size() > TRAIL_LENGTH or (not swiping and not trail.is_empty()):
		trail.pop_front()
	last_pointer = pointer
	queue_redraw()


func _on_sliced(fruit: Fruit) -> void:
	fruit.juiced = true
	sliced_count += 1
	var info: Array = KINDS[stage][fruit.kind]
	var juice: Color = info[3]
	burst(fruit.pos, juice, 16, 460.0, 11.0)
	Sfx.play("swish")
	Sfx.play(["squish", "crunch", "splash"][stage], 0.8)
	shake(4.0)
	if sliced_count == fruits.size():
		popup("ALL CUT!", fruit.pos + Vector2(0, -90), Stages.theme(stage).glow, 60)


func _draw() -> void:
	var theme := Stages.theme(stage)
	for i in 16:
		draw_rect(Rect2(0, SCREEN.y * i / 16.0, SCREEN.x, SCREEN.y / 16.0 + 1), (theme.sky as Color).lerp(theme.sky_low, i / 15.0))
	match stage:
		Stages.GRAVEYARD:
			draw_circle(Vector2(560, 190), 80, Color("fff2c4"))
			draw_circle(Vector2(530, 170), 80, (theme.sky as Color).lerp(theme.sky_low, 2.0 / 15.0))
			# An iron fence along the bottom.
			draw_rect(Rect2(0, 1060, SCREEN.x, 10), Color("1b1428"))
			draw_rect(Rect2(0, 1160, SCREEN.x, 10), Color("1b1428"))
			for x in range(10, int(SCREEN.x), 48):
				draw_rect(Rect2(x, 1030, 10, 250), Color("1b1428"))
				draw_colored_polygon(PackedVector2Array([Vector2(x - 6, 1032), Vector2(x + 5, 1006), Vector2(x + 16, 1032)]), Color("1b1428"))
		Stages.TEMPLE:
			for row in 6:
				for col in 6:
					var x := col * 150.0 + (75.0 if row % 2 else 0.0) - 60.0
					draw_rect(Rect2(x, 860 + row * 72, 146, 68), Color("4d5a4f").lerp(Color("2f3a33"), row / 6.0))
			draw_sprite("temple/t_totem_heads", 3, 0, Vector2(90, 800), 5.0)
			draw_sprite("temple/t_totem_heads", 3, 2, Vector2(630, 800), 5.0)
		_:
			draw_sprite("swamp/tree_5", 1, 0, Vector2(110, 1060), 3.0, false, Color(0.4, 0.55, 0.4))
			draw_sprite("graveyard/tree", 1, 0, Vector2(620, 1080), 3.0, true, Color(0.4, 0.55, 0.4))
			for i in 5:
				draw_rect(Rect2(-60 + sin(_clock * 0.6 + i) * 60.0, 1040 + i * 44, 840, 50), Color(0.7, 0.95, 0.6, 0.08))

	for fruit in fruits:
		if not fruit.launched:
			continue
		var info: Array = KINDS[stage][fruit.kind]
		var path: String = info[0]
		var frames: int = info[1]
		var scale: float = info[2]
		var frame := 0 if stage == Stages.GRAVEYARD else anim_frame(12, frames, fruit.spin_speed)
		if not fruit.sliced:
			if stage == Stages.SWAMP:
				draw_circle(fruit.pos, RADIUS * 1.1, Color(theme.glow, 0.18))
			draw_sprite(path, frames, frame, fruit.pos, scale, false, Color.WHITE, fruit.spin)
			continue
		# Two halves drifting apart along the cut.
		var apart := Vector2.from_angle(fruit.slice_angle + PI / 2) * fruit.split * 140.0
		_draw_half(path, frames, frame, fruit.pos - apart, scale, fruit.slice_angle - fruit.split * 2.0, true)
		_draw_half(path, frames, frame, fruit.pos + apart, scale, fruit.slice_angle + fruit.split * 2.0, false)

	if trail.size() >= 2:
		draw_polyline(PackedVector2Array(trail), Color(theme.glow, 0.6), 16, true)
		draw_polyline(PackedVector2Array(trail), Color.WHITE, 6, true)


## The top (or bottom) half of a sprite frame, rotated so the cut runs along [param angle].
func _draw_half(path: String, frames: int, frame: int, center: Vector2, scale: float, angle: float, top: bool) -> void:
	var tex := art(path)
	var w := tex.get_width() / float(frames)
	var h := float(tex.get_height())
	var y := -h / 2 if top else 0.0
	draw_set_transform(center, angle, Vector2(scale, scale))
	draw_texture_rect_region(tex, Rect2(-w / 2, y, w, h / 2), Rect2(w * frame, h / 2 + y, w, h / 2))
	draw_set_transform(Vector2.ZERO)
