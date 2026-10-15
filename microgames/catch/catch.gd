extends Microgame
## CATCH! Slide the basket under the falling treat.
## Graveyard: candy corn into the candy basket. Temple: a gold coin into a stone
## offering bowl. Swamp: a potion into the witch's cauldron.

const BASKET_Y := 900.0
const BASKET_W := 170.0
const BASKET_SPEED := 700.0
const APPLE_R := 32.0
const GROUND_Y := 990.0

## The falling thing; kept as `apple` (tools/autopilot.gd reads it).
var basket_x := SCREEN.x / 2
var apple := Vector2.ZERO
var apple_vel := Vector2.ZERO
var caught := false
var spin := 0.0
## Squash on the basket when something lands in it, 1 -> 0.
var bounce := 0.0
var lean := 0.0


func _init() -> void:
	prompt = "CATCH!"
	controls_hint = "ARROW KEYS"
	touch_hint = "LEFT / RIGHT"
	controls = Controls.LEFT_RIGHT
	duration = 4.0


func _on_start() -> void:
	apple = Vector2(randf_range(110, SCREEN.x - 110), 170)
	var fall_time := 2.6 - 0.35 * difficulty
	apple_vel.y = (BASKET_Y - apple.y) / fall_time
	if difficulty >= 2:
		apple_vel.x = randf_range(150, 280) * (1.0 if randf() < 0.5 else -1.0)
	# Start the basket well away from where the apple will land, so the player has to move.
	var landing := _landing_x(fall_time)
	var half := BASKET_W / 2
	var gap := randf_range(250, 400)
	basket_x = landing + gap if landing + gap < SCREEN.x - half else landing - gap
	basket_x = clampf(basket_x, half, SCREEN.x - half)


## Where the apple reaches the basket, bouncing off the walls on the way.
func _landing_x(fall_time: float) -> float:
	var span := SCREEN.x - 2 * APPLE_R
	var x := fposmod(apple.x - APPLE_R + apple_vel.x * fall_time, 2 * span)
	return APPLE_R + (x if x <= span else 2 * span - x)


func _process(delta: float) -> void:
	bounce = maxf(bounce - delta * 4.0, 0.0)
	var axis := 0.0
	if is_playing():
		var half := BASKET_W / 2
		axis = Input.get_axis("left", "right")
		basket_x = clampf(basket_x + axis * BASKET_SPEED * delta, half, SCREEN.x - half)
	lean = lerpf(lean, axis * 0.12, minf(delta * 12.0, 1.0))

	if caught:
		apple = Vector2(basket_x, BASKET_Y + 6)
	elif active and apple.y < GROUND_Y:
		apple += apple_vel * delta
		spin += delta * (3.0 + absf(apple_vel.x) / 60.0) * signf(apple_vel.x + 0.01)
		if apple.x < APPLE_R or apple.x > SCREEN.x - APPLE_R:
			apple_vel.x *= -1
			apple.x = clampf(apple.x, APPLE_R, SCREEN.x - APPLE_R)
			Sfx.play("tap", 0.5)
		if not is_resolved and apple.y >= BASKET_Y - 8:
			# The rim counts too: a treat that clips the edge rolls in.
			if absf(apple.x - basket_x) < BASKET_W / 2 + APPLE_R * 0.3:
				caught = true
				win()
			else:
				lose()
		apple.y = minf(apple.y, GROUND_Y)
	queue_redraw()


func _on_resolved(result: bool) -> void:
	var color: Color = Stages.theme(stage).accent
	if result:
		bounce = 1.0
		burst(Vector2(basket_x, BASKET_Y - 10), color, 14, 380.0, 9.0)
		popup("GOT IT!", Vector2(basket_x, BASKET_Y - 140), Stages.theme(stage).glow, 60)
		Sfx.play(["pop", "coin", "splash"][stage])
		Sfx.play("coin", 0.5)
	else:
		Sfx.play(["crunch", "thud", "splash"][stage])
		var splat: Color = [Color("ffb347"), Color("f2c14e"), Color("8ee04a")][stage]
		burst(Vector2(apple.x, GROUND_Y), splat, 16, 420.0, 10.0)
		shake(8.0)


