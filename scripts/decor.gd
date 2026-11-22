## The scenery behind the action: the ground, Sam-style trees, clouds, caves, castle walls.
## Level 1 starts in front of Sam's actual house drawing (assets/art/house.png).
## Only the part on screen is drawn each frame.
extends Node2D

const Ink = preload("res://scripts/ink.gd")
const HOUSE_SCALE := 0.8

var level
var theme := "home"
var items: Array = []   # each: {"t": type, "x": .., "y": .., "h": .., "r": .., "seed": ..}


func generate(theme_name: String, length: float, rng: RandomNumberGenerator, with_house: bool) -> void:
	theme = theme_name
	var x := 0.0
	if with_house:
		var house := Sprite2D.new()
		house.texture = load("res://assets/art/house.png")
		house.centered = false
		house.scale = Vector2.ONE * HOUSE_SCALE
		house.position = Vector2(-150, level.ground_y + 4.0 - house.texture.get_height() * HOUSE_SCALE)
		add_child(house)
		x = 1500.0
	while x < length + 1400.0:
		match theme:
			"home":
				items.append({"t": "tree", "x": x, "h": rng.randf_range(60, 160), "r": rng.randf_range(30, 55), "seed": rng.randi() % 9999})
				if rng.randf() < 0.4:
					items.append({"t": "cloud", "x": x + 120, "y": rng.randf_range(80, 220), "r": rng.randf_range(40, 70), "seed": rng.randi() % 9999})
				x += rng.randf_range(220, 420)
			"forest":
				items.append({"t": "tree", "x": x, "h": rng.randf_range(140, 300), "r": rng.randf_range(45, 80), "seed": rng.randi() % 9999})
				x += rng.randf_range(130, 260)
			"cave":
				items.append({"t": "stalactite", "x": x, "h": rng.randf_range(30, 90), "seed": rng.randi() % 9999})
				if rng.randf() < 0.5:
					items.append({"t": "rock", "x": x + 60, "r": rng.randf_range(20, 45), "seed": rng.randi() % 9999})
				x += rng.randf_range(90, 200)
			"sky":
				items.append({"t": "cloud", "x": x, "y": rng.randf_range(80, 500), "r": rng.randf_range(40, 90), "seed": rng.randi() % 9999})
				if rng.randf() < 0.3:
					items.append({"t": "bird", "x": x + 80, "y": rng.randf_range(60, 300), "seed": rng.randi() % 9999})
				x += rng.randf_range(160, 320)
			"castle":
				items.append({"t": "tower", "x": x, "h": rng.randf_range(250, 420), "seed": rng.randi() % 9999})
				x += rng.randf_range(300, 480)
			_:
				x += 300.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var left: float = level.cam_x - 200.0
	var right: float = level.cam_x + 1500.0
	var gy: float = level.ground_y
	var faded := Ink.FADED
	for it in items:
		var x: float = it["x"]
		if x < left or x > right:
			continue
		var sd: int = it["seed"]
		match str(it["t"]):
			"tree":
				Ink.tree(self, x, gy, it["h"], it["r"], sd, faded, 3.0)
			"cloud":
				Ink.circle(self, Vector2(x, it["y"]), it["r"], 2.5, faded, sd, Color(1, 1, 1, 0.5), 0.55, float(it["r"]) * 0.18)
			"bird":
				var p := Vector2(x, it["y"])
				Ink.line(self, p + Vector2(-14, -6), p, 2.0, faded, sd)
				Ink.line(self, p, p + Vector2(14, -6), 2.0, faded, sd + 1)
			"stalactite":
				var cy: float = level.ceil_y
				Ink.poly(self, PackedVector2Array([Vector2(x - 20, cy), Vector2(x, cy + float(it["h"])), Vector2(x + 20, cy)]), 2.5, faded, sd, Ink.NO_FILL, false)
			"rock":
				Ink.circle(self, Vector2(x, gy - 6), it["r"], 2.5, faded, sd, Ink.NO_FILL, 0.6)
			"tower":
				var h: float = it["h"]
				Ink.rect(self, Rect2(x - 60, gy - h, 120, h), 3.0, faded, sd)
				for k in 3:
					Ink.rect(self, Rect2(x - 60 + k * 45, gy - h - 26, 30, 26), 2.5, faded, sd + k)
				Ink.rect(self, Rect2(x - 14, gy - h + 50, 28, 40), 2.5, faded, sd + 9)
				Ink.line(self, Vector2(x, gy - h - 26), Vector2(x, gy - h - 80), 2.5, faded, sd + 10)
				Ink.poly(self, PackedVector2Array([Vector2(x, gy - h - 80), Vector2(x + 40, gy - h - 68), Vector2(x, gy - h - 56)]), 2.5, faded, sd + 11, Color(0.9, 0.3, 0.3, 0.4))
	_draw_ground(left, right)
	if level.ceil_y > 40.0:
		_draw_ceiling(left, right)
	_draw_flags()


