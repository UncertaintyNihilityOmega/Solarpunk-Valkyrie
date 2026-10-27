extends Node
## Procedural audio: synthesizes every sound effect and two music loops at
## startup, so the prototype needs no audio files. Autoloaded as `Sfx`.
## Volumes come from Game.settings (master / music / sfx / mute).

const RATE := 22050
const POOL_SIZE := 14

var _sounds := {}
var _music := {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_idx := 0
var _music_player: AudioStreamPlayer
var _music_key := ""
var _last_played := {}
var _headless := false
var _pending := {} # music key -> WorkerThreadPool task id
var _music_mutex := Mutex.new()


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	if _headless:
		return
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)
	_build_sounds()
	apply_volumes()
	Game.settings_changed.connect(apply_volumes)
	_request_music("menu")
	_request_music("battle")


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


func apply_volumes() -> void:
	if _headless:
		return
	var s: Dictionary = Game.settings
	AudioServer.set_bus_mute(0, bool(s.mute))
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, float(s.master_volume))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(0.0001, float(s.music_volume))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(0.0001, float(s.sfx_volume))))


## Plays a named effect. Rapid repeats of the same sound are throttled.
func play(sound: String, pitch_jitter: float = 0.06, volume_db: float = 0.0) -> void:
	if _headless or not _sounds.has(sound):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sound, -1000)) < 45:
		return
	_last_played[sound] = now
	var p := _pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % _pool.size()
	p.stream = _sounds[sound]
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.volume_db = volume_db
	p.play()


func play_music(key: String) -> void:
	if _headless or key == _music_key:
		return
	_music_key = key
	_music_mutex.lock()
	var have := _music.has(key)
	_music_mutex.unlock()
	if have:
		_start_music()
	else:
		_request_music(key)


## Music is synthesized on a worker thread so menus never hitch.
func _request_music(key: String) -> void:
	_music_mutex.lock()
	var busy := _music.has(key) or _pending.has(key)
	_music_mutex.unlock()
	if busy:
		return
	_pending[key] = WorkerThreadPool.add_task(_generate_music.bind(key))


func _generate_music(key: String) -> void:
	var stream := _make_music(key)
	_music_mutex.lock()
	_music[key] = stream
	_music_mutex.unlock()


func _process(_delta: float) -> void:
	for key in _pending.keys():
		var id: int = _pending[key]
		if WorkerThreadPool.is_task_completed(id):
			WorkerThreadPool.wait_for_task_completion(id)
			_pending.erase(key)
			if key == _music_key:
				_start_music()


func _start_music() -> void:
	_music_mutex.lock()
	_music_player.stream = _music[_music_key]
	_music_mutex.unlock()
	_music_player.volume_db = -4.0
	_music_player.play()


func stop_music() -> void:
	if _headless:
		return
	_music_key = ""
	_music_player.stop()


func _exit_tree() -> void:
	for key in _pending:
		WorkerThreadPool.wait_for_task_completion(_pending[key])


# ------------------------------------------------------------------ synthesis

func _build_sounds() -> void:
	_sounds.click = _tone(880, 660, 0.06, "square", 0.0, 0.002, 0.35)
	_sounds.hover = _tone(1320, 1320, 0.025, "sine", 0.0, 0.002, 0.12)
	_sounds.deploy = _tone(330, 660, 0.16, "triangle", 0.15, 0.005, 0.55)
	_sounds.splat = _tone(220, 90, 0.12, "sine", 0.6, 0.002, 0.35)
	_sounds.hit = _tone(180, 120, 0.06, "square", 0.5, 0.001, 0.22)
	_sounds.shoot = _tone(900, 500, 0.05, "triangle", 0.2, 0.001, 0.15)
	_sounds.explode = _tone(120, 40, 0.45, "sine", 0.85, 0.002, 0.7)
	_sounds.zap = _tone(1400, 300, 0.18, "saw", 0.3, 0.001, 0.4)
	_sounds.freeze = _tone(1800, 2400, 0.3, "sine", 0.25, 0.01, 0.35)
	_sounds.spawn = _tone(500, 800, 0.08, "sine", 0.05, 0.002, 0.3)
	_sounds.death = _tone(300, 80, 0.22, "triangle", 0.4, 0.002, 0.4)
	_sounds.error = _tone(220, 180, 0.18, "square", 0.0, 0.002, 0.3)
	_sounds.energy = _tone(1046, 1568, 0.12, "sine", 0.0, 0.002, 0.25)
	_sounds.countdown = _tone(660, 660, 0.15, "sine", 0.0, 0.002, 0.45)
	_sounds.overtime = _chord([523.0, 659.0, 784.0, 1046.0], 0.7, "triangle", 0.5)
	_sounds.win = _arp([523.0, 659.0, 784.0, 1046.0, 1318.0], 0.11, "triangle", 0.5)
	_sounds.lose = _arp([392.0, 330.0, 262.0, 196.0], 0.16, "triangle", 0.45)
	_sounds.pack = _arp([392.0, 523.0, 659.0, 784.0], 0.07, "square", 0.3)
	_sounds.reveal = _tone(600, 1200, 0.25, "triangle", 0.1, 0.004, 0.45)
	_sounds.legendary = _chord([523.0, 784.0, 1046.0, 1568.0], 1.0, "sine", 0.5)
	_sounds.upgrade = _arp([523.0, 784.0, 1046.0], 0.09, "sine", 0.45)
	_sounds.coins = _arp([1318.0, 1568.0, 2093.0], 0.05, "sine", 0.3)


