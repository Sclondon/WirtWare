extends Microgame
## WHACK! Bonk each one with the arrow key for its hole. Swinging at the wrong hole loses.
## Graveyard: zombies out of graves. Temple: warriors out of stone pits.
## Swamp: sludge toads out of the muck.

const HOLES := {
	"up": Vector2(360, 340),
	"left": Vector2(165, 600),
	"right": Vector2(555, 600),
	"down": Vector2(360, 860),
}
const DIRECTIONS := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}
const HOLE_RADII := Vector2(85, 28)
const RISE_TIME := 0.08
## Per stage: sprite, frames, frame size, scale, how much of it pokes out.
const MOLES: Array[Array] = [
	["graveyard/zombie", 6, Vector2(16, 24), 7.0, 0.75],
	["temple/warrior", 5, Vector2(17, 23), 7.0, 0.7],
	["swamp/sludge_toad", 4, Vector2(24, 24), 6.0, 0.85],
]

var needed := 3
var hits := 0
var mole_hole := ""
var last_hole := ""
var mole_time := 0.0
var mole_up_time := 1.0
var cooldown := 0.6
var bonked_hole := ""
var bonk_timer := 0.0
## Where the last swing landed, and how long ago (for drawing the mallet).
var swing_hole := ""
var swing_timer := 0.0


func _init() -> void:
	prompt = "WHACK!"
	controls_hint = "ARROW KEYS"
	touch_hint = "USE THE ARROWS"
	controls = Controls.ARROWS
	duration = 4.5


func _on_start() -> void:
	needed = 2 + difficulty
	mole_up_time = 1.0 - 0.15 * difficulty


func _process(delta: float) -> void:
	bonk_timer = maxf(bonk_timer - delta, 0.0)
	swing_timer = maxf(swing_timer - delta, 0.0)
	if is_playing():
		if mole_hole == "":
			cooldown -= delta
			if cooldown <= 0.0:
				_pop_mole()
		else:
			mole_time += delta
			if mole_time > mole_up_time:
				mole_hole = ""
				cooldown = 0.15
			else:
				_check_swing()
	queue_redraw()


func _check_swing() -> void:
	for hole: String in HOLES:
		if not Input.is_action_just_pressed(hole):
			continue
		swing_hole = hole
		swing_timer = 0.25
		var center: Vector2 = HOLES[hole]
		if hole != mole_hole:
			bonked_hole = hole
			Sfx.play("thud")
			burst(center, Color("8a7a66"), 10, 300.0, 8.0)
			lose()
			return
		hits += 1
		bonked_hole = hole
		bonk_timer = 0.35
		mole_hole = ""
		cooldown = 0.15
		Sfx.play("squish" if stage == Stages.SWAMP else "hit")
		Sfx.play("thud", 0.6)
		burst(center + Vector2(0, -60), Stages.theme(stage).accent, 12, 420.0, 9.0)
		popup("BONK!" if hits < needed else "GOT 'EM!", center + Vector2(0, -150), Stages.theme(stage).glow, 52)
		shake(5.0)
		if hits >= needed:
			win()
		return


func _pop_mole() -> void:
	var options := HOLES.keys().filter(func(h: String) -> bool: return h != last_hole)
	mole_hole = options.pick_random()
	last_hole = mole_hole
	mole_time = 0.0
	Sfx.play("tap", 0.5, 0.8)


func _draw() -> void:
	var theme := Stages.theme(stage)
	var ground: Color = theme.ground
	draw_rect(Rect2(Vector2.ZERO, SCREEN), ground)
	match stage:
		Stages.GRAVEYARD:
			for i in 16:
				var p := Vector2(fposmod(i * 173.0, SCREEN.x), 160 + i * 66)
				for k in 3:
					draw_line(p + Vector2(k * 8 - 8, 0), p + Vector2(k * 10 - 12, -16), Color("4f6a3a"), 4)
		Stages.TEMPLE:
			for row in 14:
				for col in 6:
					var x := col * 130.0 + (65.0 if row % 2 else 0.0) - 40.0
					draw_rect(Rect2(x, row * 96.0, 126, 92), ground.lightened(0.06 * ((row + col) % 3)))
		_:
			for i in 9:
				var p := Vector2(fposmod(i * 211.0 + 60, SCREEN.x), 180 + i * 110)
				draw_colored_polygon(ellipse_points(p, Vector2(70, 18)), ground.darkened(0.25))
	draw_text_centered("%d / %d" % [hits, needed], Vector2(360, 1000), 60)

	var lost := is_resolved and not won
	for hole: String in HOLES:
		var center: Vector2 = HOLES[hole]
		_draw_hole_back(center)
		draw_arrow(center + Vector2(0, 80), DIRECTIONS[hole], 50, Color(1, 1, 1, 0.8))

		var showing_bonk := hole == bonked_hole and bonk_timer > 0.0
		if hole == mole_hole or showing_bonk:
			var rise := 1.0 if showing_bonk else clampf(mole_time / RISE_TIME, 0.0, 1.0)
			_draw_mole(center, rise, showing_bonk, lost)
			if showing_bonk:
				for i in 5:
					var a := TAU * i / 5.0 + _clock * 8.0
					draw_circle(center + Vector2(cos(a) * 70, sin(a) * 22 - 120), 9, Color("ffd60a"))
		elif lost and hole == bonked_hole:
			draw_text_centered("MISS!", center + Vector2(0, -80), 60, Color("ef476f"))
		_draw_hole_front(center)
		if hole == swing_hole and swing_timer > 0.0:
			_draw_mallet(center, swing_timer / 0.25)


