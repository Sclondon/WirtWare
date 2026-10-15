extends Microgame
## BOSS: SQUASH THE SNAIL LORD! He hides in his shell and flings goo, crows and
## toads at your screen: tap or swipe them before they reach the glass (three
## cracks and it shatters). When he pokes his head out, tap him to hurt him.
## Angry at half health: faster, slimier, and the toads join in.

const SNAIL_POS := Vector2(360, 470)
const SNAIL_SCALE := 5.0
const SNAIL_R := 150.0
## Threats that get this far hit the screen.
const GLASS_Y := 1170.0
const MAX_CRACKS := 3
const BAR_RECT := Rect2(130, 70, 530, 26)
const WARMUP := 1.0
const DEATH_TIME := 0.9
## Sprites drawn with this tint come out as a pure white silhouette (hit flash).
const FLASH := Color(2, 2, 2)
const FLASH_SHADER := """
shader_type canvas_item;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = tint.r > 1.5 ? vec4(1.0, 1.0, 1.0, tex.a) : tex * tint;
}
"""
const PEEK_TIME := 0.6

var max_hp := 12
var hp := 12
var angry := false
var cracks: Array[Dictionary] = []

## "shell", "peek" or "open".
var mode := "shell"
var mode_t := 0.0
var shell_time := 2.0
var open_time := 1.6
var spawn_timer := 1.2
var hurt_flash := 0.0
var clink_cooldown := 0.0
var dying := false
var death_t := 0.0
var gone := false
var shattered := false
var elapsed := 0.0
var last_pointer := Vector2.ZERO

## Each: {kind ("goo", "crow", "toad"), pos, vel, age, flip}
var threats: Array[Dictionary] = []


func _init() -> void:
	prompt = "SQUASH THE SNAIL LORD!"
	controls_hint = "CLICK / SWIPE"
	touch_hint = "TAP / SWIPE"
	controls = Controls.POINTER
	duration = 24.0
	is_boss = true
	win_on_timeout = false


func _on_start() -> void:
	var flash_shader := Shader.new()
	flash_shader.code = FLASH_SHADER
	material = ShaderMaterial.new()
	(material as ShaderMaterial).shader = flash_shader
	var d := clampi(difficulty, 1, 3)
	max_hp = [10, 11, 12][d - 1]
	hp = max_hp
	shell_time = [2.2, 2.0, 1.8][d - 1]
	open_time = [2.0, 1.8, 1.6][d - 1]
	mode_t = 0.6  # The first opening comes a little sooner.


func _process(delta: float) -> void:
	elapsed += delta
	update_pointer()
	hurt_flash = maxf(hurt_flash - delta, 0.0)
	clink_cooldown = maxf(clink_cooldown - delta, 0.0)
	if is_playing() and not dying:
		_cycle(delta)
		if elapsed > WARMUP:
			_spawn(delta)
		_handle_pointer()
	_move_threats(delta)
	if dying:
		_die(delta)
	last_pointer = pointer
	queue_redraw()


func _cycle(delta: float) -> void:
	mode_t += delta
	var pace := 0.8 if angry else 1.0
	match mode:
		"shell":
			if mode_t > shell_time * pace and elapsed > WARMUP:
				mode = "peek"
				mode_t = 0.0
				Sfx.play("beep", 0.8, 0.8)
				popup("!", SNAIL_POS + Vector2(0, -190), Color("d4ff7a"), 90)
		"peek":
			if mode_t > PEEK_TIME:
				mode = "open"
				mode_t = 0.0
				Sfx.play("squish", 0.8, 0.7)
		"open":
			if mode_t > open_time * (0.85 if angry else 1.0):
				mode = "shell"
				mode_t = 0.0
				Sfx.play("thud", 0.8, 0.8)


