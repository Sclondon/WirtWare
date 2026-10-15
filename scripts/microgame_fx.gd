class_name MicrogameFx
extends Node2D
## Sparks and floating words drawn over a microgame. Every microgame gets one
## in start(); use Microgame.burst() and Microgame.popup() rather than this.

const GRAVITY := 900.0

var sparks: Array[Dictionary] = []
var words: Array[Dictionary] = []


func burst(pos: Vector2, color: Color, count: int, speed: float, size: float) -> void:
	for i in count:
		var angle := randf() * TAU
		sparks.append({
			"pos": pos,
			"vel": Vector2.from_angle(angle) * speed * randf_range(0.4, 1.0) + Vector2(0, -speed * 0.3),
			"life": randf_range(0.35, 0.7),
			"age": 0.0,
			"size": size * randf_range(0.6, 1.2),
			"color": color,
		})


func popup(text: String, pos: Vector2, color: Color, font_size: int) -> void:
	words.append({"text": text, "pos": pos, "age": 0.0, "color": color, "size": font_size})


func _process(delta: float) -> void:
	if sparks.is_empty() and words.is_empty():
		return
	for s in sparks:
		s.age += delta
		s.vel.y += GRAVITY * delta
		s.pos += s.vel * delta
	sparks = sparks.filter(func(s: Dictionary) -> bool: return s.age < s.life)
	for w in words:
		w.age += delta
		w.pos.y -= 160.0 * delta * maxf(1.0 - w.age, 0.2)
	words = words.filter(func(w: Dictionary) -> bool: return w.age < 0.9)
	queue_redraw()


func _draw() -> void:
	for s in sparks:
		var k: float = 1.0 - s.age / s.life
		var c: Color = s.color
		draw_circle(s.pos, s.size * k, Color(c, k))
	var font := ThemeDB.fallback_font
	for w in words:
		var size: int = w.size
		var grow: float = minf(w.age * 8.0, 1.0)
		var fs := int(size * (0.6 + 0.4 * grow))
		var alpha: float = clampf((0.9 - w.age) * 4.0, 0.0, 1.0)
		var text_size := font.get_string_size(w.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var p: Vector2 = w.pos + Vector2(-text_size.x / 2, text_size.y / 4)
		draw_string_outline(font, p, w.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(fs / 6, 4), Color(0, 0, 0, alpha))
		draw_string(font, p, w.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(w.color, alpha))
