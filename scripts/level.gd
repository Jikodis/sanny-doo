## A level: the screen scrolls right and Sanny Doo flies through spikes, monsters and coins.
##
## The level is built from the data in Game.LEVELS: it strings together "chunks"
## (a row of coins, a spike tower, a group of monsters...) picked with a fixed
## random seed, so each level is the same every time you play it.
## Halfway there is a checkpoint. The last level ends with the King Grumble boss fight.
extends Node2D

const Ink = preload("res://scripts/ink.gd")
const Player = preload("res://scripts/player.gd")
const Hazard = preload("res://scripts/hazard.gd")
const Monster = preload("res://scripts/monster.gd")
const Boss = preload("res://scripts/boss.gd")
const Bullet = preload("res://scripts/bullet.gd")
const Pickup = preload("res://scripts/pickup.gd")
const Fx = preload("res://scripts/fx.gd")
const SpellFx = preload("res://scripts/spell_fx.gd")
const Decor = preload("res://scripts/decor.gd")
const Hud = preload("res://scripts/hud.gd")

const VIEW_W := 1280.0
const INTRO_TIME := 2.0
const LEFT_PAD := 12.0

var data: Dictionary
var index := 0
var length := 7000.0
var scroll_speed := 150.0
var ground_y := 650.0
var ceil_y := 20.0
var cam_x := 0.0
var state := "intro"   # intro, play, boss, done, dead
var intro_t := INTRO_TIME
var coins_got := 0
var xp_got := 0
var finish_x := 0.0
var checkpoint_x := 0.0
var checkpoint_reached := false
var arena_x := 0.0
var player
var boss
var hud: CanvasLayer
var world: Node2D
var rng := RandomNumberGenerator.new()
var _cam: Camera2D
var _decor: Node2D
var _shake := 0.0


func _ready() -> void:
	index = Game.current_level
	data = Game.LEVELS[index]
	length = data["length"]
	scroll_speed = data["speed"]
	ceil_y = data.get("ceil", 20.0)
	rng.seed = int(data["seed"])
	seed(int(data["seed"]))  # so monster wiggles are the same each time too

	_cam = Camera2D.new()
	_cam.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(_cam)
	_cam.make_current()

	_decor = Decor.new()
	_decor.level = self
	add_child(_decor)
	world = Node2D.new()
	add_child(world)

	if data.get("boss", false):
		arena_x = length - VIEW_W
	else:
		finish_x = length - 260.0
	checkpoint_x = snappedf(length * 0.5, 10.0)
	_build()
	_decor.generate(str(data["theme"]), length, rng, index == 0)

	# Start from the checkpoint if we died after reaching it.
	if Game.checkpoint_level == index and Game.checkpoint_x > 0.0:
		cam_x = Game.checkpoint_x - 300.0
		checkpoint_reached = true
		for n in world.get_children():
			if n.position.x < cam_x + 500.0:
				n.queue_free()

	player = Player.new()
	player.level = self
	player.position = Vector2(cam_x + 220.0, 380.0)
	add_child(player)
	player.died.connect(_on_player_died)

	hud = Hud.new()
	hud.level = self
	add_child(hud)
	Music.play_track(str(data["music"]))
	_cam.position = Vector2(cam_x, 0)


func cam_left() -> float:
	return cam_x


# ---------------------------------------------------------------- building the level
func _build() -> void:
	var x := 1300.0 if index == 0 else 800.0
	var end := (arena_x - 400.0) if arena_x > 0.0 else (finish_x - 500.0)
	var patterns: Array = data["patterns"]
	var density: float = data["density"]
	var placed_checkpoint_heart := false
	while x < end:
		var pat: String = patterns[rng.randi() % patterns.size()]
		x += _place(pat, x)
		x += rng.randf_range(240.0, 400.0) / density
		if not placed_checkpoint_heart and x > checkpoint_x:
			placed_checkpoint_heart = true
			_pickup("heart", Vector2(checkpoint_x + 60.0, 420.0))
	# A row of coins leading to the finish (or to the boss)
	var lead := (arena_x - 300.0) if arena_x > 0.0 else (finish_x - 420.0)
	for i in 6:
		_pickup("coin", Vector2(lead + i * 50.0, 360.0 + sin(i * 0.9) * 40.0))


func _top() -> float:
	return ceil_y + 90.0


func _bottom() -> float:
	return ground_y - 90.0