func _draw_ground(left: float, right: float) -> void:
	var gy: float = level.ground_y
	var pts := PackedVector2Array()
	var x0 := floorf(left / 40.0) * 40.0
	var x := x0
	var bumps := theme == "sky"
	while x <= right:
		var y := gy
		if bumps:
			y += sin(x * 0.03) * 6.0
		pts.append(Vector2(x, y + Ink.jit(77, int(x / 40.0)) * 1.5))
		x += 40.0
	draw_polyline(pts, Ink.INK, 3.0, true)
	# Under the ground: light hatching so it reads as solid
	var shade := Ink.PAPER_DARK
	shade.a = 0.5
	draw_rect(Rect2(x0, gy + 2, right - x0, 120), shade)
	x = x0
	while x <= right:
		if theme == "home" or theme == "forest":
			Ink.line(self, Vector2(x + 10, gy), Vector2(x + 14, gy - 10), 2.0, Ink.FADED, int(x))
			Ink.line(self, Vector2(x + 18, gy), Vector2(x + 16, gy - 12), 2.0, Ink.FADED, int(x) + 1)
		elif theme == "castle":
			Ink.line(self, Vector2(x, gy + 20), Vector2(x + 40, gy + 20), 2.0, Ink.FADED, int(x))
			Ink.line(self, Vector2(x + 20, gy), Vector2(x + 20, gy + 20), 2.0, Ink.FADED, int(x) + 1)
		x += 80.0


func _draw_ceiling(left: float, right: float) -> void:
	var cy: float = level.ceil_y
	var shade := Ink.PAPER_DARK
	shade.a = 0.5
	draw_rect(Rect2(left, cy - 200, right - left, 200), shade)
	Ink.line(self, Vector2(left, cy), Vector2(right, cy), 3.0, Ink.INK, 78)


func _draw_flags() -> void:
	var gy: float = level.ground_y
	if level.checkpoint_x > 0.0:
		var cx: float = level.checkpoint_x
		Ink.line(self, Vector2(cx, gy), Vector2(cx, gy - 120), 3.0, Ink.INK, 81)
		Ink.poly(self, PackedVector2Array([Vector2(cx, gy - 120), Vector2(cx + 50, gy - 105), Vector2(cx, gy - 90)]), 2.5, Ink.INK, 82, Color(0.3, 0.7, 0.9, 0.6) if level.checkpoint_reached else Color(1, 1, 1, 0.5))
		Ink.text(self, Vector2(cx + 10, gy - 130), "checkpoint", 20, Ink.FADED)
	if level.finish_x > 0.0:
		var fx: float = level.finish_x
		Ink.line(self, Vector2(fx, gy), Vector2(fx, gy - 260), 4.0, Ink.INK, 83)
		Ink.poly(self, PackedVector2Array([Vector2(fx, gy - 260), Vector2(fx + 110, gy - 225), Vector2(fx, gy - 190)]), 3.0, Ink.INK, 84, Color(0.95, 0.3, 0.3, 0.6))
		Ink.poly(self, Ink.star_points(Vector2(fx + 38, gy - 225), 16, 7), 2.0, Ink.INK, 85, Ink.COIN)
		Ink.text(self, Vector2(fx, gy - 280), "FINISH!", 34)
