## Sanny's House: the place between levels.
## Pick a level to fly to, and spend coins in the shop on weapons, armor,
## heart jars and magic jars. Shows Sanny's stats (the RPG part).
extends Control

const Ink = preload("res://scripts/ink.gd")
const Ui = preload("res://scripts/ui.gd")
const Puppet = preload("res://scripts/sanny_puppet.gd")

const HOUSE_SCALE := 0.56

var _house: Texture2D
var _sanny: Node2D
var _left: VBoxContainer
var _overlay: Control
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_house = load("res://assets/art/house.png")
	_sanny = Puppet.new()
	_sanny.position = Vector2(900, 600)
	_sanny.scale = Vector2.ONE * 1.1
	add_child(_sanny)
	Music.play_track("hub")
	_build_menu()
	if Game.just_won:
		Game.just_won = false
		_show_victory()


func _process(delta: float) -> void:
	_t += delta
	_sanny.position.y = 560.0 + sin(_t * 2.0) * 10.0
	queue_redraw()


func _draw() -> void:
	var hs := Vector2(_house.get_width(), _house.get_height()) * HOUSE_SCALE
	draw_texture_rect(_house, Rect2(Vector2(640 - hs.x * 0.45, 712 - hs.y), hs), false)
	Ink.line(self, Vector2(0, 712), Vector2(1280, 712), 3.0, Ink.INK, 1)
	Ink.text(self, Vector2(640, 64), "Sanny's House", 62)
	_draw_stats(Rect2(930, 110, 330, 300))


func _draw_stats(r: Rect2) -> void:
	Ink.rect(self, r, 3.0, Ink.INK, 50, Color(1, 1, 1, 0.7))
	var x := r.position.x + 18
	var y := r.position.y + 38
	Ink.text(self, Vector2(r.position.x + r.size.x * 0.5, y), "Sanny Doo  Lv %d" % Game.player_level, 32)
	y += 36
	Ink.text(self, Vector2(x, y), "XP: %d / %d" % [Game.xp, Game.xp_needed()], 24, Ink.INK, false)
	y += 30
	Ink.text(self, Vector2(x, y), "Hearts: %d    Magic: %d" % [Game.max_hearts(), Game.max_mana()], 24, Ink.INK, false)
	y += 30
	Ink.text(self, Vector2(x, y), "Coins: %d" % Game.coins, 24, Ink.INK, false)
	y += 30
	Ink.text(self, Vector2(x, y), "Weapon: %s" % Game.weapon_data()["name"], 24, Ink.INK, false)
	y += 30
	Ink.text(self, Vector2(x, y), "Armor: %s" % Game.ARMORS[Game.armor]["name"], 24, Ink.INK, false)
	y += 30
	var names := []
	for id in Game.SPELL_ORDER:
		if Game.spells.has(id):
			names.append(Game.SPELLS[id]["name"])
	Ink.text(self, Vector2(x, y), "Magic: %s" % (", ".join(names) if names.size() > 0 else "none yet"), 22, Ink.INK, false)


func _build_menu() -> void:
	_left = VBoxContainer.new()
	_left.position = Vector2(24, 110)
	_left.add_theme_constant_override("separation", 8)
	add_child(_left)
	_left.add_child(Ui.label("Fly to...", 34))
	var first: Button = null
	for i in Game.LEVELS.size():
		var lv: Dictionary = Game.LEVELS[i]
		var open := i < Game.unlocked
		var label := "%d. %s" % [i + 1, lv["name"]] if open else "%d. ???" % (i + 1)
		var b = Ui.button(label, func(): Game.start_level(i), Vector2(340, 52))
		b.font_size = 26
		b.disabled = not open
		_left.add_child(b)
		if open:
			first = b
	var shop = Ui.button("Shop", _show_shop, Vector2(340, 52))
	_left.add_child(shop)
	_left.add_child(Ui.button("Title screen", Game.goto_title, Vector2(340, 52)))
	if first:
		first.grab_focus.call_deferred()


# ---------------------------------------------------------------- shop
func _show_shop() -> void:
	_close_overlay()
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var v := Ui.panel(_overlay, Vector2(860, 620), "Shop")
	v.add_child(Ui.label("You have %d coins" % Game.coins, 30, Color(0.7, 0.45, 0.0)))
	var first: Button = null
	for item in ["weapon", "armor", "heart", "mana"]:
		var b := _shop_row(v, item)
		if first == null and not b.disabled:
			first = b
	var back = Ui.button("Back", _close_overlay)
	Ui.row(v, [back])
	(first if first else back).grab_focus.call_deferred()


func _shop_row(v: VBoxContainer, item: String) -> Button:
	var price := Game.next_price(item)
	var title := ""
	var desc := ""
	match item:
		"weapon":
			if price >= 0:
				var w: Dictionary = Game.WEAPONS[Game.weapon + 1]
				title = w["name"]
				desc = w["desc"]
			else:
				title = "Best weapon!"
		"armor":
			if price >= 0:
				var a: Dictionary = Game.ARMORS[Game.armor + 1]
				title = a["name"]
				desc = a["desc"]
			else:
				title = "Best armor!"
		"heart":
			title = "Heart Jar"
			desc = "+1 heart, forever." if price >= 0 else "All heart jars bought!"
		"mana":
			title = "Magic Jar"
			desc = "+2 magic, forever." if price >= 0 else "All magic jars bought!"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var info := Ui.label("%s: %s" % [title, desc] if desc != "" else title, 26)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info.custom_minimum_size = Vector2(560, 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var b = Ui.button("Buy  %d" % price if price >= 0 else "Sold out", func(): _buy(item), Vector2(200, 56))
	b.disabled = price < 0 or Game.coins < price
	row.add_child(b)
	v.add_child(row)
	return b


func _buy(item: String) -> void:
	if Game.buy(item):
		Sfx.play("coin", 0.0)
	else:
		Sfx.play("nope", 0.0)
	_show_shop()


func _close_overlay() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null
		for c in _left.get_children():
			if c is Button and not c.disabled:
				c.grab_focus.call_deferred()
				break


func _show_victory() -> void:
	_close_overlay()
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var v := Ui.panel(_overlay, Vector2(760, 440), "The End... for now!")
	v.add_child(Ui.label("King Grumble is beaten and Sanny Doo is home safe.", 30))
	v.add_child(Ui.label("Fly any level again to collect more coins and get even stronger.", 26))
	var ok = Ui.button("Yay!", _close_overlay)
	Ui.row(v, [ok])
	ok.grab_focus.call_deferred()
	Sfx.play("win", 0.0)