func _draw() -> void:
	var theme := Stages.theme(stage)
	var floor_y := GROUND_Y + APPLE_R - 10
	for i in 12:
		draw_rect(Rect2(0, floor_y * i / 12.0, SCREEN.x, floor_y / 12.0 + 1), (theme.sky as Color).lerp(theme.sky_low, i / 11.0))
	match stage:
		Stages.GRAVEYARD:
			draw_sprite("graveyard/tree", 1, 0, Vector2(90, floor_y - 170), 3.0, false, Color(0.55, 0.5, 0.65))
			draw_sprite("graveyard/tree_3", 1, 0, Vector2(640, floor_y - 170), 3.0, true, Color(0.55, 0.5, 0.65))
			draw_sprite("graveyard/prop_pumpkin_pile", 1, 0, Vector2(630, floor_y - 34), 3.0)
		Stages.TEMPLE:
			for col in 6:
				draw_rect(Rect2(col * 130.0 - 20, 90, 110, 70), Color("2f3a33"))
				draw_sprite("temple/t_glyph_tile", 2, col % 2, Vector2(col * 130.0 + 35, 125), 5.0, false, Color(1, 1, 1, 0.5))
			for x in [60.0, 660.0]:
				draw_sprite("temple/t_torch", 12, anim_frame(10, 4, x), Vector2(x, floor_y - 110), 5.0)
		_:
			draw_sprite("swamp/tree_5", 1, 0, Vector2(100, floor_y - 170), 3.0, false, Color(0.45, 0.6, 0.45))
			for i in 4:
				draw_rect(Rect2(-60 + sin(_clock * 0.7 + i) * 50.0, floor_y - 110 + i * 26, 840, 30), Color(0.7, 0.95, 0.6, 0.07))
	var ground: Color = theme.ground
	draw_rect(Rect2(0, floor_y, SCREEN.x, SCREEN.y - floor_y), ground)
	draw_rect(Rect2(0, floor_y, SCREEN.x, 12), ground.lightened(0.3))

	var splat := is_resolved and not won
	if splat:
		draw_colored_polygon(ellipse_points(Vector2(apple.x, floor_y + 6), Vector2(70, 14)), [Color("ff9a3c"), Color("f2c14e"), Color("8ee04a")][stage])
	# Shadow under the treat, so its landing spot reads.
	if not caught:
		var near := clampf(apple.y / BASKET_Y, 0.0, 1.0)
		draw_colored_polygon(ellipse_points(Vector2(apple.x, floor_y + 4), Vector2(40 * near, 8 * near)), Color(0, 0, 0, 0.35 * near))

	if not caught:
		_draw_treat(splat)
	_draw_basket()


func _draw_treat(broken: bool) -> void:
	match stage:
		Stages.GRAVEYARD:
			if broken:
				draw_sprite("graveyard/candy_corn", 6, 0, apple + Vector2(-20, 6), 3.0, false, Color.WHITE, 1.4)
				draw_sprite("graveyard/candy_corn", 6, 3, apple + Vector2(24, 10), 3.0, true, Color.WHITE, -0.9)
			else:
				draw_sprite("graveyard/candy_corn", 6, anim_frame(10, 6), apple, 5.0, false, Color.WHITE, spin * 0.3)
		Stages.TEMPLE:
			# Flip between the faces to fake a spin.
			var flat := absf(cos(spin * 2.0)) if not broken else 1.0
			draw_set_transform(apple + Vector2(0, 12 if broken else 0), 0.0, Vector2(4.0 * maxf(flat, 0.2), 4.0 if not broken else 2.0))
			var tex := art("temple/ed_gold_coin")
			draw_texture_rect_region(tex, Rect2(-9, -9, 18, 18), Rect2(18 * anim_frame(6, 2), 0, 18, 18))
			draw_set_transform(Vector2.ZERO)
		_:
			if broken:
				return
			draw_circle(apple, 44, Color(Stages.theme(stage).glow, 0.22))
			draw_sprite("swamp/acid_potion", 4, anim_frame(8, 4), apple, 5.0, false, Color.WHITE, spin * 0.4)


func _draw_basket() -> void:
	var s := 1.0 + 0.25 * bounce
	var squash := Vector2(s, 1.0 / s)
	var base := Vector2(basket_x, BASKET_Y + 70)
	match stage:
		Stages.GRAVEYARD:
			draw_set_transform(base, lean, squash * 5.0)
			draw_texture_rect(art("graveyard/candybasket"), Rect2(-16, -30, 32, 32), false)
			draw_set_transform(Vector2.ZERO)
			if caught:
				draw_sprite("graveyard/candy_corn", 6, 0, Vector2(basket_x, BASKET_Y - 4), 4.0, false, Color.WHITE, -0.5)
		Stages.TEMPLE:
			draw_set_transform(base, lean, squash)
			var bowl := PackedVector2Array([Vector2(-90, -80), Vector2(90, -80), Vector2(62, 0), Vector2(-62, 0)])
			draw_colored_polygon(bowl, Color("6b6355"))
			draw_rect(Rect2(-96, -86, 192, 18), Color("8c836f"))
			for i in 4:
				draw_rect(Rect2(-58 + i * 32, -56, 20, 20), Color("f2c14e"))
				draw_rect(Rect2(-53 + i * 32, -51, 10, 10), Color("2a9d8f"))
			draw_rect(Rect2(-40, 0, 80, 14), Color("4d4638"))
			draw_set_transform(Vector2.ZERO)
			if caught:
				draw_sprite("temple/ed_gold_coin", 2, 1, Vector2(basket_x, BASKET_Y - 8), 4.0)
		_:
			draw_set_transform(base, lean, squash)
			draw_colored_polygon(ellipse_points(Vector2(0, -40), Vector2(88, 52)), Color("1c1c24"))
			draw_colored_polygon(ellipse_points(Vector2(0, -78), Vector2(90, 16)), Color("33334a"))
			draw_colored_polygon(ellipse_points(Vector2(0, -76), Vector2(74, 11)), Color("8ee04a"))
			for i in 3:
				var b := Vector2(-40 + i * 40, -78 - fmod(_clock * 60.0 + i * 13.0, 26.0))
				draw_circle(b, 8.0 - i, Color("b6f24e"))
			for side in [-1.0, 1.0]:
				draw_line(Vector2(side * 50, -6), Vector2(side * 60, 12), Color("1c1c24"), 10)
			draw_set_transform(Vector2.ZERO)
