extends Microgame
## BOSS: BREAK THE CURSE! Pinball breakout against Tlaloc's stone face. Bounce
## the iron ball off the paddle, smash through his guard stones and warriors,
## and crack his face. Angry at half health: the stones grow back, and he spits
## darts that stun the paddle. Lose every ball and the curse wins.

const LEFT := 44.0
const RIGHT := 676.0
const TOP := 112.0
const FACE_POS := Vector2(360, 250)
const FACE_R := 112.0
const BALL_R := 22.0
const PADDLE_Y := 960.0
const PADDLE_H := 28.0
const PADDLE_SPEED := 980.0
const LOST_Y := 1070.0
const BLOCK_Y := 430.0
const BLOCK_SIZE := Vector2(88, 44)
const WARRIOR_Y := 580.0
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
## Steepest bounce off the paddle, from straight up.
const MAX_ANGLE := deg_to_rad(62.0)
## The ball never flies flatter than this (no endless side-to-side loops).
const MIN_RISE := 0.38

var max_hp := 6
var hp := 6
var balls := 3
var max_balls := 3
var angry := false

var paddle_x := SCREEN.x / 2
var paddle_w := 170.0
var paddle_dir := 0.0
var stun := 0.0
var ball := Vector2.ZERO
var vel := Vector2.ZERO
var speed := 760.0
var held := true
var serve_timer := WARMUP
var roll := 0.0
var ball_lost := false

var face_flash := 0.0
var face_cooldown := 0.0
var dart_timer := 3.0
var dying := false
var death_t := 0.0
var gone := false
var elapsed := 0.0

## Each: {rect, alive, flash}
var blocks: Array[Dictionary] = []
## Each: {x, dir, speed, flash}
var warriors: Array[Dictionary] = []
## Each: {pos, vel}
var darts: Array[Dictionary] = []


func _init() -> void:
	prompt = "BREAK THE CURSE!"
	controls_hint = "ARROW KEYS / MOUSE"
	touch_hint = "LEFT / RIGHT OR DRAG"
	controls = Controls.LEFT_RIGHT
	duration = 25.0
	is_boss = true
	win_on_timeout = false


func _on_start() -> void:
	var flash_shader := Shader.new()
	flash_shader.code = FLASH_SHADER
	material = ShaderMaterial.new()
	(material as ShaderMaterial).shader = flash_shader
	var d := clampi(difficulty, 1, 3)
	max_hp = [4, 5, 6][d - 1]
	hp = max_hp
	max_balls = 3 if d < 3 else 2
	balls = max_balls
	paddle_w = [180.0, 160.0, 140.0][d - 1]
	speed = [740.0, 800.0, 860.0][d - 1]
	dart_timer = [99.0, 3.0, 2.2][d - 1]
	_build_blocks(5)
	for i in d - 1:
		_add_warrior(i)


func _build_blocks(count: int) -> void:
	blocks.clear()
	var gap := 6.0
	var x0 := SCREEN.x / 2 - (count * BLOCK_SIZE.x + (count - 1) * gap) / 2
	for i in count:
		blocks.append({"rect": Rect2(Vector2(x0 + i * (BLOCK_SIZE.x + gap), BLOCK_Y), BLOCK_SIZE), "alive": true, "flash": 0.0})


func _add_warrior(i: int) -> void:
	warriors.append({"x": 160.0 + i * 400.0, "dir": 1.0 if i % 2 == 0 else -1.0,
			"speed": 110.0 + 30.0 * difficulty, "flash": 0.0})


func _process(delta: float) -> void:
	elapsed += delta
	update_pointer()
	face_flash = maxf(face_flash - delta, 0.0)
	face_cooldown = maxf(face_cooldown - delta, 0.0)
	stun = maxf(stun - delta, 0.0)
	for b in blocks:
		b.flash = maxf(b.flash - delta, 0.0)
	for w in warriors:
		w.flash = maxf(w.flash - delta, 0.0)
		if not dying:
			w.x += w.dir * w.speed * delta
			if w.x < LEFT + 60 or w.x > RIGHT - 60:
				w.dir *= -1.0
				w.x = clampf(w.x, LEFT + 60, RIGHT - 60)
	if is_playing() and not dying:
		_move_paddle(delta)
		_move_ball(delta)
		if elapsed > WARMUP:
			_spit(delta)
	_move_darts(delta)
	if dying:
		_die(delta)
	queue_redraw()


