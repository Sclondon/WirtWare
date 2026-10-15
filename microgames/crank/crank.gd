extends Microgame
## WIND IT! Spin your finger around the crank until the jack-in-the-box pops.
## Out springs a winged skull in the graveyard, Tlaloc's face in the temple, or
## a goggling eye stalk in the swamp.

const BOX := Rect2(210, 430, 300, 270)
const CRANK_CENTER := Vector2(360, 960)
const CRANK_LENGTH := 100.0
const GUIDE_RADIUS := 170.0
## Per stage: box, inner panel, lid.
const BOX_COLORS := [
	[Color("6a3fa0"), Color("ff9a3c"), Color("3d2266")],
	[Color("8f856c"), Color("c9a227"), Color("5c5444")],
	[Color("4f6b2e"), Color("8fcf5a"), Color("2f4420")],
]

var turns_needed := 3.0
## Net radians wound; spinning back and forth cancels out.
var wound := 0.0
var last_angle := 0.0
var spinning := false
var popped_time := 0.0
var elapsed := 0.0
var clicks := 0


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
		var in_reach := offset.length() > 20 and offset.length() < touch_size(320, 150)
		if pointer_down and in_reach:
			var angle := offset.angle()
			if spinning:
				wound += wrapf(angle - last_angle, -PI, PI)
			spinning = true
			last_angle = angle
		else:
			spinning = false
		# A ratchet click every quarter turn.
		var now := int(absf(wound) / (PI / 2))
		if now > clicks:
			clicks = now
			Sfx.play("tap", 0.7, 0.8 + 0.8 * _progress())
		if _progress() >= 1.0:
			win()
	if is_resolved and won:
		popped_time += delta
	queue_redraw()


func _on_resolved(result: bool) -> void:
	if not result:
		Sfx.play("thud", 0.8, 0.7)
		return
	var head := Vector2(BOX.get_center().x, BOX.position.y - 280)
	Sfx.play("spring")
	Sfx.play("pop", 0.8, 0.8)
	shake(10)
	burst(Vector2(BOX.get_center().x, BOX.position.y), Stages.theme(stage).accent, 24, 600.0, 12.0)
	burst(Vector2(BOX.get_center().x, BOX.position.y), Color.WHITE, 12, 500.0, 8.0)
	popup(["BOO!", "ROAR!", "BOING!"][posmod(stage, 3)], head + Vector2(180, -40), Stages.theme(stage).glow, 72)


