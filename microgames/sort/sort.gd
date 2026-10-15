extends Microgame
## SORT! Toss each falling item into its bin with left or right. The items
## suit the stage: candy corn and candy bars in the graveyard, gold and jade
## balls in the temple, frogs and crows in the swamp. The bins show which is which.

const BIN_X: Array[float] = [130.0, 590.0]
const BIN_TOP := 860.0
const BIN_BOTTOM := 1010.0
const START_Y := 170.0
const FLOOR_Y := 780.0
const ITEM_SIZE := 48.0
## Per stage: [left item, right item], each [path, frames, scale].
const ITEMS := [
	[["graveyard/candy_corn", 6, 5.5], ["graveyard/candy_bar", 5, 5.5]],
	[["temple/golden_Ball", 16, 7.0], ["temple/emerald_Ball", 16, 7.0]],
	[["swamp/h_frog", 1, 7.5], ["swamp/h_crow", 8, 7.5]],
]
## Per stage: the two bin colours.
const BIN_COLORS := [
	[Color("e8781e"), Color("4b6cc1")],
	[Color("b8862b"), Color("2a8f6a")],
	[Color("3f7a34"), Color("4a4466")],
]

class Tossed:
	var pos: Vector2
	var vel: Vector2
	var side: int
	var spin: float
	var right_bin: bool

var remaining := 3
var item_side := 0
var item_pos := Vector2.ZERO
var item_speed := 500.0
var spawn_delay := 0.6
var tossed: Array[Tossed] = []
var bin_pop: Array[float] = [0.0, 0.0]
var elapsed := 0.0


func _init() -> void:
	prompt = "SORT!"
	controls_hint = "LEFT / RIGHT"
	touch_hint = "LEFT / RIGHT"
	controls = Controls.LEFT_RIGHT
	duration = 5.0


func _on_start() -> void:
	remaining = 2 + difficulty
	# Each item needs a real-time reaction, so don't let the speed-up squeeze it too hard.
	item_speed = (480.0 + 100.0 * difficulty) / pow(Engine.time_scale, 0.3)
	_next_item()


func _next_item() -> void:
	item_side = randi() % 2
	item_pos = Vector2(SCREEN.x / 2, START_Y)


func _process(delta: float) -> void:
	elapsed += delta
	if is_playing():
		spawn_delay -= delta
		if spawn_delay <= 0.0:
			item_pos.y += item_speed * delta
			var dir := 0
			if Input.is_action_just_pressed("left"):
				dir = -1
			elif Input.is_action_just_pressed("right"):
				dir = 1
			if dir != 0:
				_toss(dir)
			elif item_pos.y > FLOOR_Y:
				item_pos.y = FLOOR_Y
				Sfx.play("thud")
				burst(item_pos + Vector2(0, ITEM_SIZE), Color("ef476f"), 10, 300.0, 9.0)
				lose()

	for i in 2:
		bin_pop[i] = move_toward(bin_pop[i], 0.0, delta * 4.0)
	for t in tossed:
		t.vel.y += 1800.0 * delta
		t.pos += t.vel * delta
	for i in range(tossed.size() - 1, -1, -1):
		var t := tossed[i]
		if t.pos.y > BIN_TOP + 20 and t.vel.y > 0.0:
			_land(t)
			tossed.remove_at(i)
	queue_redraw()


func _toss(dir: int) -> void:
	var t := Tossed.new()
	t.pos = item_pos
	t.side = item_side
	t.spin = dir * 9.0
	t.right_bin = (dir < 0) == (item_side == 0)
	var target_x := BIN_X[0 if dir < 0 else 1]
	var flight_time := 0.45
	t.vel = Vector2((target_x - item_pos.x) / flight_time, (BIN_TOP - item_pos.y) / flight_time - 900.0 * flight_time)
	tossed.append(t)
	Sfx.play("swish", 0.7)
	if not t.right_bin:
		item_pos = Vector2(-1000, -1000)
		lose()
		return
	remaining -= 1
	if remaining == 0:
		item_pos = Vector2(-1000, -1000)
		win()
	else:
		_next_item()


## An item drops into a bin.
func _land(t: Tossed) -> void:
	var bin := 0 if t.pos.x < SCREEN.x / 2 else 1
	bin_pop[bin] = 1.0
	var top := Vector2(BIN_X[bin], BIN_TOP)
	if t.right_bin:
		Sfx.play(["munch", "coin", "squish"][posmod(stage, 3)], 0.8)
		burst(top, Stages.theme(stage).glow, 12, 380.0, 9.0)
		popup("+1", top + Vector2(0, -60), Stages.theme(stage).glow, 48)
	else:
		Sfx.play("thud")
		burst(top, Color("ef476f"), 12, 380.0, 9.0)
		popup("WRONG!", top + Vector2(0, -60), Color("ef476f"), 56)


