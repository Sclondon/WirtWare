extends Node
## Main loop. A run is three stages (see Stages), each a set of microgames and
## then a boss, with the stage's boss hosting between games (Wirt hosts the title). After the third
## boss it loops back to stage one, faster.
##
## Microgames are found automatically: any `res://microgames/<name>/<name>.tscn`
## whose root script extends Microgame joins the rotation. Bosses are named in
## Stages.THEMES and live in res://bosses/.

const Hearts := preload("res://scripts/hearts.gd")
const TouchControls := preload("res://scripts/touch_controls.gd")
const Backdrop := preload("res://scripts/backdrop.gd")

const MICROGAME_DIR := "res://microgames"
const SAVE_PATH := "user://save.cfg"
const START_LIVES := 4
const GAMES_PER_STAGE := 10
const GAMES_PER_SPEEDUP := 4
const SPEEDUP_STEP := 0.15
const MAX_SPEED := 2.2
## Beating a boss is worth this many points.
const BOSS_SCORE := 5
## The fuse runs along the top, since touch buttons can cover the bottom.
const FUSE_RECT := Rect2(96, 26, 596, 24)
const MASCOT_POS := Vector2(360, 1110)

## Set this to a microgame scene to play only that one (handy while building one).
@export var debug_microgame: PackedScene
## Start the run on this stage (0-2), for testing a stage or its boss.
@export var debug_stage := 0
## Play this many microgames per stage instead (0 = normal). 1 gets to bosses fast.
@export var debug_games_per_stage := 0

var microgames: Array[PackedScene] = []
var bag: Array[int] = []
var last_pick := -1
var lives := START_LIVES
var score := 0
var best := 0
var speed := 1.0
var stage := 0
var lap := 0
var game_in_stage := 0
var playing := false
var has_played := false

var game_frame: Control
var holder: Node2D
var hud_root: Control
var touch: TouchControls
var curtain: Control
var backdrop: Backdrop
var mascot: Mascot
var host: BossHost
var stage_label: Label
var big_label: Label
var small_label: Label
var hearts: Hearts
var prompt_label: Label
var hint_label: Label
var prompt_tween: Tween
var fuse: Control
var fuse_fill: ColorRect
var fuse_label: Label
var flash: ColorRect
var shake_amount := 0.0
var frame_pos := Vector2.ZERO


func _ready() -> void:
	_load_microgames()
	_load_best()
	_build_hud()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_show_title()
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--stage="):
			debug_stage = int(arg.get_slice("=", 1))
		elif arg.begins_with("--games="):
			debug_games_per_stage = int(arg.get_slice("=", 1))
		elif arg.begins_with("--game="):
			var name := arg.get_slice("=", 1)
			debug_microgame = load("res://microgames/%s/%s.tscn" % [name, name])
	if "--mute" in args:
		Sfx.muted = true
	if Array(args).any(func(a: String) -> bool: return a.begins_with("--shots=")):
		add_child(load("res://tools/shots.gd").new())
	if "--autopilot" in args:
		add_child(load("res://tools/autopilot.gd").new())


func _process(delta: float) -> void:
	# Screen shake on the game area, decaying in real time.
	if shake_amount > 0.0:
		shake_amount = maxf(shake_amount - delta / Engine.time_scale * 60.0, 0.0)
		var offset := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amount
		game_frame.position = frame_pos + offset
	elif game_frame.position != frame_pos:
		game_frame.position = frame_pos


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
	lap = 0
	stage = clampi(debug_stage, 0, 2)
	hearts.max_count = START_LIVES
	hint_label.visible = false
	Sfx.jingle("start")

	while lives > 0:
		await _stage_intro()
		var per_stage := debug_games_per_stage if debug_games_per_stage > 0 else GAMES_PER_STAGE
		var last_won := true
		var first := true
		game_in_stage = 0
		while game_in_stage < per_stage and lives > 0:
			await _intermission(first, last_won)
			if lives <= 0:
				break
			first = false
			last_won = await _play_microgame(_pick_microgame())
			game_in_stage += 1
			if last_won:
				score += 1
			else:
				lives -= 1
		if lives <= 0:
			break
		await _intermission(false, last_won)
		if lives <= 0:
			break

		# The boss: losing costs a heart and you go again.
		var boss_scene: PackedScene = load(Stages.theme(stage).boss)
		await _boss_intro()
		var beaten := false
		while lives > 0:
			beaten = await _play_microgame(boss_scene)
			if beaten:
				break
			lives -= 1
			await _intermission(false, false)
			if lives > 0:
				await _boss_intro()
		if not beaten:
			break
		score += BOSS_SCORE
		await _stage_clear()
		stage += 1
		if stage >= Stages.THEMES.size():
			stage = 0
			lap += 1

	await _game_over()


func _difficulty() -> int:
	return clampi(1 + stage + lap * 3, 1, 3)


