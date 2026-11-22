## King Grumble, the boss at the end of the castle.
##
## He attacks ON THE BEAT of the boss music, so listening helps you dodge.
## Three phases, getting meaner as his health goes down:
##   1. (full to 2/3)  sprays 3 ink balls at Sanny every 2 beats
##   2. (2/3 to 1/3)   sprays 5, and calls bats every 8 beats
##   3. (below 1/3)    rings of ink balls, and charges at Sanny
extends "res://scripts/monster.gd"

const HOME_X := 1010.0   # where he hovers, measured from the left of the screen
var phase := 1
var _charge := 0.0       # >0 while charging
var _wind_up := 0.0      # flashes just before an attack


func setup_boss(total_hp: int) -> void:
	kind = "boss"
	is_boss = true
	max_hp = total_hp
	hp = total_hp
	radius = 100.0
	xp = 60
	coins = 30
	color = Color(0.45, 0.3, 0.6, 0.5)


func _ready() -> void:
	super._ready()
	active = true
	Music.beat.connect(_on_beat)


func _physics_process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	_wind_up = maxf(0.0, _wind_up - delta)
	var ratio := float(hp) / float(max_hp)
	var new_phase := 1 if ratio > 0.66 else (2 if ratio > 0.33 else 3)
	if new_phase != phase:
		phase = new_phase
		level.fx_text(position + Vector2(0, -140), "GRRR! Phase %d!" % phase, Color(0.6, 0.1, 0.1), 40)
		level.shake(14.0)
		Sfx.play("boss", 0.0)
	var home := Vector2(level.cam_x + HOME_X, 340.0 + sin(_t * 0.9) * 170.0)
	if _charge > 0.0:
		_charge -= delta
		var target_x: float = level.cam_x + 260.0
		position.x = move_toward(position.x, target_x, 900.0 * delta)
		if _charge <= 0.0:
			_charge = 0.0
	else:
		position = position.move_toward(home, 260.0 * delta)
	if poison_t > 0.0:
		poison_t -= delta
		_poison_tick -= delta
		if _poison_tick <= 0.0:
			_poison_tick = 0.5
			take_damage(1 + Game.attack_bonus(), false)
	queue_redraw()


func hit_radius() -> float:
	return radius


func _on_beat(i: int) -> void:
	if not alive or not is_inside_tree() or level.state != "boss":
		return
	var player = level.player
	if player == null or player.dead:
		return
	var aim: float = (player.hit_center() - position).angle()
	match phase:
		1:
			if i % 2 == 1:
				_wind_up = 0.25
			if i % 2 == 0:
				_spray(aim, 3, 0.28, 280.0)
		2:
			if i % 2 == 1:
				_wind_up = 0.25
			if i % 2 == 0:
				_spray(aim, 5, 0.22, 300.0)
			if i % 8 == 4:
				level.spawn_monster("bat", position + Vector2(0, -120))
				level.spawn_monster("bat", position + Vector2(0, 120))
		3:
			if i % 4 == 3:
				_wind_up = 0.35
			if i % 4 == 0:
				for k in 10:
					_spray(TAU * k / 10.0 + i * 0.3, 1, 0.0, 240.0)
			elif i % 2 == 0:
				_spray(aim, 3, 0.2, 340.0)
			if i % 16 == 10:
				_charge = 1.2
				level.fx_text(position + Vector2(0, -140), "CHARGE!", Color(0.6, 0.1, 0.1), 40)


func _spray(center_angle: float, n: int, spread: float, spd: float) -> void:
	for k in n:
		var a := center_angle + (k - (n - 1) / 2.0) * spread
		var dir := Vector2.RIGHT.rotated(a)
		level.spawn_bullet(position + dir * radius * 0.8, dir * spd, 1, false, "enemy", false, false)
	Sfx.play("pop", 0.2)


func _draw() -> void:
	var fill := Color(1, 1, 1, 0.9) if _flash > 0.0 else color
	if _wind_up > 0.0:
		fill = Color(1.0, 0.4, 0.3, 0.6)
	# Wings like Sanny's, but bigger and grumpier
	var flap := sin(_t * 6.0) * 0.25
	for side in [-1.0, 1.0]:
		var s: float = side
		var pts := PackedVector2Array()
		for k in 9:
			var a := PI * 0.5 + (k / 8.0) * PI
			var p := Vector2(cos(a) * 60.0 * s * -1.0 - 0.0, sin(a) * 90.0)
			pts.append(Vector2(s * (radius + 30.0), -30.0) + p.rotated(flap * s))
		Ink.poly(self, pts, 4.0, Ink.INK, seed + int(s * 7.0), fill, false)
	# Spikes all around
	for i in 12:
		var a := TAU * i / 12.0
		var d := Vector2(cos(a), sin(a))
		var side := d.orthogonal() * 14.0
		Ink.poly(self, PackedVector2Array([d * radius * 0.9 + side, d * (radius + 34.0), d * radius * 0.9 - side]), 3.0, Ink.INK, seed + i, Ink.SPIKE)
	Ink.circle(self, Vector2.ZERO, radius, 5.0, Ink.INK, seed, fill)
	# Crown
	var crown := PackedVector2Array([Vector2(-60, -radius + 10), Vector2(-70, -radius - 60), Vector2(-35, -radius - 25), Vector2(0, -radius - 75), Vector2(35, -radius - 25), Vector2(70, -radius - 60), Vector2(60, -radius + 10)])
	Ink.poly(self, crown, 4.0, Ink.INK, seed + 90, Ink.COIN)
	Ink.face(self, Vector2(0, 10), radius * 0.9, "teeth", seed + 40, Vector2.LEFT, 4.0)
	# Health bar is drawn by the HUD.
