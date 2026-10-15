extends Microgame
## BOSS: BEAT MR HAT! Jon fires stakes straight up on his own; slide him under
## Mr Hat to hit him and out from under the top-hat tornadoes he drops. At half
## health he gets angry: faster, tornadoes in threes, and bats that dive at Jon.

const GROUND_Y := 1000.0
const JON_SCALE := 5.0
const JON_SPEED := 640.0
const HAT_SCALE := 2.0
const HAT_Y := 330.0
const STAKE_SPEED := 1350.0
const FIRE_EVERY := 0.2
const BAR_RECT := Rect2(130, 70, 530, 26)
## The grace period while the prompt word is on screen.
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

var max_hp := 22
var hp := 22
var hearts := 3
var max_hearts := 3
var angry := false

var jon_x := SCREEN.x / 2
var jon_dir := 0.0
var jon_facing := 1.0
var jon_hurt := 0.0
var jon_down := false
var fire_timer := 0.0

var hat_pos := Vector2(SCREEN.x / 2, HAT_Y)
var hat_t := 0.0
var hat_flash := 0.0
var drop_timer := 1.6
var bat_timer := 1.0
var dying := false
var death_t := 0.0
var gone := false

var elapsed := 0.0
var stakes: Array[Vector2] = []
## Each: {pos, vel, spin}
var tornadoes: Array[Dictionary] = []
## Each: {pos, vel}
var bats: Array[Dictionary] = []


func _init() -> void:
	prompt = "BEAT MR HAT!"
	controls_hint = "ARROW KEYS / MOUSE"
	touch_hint = "LEFT / RIGHT OR DRAG"
	controls = Controls.LEFT_RIGHT
	duration = 22.0
	is_boss = true
	win_on_timeout = false


func _on_start() -> void:
	var flash_shader := Shader.new()
	flash_shader.code = FLASH_SHADER
	material = ShaderMaterial.new()
	(material as ShaderMaterial).shader = flash_shader
	max_hp = [20, 24, 28][clampi(difficulty, 1, 3) - 1]
	hp = max_hp
	max_hearts = 3
	hearts = max_hearts


func _process(delta: float) -> void:
	elapsed += delta
	hat_flash = maxf(hat_flash - delta, 0.0)
	jon_hurt = maxf(jon_hurt - delta, 0.0)
	_move_hat(delta)
	if is_playing() and not dying:
		_move_jon(delta)
		_fire(delta)
		if elapsed > WARMUP:
			_attack(delta)
	else:
		jon_dir = 0.0
	_move_stakes(delta)
	_move_hazards(delta)
	if dying:
		_die(delta)
	queue_redraw()


func _move_jon(delta: float) -> void:
	jon_dir = Input.get_axis("left", "right")
	update_pointer()
	if jon_dir == 0.0 and pointer_down and pointer.y < CONTROLS_TOP and absf(pointer.x - jon_x) > 12.0:
		# Run toward a held finger or mouse.
		jon_dir = signf(pointer.x - jon_x)
	if jon_dir != 0.0:
		jon_facing = signf(jon_dir)
	jon_x = clampf(jon_x + jon_dir * JON_SPEED * delta, 50, SCREEN.x - 50)


func _fire(delta: float) -> void:
	fire_timer -= delta
	if fire_timer <= 0.0:
		fire_timer = FIRE_EVERY
		stakes.append(Vector2(jon_x + 6 * jon_facing, GROUND_Y - 110))
		Sfx.play("swish", 0.25, randf_range(1.3, 1.6))


func _move_hat(delta: float) -> void:
	if gone:
		return
	var pace := (1.7 if angry else 1.1) + 0.15 * (difficulty - 1)
	if dying:
		pace = 0.0
	hat_t += delta * pace
	hat_pos = Vector2(SCREEN.x / 2 + sin(hat_t) * 230.0, HAT_Y + sin(hat_t * 2.3) * 30.0)
	if dying:
		hat_pos += Vector2(randf_range(-10, 10), randf_range(-10, 10))


