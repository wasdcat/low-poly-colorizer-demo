class_name DemoMode
extends Node

## Manages the attract / demo showroom mode.
##
## Activated on launch and after 20 seconds of idle time outside a game round.
## Deactivated immediately by any key press, mouse click or mouse motion.
## During an active game round, demo mode stays disabled and OrbitCamera's simple
## horizontal idle spin is used instead.
##
## While active, DemoMode:
## - orbits the camera dynamically across all 3 axes (yaw, pitch, roll);
## - oscillates the cube's cubie gap smoothly;
## - periodically changes the cube's size (e.g. between 2 and 5);
## - periodically cycles the sticker color schemes and body looks.

signal demo_mode_started
signal demo_mode_stopped

@export var cube: PuzzleCube
@export var rig: OrbitCamera
@export var looks: CubeLooks
@export var ui: Control

## Inactivity time in seconds outside of a game before demo mode starts.
@export var idle_timeout := 20.0
## Seconds between cube size changes in demo mode.
@export var size_interval := 5.0
## Seconds between color scheme changes in demo mode.
@export var color_interval := 3.5

var active := false

var _idle_time := 0.0
var _demo_time := 0.0
var _size_timer := 0.0
var _color_timer := 0.0
var _size_sequence: Array[int] = [3, 4, 2, 5]
var _size_index := 0
var _scheme_index := 0
var _body_index := 0


func _ready() -> void:
	# Activate demo mode on application startup.
	start()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		_on_user_activity()
	elif event is InputEventMouseButton and event.pressed:
		_on_user_activity()
	elif event is InputEventMouseMotion and event.relative.length_squared() > 4.0:
		_on_user_activity()


func _process(delta: float) -> void:
	if cube and cube.is_playing():
		if active:
			stop()
		_idle_time = 0.0
		return

	if not active:
		_idle_time += delta
		if _idle_time >= idle_timeout:
			start()
		return

	_demo_time += delta

	# 1. Slide gap smoothly back and forth.
	if cube:
		cube.gap = 0.05 + 0.22 * (sin(_demo_time * 2.2) * 0.5 + 0.5)

	# 2. Cycle cube size periodically.
	_size_timer += delta
	if _size_timer >= size_interval:
		_size_timer = 0.0
		_size_index = (_size_index + 1) % _size_sequence.size()
		if cube:
			cube.size = _size_sequence[_size_index]

	# 3. Cycle color schemes and body looks periodically.
	_color_timer += delta
	if _color_timer >= color_interval:
		_color_timer = 0.0
		_next_looks()

	# 4. Fancy multi-axis camera motion.
	if rig:
		rig.update_demo_motion(delta, _demo_time)


## Starts the demo mode.
func start() -> void:
	if active:
		return
	if cube and cube.is_playing():
		return
	active = true
	_demo_time = 0.0
	_size_timer = 0.0
	_color_timer = 0.0
	if rig:
		rig.set_demo_mode(true)
	demo_mode_started.emit()


## Stops the demo mode and restores the user's settings.
func stop() -> void:
	if not active:
		return
	active = false
	_idle_time = 0.0
	if rig:
		rig.set_demo_mode(false)
	if ui and ui.has_method("restore_cube_state"):
		ui.restore_cube_state()
	elif cube:
		cube.gap = 0.0
	demo_mode_stopped.emit()


func _on_user_activity() -> void:
	_idle_time = 0.0
	if active:
		stop()


func _next_looks() -> void:
	if looks == null:
		return
	if not looks.schemes.is_empty():
		_scheme_index = (_scheme_index + 1) % (looks.schemes.size() + 1)
		if _scheme_index < looks.schemes.size():
			looks.scheme = looks.schemes[_scheme_index]
		else:
			looks.scheme = looks.random_scheme()
	if not looks.body_looks.is_empty():
		_body_index = (_body_index + 1) % looks.body_looks.size()
		looks.body_look = looks.body_looks[_body_index]
	looks.apply()

