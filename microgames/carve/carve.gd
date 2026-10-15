extends Microgame
## CARVE! Drag along the dotted face shapes to cut them out and light the pumpkin.
## A homage to Jack O'Lantern.

const CENTER := Vector2(360, 660)
const RADII := Vector2(310, 270)
const SPACING := 14.0
## Share of a shape's outline that has to be cut before it pops out.
const DONE_AT := 0.9

const EYE := [Vector2(-175, -40), Vector2(-50, -40), Vector2(-112, -150)]
const MOUTH := [
	Vector2(-185, 50), Vector2(-120, 80), Vector2(-90, 50), Vector2(-45, 85), Vector2(0, 55), Vector2(45, 85),
	Vector2(90, 50), Vector2(120, 80), Vector2(185, 50), Vector2(120, 145), Vector2(0, 170), Vector2(-120, 145),
]

## Each shape: {"points": PackedVector2Array (closed outline samples), "cut": Array[bool], "done": bool}.
var shapes: Array[Dictionary] = []
var tolerance := 46.0
var last_pointer := Vector2.ZERO
var cutting := false
var swish_timer := 0.0
var glow := 0.0
var flicker := 0.0
var theme := {}


func _init() -> void:
	prompt = "CARVE!"
	controls_hint = "DRAG ALONG THE DOTS"
	touch_hint = "DRAG ALONG THE DOTS"
	controls = Controls.POINTER
	duration = 5.0


func _on_start() -> void:
	theme = Stages.theme(stage)
	tolerance = touch_size([50.0, 44.0, 40.0][difficulty - 1], 24)
	var mirror := Vector2(-1, 1)
	match difficulty:
		1:
			_add_shape(MOUTH, Vector2(0, -20), 1.15)
		2:
			_add_shape(EYE, Vector2(0, 20), 1.15)
			_add_shape(EYE, Vector2(0, 20), 1.15, mirror)
		_:
			_add_shape(EYE, Vector2.ZERO, 0.95)
			_add_shape(EYE, Vector2.ZERO, 0.95, mirror)
			_add_shape(MOUTH, Vector2(0, 10), 0.95)


## Resamples the polygon [param corners] into evenly spaced points around its closed outline.
func _add_shape(corners: Array, offset: Vector2, size: float, flip := Vector2.ONE) -> void:
	var points := PackedVector2Array()
	for i in corners.size():
		var a: Vector2 = CENTER + offset + corners[i] * size * flip
		var b: Vector2 = CENTER + offset + corners[(i + 1) % corners.size()] * size * flip
		var count := maxi(1, int(a.distance_to(b) / SPACING))
		for j in count:
			points.append(a.lerp(b, float(j) / count))
	var cut: Array[bool] = []
	cut.resize(points.size())
	cut.fill(false)
	shapes.append({"points": points, "cut": cut, "done": false})


func _process(delta: float) -> void:
	update_pointer()
	flicker += delta
	swish_timer -= delta
	if is_resolved and won:
		glow = minf(glow + delta * 4.0, 1.0)
	if is_playing():
		if pointer_pressed:
			last_pointer = pointer
		cutting = pointer_down
		if cutting:
			_cut_along(last_pointer, pointer)
		last_pointer = pointer
	queue_redraw()


## Cuts every outline point near the stroke from [param from] to [param to].
func _cut_along(from: Vector2, to: Vector2) -> void:
	var hit := false
	for shape in shapes:
		if shape.done:
			continue
		var points: PackedVector2Array = shape.points
		var cut: Array[bool] = shape.cut
		var count := 0
		for i in points.size():
			if not cut[i]:
				var closest := Geometry2D.get_closest_point_to_segment(points[i], from, to)
				if closest.distance_to(points[i]) < tolerance:
					cut[i] = true
					hit = true
			if cut[i]:
				count += 1
		if float(count) / points.size() >= DONE_AT:
			cut.fill(true)
			shape.done = true
			var middle := Vector2.ZERO
			for p in points:
				middle += p
			middle /= points.size()
			Sfx.play("crunch")
			burst(middle, Color("ff8c1a"), 16, 420, 11)
			popup("CUT!", middle + Vector2(0, -40), Color.WHITE, 44)
			shake(6)
			if shapes.all(func(s: Dictionary) -> bool: return s.done):
				Sfx.play("whoosh", 0.7, 1.3)
				burst(CENTER, theme.glow, 24, 560, 12)
				win()
	if hit and swish_timer <= 0.0:
		swish_timer = 0.11
		Sfx.play("swish", 0.45, randf_range(0.9, 1.2))
		burst(to, Color("ffb347"), 3, 220, 6)


func _on_resolved(result: bool) -> void:
	if not result:
		Sfx.play("squish")
		burst(CENTER + Vector2(0, 120), Color("ff8c1a"), 18, 360, 12)


