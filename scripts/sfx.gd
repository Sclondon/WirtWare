extends Node
## Sound effects, jingles and stage music, all made up at startup (no audio
## files) and played as ordinary samples. Autoloaded as Sfx.
##
##   Sfx.play("pop")              # one-shot: name, volume 0-1, pitch
##   Sfx.jingle("win")            # short tune between microgames
##   Sfx.music(stage, speed)      # loop under a microgame; Sfx.stop_music()
##
## Engine.time_scale does not speed up audio, so main.gd passes the game speed
## to music() and microgames can pass it as pitch if they want.
##
## One-shots: tap pop hit boom whoosh coin jump splash zap beep buzz munch swish
## ding thud squish crunch spring
## Jingles: start stage win lose speed boss boss_win clear gameover

const RATE := 22050
const VOICES := 10
const SOUNDS := {
	"tap": 0.07, "pop": 0.14, "hit": 0.18, "boom": 0.6, "whoosh": 0.24, "coin": 0.3,
	"jump": 0.22, "splash": 0.4, "zap": 0.2, "beep": 0.1, "buzz": 0.3, "munch": 0.12,
	"swish": 0.16, "ding": 0.4, "thud": 0.18, "squish": 0.2, "crunch": 0.16, "spring": 0.35,
}
## Notes as semitones from A4 (0 = 440 Hz); "r" is a rest. Each step is [note, beats].
const JINGLES := {
	"start": [[3, 0.5], [7, 0.5], [10, 0.5], [15, 1.5]],
	"stage": [[-2, 0.5], [3, 0.5], [7, 0.5], [3, 0.5], [10, 1.0], [15, 1.5]],
	"win": [[7, 0.33], [11, 0.33], [14, 0.33], [19, 1.0]],
	"lose": [[7, 0.5], [6, 0.5], [5, 0.5], [4, 1.5]],
	"speed": [[0, 0.25], [2, 0.25], [4, 0.25], [5, 0.25], [7, 0.25], [9, 0.25], [11, 0.25], [12, 1.0]],
	"boss": [[-12, 0.75], [-11, 0.75], [-12, 0.75], [-6, 1.5], ["r", 0.25], [-13, 1.5]],
	"boss_win": [[0, 0.33], [4, 0.33], [7, 0.33], [12, 0.66], [7, 0.33], [12, 0.33], [16, 0.33], [19, 1.5]],
	"clear": [[0, 0.5], [4, 0.5], [7, 0.5], [12, 0.5], [11, 0.5], [12, 0.5], [16, 1.5]],
	"gameover": [[7, 0.6], [3, 0.6], [0, 0.6], [-5, 0.6], [-6, 2.0]],
}
## Per stage: [root semitone, bpm, wave]. Each loop is a short bass + drums groove.
const STAGE_MUSIC := [
	[-17, 132, "square"],   # graveyard: bouncy spooky
	[-19, 120, "triangle"], # temple: drums and a low flute
	[-21, 112, "saw"],      # swamp: slow and wobbly
]

var _streams := {}
var _jingles := {}
var _music := {}
var _players: Array[AudioStreamPlayer] = []
var _jingle_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _next := 0
var _last := {}
var muted := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_jingle_player = AudioStreamPlayer.new()
	add_child(_jingle_player)
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -12.0
	add_child(_music_player)
	for sound: String in SOUNDS:
		_streams[sound] = _make(sound, SOUNDS[sound])


func play(sound: String, volume := 1.0, pitch := 1.0, gap_ms := 40) -> void:
	if muted or volume <= 0.02 or not _streams.has(sound):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last.get(sound, -1000)) < gap_ms:
		return
	_last[sound] = now
	var player := _players[_next]
	_next = (_next + 1) % VOICES
	player.stream = _streams[sound]
	player.volume_db = linear_to_db(clampf(volume, 0.0, 1.0)) - 6.0
	player.pitch_scale = pitch * randf_range(0.95, 1.05)
	player.play()


func jingle(name: String, pitch := 1.0) -> void:
	if muted or not JINGLES.has(name):
		return
	if not _jingles.has(name):
		_jingles[name] = _make_tune(JINGLES[name], 150.0, "square")
	_jingle_player.stream = _jingles[name]
	_jingle_player.pitch_scale = pitch
	_jingle_player.volume_db = -4.0
	_jingle_player.play()


func music(stage: int, speed := 1.0) -> void:
	if muted:
		return
	stage = clampi(stage, 0, STAGE_MUSIC.size() - 1)
	if not _music.has(stage):
		_music[stage] = _make_groove(STAGE_MUSIC[stage])
	if _music_player.stream != _music[stage] or not _music_player.playing:
		_music_player.stream = _music[stage]
		_music_player.play()
	_music_player.pitch_scale = speed


func stop_music() -> void:
	_music_player.stop()


# --- Synthesis ---------------------------------------------------------------

