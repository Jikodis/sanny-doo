## The HUD: hearts, magic, coins, level and XP, the beat circle, magic slots,
## the boss health bar, and the pause / level-complete / try-again panels.
extends CanvasLayer

const Ink = preload("res://scripts/ink.gd")
const Ui = preload("res://scripts/ui.gd")

var level
var _draw_node: Control
var _panel_root: Control


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_draw_node = HudDraw.new()
	_draw_node.hud = self
	_draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_draw_node)


func _process(_delta: float) -> void:
	_draw_node.queue_redraw()


## Esc/P pauses and unpauses. This lives in the HUD because the HUD keeps
## running while the game is paused (the level does not).
func _unhandled_input(event: InputEvent) -> void:
	var st: String = level.state
	if event.is_action_pressed("pause") and (st == "play" or st == "boss" or st == "intro"):
		get_viewport().set_input_as_handled()
		toggle_pause()


# ---------------------------------------------------------------- panels
func _clear_panel() -> void:
	if _panel_root:
		_panel_root.queue_free()
		_panel_root = null


func _new_panel_root() -> Control:
	_clear_panel()
	_panel_root = Control.new()
	_panel_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.95, 0.93, 0.87, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_root.add_child(dim)
	add_child(_panel_root)
	return _panel_root


func toggle_pause() -> void:
	if get_tree().paused:
		get_tree().paused = false
		_clear_panel()
		return
	get_tree().paused = true
	var v := Ui.panel(_new_panel_root(), Vector2(560, 470), "Paused")
	v.add_child(Ui.label("Flying style: %s" % ("Free Fly" if Game.flight_mode == "free" else "Flappy"), 26))
	var resume = Ui.button("Keep flying", toggle_pause)
	v.add_child(resume)
	v.add_child(Ui.button("Switch flying style", _switch_style))
	v.add_child(Ui.button("Back to the house", Game.goto_hub))
	resume.grab_focus.call_deferred()


func _switch_style() -> void:
	Game.flight_mode = "flap" if Game.flight_mode == "free" else "free"
	Game.save_game()
	toggle_pause()


func show_complete(learned: String) -> void:
	var is_boss: bool = level.data.get("boss", false)
	var v := Ui.panel(_new_panel_root(), Vector2(700, 520), "You beat King Grumble!" if is_boss else "Level complete!")
	v.add_child(Ui.label("Coins: +%d     XP: +%d" % [level.coins_got, level.xp_got], 32))
	if learned != "":
		var sp: Dictionary = Game.SPELLS[learned]
		var key := Game.SPELL_ORDER.find(learned) + 1
		v.add_child(Ui.label("New magic learned: %s!" % sp["name"], 38, Color(0.45, 0.15, 0.7)))
		v.add_child(Ui.label("%s  Press %d to cast it." % [sp["desc"], key], 26))
	if is_boss:
		v.add_child(Ui.label("Sanny Doo saved the day! Thanks for playing, Sam!", 30, Color(0.8, 0.45, 0.0)))
	var buttons := [Ui.button("Back to the house", Game.goto_hub)]
	var next: int = level.index + 1
	if next < Game.LEVELS.size():
		buttons.append(Ui.button("Next level", func(): Game.start_level(next)))
	Ui.row(v, buttons)
	_arm(buttons, buttons[-1])


func show_fail() -> void:
	var v := Ui.panel(_new_panel_root(), Vector2(620, 420), "Oops! Sanny got bonked.")
	var cp := "from the checkpoint" if Game.checkpoint_level == level.index else "from the start"
	v.add_child(Ui.label("You keep your coins. Try again %s?" % cp, 28))
	v.add_child(Ui.label("Tip: buy armor or hearts at the house shop.", 24, Color(0.35, 0.35, 0.4)))
	var again = Ui.button("Try again", func(): Game.start_level(level.index))
	var home = Ui.button("Back to the house", Game.goto_hub)
	Ui.row(v, [again, home])
	_arm([again, home], again)


## Buttons on the end-of-level panels wait a moment before they work, so a
## Space or X tap that was meant as a shot doesn't skip the panel.
const PANEL_LOCK_TIME := 0.8


func _arm(buttons: Array, focus_button) -> void:
	for b in buttons:
		b.disabled = true
	await get_tree().create_timer(PANEL_LOCK_TIME, true).timeout
	for b in buttons:
		if is_instance_valid(b):
			b.disabled = false
	if is_instance_valid(focus_button):
		focus_button.grab_focus()


