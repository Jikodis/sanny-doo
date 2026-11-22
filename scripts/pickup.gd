## Things to collect: coins, big coins (worth 5), hearts, and magic bottles.
## They slide toward Sanny when he gets close (a magnet), which helps young players.
extends Node2D

const Ink = preload("res://scripts/ink.gd")
const MAGNET_RANGE := 120.0
const MAGNET_SPEED := 420.0

var level
var kind := "coin"   # "coin", "big_coin", "heart", "mana"
var radius := 16.0
var seed := 0
var _t := 0.0
var _base_y := 0.0


func _ready() -> void:
	add_to_group("pickup")
	seed = randi() % 10000
	_t = randf() * TAU
	_base_y = position.y
	if kind == "big_coin":
		radius = 24.0


func _physics_process(delta: float) -> void:
	_t += delta
	var player = level.player
	if player and not player.dead and position.distance_to(player.position) < MAGNET_RANGE:
		position = position.move_toward(player.position, MAGNET_SPEED * delta)
		_base_y = position.y
	else:
		position.y = _base_y + sin(_t * 3.0) * 5.0
	if position.x < level.cam_x - 80.0:
		queue_free()
	queue_redraw()


func collect() -> void:
	var player = level.player
	match kind:
		"coin":
			Game.add_coins(1)
			level.coins_got += 1
			Sfx.play("coin", 0.03)
		"big_coin":
			Game.add_coins(5)
			level.coins_got += 5
			level.fx_text(position + Vector2(0, -30), "+5", Color(0.8, 0.55, 0.0))
			Sfx.play("coin", 0.0)
		"heart":
			player.hp = mini(player.hp + 1, Game.max_hearts())
			level.fx_text(position + Vector2(0, -30), "+1 heart", Color(0.85, 0.15, 0.2))
			Sfx.play("heal", 0.0)
		"mana":
			player.mana = minf(float(Game.max_mana()), player.mana + 3.0)
			level.fx_text(position + Vector2(0, -30), "+3 magic", Color(0.2, 0.4, 0.9))
			Sfx.play("spell", 0.0)
	queue_free()


func _draw() -> void:
	match kind:
		"coin", "big_coin":
			var spin := absf(cos(_t * 3.0)) * 0.8 + 0.2
			Ink.circle(self, Vector2.ZERO, radius, 2.5, Ink.INK, seed, Ink.COIN, 1.0)
			if spin > 0.5:
				Ink.text(self, Vector2(0, radius * 0.45), "5" if kind == "big_coin" else "$", int(radius * 1.3))
		"heart":
			Ink.heart(self, Vector2.ZERO, 18.0, Ink.HEART, 2.5, seed)
		"mana":
			var bottle := PackedVector2Array([Vector2(-6, -20), Vector2(6, -20), Vector2(6, -10), Vector2(15, 4), Vector2(12, 18), Vector2(-12, 18), Vector2(-15, 4), Vector2(-6, -10)])
			Ink.poly(self, bottle, 2.5, Ink.INK, seed, Ink.MANA)
