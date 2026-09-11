class_name OrbitCamera
extends Node3D

## Orbits its camera around this node's origin: drag with any mouse button to
## rotate the view, Ctrl + wheel to zoom. Left alone for a while, it slowly
## circles on its own, showroom style, until the next input.

## How much of the view a framed sphere fills (see [method frame]).
const FILL := 0.8

@export var camera: Camera3D
@export_range(0.001, 0.02) var drag_sensitivity := 0.006
## Seconds without any mouse or key input before the camera starts circling;
## 0 never.
@export var idle_delay := 10.0
## How fast it circles then, in degrees per second.
@export var idle_speed := 10.0

## Distance of the camera from the orbit center.
@export var distance := 2.5:
	set(value):
		distance = clampf(value, 0.3, 50.0)
		_apply()

## The part of the screen (normalized, 0..1) to show the orbit center in --
## for instance what a side panel leaves free. The camera slides sideways so
## the orbit center sits in the middle of this area instead of the window's.
var view_area := Rect2(0.0, 0.0, 1.0, 1.0):
	set(value):
		view_area = value
		if _framed_radius > 0.0:
			frame(_framed_radius)
		else:
			_apply()

var _yaw := deg_to_rad(35.0)
var _pitch := deg_to_rad(-25.0)
var _framed_radius := 0.0
var _idle_time := 0.0
var _idle_spin := 0.0  # radians per second right now


func _ready() -> void:
	get_viewport().size_changed.connect(_apply)
	_apply()


func _input(event: InputEvent) -> void:
	# _input sees every event, the ones the panel takes included.
	if event is InputEventMouse or event is InputEventKey:
		_idle_time = 0.0


func _process(delta: float) -> void:
	_idle_time += delta
	var circling := idle_delay > 0.0 and _idle_time >= idle_delay
	var top_speed := deg_to_rad(idle_speed)
	# Picks up speed over two seconds, stops within a fraction of one.
	_idle_spin = move_toward(_idle_spin, top_speed if circling else 0.0,
			top_speed * (0.5 if circling else 8.0) * delta)
	if _idle_spin > 0.0:
		_yaw = wrapf(_yaw - _idle_spin * delta, -PI, PI)
		_apply()


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	var drag_buttons := MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE
	if motion and (motion.button_mask & drag_buttons) != 0:
		_yaw -= motion.relative.x * drag_sensitivity
		_pitch = clampf(_pitch - motion.relative.y * drag_sensitivity, -1.5, 1.5)
		_apply()
		get_viewport().set_input_as_handled()
		return
	var button := event as InputEventMouseButton
	if button and button.pressed and button.is_command_or_control_pressed():
		match button.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				distance /= 1.1
			MOUSE_BUTTON_WHEEL_DOWN:
				distance *= 1.1
			_:
				return
		get_viewport().set_input_as_handled()


## Backs off far enough for a sphere of [param radius] around the orbit center
## to fill most of [member view_area] -- its height or its width, whichever is
## tighter.
func frame(radius: float) -> void:
	_framed_radius = radius
	var tan_half_height := tan(deg_to_rad(camera.fov) * 0.5)
	var tan_half_width := tan_half_height * _aspect()
	var fit_height := radius / sin(atan(tan_half_height * view_area.size.y))
	var fit_width := radius / sin(atan(tan_half_width * view_area.size.x))
	distance = maxf(fit_height, fit_width) / FILL


func _apply() -> void:
	if not is_node_ready() or camera == null:
		return
	basis = Basis.from_euler(Vector3(_pitch, _yaw, 0.0))
	camera.position = Vector3(0.0, 0.0, distance)
	# Slide the camera (not turn it) so the orbit center lands in the middle of
	# the view area. Picking stays right: Camera3D's rays include these offsets.
	var view_height := 2.0 * distance * tan(deg_to_rad(camera.fov) * 0.5)
	camera.h_offset = (0.5 - view_area.get_center().x) * view_height * _aspect()
	camera.v_offset = (view_area.get_center().y - 0.5) * view_height


func _aspect() -> float:
	var size := get_viewport().get_visible_rect().size
	return size.x / maxf(size.y, 1.0)
