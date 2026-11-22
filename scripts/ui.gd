## Helpers for building menus in code: paper panels, handwritten labels.
extends RefCounted

const Ink = preload("res://scripts/ink.gd")
const InkButton = preload("res://scripts/ink_button.gd")


## A paper panel in the middle of the screen. Returns the VBoxContainer to put things in.
static func panel(parent: Node, panel_size: Vector2, title: String = "") -> VBoxContainer:
	var box := PaperPanel.new()
	box.size = panel_size
	box.position = (Vector2(1280, 720) - panel_size) * 0.5
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(box)
	var v := VBoxContainer.new()
	v.position = Vector2(30, 24)
	v.size = panel_size - Vector2(60, 48)
	v.add_theme_constant_override("separation", 10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(v)
	if title != "":
		v.add_child(label(title, 46))
	return v


static func label(t: String, font_size: int = 28, col: Color = Ink.INK) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", Game.font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	return l


static func button(t: String, on_press: Callable, min_size: Vector2 = Vector2(260, 58)):
	return InkButton.new(t, on_press, min_size)


## A centered row of buttons.
static func row(parent: Control, buttons: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 16)
	for b in buttons:
		h.add_child(b)
	parent.add_child(h)
	return h


## A sheet of paper with a wobbly pen border.
class PaperPanel:
	extends Control
	var seed := randi() % 10000

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2(10, 12), size), Color(0, 0, 0, 0.12))
		Ink.rect(self, Rect2(Vector2.ZERO, size), 4.0, Ink.INK, seed, Color(0.98, 0.96, 0.9, 0.97))
