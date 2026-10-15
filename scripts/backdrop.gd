extends Control
## The scene behind the between-games screen: the current stage's sky, props
## from its arcade game, spinning rays behind the score, and the boss looming
## over it all when one is on its way. Drawn in the 720x1280 game space.

const FLOOR_Y := 1110.0

var stage := 0
## The burst of rays behind the score takes this colour.
var ray_color := Color("ff7a1a")
## 0 = no boss, 1 = the boss fills the sky. Tween it.
var boss_show := 0.0
## Plain dark backdrop for the game-over screen.
var dim := false
var t := 0.0


func _process(delta: float) -> void:
	t += delta
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	var theme := Stages.theme(stage)
	var size := Microgame.SCREEN
	# Sky.
	var top: Color = theme.sky
	var low: Color = theme.sky_low
	if dim:
		top = Color("16121f")
		low = Color("2a2338")
	for i in 16:
		var y0 := size.y * i / 16.0
		draw_rect(Rect2(0, y0, size.x, size.y / 16.0 + 1), top.lerp(low, i / 15.0))

	# Rays behind the score.
	if not dim:
		var c := Vector2(360, 560)
		for i in 14:
			var a := t * 0.35 + i * TAU / 14.0
			draw_colored_polygon(PackedVector2Array([
				c, c + Vector2.from_angle(a) * 900.0, c + Vector2.from_angle(a + TAU / 28.0) * 900.0,
			]), Color(ray_color, 0.22))
		draw_circle(c, 210, Color(ray_color, 0.25))

	if boss_show > 0.0:
		_draw_boss(theme)

	match int(posmod(stage, 3)):
		Stages.GRAVEYARD: _draw_graveyard()
		Stages.TEMPLE: _draw_temple()
		Stages.SWAMP: _draw_swamp()

	# Floor.
	var ground: Color = theme.ground
	draw_rect(Rect2(0, FLOOR_Y, size.x, size.y - FLOOR_Y), ground)
	draw_rect(Rect2(0, FLOOR_Y, size.x, 10), ground.lightened(0.25))


func _draw_boss(theme: Dictionary) -> void:
	var sprite: Array = theme.boss_sprite
	var tex := Microgame.art(sprite[0])
	var frames: int = sprite[1]
	var w := tex.get_width() / float(frames)
	var h := float(tex.get_height())
	var frame := int(t * 8.0) % frames
	var scale := 640.0 / maxf(w, h) * lerpf(0.6, 1.0, boss_show)
	var center := Vector2(360 + sin(t * 23.0) * 6.0 * boss_show, lerpf(-300, 520, ease(boss_show, 0.4)))
	draw_set_transform(center, 0.0, Vector2(scale, scale))
	draw_texture_rect_region(tex, Rect2(-w / 2, -h / 2, w, h), Rect2(w * frame, 0, w, h), Color(1, 1, 1, boss_show))
	draw_set_transform(Vector2.ZERO)


func _sprite(path: String, frames: int, frame: int, center: Vector2, scale: float, tint := Color.WHITE, flip := false) -> void:
	var tex := Microgame.art(path)
	var w := tex.get_width() / float(frames)
	var h := float(tex.get_height())
	draw_set_transform(center, 0.0, Vector2(-scale if flip else scale, scale))
	draw_texture_rect_region(tex, Rect2(-w / 2, -h / 2, w, h), Rect2(w * posmod(frame, frames), 0, w, h), tint)
	draw_set_transform(Vector2.ZERO)


func _draw_graveyard() -> void:
	draw_circle(Vector2(560, 170), 80, Color("fff2c4"))
	draw_circle(Vector2(530, 150), 80, Stages.theme(0).sky)
	var bat := int(t * 10.0)
	_sprite("graveyard/bat", 4, bat, Vector2(fmod(t * 90.0, 900.0) - 90, 240 + sin(t * 3.0) * 30.0), 3.0)
	_sprite("swamp/tree_owl", 5, int(t * 4.0), Vector2(110, FLOOR_Y - 150), 2.6, Color(0.8, 0.75, 0.9))
	_sprite("graveyard/mausoleum", 1, 0, Vector2(610, FLOOR_Y - 170), 2.9, Color(0.75, 0.7, 0.85))
	_sprite("graveyard/grave_2", 1, 0, Vector2(250, FLOOR_Y - 40), 3.0)
	_sprite("graveyard/grave_1_small", 1, 0, Vector2(470, FLOOR_Y - 40), 3.0)
	_sprite("graveyard/pumpkin", 6, int(t * 6.0), Vector2(60, FLOOR_Y - 22), 3.0)
	_sprite("graveyard/prop_pumpkin_pile", 1, 0, Vector2(670, FLOOR_Y - 34), 3.0)


func _draw_temple() -> void:
	# Stone blocks.
	for row in 6:
		for col in 5:
			var x := col * 160.0 + (80.0 if row % 2 else 0.0) - 40.0
			draw_rect(Rect2(x, 700 + row * 70, 156, 66), Color("4d5a4f").lerp(Color("2f3a33"), row / 6.0))
	_sprite("temple/t_totem_heads", 3, 0, Vector2(90, 660), 4.0)
	_sprite("temple/t_totem_heads", 3, 2, Vector2(630, 660), 4.0)
	for x in [60.0, 660.0]:
		_sprite("temple/t_torch", 12, int(t * 10.0 + x) % 4, Vector2(x, FLOOR_Y - 120), 5.0)
	_sprite("temple/t_kickback_frog", 3, int(t * 3.0), Vector2(220, FLOOR_Y - 22), 4.0)
	_sprite("temple/t_wall_jaguar", 3, 0, Vector2(520, FLOOR_Y - 46), 4.0)
	for i in 30:
		var p := Vector2(fmod(i * 97.0 + t * 30.0, 720.0), fmod(i * 173.0 + t * 520.0, 1100.0))
		draw_line(p, p + Vector2(-3, 18), Color(0.7, 0.9, 1.0, 0.35), 2.0)


func _draw_swamp() -> void:
	draw_circle(Vector2(180, 180), 70, Color(0.85, 1.0, 0.6, 0.35))
	_sprite("graveyard/tree", 1, 0, Vector2(600, FLOOR_Y - 170), 2.8, Color(0.55, 0.75, 0.5))
	_sprite("swamp/tree_5", 1, 0, Vector2(100, FLOOR_Y - 180), 2.8, Color(0.5, 0.7, 0.5))
	for i in 3:
		var p := Vector2(150 + i * 220 + sin(t * 1.3 + i) * 40.0, 820 + cos(t * 1.7 + i * 2.0) * 50.0)
		_sprite("swamp/willOWisp", 6, int(t * 8.0) + i, p, 2.5)
	_sprite("swamp/h_frog", 1, 0, Vector2(300, FLOOR_Y - 20), 4.0)
	_sprite("swamp/toxic_barrel", 1, 0, Vector2(470, FLOOR_Y - 26), 3.5)
	for i in 5:
		var y := 1000.0 + i * 22.0
		draw_rect(Rect2(-60 + sin(t * 0.6 + i) * 60.0, y, 840, 26), Color(0.7, 0.95, 0.6, 0.08))