func _draw() -> void:
	var sky: Color = theme.sky
	draw_rect(Rect2(Vector2.ZERO, SCREEN), sky)
	# A warm halo behind the pumpkin once it is lit.
	if glow > 0.0:
		for i in 5:
			draw_circle(CENTER, 520.0 - i * 70.0, Color(theme.glow, 0.06 * glow))
	var table: Color = theme.ground
	draw_rect(Rect2(0, 900, SCREEN.x, SCREEN.y - 900), table)
	draw_rect(Rect2(0, 900, SCREEN.x, 18), table.lightened(0.2))
	_draw_props()

	# The pumpkin: ribbed ovals and a stem.
	var lost := is_resolved and not won
	var orange := Color("f77f00") if not lost else Color("b5651d")
	# A failed pumpkin just goes dull and slumps a little at the sides.
	var squash := Vector2(1.04, 0.97) if lost else Vector2.ONE
	var c := CENTER + (Vector2(0, 8) if lost else Vector2.ZERO)
	draw_rect(Rect2(CENTER.x - 22, CENTER.y - RADII.y - 50, 44, 70), Color("5a7d2a"))
	for rib in [-0.62, 0.62, -0.32, 0.32, 0.0]:
		var rx := RADII.x * (0.5 if rib != 0.0 else 0.62)
		var col := orange.darkened(0.12) if rib != 0.0 else orange
		draw_colored_polygon(ellipse_points(c + Vector2(RADII.x * rib, 0), Vector2(rx, RADII.y) * squash), col)
	for rib in [-0.45, 0.0, 0.45]:
		draw_arc(c + Vector2(RADII.x * rib * 0.9, 0), RADII.y * 0.9 * squash.y, -PI / 2 - 0.5, -PI / 2 + 0.5, 12, orange.darkened(0.25), 4)

	var lit: Color = Color("ff9f1c").lerp(theme.glow, 0.25)
	var core: Color = Color("fff3b0").lightened(0.1 * sin(flicker * 23.0))
	for shape in shapes:
		var points: PackedVector2Array = shape.points
		var cut: Array[bool] = shape.cut
		if shape.done:
			var hole := Color("2b1200").lerp(lit, glow)
			draw_colored_polygon(points, hole)
			if glow > 0.0:
				# Candlelight: a hot core inside each hole, flickering.
				var middle := Vector2.ZERO
				for p in points:
					middle += p
				middle /= points.size()
				var inner := PackedVector2Array()
				var shrink := 0.55 + 0.05 * sin(flicker * 19.0)
				for p in points:
					inner.append(middle + (p - middle) * shrink)
				draw_colored_polygon(inner, Color(core, glow))
			draw_polyline(points + PackedVector2Array([points[0]]), Color("4a2300"), 6)
			continue
		for i in points.size():
			if cut[i] and cut[(i + 1) % points.size()]:
				draw_line(points[i], points[(i + 1) % points.size()], Color("3d1a00"), 10)
			elif i % 2 == 0 and not cut[i]:
				draw_circle(points[i], 7, Color("5c2a00"))
	if cutting and is_playing():
		_draw_knife(pointer)
	if lost:
		draw_text_centered("TOO SLOW!", Vector2(360, 140), 64, Color("ef476f"))
	elif is_resolved:
		draw_text_centered("SPOOKY!", Vector2(360, 140), 64, lit)


## A little stage dressing in the corners, around the pumpkin.
func _draw_props() -> void:
	match stage:
		Stages.GRAVEYARD:
			draw_sprite("graveyard/bat", 4, anim_frame(8, 4), Vector2(100, 190), 4.0)
			draw_sprite("graveyard/bat", 4, anim_frame(8, 4, 0.2), Vector2(620, 240), 4.0, true)
			draw_sprite("graveyard/prop_pumpkin_pile", 1, 0, Vector2(90, 1010), 5.0)
			draw_sprite("graveyard/prop_pumpkin_pile", 1, 0, Vector2(630, 1010), 5.0, true)
		Stages.TEMPLE:
			draw_sprite("temple/t_torch", 12, anim_frame(10, 6), Vector2(80, 210), 6.0)
			draw_sprite("temple/t_torch", 12, anim_frame(10, 6, 0.15), Vector2(640, 210), 6.0, true)
		_:
			draw_sprite("swamp/willOWisp", 6, anim_frame(8, 6), Vector2(90, 200 + sin(flicker * 3.0) * 14), 4.0)
			draw_sprite("swamp/willOWisp", 6, anim_frame(8, 6, 0.3), Vector2(630, 230 + sin(flicker * 3.0 + 2.0) * 14), 4.0, true)


func _draw_knife(at: Vector2) -> void:
	draw_set_transform(at, -0.6, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(14, -70), Vector2(-6, -70)]), Color("e0e0e0"))
	draw_rect(Rect2(-10, -110, 26, 42), Color("6b3e26"))
	draw_set_transform(Vector2.ZERO)
