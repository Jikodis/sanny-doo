## Automated checks, started from the command line (never in normal play).
##
##   --smoke : plays the whole game by itself, headless and fast:
##             buys every upgrade, flies all 5 levels on autopilot (casting
##             every spell), beats the boss, then saves and reloads.
##             Prints SMOKE PASS or SMOKE FAIL and quits with code 0 or 1.
##   --shots : opens each screen in a real window and saves screenshots
##             into the folder given by --out=<folder>.
##
## Examples (from the project folder):
##   Godot --headless --path . --fixed-fps 60 -- --smoke
##   Godot --path . -- --shots --out=/tmp/sanny-shots
extends Node

var _fails: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_fails.append(what)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if "--shots" in args:
		await _shots(args)
	else:
		await _smoke()


func _smoke() -> void:
	print("SMOKE: start")
	Game.new_game()
	await _frames(5)
	await _player_paths()
	Game.new_game()
	Game.last_completed = -1
	get_tree().change_scene_to_file("res://scenes/title.tscn")
	await _frames(10)
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
	await _frames(10)
	Game.coins = 5000
	for i in 4:
		for item in ["weapon", "armor", "heart", "mana"]:
			Game.buy(item)
	_check(Game.weapon == 3 and Game.armor == 3 and Game.heart_jars == 3 and Game.mana_jars == 2, "shop: bought every upgrade")
	Game.coins = 0
	Game.spells = Game.SPELL_ORDER.duplicate()
	Game.smoke_autopilot = true
	for lvl in Game.LEVELS.size():
		Game.start_level(lvl)
		var frames := 0
		while Game.last_completed != lvl and frames < 30000:
			await get_tree().process_frame
			frames += 1
		_check(Game.last_completed == lvl, "level %d (%s) finished in %d frames" % [lvl + 1, Game.LEVELS[lvl]["name"], frames])
	_check(Game.boss_beaten, "boss beaten")
	_check(Game.smoke_casts >= 8, "cast spells %d times (all four kinds)" % Game.smoke_casts)
	_check(Game.player_level > 1, "gained RPG levels (now Lv %d)" % Game.player_level)
	_check(Game.coins > 0, "collected coins (%d)" % Game.coins)
	var coins_before := Game.coins
	Game.save_game()
	Game.coins = -1
	Game.load_game()
	_check(Game.coins == coins_before, "save and reload keeps coins")
	Game.smoke_autopilot = false
	print("SMOKE PASS" if _fails.is_empty() else "SMOKE FAIL: %s" % ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)


# ---------------------------------------------------------------- helpers for real-player paths
func _key(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)


func _tap(code: Key) -> void:
	_key(code, true)
	await _frames(2)
	_key(code, false)
	await _frames(1)


## Finds a pen button by its text anywhere under node.
func _button(node: Node, text: String):
	if "label" in node and str(node.get("label")).begins_with(text) and node is Button:
		return node
	for c in node.get_children():
		var found = _button(c, text)
		if found:
			return found
	return null


