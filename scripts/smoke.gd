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
	get_tree().quit(0)
