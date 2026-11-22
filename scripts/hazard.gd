## Things that hurt Sanny when he touches them: spikes, spike towers, spike balls,
## and beat-spikes that pop up in time with the music.
##
## kind:
##   "ground_spikes"  a row of spikes on the ground
##   "ceiling_spikes" a row of spikes hanging from the ceiling
##   "column"         two thorny towers (from the top and the bottom) with a gap to fly through
##   "ball"           a spiky ball with a grumpy face, bobbing up and down
##   "beat_spikes"    ground spikes that shoot up on every other beat
extends Node2D

const Ink = preload("res://scripts/ink.gd")

const SPIKE_W := 44.0
const SPIKE_H := 58.0
const COLUMN_W := 70.0

var level
var kind := "ground_spikes"
var count := 3
var gap_top := 0.0      # column: where the open gap starts
var gap_bottom := 0.0   # column: where the open gap ends
var base_y := 0.0       # ball: middle of its bobbing
var amp := 120.0        # ball: how far it bobs
var speed := 1.5        # ball: how fast it bobs
var radius := 30.0      # ball size
var raise := 0.0        # beat spikes: 0 = hidden, 1 = fully up
var seed := 0
var _t := 0.0


func _ready() -> void:
	add_to_group("hazard")
	seed = randi() % 10000
	_t = randf() * TAU


func _process(delta: float) -> void:
	_t += delta
	match kind:
		"ball":
			position.y = base_y + sin(_t * speed) * amp
		"beat_spikes":
			# Up on even beats, down on odd beats. Watch the music!
			var up := Music.beat_index() % 2 == 0
			raise = move_toward(raise, 1.0 if up else 0.0, delta * 9.0)
	queue_redraw()


func width() -> float:
	match kind:
		"column":
			return COLUMN_W
		"ball":
			return radius * 2.0
	return SPIKE_W * count


## Does a circle (Sanny's hit circle) touch this hazard?
func touches(p: Vector2, r: float) -> bool:
	var x := position.x
	match kind:
		"ground_spikes":
			return Ink.circle_hits_rect(p, r, Rect2(x + 8, level.ground_y - SPIKE_H * 0.7, SPIKE_W * count - 16, SPIKE_H * 0.7))
		"ceiling_spikes":
			return Ink.circle_hits_rect(p, r, Rect2(x + 8, level.ceil_y, SPIKE_W * count - 16, SPIKE_H * 0.7))
		"beat_spikes":
			if raise < 0.5:
				return false
			var h := SPIKE_H * 1.3 * raise * 0.7
			return Ink.circle_hits_rect(p, r, Rect2(x + 8, level.ground_y - h, SPIKE_W * count - 16, h))
		"column":
			var top_box := Rect2(x, level.ceil_y, COLUMN_W, gap_top - level.ceil_y - 6)
			var bot_box := Rect2(x, gap_bottom + 6, COLUMN_W, level.ground_y - gap_bottom - 6)
			return Ink.circle_hits_rect(p, r, top_box) or Ink.circle_hits_rect(p, r, bot_box)
		"ball":
			return p.distance_to(position) < radius * 0.85 + r
	return false


## The Flood spell washes away spike balls.
func wash_away() -> bool:
	if kind == "ball":
		level.fx_puff(position, Ink.WATER, 50.0)
		queue_free()
		return true
	return false


func _draw() -> void:
	var gy: float = level.ground_y - position.y
	var cy: float = level.ceil_y - position.y
	match kind:
		"ground_spikes":
			Ink.spikes(self, 0, gy, count, SPIKE_W, SPIKE_H, -1.0, seed)
		"ceiling_spikes":
			Ink.spikes(self, 0, cy, count, SPIKE_W, SPIKE_H, 1.0, seed)
		"beat_spikes":
			if raise > 0.05:
				Ink.spikes(self, 0, gy, count, SPIKE_W, SPIKE_H * 1.3 * raise, -1.0, seed, Color(0.65, 0.35, 0.85, 0.45))
			# Little music notes so you know these follow the beat
			for i in count:
				_note(Vector2(SPIKE_W * (i + 0.5), gy + 22))
			Ink.line(self, Vector2(-4, gy), Vector2(SPIKE_W * count + 4, gy), 3.0, Ink.INK, seed + 2)
		"column":
			_thorn_tower(cy, gap_top, true)
			_thorn_tower(gap_bottom, gy, false)
		"ball":
			for i in 8:
				var a := TAU * i / 8.0 + _t * 0.8
				var d := Vector2(cos(a), sin(a))
				var side := d.orthogonal() * 9.0
				Ink.poly(self, PackedVector2Array([d * radius * 0.85 + side, d * (radius + 20.0), d * radius * 0.85 - side]), 2.5, Ink.INK, seed + i, Ink.SPIKE, true, 0.6)
			Ink.circle(self, Vector2.ZERO, radius, 3.0, Ink.INK, seed, Color(0.75, 0.7, 0.78, 0.6))
			Ink.face(self, Vector2.ZERO, radius, "angry", seed + 30)


func _note(at: Vector2) -> void:
	Ink.circle(self, at, 5.0, 2.0, Color(0.55, 0.2, 0.75), seed + int(at.x), Color(0.55, 0.2, 0.75, 0.8), 0.8)
	Ink.line(self, at + Vector2(5, 0), at + Vector2(5, -16), 2.0, Color(0.55, 0.2, 0.75), seed + 7)


## A tall box with thorns on both sides, pointing at the gap.
func _thorn_tower(y0: float, y1: float, from_top: bool) -> void:
	if y1 - y0 < 10.0:
		return
	Ink.rect(self, Rect2(8, y0, COLUMN_W - 16, y1 - y0), 3.0, Ink.INK, seed + (1 if from_top else 2), Color(0.55, 0.45, 0.35, 0.35))
	var y := y0 + 20.0
	var k := 0
	while y < y1 - 20.0:
		for side in [0.0, 1.0]:
			var bx: float = 8.0 + side * (COLUMN_W - 16.0)
			var out: float = -14.0 if side == 0.0 else 14.0
			Ink.poly(self, PackedVector2Array([Vector2(bx, y - 9), Vector2(bx + out, y), Vector2(bx, y + 9)]), 2.0, Ink.INK, seed + k, Ink.SPIKE, false, 0.5)
			k += 1
		y += 34.0
	# The end of the tower (next to the gap) is a row of spikes
	if from_top:
		Ink.spikes(self, 8, y1, 2, (COLUMN_W - 16) / 2.0, 22.0, 1.0, seed + 50)
	else:
		Ink.spikes(self, 8, y0, 2, (COLUMN_W - 16) / 2.0, 22.0, -1.0, seed + 51)
