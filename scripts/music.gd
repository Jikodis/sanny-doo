## Music: makes and plays the background songs, and keeps the beat (an autoload).
##
## The songs are built from math (drums, a bass line and a little tune), not
## sound files, so there are no music files to manage. Each song is a 4-bar loop.
##
## The beat is the rhythm part of the game: shots fired right on a beat do
## double damage, beat-spikes pop up on the beat, and the boss attacks on the beat.
extends Node

signal beat(index: int)

const MIX_RATE := 16000
const VOLUME_DB := -9.0

# bpm = beats per minute. root = the song's key (a MIDI note number). happy = major or minor.
const TRACKS := {
	"title": {"bpm": 100.0, "root": 60, "seed": 11, "happy": true},
	"home": {"bpm": 110.0, "root": 62, "seed": 22, "happy": true},
	"forest": {"bpm": 116.0, "root": 57, "seed": 33, "happy": false},
	"cave": {"bpm": 120.0, "root": 55, "seed": 44, "happy": false},
	"sky": {"bpm": 126.0, "root": 64, "seed": 55, "happy": true},
	"castle": {"bpm": 128.0, "root": 53, "seed": 66, "happy": false},
	"boss": {"bpm": 140.0, "root": 52, "seed": 77, "happy": false},
	"hub": {"bpm": 96.0, "root": 65, "seed": 88, "happy": true},
}
const BEATS_PER_LOOP := 16

var bpm := 120.0
var current := ""
var _player: AudioStreamPlayer
var _cache := {}
var _clock := 0.0
var _loop_len := 8.0
var _loops := 0
var _last_raw := 0.0
var _last_beat := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.volume_db = VOLUME_DB
	add_child(_player)


func play_track(track: String) -> void:
	if track == current and _player.playing:
		return
	current = track
	var info: Dictionary = TRACKS[track]
	bpm = info["bpm"]
	if not _cache.has(track):
		_cache[track] = _make_song(info)
	_player.stream = _cache[track]
	_loop_len = BEATS_PER_LOOP * 60.0 / bpm
	_clock = 0.0
	_loops = 0
	_last_raw = 0.0
	_last_beat = -1
	_player.play()


func _process(delta: float) -> void:
	if current == "":
		return
	_clock += delta
	# Follow the real audio position when we can (it is the most exact clock).
	if _player.playing:
		var raw := _player.get_playback_position()
		if raw > 0.0:
			if raw + 0.5 < _last_raw:
				_loops += 1
			_last_raw = raw
			_clock = _loops * _loop_len + raw + AudioServer.get_time_since_last_mix()
	var b := beat_index()
	if b > _last_beat:
		_last_beat = b
		beat.emit(b)


func beat_len() -> float:
	return 60.0 / bpm


func beat_float() -> float:
	return _clock / beat_len()


func beat_index() -> int:
	return int(floor(beat_float()))


## 0.0 right on a beat, going up to 1.0 just before the next one.
func beat_phase() -> float:
	return fposmod(beat_float(), 1.0)


## How many seconds away the nearest beat is (0 = exactly on the beat).
func beat_offset() -> float:
	var ph := beat_phase()
	return minf(ph, 1.0 - ph) * beat_len()


# ---------------------------------------------------------------- song maker
func _midi(n: float) -> float:
	return 440.0 * pow(2.0, (n - 69.0) / 12.0)


func _make_song(info: Dictionary) -> AudioStreamWAV:
	var bl: float = 60.0 / float(info["bpm"])
	var n := int(BEATS_PER_LOOP * bl * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(info["seed"])
	var happy: bool = info["happy"]
	var scale := [0, 2, 4, 7, 9] if happy else [0, 3, 5, 7, 10]
	var prog := [0, 7, 9, 5] if happy else [0, 8, 3, 10]
	var root: int = info["root"]
	# A 2-bar tune (16 eighth notes) that repeats, so it is catchy.
	var tune := []
	for i in 16:
		if rng.randf() < 0.7:
			tune.append(scale[rng.randi() % scale.size()] + (12 if rng.randf() < 0.25 else 0))
		else:
			tune.append(-1)
	for b in BEATS_PER_LOOP:
		var t0 := b * bl
		var bar := b / 4
		if b % 2 == 0:
			_kick(buf, t0)
		else:
			_snare(buf, t0, rng)
		for half in 2:
			var th := t0 + half * bl * 0.5
			_hat(buf, th, 0.5 if half == 1 else 0.3, rng)
			var bass_note: float = root - 24 + prog[bar] + (12 if (half == 1 and b % 2 == 1) else 0)
			_tone(buf, th, bl * 0.45, _midi(bass_note), 0.22, false)
			var step := (b % 8) * 2 + half
			var tn: int = tune[step]
			if tn >= 0:
				_tone(buf, th, bl * 0.4, _midi(root + tn), 0.08, true)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav


func _tone(buf: PackedFloat32Array, start: float, dur: float, freq: float, vol: float, square: bool) -> void:
	var i0 := int(start * MIX_RATE)
	var count := int(dur * MIX_RATE)
	for i in count:
		var idx := i0 + i
		if idx >= buf.size():
			return
		var t := float(i) / MIX_RATE
		var ph := fposmod(t * freq, 1.0)
		var v := (1.0 if ph < 0.5 else -1.0) if square else (4.0 * absf(ph - 0.5) - 1.0)
		var env := minf(1.0, t * 300.0) * (1.0 - t / dur)
		buf[idx] += v * vol * env


func _kick(buf: PackedFloat32Array, start: float) -> void:
	var i0 := int(start * MIX_RATE)
	var phase := 0.0
	for i in int(0.2 * MIX_RATE):
		var idx := i0 + i
		if idx >= buf.size():
			return
		var t := float(i) / MIX_RATE
		phase += (50.0 + 100.0 * exp(-t * 30.0)) / MIX_RATE
		buf[idx] += sin(phase * TAU) * exp(-t * 14.0) * 0.6


func _snare(buf: PackedFloat32Array, start: float, rng: RandomNumberGenerator) -> void:
	var i0 := int(start * MIX_RATE)
	for i in int(0.16 * MIX_RATE):
		var idx := i0 + i
		if idx >= buf.size():
			return
		var t := float(i) / MIX_RATE
		buf[idx] += rng.randf_range(-1.0, 1.0) * exp(-t * 22.0) * 0.28 + sin(t * 190.0 * TAU) * exp(-t * 30.0) * 0.18


func _hat(buf: PackedFloat32Array, start: float, vol: float, rng: RandomNumberGenerator) -> void:
	var i0 := int(start * MIX_RATE)
	var prev := 0.0
	for i in int(0.04 * MIX_RATE):
		var idx := i0 + i
		if idx >= buf.size():
			return
		var t := float(i) / MIX_RATE
		var nz := rng.randf_range(-1.0, 1.0)
		buf[idx] += (nz - prev) * 0.5 * exp(-t * 90.0) * vol * 0.4
		prev = nz