## Draws everything on the HUD each frame.
class HudDraw:
	extends Control
	var hud

	func _draw() -> void:
		var level = hud.level
		var player = level.player
		if player == null:
			return
		# Hearts
		for i in Game.max_hearts():
			var fill := Ink.HEART if i < player.hp else Color(1, 1, 1, 0.4)
			Ink.heart(self, Vector2(36 + i * 40, 38), 15.0, fill, 2.5, 600 + i)
		# Magic drops
		var mm := Game.max_mana()
		for i in mm:
			var c := Vector2(30 + i * 26, 82)
			var amt := clampf(player.mana - i, 0.0, 1.0)
			Ink.circle(self, c, 9.0, 2.0, Ink.INK, 700 + i, Color(0.3, 0.55, 0.95, 0.2 + 0.7 * amt))
		# Coins, level, XP
		Ink.circle(self, Vector2(36, 124), 14.0, 2.5, Ink.INK, 800, Ink.COIN)
		Ink.text(self, Vector2(60, 134), "%d" % Game.coins, 30, Ink.INK, false)
		Ink.text(self, Vector2(150, 134), "Lv %d" % Game.player_level, 30, Ink.INK, false)
		var xpw := 120.0
		Ink.rect(self, Rect2(215, 116, xpw, 14), 2.0, Ink.INK, 801)
		draw_rect(Rect2(217, 118, (xpw - 4) * float(Game.xp) / float(Game.xp_needed()), 10), Color(0.95, 0.75, 0.2, 0.9))
		Ink.text(self, Vector2(345, 132), "XP", 20, Ink.FADED, false)

		# Beat circle: it pops on every beat. Shoot right when it pops for double damage!
		var ph: float = Music.beat_phase()
		var pop := pow(1.0 - ph, 3.0)
		var bc := Vector2(640, 46)
		Ink.circle(self, bc, 18.0 + 14.0 * pop, 3.0, Color(0.55, 0.2, 0.75), 900, Color(0.8, 0.6, 1.0, 0.25 + 0.5 * pop))
		Ink.circle(self, bc, 32.0, 2.0, Ink.FADED, 901)
		Ink.text(self, bc + Vector2(0, 62), "shoot on the beat!", 18, Ink.FADED)
		if player.beat_combo >= 2:
			Ink.text(self, bc + Vector2(70, 10), "x%d" % player.beat_combo, 28, Color(0.55, 0.2, 0.75), false)

		# Level progress, or the boss health bar
		if level.boss and is_instance_valid(level.boss):
			var b = level.boss
			var w := 420.0
			Ink.text(self, Vector2(1060, 30), "King Grumble", 26)
			Ink.rect(self, Rect2(850, 40, w, 22), 3.0, Ink.INK, 902)
			draw_rect(Rect2(853, 43, (w - 6) * maxf(0.0, float(b.hp)) / float(b.max_hp), 16), Color(0.6, 0.2, 0.7, 0.85))
		elif level.state != "done":
			var goal: float = level.length - 1280.0
			var prog := clampf(level.cam_x / maxf(1.0, goal), 0.0, 1.0)
			Ink.line(self, Vector2(900, 40), Vector2(1240, 40), 3.0, Ink.INK, 903)
			Ink.circle(self, Vector2(900 + 340 * prog, 40), 9.0, 2.5, Ink.PEN_BLUE, 904, Color(1, 1, 1, 0.9))
			var cpx: float = 900 + 340 * clampf(level.checkpoint_x / maxf(1.0, goal), 0.0, 1.0)
			Ink.line(self, Vector2(cpx, 30), Vector2(cpx, 50), 2.0, Ink.INK, 905)
			Ink.text(self, Vector2(1070, 76), level.data["name"], 24)

		# Magic slots (keys 1 to 4)
		for i in 4:
			var id: String = Game.SPELL_ORDER[i]
			var r := Rect2(20 + i * 92, 630, 80, 72)
			var known: bool = Game.spells.has(id)
			var cost: float = Game.SPELLS[id]["cost"]
			var ready: bool = known and player.mana >= cost
			var fill := Color(1, 1, 1, 0.6) if ready else Color(0.8, 0.8, 0.8, 0.3)
			Ink.rect(self, r, 2.5, Ink.INK if known else Ink.FADED, 910 + i, fill)
			Ink.text(self, r.position + Vector2(10, 22), str(i + 1), 20, Ink.INK, false)
			var c := r.position + Vector2(44, 36)
			if not known:
				Ink.text(self, c + Vector2(0, 14), "?", 40, Ink.FADED)
				continue
			match id:
				"heal":
					Ink.heart(self, c, 14.0, Ink.HEART, 2.0, 920)
				"poison":
					Ink.circle(self, c, 14.0, 2.0, Ink.INK, 921, Ink.POISON, 1.0, 3.0)
				"teleport":
					Ink.poly(self, Ink.star_points(c, 16, 6, 4), 2.0, Ink.INK, 922, Color(0.7, 0.5, 1.0, 0.6))
				"flood":
					Ink.poly(self, PackedVector2Array([c + Vector2(-18, 14), c + Vector2(-14, -4), c + Vector2(0, -14), c + Vector2(8, -2), c + Vector2(18, 14)]), 2.0, Ink.INK, 923, Ink.WATER)
			Ink.text(self, r.position + Vector2(r.size.x - 12, 66), "%d" % int(cost), 16, Ink.FADED)
		Ink.text(self, Vector2(1060, 700), "%s   (%s)" % [Game.weapon_data()["name"], "Free Fly" if Game.flight_mode == "free" else "Flappy"], 24, Ink.FADED)

		# Intro banner
		if level.state == "intro":
			Ink.text(self, Vector2(640, 300), "Level %d: %s" % [level.index + 1, level.data["name"]], 60)
			var hint := "Arrows to fly, Space or X to shoot" if Game.flight_mode == "free" else "Space to flap, X to shoot"
			if Game.uses_touch():
				hint = "Left thumb: slide to fly.  Right thumb: SHOOT" if Game.flight_mode == "free" else "Tap FLAP to fly up, slide left thumb to steer, SHOOT"
			Ink.text(self, Vector2(640, 360), hint, 32, Ink.FADED)
			Ink.text(self, Vector2(640, 420), "Ready... FLY!" if level.intro_t < 1.0 else "Ready...", 44)
