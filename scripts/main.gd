extends Node3D

## Mouse control for the cube, all of it on the sticker under the cursor:
##
## - wheel: rolls the surface under the cursor up or down, i.e. turns the
##   column through that sticker -- middle slices included;
## - Shift + wheel (or a horizontal scroll): rolls it sideways, the row;
## - Alt + wheel: spins the face the sticker is on.
##
## Which of the two layers through a sticker counts as its column and which as
## its row is decided on screen, from how each would move it, so it holds from
## any viewing angle. Ctrl + Z undoes.

@export var cube: RubiksCube
@export var rig: OrbitCamera
## Reverses every wheel direction.
@export var invert_wheel := false

var _hover: RubiksCube.Pick
var _column := Roll.new()
var _row := Roll.new()
var _wheel := 0.0
var _mouse := Vector2.ZERO
var _mouse_over_view := false
var _highlighted := Vector2i(-1, 0)


## A layer the wheel can turn, and the quarter turn that moves the surface
## under the cursor up (for the column) or to the right (for the row).
class Roll:
	var axis := -1
	var layer := 0
	var quarters := 1


func _ready() -> void:
	cube.layout_changed.connect(_on_cube_layout_changed)
	_on_cube_layout_changed()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_mouse_over_view = false


func _input(event: InputEvent) -> void:
	# _input runs before the GUI, _unhandled_input only for what the GUI left
	# over -- between the two we know whether the mouse is over a panel.
	if event is InputEventMouseMotion:
		_mouse_over_view = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse = event.position
		_mouse_over_view = true
	elif event is InputEventMouseButton and event.pressed:
		_on_wheel(event)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_Z and event.is_command_or_control_pressed():
		cube.undo()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	# Picked every frame: orbiting and turning change what is under the mouse.
	var hover: RubiksCube.Pick = null
	var camera := get_viewport().get_camera_3d()
	if _mouse_over_view and camera:
		var hit := cube.pick(camera.project_ray_origin(_mouse), camera.project_ray_normal(_mouse))
		if hit.face >= 0:
			hover = hit
			_aim(hit, camera)
	if hover == null or _hover == null or hover.cell != _hover.cell or hover.face != _hover.face:
		_wheel = 0.0
	_hover = hover
	_show_target()


func _on_wheel(event: InputEventMouseButton) -> void:
	var vertical := event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
	var horizontal := event.button_index in [MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]
	if not (vertical or horizontal):
		return
	get_viewport().set_input_as_handled()
	if _hover == null:
		return
	# +1 for up / left, -1 for down / right. Touchpads send many fractional
	# steps; only whole ones turn a layer.
	var step := 1.0 if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT] else -1.0
	if invert_wheel:
		step = -step
	_wheel += step * (event.factor if event.factor > 0.0 else 1.0)
	while absf(_wheel) >= 1.0:
		var direction := int(signf(_wheel))
		_wheel -= direction
		if event.alt_pressed:
			cube.turn_face(_hover.face, 0, direction > 0)
		elif horizontal or event.shift_pressed:
			# macOS reports Shift + wheel as horizontal scrolling. Up / left
			# moves the surface to the left.
			cube.turn(_row.axis, _row.layer, -_row.quarters * direction)
		else:
			cube.turn(_column.axis, _column.layer, _column.quarters * direction)


## Of the two layers through the hovered sticker, the one that moves it more
## up/down on screen becomes the wheel's column, the other one Shift's row.
func _aim(hit: RubiksCube.Pick, camera: Camera3D) -> void:
	var normal_axis := RubiksCube.axis_of(hit.face)
	var point := cube.global_transform * hit.point
	var first := (normal_axis + 1) % 3
	var second := (normal_axis + 2) % 3
	var first_motion := _screen_motion(first, point, camera)
	var second_motion := _screen_motion(second, point, camera)
	var first_is_column := absf(first_motion.normalized().y) >= absf(second_motion.normalized().y)
	var column_axis := first if first_is_column else second
	var row_axis := second if first_is_column else first
	var column_motion := first_motion if first_is_column else second_motion
	var row_motion := second_motion if first_is_column else first_motion
	_column.axis = column_axis
	_column.layer = hit.cell[column_axis]
	_column.quarters = 1 if column_motion.y < 0.0 else -1  # screen y grows downwards
	_row.axis = row_axis
	_row.layer = hit.cell[row_axis]
	_row.quarters = 1 if row_motion.x > 0.0 else -1


## Where [param point] heads on screen when its layer starts turning the
## positive way around the cube's [param axis].
func _screen_motion(axis: int, point: Vector3, camera: Camera3D) -> Vector2:
	var center := cube.global_position
	var velocity := cube.global_transform.basis[axis].normalized().cross(point - center)
	return camera.unproject_position(point + velocity * 0.01) - camera.unproject_position(point)


## Outlines the layer the next wheel click would turn -- that depends on the
## modifier keys held right now.
func _show_target() -> void:
	var target := Vector2i(-1, 0)
	if _hover:
		if Input.is_key_pressed(KEY_ALT):
			target = Vector2i(RubiksCube.axis_of(_hover.face), cube.layer_of(_hover.face, 0))
		elif Input.is_key_pressed(KEY_SHIFT):
			target = Vector2i(_row.axis, _row.layer)
		else:
			target = Vector2i(_column.axis, _column.layer)
	if target != _highlighted:
		_highlighted = target
		cube.highlight_layer(target.x, target.y)


func _on_cube_layout_changed() -> void:
	_highlighted = Vector2i(-2, 0)  # force the outline onto the new layout
	if rig:
		rig.frame(cube.half_extent() * sqrt(3.0))