func _stage_intro() -> void:
	speed = minf(1.0 + lap * 0.3, MAX_SPEED)
	Engine.time_scale = speed
	_show_curtain(Stages.theme(stage).curtains[0])
	backdrop.stage = stage
	hearts.visible = true
	hearts.count = lives
	stage_label.text = ""
	small_label.text = ("LAP %d · STAGE %d" % [lap + 1, stage + 1]) if lap > 0 else "STAGE %d" % (stage + 1)
	_set_big_text(Stages.theme(stage).name, 96)
	_host("wave")
	_pop(small_label)
	_pop(big_label)
	Sfx.jingle("stage")
	await _wait(2.0)


func _intermission(first: bool, last_won: bool) -> void:
	_show_curtain(Stages.theme(stage).curtains.pick_random())
	hearts.visible = true
	stage_label.text = "%s  ·  %d/%d" % [Stages.theme(stage).name, mini(game_in_stage + 1, _per_stage()), _per_stage()]
	_set_big_text(str(score), 200)
	if first:
		small_label.text = "GET READY!"
		_host("idle")
	elif last_won:
		small_label.text = "NICE!"
		_host("cheer")
		Sfx.jingle("win", speed)
	else:
		small_label.text = "OOPS!"
		_host("oops")
		Sfx.jingle("lose", speed)
	hearts.count = lives if (first or last_won) else lives + 1
	_pop(small_label)
	_pop(big_label)

	await _wait(0.45)
	if hearts.count != lives:
		hearts.count = lives
		_shake(hearts)
		Sfx.play("hit")
	await _wait(0.55)
	if lives <= 0:
		return

	if not first and last_won and game_in_stage > 0 and game_in_stage % GAMES_PER_SPEEDUP == 0 \
			and game_in_stage < _per_stage() and speed < MAX_SPEED:
		speed = minf(speed + SPEEDUP_STEP, MAX_SPEED)
		Engine.time_scale = speed
		small_label.text = "SPEED UP!"
		_host("panic")
		_pop(small_label)
		Sfx.jingle("speed", speed)
		await _wait(1.0)


## Between games the stage's boss hosts, in Wirt's place.
func _host(mood: String) -> void:
	mascot.visible = false
	host.stage = stage
	host.mood = mood


func _per_stage() -> int:
	return debug_games_per_stage if debug_games_per_stage > 0 else GAMES_PER_STAGE