func _make(sound: String, seconds: float) -> AudioStreamWAV:
	var count := int(seconds * RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	var low := 0.0
	for i in count:
		var t := float(i) / RATE
		var n := float(i) / count
		var noise := randf() * 2.0 - 1.0
		low = lerpf(low, noise, 0.12)
		var freq := 440.0
		match sound:
			"tap": freq = 520.0 - 200.0 * n
			"pop": freq = 900.0 * exp(-t * 30.0) + 140.0
			"hit": freq = 180.0 - 90.0 * n
			"boom": freq = 70.0 - 30.0 * n
			"coin": freq = 988.0 if t < 0.07 else 1319.0
			"jump": freq = 260.0 + 600.0 * n
			"zap": freq = 1400.0 * exp(-t * 14.0) + 200.0
			"beep": freq = 880.0
			"buzz": freq = 110.0
			"ding": freq = 1175.0
			"thud": freq = 95.0 - 50.0 * n
			"spring": freq = 300.0 + 200.0 * sin(t * 60.0) * (1.0 - n)
			"squish": freq = 200.0 + 300.0 * sin(PI * n)
		phase = fmod(phase + freq / RATE, 1.0)
		var sine := sin(phase * TAU)
		var square := 1.0 if phase < 0.5 else -1.0
		var out := 0.0
		match sound:
			"tap": out = sine * exp(-t * 50.0)
			"pop": out = sine * exp(-t * 45.0) * 0.7 + noise * exp(-t * 70.0) * 0.6
			"hit": out = square * exp(-t * 22.0) * 0.5 + low * exp(-t * 40.0) * 1.5
			"boom": out = sine * exp(-t * 6.0) * 0.8 + low * exp(-t * 5.0) * 2.0
			"whoosh": out = low * sin(PI * n) * 1.8
			"coin": out = square * exp(-t * 6.0) * 0.35
			"jump": out = square * (1.0 - n) * 0.3
			"splash": out = low * exp(-t * 8.0) * 2.2 + noise * exp(-t * 20.0) * 0.3
			"zap": out = square * exp(-t * 12.0) * 0.4
			"beep": out = square * 0.3 * (1.0 if n < 0.85 else 0.0)
			"buzz": out = (square * 0.5 + (fmod(t * 113.0, 1.0) * 2.0 - 1.0) * 0.4) * (1.0 - n * 0.5) * 0.6
			"munch": out = low * sin(PI * n) * 2.4 + noise * exp(-t * 60.0) * 0.25
			"swish": out = (noise - low) * sin(PI * n) * 1.1
			"ding": out = (sine + sin(t * TAU * 2350.0) * 0.4) * exp(-t * 8.0) * 0.5
			"thud": out = sine * exp(-t * 26.0) + low * exp(-t * 80.0) * 1.6
			"squish": out = sine * sin(PI * n) * 0.5 + low * sin(PI * n) * 1.2
			"crunch": out = noise * (0.5 + 0.5 * sin(t * 300.0)) * exp(-t * 18.0) * 0.8
			"spring": out = square * exp(-t * 7.0) * 0.3
		samples[i] = out
	return _to_wav(samples)


func _tone(phase: float, wave: String) -> float:
	match wave:
		"square": return 1.0 if phase < 0.5 else -1.0
		"triangle": return 4.0 * absf(phase - 0.5) - 1.0
		"saw": return phase * 2.0 - 1.0
	return sin(phase * TAU)


func _make_tune(steps: Array, bpm: float, wave: String) -> AudioStreamWAV:
	var beat := 60.0 / bpm
	var samples := PackedFloat32Array()
	for step: Array in steps:
		var count := int(step[1] * beat * RATE)
		var start := samples.size()
		samples.resize(start + count)
		if str(step[0]) == "r":
			continue
		var freq := 440.0 * pow(2.0, float(step[0]) / 12.0)
		var phase := 0.0
		var phase2 := 0.0
		for i in count:
			var t := float(i) / RATE
			phase = fmod(phase + freq / RATE, 1.0)
			phase2 = fmod(phase2 + freq * 0.5 / RATE, 1.0)
			var env := minf(t * 200.0, 1.0) * exp(-t * 2.5) * minf(float(count - i) / 300.0, 1.0)
			samples[start + i] = (_tone(phase, wave) * 0.22 + _tone(phase2, "triangle") * 0.25) * env
	return _to_wav(samples)


## Two bars of bass, kick, snare and hats, set to loop.
func _make_groove(config: Array) -> AudioStreamWAV:
	var root: int = config[0]
	var bpm: float = config[1]
	var wave: String = config[2]
	var step_len := int(60.0 / bpm / 4.0 * RATE)  # sixteenth notes
	var steps := 32
	var samples := PackedFloat32Array()
	samples.resize(step_len * steps)
	var bass := [0, 0, 12, 0, 3, 0, 7, 5, 0, 0, 12, 0, 10, 7, 5, 3]
	for s in steps:
		var base := s * step_len
		if s % 2 == 0:
			var freq := 440.0 * pow(2.0, float(root + bass[(s / 2) % bass.size()]) / 12.0)
			var phase := 0.0
			for i in step_len * 2:
				if base + i >= samples.size():
					break
				phase = fmod(phase + freq / RATE, 1.0)
				var t := float(i) / RATE
				samples[base + i] += _tone(phase, wave) * 0.16 * exp(-t * 6.0)
		var kick := s % 8 == 0 or s % 16 == 11
		var snare := s % 8 == 4
		for i in step_len:
			var t := float(i) / RATE
			var v := 0.0
			if kick:
				v += sin(TAU * (120.0 - 400.0 * t) * t) * exp(-t * 18.0) * 0.6
			if snare:
				v += (randf() * 2.0 - 1.0) * exp(-t * 22.0) * 0.35
			v += (randf() * 2.0 - 1.0) * exp(-t * 90.0) * 0.08  # hat on every step
			samples[base + i] += v
	var wav := _to_wav(samples)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = samples.size()
	return wav


func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 30000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream
