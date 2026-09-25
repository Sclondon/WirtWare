extends Node
## Main loop: intermission -> microgame -> result, speeding up as you go.
##
## Microgames are found automatically: any `res://microgames/<name>/<name>.tscn`
## whose root script extends Microgame joins the rotation.

const Hearts := preload("res://scripts/hearts.gd")
const TouchControls := preload("res://scripts/touch_controls.gd")

const MICROGAME_DIR := "res://microgames"
const SAVE_PATH := "user://save.cfg"
const START_LIVES := 4
const GAMES_PER_SPEEDUP := 4
const SPEEDUP_STEP := 0.15
const MAX_SPEED := 2.2
const GAMES_PER_DIFFICULTY := 8
const FUSE_RECT := Rect2(100, 686, 1160, 22)
## On screens this much taller than 16:9 (in viewport units), the touch buttons
## get their own area under the game instead of floating over it.
const MIN_PAD_HEIGHT := 400.0
const PAD_HEIGHT_PX := 330.0
const CURTAIN_COLORS: Array[Color] = [
	Color("ff5a5f"), Color("ffb400"), Color("00a699"),
	Color("7b5cff"), Color("fc642d"), Color("3ec1d3"),
]

## Set this to a microgame scene to play only that one (handy while building one).
@export var debug_microgame: PackedScene

var microgames: Array[PackedScene] = []
var last_pick := -1
var lives := START_LIVES
var score := 0
var best := 0
var speed := 1.0
var playing := false
var has_played := false

var game_frame: Control
var holder: Node2D
var hud_root: Control
var touch: TouchControls
var curtain: ColorRect
var big_label: Label
var small_label: Label
var hearts: Hearts
var prompt_label: Label
var hint_label: Label
var prompt_tween: Tween
var fuse: Control
var fuse_fill: ColorRect
var fuse_label: Label


func _ready() -> void:
	_load_microgames()
	_load_best()
	_build_hud()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_show_title()
	if "--autopilot" in OS.get_cmdline_user_args():
		add_child(load("res://tools/autopilot.gd").new())


func _unhandled_input(event: InputEvent) -> void:
	if not playing and (event.is_action_pressed("action") or _is_tap(event)):
		get_viewport().set_input_as_handled()
		_run()


