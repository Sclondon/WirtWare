extends Microgame
## POP 'EM! Tap every spook before time runs out.
## Graveyard: ghosts. Temple: rain spirits. Swamp: will-o'-wisps.

const RADIUS := 62.0
const PLAY_AREA := Rect2(90, 190, 540, 960)

class Balloon:
	var pos: Vector2
	var vel: Vector2
	var popped := false
	## Seconds since it popped (-1 while it's still floating).
	var age := -1.0
	var phase := 0.0
	var frame := 0

var balloons: Array[Balloon] = []
var pops := 0


func _init() -> void:
	prompt = "POP 'EM!"
	controls_hint = "CLICK"
	touch_hint = "TAP THEM"
	controls = Controls.POINTER
	duration = 4.0


func _on_start() -> void:
	for i in 2 + difficulty:
		var b := Balloon.new()
		b.pos = _free_spot()
		b.phase = randf() * TAU
		b.frame = i
		if difficulty >= 2:
			b.vel = Vector2.from_angle(randf() * TAU) * randf_range(120, 220) * (difficulty - 1)
		balloons.append(b)


func _free_spot() -> Vector2:
	var spot := Vector2.ZERO
	for attempt in 30:
		spot = Vector2(randf_range(PLAY_AREA.position.x, PLAY_AREA.end.x), randf_range(PLAY_AREA.position.y, PLAY_AREA.end.y))
		if balloons.all(func(b: Balloon) -> bool: return b.pos.distance_to(spot) > RADIUS * 3):
			break
	return spot


# Taps are read as events rather than polled, so a quick tap that goes down and
# up within one frame still counts.
func _unhandled_input(event: InputEvent) -> void:
	if not is_playing():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var tap := get_local_mouse_position()
		var reach := touch_size(RADIUS * 1.15, 32)
		# Pop the nearest one in reach, not just the first in the list.
		var best: Balloon = null
		for b in balloons:
			if not b.popped and b.pos.distance_to(tap) < reach and (best == null or b.pos.distance_to(tap) < best.pos.distance_to(tap)):
				best = b
		if best:
			best.popped = true
		else:
			Sfx.play("tap", 0.4)


func _process(delta: float) -> void:
	for b in balloons:
		if b.popped:
			if b.age < 0.0:
				_on_pop(b)
			b.age += delta
		elif not is_resolved:
			b.pos += b.vel * delta
			if b.pos.x < PLAY_AREA.position.x or b.pos.x > PLAY_AREA.end.x:
				b.vel.x *= -1
			if b.pos.y < PLAY_AREA.position.y or b.pos.y > PLAY_AREA.end.y:
				b.vel.y *= -1
			b.pos = b.pos.clamp(PLAY_AREA.position, PLAY_AREA.end)
		elif not won:
			b.pos.y -= 260.0 * delta  # Got away, giggling.
	if is_playing() and balloons.all(func(b: Balloon) -> bool: return b.popped):
		win()
	queue_redraw()


func _on_pop(b: Balloon) -> void:
	b.age = 0.0
	pops += 1
	var last := pops == balloons.size()
	var color: Color = [Color("e8f4ff"), Color("8de3f0"), Color("d4ff7a")][stage]
	burst(b.pos, color, 22 if last else 14, 520.0 if last else 400.0, 12.0)
	var at := Vector2(clampf(b.pos.x, 190, SCREEN.x - 190), b.pos.y - 60)
	popup(["BOO!", "POP!", "FWIP!"][stage] if not last else "ALL GONE!", at, color, 64 if last else 48)
	Sfx.play("pop", 1.0, 1.0 + 0.12 * pops)
	if last:
		Sfx.play("zap", 0.6)
		shake(6.0)


