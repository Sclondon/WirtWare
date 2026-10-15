class_name Mascot
extends Node2D
## Wirt, the host. A scrawny kid in a huge floppy cone hat and a too-big cape,
## drawn in code so every pose can be animated. Stands with his feet on the
## node's origin, about 330 units tall.
##
## Set [member mood] and he acts it out:
##   idle     bobbing, blinking, looking around
##   wave     title screen: waves hello
##   cheer    jumps with arms up (after a win)
##   oops     flinches, then slumps with a sweat drop (after a loss)
##   panic    runs on the spot, sweating (speed up)
##   scared   knees knocking, hat over his eyes (a boss is coming)
##   victory  spins and hops with a fist pump (boss beaten / stage clear)
##   dead     flat on his back with spiral eyes (game over)

const SKIN := Color("ffd9b3")
const HAT := Color("ff7a1a")
const HAT_DARK := Color("c4520a")
const HAT_BAND := Color("4b2a7a")
const CAPE := Color("b8202f")
const CAPE_IN := Color("6e0f1a")
const SHIRT := Color("2d6cdf")
const PANTS := Color("7a5236")
const SHOE := Color("f2f2f2")
const INK := Color("1b1426")

var mood := "idle":
	set(value):
		if value != mood:
			mood = value
			t = 0.0
var t := 0.0
var blink := 0.0
var look := 0.0


func _process(delta: float) -> void:
	t += delta
	blink -= delta
	if blink < -0.12:
		blink = randf_range(1.5, 3.5)
	if mood == "idle":
		look = sin(t * 0.9) * 0.6
	else:
		look = lerpf(look, 0.0, delta * 6.0)
	queue_redraw()


