# Turns Sam's paper drawings (photos) into transparent "ink only" PNGs.
# Run once from the project folder:
#   Godot --headless --path . --script res://tools/extract_ink.gd
# How it works: for each pixel we compare its brightness to the average
# brightness of the paper around it (a blurred copy). Pen lines are much
# darker than the nearby paper, so they keep their color; paper becomes
# see-through. Comparing to the LOCAL average handles the shadow/gradient
# in the photos better than one global cutoff would.
extends SceneTree

func _init() -> void:
	_extract_sanny()
	_extract_house()
	quit()

func _ink_mask(img: Image, blur_size: int, strength: float) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var blur := img.duplicate() as Image
	blur.resize(max(1, w / blur_size), max(1, h / blur_size), Image.INTERPOLATE_BILINEAR)
	blur.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var paper := blur.get_pixel(x, y).get_luminance()
			var lum := c.get_luminance()
			# How much darker than the local paper is this pixel? 0 = paper.
			var dark := clampf((paper - lum) / max(paper, 0.05), 0.0, 1.0)
			var a := smoothstep(0.10 * strength, 0.28 * strength, dark)
			out.set_pixel(x, y, Color(0, 0, 0, a))
	return out

## Makes pen lines thicker (a "max" filter), so they still look like pen
## when Sanny is shrunk down to game size.
func _thicken(mask: Image, r: int) -> Image:
	var w := mask.get_width()
	var h := mask.get_height()
	var tmp := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var m := 0.0
			for k in range(-r, r + 1):
				m = maxf(m, mask.get_pixel(clampi(x + k, 0, w - 1), y).a)
			tmp.set_pixel(x, y, Color(0, 0, 0, m))
	for y in h:
		for x in w:
			var m2 := 0.0
			for k in range(-r, r + 1):
				m2 = maxf(m2, tmp.get_pixel(x, clampi(y + k, 0, h - 1)).a)
			out.set_pixel(x, y, Color(0, 0, 0, m2))
	return out


func _extract_sanny() -> void:
	var img := Image.load_from_file("res://assets/source/sanny_doo_drawing.jpg")
	var mask := _thicken(_ink_mask(img, 24, 1.0), 4)
	var ink := Color(0.16, 0.12, 0.42)  # the purple-blue pen Sam used
	var w := mask.get_width()
	var h := mask.get_height()
	# Head circle (measured on the photo) separates the wings from the body.
	var head_c := Vector2(358, 268)
	var head_r := 200.0
	var body := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var wing_l := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var wing_r := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var a := mask.get_pixel(x, y).a
			if a <= 0.01:
				continue
			var px := Color(ink.r, ink.g, ink.b, a)
			var outside_head := Vector2(x, y).distance_to(head_c) > head_r + 6.0
			if outside_head and y < 420 and x < 230:
				wing_l.set_pixel(x, y, px)
			elif outside_head and y < 420 and x > 500:
				wing_r.set_pixel(x, y, px)
			else:
				body.set_pixel(x, y, px)
	body.save_png("res://assets/art/sanny_body.png")
	wing_l.save_png("res://assets/art/sanny_wing_left.png")
	wing_r.save_png("res://assets/art/sanny_wing_right.png")
	print("sanny done ", w, "x", h)

func _extract_house() -> void:
	var img := Image.load_from_file("res://assets/source/house_drawing.jpg")
	img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	var mask := _ink_mask(img, 20, 1.0)
	var w := mask.get_width()
	var h := mask.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var ink := Color(0.10, 0.10, 0.12)
	for y in h:
		for x in w:
			var a := mask.get_pixel(x, y).a
			# Bottom-right corner of the photo shows the table edge, not drawing.
			if y > h - 30 and x > w * 0.5:
				a = 0.0
			if a > 0.01:
				out.set_pixel(x, y, Color(ink.r, ink.g, ink.b, a))
	out.save_png("res://assets/art/house.png")
	print("house done ", w, "x", h)