func _draw() -> void:
	var theme := Stages.theme(stage)
	for i in 16:
		draw_rect(Rect2(0, SCREEN.y * i / 16.0, SCREEN.x, SCREEN.y / 16.0 + 1), (theme.sky as Color).lerp(theme.sky_low, i / 15.0))
	match stage:
		Stages.GRAVEYARD:
			draw_circle(Vector2(560, 170), 70, Color("fff2c4"))
			draw_circle(Vector2(532, 152), 70, (theme.sky as Color).lerp(theme.sky_low, 1.5 / 15.0))
			draw_sprite("graveyard/mausoleum", 1, 0, Vector2(560, 1100), 3.0, false, Color(0.5, 0.45, 0.6))
			draw_sprite("graveyard/grave_2", 1, 0, Vector2(150, 1180), 3.0, false, Color(0.6, 0.55, 0.7))
		Stages.TEMPLE:
			for row in 6:
				for col in 6:
					var x := col * 150.0 + (75.0 if row % 2 else 0.0) - 60.0
					draw_rect(Rect2(x, 860 + row * 72, 146, 68), Color("4d5a4f").lerp(Color("2f3a33"), row / 6.0))
			for i in 30:
				var p := Vector2(fmod(i * 97.0 + _clock * 40.0, 760.0) - 20, fmod(i * 173.0 + _clock * 900.0, SCREEN.y))
				draw_line(p, p + Vector2(-4, 26), Color(0.7, 0.9, 1.0, 0.3), 2.0)
		_:
			draw_sprite("swamp/tree_5", 1, 0, Vector2(110, 1080), 3.0, false, Color(0.4, 0.55, 0.4))
			draw_sprite("graveyard/tree", 1, 0, Vector2(620, 1100), 3.0, true, Color(0.4, 0.55, 0.4))
			for i in 5:
				draw_rect(Rect2(-60 + sin(_clock * 0.6 + i) * 60.0, 1050 + i * 40, 840, 50), Color(0.7, 0.95, 0.6, 0.07))
	draw_rect(Rect2(0, 1200, SCREEN.x, 80), theme.ground)

	var giggle := is_resolved and not won
	for b in balloons:
		if b.popped:
			_draw_poof(b)
			continue
		var bob := Vector2(sin(_clock * 2.0 + b.phase) * 8.0, sin(_clock * 3.1 + b.phase) * 12.0)
		if giggle:
			bob = Vector2(sin(_clock * 40.0 + b.phase) * 6.0, 0)
		var p := b.pos + bob
		var flip := b.vel.x < 0.0
		match stage:
			Stages.GRAVEYARD:
				draw_circle(p, RADIUS * 0.95, Color(theme.glow, 0.16))
				draw_circle(p, RADIUS * 0.6, Color(theme.glow, 0.16))
				draw_sprite("graveyard/ghost", 6, anim_frame(8, 6, b.phase), p + Vector2(0, 12), 6.0, flip)
			Stages.TEMPLE:
				draw_circle(p, RADIUS * 0.95, Color(theme.glow, 0.18))
				# Two blue spirits for every gold one.
				draw_sprite("temple/t_spirit", 3, 2 if b.frame % 3 == 2 else anim_frame(4, 2, b.phase), p, 7.0, flip)
			_:
				draw_circle(p, RADIUS * 0.85, Color(theme.glow, 0.18))
				draw_circle(p, RADIUS * 0.5, Color(theme.glow, 0.18))
				draw_sprite("swamp/willOWisp", 6, anim_frame(10, 6, b.phase), p, 6.0, flip)
		if giggle:
			draw_text_centered("HEE!", p + Vector2(0, -RADIUS - 20), 36, theme.glow)


## A ring of puffs that spreads out and fades after a pop.
func _draw_poof(b: Balloon) -> void:
	var k := clampf(b.age / 0.35, 0.0, 1.0)
	if k >= 1.0:
		return
	var color: Color = Stages.theme(stage).glow
	for i in 8:
		var dir := Vector2.from_angle(TAU * i / 8.0 + 0.3)
		draw_circle(b.pos + dir * lerpf(20.0, 90.0, k), lerpf(18.0, 4.0, k), Color(color, 1.0 - k))
	draw_arc(b.pos, lerpf(30.0, 110.0, k), 0, TAU, 32, Color(1, 1, 1, 1.0 - k), 6.0)
