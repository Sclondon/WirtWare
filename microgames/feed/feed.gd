extends Microgame
## FEED! Drag each snack up into the monster's mouth.
## Graveyard: a jack-o'-lantern eats candy. Temple: a stone idol eats offerings.
## Swamp: a sludge toad eats goo and bugs.

const MONSTER_RADIUS := 150.0
const MOUTH_RADIUS := 72.0
const FOOD_RADIUS := 44.0
const MONSTER_HOME := Vector2(360, 330)
const SPAWN_AWAY := Vector2(-1000, -1000)
## Per stage: [sprite, frames, scale] for each snack.
const FOODS: Array[Array] = [
	[["graveyard/candy_corn", 6, 5.0], ["graveyard/candy_bar", 5, 5.0], ["graveyard/lollipop", 4, 8.0]],
	[["temple/ed_gold_coin", 2, 6.0], ["temple/t_offering", 2, 8.0], ["temple/t_rail_gem", 4, 7.0]],
	[["swamp/goo_glob", 2, 12.0], ["swamp/orb_purple", 2, 12.0], ["swamp/h_crow", 8, 6.0]],
]

var monster := MONSTER_HOME
var food := Vector2.ZERO
var food_kind := 0
var holding := false
var total := 2
var eaten := 0
var chomp := 0.0
var elapsed := 0.0
var end_time := 0.0


func _init() -> void:
	prompt = "FEED!"
	controls_hint = "DRAG FOOD TO THE MOUTH"
	touch_hint = "DRAG FOOD TO THE MOUTH"
	controls = Controls.POINTER
	duration = 4.5


func _on_start() -> void:
	total = 1 + difficulty
	_spawn_food()


func _spawn_food() -> void:
	food_kind = randi() % 3
	food = Vector2(randf_range(110, SCREEN.x - 110), randf_range(780, 1130))
	holding = false
	burst(food, Color(1, 1, 1, 0.8), 6, 200.0, 6.0)


func _mouth() -> Vector2:
	return monster + Vector2(0, 45)


func _process(delta: float) -> void:
	update_pointer()
	elapsed += delta
	chomp = maxf(chomp - delta * 4.0, 0.0)
	if is_resolved:
		end_time += delta
	if difficulty == 3 and not is_resolved:
		monster.x = MONSTER_HOME.x + sin(elapsed * 2.5) * 170

	if is_playing():
		if pointer_pressed and pointer.distance_to(food) < touch_size(FOOD_RADIUS * 1.4, 40):
			holding = true
			Sfx.play("tap")
		elif not pointer_down:
			holding = false
		if holding:
			food = pointer
		if food.distance_to(_mouth()) < MOUTH_RADIUS:
			eaten += 1
			chomp = 1.0
			Sfx.play("munch")
			Sfx.play("crunch", 0.5)
			burst(_mouth(), _crumb_color(), 14, 380.0, 9.0)
			popup("YUM!" if eaten < total else "BURP!", monster + Vector2(0, 230), Stages.theme(stage).glow, 56)
			shake(4.0)
			if eaten == total:
				food = SPAWN_AWAY
				win()
			else:
				_spawn_food()
	queue_redraw()


func _crumb_color() -> Color:
	return [Color("ffb347"), Color("f2c14e"), Color("b6f24e")][stage]


func _draw() -> void:
	var theme := Stages.theme(stage)
	for i in 12:
		draw_rect(Rect2(0, 700 * i / 12.0, SCREEN.x, 700 / 12.0 + 1), (theme.sky as Color).lerp(theme.sky_low, i / 11.0))
	var ground: Color = theme.ground
	draw_rect(Rect2(0, 700, SCREEN.x, SCREEN.y - 700), ground)
	draw_rect(Rect2(0, 700, SCREEN.x, 12), ground.lightened(0.3))
	draw_text_centered("%d / %d" % [eaten, total], Vector2(360, 620), 56)

	var lost := is_resolved and not won
	var open := 1.0 - chomp
	if lost:
		open = 0.25
	# Squash on each bite; a happy bounce once full.
	var hop := absf(sin(end_time * 10.0)) * 30.0 if is_resolved and won else 0.0
	var at := monster + Vector2(0, -hop)
	var squash := Vector2(1.0 + 0.12 * chomp, 1.0 - 0.1 * chomp)
	draw_set_transform(at, 0.0, squash)
	var origin := Vector2.ZERO
	match stage:
		Stages.GRAVEYARD:
			_draw_pumpkin(origin, open, lost)
		Stages.TEMPLE:
			_draw_idol(origin, open, lost)
		_:
			_draw_toad(origin, open, lost)
	draw_set_transform(Vector2.ZERO)
	if lost:
		draw_text_centered("STILL HUNGRY...", Vector2(360, 110), 50, theme.glow)

	if food == SPAWN_AWAY:
		return
	var info: Array = FOODS[stage][food_kind]
	var lift := 1.15 if holding else 1.0
	draw_colored_polygon(ellipse_points(food + Vector2(0, FOOD_RADIUS + (14 if holding else 4)), Vector2(36, 9)), Color(0, 0, 0, 0.3))
	draw_sprite(info[0], info[1], anim_frame(8, info[1]), food, float(info[2]) * lift)
	if holding:
		draw_arc(food, FOOD_RADIUS + 14, 0, TAU, 32, Color(1, 1, 1, 0.8), 4)
	elif not is_resolved:
		# A pulsing ring says "grab me".
		var pulse := fmod(_clock * 1.5, 1.0)
		draw_arc(food, FOOD_RADIUS + 10 + pulse * 30.0, 0, TAU, 32, Color(1, 1, 1, 0.6 * (1.0 - pulse)), 4)


