## A shot. Sanny's shots look like his weapon (pencil, ink, star, lightning).
## Monster shots are ink blots. Shots fired on the beat are bigger and glow.
extends Node2D

const Ink = preload("res://scripts/ink.gd")

var level
var vel := Vector2.ZERO
var dmg := 1
var radius := 9.0
var from_player := true
var kind := "dart"
var pierce := false
var on_beat := false
var life := 2.5
var already_hit: Array = []
var seed := 0


func _ready() -> void:
	add_to_group("player_bullet" if from_player else "enemy_bullet")
	seed = randi() % 10000
	if on_beat:
		radius *= 1.5
	if kind == "enemy":
		radius = 11.0
	rotation = vel.angle() if from_player else 0.0


func _physics_process(delta: float) -> void:
	position += vel * delta
	life -= delta
	if life <= 0.0 or position.x > level.cam_x + 1340.0 or position.x < level.cam_x - 60.0 or position.y < -60.0 or position.y > 780.0:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var s := 1.5 if on_beat else 1.0
	if on_beat:
		Ink.circle(self, Vector2.ZERO, 20.0 * s, 2.0, Color(0.55, 0.2, 0.75, 0.6), seed, Color(0.8, 0.6, 1.0, 0.3))
	match kind:
		"dart":
			# A little pencil
			Ink.rect(self, Rect2(-18 * s, -4 * s, 22 * s, 8 * s), 2.0, Ink.INK, seed, Color(1.0, 0.85, 0.3, 0.9))
			Ink.poly(self, PackedVector2Array([Vector2(4 * s, -4 * s), Vector2(14 * s, 0), Vector2(4 * s, 4 * s)]), 2.0, Ink.INK, seed + 1, Color(0.95, 0.8, 0.6, 1.0))
		"ink":
			Ink.circle(self, Vector2.ZERO, 8.0 * s, 2.0, Ink.INK, seed, Color(0.2, 0.3, 0.8, 0.8))
		"star":
			Ink.poly(self, Ink.star_points(Vector2.ZERO, 13.0 * s, 6.0 * s, 5, life * 8.0), 2.0, Ink.INK, seed, Ink.COIN)
		"bolt":
			var z := PackedVector2Array([Vector2(-22 * s, -5), Vector2(-8 * s, 4), Vector2(-2 * s, -5), Vector2(10 * s, 4), Vector2(20 * s, -2)])
			draw_polyline(z, Color(1.0, 0.85, 0.1, 0.9), 7.0 * s, true)
			draw_polyline(Ink.wobble_points(z, false, seed, 1.0), Ink.INK, 2.0, true)
		"enemy":
			Ink.circle(self, Vector2.ZERO, radius, 2.5, Ink.INK, seed, Color(0.25, 0.15, 0.35, 0.85), 1.0, 2.0)