func _spawn(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer > 0.0:
		return
	var every: float = [1.0, 0.82, 0.68][difficulty - 1] * (0.85 if angry else 1.0)
	# Fewer threats while his head is out, so there's time to hit him.
	spawn_timer = every * (1.8 if mode == "open" else 1.0)
	var kinds := ["goo", "crow"]
	if angry:
		kinds.append("toad")
	var kind: String = "crow" if mode == "open" and not angry else kinds.pick_random()
	var travel: float = [3.0, 2.6, 2.3][difficulty - 1] * (0.88 if angry else 1.0)
	var target := Vector2(randf_range(110, 610), GLASS_Y)
	var t := {"kind": kind, "age": 0.0, "flip": false}
	match kind:
		"goo":
			var from := SNAIL_POS + Vector2(70, 60)
			t.pos = from
			# A lob that lands on target after `travel` seconds.
			t.vel = Vector2((target.x - from.x) / travel, -500.0)
			t.gravity = 2.0 * (target.y - from.y + 500.0 * travel) / (travel * travel)
			Sfx.play("squish", 0.6, 1.3)
		"crow":
			var left := randf() < 0.5
			var from := Vector2(-40.0 if left else SCREEN.x + 40.0, randf_range(200, 380))
			t.pos = from
			t.vel = (target - from) / travel
			t.flip = not left
			t.wobble = randf_range(0, TAU)
			Sfx.play("whoosh", 0.5, 1.4)
		"toad":
			var from := Vector2(randf_range(120, 600), 700)
			t.pos = from
			t.vel = (target - from) / travel
			t.flip = target.x < from.x
			Sfx.play("spring", 0.5, 0.8)
	threats.append(t)


func _move_threats(delta: float) -> void:
	for t in threats:
		t.age += delta
		match t.kind:
			"goo":
				t.vel.y += t.gravity * delta
				t.pos += t.vel * delta
			"crow":
				t.pos += t.vel * delta
				t.pos.x += sin(t.age * 6.0 + t.wobble) * 160.0 * delta
			"toad":
				t.pos += t.vel * delta
		if t.pos.y >= GLASS_Y and not t.get("dead", false):
			t.dead = true
			if is_playing() and not dying:
				_crack(t.pos)
	threats = threats.filter(func(t: Dictionary) -> bool: return not t.get("dead", false))


## How big a threat is drawn: it grows as it flies at the screen.
func _threat_scale(t: Dictionary) -> float:
	var k := clampf((t.pos.y - 300.0) / (GLASS_Y - 300.0), 0.0, 1.0)
	return 4.0 + floorf(k * 3.0)


func _handle_pointer() -> void:
	if not pointer_down:
		return
	var reach := touch_size(64, 30)
	var killed := false
	for t in threats:
		var closest := Geometry2D.get_closest_point_to_segment(t.pos, last_pointer if not pointer_pressed else pointer, pointer)
		if closest.distance_to(t.pos) < reach:
			t.dead = true
			killed = true
			var color := Color("b6f24e") if t.kind == "goo" else (Color("3a3a5a") if t.kind == "crow" else Color("7ccf4a"))
			burst(t.pos, color, 12, 360, 9)
			popup(["SPLAT!", "POP!", "GOT IT!"].pick_random(), t.pos + Vector2(0, -50), Color("d4ff7a"), 40)
			Sfx.play("pop" if t.kind == "goo" else "squish")
	threats = threats.filter(func(t: Dictionary) -> bool: return not t.get("dead", false))
	if killed or not pointer_pressed:
		return
	# A fresh tap on the Snail Lord himself.
	if pointer.distance_to(SNAIL_POS + Vector2(0, 20)) < maxf(SNAIL_R, touch_size(SNAIL_R, 60)):
		if mode == "open":
			_hit_snail()
		elif clink_cooldown <= 0.0:
			clink_cooldown = 0.25
			burst(pointer, Color("c8d0c8"), 6, 220, 6)
			popup("CLINK!", pointer + Vector2(0, -40), Color("c8d0c8"), 36)
			Sfx.play("tap", 0.9, 0.7)


func _hit_snail() -> void:
	hp -= 1
	hurt_flash = 0.1
	burst(pointer, Color("b6f24e"), 12, 380, 10)
	shake(6)
	Sfx.play("hit", 0.8, randf_range(0.9, 1.15))
	if hp <= 0:
		dying = true
		death_t = 0.0
		for t in threats:
			burst(t.pos, Color("b6f24e"), 6, 200, 6)
		threats.clear()
		Sfx.play("boom", 0.8, 1.1)
	elif not angry and hp <= max_hp / 2.0:
		angry = true
		popup("SLIME TIME!", SNAIL_POS + Vector2(0, -200), Color("ff4d6d"), 60)
		shake(14)
		Sfx.play("zap", 0.8, 0.6)
		mode = "shell"
		mode_t = 0.0
		spawn_timer = 0.3
	else:
		popup("OUCH!", SNAIL_POS + Vector2(randf_range(-80, 80), -150), Color("d4ff7a"), 44)


func _crack(at: Vector2) -> void:
	var lines: Array[PackedVector2Array] = []
	for i in 7:
		var line := PackedVector2Array([at])
		var p := at
		var angle := i * TAU / 7.0 + randf_range(-0.3, 0.3)
		for j in 4:
			p += Vector2.from_angle(angle + randf_range(-0.5, 0.5)) * randf_range(40, 90)
			line.append(p)
		lines.append(line)
	cracks.append({"at": at, "lines": lines})
	burst(at, Color("b6f24e"), 18, 420, 11)
	Sfx.play("crunch")
	if cracks.size() >= MAX_CRACKS:
		shattered = true
		shake(20)
		lose()
	else:
		shake(12)
		popup("CRACK!", at + Vector2(0, -80), Color.WHITE, 56)


func _die(delta: float) -> void:
	death_t += delta
	# Never let the fuse run out mid-explosion.
	var length := minf(DEATH_TIME, duration - elapsed - 0.1)
	if not gone and int(death_t * 12.0) != int((death_t - delta) * 12.0):
		var spot := SNAIL_POS + Vector2(randf_range(-120, 120), randf_range(-100, 100))
		burst(spot, [Color("b6f24e"), Color("d4ff7a"), Color("8a5cc7")].pick_random(), 10, 360, 10)
		Sfx.play("squish", 0.6, randf_range(0.6, 1.0))
		shake(8)
	if not gone and death_t >= length:
		gone = true
		burst(SNAIL_POS, Color("b6f24e"), 44, 720, 14)
		burst(SNAIL_POS, Color("8a5cc7"), 24, 520, 12)
		popup("SQUASHED!", SNAIL_POS, Color("d4ff7a"), 84)
		shake(20)
		Sfx.play("boom")
		win()


func _on_resolved(result: bool) -> void:
	if not result and not gone:
		popup("HEH HEH HEH!", SNAIL_POS + Vector2(0, -200), Color("d4ff7a"), 52)


# --- Drawing ----------------------------------------------------------------

func _draw() -> void:
	var theme := Stages.theme(stage)
	_draw_swamp(theme)
	_draw_snail()
	for t in threats:
		var s := _threat_scale(t)
		# A halo that turns red as it nears the glass.
		var danger := clampf((t.pos.y - 700.0) / (GLASS_Y - 700.0), 0.0, 1.0)
		draw_circle(t.pos, 30.0 + s * 6.0, Color(0.85, 1.0, 0.6, 0.12).lerp(Color(1, 0.2, 0.3, 0.3), danger))
		match t.kind:
			"goo":
				draw_sprite("swamp/goo_glob", 2, anim_frame(8, 2), t.pos, s + 1.0)
			"crow":
				draw_sprite("swamp/h_crowFlap", 4, anim_frame(12, 4, t.wobble), t.pos, s - 1.0, t.flip)
			"toad":
				var hop := absf(sin(t.age * 7.0)) * 40.0
				draw_sprite("swamp/sludge_toad", 4, anim_frame(10, 4), t.pos + Vector2(0, -hop), s - 1.0, t.flip)
	_draw_cracks()
	_draw_hud(theme)


func _draw_swamp(theme: Dictionary) -> void:
	var top: Color = theme.sky
	var low: Color = theme.sky_low
	if angry and not gone:
		top = top.lerp(Color("2a1030"), 0.4)
	for i in 16:
		draw_rect(Rect2(0, SCREEN.y * i / 16.0, SCREEN.x, SCREEN.y / 16.0 + 1), top.lerp(low, i / 15.0))
	draw_circle(Vector2(540, 200), 60, Color(0.85, 1.0, 0.6, 0.35))
	draw_sprite("graveyard/tree", 1, 0, Vector2(620, 470), 3.0, false, Color(0.5, 0.7, 0.45))
	draw_sprite("swamp/tree_5", 1, 0, Vector2(90, 460), 3.0, false, Color(0.45, 0.65, 0.45))
	# The swamp water he sits in, darker toward the glass.
	var ground: Color = theme.ground
	for i in 20:
		var y0 := 600.0 + i * 34.0
		draw_rect(Rect2(0, y0, SCREEN.x, 35), ground.lerp(ground.darkened(0.45), i / 19.0))
	draw_rect(Rect2(0, 600, SCREEN.x, 8), ground.lightened(0.25))
	for i in 7:
		var c := Vector2(fmod(i * 233.0 + elapsed * 25.0, 820.0) - 50.0, 880.0 + i * 50.0)
		draw_arc(c, 60.0, PI + 0.5, TAU - 0.5, 12, Color(0.7, 0.95, 0.6, 0.12), 3.0)
	draw_colored_polygon(ellipse_points(SNAIL_POS + Vector2(0, 150), Vector2(230, 40)), ground.lightened(0.12))
	for i in 3:
		var p := Vector2(130 + i * 230 + sin(elapsed * 1.3 + i) * 40.0, 760 + cos(elapsed * 1.7 + i * 2.0) * 40.0)
		draw_sprite("swamp/willOWisp", 6, anim_frame(8, 6, i), p, 3.0)
	draw_sprite("swamp/toxic_barrel", 1, 0, Vector2(80, 660), 4.0)
	draw_sprite("swamp/h_frog", 1, 0, Vector2(640, 650), 4.0)


func _draw_snail() -> void:
	if gone:
		draw_colored_polygon(ellipse_points(SNAIL_POS + Vector2(0, 130), Vector2(200, 36)), Color("b6f24e", 0.6))
		return
	var frame := anim_frame(5, 4)
	var pos := SNAIL_POS
	match mode:
		"peek":
			frame = 5 + mini(int(mode_t / PEEK_TIME * 4.0), 3)
			pos += Vector2(sin(elapsed * 60.0) * 5.0, 0)
		"open":
			frame = 9 + anim_frame(8, 4)
	if angry and mode == "shell":
		frame = 4 + anim_frame(6, 2)
	if dying:
		frame = 9 + anim_frame(12, 4)
		pos += Vector2(randf_range(-10, 10), randf_range(-10, 10))
	var tint := Color.WHITE
	if hurt_flash > 0.0 or (dying and int(death_t * 16.0) % 2 == 0):
		tint = FLASH
	elif angry:
		tint = Color(1.0, 0.7 + 0.1 * sin(elapsed * 8.0), 0.7)
	# Eye stalks pop up out of the shell to warn he's about to open up.
	if mode != "shell" and not dying:
		var rise := clampf(mode_t / 0.25, 0.0, 1.0) if mode == "peek" else 1.0
		for side in [-1.0, 1.0]:
			draw_sprite("swamp/eye_stalk", 4, anim_frame(10, 4, side), pos + Vector2(side * 60.0 + 40.0, -110.0 - rise * 70.0), 4.0)
	draw_sprite("swamp/snailLord", 13, frame, pos, SNAIL_SCALE, false, tint)
	if mode == "open" and is_playing() and not dying:
		var pulse := 0.5 + 0.5 * sin(elapsed * 14.0)
		draw_arc(SNAIL_POS + Vector2(0, 20), SNAIL_R + pulse * 12.0, 0, TAU, 48, Color("d4ff7a", 0.9), 6.0)
		draw_text_centered("TAP HIM!", SNAIL_POS + Vector2(0, 220), 48, Color("d4ff7a"))


func _draw_cracks() -> void:
	for c in cracks:
		draw_colored_polygon(ellipse_points(c.at, Vector2(70, 50)), Color("b6f24e", 0.55))
		for line: PackedVector2Array in c.lines:
			draw_polyline(line, Color(0, 0, 0, 0.6), 7.0)
			draw_polyline(line, Color(1, 1, 1, 0.9), 3.0)
	if shattered:
		draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(1, 1, 1, 0.15))
		for i in 12:
			var a := i * TAU / 12.0
			var p := Vector2(360, 700)
			var line := PackedVector2Array([p])
			for j in 6:
				p += Vector2.from_angle(a + sin(i * 7.0 + j) * 0.4) * 140.0
				line.append(p)
			draw_polyline(line, Color(0, 0, 0, 0.6), 8.0)
			draw_polyline(line, Color.WHITE, 4.0)


func _draw_hud(theme: Dictionary) -> void:
	_draw_health_bar(theme.boss_name, hurt_flash > 0.0)
	draw_sprite("swamp/snailLord", 13, 0, Vector2(BAR_RECT.position.x - 44, BAR_RECT.get_center().y), 1.0)
	# Screen health: one glass pane per crack you can still take.
	for i in MAX_CRACKS:
		var r := Rect2(40 + i * 52, 130, 40, 40)
		var ok := i < MAX_CRACKS - cracks.size()
		draw_rect(r, Color("8fd3ff", 0.8) if ok else Color(0.2, 0.2, 0.2, 0.6))
		draw_rect(r, Color.WHITE, false, 3.0)
		if not ok:
			draw_line(r.position, r.end, Color.WHITE, 3.0)
			draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), Color.WHITE, 3.0)


## The boss's health: red, pulsing once he's angry, white on a hit.
func _draw_health_bar(boss_name: String, flashing: bool) -> void:
	draw_circle(Vector2(BAR_RECT.position.x - 44, BAR_RECT.get_center().y), 33, Color(0, 0, 0, 0.7))
	draw_rect(BAR_RECT.grow(6), Color(0, 0, 0, 0.7))
	var fill := BAR_RECT
	fill.size.x *= clampf(float(hp) / max_hp, 0.0, 1.0)
	var color := Color("ff4d6d")
	if angry:
		color = Color("ff2e63").lerp(Color("ff9a3c"), 0.5 + 0.5 * sin(elapsed * 12.0))
	draw_rect(fill, Color.WHITE if flashing else color)
	draw_rect(Rect2(BAR_RECT.position, Vector2(BAR_RECT.size.x, 6)), Color(1, 1, 1, 0.25))
	draw_text_centered(boss_name, BAR_RECT.get_center() + Vector2(0, 2), 24)