## Pupils that follow the food.
func _draw_eyes(center: Vector2, spread: float, size: float, white: Color, pupil: Color) -> void:
	for side in [-1.0, 1.0]:
		var eye := center + Vector2(side * spread, 0)
		draw_circle(eye, size, white)
		var look := (food - (monster + eye)).limit_length(size * 0.4) if food != SPAWN_AWAY else Vector2.ZERO
		draw_circle(eye + look, size * 0.45, pupil)


func _draw_mouth(center: Vector2, open: float, inside: Color, teeth: Color) -> void:
	draw_colored_polygon(ellipse_points(center, Vector2(85, maxf(55.0 * open, 6.0))), inside)
	if open > 0.3:
		for i in 4:
			var tooth := center + Vector2(-54 + i * 36, -55.0 * open + 4)
			draw_colored_polygon(PackedVector2Array([tooth + Vector2(-12, 0), tooth + Vector2(12, 0), tooth + Vector2(0, 18)]), teeth)


func _draw_pumpkin(o: Vector2, open: float, lost: bool) -> void:
	var orange := Color("e8711a") if not lost else Color("a85a24")
	draw_rect(Rect2(o + Vector2(-14, -MONSTER_RADIUS - 40), Vector2(28, 50)), Color("4f7a28"))
	for k in [-1.0, 1.0]:
		draw_colored_polygon(ellipse_points(o + Vector2(k * 70, 0), Vector2(100, MONSTER_RADIUS - 6)), orange.darkened(0.15))
	draw_colored_polygon(ellipse_points(o, Vector2(110, MONSTER_RADIUS)), orange)
	# Carved triangle eyes with candle light inside, and a jagged grin.
	var glow := Color("ffe066")
	for side in [-1.0, 1.0]:
		var e := o + Vector2(side * 58, -52)
		var look := (food - (monster + e)).limit_length(8) if food != SPAWN_AWAY else Vector2.ZERO
		draw_colored_polygon(PackedVector2Array([e + Vector2(-30, 20), e + Vector2(30, 20), e + Vector2(0, -28)]), Color("3a1c08"))
		draw_circle(e + Vector2(0, 6) + look, 10, glow)
	_draw_mouth(o + Vector2(0, 45), open, Color("3a1c08"), orange)
	if open > 0.3:
		draw_circle(o + Vector2(0, 50), 18 * open, Color(glow, 0.6))


func _draw_idol(o: Vector2, open: float, lost: bool) -> void:
	var stone := Color("7d8a6e") if not lost else Color("5e5a52")
	for side in [-1.0, 1.0]:
		draw_circle(o + Vector2(side * 150, -10), 38, Color("f2c14e"))
		draw_circle(o + Vector2(side * 150, -10), 18, Color("2a9d8f"))
	draw_rect(Rect2(o + Vector2(-140, -150), Vector2(280, 290)), stone)
	draw_rect(Rect2(o + Vector2(-150, -170), Vector2(300, 40)), Color("f2c14e"))
	for i in 5:
		draw_rect(Rect2(o + Vector2(-130 + i * 56, -164), Vector2(28, 28)), Color("2a9d8f"))
	draw_rect(Rect2(o + Vector2(-110, -88), Vector2(220, 14)), stone.darkened(0.25))
	_draw_eyes(o + Vector2(0, -50), 58, 30, Color("e9f5db") if not lost else Color("e76f51"), Color("1d3b2f"))
	_draw_mouth(o + Vector2(0, 45), open, Color("1d1a14"), Color("e9f5db"))


func _draw_toad(o: Vector2, open: float, lost: bool) -> void:
	draw_circle(o + Vector2(0, 20), 175, Color(Stages.theme(stage).glow, 0.12))
	var tint := Color(0.8, 0.8, 0.8) if lost else Color.WHITE
	# (Not draw_sprite: that would reset the squash transform we're drawing in.)
	var src := Rect2(24 * anim_frame(6, 4), 0, 24, 24)
	draw_texture_rect_region(art("swamp/sludge_toad"), Rect2(o + Vector2(-144, -164), Vector2(288, 288)), src, tint)
	# Its mouth sits on the line across its face.
	draw_colored_polygon(ellipse_points(o + Vector2(0, 45), Vector2(95, maxf(50.0 * open, 6.0))), Color("1a2a12"))
	if open > 0.3:
		draw_colored_polygon(ellipse_points(o + Vector2(0, 45 + 30 * open), Vector2(50, 18 * open)), Color("e05a7a"))