func _draw() -> void:
	# Pose values: everything below reads these.
	var lift := 0.0          # whole body up from the floor
	var squash := 1.0        # <1 = squashed flat, >1 = stretched tall
	var lean := 0.0          # radians, whole body
	var arm_l := 0.4         # radians from hanging straight down, outward
	var arm_r := 0.4
	var leg_l := 0.0
	var leg_r := 0.0
	var hat_tilt := 0.0
	var hat_droop := 0.3     # how far the hat tip flops over (0..1)
	var eyes := "open"       # open, closed, happy, worried, spiral, hidden
	var mouth := "smile"     # smile, grin, open, wobble, o, flat
	var sweat := false
	var shake := 0.0
	var spin := 1.0          # horizontal scale, for turning round

	match mood:
		"idle":
			lift = absf(sin(t * 3.0)) * 6.0
			squash = 1.0 + sin(t * 6.0) * 0.02
			arm_l = 0.35 + sin(t * 3.0) * 0.1
			arm_r = 0.35 - sin(t * 3.0) * 0.1
			hat_droop = 0.3 + sin(t * 3.0 + 1.0) * 0.08
		"wave":
			lift = absf(sin(t * 3.0)) * 5.0
			arm_r = 2.6 + sin(t * 10.0) * 0.45
			arm_l = 0.3
			hat_tilt = sin(t * 5.0) * 0.08
			mouth = "grin"
		"cheer":
			var hop := absf(sin(t * 7.0))
			lift = hop * 70.0
			squash = 0.88 + hop * 0.2 if hop > 0.15 else 0.8
			arm_l = 2.7 + sin(t * 14.0) * 0.2
			arm_r = 2.7 - sin(t * 14.0) * 0.2
			leg_l = -0.3 * hop
			leg_r = 0.3 * hop
			hat_droop = 0.1 + (1.0 - hop) * 0.5
			eyes = "happy"
			mouth = "open"
		"oops":
			if t < 0.25:
				squash = 1.0 + (0.25 - t) * 0.8
				lean = -0.15
				eyes = "closed"
				mouth = "o"
				arm_l = 1.4
				arm_r = 1.4
			else:
				squash = 0.94
				lean = 0.05 * sin(t * 2.0)
				arm_l = 0.1
				arm_r = 0.1
				hat_droop = 0.9
				eyes = "worried"
				mouth = "wobble"
				sweat = true
		"panic":
			lift = absf(sin(t * 16.0)) * 14.0
			lean = 0.18
			leg_l = sin(t * 16.0) * 0.8
			leg_r = -sin(t * 16.0) * 0.8
			arm_l = 1.2 + sin(t * 16.0) * 0.6
			arm_r = 1.2 - sin(t * 16.0) * 0.6
			hat_droop = 0.6 + sin(t * 16.0) * 0.2
			eyes = "worried"
			mouth = "open"
			sweat = true
		"scared":
			shake = 4.0
			squash = 0.9
			arm_l = 1.9
			arm_r = 1.9
			leg_l = 0.12 + sin(t * 30.0) * 0.08
			leg_r = -0.12 - sin(t * 30.0) * 0.08
			hat_droop = 1.0
			eyes = "hidden" if fmod(t, 1.6) < 1.1 else "worried"
			mouth = "wobble"
			sweat = true
		"victory":
			var cycle := fmod(t, 1.2)
			lift = sin(minf(cycle / 0.6, 1.0) * PI) * 110.0
			spin = cos(minf(cycle / 0.6, 1.0) * TAU)
			arm_r = 2.9
			arm_l = 0.9 + sin(t * 12.0) * 0.3
			leg_l = -0.4 if lift > 10 else 0.0
			eyes = "happy"
			mouth = "grin"
			hat_droop = 0.0 if lift > 10 else 0.5
		"dead":
			var fall := minf(t / 0.35, 1.0)
			lean = -PI / 2 * ease(fall, 0.4)
			lift = 0.0
			arm_l = 1.6
			arm_r = 1.2
			leg_l = 0.4
			leg_r = -0.2
			eyes = "spiral"
			mouth = "flat"
			hat_droop = 0.0
			hat_tilt = -0.8 * fall

	var origin := Vector2(randf_range(-shake, shake), -lift)
	var body := Transform2D(lean, Vector2(spin, squash), 0.0, origin)
	draw_set_transform_matrix(body)

	# Cape, behind everything.
	var cape := PackedVector2Array([
		Vector2(-46, -205), Vector2(46, -205),
		Vector2(78 + sin(t * 4.0) * 8.0, -70), Vector2(-78 + sin(t * 4.0 + 1.0) * 8.0, -66),
	])
	draw_colored_polygon(cape, CAPE_IN)

	# Legs and shoes.
	for side in [-1.0, 1.0]:
		var hip := Vector2(side * 20.0, -95)
		var angle: float = leg_l if side < 0 else leg_r
		var foot := hip + Vector2(0, 85).rotated(angle)
		draw_line(hip, foot, INK, 28.0)
		draw_line(hip, foot, PANTS, 20.0)
		draw_colored_polygon(_ellipse(foot + Vector2(side * 10.0, 4), Vector2(26, 13)), SHOE)
		draw_polyline(_ellipse(foot + Vector2(side * 10.0, 4), Vector2(26, 13)), INK, 3.0)

	# Body: shirt, then the front of the cape.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-38, -200), Vector2(38, -200), Vector2(44, -92), Vector2(-44, -92),
	]), SHIRT)
	draw_rect(Rect2(-44, -104, 88, 14), INK)
	for side in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(side * 30, -206), Vector2(side * 52, -200),
			Vector2(side * (70 + sin(t * 4.0 + side) * 6.0), -80), Vector2(side * 42, -86),
		]), CAPE)

	# Arms (hands are little mitts).
	for side in [-1.0, 1.0]:
		var shoulder := Vector2(side * 44.0, -190)
		var angle: float = arm_l if side < 0 else arm_r
		var elbow := shoulder + Vector2(0, 52).rotated(-side * angle)
		var hand := elbow + Vector2(0, 46).rotated(-side * angle * 1.1)
		draw_line(shoulder, elbow, SHIRT, 18.0)
		draw_line(elbow, hand, SKIN, 14.0)
		draw_circle(hand, 13.0, SKIN)
		draw_arc(hand, 13.0, 0, TAU, 16, INK, 3.0)

	# Head.
	var head := Vector2(look * 6.0, -262)
	draw_circle(head, 64, SKIN)
	draw_arc(head, 64, 0, TAU, 40, INK, 4.0)
	draw_circle(head + Vector2(-38, 24), 11, Color(1, 0.5, 0.5, 0.45))
	draw_circle(head + Vector2(38, 24), 11, Color(1, 0.5, 0.5, 0.45))
	_draw_eyes(head, eyes)
	_draw_mouth(head + Vector2(look * 4.0, 32), mouth)

	# The hat: a tall cone whose tip flops over.
	draw_set_transform_matrix(body * Transform2D(hat_tilt, head + Vector2(0, -40)))
	var tip_dir := Vector2(0, -1).rotated(hat_droop * 1.9 + sin(t * 2.5) * 0.06)
	var mid := Vector2(0, -110)
	var tip := mid + tip_dir * 90.0
	draw_colored_polygon(PackedVector2Array([Vector2(-82, 6), Vector2(82, 6), mid + Vector2(16, 0), mid + Vector2(-16, 0)]), HAT)
	draw_colored_polygon(PackedVector2Array([mid + Vector2(-16, 0), mid + Vector2(16, 0), tip]), HAT)
	draw_colored_polygon(PackedVector2Array([mid + Vector2(16, 0), Vector2(60, 6), Vector2(20, 6)]), HAT_DARK)
	draw_polyline(PackedVector2Array([Vector2(-82, 6), mid + Vector2(-16, 0), tip, mid + Vector2(16, 0), Vector2(82, 6)]), INK, 4.0)
	draw_rect(Rect2(-74, -22, 148, 20), HAT_BAND)
	draw_colored_polygon(_ellipse(Vector2(0, 6), Vector2(104, 18)), HAT_DARK)
	draw_polyline(_ellipse(Vector2(0, 6), Vector2(104, 18)), INK, 4.0)
	draw_circle(tip, 11, Color("ffe066"))
	if eyes == "hidden":
		draw_colored_polygon(_ellipse(Vector2(0, 30), Vector2(96, 30), 0, PI), HAT_DARK)

	draw_set_transform_matrix(body)
	if sweat:
		var drop := head + Vector2(70, -30 + fmod(t * 60.0, 50.0))
		draw_colored_polygon(PackedVector2Array([drop + Vector2(0, -16), drop + Vector2(9, 2), drop + Vector2(-9, 2)]), Color("8fd3ff"))
		draw_circle(drop + Vector2(0, 4), 9, Color("8fd3ff"))
	draw_set_transform(Vector2.ZERO)