func _draw() -> void:
	var theme := Stages.theme(stage)
	_draw_scenery(theme)
	var colors: Array = BOX_COLORS[posmod(stage, 3)]

	var progress := _progress()
	var rattle := Vector2(sin(elapsed * 50.0) * progress * 8.0, 0) if not is_resolved else Vector2.ZERO
	var box := Rect2(BOX.position + rattle, BOX.size)

	# The surprise springs up out of the open lid, overshooting a little.
	if is_resolved and won:
		var t := minf(popped_time * 5.0, 1.0)
		var rise := (1.0 + sin(t * PI) * 0.25) * 230.0 * t
		var top := box.position.y - rise
		var spring := PackedVector2Array()
		for i in 9:
			spring.append(Vector2(box.get_center().x + (30.0 if i % 2 == 0 else -30.0), lerpf(box.position.y, top, i / 8.0)))
		draw_polyline(spring, Color("2b2b2b"), 14)
		draw_polyline(spring, Color("b0b8c0"), 8)
		var head := Vector2(box.get_center().x, top - 70)
		draw_circle(head, 110, Color(theme.glow, 0.25))
		match stage:
			Stages.TEMPLE:
				draw_sprite("temple/tlaloc", 2, 1, head, 3.0)
			Stages.SWAMP:
				draw_sprite("swamp/eye_stalk", 4, anim_frame(6, 4), head + Vector2(0, 10), 7.0)
			_:
				draw_sprite("graveyard/skull_enemy", 8, anim_frame(12, 8), head, 8.0)

	# A drive shaft down to the crank.
	draw_line(Vector2(CRANK_CENTER.x, box.end.y), CRANK_CENTER, Color("495057"), 16)
	draw_rect(box.grow(6), Color.BLACK)
	draw_rect(box, colors[0])
	draw_rect(box.grow(-24), colors[1])
	draw_rect(Rect2(box.position + Vector2(24, 24), Vector2(box.size.x - 48, 14)), Color(1, 1, 1, 0.25))
	if stage == Stages.TEMPLE:
		for i in 3:
			draw_texture_rect_region(art("temple/t_glyph_tile"), Rect2(box.position + Vector2(36 + i * 80, box.size.y - 70), Vector2(48, 48)), Rect2(8, 0, 8, 8))
	draw_text_centered("?" if not (is_resolved and won) else "!", box.get_center() + Vector2(0, -12), 130, Color.WHITE)
	var lid_y := box.position.y
	if is_resolved and won:
		draw_line(Vector2(box.position.x, lid_y), Vector2(box.position.x - 40, lid_y - box.size.x * 0.9), Color.BLACK, 26)
		draw_line(Vector2(box.position.x, lid_y), Vector2(box.position.x - 40, lid_y - box.size.x * 0.9), colors[2], 18)
	else:
		var bump := -absf(sin(elapsed * 30.0)) * 10.0 * maxf(progress - 0.6, 0.0) / 0.4
		draw_rect(Rect2(box.position.x - 16, lid_y - 24 + bump, box.size.x + 32, 30), Color.BLACK)
		draw_rect(Rect2(box.position.x - 12, lid_y - 20 + bump, box.size.x + 24, 22), colors[2])

	# Where to spin, how far along you are, and the crank itself.
	draw_arc(CRANK_CENTER, GUIDE_RADIUS, 0, TAU, 64, Color(0, 0, 0, 0.3), 22)
	if progress > 0.0:
		draw_arc(CRANK_CENTER, GUIDE_RADIUS, -PI / 2, -PI / 2 + TAU * progress, 64, Color(theme.glow), 22)
	# Little arrows round the guide show it's a circle to trace.
	if not is_resolved and progress < 0.2:
		for i in 4:
			var a := elapsed * 2.0 + i * TAU / 4.0
			draw_arrow(CRANK_CENTER + Vector2.from_angle(a) * GUIDE_RADIUS, Vector2.from_angle(a + PI / 2), 40, Color(1, 1, 1, 0.7))
	var knob := CRANK_CENTER + Vector2.from_angle(wound) * CRANK_LENGTH
	draw_line(CRANK_CENTER, knob, Color.BLACK, 24)
	draw_line(CRANK_CENTER, knob, Color("adb5bd"), 16)
	draw_circle(CRANK_CENTER, 20, Color("343a40"))
	draw_circle(knob, 32, Color.BLACK)
	draw_circle(knob, 28, Color(theme.accent))
	if is_resolved and not won:
		draw_text_centered("TOO SLOW!", Vector2(360, 200), 80, Color("ef476f"))


## The stage's sky, floor and a few props.
func _draw_scenery(theme: Dictionary) -> void:
	var top: Color = theme.sky
	var low: Color = theme.sky_low
	var floor_y := BOX.end.y
	for i in 12:
		draw_rect(Rect2(0, floor_y * i / 12.0, SCREEN.x, floor_y / 12.0 + 1), top.lerp(low, i / 11.0))
	var ground: Color = theme.ground
	draw_rect(Rect2(0, floor_y, SCREEN.x, SCREEN.y - floor_y), ground)
	draw_rect(Rect2(0, floor_y, SCREEN.x, 10), ground.lightened(0.25))
	match stage:
		Stages.GRAVEYARD:
			draw_circle(Vector2(600, 180), 60, Color("fff2c4"))
			draw_circle(Vector2(578, 165), 60, top)
			draw_sprite("graveyard/grave_2", 1, 0, Vector2(80, floor_y - 44), 3.0, false, Color(0.7, 0.65, 0.8))
			draw_sprite("graveyard/pumpkin", 6, anim_frame(6, 6), Vector2(630, floor_y - 30), 4.0)
		Stages.TEMPLE:
			for x in [70.0, 650.0]:
				draw_sprite("temple/t_torch", 12, anim_frame(10, 4, x), Vector2(x, floor_y - 72), 6.0)
		Stages.SWAMP:
			draw_circle(Vector2(140, 200), 64, Color(0.85, 1.0, 0.6, 0.3))
			draw_sprite("swamp/toxic_barrel", 1, 0, Vector2(640, floor_y - 30), 4.0)
			draw_sprite("swamp/h_frog", 1, 0, Vector2(90, floor_y - 30), 4.0)
