extends Microgame
## GLIDE! Steer the white glider through the gaps between clouds and airships.
## A homage to Daughter Of The Wind.

const GLIDER_Y := 860.0
const GLIDER_R := 22.0
const STEER := 660.0
const ROW_H := 80.0
const FIRST_ROW_TIME := 1.35

## Each row: {"y", "gap" (centre x), "width", "ship_left", "ship_right", "ring" (bool: still there)}.
var rows: Array[Dictionary] = []
var glider := Vector2(360, GLIDER_Y)
var tilt := 0.0
var scroll_speed := 380.0
var scrolled := 0.0
var crashed := false
var spin := 0.0
var fall := Vector2.ZERO
var puffs := PackedVector3Array()
var theme := {}


func _init() -> void:
	prompt = "GLIDE!"
	controls_hint = "ARROW KEYS"
	touch_hint = "LEFT / RIGHT"
	controls = Controls.LEFT_RIGHT
	duration = 4.5
	win_on_timeout = true


func _on_start() -> void:
	theme = Stages.theme(stage)
	scroll_speed = [360.0, 430.0, 500.0][difficulty - 1]
	var interval: float = [1.2, 1.0, 0.85][difficulty - 1]
	var width: float = [300.0, 250.0, 215.0][difficulty - 1]
	var gap := 360.0 + randf_range(170, 240) * (1.0 if randf() < 0.5 else -1.0)
	var t := FIRST_ROW_TIME
	while t < duration + 0.4:
		var half := width / 2 + 20
		gap = clampf(gap, half, SCREEN.x - half)
		rows.append({
			"y": GLIDER_Y - scroll_speed * t,
			"gap": gap,
			"width": width,
			"ship_left": difficulty >= 2 and randf() < 0.4,
			"ship_right": difficulty >= 2 and randf() < 0.4,
			"ring": true,
		})
		# The next gap is a fair swerve away: far enough to need steering, never too far to reach.
		var reach := STEER * interval * 0.6
		var shift := randf_range(minf(150.0, reach), reach) * (1.0 if randf() < 0.5 else -1.0)
		if gap + shift < half or gap + shift > SCREEN.x - half:
			shift = -shift
		gap += shift
		t += interval
	for i in 16:
		puffs.append(Vector3(randf() * SCREEN.x, randf() * SCREEN.y, randf_range(30, 70)))


func _process(delta: float) -> void:
	if crashed:
		spin += 14.0 * delta
		fall.y += 1400.0 * delta
		glider += fall * delta
	else:
		var steer := Input.get_axis("left", "right") if is_playing() else 0.0
		glider.x = clampf(glider.x + steer * STEER * delta, 30, SCREEN.x - 30)
		tilt = lerpf(tilt, steer * 0.45, minf(delta * 12.0, 1.0))
		if is_resolved and won:
			glider.y -= 700.0 * delta
		scrolled += scroll_speed * delta
		for row in rows:
			row.y += scroll_speed * delta
		if is_playing():
			_check_rows()
	queue_redraw()


func _check_rows() -> void:
	for row in rows:
		var y: float = row.y
		if absf(y - glider.y) > ROW_H / 2 + GLIDER_R:
			continue
		var gap: float = row.gap
		var half: float = row.width / 2
		var left := Rect2(-100, y - ROW_H / 2, gap - half + 100, ROW_H)
		var right := Rect2(gap + half, y - ROW_H / 2, SCREEN.x - gap - half + 100, ROW_H)
		if circle_hits_rect(glider, GLIDER_R, left) or circle_hits_rect(glider, GLIDER_R, right):
			_crash()
			return
		if row.ring and absf(y - glider.y) < 12:
			row.ring = false
			Sfx.play("whoosh", 0.6, 1.4)
			burst(Vector2(gap, y), theme.glow, 12, 320, 8)
			popup("WIND!", Vector2(gap, y - 60), theme.glow, 40)


func _crash() -> void:
	crashed = true
	fall = Vector2(randf_range(-120, 120), -200)
	Sfx.play("thud")
	Sfx.play("whoosh", 0.8, 0.6)
	burst(glider, Color.WHITE, 18, 420, 14)
	shake(14)
	lose()


func _on_resolved(result: bool) -> void:
	if result:
		Sfx.play("whoosh", 0.8, 1.2)
		burst(glider + Vector2(0, 30), theme.glow, 14, 300, 8)