func _move_paddle(delta: float) -> void:
	paddle_dir = 0.0
	if stun > 0.0:
		return
	var axis := Input.get_axis("left", "right")
	var half := paddle_w / 2
	if axis != 0.0:
		paddle_dir = axis
		paddle_x += axis * PADDLE_SPEED * delta
	elif pointer_down and pointer.y < CONTROLS_TOP:
		# Follow a held finger or mouse.
		var step := clampf(pointer.x - paddle_x, -PADDLE_SPEED * 1.6 * delta, PADDLE_SPEED * 1.6 * delta)
		paddle_dir = signf(step)
		paddle_x += step
	paddle_x = clampf(paddle_x, LEFT + half, RIGHT - half)


func _move_ball(delta: float) -> void:
	if held:
		ball = Vector2(paddle_x, PADDLE_Y - BALL_R - 2)
		serve_timer -= delta
		if serve_timer <= 0.0:
			held = false
			var angle := randf_range(-0.4, 0.4)
			vel = Vector2(sin(angle), -cos(angle)) * speed
			Sfx.play("spring", 0.6)
		return
	# Small steps so the ball never tunnels through a block.
	var travel := vel.length() * delta
	var steps := maxi(1, ceili(travel / 10.0))
	for i in steps:
		ball += vel * (delta / steps)
		_collide()
		if held or ball_lost:
			break
	roll += travel
	if not ball_lost and ball.y > LOST_Y:
		_lose_ball()


func _collide() -> void:
	# Walls.
	if ball.x < LEFT + BALL_R:
		ball.x = LEFT + BALL_R
		vel.x = absf(vel.x)
		_wall_tick()
	elif ball.x > RIGHT - BALL_R:
		ball.x = RIGHT - BALL_R
		vel.x = -absf(vel.x)
		_wall_tick()
	if ball.y < TOP + BALL_R:
		ball.y = TOP + BALL_R
		vel.y = absf(vel.y)
		_wall_tick()

	# Tlaloc's face.
	if not gone and ball.distance_to(FACE_POS) < FACE_R + BALL_R:
		var normal := (ball - FACE_POS).normalized()
		ball = FACE_POS + normal * (FACE_R + BALL_R)
		if vel.dot(normal) < 0.0:
			vel = vel.bounce(normal).rotated(randf_range(-0.12, 0.12))
			_fix_angle()
		if face_cooldown <= 0.0:
			_hit_face()

	# Guard stones.
	for b in blocks:
		if b.alive and _bounce_rect(b.rect):
			b.alive = false
			var r: Rect2 = b.rect
			burst(r.get_center(), Color("8a9a86"), 12, 320, 10)
			Sfx.play("crunch", 0.8)
			break

	# Warriors.
	for w in warriors:
		if _bounce_rect(_warrior_box(w)):
			w.flash = 0.15
			Sfx.play("thud", 0.8, 1.2)
			break

	# The paddle.
	if vel.y > 0.0 and ball.y + BALL_R >= PADDLE_Y and ball.y < PADDLE_Y + PADDLE_H \
			and absf(ball.x - paddle_x) < paddle_w / 2 + BALL_R * 0.7:
		var offset := clampf((ball.x - paddle_x) / (paddle_w / 2), -1.0, 1.0)
		var angle := offset * MAX_ANGLE + paddle_dir * 0.12
		vel = Vector2(sin(angle), -cos(angle)) * speed
		ball.y = PADDLE_Y - BALL_R
		_fix_angle()
		Sfx.play("spring", 0.5, 1.4)


