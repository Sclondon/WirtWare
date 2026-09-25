extends Microgame
## WIND IT! Spin your finger around the crank until the jack-in-the-box pops.

const BOX := Rect2(360, 340, 300, 270)
const CRANK_CENTER := Vector2(740, 470)
const CRANK_LENGTH := 90.0
const GUIDE_RADIUS := 140.0

var turns_needed := 3.0
## Net radians wound; spinning back and forth cancels out.
var wound := 0.0
var last_angle := 0.0
var spinning := false
var popped_time := 0.0
var elapsed := 0.0


func _init() -> void:
	prompt = "WIND IT!"
	controls_hint = "DRAG IN CIRCLES"
	touch_hint = "SPIN YOUR FINGER AROUND"
	controls = Controls.POINTER
	duration = 4.5


func _on_start() -> void:
	# Finger speed isn't time-scaled, so ask for fewer turns at high speed.
	turns_needed = (1.5 + 0.75 * difficulty) / sqrt(Engine.time_scale)


func _progress() -> float:
	return clampf(absf(wound) / (turns_needed * TAU), 0.0, 1.0)


func _process(delta: float) -> void:
	update_pointer()
	elapsed += delta
	if is_playing():
		var offset := pointer - CRANK_CENTER
		var in_reach := offset.length() > 20 and offset.length() < touch_size(280, 130)
		if pointer_down and in_reach:
			var angle := offset.angle()
			if spinning:
				wound += wrapf(angle - last_angle, -PI, PI)
			spinning = true
			last_angle = angle
		else:
			spinning = false
		if _progress() >= 1.0:
			win()
	if is_resolved and won:
		popped_time += delta
	queue_redraw()


func _draw() -> void:
	for i in 17:
		draw_rect(Rect2(i * 80, 0, 80, SCREEN.y), Color("fdffb6") if i % 2 == 0 else Color("ffd6a5"))
	draw_rect(Rect2(0, BOX.end.y, SCREEN.x, SCREEN.y - BOX.end.y), Color("bc6c25"))

	var progress := _progress()
	var shake := Vector2(sin(elapsed * 50.0) * progress * 6.0, 0) if not is_resolved else Vector2.ZERO
	var box := Rect2(BOX.position + shake, BOX.size)

	# Jack springs up out of the open lid.
	if is_resolved and won:
		var rise := minf(popped_time * 6.0, 1.0) * 230.0
		var top := box.position.y - rise
		var spring := PackedVector2Array()
		for i in 9:
			spring.append(Vector2(box.get_center().x + (30.0 if i % 2 == 0 else -30.0), lerpf(box.position.y, top, i / 8.0)))
		draw_polyline(spring, Color("6c757d"), 8)
		var head := Vector2(box.get_center().x, top - 50)
		draw_circle(head, 60, Color.WHITE)
		draw_face(head, 60, true)
		draw_circle(head + Vector2(0, 2), 12, Color("e63946"))
		draw_colored_polygon(PackedVector2Array([head + Vector2(-50, -40), head + Vector2(50, -40), head + Vector2(0, -120)]), Color("3a86ff"))

	draw_rect(box, Color("e63946"))
	draw_rect(box.grow(-24), Color("f28482"))
	draw_text_centered("?", box.get_center(), 120, Color.WHITE)
	var lid_y := box.position.y
	if is_resolved and won:
		draw_line(Vector2(box.position.x, lid_y), Vector2(box.position.x - 40, lid_y - box.size.x * 0.9), Color("9d0208"), 18)
	else:
		draw_rect(Rect2(box.position.x - 12, lid_y - 20, box.size.x + 24, 22), Color("9d0208"))

	# Where to spin, how far along you are, and the crank itself.
	draw_arc(CRANK_CENTER, GUIDE_RADIUS, 0, TAU, 64, Color(0, 0, 0, 0.15), 18)
	if progress > 0.0:
		draw_arc(CRANK_CENTER, GUIDE_RADIUS, -PI / 2, -PI / 2 + TAU * progress, 64, Color("06d6a0"), 18)
	var knob := CRANK_CENTER + Vector2.from_angle(wound) * CRANK_LENGTH
	draw_line(CRANK_CENTER, knob, Color("495057"), 14)
	draw_circle(CRANK_CENTER, 16, Color("343a40"))
	draw_circle(knob, 24, Color("ffbe0b"))
