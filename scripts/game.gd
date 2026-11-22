## Game: the shared state that survives scene changes (an autoload).
## Coins, upgrades, magic, the RPG level, which levels are unlocked, and the save file.
## All the "catalog" data (weapons, armor, spells, levels) lives here too, so
## tuning prices or levels means changing numbers in one place.
extends Node

signal coins_changed
signal xp_changed
signal leveled_up(new_level: int)

const Ink = preload("res://scripts/ink.gd")
var SAVE_PATH := "user://sanny_doo_save.json"  # the tests use their own file

# ---------------------------------------------------------------- catalogs
# shots: a list of [angle (radians), up/down offset] for each bullet per shot.
const WEAPONS := [
	{"name": "Pencil Darts", "cost": 0, "dmg": 1, "rate": 0.26, "speed": 760.0, "kind": "dart", "pierce": false,
		"shots": [[0.0, 0.0]], "desc": "Sharp pencils. Pew!"},
	{"name": "Ink Blaster", "cost": 25, "dmg": 1, "rate": 0.22, "speed": 800.0, "kind": "ink", "pierce": false,
		"shots": [[0.0, -12.0], [0.0, 12.0]], "desc": "Shoots two ink blobs at once."},
	{"name": "Star Wand", "cost": 60, "dmg": 2, "rate": 0.24, "speed": 720.0, "kind": "star", "pierce": false,
		"shots": [[-0.16, 0.0], [0.0, 0.0], [0.16, 0.0]], "desc": "Three stars that spread out."},
	{"name": "Thunder Pen", "cost": 120, "dmg": 3, "rate": 0.26, "speed": 950.0, "kind": "bolt", "pierce": true,
		"shots": [[-0.08, 0.0], [0.0, 0.0], [0.08, 0.0]], "desc": "Lightning that zaps through monsters."},
]

const ARMORS := [
	{"name": "No Armor", "cost": 0, "hearts": 0, "desc": ""},
	{"name": "Cardboard Armor", "cost": 20, "hearts": 1, "desc": "+1 heart. Made from a box!"},
	{"name": "Pot Helmet", "cost": 50, "hearts": 2, "desc": "+2 hearts. Clang!"},
	{"name": "Knight Armor", "cost": 100, "hearts": 3, "desc": "+3 hearts, and blocks some hits."},
]

const HEART_JAR_COSTS := [30, 60, 90]  # each jar = +1 max heart
const MANA_JAR_COSTS := [30, 60]       # each jar = +2 max magic

# Magic Sanny Doo learns by finishing levels. Keys 1 to 4 cast them.
const SPELL_ORDER := ["heal", "poison", "teleport", "flood"]
const SPELLS := {
	"heal": {"name": "Heal", "cost": 3, "desc": "Get 2 hearts back."},
	"poison": {"name": "Poison Cloud", "cost": 3, "desc": "A green cloud that hurts monsters inside it."},
	"teleport": {"name": "Teleport", "cost": 2, "desc": "Zap ahead and dodge danger."},
	"flood": {"name": "Flood", "cost": 6, "desc": "A huge wave washes away monsters and spike balls."},
}