## Bounces the ball off [param rect] if it overlaps it; returns whether it did.
func _bounce_rect(rect: Rect2) -> bool:
	if not circle_hits_rect(ball, BALL_R, rect):
		return false
	var closest := Vector2(clampf(ball.x, rect.position.x, rect.end.x), clampf(ball.y, rect.position.y, rect.end.y))
	var normal := ball - closest
	if normal.length_squared() < 0.01:
		normal = -vel
	normal = normal.normalized()
	ball = closest + normal * (BALL_R + 0.5)
	if vel.dot(normal) < 0.0:
		vel = vel.bounce(normal)
	_fix_angle()
	return true


## Keeps the ball at full speed and never too flat.
func _fix_angle() -> void:
	var dir := vel.normalized()
	if absf(dir.y) < MIN_RISE:
		dir.y = MIN_RISE * (signf(dir.y) if dir.y != 0.0 else -1.0)
		dir.x = signf(dir.x) * sqrt(1.0 - MIN_RISE * MIN_RISE)
	vel = dir.normalized() * speed


func _wall_tick() -> void:
	Sfx.play("tap", 0.5)


func _warrior_box(w: Dictionary) -> Rect2:
	return Rect2(w.x - 26, WARRIOR_Y - 40, 52, 80)


func _hit_face() -> void:
	face_cooldown = 0.2
	hp -= 1
	face_flash = 0.12
	speed += 30.0
	vel = vel.normalized() * speed
	var at := FACE_POS + (ball - FACE_POS).normalized() * FACE_R
	burst(at, Color("9ff0c8"), 14, 380, 10)
	shake(8)
	Sfx.play("hit")
	if hp <= 0:
		dying = true
		death_t = 0.0
		held = false
		Sfx.play("boom", 0.8, 1.1)
	elif not angry and hp <= max_hp / 2.0:
		angry = true
		popup("RUMBLE!", FACE_POS + Vector2(0, 170), Color("ff4d6d"), 60)
		shake(14)
		Sfx.play("thud")
		Sfx.play("zap", 0.7, 0.6)
		_build_blocks(3)
		_add_warrior(warriors.size())
		dart_timer = 0.8
	else:
		popup("CRACK!", at + Vector2(0, 40), Color("f2c14e"), 44)


func _spit(delta: float) -> void:
	dart_timer -= delta
	if dart_timer > 0.0:
		return
	dart_timer = [2.4, 1.8, 1.3][difficulty - 1] if angry else [99.0, 3.0, 2.2][difficulty - 1]
	var mouth := FACE_POS + Vector2(0, 90)
	var aim := Vector2(paddle_x + randf_range(-60, 60), PADDLE_Y) - mouth
	darts.append({"pos": mouth, "vel": aim.normalized() * (440.0 + 60.0 * difficulty)})
	Sfx.play("whoosh", 0.6, 1.3)


func _move_darts(delta: float) -> void:
	var paddle := Rect2(paddle_x - paddle_w / 2, PADDLE_Y, paddle_w, PADDLE_H)
	for d in darts:
		d.pos += d.vel * delta
		if d.pos.y > LOST_Y:
			d.dead = true
		elif is_playing() and not dying and circle_hits_rect(d.pos, 14, paddle):
			d.dead = true
			stun = 0.7
			burst(d.pos, Color("8fd3ff"), 10, 300, 8)
			popup("ZAP!", Vector2(paddle_x, PADDLE_Y - 70), Color("8fd3ff"), 48)
			Sfx.play("zap")
	darts = darts.filter(func(d: Dictionary) -> bool: return not d.get("dead", false))


func _lose_ball() -> void:
	ball_lost = true
	balls -= 1
	burst(Vector2(ball.x, LOST_Y - 20), Color("8fd3ff"), 16, 420, 10)
	Sfx.play("splash")
	if balls <= 0:
		burst(Vector2(paddle_x, PADDLE_Y), Color("f2c14e"), 24, 480, 12)
		Sfx.play("crunch")
		lose()
		return
	shake(10)
	popup("%d LEFT" % balls, Vector2(SCREEN.x / 2, 760), Color("ff4d6d"), 56)
	held = true
	ball_lost = false
	serve_timer = 0.7