## Places one chunk at x. Returns how wide it is.
func _place(pat: String, x: float) -> float:
	match pat:
		"coins":
			var n := rng.randi_range(5, 9)
			var y := rng.randf_range(_top(), _bottom())
			var wave := rng.randf() < 0.5
			for i in n:
				_pickup("coin", Vector2(x + i * 46.0, y + (sin(i * 0.8) * 50.0 if wave else 0.0)))
			if rng.randf() < 0.25:
				_pickup("big_coin", Vector2(x + n * 46.0 + 30.0, y))
			return n * 46.0 + 40.0
		"ground_spikes", "ceiling_spikes", "beat_spikes":
			var n2 := rng.randi_range(2, 5)
			var h = _hazard(pat, x)
			h.count = n2
			var w: float = h.width()
			# Coins in an arc over the spikes, as a reward for going over
			for i in 3:
				var cy := (ground_y - 150.0 - sin(i / 2.0 * PI) * 40.0) if pat != "ceiling_spikes" else (ceil_y + 150.0 + sin(i / 2.0 * PI) * 40.0)
				_pickup("coin", Vector2(x + w * (0.2 + i * 0.3), cy))
			return w
		"tower":
			var gap := 250.0
			var gc := rng.randf_range(_top() + gap * 0.3, _bottom() - gap * 0.3)
			var t = _hazard("column", x)
			t.gap_top = gc - gap * 0.5
			t.gap_bottom = gc + gap * 0.5
			_pickup("coin", Vector2(x + 35.0, gc))
			if rng.randf() < 0.3:
				_pickup("big_coin", Vector2(x + 140.0, gc))
			return 140.0
		"ball":
			var n3 := rng.randi_range(1, 2)
			for i in n3:
				var b = _hazard("ball", x + i * 160.0)
				b.base_y = rng.randf_range(_top() + 80.0, _bottom() - 80.0)
				b.position.y = b.base_y
				b.amp = rng.randf_range(80.0, 170.0)
				b.speed = rng.randf_range(1.0, 2.0)
			return n3 * 160.0
		"monster":
			var kinds: Array = data["monsters"]
			var n4 := rng.randi_range(1, int(data["max_group"]))
			for i in n4:
				var k: String = kinds[rng.randi() % kinds.size()]
				spawn_monster(k, Vector2(x + i * 110.0, rng.randf_range(_top(), _bottom())))
			return n4 * 110.0
		"pickup":
			_pickup("heart" if rng.randf() < 0.5 else "mana", Vector2(x, rng.randf_range(_top(), _bottom())))
			return 60.0
	return 100.0


func _hazard(kind: String, x: float):
	var h := Hazard.new()
	h.kind = kind
	h.level = self
	h.position = Vector2(x, 0)
	world.add_child(h)
	return h


func _pickup(kind: String, pos: Vector2) -> void:
	var p := Pickup.new()
	p.kind = kind
	p.level = self
	p.position = pos
	world.add_child(p)


func spawn_monster(kind: String, pos: Vector2) -> void:
	var m := Monster.new()
	m.setup(kind, float(data["hp_scale"]))
	m.level = self
	m.position = pos
	world.add_child(m)


func spawn_bullet(pos: Vector2, vel: Vector2, dmg: int, from_player: bool, kind: String, pierce: bool, on_beat: bool) -> void:
	var b := Bullet.new()
	b.level = self
	b.position = pos
	b.vel = vel
	b.dmg = dmg
	b.from_player = from_player
	b.kind = kind
	b.pierce = pierce
	b.on_beat = on_beat
	world.add_child(b)


func spawn_spell(kind: String, pos: Vector2) -> void:
	var s := SpellFx.new()
	s.kind = kind
	s.level = self
	s.position = pos
	world.add_child(s)


func fx_text(pos: Vector2, text: String, color: Color = Ink.INK, size: int = 30) -> void:
	var f := Fx.new()
	f.kind = "text"
	f.text = text
	f.color = color
	f.size = size
	f.position = pos
	world.add_child(f)


func fx_puff(pos: Vector2, color: Color, radius: float) -> void:
	var f := Fx.new()
	f.kind = "puff"
	f.color = color
	f.radius = radius
	f.life = 0.5
	f.position = pos
	world.add_child(f)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


