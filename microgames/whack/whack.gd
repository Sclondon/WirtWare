extends Microgame
## WHACK! Bonk each mole with the arrow key for its hole. Swinging at the wrong hole loses.

const HOLES := {
	"up": Vector2(360, 330),
	"left": Vector2(165, 590),
	"right": Vector2(555, 590),
	"down": Vector2(360, 850),
}
const DIRECTIONS := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}
const HOLE_RADII := Vector2(85, 28)
const RISE_TIME := 0.08

var needed := 3
var hits := 0
var mole_hole := ""
var last_hole := ""
var mole_time := 0.0
var mole_up_time := 1.0
var cooldown := 0.5
var bonked_hole := ""
var bonk_timer := 0.0


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
		if hole != mole_hole:
			bonked_hole = hole
			lose()
			return
		hits += 1
		bonked_hole = hole
		bonk_timer = 0.35
		mole_hole = ""
		cooldown = 0.15
		if hits >= needed:
			win()
		return


func _pop_mole() -> void:
	var options := HOLES.keys().filter(func(h: String) -> bool: return h != last_hole)
	mole_hole = options.pick_random()
	last_hole = mole_hole
	mole_time = 0.0


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("80b918"))
	for i in 12:
		draw_circle(Vector2(fposmod(i * 173.0, SCREEN.x), 150 + i * 83), 6, Color("70a800"))
	draw_text_centered("%d / %d" % [hits, needed], Vector2(360, 120), 60)

	for hole: String in HOLES:
		var center: Vector2 = HOLES[hole]
		draw_colored_polygon(ellipse_points(center, HOLE_RADII), Color("3e2723"))
		draw_arrow(center + Vector2(0, 80), DIRECTIONS[hole], 50, Color(1, 1, 1, 0.8))

		var showing_bonk := hole == bonked_hole and bonk_timer > 0.0
		var lost_here := hole == bonked_hole and is_resolved and not won
		if hole == mole_hole or showing_bonk:
			var rise := 1.0 if showing_bonk else clampf(mole_time / RISE_TIME, 0.0, 1.0)
			var mole := center + Vector2(0, 30 - 70 * rise)
			draw_circle(mole, 55, Color("8d6e63"))
			draw_circle(mole + Vector2(0, 14), 14, Color("f48fb1"))
			draw_face(mole + Vector2(0, -10), 55, not showing_bonk)
			if showing_bonk:
				for i in 5:
					draw_circle(mole + Vector2.from_angle(TAU * i / 5.0) * Vector2(80, 30) + Vector2(0, -70), 9, Color("ffd60a"))
		elif lost_here:
			draw_text_centered("MISS!", center + Vector2(0, -60), 60, Color("ef476f"))
		# Front lip of the hole hides the bottom of the mole.
		draw_colored_polygon(ellipse_points(center + Vector2(0, 2), HOLE_RADII, 0, PI, 16), Color("5d4037"))
		draw_colored_polygon(ellipse_points(center + Vector2(0, 30), Vector2(HOLE_RADII.x + 6, 20), 0, PI, 16), Color("80b918"))
