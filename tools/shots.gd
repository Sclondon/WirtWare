extends Node
## Saves a screenshot every --every=<seconds> (real time) into --shots=<folder>,
## for checking how things look without playing. Needs a window (not --headless).
##
##   godot --path . -- --autopilot --shots=C:/tmp/shots --every=0.5 --mute

var folder := ""
var every := 0.5
var timer := 0.0
var count := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			folder = arg.get_slice("=", 1)
		elif arg.begins_with("--every="):
			every = float(arg.get_slice("=", 1))
	DirAccess.make_dir_recursive_absolute(folder)


func _process(delta: float) -> void:
	timer += delta / maxf(Engine.time_scale, 0.01)
	if timer < every:
		return
	timer = 0.0
	var image := get_viewport().get_texture().get_image()
	image.save_png(folder.path_join("shot_%03d.png" % count))
	count += 1
