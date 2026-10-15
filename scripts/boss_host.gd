class_name BossHost
extends Node2D
## The stage's boss, hosting the stage between microgames in Wirt's place:
## Mr Hat in the graveyard, Tlaloc in the temple, the Snail Lord in the swamp.
## Stands with its feet on the node's origin, about 330 units tall, like Wirt.
##
## Takes the same moods as [Mascot], and plays them as a villain would:
##   idle     bobbing, sizing you up
##   wave     stage intro: drops in and welcomes you to its stage
##   cheer    you won: it fumes and shakes
##   oops     you lost: it gloats, bouncing with laughter
##   panic    speed up: it cackles and swells
##   scared   its fight is coming: it steps aside (the backdrop shows it huge)
##   victory  you beat it: it topples over
##   dead     game over: it laughs at you

const HEIGHT := 330.0
const BUBBLE := Color("fff8e8")
const INK := Color("1b1426")

## Which stage's boss is hosting.
var stage := 0:
	set(value):
		stage = value
		queue_redraw()
var mood := "idle":
	set(value):
		if value != mood:
			mood = value
			t = 0.0
		visible = mood != "scared"
var t := 0.0


func _process(delta: float) -> void:
	t += delta / maxf(Engine.time_scale, 0.01)
	queue_redraw()


func _draw() -> void:
	var sprite: Array = Stages.theme(stage).boss_sprite
	var tex := Microgame.art(sprite[0])
	var frames: int = sprite[1]
	var w := tex.get_width() / float(frames)
	var h := float(tex.get_height())
	var scale := HEIGHT / h
	var fps := 8.0
	var offset := Vector2.ZERO
	var squash := Vector2.ONE
	var turn := 0.0
	var tint := Color.WHITE
	var say := ""
	match mood:
		"idle":
			offset.y = -absf(sin(t * 3.0)) * 10.0
		"wave":
			# Drops in from above, lands with a squash, then says hello.
			var fall := clampf(t / 0.35, 0.0, 1.0)
			offset.y = lerpf(-700.0, 0.0, fall * fall)
			var land := clampf((t - 0.35) / 0.3, 0.0, 1.0)
			squash = Vector2(1.0 + 0.2 * sin(land * PI), 1.0 - 0.2 * sin(land * PI))
			if t > 0.5:
				say = "WELCOME!"
		"cheer":
			offset.x = sin(t * 40.0) * 10.0 * maxf(1.0 - t, 0.3)
			tint = Color.WHITE.lerp(Color("ff6b6b"), 0.5 + 0.3 * sin(t * 12.0))
			say = "GRRR!"
		"oops":
			offset.y = -absf(sin(t * 14.0)) * 40.0
			squash = Vector2(1.0 + 0.08 * sin(t * 28.0), 1.0 - 0.08 * sin(t * 28.0))
			fps = 14.0
			say = "HA HA!"
		"panic":
			var swell := 1.0 + 0.15 * clampf(t * 3.0, 0.0, 1.0) + 0.04 * sin(t * 20.0)
			squash = Vector2(swell, swell)
			fps = 16.0
			say = "FASTER!"
		"victory":
			# Topples over and lies there.
			var fall := clampf(t / 0.6, 0.0, 1.0)
			turn = lerpf(0.0, PI / 2.0, ease(fall, 2.5))
			offset.y = -sin(fall * PI) * 60.0
			tint = Color(0.75, 0.75, 0.8)
			fps = 0.0
			if t > 0.6:
				say = "NOOO..."
		"dead":
			offset.y = -absf(sin(t * 10.0)) * 30.0
			fps = 14.0
			say = "HA HA HA!"
	var frame := int(t * fps) % frames if fps > 0.0 else 0
	# Feet on the origin: the sprite sits on the floor, its centre half a height up.
	var size := Vector2(w, h) * scale * squash
	var center := offset + Vector2(0, -size.y / 2.0)
	draw_set_transform(center, turn, size / Vector2(w, h))
	draw_texture_rect_region(tex, Rect2(-w / 2, -h / 2, w, h), Rect2(w * frame, 0, w, h), tint)
	draw_set_transform(Vector2.ZERO)
	if say != "":
		_draw_bubble(say, offset + Vector2(150, -HEIGHT - 20))


## A speech bubble with its tail pointing down-left at the boss.
func _draw_bubble(text: String, at: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 44
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var box := Rect2(at - Vector2(text_size.x / 2.0 + 24, 40), Vector2(text_size.x + 48, 76))
	box.position.x = clampf(box.position.x, -340, 340 - box.size.x)
	draw_colored_polygon(PackedVector2Array([box.position + Vector2(30, box.size.y - 2), box.position + Vector2(76, box.size.y - 2), at + Vector2(-110, 70)]), BUBBLE)
	draw_rect(box, BUBBLE)
	draw_rect(box, INK, false, 4.0)
	draw_string(font, Vector2(box.position.x + 24, box.position.y + 54), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INK)
