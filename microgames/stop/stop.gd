extends Microgame
## STOP! Hit the button while the needle is inside the glowing zone. The needle
## is a bat, a golden ball or a will-o'-wisp depending on the stage, and the
## stage's hero cheers or flops.

const BAR := Rect2(440, 200, 120, 800)
const HERO_POS := Vector2(220, 866)

var needle_y := BAR.end.y
var needle_dir := -1.0
var needle_speed := 800.0
var zone := Rect2()
var react := 0.0
var elapsed := 0.0
## True once the player pressed (rather than running out of time).
var pressed := false


func _init() -> void:
	prompt = "STOP!"
	controls_hint = "PRESS SPACE"
	touch_hint = "TAP THE BUTTON"
	controls = Controls.BUTTON
	duration = 3.5


func _on_start() -> void:
	var height: float = [200.0, 140.0, 105.0][difficulty - 1]
	# Keep the zone away from the needle's starting end (the bottom).
	var y := randf_range(BAR.position.y, BAR.end.y - BAR.size.y * 0.3 - height)
	zone = Rect2(BAR.position.x, y, BAR.size.x, height)
	# The press is a real-time reflex, so slow the needle a little as the game speeds up.
	needle_speed = (650.0 + 150.0 * difficulty) / sqrt(Engine.time_scale)


func _process(delta: float) -> void:
	elapsed += delta
	if is_playing():
		needle_y += needle_dir * needle_speed * delta
		if needle_y < BAR.position.y or needle_y > BAR.end.y:
			needle_dir *= -1
			needle_y = clampf(needle_y, BAR.position.y, BAR.end.y)
			Sfx.play("tap", 0.4)
		if Input.is_action_just_pressed("action"):
			pressed = true
			if needle_y >= zone.position.y and needle_y <= zone.end.y:
				win()
			else:
				lose()
	else:
		react += delta
	queue_redraw()


func _on_resolved(result: bool) -> void:
	if not pressed:
		return  # Time ran out: no press to react to.
	var at := Vector2(BAR.get_center().x, needle_y)
	Sfx.play("hit")
	if result:
		var glow: Color = Stages.theme(stage).glow
		burst(at, glow, 24, 520.0, 12.0)
		shake(8)
	else:
		burst(at, Color("ef476f"), 10, 300.0, 8.0)


func _draw() -> void:
	var theme := Stages.theme(stage)
	_draw_scenery(theme)

	# The hero cheers (hops) on a hit and flops over on a miss.
	var hop := 0.0
	var tilt := 0.0
	var tint := Color.WHITE
	if is_resolved and won:
		hop = -absf(sin(react * 12.0)) * 60.0
	elif is_resolved:
		tilt = minf(react * 8.0, 1.0) * -PI / 2
		tint = Color(0.75, 0.7, 0.8)
	var hero := HERO_POS + Vector2(0, hop)
	draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(ellipse_points(HERO_POS + Vector2(0, 130), Vector2(90, 20)), Color(0, 0, 0, 0.3))
	match stage:
		Stages.TEMPLE:
			draw_sprite("temple/t_warrior", 5, 0, hero, 11.0, false, tint, tilt)
		Stages.SWAMP:
			draw_sprite("swamp/h_frog", 1, 0, hero + Vector2(0, 40), 11.0, false, tint, tilt)
		_:
			draw_sprite("graveyard/idle_jon", 5, anim_frame(6, 5), hero, 11.0, false, tint, tilt)

	# The bar, its glowing target zone, and the needle.
	var glow: Color = theme.glow
	var accent: Color = theme.accent
	draw_rect(BAR.grow(10), Color.BLACK)
	draw_rect(BAR, Color("8a2846"))
	var pulse := 0.93 + 0.07 * sin(elapsed * 12.0)
	draw_rect(zone.grow(6), accent)
	draw_rect(zone, glow * Color(pulse, pulse, pulse))
	var line_color := Color.WHITE if not is_resolved or won else Color("ef476f")
	draw_line(Vector2(BAR.position.x - 20, needle_y), Vector2(BAR.end.x + 20, needle_y), Color.BLACK, 16)
	draw_line(Vector2(BAR.position.x - 20, needle_y), Vector2(BAR.end.x + 20, needle_y), line_color, 8)
	var marker := Vector2(BAR.end.x + 70, needle_y)
	match stage:
		Stages.TEMPLE:
			draw_sprite("temple/golden_Ball", 16, anim_frame(20, 16), marker, 5.0)
		Stages.SWAMP:
			draw_sprite("swamp/willOWisp", 6, anim_frame(10, 6), marker, 3.5)
		_:
			draw_circle(marker, 44, Color(1, 0.95, 0.7, 0.35))
			draw_sprite("graveyard/bat", 4, anim_frame(12, 4), marker, 3.5)

	if is_resolved:
		draw_text_centered("PERFECT!" if won else "MISS!", Vector2(360, 130), 84, glow if won else Color("ef476f"))


## The stage's sky, ground and a few props.
func _draw_scenery(theme: Dictionary) -> void:
	var top: Color = theme.sky
	var low: Color = theme.sky_low
	var floor_y := 1060.0
	for i in 12:
		draw_rect(Rect2(0, floor_y * i / 12.0, SCREEN.x, floor_y / 12.0 + 1), top.lerp(low, i / 11.0))
	var ground: Color = theme.ground
	draw_rect(Rect2(0, floor_y, SCREEN.x, SCREEN.y - floor_y), ground)
	draw_rect(Rect2(0, floor_y, SCREEN.x, 10), ground.lightened(0.25))
	match stage:
		Stages.GRAVEYARD:
			draw_circle(Vector2(140, 210), 64, Color("fff2c4"))
			draw_circle(Vector2(165, 195), 64, top)
			draw_sprite("graveyard/grave_2", 1, 0, Vector2(60, floor_y - 44), 3.0, false, Color(0.7, 0.65, 0.8))
			draw_sprite("graveyard/prop_pumpkin_pile", 1, 0, Vector2(370, floor_y - 34), 3.0)
		Stages.TEMPLE:
			for row in 9:
				for col in 6:
					var x := col * 140.0 + (70.0 if row % 2 else 0.0) - 70.0
					draw_rect(Rect2(x, 420 + row * 72, 136, 68), Color("4d5a4f").lerp(Color("2f3a33"), row / 9.0))
			draw_sprite("temple/t_torch", 12, anim_frame(10, 4), Vector2(60, 700), 6.0)
		Stages.SWAMP:
			draw_circle(Vector2(150, 220), 64, Color(0.85, 1.0, 0.6, 0.3))
			draw_sprite("swamp/tree_5", 1, 0, Vector2(40, floor_y - 190), 3.0, false, Color(0.35, 0.5, 0.38))
			draw_sprite("swamp/toxic_barrel", 1, 0, Vector2(370, floor_y - 28), 3.5)