func _osc(wave: String, phase: float) -> float:
	var p := fposmod(phase, 1.0)
	match wave:
		"square":
			return 1.0 if p < 0.5 else -1.0
		"saw":
			return p * 2.0 - 1.0
		"triangle":
			return 1.0 - 4.0 * absf(p - 0.5)
		_:
			return sin(p * TAU)


func _wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = samples.size()
	return w


## A pitch sweep with optional noise, simple attack + exponential decay.
func _tone(f0: float, f1: float, dur: float, wave: String, noise: float, attack: float, vol: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		phase += f / RATE
		var env := minf(1.0, (float(i) / RATE) / maxf(attack, 0.0005)) * pow(1.0 - t, 2.0)
		var s := _osc(wave, phase) * (1.0 - noise) + randf_range(-1.0, 1.0) * noise
		out[i] = s * env * vol
	return _wav(out)


func _arp(freqs: Array, step: float, wave: String, vol: float) -> AudioStreamWAV:
	var note_len := int(step * RATE)
	var tail := int(0.25 * RATE)
	var n := note_len * freqs.size() + tail
	var out := PackedFloat32Array()
	out.resize(n)
	for k in freqs.size():
		var start := k * note_len
		var length := note_len + tail
		var phase := 0.0
		for i in length:
			if start + i >= n:
				break
			phase += freqs[k] / RATE
			var env := minf(1.0, i / 80.0) * exp(-3.5 * float(i) / length)
			out[start + i] += _osc(wave, phase) * env * vol * 0.6
	return _wav(out)


func _chord(freqs: Array, dur: float, wave: String, vol: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for f in freqs:
		var phase := 0.0
		for i in n:
			phase += f / RATE
			var env := minf(1.0, i / 200.0) * exp(-2.5 * float(i) / n)
			out[i] += _osc(wave, phase) * env * vol / freqs.size()
	return _wav(out)


## Gentle pentatonic loop: soft pad + plucked arpeggio. "battle" is faster and brighter.
func _make_music(key: String) -> AudioStreamWAV:
	var battle := key == "battle"
	var bpm := 112.0 if battle else 84.0
	var beat := 60.0 / bpm
	var bars := 8
	var n := int(bars * 4 * beat * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	# Chord roots (in semitones from A3=220Hz): a hopeful I-V-vi-IV feel.
	var roots := [3, 10, 0, 8, 3, 10, 5, 8] if not battle else [0, 8, 3, 10, 0, 8, 5, 7]
	var scale := [0, 2, 4, 7, 9, 12, 14, 16]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 if battle else 3
	for bar in bars:
		var root_f := 220.0 * pow(2.0, roots[bar] / 12.0)
		var bar_start := int(bar * 4 * beat * RATE)
		var bar_len := int(4 * beat * RATE)
		# Pad: root + fifth + tenth, slow swell.
		for interval in [0, 7, 16]:
			var f := root_f * 0.5 * pow(2.0, interval / 12.0)
			var phase := 0.0
			for i in bar_len:
				phase += f / RATE
				var t := float(i) / bar_len
				var env := sin(t * PI) * 0.6 + 0.2
				out[bar_start + i] += sin(phase * TAU) * env * 0.045
		# Pluck arpeggio on eighth notes.
		var steps := 8
		for s in steps:
			if not battle and rng.randf() < 0.25:
				continue
			var deg: int = scale[(s * 3 + bar + rng.randi_range(0, 2)) % scale.size()]
			var f := root_f * pow(2.0, deg / 12.0)
			var start := bar_start + int(s * beat * 0.5 * RATE)
			var length := int(beat * 0.9 * RATE)
			var phase := 0.0
			for i in length:
				if start + i >= n:
					break
				phase += f / RATE
				var env := exp(-6.0 * float(i) / length) * minf(1.0, i / 60.0)
				out[start + i] += _osc("triangle", phase) * env * 0.09
		# Soft kick on beats in battle music.
		if battle:
			for b in 4:
				var start := bar_start + int(b * beat * RATE)
				var length := int(0.18 * RATE)
				var phase := 0.0
				for i in length:
					if start + i >= n:
						break
					var t := float(i) / length
					phase += lerpf(110.0, 40.0, t) / RATE
					out[start + i] += sin(phase * TAU) * pow(1.0 - t, 3.0) * 0.18
	return _wav(out, true)
