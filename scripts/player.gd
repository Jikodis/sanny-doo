## The player: Sanny Doo flying through a level.
##
## Two ways to fly (pick on the title screen, so Sam can try both):
##   "free" : hold the arrows to fly anywhere. Space or X shoots.
##   "flap" : tap Space (or Up) to flap your wings; gravity pulls you down. X shoots.
extends Node2D

signal died

# ---- Feel values: change one number to change how it feels ----
const FREE_MAX_SPEED := 380.0   # free fly: top speed (pixels per second)
const FREE_ACCEL := 2600.0      # free fly: how fast you speed up and stop
const FLAP_GRAVITY := 1250.0    # flappy: how hard gravity pulls down
const FLAP_VELOCITY := -470.0   # flappy: how high one flap pushes you (negative = up)
const FLAP_MAX_FALL := 620.0    # flappy: fastest falling speed
const FLAP_SIDE_SPEED := 330.0  # flappy: left/right speed
const INVINCIBLE_TIME := 1.4    # seconds of blinking safety after getting hit
const HIT_RADIUS := 28.0        # smaller than the drawing on purpose (forgiving)
const HIT_OFFSET := Vector2(0, -10)
const BEAT_WINDOW := 0.11       # seconds before/after a beat that count as "on beat"
const MANA_REGEN := 0.45        # magic points refilled per second
const TELEPORT_DIST := 260.0

var level
var vel := Vector2.ZERO
var hp := 3
var mana := 4.0
var invincible := 0.0
var shoot_cd := 0.0
var beat_combo := 0
var god_mode := false
var dead := false
var puppet
var _auto_t := 0.0
var _auto_cast_t := 0.0


func _ready() -> void:
	hp = Game.max_hearts()
	mana = float(Game.max_mana())
	puppet = preload("res://scripts/sanny_puppet.gd").new()
	add_child(puppet)
	god_mode = Game.smoke_autopilot


func hit_center() -> Vector2:
	return position + HIT_OFFSET


func _physics_process(delta: float) -> void:
	if dead or level.state == "done":
		return
	if Game.smoke_autopilot:
		_autopilot(delta)
	elif Game.flight_mode == "flap":
		_flap_move(delta)
	else:
		_free_move(delta)
	position += vel * delta
	_stay_on_screen()

	invincible = maxf(0.0, invincible - delta)
	shoot_cd -= delta
	mana = minf(float(Game.max_mana()), mana + MANA_REGEN * delta)
	modulate.a = 0.35 if (invincible > 0.0 and int(invincible * 12.0) % 2 == 0) else 1.0
	rotation = clampf(vel.y / 1600.0, -0.25, 0.3)

	if level.state == "play" or level.state == "boss":
		_shooting()
		for i in 4:
			if Input.is_action_just_pressed("spell_%d" % (i + 1)):
				cast(Game.SPELL_ORDER[i])