func _hat_box() -> Rect2:
	return Rect2(hat_pos + Vector2(-80, -105), Vector2(160, 215))


func _attack(delta: float) -> void:
	drop_timer -= delta
	if drop_timer <= 0.0:
		var fall := 420.0 + 50.0 * difficulty
		var at := hat_pos + Vector2(0, 90)
		tornadoes.append({"pos": at, "vel": Vector2(0, fall)})
		if angry:
			var side := 150.0 + 20.0 * difficulty
			tornadoes.append({"pos": at, "vel": Vector2(-side, fall * 0.9)})
			tornadoes.append({"pos": at, "vel": Vector2(side, fall * 0.9)})
			drop_timer = [1.35, 1.2, 1.05][difficulty - 1]
		else:
			drop_timer = [1.1, 0.95, 0.8][difficulty - 1]
		Sfx.play("whoosh", 0.6, 0.8)
	if angry:
		bat_timer -= delta
		if bat_timer <= 0.0:
			bat_timer = [2.2, 1.8, 1.5][difficulty - 1]
			var from := Vector2(-40.0 if randf() < 0.5 else SCREEN.x + 40.0, randf_range(420, 560))
			var aim := Vector2(jon_x, GROUND_Y - 60) - from
			bats.append({"pos": from, "vel": aim.normalized() * (360.0 + 60.0 * difficulty)})


func _move_stakes(delta: float) -> void:
	var kept: Array[Vector2] = []
	for s in stakes:
		var p := s + Vector2(0, -STAKE_SPEED * delta)
		if p.y < 90:
			continue
		if not dying and not gone and _hat_box().has_point(p):
			_hit_hat(p)
			continue
		var hit_bat := false
		for b in bats:
			if p.distance_to(b.pos) < 44:
				hit_bat = true
				b.dead = true
				burst(b.pos, Color("8f7fd6"), 10, 300, 8)
				popup("POP!", b.pos, Color("ffe8a3"), 40)
				Sfx.play("pop")
				break
		if not hit_bat:
			kept.append(p)
	stakes = kept
	bats = bats.filter(func(b: Dictionary) -> bool: return not b.get("dead", false))


func _hit_hat(p: Vector2) -> void:
	hp -= 1
	hat_flash = 0.08
	burst(p, Color("ffe8a3"), 5, 240, 6)
	Sfx.play("hit", 0.5, randf_range(0.9, 1.2))
	if hp <= 0:
		dying = true
		death_t = 0.0
		for t in tornadoes:
			burst(t.pos, Color("b9b4ff"), 6, 200, 6)
		for b in bats:
			burst(b.pos, Color("8f7fd6"), 6, 200, 6)
		tornadoes.clear()
		bats.clear()
		Sfx.play("boom", 0.8, 1.2)
	elif not angry and hp <= max_hp / 2:
		angry = true
		popup("GRRR!", hat_pos + Vector2(0, -150), Color("ff4d6d"), 64)
		shake(14)
		Sfx.play("zap")
		drop_timer = 0.6
		bat_timer = 0.4


func _move_hazards(delta: float) -> void:
	var jon_box := Rect2(jon_x - 24, GROUND_Y - 108, 48, 104)
	for t in tornadoes:
		t.pos += t.vel * delta
		if t.pos.x < 50 or t.pos.x > SCREEN.x - 50:
			t.vel.x *= -1
			t.pos.x = clampf(t.pos.x, 50, SCREEN.x - 50)
		if t.pos.y > GROUND_Y - 40:
			t.dead = true
			burst(Vector2(t.pos.x, GROUND_Y - 10), Color("b9b4ff"), 6, 180, 6)
		elif jon_hurt <= 0.0 and is_playing() and circle_hits_rect(t.pos + Vector2(0, 8), 24, jon_box):
			t.dead = true
			_hurt_jon(t.pos)
	tornadoes = tornadoes.filter(func(t: Dictionary) -> bool: return not t.get("dead", false))
	for b in bats:
		b.pos += b.vel * delta
		if b.pos.y > GROUND_Y + 40 or b.pos.x < -120 or b.pos.x > SCREEN.x + 120:
			b.dead = true
		elif jon_hurt <= 0.0 and is_playing() and circle_hits_rect(b.pos, 22, jon_box):
			b.dead = true
			_hurt_jon(b.pos)
	bats = bats.filter(func(b: Dictionary) -> bool: return not b.get("dead", false))


