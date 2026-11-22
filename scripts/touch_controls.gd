## Phone and tablet controls, shown only on touch screens.
##
##   Left thumb:  put it down anywhere on the left side and slide to fly (a joystick)
##   Right side:  big SHOOT button (hold to keep shooting, tap on the beat for x2)
##                FLAP button too, in Flappy style
##   Magic:       tap the magic boxes (1 to 4) at the bottom left
##   Pause:       the || button near the top right
##
## It works by pressing the same named actions the keyboard uses
## (move_left, shoot, flap, spell_1...), so the player code doesn't change.
extends CanvasLayer

const Ink = preload("res://scripts/ink.gd")

const STICK_RADIUS := 90.0     # how far your thumb slides for full speed
const DEAD_ZONE := 0.15
const SHOOT_CENTER := Vector2(1150, 520)
const SHOOT_RADIUS := 85.0
const FLAP_CENTER := Vector2(990, 600)
const FLAP_RADIUS := 72.0
const PAUSE_CENTER := Vector2(1236, 122)
const PAUSE_RADIUS := 30.0
const SPELL_TOP := 620.0       # the magic boxes are below this line, left of SPELL_RIGHT
const SPELL_RIGHT := 392.0

var level
var _stick_finger := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _shoot_finger := -1
var _flap_finger := -1
var _draw_node: Control
var _release_next_frame: Array = []


func _ready() -> void:
	layer = 11
	visible = Game.uses_touch()
	_draw_node = _Pad.new()
	_draw_node.pad = self
	_draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_draw_node)


func _process(_delta: float) -> void:
	for a in _release_next_frame:
		Input.action_release(a)
	_release_next_frame.clear()
	if visible:
		_draw_node.queue_redraw()


func _playing() -> bool:
	return level.state == "play" or level.state == "boss" or level.state == "intro"


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if not visible:
			visible = true
			Game.touch_seen = true
	else:
		return
	if not _playing():
		_release_all()
		return
	var pos: Vector2 = event.position  # Godot already turns this into game pixels (1280x720)
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, pos)
		else:
			_touch_up(event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _stick_finger:
		_stick_pos = pos
		_apply_stick()
		get_viewport().set_input_as_handled()


func _touch_down(finger: int, pos: Vector2) -> void:
	if pos.distance_to(PAUSE_CENTER) < PAUSE_RADIUS + 20.0:
		_release_all()
		level.hud.toggle_pause()
		return
	if pos.distance_to(SHOOT_CENTER) < SHOOT_RADIUS + 25.0:
		_shoot_finger = finger
		Input.action_press("shoot")
		return
	if Game.flight_mode == "flap" and pos.distance_to(FLAP_CENTER) < FLAP_RADIUS + 20.0:
		_flap_finger = finger
		_tap_action("flap")
		return
	if pos.y > SPELL_TOP and pos.x < SPELL_RIGHT:
		var slot := clampi(int((pos.x - 20.0) / 92.0), 0, 3)
		_tap_action("spell_%d" % (slot + 1))
		return
	if pos.x < 760.0 and _stick_finger == -1:
		_stick_finger = finger
		_stick_origin = pos
		_stick_pos = pos
		_apply_stick()
	elif Game.flight_mode == "flap":
		# In Flappy style, tapping anywhere else on the right side also flaps.
		_tap_action("flap")


func _touch_up(finger: int) -> void:
	if finger == _stick_finger:
		_stick_finger = -1
		for a in ["move_left", "move_right", "move_up", "move_down"]:
			Input.action_release(a)
	if finger == _shoot_finger:
		_shoot_finger = -1
		Input.action_release("shoot")
	if finger == _flap_finger:
		_flap_finger = -1


func _tap_action(action: String) -> void:
	Input.action_press(action)
	_release_next_frame.append(action)


func _apply_stick() -> void:
	var v := (_stick_pos - _stick_origin) / STICK_RADIUS
	if v.length() > 1.0:
		_stick_origin = _stick_pos - v.normalized() * STICK_RADIUS  # the stick follows your thumb
		v = v.normalized()
	_axis("move_left", "move_right", v.x)
	# In Flappy style the stick only steers left and right; flapping is a tap.
	_axis("move_up", "move_down", v.y if Game.flight_mode == "free" else 0.0)


func _axis(neg: String, pos_action: String, value: float) -> void:
	if value < -DEAD_ZONE:
		Input.action_press(neg, -value)
		Input.action_release(pos_action)
	elif value > DEAD_ZONE:
		Input.action_press(pos_action, value)
		Input.action_release(neg)
	else:
		Input.action_release(neg)
		Input.action_release(pos_action)


func _release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "shoot", "flap"]:
		Input.action_release(a)
	_stick_finger = -1
	_shoot_finger = -1
	_flap_finger = -1


func _exit_tree() -> void:
	_release_all()


class _Pad:
	extends Control
	var pad

	func _draw() -> void:
		var faint := Color(0.11, 0.10, 0.14, 0.35)
		# Joystick
		if pad._stick_finger != -1:
			Ink.circle(self, pad._stick_origin, pad.STICK_RADIUS, 3.0, faint, 1100, Color(1, 1, 1, 0.25))
			Ink.circle(self, pad._stick_pos, 34.0, 3.0, Ink.INK, 1101, Color(0.16, 0.12, 0.42, 0.35))
		else:
			Ink.text(self, Vector2(260, 560), "slide here to fly", 24, faint)
		# Shoot button
		var held: bool = pad._shoot_finger != -1
		Ink.circle(self, pad.SHOOT_CENTER, pad.SHOOT_RADIUS, 4.0, Ink.INK, 1102, Color(1.0, 0.82, 0.3, 0.75 if held else 0.45))
		Ink.text(self, pad.SHOOT_CENTER + Vector2(0, 10), "SHOOT", 32)
		if Game.flight_mode == "flap":
			Ink.circle(self, pad.FLAP_CENTER, pad.FLAP_RADIUS, 4.0, Ink.INK, 1103, Color(0.6, 0.8, 1.0, 0.5))
			Ink.text(self, pad.FLAP_CENTER + Vector2(0, 10), "FLAP", 30)
		# Pause
		Ink.circle(self, pad.PAUSE_CENTER, pad.PAUSE_RADIUS, 3.0, Ink.INK, 1104, Color(1, 1, 1, 0.6))
		Ink.line(self, pad.PAUSE_CENTER + Vector2(-7, -12), pad.PAUSE_CENTER + Vector2(-7, 12), 4.0, Ink.INK, 1105)
		Ink.line(self, pad.PAUSE_CENTER + Vector2(7, -12), pad.PAUSE_CENTER + Vector2(7, 12), 4.0, Ink.INK, 1106)