func _die(delta: float) -> void:
	death_t += delta
	# Never let the fuse run out mid-explosion.
	var length := minf(DEATH_TIME, duration - elapsed - 0.1)
	if not gone and int(death_t * 12.0) != int((death_t - delta) * 12.0):
		var spot := FACE_POS + Vector2(randf_range(-100, 100), randf_range(-100, 100))
		burst(spot, [Color("9ff0c8"), Color("f2c14e"), Color("8a9a86")].pick_random(), 10, 360, 10)
		Sfx.play("boom", 0.4, randf_range(1.0, 1.4))
		shake(8)
	if not gone and death_t >= length:
		gone = true
		for d in darts:
			burst(d.pos, Color("8fd3ff"), 6, 200, 6)
		darts.clear()
		for w in warriors:
			burst(Vector2(w.x, WARRIOR_Y), Color("f2c14e"), 10, 300, 8)
		warriors.clear()
		for b in blocks:
			if b.alive:
				b.alive = false
				var r: Rect2 = b.rect
				burst(r.get_center(), Color("8a9a86"), 10, 300, 10)
		burst(FACE_POS, Color("9ff0c8"), 40, 700, 14)
		burst(FACE_POS, Color("f2c14e"), 30, 520, 12)
		popup("CURSE BROKEN!", FACE_POS + Vector2(0, 40), Color("f2c14e"), 72)
		shake(20)
		Sfx.play("boom")
		win()


func _on_resolved(result: bool) -> void:
	if not result:
		face_flash = 0.0
		popup("HA HA HA!", FACE_POS + Vector2(0, 170), Color("9ff0c8"), 56)


# --- Drawing ----------------------------------------------------------------

func _draw() -> void:
	var theme := Stages.theme(stage)
	_draw_temple(theme)
	_draw_face()
	for b in blocks:
		if b.alive:
			_draw_block(b.rect, b.flash > 0.0)
	for w in warriors:
		var tint := FLASH if w.flash > 0.0 else Color.WHITE
		draw_sprite("temple/t_warrior", 5, anim_frame(8, 5, w.x * 0.01), Vector2(w.x, WARRIOR_Y), 4.0, w.dir < 0, tint)
	for d in darts:
		draw_sprite("temple/t_dart_falling", 1, 0, d.pos, 4.0, false, Color.WHITE, d.vel.angle() - PI / 2)
	_draw_paddle()
	if balls > 0 and not gone:
		draw_sprite("temple/iron_Ball", 16, int(roll / 14.0), ball, 3.0)
	_draw_hud(theme)


func _draw_temple(theme: Dictionary) -> void:
	var top: Color = theme.sky
	var low: Color = theme.sky_low
	if angry and not gone:
		top = top.lerp(Color("2a1030"), 0.45)
	for i in 16:
		draw_rect(Rect2(0, SCREEN.y * i / 16.0, SCREEN.x, SCREEN.y / 16.0 + 1), top.lerp(low, i / 15.0))
	# Mossy stone courses behind the play field.
	for row in 17:
		for col in 6:
			var x := col * 140.0 + (70.0 if row % 2 else 0.0) - 70.0
			var y := 100.0 + row * 60.0
			draw_rect(Rect2(x + 2, y + 2, 136, 56), Color("4d5a4f").lerp(Color("26302a"), row / 17.0).darkened(0.25))
	# Side walls.
	for x in [0.0, RIGHT]:
		draw_rect(Rect2(x, TOP - 12, LEFT, SCREEN.y), Color("6b6355"))
		draw_rect(Rect2(x + (LEFT - 6 if x == 0.0 else 0.0), TOP - 12, 6, SCREEN.y), Color("f2c14e", 0.6))
	draw_rect(Rect2(0, TOP - 14, SCREEN.x, 14), Color("6b6355"))
	draw_sprite("temple/t_totem_heads", 3, 0, Vector2(130, 270), 4.0, false, Color(0.7, 0.7, 0.7))
	draw_sprite("temple/t_totem_heads", 3, 2, Vector2(590, 270), 4.0, false, Color(0.7, 0.7, 0.7))
	for x in [LEFT / 2, RIGHT + LEFT / 2]:
		draw_sprite("temple/t_torch", 12, anim_frame(10, 4, x), Vector2(x, 720), 4.0)
	# The pit under the paddle.
	draw_rect(Rect2(LEFT, LOST_Y - 60, RIGHT - LEFT, SCREEN.y), Color(0.05, 0.12, 0.15, 0.55))
	draw_sprite("temple/t_kickback_frog", 3, anim_frame(3, 3), Vector2(LEFT + 50, LOST_Y + 30), 4.0)
	draw_sprite("temple/t_wall_jaguar", 3, 0, Vector2(RIGHT - 70, LOST_Y + 20), 4.0)
	# Rain; it pours once he's angry.
	var count := 50 if angry else 24
	for i in count:
		var p := Vector2(fmod(i * 97.0 + elapsed * 40.0, 720.0), fmod(i * 173.0 + elapsed * 620.0, 1180.0) + 100.0)
		draw_sprite("temple/t_raindrop", 1, 0, p, 3.0, false, Color(0.75, 0.9, 1.0, 0.5))


