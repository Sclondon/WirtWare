class_name Microgame
extends Node2D
## Base class for every microgame.
##
## The main loop instantiates a microgame scene, sets [member difficulty], calls
## [method start], and runs a countdown of [member duration] seconds. Call
## [method win] or [method lose] to end early. If time runs out first, the
## result is [member win_on_timeout] (true for "survive" games like DODGE!).
##
## Speed-ups are applied through Engine.time_scale, so just use `delta` and
## everything (timers, tweens, the countdown) speeds up together.

signal resolved(won: bool)
## Asks main.gd to shake the screen. Use shake() rather than emitting this.
signal shake_requested(strength: float)

## Which on-screen touch controls this microgame needs on phones.
## POINTER games use the mouse, which touch drives directly, so they show no buttons.
enum Controls { BUTTON, LEFT_RIGHT, ARROWS, POINTER }

## The game is portrait-first: every microgame is laid out for this 9:16 canvas.
## For games that use touch buttons (BUTTON, LEFT_RIGHT, ARROWS), keep the action
## above CONTROLS_TOP; on shorter phones the buttons float over the area below it.
const SCREEN := Vector2(720, 1280)
const CONTROLS_TOP := 1060.0

## The big one-word instruction flashed at the start ("DODGE!", "CATCH!").
@export var prompt := "GO!"
## Small hint under the prompt ("ARROW KEYS", "PRESS SPACE", "CLICK").
@export var controls_hint := ""
## Hint shown instead of controls_hint on touch screens ("TAP THE BUTTON").
@export var touch_hint := ""
@export var controls := Controls.BUTTON
## Length of the microgame in seconds (before speed-up).
@export var duration := 4.0
## Result when the timer runs out without win() or lose() being called.
@export var win_on_timeout := false
## Bosses end a stage. They live in res://bosses/ (not in the normal rotation),
## run longer, and losing one costs a heart and replays it.
@export var is_boss := false

## Which stage (Stages.GRAVEYARD / TEMPLE / SWAMP) this round is played in. Set
## by the main loop before start(); use it, and Stages.theme(stage), to dress
## the game in that stage's art.
var stage := 0
## Sparks, score pops and other effects drawn over the game. See burst() and popup().
var fx: MicrogameFx

## Viewport units per screen pixel, kept up to date by main.gd. A portrait
## phone squeezes the 1280-wide game into ~400px, so touch targets use this to
## stay finger-sized. See touch_size().
static var units_per_pixel := 1.0

## 1 (easy) to 3 (hard). Set by the main loop before start().
var difficulty := 1
var active := false
var is_resolved := false
var won := false

## Pointer state: the mouse, or a finger on touch screens (touch drives the
## mouse). Call update_pointer() at the top of _process to refresh it.
var pointer := Vector2.ZERO
var pointer_down := false
## True only on the frame the button/finger went down or came up.
var pointer_pressed := false
var pointer_released := false


func start() -> void:
	active = true
	fx = MicrogameFx.new()
	fx.z_index = 50
	add_child(fx)
	_on_start()


func win() -> void:
	_resolve(true)


func lose() -> void:
	_resolve(false)


## Called by the main loop when the countdown hits zero.
func time_up() -> void:
	_resolve(win_on_timeout)
	active = false


## True while the player can still affect the outcome.
func is_playing() -> bool:
	return active and not is_resolved


func _resolve(result: bool) -> void:
	if is_resolved:
		return
	is_resolved = true
	won = result
	_on_resolved(result)
	resolved.emit(result)


func update_pointer() -> void:
	var down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	pointer = get_local_mouse_position()
	pointer_pressed = down and not pointer_down
	pointer_released = pointer_down and not down
	pointer_down = down


## Shakes the whole game screen (8 = a bump, 20 = a crash).
func shake(strength := 12.0) -> void:
	shake_requested.emit(strength)


## Throws [param count] sparks out from [param pos].
func burst(pos: Vector2, color: Color, count := 12, speed := 420.0, size := 10.0) -> void:
	if fx:
		fx.burst(pos, color, count, speed, size)


## Floats a word (or "+1") up from [param pos].
func popup(text: String, pos: Vector2, color := Color.WHITE, font_size := 56) -> void:
	if fx:
		fx.popup(text, pos, color, font_size)