func _hurt_jon(from: Vector2) -> void:
	if not is_playing() or dying or jon_hurt > 0.0:
		return
	hearts -= 1
	burst(Vector2(jon_x, GROUND_Y - 60), Color("ff4d6d"), 14, 380, 9)
	if hearts <= 0:
		jon_down = true
		Sfx.play("crunch")
		lose()
		return
	jon_hurt = 1.2
	popup("OUCH!", Vector2(jon_x, GROUND_Y - 170), Color("ff4d6d"), 52)
	shake(10)
	Sfx.play("hit")
	jon_x = clampf(jon_x + signf(jon_x - from.x + 0.01) * 50.0, 50, SCREEN.x - 50)


func _die(delta: float) -> void:
	death_t += delta
	# Never let the fuse run out mid-explosion.
	var length := minf(DEATH_TIME, duration - elapsed - 0.1)
	if not gone and int(death_t * 12.0) != int((death_t - delta) * 12.0):
		var spot := hat_pos + Vector2(randf_range(-90, 90), randf_range(-100, 100))
		burst(spot, [Color("ffe8a3"), Color("ff9a3c"), Color("b9b4ff")].pick_random(), 10, 360, 10)
		Sfx.play("boom", 0.4, randf_range(1.1, 1.5))
		shake(8)
	if not gone and death_t >= length:
		gone = true
		burst(hat_pos, Color("ffe8a3"), 40, 700, 14)
		burst(hat_pos, Color("ff9a3c"), 30, 500, 12)
		popup("BOOM!", hat_pos, Color("ffe8a3"), 96)
		shake(20)
		Sfx.play("boom")
		win()


func _on_resolved(result: bool) -> void:
	if not result and not gone:
		popup("HA HA HA!", hat_pos + Vector2(0, -150), Color("b9b4ff"), 56)


# --- Drawing ----------------------------------------------------------------

func _draw() -> void:
	var theme := Stages.theme(stage)
	_draw_graveyard(theme)

	for s in stakes:
		draw_sprite("graveyard/wood_stake_shot", 1, 0, s, 4.0)
	if not gone:
		_draw_hat()
	elif death_t < DEATH_TIME + 0.6:
		# His hat sails off into the night.
		var k := (death_t - DEATH_TIME) * 2.0
		draw_sprite("graveyard/tornado_hat", 4, 0, hat_pos + Vector2(k * 140.0, -k * 420.0 + k * k * 80.0), 3.0,
				false, Color(1, 1, 1, clampf(1.0 - k * 0.5, 0, 1)), k * 6.0)
	for t in tornadoes:
		draw_sprite("graveyard/tornado_hat", 4, anim_frame(14, 4), t.pos, 3.0)
	for b in bats:
		draw_sprite("graveyard/bat", 4, anim_frame(12, 4), b.pos, 3.0, b.vel.x < 0)
	_draw_jon()
	_draw_hud(theme)


