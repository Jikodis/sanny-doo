## Little effects: floating words ("ON BEAT!", "+5") and scribble puffs (when something pops).
extends Node2D

const Ink = preload("res://scripts/ink.gd")

var kind := "text"   # "text" or "puff"
var text := ""
var color := Color.BLACK
var size := 30
var radius := 50.0
var life := 0.9
var seed := 0
var _age := 0.0


func _ready() -> void:
	seed = randi() % 10000
	z_index = 20


func _process(delta: float) -> void:
	_age += delta
	if _age >= life:
		queue_free()
		return
	if kind == "text":
		position.y -= 55.0 * delta
	queue_redraw()


func _draw() -> void:
	var k := _age / life
	match kind:
		"text":
			var c := color
			c.a = 1.0 - k * k
			Ink.text(self, Vector2.ZERO, text, size, c)
		"puff":
			var c2 := color
			c2.a *= 1.0 - k
			var ink := Ink.INK
			ink.a = 1.0 - k
			for i in 6:
				var a := TAU * i / 6.0 + seed
				var p := Vector2(cos(a), sin(a)) * radius * (0.3 + k)
				Ink.circle(self, p, radius * 0.25 * (1.0 - k * 0.5), 2.5, ink, seed + i, c2)