func _draw_item(pos: Vector2, side: int, spin: float, tint := Color.WHITE) -> void:
	var item: Array = ITEMS[posmod(stage, 3)][side]
	var frames: int = item[1]
	# Crows face the way they're going; frogs and candy just bob.
	draw_sprite(item[0], frames, anim_frame(10, frames), pos, item[2], false, tint, spin)


func _draw() -> void:
	var theme := Stages.theme(stage)
	_draw_scenery(theme)
	var glow: Color = theme.glow
	# A soft light down the drop chute keeps every item easy to read.
	draw_rect(Rect2(SCREEN.x / 2 - 90, 100, 180, FLOOR_Y + ITEM_SIZE - 100), Color(glow, 0.12))

	var lost := is_resolved and not won
	for t in tossed:
		_draw_item(t.pos, t.side, elapsed * t.spin, Color(1, 0.55, 0.55) if not t.right_bin else Color.WHITE)
	if spawn_delay <= 0.0 and item_pos.x > 0.0:
		_draw_item(item_pos, item_side, 0.0, Color(1, 0.55, 0.55) if lost else Color.WHITE)

	var colors: Array = BIN_COLORS[posmod(stage, 3)]
	for side in 2:
		var x := BIN_X[side]
		var grow := 1.0 + 0.12 * bin_pop[side]
		var w := 100.0 * grow
		var bottom := BIN_BOTTOM
		var top := BIN_TOP - 10.0 * bin_pop[side]
		var color: Color = colors[side]
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - w - 8, top - 8), Vector2(x + w + 8, top - 8), Vector2(x + w * 0.8 + 8, bottom + 8), Vector2(x - w * 0.8 - 8, bottom + 8),
		]), Color.BLACK)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - w, top), Vector2(x + w, top), Vector2(x + w * 0.8, bottom), Vector2(x - w * 0.8, bottom),
		]), color)
		draw_rect(Rect2(x - w, top, w * 2, 16), color.lightened(0.3))
		var icon := Vector2(x, (top + bottom) / 2 + 6)
		draw_circle(icon, 46, Color(0, 0, 0, 0.3))
		var item: Array = ITEMS[posmod(stage, 3)][side]
		draw_sprite(item[0], item[1], 0, icon, (item[2] as float) * 0.6)
		draw_arrow(Vector2(x, BIN_TOP - 70), Vector2.LEFT if side == 0 else Vector2.RIGHT, 70, Color(1, 1, 1, 0.8))


## The stage's sky, ground and a few props.
func _draw_scenery(theme: Dictionary) -> void:
	var top: Color = theme.sky
	var low: Color = theme.sky_low
	var floor_y := FLOOR_Y + ITEM_SIZE
	for i in 12:
		draw_rect(Rect2(0, floor_y * i / 12.0, SCREEN.x, floor_y / 12.0 + 1), top.lerp(low, i / 11.0))
	var ground: Color = theme.ground
	draw_rect(Rect2(0, floor_y, SCREEN.x, SCREEN.y - floor_y), ground)
	draw_rect(Rect2(0, floor_y, SCREEN.x, 10), ground.lightened(0.25))
	match stage:
		Stages.GRAVEYARD:
			draw_circle(Vector2(600, 180), 60, Color("fff2c4"))
			draw_circle(Vector2(578, 165), 60, top)
		Stages.TEMPLE:
			for row in 8:
				for col in 6:
					var x := col * 140.0 + (70.0 if row % 2 else 0.0) - 70.0
					draw_rect(Rect2(x, floor_y - (8 - row) * 72, 136, 68), Color("4d5a4f").lerp(Color("3a463e"), row / 8.0))
			for x in [80.0, 640.0]:
				draw_sprite("temple/t_torch", 12, anim_frame(10, 4, x), Vector2(x, 330), 6.0)
		Stages.SWAMP:
			draw_circle(Vector2(140, 200), 64, Color(0.85, 1.0, 0.6, 0.3))
			draw_sprite("swamp/tree_5", 1, 0, Vector2(690, 420), 3.0, false, Color(0.3, 0.42, 0.32))
			draw_sprite("swamp/tree_5", 1, 0, Vector2(30, 520), 3.0, true, Color(0.3, 0.42, 0.32))
