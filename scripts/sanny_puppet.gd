## Sanny Doo's look, made from Sam's own drawing.
##
## tools/extract_ink.gd cut the photo into three pieces: the body and the two
## wings, so the wings can flap. Armor bought in the shop is drawn on top.
## Used by the player in levels, and by the title and house screens.
extends Node2D

const Ink = preload("res://scripts/ink.gd")

const DRAW_SCALE := 0.16    # Sam's drawing is 720 px tall; this makes Sanny about 110 px
const CENTER := Vector2(360, 360)
# Where each wing joins the head, in drawing pixels (measured on the photo).
const WING_L_PIVOT := Vector2(200, 300)
const WING_R_PIVOT := Vector2(525, 290)

var flap_speed := 9.0       # wing beats per second (times 2 PI)
var flap_amount := 0.35     # how far the wings swing (radians)
var flap_boost := 0.0       # extra swing for a moment after a flap
var armor_level := -1       # -1 = read it from Game every frame
var _t := 0.0
var _look: Node2D
var _wing_l: Sprite2D
var _wing_r: Sprite2D
var _armor: Node2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # smooth when shrunk
	_look = Node2D.new()
	_look.scale = Vector2.ONE * DRAW_SCALE
	add_child(_look)
	_wing_l = _wing("res://assets/art/sanny_wing_left.png", WING_L_PIVOT)
	_wing_r = _wing("res://assets/art/sanny_wing_right.png", WING_R_PIVOT)
	var body := Sprite2D.new()
	body.texture = load("res://assets/art/sanny_body.png")
	_look.add_child(body)
	_armor = _ArmorLayer.new()
	_armor.puppet = self
	_look.add_child(_armor)


func _wing(path: String, pivot: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.centered = false
	s.offset = -pivot
	s.position = pivot - CENTER
	_look.add_child(s)
	return s


func flap() -> void:
	flap_boost = 0.6


func _process(delta: float) -> void:
	_t += delta
	flap_boost = move_toward(flap_boost, 0.0, delta * 2.0)
	var swing := sin(_t * flap_speed) * (flap_amount + flap_boost)
	_wing_l.rotation = -swing
	_wing_r.rotation = swing
	_armor.queue_redraw()


func current_armor() -> int:
	return Game.armor if armor_level < 0 else armor_level


## Draws the armor on top of Sanny, in the same pen style, in drawing pixels.
class _ArmorLayer:
	extends Node2D
	var puppet

	func _draw() -> void:
		var a: int = puppet.current_armor()
		var w := 16.0  # line width in drawing pixels (scaled down 0.15x)
		var c := Vector2(-2, -92)  # head center relative to the drawing center
		if a == 1:
			# Cardboard box around the legs
			Ink.rect(self, Rect2(-215, 55, 420, 260), w, Ink.INK, 401, Color(0.78, 0.6, 0.38, 0.55))
			Ink.line(self, Vector2(-160, 120), Vector2(140, 120), w * 0.6, Ink.INK, 402)
		elif a == 2:
			# A cooking pot on his head
			var pot := PackedVector2Array([c + Vector2(-170, -150), c + Vector2(170, -150), c + Vector2(150, -270), c + Vector2(-150, -270)])
			Ink.poly(self, pot, w, Ink.INK, 403, Color(0.6, 0.62, 0.68, 0.7))
			Ink.line(self, c + Vector2(-210, -160), c + Vector2(210, -160), w, Ink.INK, 404)
			Ink.circle(self, c + Vector2(0, -290), 26.0, w * 0.7, Ink.INK, 405, Color(0.3, 0.3, 0.35, 0.8))
		elif a >= 3:
			# Knight helmet with a plume, and a chest plate
			var helm := PackedVector2Array([c + Vector2(-190, -115), c + Vector2(-150, -220), c + Vector2(0, -250), c + Vector2(150, -220), c + Vector2(190, -115)])
			Ink.poly(self, helm, w, Ink.INK, 406, Color(0.72, 0.74, 0.8, 0.75), true)
			Ink.line(self, c + Vector2(-190, -115), c + Vector2(190, -115), w, Ink.INK, 407)
			Ink.circle(self, c + Vector2(0, -290), 50.0, w * 0.7, Ink.INK, 408, Color(0.9, 0.2, 0.25, 0.75), 1.0, 10.0)
			Ink.rect(self, Rect2(-190, 60, 380, 150), w, Ink.INK, 409, Color(0.72, 0.74, 0.8, 0.7))
			Ink.line(self, Vector2(0, 70), Vector2(0, 200), w * 0.6, Ink.INK, 410)
