## The title screen: Sanny Doo flapping, Sam-style trees, and the main buttons.
## The flying style button switches between the two ways to fly, so Sam can pick.
extends Control

const Ink = preload("res://scripts/ink.gd")
const Ui = preload("res://scripts/ui.gd")
const Puppet = preload("res://scripts/sanny_puppet.gd")

var _sanny: Node2D
var _style_button
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_sanny = Puppet.new()
	_sanny.scale = Vector2.ONE * 2.0
	_sanny.position = Vector2(330, 330)
	add_child(_sanny)
	Music.play_track("title")

	var v := VBoxContainer.new()
	v.position = Vector2(760, 210)
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	var play = Ui.button("Play" if Game.has_save() else "Start", _play, Vector2(380, 64))
	v.add_child(play)
	if Game.has_save():
		v.add_child(Ui.button("New game", _new_game, Vector2(380, 64)))
	_style_button = Ui.button("", _toggle_style, Vector2(380, 64))
	v.add_child(_style_button)
	_update_style_label()
	play.grab_focus.call_deferred()


func _play() -> void:
	if not Game.has_save():
		Game.new_game()
	Game.goto_hub()


func _new_game() -> void:
	var style := Game.flight_mode
	Game.new_game()
	Game.flight_mode = style
	Game.save_game()
	Game.goto_hub()


func _toggle_style() -> void:
	Game.flight_mode = "flap" if Game.flight_mode == "free" else "free"
	Game.save_game()
	_update_style_label()


func _update_style_label() -> void:
	_style_button.label = "Flying: Free Fly" if Game.flight_mode == "free" else "Flying: Flappy"


func _process(delta: float) -> void:
	_t += delta
	_sanny.position = Vector2(330 + sin(_t * 0.7) * 40.0, 330 + sin(_t * 1.8) * 22.0)
	queue_redraw()


func _draw() -> void:
	Ink.text(self, Vector2(640, 130), "Sanny Doo", 120)
	Ink.line(self, Vector2(430, 150), Vector2(850, 146), 4.0, Ink.INK, 3)
	Ink.text(self, Vector2(640, 190), "a game by Sam", 32, Ink.FADED)
	for i in 6:
		Ink.tree(self, 80 + i * 230, 712, 70 + (i * 37) % 90, 34 + (i * 13) % 24, 40 + i, Ink.INK, 3.0)
	Ink.line(self, Vector2(0, 712), Vector2(1280, 712), 3.0, Ink.INK, 5)
	var help := "Free Fly: arrows to fly, Space or X to shoot" if Game.flight_mode == "free" else "Flappy: Space to flap, arrows steer, X shoots"
	Ink.rect(self, Rect2(740, 470, 420, 118), 2.5, Ink.INK, 6, Color(0.98, 0.96, 0.9, 0.95))
	var line2 := "1 2 3 4 = magic     Esc = pause"
	if Game.uses_touch():
		help = "Slide your left thumb to fly, tap SHOOT" if Game.flight_mode == "free" else "Tap FLAP to fly up, left thumb steers"
		line2 = "Tap the magic boxes to cast,  || to pause"
	Ink.text(self, Vector2(950, 504), help, 22, Ink.INK)
	Ink.text(self, Vector2(950, 536), line2, 22, Ink.INK)
	Ink.text(self, Vector2(950, 568), "Shoot right on the beat for double damage!", 22, Color(0.55, 0.2, 0.75))