# Levels. patterns = which chunks the level is built from (repeats = more often).
# length is in pixels; speed is how fast the screen scrolls (pixels per second).
const LEVELS := [
	{"name": "Home Sweet Home", "theme": "home", "length": 7000.0, "speed": 150.0, "seed": 101,
		"density": 0.9, "monsters": ["blob"], "max_group": 2, "hp_scale": 1.0, "music": "home", "spell": "heal",
		"patterns": ["coins", "coins", "ground_spikes", "monster", "monster", "ball", "coins", "pickup"]},
	{"name": "Tall Tree Forest", "theme": "forest", "length": 8200.0, "speed": 160.0, "seed": 202,
		"density": 1.0, "monsters": ["blob", "bat"], "max_group": 3, "hp_scale": 1.2, "music": "forest", "spell": "poison",
		"patterns": ["coins", "tower", "tower", "monster", "monster", "ground_spikes", "ball", "pickup"]},
	{"name": "Spiky Caves", "theme": "cave", "ceil": 90.0, "length": 8800.0, "speed": 165.0, "seed": 303,
		"density": 1.05, "monsters": ["bat", "spitter"], "max_group": 3, "hp_scale": 1.5, "music": "cave", "spell": "teleport",
		"patterns": ["coins", "ground_spikes", "ceiling_spikes", "tower", "ball", "monster", "monster", "pickup"]},
	{"name": "Stormy Sky", "theme": "sky", "length": 9200.0, "speed": 175.0, "seed": 404,
		"density": 1.1, "monsters": ["bat", "spitter", "spiky"], "max_group": 3, "hp_scale": 1.8, "music": "sky", "spell": "flood",
		"patterns": ["coins", "beat_spikes", "beat_spikes", "tower", "ball", "monster", "monster", "monster", "pickup"]},
	{"name": "King Grumble's Castle", "theme": "castle", "length": 5600.0, "speed": 170.0, "seed": 505,
		"density": 1.0, "monsters": ["spitter", "spiky", "bat"], "max_group": 2, "hp_scale": 2.0, "music": "castle",
		"boss": true, "boss_hp": 300, "spell": "",
		"patterns": ["coins", "beat_spikes", "tower", "monster", "monster", "ball", "pickup"]},
]

# ---------------------------------------------------------------- saved state
var coins := 0
var xp := 0
var player_level := 1
var weapon := 0
var armor := 0
var heart_jars := 0
var mana_jars := 0
var spells: Array = []
var unlocked := 1         # how many levels can be played
var boss_beaten := false
var flight_mode := "free"  # "free" (hold arrows to fly anywhere) or "flap" (tap to flap, gravity pulls down)

# ---------------------------------------------------------------- not saved
var current_level := 0
var checkpoint_level := -1
var checkpoint_x := 0.0
var last_completed := -1
var just_won := false
var smoke_autopilot := false  # the automated test flies Sanny by itself
var smoke_casts := 0
var font: Font
var _boil_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = load("res://assets/fonts/PatrickHand-Regular.ttf")
	_setup_input()
	var test_args := OS.get_cmdline_user_args()
	if "--smoke" in test_args or "--shots" in test_args:
		SAVE_PATH = "user://sanny_doo_test_save.json"
	load_game()
	var args := OS.get_cmdline_user_args()
	if "--smoke" in args or "--shots" in args:
		add_child(preload("res://scripts/smoke.gd").new())


func _process(delta: float) -> void:
	# Make every pen line wobble a little, about 7 times a second.
	_boil_t += delta
	if _boil_t > 0.14:
		_boil_t = 0.0
		Ink.boil += 1


# ---------------------------------------------------------------- stats
func max_hearts() -> int:
	return 3 + int(ARMORS[armor]["hearts"]) + heart_jars + (player_level - 1) / 2


func max_mana() -> int:
	return 4 + mana_jars * 2 + (player_level - 1)


func attack_bonus() -> int:
	return (player_level - 1) / 3


func xp_needed() -> int:
	return 10 + (player_level - 1) * 8


func weapon_data() -> Dictionary:
	return WEAPONS[weapon]


## Adds experience. Returns true if Sanny leveled up.
func add_xp(n: int) -> bool:
	xp += n
	var up := false
	while xp >= xp_needed():
		xp -= xp_needed()
		player_level += 1
		up = true
		leveled_up.emit(player_level)
	xp_changed.emit()
	return up


func add_coins(n: int) -> void:
	coins += n
	coins_changed.emit()


# ---------------------------------------------------------------- shop
## Price of the next upgrade of this kind, or -1 if it is maxed out.
func next_price(item: String) -> int:
	match item:
		"weapon":
			return int(WEAPONS[weapon + 1]["cost"]) if weapon + 1 < WEAPONS.size() else -1
		"armor":
			return int(ARMORS[armor + 1]["cost"]) if armor + 1 < ARMORS.size() else -1
		"heart":
			return int(HEART_JAR_COSTS[heart_jars]) if heart_jars < HEART_JAR_COSTS.size() else -1
		"mana":
			return int(MANA_JAR_COSTS[mana_jars]) if mana_jars < MANA_JAR_COSTS.size() else -1
	return -1


