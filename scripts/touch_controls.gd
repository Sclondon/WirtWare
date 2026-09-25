extends Control
## On-screen buttons for phones and tablets.
##
## Each microgame says which controls it needs (Microgame.Controls) and only
## those buttons appear, along the bottom edge of the screen. On tall phones
## that's the spare space under the game; on shorter ones they float over the
## bottom of the game, which microgames keep clear (Microgame.CONTROLS_TOP).
##
## They send the same input actions as the keyboard, as InputEventActions, so
## games that poll Input and games that read _unhandled_input both work
## unchanged. POINTER games show no buttons: touch already drives the mouse.

signal touch_detected

const DIRECTIONS := {"left": Vector2.LEFT, "up": Vector2.UP, "down": Vector2.DOWN, "right": Vector2.RIGHT}
const NO_CONTROLS := -1
const FILL_COLOR := Color(0, 0, 0, 0.4)
const HELD_COLOR := Color(1, 1, 1, 0.45)
const RING_COLOR := Color(1, 1, 1, 0.85)

## True once we know this is a touch screen; nothing shows until then.
var enabled := false
var mode := NO_CONTROLS
var area := Rect2()
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


## [param screen] is the whole visible area; buttons hug its bottom edge.
func set_layout(screen: Rect2, units_per_pixel: float) -> void:
	area = screen
	unit = units_per_pixel
	_build_buttons()


func _build_buttons() -> void:
	buttons.clear()
	var k := unit
	var center_x := area.get_center().x
	match mode:
		Microgame.Controls.BUTTON:
			_add("action", Vector2(center_x, area.end.y - 100 * k), 62 * k, Vector2.ZERO)
		Microgame.Controls.LEFT_RIGHT:
			var y := area.end.y - 90 * k
			_add("left", Vector2(area.position.x + 85 * k, y), 54 * k, Vector2.LEFT)
			_add("right", Vector2(area.end.x - 85 * k, y), 54 * k, Vector2.RIGHT)
		Microgame.Controls.ARROWS:
			# A row fits a narrow phone better than a d-pad.
			var spacing := minf(area.size.x / 4.0, 110 * k)
			var i := 0
			for action: String in DIRECTIONS:
				_add(action, Vector2(center_x + (i - 1.5) * spacing, area.end.y - 85 * k), minf(40 * k, spacing * 0.42), DIRECTIONS[action])
				i += 1
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
		if p.distance_to(b.center) < b.radius * 1.25:
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
	var pressed_actions := held.values()
	for b in buttons:
		var center: Vector2 = b.center
		var r: float = b.radius
		draw_circle(center, r, HELD_COLOR if pressed_actions.has(b.action) else FILL_COLOR)
		draw_arc(center, r, 0, TAU, 48, RING_COLOR, 3 * unit)
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
