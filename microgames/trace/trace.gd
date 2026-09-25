extends Microgame
## TRACE! Drag down the wiggly path from start to finish without straying off it.

const SAMPLES := 64
const LOOKAHEAD := 8
const TOP := 200.0
const BOTTOM := 1120.0

var path := PackedVector2Array()
## How far from the centre line the pointer may be.
var width := 60.0
## Index of the furthest path point reached.
var progress := 0
var tracing := false
var strayed := false


func _init() -> void:
	prompt = "TRACE!"
	controls_hint = "DRAG ALONG THE PATH"
	touch_hint = "DRAG YOUR FINGER ALONG IT"
	controls = Controls.POINTER
	duration = 5.0


func _on_start() -> void:
	var waves := 1.0 + 0.75 * difficulty
	var amplitude := 150.0 + 30.0 * difficulty
	var phase := randf() * TAU
	for i in SAMPLES:
		var t := float(i) / (SAMPLES - 1)
		path.append(Vector2(SCREEN.x / 2 + sin(t * waves * TAU + phase) * amplitude, lerpf(TOP, BOTTOM, t)))
	width = touch_size([65.0, 52.0, 42.0][difficulty - 1], 22)


func _process(_delta: float) -> void:
	update_pointer()
	if is_playing():
		if pointer_pressed and pointer.distance_to(path[progress]) < width * 1.5:
			tracing = true
		elif not pointer_down:
			tracing = false  # Lifting pauses; press again where you left off.
		if tracing:
			for i in range(progress + 1, mini(progress + LOOKAHEAD, SAMPLES)):
				if pointer.distance_to(path[i]) < width:
					progress = i
			if _distance_to_path() > width * 1.25:
				strayed = true
				lose()
			elif progress == SAMPLES - 1:
				win()
	queue_redraw()


## Distance from the pointer to the path near where the player is.
func _distance_to_path() -> float:
	var best := INF
	for i in range(maxi(progress - 2, 0), mini(progress + LOOKAHEAD, SAMPLES - 1)):
		var closest := Geometry2D.get_closest_point_to_segment(pointer, path[i], path[i + 1])
		best = minf(best, pointer.distance_to(closest))
	return best


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("fdf0d5"))
	for p in path:
		draw_circle(p, width, Color("e0c9a6"))
	draw_polyline(path, Color.WHITE, 4, true)
	if progress > 0:
		draw_polyline(path.slice(0, progress + 1), Color("06d6a0"), 16, true)

	var start := path[0]
	draw_circle(start, width * 0.8, Color("06d6a0"))
	draw_text_centered("GO", start, 30)
	var goal := path[SAMPLES - 1]
	draw_line(goal + Vector2(0, 20), goal + Vector2(0, -110), Color("333333"), 6)
	for row in 2:
		for col in 3:
			var cell := Rect2(goal + Vector2(col * 20, -110 + row * 20), Vector2(20, 20))
			draw_rect(cell, Color.BLACK if (row + col) % 2 == 0 else Color.WHITE)

	if tracing and not is_resolved:
		draw_circle(pointer, 16, Color("ef476f"))
	if strayed:
		draw_circle(pointer, 22, Color("ef476f"))
		draw_text_centered("OFF THE PATH!", Vector2(360, 110), 64, Color("ef476f"))
	elif is_resolved and won:
		draw_text_centered("NAILED IT!", Vector2(360, 110), 64, Color("06d6a0"))
