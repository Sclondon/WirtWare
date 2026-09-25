extends Node
## Plays WirtWare by itself so the arcade attract video can be recorded:
##
##   godot --path . --write-movie attract.avi --fixed-fps 30 --quit-after 540 -- --autopilot
##
## main.gd adds this node when it sees --autopilot. It reads each microgame's
## state and presses the same input actions a player would. The pointer games
## are "played" by poking their state directly, since the movie maker has no
## real mouse.

const PLAYLIST: Array[String] = ["whack", "slice", "land", "copy", "pop", "catch", "duel", "scrub", "sort", "stop"]

var main: Node
var next_game := 0
var current: Microgame
var held := {}  # action -> true while pressed
var tap_release: Array[String] = []
var poke_timer := 0.0


func _ready() -> void:
	main = get_parent()
	_queue_next_game()
	await get_tree().create_timer(0.6).timeout
	main._run()


func _process(delta: float) -> void:
	# Release last frame's taps, and wait a frame so the next press registers as new.
	if not tap_release.is_empty():
		for action in tap_release:
			_send(action, false)
		tap_release.clear()
		return

	var game: Microgame = main.holder.get_child(0) if main.holder.get_child_count() > 0 else null
	if game != current:
		current = game
		_release_all()
		if game:
			_queue_next_game()
	if game == null or not game.is_playing():
		_release_all()
		return

	poke_timer -= delta
	match game.scene_file_path.get_file().get_basename():
		"whack":
			if game.mole_hole != "" and game.mole_time > 0.18:
				_tap(game.mole_hole)
		"copy":
			if poke_timer <= 0.0 and game.progress < game.sequence.size():
				poke_timer = 0.22
				_tap(game.sequence[game.progress])
		"sort":
			if game.spawn_delay <= 0.0 and game.item_pos.y > 260:
				_tap("left" if game.item_side == 0 else "right")
		"stop":
			if game.needle_x > game.zone.position.x + 12 and game.needle_x < game.zone.end.x - 12:
				_tap("action")
		"duel":
			if game.elapsed >= game.signal_time + 0.15:
				_tap("action")
		"land":
			_hold("action", game.velocity > game.safe_speed * 0.8 and game.ship.y > 380)
		"catch":
			var gap: float = game.apple.x - game.basket_x
			_hold("left", gap < -20)
			_hold("right", gap > 20)
		"pop":
			if poke_timer <= 0.0:
				poke_timer = 0.3
				for balloon in game.balloons:
					if not balloon.popped:
						balloon.popped = true
						break
				if game.balloons.all(func(b) -> bool: return b.popped):
					game.win()
		"slice":
			for fruit in game.fruits:
				if fruit.launched and not fruit.sliced and fruit.vel.y > -250:
					fruit.sliced = true
					fruit.slice_angle = randf_range(-0.6, 0.6)
		"scrub":
			for blob in game.blobs:
				blob.dirt = maxf(blob.dirt - delta * 1.1, 0.0)
			if game.blobs.all(func(b) -> bool: return b.dirt <= 0.0):
				game.win()


func _queue_next_game() -> void:
	var name := PLAYLIST[next_game % PLAYLIST.size()]
	next_game += 1
	main.debug_microgame = load("res://microgames/%s/%s.tscn" % [name, name])


func _tap(action: String) -> void:
	if tap_release.has(action):
		return
	_send(action, true)
	tap_release.append(action)


func _hold(action: String, pressed: bool) -> void:
	if pressed == held.has(action):
		return
	_send(action, pressed)
	if pressed:
		held[action] = true
	else:
		held.erase(action)


func _release_all() -> void:
	for action: String in held.keys():
		_send(action, false)
	held.clear()


func _send(action: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
