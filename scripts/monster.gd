## Monsters. They are drawn in the same pen style as Sanny, with faces like his.
##
## kind:
##   "blob"    a round green blob that floats up and down
##   "bat"     a purple bat that swoops toward Sanny
##   "spitter" an orange box monster that spits ink balls at Sanny
##   "spiky"   a red spiky monster that puffs up on the beat (tough!)
extends Node2D

const Ink = preload("res://scripts/ink.gd")

# hp, size, xp reward, coins dropped, crayon color
const KINDS := {
	"blob": {"hp": 2, "radius": 30.0, "xp": 3, "coins": 1, "color": Color(0.45, 0.8, 0.35, 0.55)},
	"bat": {"hp": 2, "radius": 26.0, "xp": 4, "coins": 2, "color": Color(0.6, 0.4, 0.85, 0.55)},
	"spitter": {"hp": 4, "radius": 32.0, "xp": 6, "coins": 2, "color": Color(1.0, 0.6, 0.2, 0.55)},
	"spiky": {"hp": 6, "radius": 34.0, "xp": 8, "coins": 3, "color": Color(0.9, 0.3, 0.3, 0.5)},
}

var level
var kind := "blob"
var hp := 2
var max_hp := 2
var radius := 30.0
var xp := 3
var coins := 1
var color := Color.WHITE
var active := false
var alive := true
var base_y := 0.0
var poison_t := 0.0     # seconds of poison left
var seed := 0
var is_boss := false
var _t := 0.0
var _flash := 0.0
var _shoot_t := 2.0
var _poison_tick := 0.0


func setup(k: String, hp_scale: float) -> void:
	kind = k
	var d: Dictionary = KINDS[k]
	max_hp = int(ceil(float(d["hp"]) * hp_scale))
	hp = max_hp
	radius = d["radius"]
	xp = d["xp"]
	coins = d["coins"]
	color = d["color"]


func _ready() -> void:
	add_to_group("monster")
	seed = randi() % 10000
	base_y = position.y
	_t = randf() * TAU
	_shoot_t = randf_range(1.0, 2.5)


func _physics_process(delta: float) -> void:
	if not active:
		# Wake up when the screen reaches us.
		if position.x < level.cam_x + 1280.0 + 60.0:
			active = true
		else:
			return
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	var player = level.player
	match kind:
		"blob":
			position.x -= 40.0 * delta
			position.y = base_y + sin(_t * 2.2) * 50.0
		"bat":
			position.x -= 110.0 * delta
			if player and not player.dead:
				position.y = move_toward(position.y, player.position.y, 95.0 * delta)
			position.y += sin(_t * 9.0) * 1.5
		"spitter":
			position.x -= 25.0 * delta
			position.y = base_y + sin(_t * 1.3) * 30.0
			_shoot_t -= delta
			var on_screen: bool = position.x < level.cam_x + 1240.0
			if _shoot_t <= 0.0 and on_screen and player and not player.dead:
				_shoot_t = 2.4
				var dir: Vector2 = (player.hit_center() - position).normalized()
				level.spawn_bullet(position + dir * radius, dir * 260.0, 1, false, "enemy", false, false)
		"spiky":
			position.x -= 30.0 * delta
			position.y = base_y + sin(_t * 1.6) * 40.0
	position.y = clampf(position.y, level.ceil_y + radius, level.ground_y - radius)
	# Poison hurts a little bit every half second.
	if poison_t > 0.0:
		poison_t -= delta
		_poison_tick -= delta
		if _poison_tick <= 0.0:
			_poison_tick = 0.5
			take_damage(1 + Game.attack_bonus(), false)
	queue_redraw()


## How big we are right now (spiky monsters puff up on the beat).
func hit_radius() -> float:
	if kind == "spiky":
		return radius * (1.0 + 0.35 * (1.0 - Music.beat_phase()))
	return radius


func take_damage(n: int, on_beat: bool) -> void:
	if not alive:
		return
	hp -= n
	_flash = 0.12
	level.fx_text(position + Vector2(randf_range(-10, 10), -radius - 10), str(n), Color(0.55, 0.2, 0.75) if on_beat else Ink.INK, 26)
	if hp <= 0:
		alive = false
		level.on_monster_killed(self)
		queue_free()


func poison(seconds: float) -> void:
	poison_t = maxf(poison_t, seconds)


func _draw() -> void:
	var fill := Color(1, 1, 1, 0.9) if _flash > 0.0 else color
	var mood := "angry"
	var look := Vector2.LEFT
	match kind:
		"blob":
			Ink.circle(self, Vector2.ZERO, radius, 3.0, Ink.INK, seed, fill, 0.85)
			mood = "o"
		"bat":
			var flap := sin(_t * 14.0) * 14.0
			for side in [-1.0, 1.0]:
				var s: float = side
				var wing := PackedVector2Array([Vector2(s * radius * 0.7, -4), Vector2(s * radius * 1.9, -18 - flap), Vector2(s * radius * 1.6, 4 - flap * 0.3), Vector2(s * radius * 1.25, -2), Vector2(s * radius * 1.0, 10)])
				Ink.poly(self, wing, 2.5, Ink.INK, seed + int(s * 4.0), fill)
			Ink.circle(self, Vector2.ZERO, radius, 3.0, Ink.INK, seed, fill, 1.1)
		"spitter":
			Ink.rect(self, Rect2(-radius, -radius, radius * 2.0, radius * 2.0), 3.0, Ink.INK, seed, fill)
			Ink.rect(self, Rect2(-radius - 18, 2, 18, 16), 2.5, Ink.INK, seed + 5, fill)  # spitting tube
			mood = "teeth"
		"spiky":
			var r := hit_radius()
			var pts := Ink.star_points(Vector2.ZERO, r * 1.25, r * 0.85, 9, _t * 0.5)
			Ink.poly(self, pts, 3.0, Ink.INK, seed, fill)
	Ink.face(self, Vector2.ZERO, radius, mood, seed + 40, look)
	if poison_t > 0.0:
		for i in 3:
			var bub := Vector2(sin(_t * 3.0 + i * 2.0) * radius * 0.6, -radius - 8 - fposmod(_t * 30.0 + i * 12.0, 30.0))
			Ink.circle(self, bub, 5.0, 2.0, Ink.INK, seed + 60 + i, Ink.POISON)
	if hp < max_hp:
		var wbar := radius * 1.6
		draw_rect(Rect2(-wbar / 2.0, radius + 8, wbar, 6), Color(0, 0, 0, 0.15))
		draw_rect(Rect2(-wbar / 2.0, radius + 8, wbar * hp / max_hp, 6), Color(0.85, 0.2, 0.2, 0.8))