func _draw_graveyard(theme: Dictionary) -> void:
	var top: Color = theme.sky
	var low: Color = theme.sky_low
	if angry and not gone:
		top = top.lerp(Color("4a1030"), 0.5)
	for i in 40:
		draw_rect(Rect2(0, GROUND_Y * i / 40.0, SCREEN.x, GROUND_Y / 40.0 + 1), top.lerp(low, i / 39.0))
	draw_circle(Vector2(590, 190), 70, Color("fff2c4"))
	draw_circle(Vector2(563, 172), 70, top.lerp(low, 0.15))
	var t := elapsed
	draw_sprite("swamp/tree_owl", 5, int(t * 4.0), Vector2(110, GROUND_Y - 150), 2.0, false, Color(0.6, 0.55, 0.75))
	draw_sprite("graveyard/mausoleum", 1, 0, Vector2(620, GROUND_Y - 116), 2.0, false, Color(0.6, 0.55, 0.72))
	draw_sprite("graveyard/grave_2", 1, 0, Vector2(250, GROUND_Y - 48), 3.0, false, Color(0.85, 0.82, 0.9))
	draw_sprite("graveyard/grave_1_small", 1, 0, Vector2(470, GROUND_Y - 48), 3.0, false, Color(0.85, 0.82, 0.9))
	var ground: Color = theme.ground
	draw_rect(Rect2(0, GROUND_Y, SCREEN.x, SCREEN.y - GROUND_Y), ground)
	draw_rect(Rect2(0, GROUND_Y, SCREEN.x, 10), ground.lightened(0.25))
	draw_sprite("graveyard/pumpkin", 6, anim_frame(6, 6), Vector2(60, GROUND_Y - 24), 3.0)
	draw_sprite("graveyard/prop_pumpkin_pile", 1, 0, Vector2(668, GROUND_Y - 36), 3.0)
	# Low fog.
	for i in 3:
		draw_rect(Rect2(-60 + sin(t * 0.7 + i) * 50.0, GROUND_Y - 40 + i * 14, 840, 18), Color(0.8, 0.75, 1.0, 0.06))


func _draw_hat() -> void:
	var tint := Color.WHITE
	if hat_flash > 0.0 or (dying and int(death_t * 16.0) % 2 == 0):
		tint = FLASH
	elif angry:
		tint = Color(1.0, 0.55 + 0.15 * sin(elapsed * 10.0), 0.6)
	if is_resolved and not won:
		tint = Color.WHITE
	# A shadow on the ground tracks him, so it's easy to line up under him.
	var shadow := Color(0, 0, 0, 0.25)
	draw_colored_polygon(ellipse_points(Vector2(hat_pos.x, GROUND_Y + 14), Vector2(70, 10)), shadow)
	if angry and not dying:
		var glow := 0.5 + 0.5 * sin(elapsed * 10.0)
		draw_circle(hat_pos + Vector2(0, 20), 120 + glow * 14.0, Color(1, 0.2, 0.3, 0.18 + glow * 0.1))
	draw_sprite("graveyard/mr_hat", 5, anim_frame(8, 5), hat_pos, HAT_SCALE, false, tint)


func _draw_jon() -> void:
	var pos := Vector2(jon_x, GROUND_Y - 60)
	if jon_down:
		draw_sprite("graveyard/idle_jon", 5, 0, pos + Vector2(0, 30), JON_SCALE, jon_facing < 0, Color(1, 0.5, 0.5), -PI / 2)
		return
	if jon_hurt > 0.0 and int(jon_hurt * 14.0) % 2 == 0:
		return
	if jon_dir != 0.0:
		draw_sprite("graveyard/run_jon", 4, anim_frame(12, 4), pos, JON_SCALE, jon_facing < 0)
	else:
		draw_sprite("graveyard/idle_jon", 5, anim_frame(8, 5), pos, JON_SCALE, jon_facing < 0)


func _draw_hud(theme: Dictionary) -> void:
	_draw_health_bar(theme.boss_name, hat_flash > 0.0)
	draw_sprite("graveyard/tornado_hat", 4, 0, Vector2(BAR_RECT.position.x - 44, BAR_RECT.get_center().y), 2.0)
	for i in max_hearts:
		var path := "graveyard/heart" if i < hearts else "graveyard/heart_empty"
		draw_sprite(path, 1, 0, Vector2(60 + i * 56, 152), 3.0)


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
