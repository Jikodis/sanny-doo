## Magic that stays on screen for a while:
##   "poison": a green cloud that floats forward and poisons monsters inside it
##   "flood":  a big wave that sweeps across the screen, hurting every monster
##             and washing away spike balls and ink shots
extends Node2D

const Ink = preload("res://scripts/ink.gd")

const POISON_TIME := 4.0
const POISON_RADIUS := 110.0
const POISON_SPEED := 120.0
const FLOOD_TIME := 1.6
const FLOOD_DAMAGE := 6

var level
var kind := "poison"
var seed := 0
var _age := 0.0
var _hit: Array = []


func _ready() -> void:
	seed = randi() % 10000
	z_index = 10


func _physics_process(delta: float) -> void:
	_age += delta
	match kind:
		"poison":
			position.x += POISON_SPEED * delta
			for m in get_tree().get_nodes_in_group("monster"):
				if m.alive and m.position.distance_to(position) < POISON_RADIUS + m.hit_radius():
					m.poison(3.0)
			if _age > POISON_TIME:
				queue_free()
		"flood":
			var front := _front_x()
			for m in get_tree().get_nodes_in_group("monster"):
				if m.alive and not _hit.has(m) and m.position.x < front:
					_hit.append(m)
					m.take_damage(FLOOD_DAMAGE + Game.attack_bonus() * 2, false)
			for b in get_tree().get_nodes_in_group("enemy_bullet"):
				if b.position.x < front:
					b.queue_free()
			for h in get_tree().get_nodes_in_group("hazard"):
				if h.position.x < front and h.position.x > level.cam_x - 50.0:
					h.wash_away()
			if _age > FLOOD_TIME + 0.5:
				queue_free()
	queue_redraw()


func _front_x() -> float:
	return level.cam_x - 200.0 + (1600.0 * minf(1.0, _age / FLOOD_TIME))


func _draw() -> void:
	match kind:
		"poison":
			var fade := 1.0 - maxf(0.0, (_age - POISON_TIME + 0.8) / 0.8)
			var c := Ink.POISON
			c.a *= fade
			var ink := Ink.INK
			ink.a = fade
			for i in 7:
				var a := TAU * i / 7.0 + _age
				var p := Vector2(cos(a), sin(a)) * POISON_RADIUS * 0.5
				Ink.circle(self, p, POISON_RADIUS * 0.45, 2.5, ink, seed + i, c)
			Ink.text(self, Vector2(0, 10), "poison!", 26, Color(0.2, 0.45, 0.1, fade))
		"flood":
			# Drawn in world space from the left edge of the screen to the wave front.
			var front := _front_x() - position.x
			var left: float = level.cam_x - 200.0 - position.x
			var fade := 1.0 - maxf(0.0, (_age - FLOOD_TIME) / 0.5)
			var top := -position.y + 120.0
			var bottom: float = level.ground_y - position.y
			var pts := PackedVector2Array()
			pts.append(Vector2(left, bottom))
			var x := left
			while x < front:
				pts.append(Vector2(x, top + sin(x * 0.02 + _age * 6.0) * 30.0))
				x += 40.0
			pts.append(Vector2(front + 60.0, top + 60.0))
			pts.append(Vector2(front, bottom))
			var c := Ink.WATER
			c.a *= fade
			draw_colored_polygon(pts, c)
			var ink := Ink.INK
			ink.a = fade
			draw_polyline(Ink.wobble_points(pts, false, seed, 2.0, 20.0), ink, 3.0, true)
			# Curly wave tops, the way kids draw waves
			x = left + 30.0
			while x < front:
				Ink.circle(self, Vector2(x, top + sin(x * 0.02 + _age * 6.0) * 30.0 + 16.0), 14.0, 2.5, ink, seed + int(x))
				x += 120.0