func _draw_face() -> void:
	var tint := Color.WHITE
	if face_flash > 0.0 or (dying and not gone and int(death_t * 16.0) % 2 == 0):
		tint = FLASH
	var pos := FACE_POS
	if dying and not gone:
		pos += Vector2(randf_range(-8, 8), randf_range(-8, 8))
	draw_circle(FACE_POS, FACE_R + 14, Color(0, 0, 0, 0.35))
	if gone:
		draw_sprite("temple/eyeless", 2, 1, pos, 4.0, false, Color(0.45, 0.45, 0.45))
		return
	var frame := 1 if (angry or face_flash > 0.0 or (is_resolved and not won)) else 0
	draw_sprite("temple/tlaloc", 2, frame, pos, 4.0, false, tint)


func _draw_block(r: Rect2, flash: bool) -> void:
	draw_rect(r, Color.WHITE if flash else Color("8a9a86"))
	draw_rect(r.grow(-5), Color("6f7d6b"))
	draw_sprite("temple/t_glyph_tile", 2, int(r.position.x) % 2, r.get_center(), 3.0)
	draw_rect(r, Color("2f3a33"), false, 3.0)


func _draw_paddle() -> void:
	var r := Rect2(paddle_x - paddle_w / 2, PADDLE_Y, paddle_w, PADDLE_H)
	var lost := is_resolved and not won and balls <= 0
	if lost:
		return
	var body := Color("8fd3ff") if stun > 0.0 and int(stun * 16.0) % 2 == 0 else Color("f2c14e")
	draw_rect(r.grow(4), Color("2f3a33"))
	draw_rect(r, body)
	draw_rect(Rect2(r.position, Vector2(26, PADDLE_H)), Color("2a9d8f"))
	draw_rect(Rect2(r.end.x - 26, r.position.y, 26, PADDLE_H), Color("2a9d8f"))
	var tiles := int((paddle_w - 60) / 24.0)
	for i in tiles:
		draw_sprite("temple/t_glyph_tile", 2, i % 2, Vector2(paddle_x - (tiles - 1) * 12.0 + i * 24.0, PADDLE_Y + PADDLE_H / 2), 3.0)


func _draw_hud(theme: Dictionary) -> void:
	_draw_health_bar(theme.boss_name, face_flash > 0.0)
	draw_sprite("temple/tlaloc", 2, 1 if angry else 0, Vector2(BAR_RECT.position.x - 44, BAR_RECT.get_center().y), 1.0)
	# Spare balls.
	for i in max_balls:
		var tint := Color.WHITE if i < balls else Color(0.2, 0.2, 0.2, 0.6)
		draw_sprite("temple/iron_Ball", 16, 0, Vector2(LEFT + 30 + i * 40, TOP + 28), 2.0, false, tint)


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