func _has_label(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text.contains(text):
		return true
	for c in node.get_children():
		if _has_label(c, text):
			return true
	return false


func _wait_for_level(index: int) -> Variant:
	for i in 60:
		await _frames(1)
		var sc = get_tree().current_scene
		if sc and "index" in sc and sc.index == index and sc.player != null:
			return sc
	return null


## Game pixels (1280x720) to window pixels, like a real finger on the glass.
func _to_window(pos: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * pos


func _touch(finger: int, pos: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = finger
	e.position = _to_window(pos)
	e.pressed = down
	Input.parse_input_event(e)


func _drag(finger: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = finger
	e.position = _to_window(pos)
	Input.parse_input_event(e)


## Phone controls: slide to fly, SHOOT button, magic boxes, pause button.
## scale = window size / game size (to check touches are mapped to game pixels).
func _touch_paths(lv, scale: float) -> void:
	var p = lv.player
	p.position = Vector2(lv.cam_x + 300.0, 360.0)
	var x0: float = p.position.x - lv.cam_x
	_touch(0, Vector2(300, 400) * scale, true)
	await _frames(2)
	_drag(0, Vector2(400, 400) * scale)
	await get_tree().create_timer(0.5).timeout
	_check(p.position.x - lv.cam_x > x0 + 60.0, "touch: sliding right flies right (%.0f px)" % (p.position.x - lv.cam_x - x0))
	_touch(0, Vector2(380, 400) * scale, false)
	await _frames(2)
	_check(not Input.is_action_pressed("move_right"), "touch: letting go stops")
	for b in get_tree().get_nodes_in_group("player_bullet"):
		b.queue_free()
	await _frames(1)
	_touch(1, Vector2(1150, 520) * scale, true)
	await _frames(10)
	_check(get_tree().get_nodes_in_group("player_bullet").size() > 0, "touch: SHOOT button shoots")
	_touch(1, Vector2(1150, 520) * scale, false)
	p.mana = 99.0
	p.hp = 1
	_touch(2, Vector2(60, 670) * scale, true)
	await _frames(2)
	_touch(2, Vector2(60, 670) * scale, false)
	await _frames(2)
	_check(p.hp == 3, "touch: tapping magic box 1 casts Heal")
	_touch(3, Vector2(1236, 122) * scale, true)
	await _frames(2)
	_touch(3, Vector2(1236, 122) * scale, false)
	_check(get_tree().paused, "touch: pause button pauses")
	lv.hud.toggle_pause()
	await _frames(2)


## The paths a real player takes, using real key presses and real buttons.
func _player_paths() -> void:
	print("SMOKE: player paths")
	Game.spells = Game.SPELL_ORDER.duplicate()
	# Flappy: a real Space press makes Sanny flap upward.
	Game.flight_mode = "flap"
	Game.start_level(0)
	var lv = await _wait_for_level(0)
	_check(lv != null, "level 1 loads")
	lv.intro_t = 0.0
	await _frames(30)
	_key(KEY_SPACE, true)
	await _frames(2)
	_check(lv.player.vel.y < 0.0, "flappy: Space key flaps up (vel.y %.0f)" % lv.player.vel.y)
	_key(KEY_SPACE, false)
	# Free fly: holding the right arrow moves right.
	Game.flight_mode = "free"
	lv.player.position.x = lv.cam_x + 220.0
	var x0: float = lv.player.position.x - lv.cam_x
	_key(KEY_RIGHT, true)
	await _frames(40)
	_key(KEY_RIGHT, false)
	_check(lv.player.position.x - lv.cam_x > x0 + 60.0, "free fly: right arrow moves right (%.0f px)" % (lv.player.position.x - lv.cam_x - x0))
	# Shooting with X makes a shot.
	_key(KEY_X, true)
	await _frames(2)
	_key(KEY_X, false)
	_check(get_tree().get_nodes_in_group("player_bullet").size() > 0, "X key shoots")
	# Each spell does its job.
	var p = lv.player
	p.mana = 99.0
	p.hp = 1
	p.cast("heal")
	_check(p.hp == 3, "heal gives +2 hearts")
	p.cast("poison")
	await _frames(1)
	var clouds := 0
	for n in lv.world.get_children():
		if "kind" in n and n.kind == "poison" and n.has_method("_front_x"):
			clouds += 1
	_check(clouds == 1, "poison makes a cloud")
	p.position = Vector2(lv.cam_x + 200.0, 360.0)
	p.vel = Vector2.ZERO
	p.cast("teleport")
	_check(p.position.x - lv.cam_x > 400.0, "teleport moves Sanny ahead")
	lv.spawn_monster("blob", Vector2(lv.cam_x + 900.0, 300.0))
	await _frames(2)
	p.cast("flood")
	await _frames(120)
	var blobs_left := 0
	for m in get_tree().get_nodes_in_group("monster"):
		if m.position.x > lv.cam_x + 700.0 and m.position.x < lv.cam_x + 1000.0:
			blobs_left += 1
	_check(blobs_left == 0, "flood washes away a monster")
	Game.force_touch = true
	lv.touch.visible = true
	await _touch_paths(lv, 1.0)
	# Pause with Esc, switch flying style with the button.
	await _tap(KEY_ESCAPE)
	_check(get_tree().paused, "Esc pauses")
	var sw = _button(lv.hud, "Switch flying style")
	_check(sw != null, "pause menu has the switch button")
	if sw:
		sw.pressed.emit()
	await _frames(2)
	_check(not get_tree().paused and Game.flight_mode == "flap", "switch style unpauses and changes to flappy")
	await _tap(KEY_ESCAPE)
	await _tap(KEY_ESCAPE)
	_check(not get_tree().paused, "Esc twice pauses and unpauses")
	Game.flight_mode = "free"
	# Pass the checkpoint, then die: Try again starts at the checkpoint.
	lv.cam_x = lv.checkpoint_x - 600.0
	lv.player.position = Vector2(lv.checkpoint_x + 10.0, 360.0)
	await _frames(3)
	_check(Game.checkpoint_level == 0, "checkpoint reached")
	for i in 20:
		lv.player.invincible = 0.0
		lv.player.hurt(1)
	await _frames(150)
	var again = _button(lv.hud, "Try again")
	_check(again != null and not again.disabled, "fail panel shows Try again")
	if again:
		again.pressed.emit()
	lv = await _wait_for_level(0)
	_check(lv != null and absf(lv.cam_x - (Game.checkpoint_x - 300.0)) < 1.0 and not lv.player.dead, "retry restarts alive at the checkpoint")
	Game.spells.erase("heal")  # so finishing level 1 teaches it again
	# Finish the level: tapping Space at the finish must not skip the panel.
	lv.intro_t = 0.0
	await _frames(2)
	lv.cam_x = lv.length - 1280.0
	lv.player.position = Vector2(lv.finish_x + 5.0, 360.0)
	await _frames(2)
	_check(lv.state == "done", "reaching the flag finishes the level")
	for i in 5:
		await _tap(KEY_SPACE)
		await _tap(KEY_ENTER)
	_check(get_tree().current_scene == lv, "Space/Enter taps do not skip the complete panel")
	_check(_has_label(lv.hud, "New magic learned: Heal"), "complete panel says Heal was learned")
	await _frames(40)
	var next = _button(lv.hud, "Next level")
	_check(next != null and not next.disabled, "Next level button works after a moment")
	if next:
		next.pressed.emit()
	var lv2 = await _wait_for_level(1)
	_check(lv2 != null, "Next level loads level 2")
	# Shop through the real buttons.
	Game.coins = 100
	Game.goto_hub()
	await _frames(5)
	var hub = get_tree().current_scene
	var shop_b = _button(hub, "Shop")
	if shop_b:
		shop_b.pressed.emit()
	await _frames(2)
	var buy = _button(hub, "Buy  25")
	_check(buy != null and not buy.disabled, "shop shows the Ink Blaster for 25")
	if buy:
		buy.pressed.emit()
	await _frames(2)
	_check(Game.weapon == 1 and Game.coins == 75, "buying with the button works")
	# Victory screen after the boss.
	Game.just_won = true
	Game.goto_hub()
	await _frames(5)
	_check(_has_label(get_tree().current_scene, "The End"), "victory message shows at the house")
	Game.just_won = false


func _shot(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(name + ".png"))
	print("shot ", name)


func _shots(args: PackedStringArray) -> void:
	var dir := "user://shots"
	for a in args:
		if a.begins_with("--out="):
			dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(dir)
	if "--touchcheck" in args:
		# Window is smaller than the game here, so this checks touch scaling.
		Game.force_touch = true
		Game.new_game()
		Game.spells = ["heal"]
		Game.start_level(0)
		await _frames(10)
		var tl = get_tree().current_scene
		tl.intro_t = 0.0
		tl.player.god_mode = true
		await _frames(5)
		var sc := 1.0
		print("window ", DisplayServer.window_get_size(), " transform ", get_tree().root.get_final_transform())
		await _touch_paths(tl, sc)
		_touch(0, Vector2(300, 400) * sc, true)
		_drag(0, Vector2(350, 360) * sc)
		_touch(1, Vector2(1150, 520) * sc, true)
		await _frames(10)
		await _shot(dir, "40_touch_controls")
		print("TOUCHCHECK PASS" if _fails.is_empty() else "TOUCHCHECK FAIL: %s" % ", ".join(_fails))
		get_tree().quit(0)
		return
	get_tree().change_scene_to_file("res://scenes/title.tscn")
	await _frames(30)
	await _shot(dir, "01_title")
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
	await _frames(20)
	await _shot(dir, "02_hub")
	var hub = get_tree().current_scene
	hub._show_shop()
	await _frames(10)
	await _shot(dir, "03_shop")
	Game.spells = ["heal", "poison"]
	for lvl in [0, 1, 2, 3]:
		Game.start_level(lvl)
		await _frames(30)
		await _shot(dir, "1%d_level%d_intro" % [lvl, lvl + 1])
		var level = get_tree().current_scene
		level.player.god_mode = true
		await _frames(240)
		await _shot(dir, "1%d_level%d_play" % [lvl, lvl + 1])
	# Jump straight to the boss arena
	Game.armor = 2
	Game.start_level(4)
	await _frames(10)
	var lv = get_tree().current_scene
	lv.player.god_mode = true
	lv.state = "play"
	lv.cam_x = lv.arena_x - 20.0
	lv.player.position.x = lv.cam_x + 250.0
	await _frames(200)
	await _shot(dir, "20_boss")
	lv.player.cast("poison")
	await _frames(20)
	await _shot(dir, "21_boss_poison")
	# Stormy Sky with the best gear: beat-spikes, Thunder Pen, Knight Armor, Flood
	Game.armor = 3
	Game.weapon = 3
	Game.spells = Game.SPELL_ORDER.duplicate()
	Game.start_level(3)
	await _frames(5)
	var sky = get_tree().current_scene
	sky.intro_t = 0.0
	sky.player.god_mode = true
	for h in get_tree().get_nodes_in_group("hazard"):
		if h.kind == "beat_spikes":
			sky.cam_x = h.position.x - 700.0
			break
	sky.player.position = Vector2(sky.cam_x + 250.0, 400.0)
	_key(KEY_X, true)
	await _frames(25)
	await _shot(dir, "30_sky_thunder_beatspikes")
	_key(KEY_X, false)
	sky.player.mana = 99.0
	sky.player.cast("flood")
	await _frames(40)
	await _shot(dir, "31_flood")
	await _tap(KEY_ESCAPE)
	await _frames(5)
	await _shot(dir, "32_pause")
	await _tap(KEY_ESCAPE)
	sky.cam_x = sky.length - 1280.0
	sky.player.position = Vector2(sky.cam_x + 300.0, 400.0)
	await _frames(10)
	await _shot(dir, "33_finish_flag")
	Game.spells.erase("flood")
	sky.player.position = Vector2(sky.finish_x + 5.0, 400.0)
	await _frames(70)
	await _shot(dir, "34_complete_panel")
	# Cardboard armor, Ink Blaster, then the fail panel
	Game.armor = 1
	Game.weapon = 1
	Game.start_level(1)
	await _frames(5)
	var fl = get_tree().current_scene
	fl.intro_t = 0.0
	await _frames(30)
	_key(KEY_X, true)
	await _frames(20)
	await _shot(dir, "35_cardboard_inkblaster")
	_key(KEY_X, false)
	for i in 20:
		fl.player.invincible = 0.0
		fl.player.hurt(1)
	await _frames(150)
	await _shot(dir, "36_fail_panel")
	Game.weapon = 2
	Game.start_level(0)
	await _frames(5)
	var l0 = get_tree().current_scene
	l0.intro_t = 0.0
	await _frames(30)
	_key(KEY_X, true)
	await _frames(20)
	await _shot(dir, "37_star_wand")
	_key(KEY_X, false)
	get_tree().quit(0)
