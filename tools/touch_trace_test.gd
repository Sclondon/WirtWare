extends SceneTree
## Plays TRACE! with simulated touches, the way a phone sends them, and checks
## it can be won. Needs a real window (headless Godot scales touches out of place):
##
##   godot --path . --script tools/touch_trace_test.gd           (a normal finger)
##   godot --path . --script tools/touch_trace_test.gd -- drag   (drags only, no finger-down,
##                                                               as an iPhone sometimes sends)
##
## Ends with PASSED or FAILED.

var drag_only := "drag" in OS.get_cmdline_user_args()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.debug_microgame = load("res://microgames/trace/trace.tscn")
	root.add_child(main)
	await create_timer(0.3).timeout
	main._run()
	var game: Microgame = null
	for i in 600:
		await process_frame
		game = _find_trace(main)
		if game and game.is_playing():
			break
	if not (game and game.is_playing()):
		_finish(false, "trace never started")
		return
	await create_timer(0.3).timeout
	var path: PackedVector2Array = game.path
	# Events come in window pixels; the game is drawn scaled into the window.
	var to_screen := root.get_final_transform() * game.get_global_transform_with_canvas()
	if not drag_only:
		var down := InputEventScreenTouch.new()
		down.index = 0
		down.pressed = true
		down.position = to_screen * path[0]
		Input.parse_input_event(down)
	for i in path.size():
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = to_screen * path[i]
		drag.relative = Vector2.ZERO if i == 0 else to_screen.basis_xform(path[i] - path[i - 1])
		Input.parse_input_event(drag)
		await process_frame
		await process_frame
		if game.is_resolved:
			break
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = to_screen * path[path.size() - 1]
	Input.parse_input_event(up)
	await process_frame
	_finish(game.is_resolved and game.won, "progress %d/%d, strayed %s" % [game.progress, path.size() - 1, game.strayed])


func _find_trace(node: Node) -> Microgame:
	for child in node.get_children():
		if child is Microgame and child.prompt == "TRACE!":
			return child
		var found := _find_trace(child)
		if found:
			return found
	return null


func _finish(ok: bool, detail: String) -> void:
	print("%s (%s%s)" % ["PASSED" if ok else "FAILED", "drags only, " if drag_only else "", detail])
	quit(0 if ok else 1)
