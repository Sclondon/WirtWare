extends Control
## On-screen buttons for phones and tablets.
##
## Each microgame says which controls it needs (Microgame.Controls) and only
## those buttons appear. They send the same input actions as the keyboard, as
## InputEventActions, so games that poll Input and games that read
## _unhandled_input both work unchanged. POINTER games show no buttons: touch
## already drives the mouse.
##
## On tall screens the buttons sit in a controller area under the game. On wide
## screens they float over the bottom corners.

signal touch_detected

const DIRECTIONS := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}
const NO_CONTROLS := -1
const PAD_COLOR := Color("241734")
const BUTTON_COLOR := Color(1, 1, 1, 0.22)
const HELD_COLOR := Color(1, 1, 1, 0.55)
const RING_COLOR := Color(1, 1, 1, 0.75)

## True once we know this is a touch screen; nothing shows until then.
var enabled := false
var mode := NO_CONTROLS
var portrait := false
var pad_area := Rect2()
## Viewport units per CSS pixel, so buttons stay thumb-sized on any screen.
var unit := 1.0
var buttons: Array[Dictionary] = []
var held := {}  # touch index -> action


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	enabled = DisplayServer.is_touchscreen_available()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_release_all()


## [param new_mode] is a Microgame.Controls value, or NO_CONTROLS between games.
func set_mode(new_mode: int) -> void:
	_release_all()
	mode = new_mode
	_build_buttons()


func set_layout(area: Rect2, is_portrait: bool, units_per_pixel: float) -> void:
	pad_area = area
	portrait = is_portrait
	unit = units_per_pixel
	_build_buttons()


func _build_buttons() -> void:
	buttons.clear()
	var k := unit * (1.2 if portrait else 1.0)
	match mode:
		Microgame.Controls.BUTTON:
			var center := pad_area.get_center() if portrait else pad_area.end - Vector2(115, 115) * k
			_add("action", center, 75.0 * k, Vector2.ZERO)
		Microgame.Controls.LEFT_RIGHT:
			var r := 58.0 * k
			if portrait:
				var y := pad_area.get_center().y
				_add("left", Vector2(pad_area.position.x + pad_area.size.x * 0.28, y), r, Vector2.LEFT)
				_add("right", Vector2(pad_area.position.x + pad_area.size.x * 0.72, y), r, Vector2.RIGHT)
			else:
				_add("left", Vector2(pad_area.position.x + 95 * k, pad_area.end.y - 95 * k), r, Vector2.LEFT)
				_add("right", pad_area.end - Vector2(95, 95) * k, r, Vector2.RIGHT)
		Microgame.Controls.ARROWS:
			var r := 42.0 * k
			var center := pad_area.get_center() if portrait else Vector2(pad_area.position.x + 150 * k, pad_area.end.y - 150 * k)
			for action: String in DIRECTIONS:
				_add(action, center + DIRECTIONS[action] * r * 2.1, r, DIRECTIONS[action])
	queue_redraw()


func _add(action: String, center: Vector2, radius: float, dir: Vector2) -> void:
	buttons.append({"action": action, "center": center, "radius": radius, "dir": dir})


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not enabled:
		enabled = true
		touch_detected.emit()
		queue_redraw()
	if buttons.is_empty():
		return
	if event is InputEventScreenTouch:
		var p := (make_input_local(event) as InputEventScreenTouch).position
		if event.pressed:
			var action := _button_at(p)
			if action != "":
				held[event.index] = action
				_send(action, true)
				get_viewport().set_input_as_handled()
		elif held.has(event.index):
			_send(held[event.index], false)
			held.erase(event.index)
		queue_redraw()
	elif event is InputEventScreenDrag and held.has(event.index):
		# Let a thumb slide from one arrow to the next without lifting.
		var action := _button_at((make_input_local(event) as InputEventScreenDrag).position)
		if action != "" and action != held[event.index]:
			_send(held[event.index], false)
			held[event.index] = action
			_send(action, true)
			queue_redraw()


func _button_at(p: Vector2) -> String:
	for b in buttons:
		if p.distance_to(b.center) < b.radius * 1.2:
			return b.action
	return ""


func _send(action: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)


func _release_all() -> void:
	for index: int in held:
		_send(held[index], false)
	held.clear()


func _draw() -> void:
	if not enabled:
		return
	var font := ThemeDB.fallback_font
	if portrait:
		draw_rect(pad_area, PAD_COLOR)
		if buttons.is_empty():
			var text := "TOUCH THE GAME ABOVE" if mode == Microgame.Controls.POINTER else "WIRTWARE"
			var font_size := int(30 * unit)
			var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			draw_string(font, pad_area.get_center() + Vector2(-width / 2, font_size / 3.0), text,
					HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.35))

	var pressed_actions := held.values()
	for b in buttons:
		var center: Vector2 = b.center
		var r: float = b.radius
		draw_circle(center, r, HELD_COLOR if pressed_actions.has(b.action) else BUTTON_COLOR)
		draw_arc(center, r, 0, TAU, 48, RING_COLOR, 4 * unit)
		var dir: Vector2 = b.dir
		if dir != Vector2.ZERO:
			draw_colored_polygon(PackedVector2Array([
				center + dir * r * 0.5,
				center + dir.rotated(2.3) * r * 0.45,
				center + dir.rotated(-2.3) * r * 0.45,
			]), Color.WHITE)
		else:
			var font_size := int(r * 0.9)
			var width := font.get_string_size("A", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			draw_string(font, center + Vector2(-width / 2, font_size * 0.35), "A",
					HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