func _draw() -> void:
	var sky: Color = theme.sky
	var low: Color = theme.sky_low
	for i in 8:
		draw_rect(Rect2(0, i * 160.0, SCREEN.x, 161), sky.lerp(low, i / 7.0))
	# Far-off haze puffs drift slowly for depth.
	var haze := Color(1, 1, 1, 0.07)
	for p in puffs:
		var y := fposmod(p.y + scrolled * 0.35, SCREEN.y + 200) - 100
		draw_circle(Vector2(p.x, y), p.z, haze)
		draw_circle(Vector2(p.x + p.z * 0.8, y + 10), p.z * 0.7, haze)

	var cloud := Color.WHITE.lerp(theme.glow, 0.2)
	for row in rows:
		var y: float = row.y
		if y < -150 or y > SCREEN.y + 150:
			continue
		var gap: float = row.gap
		var half: float = row.width / 2
		if row.ring:
			draw_arc(Vector2(gap, y), 46, 0, TAU, 32, Color(theme.accent, 0.9), 7)
			draw_arc(Vector2(gap, y), 46, 0, TAU, 32, Color(1, 1, 1, 0.5), 2)
		_draw_wall(-40, gap - half, y, row.ship_left, cloud, false)
		_draw_wall(gap + half, SCREEN.x + 40, y, row.ship_right, cloud, true)

	_draw_glider()
	if crashed:
		draw_text_centered("SPUN OUT!", Vector2(360, 140), 64, Color("ef476f"))
	elif is_resolved and won:
		draw_text_centered("SOARING!", Vector2(360, 140), 64, theme.glow)


## A cloud bank or airship hull filling x [param from]..[param to] at height [param y].
## [param inner_left] is true when the gap is at its left end (the right-hand wall).
func _draw_wall(from: float, to: float, y: float, ship: bool, cloud: Color, inner_left: bool) -> void:
	if to - from < 10:
		return
	if ship:
		var hull := Color("8d6e63").lerp(theme.ground, 0.4)
		var mid := Vector2((from + to) / 2, y)
		var r := Vector2((to - from) / 2 + 6, ROW_H / 2 + 4)
		draw_rect(Rect2(mid.x - 50, y + r.y - 8, 100, 24), hull.darkened(0.35))
		draw_colored_polygon(ellipse_points(mid, r), hull)
		draw_colored_polygon(ellipse_points(mid + Vector2(0, -8), r * Vector2(0.94, 0.5)), hull.lightened(0.2))
		draw_rect(Rect2(mid.x - r.x * 0.85, y + 4, r.x * 1.7, 9), theme.accent)
		# Portholes toward the gap end, so the hull reads even when mostly off screen.
		var nose := from + 50 if inner_left else to - 50
		for i in 3:
			draw_circle(Vector2(nose + (i * 44.0 if inner_left else -i * 44.0), y + 24), 7, Color("ffe8a3"))
		return
	# Fluffy cloud: overlapping puffs packed out from the gap end, with a shade underneath.
	var shade := cloud.darkened(0.18)
	var dir := 1.0 if inner_left else -1.0
	var edge := from if inner_left else to
	for layer in 2:
		var x := edge
		var i := 0
		while x >= from - 60 and x <= to + 60:
			var r := 42.0 + ((i + layer) % 3) * 9.0
			var cx := x + dir * (r - 6)
			if layer == 0:
				draw_circle(Vector2(cx, y + 14), r, shade)
			else:
				draw_circle(Vector2(cx, y - 4), r, cloud)
			x += dir * 50.0
			i += 1


func _draw_glider() -> void:
	var angle := spin if crashed else tilt
	draw_set_transform(glider, angle, Vector2(1.3, 1.3))
	var white := Color("f8f9fa")
	# Wide wings, a slim body, a small tail, and the rider's scarf.
	draw_colored_polygon(PackedVector2Array([Vector2(-50, 14), Vector2(0, -16), Vector2(50, 14), Vector2(0, 4)]), white)
	draw_colored_polygon(PackedVector2Array([Vector2(-50, 14), Vector2(0, 4), Vector2(50, 14), Vector2(0, 10)]), Color("ced4da"))
	draw_colored_polygon(PackedVector2Array([Vector2(-8, -26), Vector2(8, -26), Vector2(6, 30), Vector2(-6, 30)]), white)
	draw_colored_polygon(PackedVector2Array([Vector2(-18, 30), Vector2(18, 30), Vector2(0, 22)]), Color("ced4da"))
	draw_circle(Vector2(0, -2), 8, Color("6c584c"))
	draw_line(Vector2(0, 2), Vector2(-6 + sin(scrolled * 0.05) * 6, 30), theme.accent, 4)
	draw_set_transform(Vector2.ZERO)
