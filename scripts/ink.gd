## Hand-drawn "pen on paper" drawing helpers.
##
## Everything in Sanny Doo that isn't cut straight out of Sam's drawings is drawn
## with these functions, so it matches his style: one dark pen line, a bit wobbly,
## on paper, with a light crayon color inside sometimes.
## The wobble changes a few times per second ("boiling lines"), like a cartoon.
##
## Use it from any script with:  const Ink = preload("res://scripts/ink.gd")
## and call Ink.circle(self, ...) from inside that node's _draw().
extends RefCounted

const INK := Color(0.11, 0.10, 0.14)
const PEN_BLUE := Color(0.16, 0.12, 0.42)  # the pen Sam drew Sanny Doo with
const PAPER := Color(0.95, 0.93, 0.87)
const PAPER_DARK := Color(0.86, 0.83, 0.76)
const FADED := Color(0.11, 0.10, 0.14, 0.45)  # background doodles

# Crayon colors (light fills inside the pen lines)
const COIN := Color(1.0, 0.80, 0.15, 0.95)
const HEART := Color(0.92, 0.22, 0.25, 0.9)
const MANA := Color(0.30, 0.55, 0.95, 0.9)
const POISON := Color(0.40, 0.78, 0.25, 0.45)
const WATER := Color(0.30, 0.55, 0.95, 0.45)
const SPIKE := Color(0.55, 0.55, 0.62, 0.40)
const NO_FILL := Color(0, 0, 0, 0)

## Goes up a few times a second (Game.gd ticks it). Every wobble depends on it,
## so all lines "boil" together.
static var boil: int = 0


## A repeatable random number from -1 to 1. Same inputs = same wobble.
static func jit(seed: int, i: int) -> float:
	var h: int = hash(Vector3i(seed, i, boil))
	return float(posmod(h, 2001)) / 1000.0 - 1.0


## Turns straight lines into slightly wobbly pen lines.
static func wobble_points(pts: PackedVector2Array, closed: bool, seed: int, amp: float = 1.4, step: float = 14.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	if n < 2:
		return pts
	var segs := n if closed else n - 1
	var k := 0
	for s in segs:
		var a: Vector2 = pts[s]
		var b: Vector2 = pts[(s + 1) % n]
		var parts := maxi(1, int(a.distance_to(b) / step))
		var normal := (b - a).orthogonal().normalized()
		for p in parts:
			var t := float(p) / float(parts)
			out.append(a.lerp(b, t) + normal * jit(seed, k) * amp)
			k += 1
	if closed:
		out.append(out[0])
	else:
		out.append(pts[n - 1] + Vector2(jit(seed, k), jit(seed, k + 1)) * amp * 0.5)
	return out


static func line(ci: CanvasItem, a: Vector2, b: Vector2, w: float = 3.0, col: Color = INK, seed: int = 0, amp: float = 1.4) -> void:
	ci.draw_polyline(wobble_points(PackedVector2Array([a, b]), false, seed, amp), col, w, true)


## Any shape from a list of corner points. fill = crayon color inside.
static func poly(ci: CanvasItem, pts: PackedVector2Array, w: float = 3.0, col: Color = INK, seed: int = 0, fill: Color = NO_FILL, closed: bool = true, amp: float = 1.4) -> void:
	if fill.a > 0.0 and closed and pts.size() >= 3:
		ci.draw_colored_polygon(pts, fill)
	ci.draw_polyline(wobble_points(pts, closed, seed, amp), col, w, true)


static func rect(ci: CanvasItem, r: Rect2, w: float = 3.0, col: Color = INK, seed: int = 0, fill: Color = NO_FILL) -> void:
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	poly(ci, pts, w, col, seed, fill, true)


static func circle_points(c: Vector2, r: float, seed: int, squash: float = 1.0, bumps: float = 0.0) -> PackedVector2Array:
	var n := clampi(int(r * 0.5) + 10, 10, 48)
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		var rr := r + jit(seed, 300 + i) * maxf(0.8, r * 0.04)
		if bumps > 0.0:
			rr += absf(sin(a * 3.5)) * bumps
		pts.append(c + Vector2(cos(a) * rr, sin(a) * rr * squash))
	return pts


## A kid-drawn circle: a little lumpy, and the pen overlaps where it started.
static func circle(ci: CanvasItem, c: Vector2, r: float, w: float = 3.0, col: Color = INK, seed: int = 0, fill: Color = NO_FILL, squash: float = 1.0, bumps: float = 0.0) -> void:
	var pts := circle_points(c, r, seed, squash, bumps)
	if fill.a > 0.0:
		ci.draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	pts.append(pts[1])
	ci.draw_polyline(pts, col, w, true)


## A row of triangle spikes. dir = -1 points up (floor), +1 points down (ceiling).
static func spikes(ci: CanvasItem, x0: float, base_y: float, count: int, sw: float, sh: float, dir: float, seed: int, fill: Color = SPIKE, w: float = 3.0) -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2(x0, base_y))
	for i in count:
		var tip := Vector2(x0 + sw * (i + 0.5), base_y + sh * dir)
		var right := Vector2(x0 + sw * (i + 1), base_y)
		if fill.a > 0.0:
			ci.draw_colored_polygon(PackedVector2Array([Vector2(x0 + sw * i, base_y), tip, right]), fill)
		pts.append(tip)
		pts.append(right)
	ci.draw_polyline(wobble_points(pts, false, seed, 1.2, 10.0), INK, w, true)


