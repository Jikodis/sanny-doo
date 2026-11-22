## Sfx: little sound effects made from math at startup (an autoload).
## Sfx.play("coin") plays one. No sound files needed.
extends Node

const MIX_RATE := 22050
const VOICES := 10

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_players.append(p)
	_rng.seed = 7
	# name: list of [start_freq, end_freq, seconds, wave, volume, noise]
	_sounds["shoot"] = _make([[900.0, 500.0, 0.08, "sq", 0.25, 0.0]])
	_sounds["beat"] = _make([[1200.0, 1200.0, 0.06, "sq", 0.25, 0.0], [1800.0, 1800.0, 0.09, "sq", 0.25, 0.0]])
	_sounds["coin"] = _make([[988.0, 988.0, 0.06, "sq", 0.2, 0.0], [1319.0, 1319.0, 0.12, "sq", 0.2, 0.0]])
	_sounds["hurt"] = _make([[400.0, 90.0, 0.28, "saw", 0.4, 0.3]])
	_sounds["flap"] = _make([[300.0, 200.0, 0.07, "tri", 0.12, 0.5]])
	_sounds["pop"] = _make([[600.0, 120.0, 0.18, "sq", 0.25, 0.5]])
	_sounds["spell"] = _make([[523.0, 523.0, 0.07, "tri", 0.3, 0.0], [659.0, 659.0, 0.07, "tri", 0.3, 0.0], [784.0, 784.0, 0.07, "tri", 0.3, 0.0], [1047.0, 1047.0, 0.2, "tri", 0.3, 0.0]])
	_sounds["heal"] = _make([[660.0, 880.0, 0.12, "tri", 0.3, 0.0], [880.0, 1320.0, 0.25, "tri", 0.3, 0.0]])
	_sounds["levelup"] = _make([[523.0, 523.0, 0.1, "sq", 0.2, 0.0], [659.0, 659.0, 0.1, "sq", 0.2, 0.0], [784.0, 784.0, 0.1, "sq", 0.2, 0.0], [1047.0, 1047.0, 0.35, "sq", 0.2, 0.0]])
	_sounds["nope"] = _make([[160.0, 140.0, 0.16, "sq", 0.2, 0.0]])
	_sounds["boss"] = _make([[110.0, 55.0, 0.6, "saw", 0.4, 0.2]])
	_sounds["win"] = _make([[523.0, 523.0, 0.15, "sq", 0.2, 0.0], [523.0, 523.0, 0.1, "sq", 0.2, 0.0], [784.0, 784.0, 0.15, "sq", 0.2, 0.0], [1047.0, 1047.0, 0.5, "sq", 0.2, 0.0]])
	_sounds["click"] = _make([[700.0, 700.0, 0.03, "sq", 0.15, 0.0]])
	_sounds["splash"] = _make([[300.0, 100.0, 0.6, "tri", 0.2, 0.7]])
	_sounds["zap"] = _make([[200.0, 1600.0, 0.15, "saw", 0.25, 0.1]])


func play(sound_name: String, pitch_jitter: float = 0.05) -> void:
	if not _sounds.has(sound_name):
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _sounds[sound_name]
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func _make(notes: Array) -> AudioStreamWAV:
	var buf := PackedFloat32Array()
	for nt in notes:
		var f0: float = nt[0]
		var f1: float = nt[1]
		var dur: float = nt[2]
		var wave: String = nt[3]
		var vol: float = nt[4]
		var noise: float = nt[5]
		var count := int(dur * MIX_RATE)
		var ph := 0.0
		for i in count:
			var t := float(i) / count
			ph += lerpf(f0, f1, t) / MIX_RATE
			var p := fposmod(ph, 1.0)
			var v := 0.0
			match wave:
				"sq":
					v = 1.0 if p < 0.5 else -1.0
				"saw":
					v = p * 2.0 - 1.0
				_:
					v = 4.0 * absf(p - 0.5) - 1.0
			v = lerpf(v, _rng.randf_range(-1.0, 1.0), noise)
			var env := minf(1.0, float(i) / 60.0) * (1.0 - t)
			buf.append(v * vol * env)
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.data = bytes
	return wav