func _free_move(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	vel = vel.move_toward(dir * FREE_MAX_SPEED, FREE_ACCEL * delta)
	puppet.flap_speed = 9.0 + dir.length() * 6.0


func _flap_move(delta: float) -> void:
	if Input.is_action_just_pressed("flap") or Input.is_action_just_pressed("move_up"):
		vel.y = FLAP_VELOCITY
		puppet.flap()
		Sfx.play("flap", 0.15)
	vel.y = minf(vel.y + FLAP_GRAVITY * delta, FLAP_MAX_FALL)
	vel.x = Input.get_axis("move_left", "move_right") * FLAP_SIDE_SPEED
	puppet.flap_speed = 7.0


## Used only by the automated test: fly up and down, shoot, cast magic.
func _autopilot(delta: float) -> void:
	_auto_t += delta
	var tx: float = level.cam_x + 260.0
	if level.finish_x > 0.0 and level.cam_x >= level.length - 1281.0:
		tx = level.finish_x + 20.0  # screen stopped: fly to the flag
	var target := Vector2(tx, 360.0 + sin(_auto_t * 1.3) * 200.0)
	vel = (target - position).limit_length(1.0) * FREE_MAX_SPEED if position.distance_to(target) > 8.0 else Vector2.ZERO
	if level.state == "play" or level.state == "boss":
		_auto_cast_t += delta
		if _auto_cast_t > 4.0:
			_auto_cast_t = 0.0
			mana = float(Game.max_mana())
			cast(Game.SPELL_ORDER[Game.smoke_casts % 4])
			Game.smoke_casts += 1


func _stay_on_screen() -> void:
	var left: float = level.cam_x + 50.0
	var right: float = level.cam_x + 1230.0
	position.x = clampf(position.x, left, right)
	var top: float = level.ceil_y + 45.0
	var bottom: float = level.ground_y - 50.0
	if position.y > bottom:
		position.y = bottom
		vel.y = minf(vel.y, 0.0)
	if position.y < top:
		position.y = top
		vel.y = maxf(vel.y, 0.0)


# ---------------------------------------------------------------- shooting
func _shooting() -> void:
	var free := Game.flight_mode == "free"
	var pressed := Input.is_action_just_pressed("shoot") or (free and Input.is_action_just_pressed("flap"))
	var held := Input.is_action_pressed("shoot") or (free and Input.is_action_pressed("flap"))
	if Game.smoke_autopilot:
		held = true
	var w: Dictionary = Game.weapon_data()
	var rate: float = w["rate"]
	# A fresh tap can fire a bit sooner than holding the button down.
	if pressed and shoot_cd < rate * 0.5:
		shoot_cd = 0.0
	if shoot_cd > 0.0 or not (pressed or held):
		return
	var on_beat := pressed and Music.beat_offset() <= BEAT_WINDOW
	shoot_cd = rate if pressed else rate * 1.3
	var dmg: int = int(w["dmg"]) + Game.attack_bonus()
	if on_beat:
		dmg *= 2
		beat_combo += 1
		mana = minf(float(Game.max_mana()), mana + 0.5)
		if beat_combo % 4 == 0:
			Game.add_coins(1)
			level.fx_text(position + Vector2(0, -80), "Beat combo x%d! +1 coin" % beat_combo, Color(0.85, 0.5, 0.0))
		else:
			level.fx_text(position + Vector2(0, -70), "ON BEAT! x2", Color(0.55, 0.2, 0.75))
		Sfx.play("beat", 0.0)
	else:
		if pressed:
			beat_combo = 0
		Sfx.play("shoot", 0.1)
	for s in w["shots"]:
		var dir := Vector2.RIGHT.rotated(float(s[0]))
		level.spawn_bullet(position + Vector2(44, -12 + float(s[1])), dir * float(w["speed"]), dmg, true, str(w["kind"]), bool(w["pierce"]), on_beat)


# ---------------------------------------------------------------- magic
func cast(id: String) -> void:
	if not Game.spells.has(id):
		level.fx_text(position + Vector2(0, -70), "You haven't learned that magic yet!", Ink_GRAY)
		Sfx.play("nope", 0.0)
		return
	var cost: float = Game.SPELLS[id]["cost"]
	if mana < cost:
		level.fx_text(position + Vector2(0, -70), "Not enough magic!", Ink_GRAY)
		Sfx.play("nope", 0.0)
		return
	mana -= cost
	match id:
		"heal":
			hp = mini(hp + 2, Game.max_hearts())
			level.fx_text(position + Vector2(0, -70), "+2 hearts!", Color(0.85, 0.15, 0.2))
			level.fx_puff(position, Color(1.0, 0.5, 0.6, 0.5), 70.0)
			Sfx.play("heal", 0.0)
		"poison":
			level.spawn_spell("poison", position + Vector2(90, 0))
			Sfx.play("spell", 0.0)
		"teleport":
			var dir := vel.normalized() if vel.length() > 40.0 else Vector2.RIGHT
			level.fx_puff(position, Color(0.6, 0.4, 0.9, 0.5), 60.0)
			position += dir * TELEPORT_DIST
			_stay_on_screen()
			invincible = maxf(invincible, 1.0)
			level.fx_puff(position, Color(0.6, 0.4, 0.9, 0.5), 60.0)
			Sfx.play("zap", 0.0)
		"flood":
			level.spawn_spell("flood", position)
			Sfx.play("splash", 0.0)


const Ink_GRAY := Color(0.35, 0.35, 0.4)


# ---------------------------------------------------------------- getting hurt
func hurt(amount: int = 1) -> void:
	if invincible > 0.0 or dead or god_mode:
		return
	if Game.armor >= 3 and randf() < 0.25:
		level.fx_text(position + Vector2(0, -70), "BLOCKED!", Color(0.3, 0.3, 0.45))
		invincible = 0.6
		Sfx.play("click", 0.0)
		return
	hp -= amount
	invincible = INVINCIBLE_TIME
	Sfx.play("hurt", 0.05)
	level.shake(10.0)
	if hp <= 0:
		hp = 0
		dead = true
		level.fx_puff(position, Color(0.3, 0.3, 0.4, 0.4), 90.0)
		visible = false
		died.emit()