func _draw_eyes(head: Vector2, eyes: String) -> void:
	for side in [-1.0, 1.0]:
		var e := head + Vector2(side * 24.0 + look * 8.0, -6)
		match eyes:
			"open", "worried":
				if blink > 0.0 or eyes == "worried":
					draw_colored_polygon(_ellipse(e, Vector2(15, 19)), Color.WHITE)
					draw_polyline(_ellipse(e, Vector2(15, 19)), INK, 3.0)
					draw_circle(e + Vector2(look * 6.0, 3), 8, INK)
					draw_circle(e + Vector2(look * 6.0 - 3, 0), 3, Color.WHITE)
				else:
					draw_line(e + Vector2(-13, 2), e + Vector2(13, 2), INK, 4.0)
				if eyes == "worried":
					draw_line(e + Vector2(-14, -26 - side * 6.0), e + Vector2(14, -26 + side * 6.0), INK, 4.0)
			"closed":
				draw_line(e + Vector2(-14, -4), e + Vector2(0, 4), INK, 5.0)
				draw_line(e + Vector2(0, 4), e + Vector2(14, -4), INK, 5.0)
			"happy":
				draw_arc(e + Vector2(0, 6), 13, PI + 0.3, TAU - 0.3, 12, INK, 5.0)
			"spiral":
				var points := PackedVector2Array()
				for i in 24:
					points.append(e + Vector2.from_angle(i * 0.6 + t * 6.0) * (2.0 + i * 0.6))
				draw_polyline(points, INK, 3.0)


func _draw_mouth(m: Vector2, mouth: String) -> void:
	match mouth:
		"smile":
			draw_arc(m, 16, 0.3, PI - 0.3, 12, INK, 4.0)
		"grin":
			draw_colored_polygon(_ellipse(m, Vector2(22, 14), 0, PI), INK)
			draw_rect(Rect2(m.x - 14, m.y, 28, 5), Color.WHITE)
		"open":
			draw_colored_polygon(_ellipse(m + Vector2(0, 4), Vector2(15, 17)), INK)
			draw_colored_polygon(_ellipse(m + Vector2(0, 13), Vector2(9, 6)), Color("ff6b81"))
		"o":
			draw_circle(m + Vector2(0, 4), 9, INK)
		"wobble":
			var points := PackedVector2Array()
			for i in 9:
				points.append(m + Vector2(-20 + i * 5, 6 + sin(i * 1.6 + t * 12.0) * 3.0))
			draw_polyline(points, INK, 4.0)
		"flat":
			draw_line(m + Vector2(-14, 6), m + Vector2(14, 6), INK, 4.0)


static func _ellipse(center: Vector2, radii: Vector2, from := 0.0, to := TAU) -> PackedVector2Array:
	return Microgame.ellipse_points(center, radii, from, to, 24)
