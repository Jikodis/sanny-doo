## A button drawn in pen, like the rest of the game. Works with mouse, keyboard
## (arrows + Enter/Space) and gamepad. The text is drawn by us, not by Godot.
extends Button

const Ink = preload("res://scripts/ink.gd")

var label := ""
var font_size := 30
var seed := 0
var fill := Color(1, 1, 1, 0.55)


func _init(text_: String = "", on_press: Callable = Callable(), min_size: Vector2 = Vector2(260, 58)) -> void:
	label = text_
	flat = true
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = min_size
	seed = randi() % 10000
	if on_press.is_valid():
		pressed.connect(on_press)
	pressed.connect(func(): Sfx.play("click", 0.0))
	mouse_entered.connect(grab_focus)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	var f := fill
	var ink := Ink.INK
	if disabled:
		f = Color(0.8, 0.8, 0.8, 0.35)
		ink = Color(0.4, 0.4, 0.45)
	elif has_focus() or is_hovered():
		f = Color(1.0, 0.88, 0.4, 0.9)
	Ink.rect(self, r, 3.0 if not has_focus() else 4.5, ink, seed, f)
	Ink.text(self, Vector2(size.x * 0.5, size.y * 0.5 + font_size * 0.32), label, font_size, ink)