func buy(item: String) -> bool:
	var price := next_price(item)
	if price < 0 or coins < price:
		return false
	coins -= price
	match item:
		"weapon":
			weapon += 1
		"armor":
			armor += 1
		"heart":
			heart_jars += 1
		"mana":
			mana_jars += 1
	coins_changed.emit()
	save_game()
	return true


# ---------------------------------------------------------------- flow
func new_game() -> void:
	coins = 0
	xp = 0
	player_level = 1
	weapon = 0
	armor = 0
	heart_jars = 0
	mana_jars = 0
	spells = []
	unlocked = 1
	boss_beaten = false
	checkpoint_level = -1
	save_game()


func start_level(i: int) -> void:
	current_level = i
	if checkpoint_level != i:
		checkpoint_x = 0.0
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred("res://scenes/level.tscn")


## Called when a level is finished. Returns the id of a newly learned spell, or "".
func complete_level(i: int) -> String:
	last_completed = i
	checkpoint_level = -1
	checkpoint_x = 0.0
	unlocked = maxi(unlocked, mini(i + 2, LEVELS.size()))
	var learned := ""
	var spell: String = LEVELS[i].get("spell", "")
	if spell != "" and not spells.has(spell):
		spells.append(spell)
		learned = spell
	if LEVELS[i].get("boss", false):
		boss_beaten = true
		just_won = true
	save_game()
	return learned


func goto_hub() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred("res://scenes/hub.tscn")


func goto_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred("res://scenes/title.tscn")


# ---------------------------------------------------------------- save file
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var data := {
		"coins": coins, "xp": xp, "player_level": player_level, "weapon": weapon, "armor": armor,
		"heart_jars": heart_jars, "mana_jars": mana_jars, "spells": spells, "unlocked": unlocked,
		"boss_beaten": boss_beaten, "flight_mode": flight_mode,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> void:
	if not has_save():
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	coins = int(data.get("coins", 0))
	xp = int(data.get("xp", 0))
	player_level = int(data.get("player_level", 1))
	weapon = clampi(int(data.get("weapon", 0)), 0, WEAPONS.size() - 1)
	armor = clampi(int(data.get("armor", 0)), 0, ARMORS.size() - 1)
	heart_jars = int(data.get("heart_jars", 0))
	mana_jars = int(data.get("mana_jars", 0))
	spells = Array(data.get("spells", []))
	unlocked = clampi(int(data.get("unlocked", 1)), 1, LEVELS.size())
	boss_beaten = bool(data.get("boss_beaten", false))
	flight_mode = str(data.get("flight_mode", "free"))


# ---------------------------------------------------------------- controls
## Controls are set up here in code (instead of Project Settings) so they are
## easy to read and change. Keyboard and gamepad both work.
func _setup_input() -> void:
	_action("move_left", [KEY_LEFT, KEY_A], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_action("move_right", [KEY_RIGHT, KEY_D], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_action("move_up", [KEY_UP, KEY_W], [JOY_BUTTON_DPAD_UP], [[JOY_AXIS_LEFT_Y, -1.0]])
	_action("move_down", [KEY_DOWN, KEY_S], [JOY_BUTTON_DPAD_DOWN], [[JOY_AXIS_LEFT_Y, 1.0]])
	_action("flap", [KEY_SPACE], [JOY_BUTTON_A], [])
	_action("shoot", [KEY_X, KEY_J, KEY_Z], [JOY_BUTTON_X], [])
	_action("spell_1", [KEY_1], [JOY_BUTTON_LEFT_SHOULDER], [])
	_action("spell_2", [KEY_2], [JOY_BUTTON_RIGHT_SHOULDER], [])
	_action("spell_3", [KEY_3], [JOY_BUTTON_Y], [])
	_action("spell_4", [KEY_4], [JOY_BUTTON_B], [])
	_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START], [])


func _action(action_name: String, keys: Array, buttons: Array, axes: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.4)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action_name, e)
	for b in buttons:
		var j := InputEventJoypadButton.new()
		j.button_index = b
		InputMap.action_add_event(action_name, j)
	for a in axes:
		var m := InputEventJoypadMotion.new()
		m.axis = a[0]
		m.axis_value = a[1]
		InputMap.action_add_event(action_name, m)
