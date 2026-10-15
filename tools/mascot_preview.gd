extends Node2D
## Shows Wirt in every mood side by side, for checking his animations:
##   godot --path . res://tools/mascot_preview.tscn -- --shots=<folder> --every=0.25

const MOODS := ["idle", "wave", "cheer", "oops", "panic", "scared", "victory", "dead"]


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("3b2f4f"))
	for i in MOODS.size():
		var mascot := Mascot.new()
		mascot.mood = MOODS[i]
		mascot.scale = Vector2(0.42, 0.42)
		mascot.position = Vector2(95 + (i % 4) * 175, 560 + (i / 4) * 600)
		add_child(mascot)
		var label := Label.new()
		label.text = MOODS[i]
		label.position = mascot.position + Vector2(-50, 20)
		label.add_theme_font_size_override("font_size", 30)
		add_child(label)
	if Array(OS.get_cmdline_user_args()).any(func(a: String) -> bool: return a.begins_with("--shots=")):
		add_child(load("res://tools/shots.gd").new())