static func heart_points(c: Vector2, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 24:
		var t := TAU * float(i) / 24.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(c + Vector2(x, y) * s / 16.0)
	return pts


static func heart(ci: CanvasItem, c: Vector2, s: float, fill: Color = HEART, w: float = 2.5, seed: int = 0) -> void:
	poly(ci, heart_points(c, s), w, INK, seed, fill, true, 0.8)


static func star_points(c: Vector2, r_out: float, r_in: float, n: int = 5, rot: float = -PI / 2.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n * 2:
		var r := r_out if i % 2 == 0 else r_in
		var a := rot + PI * float(i) / float(n)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


## A face in Sam's style: oval eyes and a big open mouth.
## mood: "happy", "angry", "teeth", "o"
static func face(ci: CanvasItem, c: Vector2, r: float, mood: String, seed: int, look: Vector2 = Vector2.ZERO, w: float = 2.5) -> void:
	var ex := r * 0.34
	var ey := -r * 0.22
	for side in [-1.0, 1.0]:
		var e: Vector2 = c + Vector2(ex * side, ey)
		circle(ci, e, r * 0.13, w, INK, seed + int(side * 3.0), NO_FILL, 1.4)
		ci.draw_circle(e + look * r * 0.06, maxf(1.5, r * 0.05), INK)
		if mood == "angry" or mood == "teeth":
			line(ci, e + Vector2(-r * 0.18 * side, -r * 0.28), e + Vector2(r * 0.14 * side, -r * 0.16), w, INK, seed + 9 + int(side))
	var m := c + Vector2(0, r * 0.25)
	match mood:
		"happy":
			var pts := PackedVector2Array()
			for i in 9:
				var a := PI * float(i) / 8.0
				pts.append(m + Vector2(cos(a) * r * 0.32, sin(a) * r * 0.3))
			poly(ci, pts, w, INK, seed + 20, Color(0.85, 0.3, 0.3, 0.35), true, 0.8)
		"angry":
			var pts2 := PackedVector2Array()
			for i in 9:
				var a := PI + PI * float(i) / 8.0
				pts2.append(m + Vector2(cos(a) * r * 0.28, sin(a) * r * 0.16 + r * 0.12))
			ci.draw_polyline(wobble_points(pts2, false, seed + 21, 0.8), INK, w, true)
		"teeth":
			var z := PackedVector2Array()
			for i in 9:
				z.append(m + Vector2(-r * 0.4 + r * 0.1 * i, (r * 0.08 if i % 2 == 0 else -r * 0.08)))
			poly(ci, PackedVector2Array([m + Vector2(-r * 0.45, -r * 0.12), m + Vector2(r * 0.45, -r * 0.12), m + Vector2(r * 0.35, r * 0.18), m + Vector2(-r * 0.35, r * 0.18)]), w, INK, seed + 22, Color(0.5, 0.1, 0.1, 0.5))
			ci.draw_polyline(wobble_points(z, false, seed + 23, 0.6), INK, w, true)
		_:
			circle(ci, m, r * 0.12, w, INK, seed + 24)


## A tree the way Sam draws them: a tall box trunk with a line across the top,
## and a lumpy round top with a couple of little curls in it.
static func tree(ci: CanvasItem, x: float, gy: float, h: float, r: float, seed: int, col: Color = INK, w: float = 3.0) -> void:
	var tw := clampf(h * 0.22, 24.0, 46.0)
	line(ci, Vector2(x - tw * 0.5, gy), Vector2(x - tw * 0.5, gy - h), w, col, seed)
	line(ci, Vector2(x + tw * 0.5, gy), Vector2(x + tw * 0.5, gy - h), w, col, seed + 1)
	line(ci, Vector2(x - tw * 0.5 - 4.0, gy - h), Vector2(x + tw * 0.5 + 4.0, gy - h + 3.0), w, col, seed + 2)
	var top := Vector2(x, gy - h - r * 0.8)
	circle(ci, top, r, w, col, seed + 3, NO_FILL, 0.9, r * 0.14)
	circle(ci, top + Vector2(-r * 0.32, -r * 0.18), r * 0.17, w * 0.8, col, seed + 4)
	circle(ci, top + Vector2(r * 0.25, r * 0.05), r * 0.14, w * 0.8, col, seed + 5)


## Handwritten text (Patrick Hand font), centered on pos.x by default.
static func text(ci: CanvasItem, pos: Vector2, s: String, size: int = 32, col: Color = INK, centered: bool = true) -> void:
	var f: Font = Game.font
	var p := pos
	if centered:
		p.x -= f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5
	ci.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## A circle overlapping a rectangle? (for spike hit boxes)
static func circle_hits_rect(p: Vector2, r: float, box: Rect2) -> bool:
	var closest := Vector2(clampf(p.x, box.position.x, box.end.x), clampf(p.y, box.position.y, box.end.y))
	return p.distance_squared_to(closest) < r * r