## A size of at least [param units] in game space, and at least [param pixels]
## on the actual screen, so a fingertip can still hit it on a small phone.
static func touch_size(units: float, pixels: float) -> float:
	return maxf(units, pixels * units_per_pixel)


# --- Overridables -----------------------------------------------------------

## Set up the round here; difficulty is already set.
func _on_start() -> void:
	pass


## React to winning or losing (play a sound, change a sprite...).
func _on_resolved(_won: bool) -> void:
	pass


# --- Drawing helpers --------------------------------------------------------

func draw_face(center: Vector2, size: float, happy := true) -> void:
	var eye := Vector2(size * 0.35, -size * 0.15)
	var width := size * 0.08
	if happy:
		draw_circle(center + Vector2(-eye.x, eye.y), size * 0.12, Color.BLACK)
		draw_circle(center + eye, size * 0.12, Color.BLACK)
		draw_arc(center + Vector2(0, size * 0.1), size * 0.35, 0.2, PI - 0.2, 12, Color.BLACK, width)
	else:
		var d := size * 0.12
		for side in [-1.0, 1.0]:
			var e := center + Vector2(eye.x * side, eye.y)
			draw_line(e - Vector2(d, d), e + Vector2(d, d), Color.BLACK, width)
			draw_line(e + Vector2(-d, d), e + Vector2(d, -d), Color.BLACK, width)
		draw_arc(center + Vector2(0, size * 0.55), size * 0.3, PI + 0.4, TAU - 0.4, 12, Color.BLACK, width)


func draw_text_centered(text: String, center: Vector2, font_size: int, color := Color.WHITE) -> void:
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := center + Vector2(-text_size.x / 2, text_size.y / 4)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, int(font_size / 6.0), Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## Draws a block arrow pointing along [param dir].
func draw_arrow(center: Vector2, dir: Vector2, size: float, color: Color) -> void:
	var shape := [
		Vector2(0.45, 0), Vector2(0, -0.4), Vector2(0, -0.15), Vector2(-0.45, -0.15),
		Vector2(-0.45, 0.15), Vector2(0, 0.15), Vector2(0, 0.4),
	]
	var points := PackedVector2Array()
	for p: Vector2 in shape:
		points.append(center + (p * size).rotated(dir.angle()))
	draw_colored_polygon(points, color)


## Points along an ellipse (or part of one) for draw_colored_polygon / draw_polyline.
static func ellipse_points(center: Vector2, radii: Vector2, from := 0.0, to := TAU, segments := 32) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments + 1:
		var angle := lerpf(from, to, float(i) / segments)
		points.append(center + Vector2(cos(angle), sin(angle)) * radii)
	return points


## Loads arcade art from res://art, e.g. art("graveyard/ghost"). Cached.
static func art(path: String) -> Texture2D:
	if not _art_cache.has(path):
		_art_cache[path] = load("res://art/%s.png" % path)
	return _art_cache[path]

static var _art_cache := {}


## Draws frame [param frame] of a horizontal sprite strip with [param frames]
## frames, centred on [param center], [param scale] times its pixel size.
## The art is pixel art and the project filters textures with nearest.
func draw_sprite(path: String, frames: int, frame: int, center: Vector2, scale: float,
		flip := false, tint := Color.WHITE, rotation := 0.0) -> void:
	var tex := art(path)
	var w := tex.get_width() / float(frames)
	var h := float(tex.get_height())
	var src := Rect2(w * posmod(frame, frames), 0, w, h)
	draw_set_transform(center, rotation, Vector2(-scale if flip else scale, scale))
	draw_texture_rect_region(tex, Rect2(-w / 2, -h / 2, w, h), src, tint)
	draw_set_transform(Vector2.ZERO)


## The frame to show for an animation running at [param fps], from the
## microgame's own clock (so speed-ups speed it up too).
func anim_frame(fps: float, frames: int, offset := 0.0) -> int:
	return int((_clock + offset) * fps) % frames

var _clock := 0.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_INTERNAL_PROCESS:
		_clock += get_process_delta_time()


func _enter_tree() -> void:
	set_process_internal(true)


static func circle_hits_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	var closest := Vector2(clampf(center.x, rect.position.x, rect.end.x), clampf(center.y, rect.position.y, rect.end.y))
	return center.distance_squared_to(closest) < radius * radius