# ---------------------------------------------------------------- every frame
func _physics_process(delta: float) -> void:
	match state:
		"intro":
			intro_t -= delta
			if intro_t <= 0.0:
				state = "play"
		"play":
			cam_x = minf(cam_x + scroll_speed * delta, length - VIEW_W)
			if not checkpoint_reached and player.position.x > checkpoint_x:
				checkpoint_reached = true
				Game.checkpoint_level = index
				Game.checkpoint_x = checkpoint_x
				fx_text(player.position + Vector2(0, -80), "Checkpoint!", Color(0.2, 0.5, 0.8), 36)
				Sfx.play("levelup", 0.0)
			if arena_x > 0.0 and cam_x >= arena_x:
				_start_boss()
			elif finish_x > 0.0 and player.position.x >= finish_x - 10.0:
				_complete()
	if state == "play" or state == "boss":
		_collide()
	_cleanup()
	_shake = move_toward(_shake, 0.0, delta * 30.0)
	var off := Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)) if _shake > 0.1 else Vector2.ZERO
	_cam.position = Vector2(cam_x, 0) + off


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and (state == "play" or state == "boss" or state == "intro"):
		hud.toggle_pause()


func _collide() -> void:
	var p: Vector2 = player.hit_center()
	var pr: float = player.HIT_RADIUS
	if not player.dead:
		for h in get_tree().get_nodes_in_group("hazard"):
			if h.touches(p, pr):
				player.hurt(1)
				break
		for m in get_tree().get_nodes_in_group("monster"):
			if m.alive and m.active and p.distance_to(m.position) < m.hit_radius() + pr * 0.8:
				player.hurt(1)
				break
		for b in get_tree().get_nodes_in_group("enemy_bullet"):
			if p.distance_to(b.position) < b.radius + pr * 0.8:
				player.hurt(1)
				b.queue_free()
		for c in get_tree().get_nodes_in_group("pickup"):
			if not c.is_queued_for_deletion() and p.distance_to(c.position) < c.radius + pr + 6.0:
				c.collect()
	var monsters := get_tree().get_nodes_in_group("monster")
	for b in get_tree().get_nodes_in_group("player_bullet"):
		if b.is_queued_for_deletion():
			continue
		for m in monsters:
			if not is_instance_valid(m) or not m.alive or not m.active or b.already_hit.has(m):
				continue
			if b.position.distance_to(m.position) < m.hit_radius() + b.radius:
				b.already_hit.append(m)
				m.take_damage(b.dmg, b.on_beat)
				if not b.pierce:
					b.queue_free()
					break


func _cleanup() -> void:
	var gone := cam_x - 300.0
	for n in world.get_children():
		if n.position.x < gone and not (n is SpellFx):
			n.queue_free()


# ---------------------------------------------------------------- events
func on_monster_killed(m) -> void:
	fx_puff(m.position, m.color, m.radius * 1.2)
	Sfx.play("pop", 0.15)
	xp_got += m.xp
	if Game.add_xp(m.xp):
		fx_text(player.position + Vector2(0, -100), "LEVEL UP! Lv %d" % Game.player_level, Color(0.85, 0.5, 0.0), 44)
		player.hp = Game.max_hearts()
		player.mana = float(Game.max_mana())
		Sfx.play("levelup", 0.0)
	if m.is_boss:
		_on_boss_killed(m)
		return
	for i in m.coins:
		_pickup("coin", m.position + Vector2(randf_range(-25, 25), randf_range(-25, 25)))


func _start_boss() -> void:
	state = "boss"
	boss = Boss.new()
	boss.setup_boss(int(data["boss_hp"]))
	boss.level = self
	boss.position = Vector2(cam_x + VIEW_W + 150.0, 340.0)
	world.add_child(boss)
	Music.play_track("boss")
	Sfx.play("boss", 0.0)
	fx_text(Vector2(cam_x + 640.0, 200.0), "KING GRUMBLE!", Color(0.6, 0.1, 0.1), 60)
	shake(12.0)


func _on_boss_killed(b) -> void:
	for i in 12:
		fx_puff(b.position + Vector2(randf_range(-90, 90), randf_range(-90, 90)), Color(0.6, 0.4, 0.8, 0.5), 90.0)
	shake(20.0)
	Game.add_coins(int(b.coins))
	coins_got += int(b.coins)
	for e in get_tree().get_nodes_in_group("enemy_bullet"):
		e.queue_free()
	for m in get_tree().get_nodes_in_group("monster"):
		if m != b:
			m.queue_free()
	_complete()


func _complete() -> void:
	if state == "done":
		return
	state = "done"
	var learned := Game.complete_level(index)
	Sfx.play("win", 0.0)
	if Game.smoke_autopilot:
		return
	hud.show_complete(learned)


func _on_player_died() -> void:
	state = "dead"
	await get_tree().create_timer(1.0).timeout
	hud.show_fail()