func _draw_hole_back(center: Vector2) -> void:
	match stage:
		Stages.GRAVEYARD:
			draw_sprite("graveyard/grave_1_small", 1, 0, center + Vector2(0, -70), 3.0, false, Color(0.45, 0.4, 0.55))
			draw_colored_polygon(ellipse_points(center, HOLE_RADII + Vector2(14, 10)), Color("5c4433"))
			draw_colored_polygon(ellipse_points(center, HOLE_RADII), Color("1e1410"))
		Stages.TEMPLE:
			draw_colored_polygon(ellipse_points(center, HOLE_RADII + Vector2(16, 12), 0, TAU, 8), Color("8c836f"))
			draw_colored_polygon(ellipse_points(center, HOLE_RADII, 0, TAU, 8), Color("15120e"))
		_:
			draw_colored_polygon(ellipse_points(center, HOLE_RADII + Vector2(16, 10)), Color("3d5a2a"))
			draw_colored_polygon(ellipse_points(center, HOLE_RADII), Color("1a2a12"))
			var b := center + Vector2(sin(_clock * 3.0 + center.x) * 40.0, 0)
			draw_circle(b, 7.0 + 3.0 * sin(_clock * 6.0 + center.y), Color("6fa83a"))


## The near half of the rim, drawn over the bottom of whatever's in the hole.
func _draw_hole_front(center: Vector2) -> void:
	var rim: Color = [Color("5c4433"), Color("8c836f"), Color("3d5a2a")][stage]
	var lip := ellipse_points(center + Vector2(0, 2), HOLE_RADII + Vector2(14, 10), 0, PI, 16)
	draw_colored_polygon(lip, rim)


## The mole pokes up out of the hole: only the part above the rim is drawn.
func _draw_mole(center: Vector2, rise: float, bonked: bool, laughing: bool) -> void:
	var info: Array = MOLES[stage]
	var path: String = info[0]
	var frames: int = info[1]
	var size: Vector2 = info[2]
	var scale: float = info[3]
	var shown := size.y * float(info[4]) * rise
	if shown <= 0.5:
		return
	var frame := anim_frame(8, frames)
	if stage == Stages.TEMPLE:
		frame = 0
	var squash := Vector2(1.3, 0.6) if bonked else Vector2.ONE
	if laughing:
		squash = Vector2(1.0 + 0.06 * sin(_clock * 30.0), 1.0)
	var tint := Color(1, 0.6, 0.6) if bonked else Color.WHITE
	# A soft glow behind it so a thin zombie still pops off the ground.
	draw_circle(center + Vector2(0, -shown * scale * 0.5), 20.0 + shown * scale * 0.4, Color(Stages.theme(stage).glow, 0.16))
	draw_set_transform(center + Vector2(0, 4), 0.0, squash * scale)
	draw_texture_rect_region(art(path), Rect2(-size.x / 2, -shown, size.x, shown), Rect2(size.x * frame, 0, size.x, shown), tint)
	draw_set_transform(Vector2.ZERO)
	if laughing:
		draw_text_centered("HA HA!", center + Vector2(0, -size.y * scale - 20), 40, Stages.theme(stage).glow)


## A big mallet slamming down over the hole; [param k] runs 1 -> 0.
func _draw_mallet(center: Vector2, k: float) -> void:
	var angle := lerpf(0.0, 0.9, k)
	var pivot := center + Vector2(110, -40)
	draw_set_transform(pivot, angle)
	draw_rect(Rect2(-130, -10, 130, 20), Color("8d5a2b"))
	draw_rect(Rect2(-175, -45, 70, 90), Color("b0413e"))
	draw_rect(Rect2(-175, -45, 70, 18), Color("d9635f"))
	draw_set_transform(Vector2.ZERO)