func _boss_intro() -> void:
	var theme := Stages.theme(stage)
	_show_curtain(Color("ff2e63"))
	hearts.visible = true
	hearts.count = lives
	stage_label.text = theme.name
	small_label.text = "BOSS STAGE!"
	_set_big_text(theme.boss_name, 120)
	_host("scared")
	_pop(small_label)
	Sfx.jingle("boss")
	var tween := create_tween()
	tween.tween_property(backdrop, "boss_show", 1.0, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _wait(0.9)
	_pop(big_label)
	_shake_game(14.0)
	await _wait(1.3)
	backdrop.boss_show = 0.0


func _stage_clear() -> void:
	_show_curtain(Color("ffd23f"))
	hearts.visible = true
	small_label.text = "%s BEATEN!" % Stages.theme(stage).boss_name
	_set_big_text(str(score), 200)
	_host("victory")
	_pop(small_label)
	_pop(big_label)
	Sfx.jingle("boss_win")
	await _wait(1.3)
	if lives < START_LIVES:
		lives += 1
		hearts.count = lives
		small_label.text = "+1 HEART!"
		_pop(small_label)
		Sfx.play("coin")
	await _wait(1.1)


## Plays one microgame (or boss) and returns whether the player won.
func _play_microgame(scene: PackedScene) -> bool:
	var game := scene.instantiate() as Microgame
	game.difficulty = _difficulty()
	game.stage = stage
	holder.add_child(game)
	game.shake_requested.connect(_shake_game)
	game.resolved.connect(_on_game_resolved)
	curtain.visible = false
	var hint := game.touch_hint if touch.enabled and game.touch_hint != "" else game.controls_hint
	_flash_prompt(game.prompt, hint)
	touch.set_mode(game.controls)
	fuse.visible = true
	Sfx.music(stage, speed * (0.9 if game.is_boss else 1.0))
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
	Sfx.stop_music()

	# Let the player see the outcome for a beat.
	await _wait(0.6)
	var result := game.won
	game.queue_free()
	if prompt_tween:
		prompt_tween.kill()
	prompt_label.visible = false
	hint_label.visible = false
	return result


func _on_game_resolved(won: bool) -> void:
	if won:
		Sfx.play("ding")
	else:
		Sfx.play("buzz")
		_shake_game(10.0)
		flash.color = Color(1, 0.1, 0.2, 0.35)
		create_tween().tween_property(flash, "color:a", 0.0, 0.35)


func _game_over() -> void:
	Engine.time_scale = 1.0
	Sfx.stop_music()
	if score > best:
		best = score
		_save_best()
	# Hand the score to the hosting page (the Scareathon arcade cabinet) for its leaderboard.
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.parent.postMessage({ type: 'PLAYER_DIED', score: %d }, '*')" % score, true)
	_show_curtain(Color("222831"))
	backdrop.dim = true
	hearts.visible = false
	stage_label.text = "REACHED %s" % Stages.theme(stage).name
	_set_big_text("GAME OVER", 104)
	small_label.text = "SCORE %d   BEST %d" % [score, best]
	_host("dead")
	_pop(big_label)
	Sfx.jingle("gameover")
	# Short delay so frantic mashing doesn't instantly restart.
	await _wait(1.0)
	hint_label.text = _start_hint()
	_place(hint_label, 1210)
	hint_label.visible = true
	playing = false


func _show_title() -> void:
	_show_curtain(Stages.theme(0).curtains[0])
	hearts.visible = false
	stage_label.text = ""
	_set_big_text("WIRTWARE", 120)
	small_label.text = "BEST %d" % best if best > 0 else "3 STAGES · 3 BOSSES"
	mascot.visible = true
	host.visible = false
	mascot.mood = "wave"
	hint_label.text = _start_hint()
	_place(hint_label, 1210)
	hint_label.visible = true


func _show_curtain(rays: Color) -> void:
	curtain.visible = true
	backdrop.dim = false
	backdrop.boss_show = 0.0
	backdrop.ray_color = rays
	backdrop.stage = stage


func _start_hint() -> String:
	var verb := "TAP" if touch.enabled else "PRESS SPACE"
	return "%s TO %s" % [verb, "PLAY AGAIN" if has_played else "START"]


## A shuffled bag, so every microgame comes up before any repeats.
func _pick_microgame() -> PackedScene:
	if debug_microgame:
		return debug_microgame
	if bag.is_empty():
		for i in microgames.size():
			bag.append(i)
		bag.shuffle()
		if bag.size() > 1 and bag[0] == last_pick:
			bag.reverse()
	last_pick = bag.pop_front()
	return microgames[last_pick]


# --- HUD --------------------------------------------------------------------

func _build_hud() -> void:
	# The game area is always 720x1280; _layout() places it on screens of other shapes.
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

	flash = ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1, 0, 0, 0)
	hud_root.add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	curtain = Control.new()
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(curtain)
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop = Backdrop.new()
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	curtain.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	mascot = Mascot.new()
	mascot.position = MASCOT_POS
	mascot.scale = Vector2(0.95, 0.95)
	curtain.add_child(mascot)
	host = BossHost.new()
	host.position = MASCOT_POS
	host.visible = false
	curtain.add_child(host)

	stage_label = _make_label(34, curtain, 110)
	stage_label.modulate = Color(1, 1, 1, 0.85)
	small_label = _make_label(52, curtain, 340)
	big_label = _make_label(200, curtain, 500)

	hearts = Hearts.new()
	hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	curtain.add_child(hearts)
	hearts.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hearts.offset_top = 150

	prompt_label = _make_label(100, hud_root, 520)
	prompt_label.visible = false
	hint_label = _make_label(36, hud_root, 660)
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
	fuse_label.position = Vector2(22, -4)
	fuse.add_child(fuse_label)


func _make_frame() -> Control:
	var frame := Control.new()
	frame.size = Microgame.SCREEN
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return frame


## Centers the 720x1280 game on the screen. On touch screens it sits at the top
## instead, so a tall phone's spare height goes under it, where the buttons are.
func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var window_px := Vector2(get_window().size) / DisplayServer.screen_get_scale()
	var unit := view.x / window_px.x if window_px.x > 0 else 1.0
	Microgame.units_per_pixel = unit
	var game_pos := ((view - Microgame.SCREEN) / 2).floor()
	if touch.enabled:
		game_pos.y = 0.0
	frame_pos = game_pos
	game_frame.position = game_pos
	hud_root.position = game_pos
	touch.set_layout(Rect2(Vector2.ZERO, view), unit)


func _on_touch_detected() -> void:
	_layout()
	if not playing:
		hint_label.text = _start_hint()


## A full-width label whose text is centered on [param center_y].
func _make_label(font_size: int, parent: Node, center_y: float) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", maxi(int(font_size / 5.0), 8))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	parent.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label.offset_left = 20
	label.offset_right = -20
	label.offset_top = center_y - font_size * 1.5
	label.offset_bottom = center_y + font_size * 1.5
	return label


func _place(label: Label, center_y: float) -> void:
	var font_size := label.get_theme_font_size("font_size")
	label.offset_top = center_y - font_size * 1.5
	label.offset_bottom = center_y + font_size * 1.5


func _set_big_text(text: String, font_size: int) -> void:
	big_label.text = text
	big_label.add_theme_font_size_override("font_size", font_size)


func _flash_prompt(text: String, hint: String) -> void:
	prompt_label.text = text
	hint_label.text = hint
	_place(hint_label, 660)
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


func _shake_game(strength: float) -> void:
	shake_amount = maxf(shake_amount, strength)


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