func _is_tap(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return event.pressed
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	return false


# --- Game loop --------------------------------------------------------------

func _run() -> void:
	playing = true
	has_played = true
	lives = START_LIVES
	score = 0
	speed = 1.0
	Engine.time_scale = speed
	hearts.max_count = START_LIVES
	hint_label.visible = false

	var first := true
	var last_won := true
	while true:
		await _intermission(first, last_won)
		if lives <= 0:
			break
		first = false
		last_won = await _play_microgame()
		if last_won:
			score += 1
		else:
			lives -= 1

	await _game_over()


func _intermission(first: bool, last_won: bool) -> void:
	curtain.color = CURTAIN_COLORS.pick_random()
	curtain.visible = true
	hearts.visible = true
	_set_big_text(str(score), 200)
	if first:
		small_label.text = "GET READY!"
	elif last_won:
		small_label.text = "NICE!"
	else:
		small_label.text = "OOPS!"
	hearts.count = lives if (first or last_won) else lives + 1
	_pop(small_label)
	_pop(big_label)

	await _wait(0.45)
	if hearts.count != lives:
		hearts.count = lives
		_shake(hearts)
	await _wait(0.55)
	if lives <= 0:
		return

	if not first and last_won and score % GAMES_PER_SPEEDUP == 0 and speed < MAX_SPEED:
		speed = minf(speed + SPEEDUP_STEP, MAX_SPEED)
		Engine.time_scale = speed
		small_label.text = "SPEED UP!"
		_pop(small_label)
		await _wait(1.0)


## Plays one microgame and returns whether the player won.
func _play_microgame() -> bool:
	var game := _pick_microgame().instantiate() as Microgame
	game.difficulty = clampi(1 + floori(float(score) / GAMES_PER_DIFFICULTY), 1, 3)
	holder.add_child(game)
	curtain.visible = false
	var hint := game.touch_hint if touch.enabled and game.touch_hint != "" else game.controls_hint
	_flash_prompt(game.prompt, hint)
	touch.set_mode(game.controls)
	fuse.visible = true
	game.start()

	var time_left := game.duration
	while time_left > 0.0 and not game.is_resolved:
		_update_fuse(time_left, game.duration)
		await get_tree().process_frame
		time_left -= get_process_delta_time()
	if not game.is_resolved:
		game.time_up()
	fuse.visible = false
	touch.set_mode(TouchControls.NO_CONTROLS)

	# Let the player see the outcome for a beat.
	await _wait(0.6)
	var result := game.won
	game.queue_free()
	if prompt_tween:
		prompt_tween.kill()
	prompt_label.visible = false
	hint_label.visible = false
	return result


func _game_over() -> void:
	Engine.time_scale = 1.0
	if score > best:
		best = score
		_save_best()
	# Hand the score to the hosting page (the Scareathon arcade cabinet) for its leaderboard.
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.parent.postMessage({ type: 'PLAYER_DIED', score: %d }, '*')" % score, true)
	curtain.visible = true
	curtain.color = Color("222831")
	hearts.visible = false
	_set_big_text("GAME OVER", 150)
	small_label.text = "SCORE %d   BEST %d" % [score, best]
	_pop(big_label)
	# Short delay so frantic mashing doesn't instantly restart.
	await _wait(1.0)
	hint_label.text = _start_hint()
	hint_label.visible = true
	playing = false


func _show_title() -> void:
	curtain.visible = true
	curtain.color = CURTAIN_COLORS[0]
	hearts.visible = false
	_set_big_text("WIRTWARE", 180)
	small_label.text = "BEST %d" % best if best > 0 else ""
	hint_label.text = _start_hint()
	hint_label.visible = true


func _start_hint() -> String:
	var verb := "TAP" if touch.enabled else "PRESS SPACE"
	return "%s TO %s" % [verb, "PLAY AGAIN" if has_played else "START"]


func _pick_microgame() -> PackedScene:
	if debug_microgame:
		return debug_microgame
	var i := randi() % microgames.size()
	while microgames.size() > 1 and i == last_pick:
		i = randi() % microgames.size()
	last_pick = i
	return microgames[i]


# --- HUD --------------------------------------------------------------------

func _build_hud() -> void:
	# The game area is always 1280x720; _layout() places it on screens of other shapes.
	game_frame = _make_frame()
	game_frame.name = "GameFrame"
	add_child(game_frame)
	holder = Node2D.new()
	holder.name = "MicrogameHolder"
	game_frame.add_child(holder)

	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.layer = 10
	add_child(hud)
	hud_root = _make_frame()
	hud.add_child(hud_root)

	var touch_layer := CanvasLayer.new()
	touch_layer.name = "TouchControls"
	touch_layer.layer = 20
	add_child(touch_layer)
	touch = TouchControls.new()
	touch_layer.add_child(touch)
	touch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	touch.touch_detected.connect(_on_touch_detected)

	curtain = ColorRect.new()
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(curtain)
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	small_label = _make_label(64, curtain)
	small_label.offset_bottom = -460
	big_label = _make_label(200, curtain)
	big_label.offset_bottom = -60

	hearts = Hearts.new()
	hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	curtain.add_child(hearts)
	hearts.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hearts.offset_top = 470

	prompt_label = _make_label(130, hud_root)
	prompt_label.offset_bottom = -140
	prompt_label.visible = false
	hint_label = _make_label(40, hud_root)
	hint_label.offset_top = 260
	hint_label.visible = false

	fuse = Control.new()
	fuse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fuse.visible = false
	hud_root.add_child(fuse)
	var fuse_back := ColorRect.new()
	fuse_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fuse_back.color = Color(0, 0, 0, 0.6)
	fuse_back.position = FUSE_RECT.position
	fuse_back.size = FUSE_RECT.size
	fuse.add_child(fuse_back)
	fuse_fill = ColorRect.new()
	fuse_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fuse_fill.position = FUSE_RECT.position + Vector2(4, 4)
	fuse_fill.size = FUSE_RECT.size - Vector2(8, 8)
	fuse.add_child(fuse_fill)
	fuse_label = Label.new()
	fuse_label.add_theme_font_size_override("font_size", 56)
	fuse_label.add_theme_constant_override("outline_size", 14)
	fuse_label.add_theme_color_override("font_outline_color", Color.BLACK)
	fuse_label.position = Vector2(30, 640)
	fuse.add_child(fuse_label)


func _make_frame() -> Control:
	var frame := Control.new()
	frame.size = Microgame.SCREEN
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return frame


## Centers the game on wide screens; on tall ones, stacks the game above a
## touch controller area.
func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var window_px := Vector2(get_window().size) / DisplayServer.screen_get_scale()
	var unit := view.x / window_px.x if window_px.x > 0 else 1.0
	Microgame.units_per_pixel = unit
	var extra_height := view.y - Microgame.SCREEN.y
	var portrait := touch.enabled and extra_height >= MIN_PAD_HEIGHT
	var game_pos: Vector2
	var pad: Rect2
	if portrait:
		var pad_height := minf(extra_height, PAD_HEIGHT_PX * unit)
		var top := floorf((extra_height - pad_height) / 2)
		game_pos = Vector2(0, top)
		pad = Rect2(0, top + Microgame.SCREEN.y, view.x, pad_height)
	else:
		game_pos = ((view - Microgame.SCREEN) / 2).floor()
		pad = Rect2(Vector2.ZERO, view)
	game_frame.position = game_pos
	hud_root.position = game_pos
	touch.set_layout(pad, portrait, unit)


func _on_touch_detected() -> void:
	_layout()
	if not playing:
		hint_label.text = _start_hint()


func _make_label(font_size: int, parent: Node) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", maxi(int(font_size / 5.0), 8))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	parent.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return label


func _set_big_text(text: String, font_size: int) -> void:
	big_label.text = text
	big_label.add_theme_font_size_override("font_size", font_size)


func _flash_prompt(text: String, hint: String) -> void:
	prompt_label.text = text
	hint_label.text = hint
	prompt_label.visible = true
	hint_label.visible = hint != ""
	prompt_label.modulate.a = 1.0
	hint_label.modulate.a = 1.0
	prompt_label.pivot_offset = prompt_label.size / 2
	prompt_label.scale = Vector2(2.5, 2.5)
	if prompt_tween:
		prompt_tween.kill()
	prompt_tween = create_tween()
	prompt_tween.tween_property(prompt_label, "scale", Vector2.ONE, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	prompt_tween.tween_interval(0.55)
	prompt_tween.tween_property(prompt_label, "modulate:a", 0.0, 0.2)
	prompt_tween.parallel().tween_property(hint_label, "modulate:a", 0.0, 0.2)


func _update_fuse(time_left: float, duration: float) -> void:
	var ratio := clampf(time_left / duration, 0.0, 1.0)
	fuse_fill.size.x = (FUSE_RECT.size.x - 8) * ratio
	fuse_fill.color = Color("ff2e63").lerp(Color("ffd23f"), ratio)
	fuse_label.text = str(ceili(time_left)) if time_left <= 3.0 else ""


func _pop(control: Control) -> void:
	control.pivot_offset = control.size / 2
	control.scale = Vector2(1.4, 1.4)
	create_tween().tween_property(control, "scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _shake(control: Control) -> void:
	var tween := create_tween()
	for offset in [-24.0, 20.0, -14.0, 8.0, 0.0]:
		tween.tween_property(control, "position:x", offset, 0.04)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


# --- Setup ------------------------------------------------------------------

func _load_microgames() -> void:
	for folder in DirAccess.get_directories_at(MICROGAME_DIR):
		var path := MICROGAME_DIR.path_join(folder).path_join(folder + ".tscn")
		if ResourceLoader.exists(path):
			microgames.append(load(path))
	assert(not microgames.is_empty(), "No microgames found in " + MICROGAME_DIR)
	print("Loaded %d microgames" % microgames.size())


func _load_best() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		best = config.get_value("scores", "best", 0)


func _save_best() -> void:
	var config := ConfigFile.new()
	config.set_value("scores", "best", best)
	config.save(SAVE_PATH)
