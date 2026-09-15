class_name PuzzleCube
extends Node3D

## An N×N×N twisty cube, assembled at runtime from two meshes: one cubie body
## and one sticker.
##
## This script is the puzzle -- building, turning, undo, scramble, "solved?" --
## and the game on top of it: [method scramble] starts one, [member moves]
## counts it, [signal solved] ends it.
## It never decides what anything looks like; it only exposes the nodes to
## color ([member bodies], [member stickers]). That part lives in
## cube_looks.gd.
##
## The state is integers only, so it cannot drift however many turns are made:
## every cubie has a position in doubled grid coordinates (-(N-1), -(N-3) ..
## N-1, whole numbers for even N too) and an axis-aligned rotation. Node
## transforms are always derived from that state. A turn animates the layer as
## a whole on top of it and then snaps to the exact result.

## The cube was (re)built: [member bodies] and [member stickers] hold new nodes.
signal rebuilt
## The cube changed its outer size ([member size] or [member gap]).
signal layout_changed
## The last queued turn has finished.
signal settled
## A game started or ended, or its [member moves] changed; see [method is_playing].
signal game_changed
## A turn left the cube solved after [method scramble] had mixed it up.
signal solved

enum Face { UP, DOWN, FRONT, BACK, RIGHT, LEFT }

## Outward normal of each [enum Face]. FRONT faces +Z, towards a default camera.
const FACE_NORMALS: Array[Vector3i] = [
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
]
## Notation letters of the outer layers per axis: [negative end, positive end].
const LAYER_LETTERS: Array[String] = ["LR", "DU", "BF"]
## Notation letter of the middle slice per axis (odd sizes only).
const SLICE_LETTERS := "MES"

const BODY_MESH: Mesh = preload("res://assets/meshes/cubie_cube.tres")
## Lies in the XZ plane facing +Y, with its underside at y = 0.
const STICKER_MESH: Mesh = preload("res://assets/meshes/cubie_color_sticker.tres")

const MIN_SIZE := 2
const MAX_SIZE := 7
## Seconds per turn while scrambling.
const SCRAMBLE_TURN := 0.07
## Seconds [method reset] takes to rewind, however long the history is.
const RESET_TIME := 1.5

## Cubies per edge. Changing it rebuilds the cube, solved.
@export_range(MIN_SIZE, MAX_SIZE) var size: int = 3:
	set(value):
		size = clampi(value, MIN_SIZE, MAX_SIZE)
		if is_node_ready():
			build()

## Space between neighboring cubies, as a fraction of a cubie's edge.
@export_range(0.0, 1.0) var gap: float = 0.0:
	set(value):
		gap = maxf(value, 0.0)
		if is_node_ready():
			_place_all()
			layout_changed.emit()

## Seconds for an interactive quarter turn. 0 applies every turn instantly.
@export_range(0.0, 1.0) var turn_duration: float = 0.25

## Turns made since the last [method scramble] -- the score of the game it
## started. [method undo] takes one back.
var moves := 0

## Every cubie body, rebuilt by [method build].
var bodies: Array[MeshInstance3D] = []
## Every sticker. Each one is a child of the body it sits on, so it simply
## travels along when that cubie turns.
var stickers: Array[MeshInstance3D] = []
## For each entry of [member stickers], the [enum Face] it shows when solved.
var sticker_faces: PackedInt32Array = []

var _cubies: Array[Cubie] = []
var _sticker_owners: Array[Cubie] = []
var _queue: Array[Move] = []
var _history: Array[Move] = []
var _tween: Tween
var _turning := false
var _playing := false
## How long [member _history] was when the scramble ended. While a game is on,
## [method undo] stops there instead of unmixing the cube.
var _scramble_end := 0
var _cubie_size := BODY_MESH.get_aabb().size.x
var _sticker_height := STICKER_MESH.get_aabb().size.y
var _highlight: MeshInstance3D
var _highlight_axis := -1
var _highlight_layer := 0


## What a ray hits, see [method pick].
class Pick:
	## The [enum Face] the ray enters through, -1 if it misses the cube.
	var face := -1
	## Doubled grid coordinates of the cubie it hits.
	var cell := Vector3i.ZERO
	## The entry point, in the cube's local space.
	var point := Vector3.ZERO


class Cubie:
	var node: MeshInstance3D
	## Doubled grid coordinates.
	var pos: Vector3i
	## Axis-aligned, every entry exactly -1, 0 or 1.
	var rot := Basis.IDENTITY


## One layer turn. [member layer] is a doubled grid coordinate along
## [member axis] (0 = X, 1 = Y, 2 = Z); [member quarters] counts 90° steps,
## counter-clockwise seen from the positive end of that axis.
class Move:
	var axis: int
	var layer: int
	var quarters: int
	## Seconds for this turn; negative means the interactive default.
	var duration: float

	func _init(p_axis: int, p_layer: int, p_quarters: int, p_duration := -1.0) -> void:
		axis = p_axis
		layer = p_layer
		quarters = p_quarters
		duration = p_duration


func _ready() -> void:
	_highlight = _make_highlight()
	add_child(_highlight)
	build()


## Throws away all cubies and assembles a solved cube of [member size]³.
func build() -> void:
	if _tween:
		_tween.kill()
	_turning = false
	_stop_game()
	_queue.clear()
	_history.clear()
	for body in bodies:
		body.queue_free()
	_cubies.clear()
	_sticker_owners.clear()
	bodies.clear()
	stickers.clear()
	sticker_faces.clear()

	# A real cube hides a mechanism inside. Here plain bodies fill every inner
	# slot, so turning a layer never opens a view into a hollow cube.
	var edge := size - 1
	for x in range(-edge, edge + 1, 2):
		for y in range(-edge, edge + 1, 2):
			for z in range(-edge, edge + 1, 2):
				_add_cubie(Vector3i(x, y, z))
	_place_all()
	rebuilt.emit()
	layout_changed.emit()


## Queues a turn of one layer; see [PuzzleCube.Move] for the parameters.
func turn(axis: int, layer: int, quarters: int) -> void:
	if _playing:  # counted first: with turn_duration 0 the turn may end the game
		moves += 1
		game_changed.emit()
	_enqueue(Move.new(axis, layer, quarters), true)


## Queues a turn of the layer [param depth] steps in from [param face] (0 is
## the face itself), clockwise as seen looking at that face.
func turn_face(face: int, depth: int, clockwise: bool) -> void:
	var s := _dot(FACE_NORMALS[face], Vector3i.ONE)
	turn(axis_of(face), layer_of(face, depth), -s if clockwise else s)


## Takes back the most recent turn -- scramble turns included, except while a
## game is on: then only the player's own.
func undo() -> void:
	if not can_undo():
		return
	var move: Move = _history.pop_back()
	if _playing:
		moves -= 1
		game_changed.emit()
	_enqueue(Move.new(move.axis, move.layer, -move.quarters), false)


## Mixes the cube up with random turns and starts a game: [member moves]
## counts from 0 and [signal solved] fires once the cube is solved again.
## [param count] 0 picks a length that suits [member size].
func scramble(count := 0) -> void:
	if count <= 0:
		count = 7 * size
	_playing = false  # a game already on must not end halfway through the mixing
	var last_axis := -1
	for i in count:
		var axis := randi() % 3
		if axis == last_axis:  # two turns on one axis in a row could cancel out
			axis = (axis + 1 + randi() % 2) % 3
		last_axis = axis
		var layer := 2 * (randi() % size) - (size - 1)
		var quarters: int = [-1, 1, 2][randi() % 3]
		_enqueue(Move.new(axis, layer, quarters, SCRAMBLE_TURN), true)
	_playing = true
	_scramble_end = _history.size()
	moves = 0
	game_changed.emit()


## Rewinds the whole history until the cube is back where it started. Ends a
## game without solving it.
func reset() -> void:
	_stop_game()
	var duration := clampf(RESET_TIME / maxf(_history.size(), 1.0), 0.02, SCRAMBLE_TURN)
	while not _history.is_empty():
		var move: Move = _history.pop_back()
		_enqueue(Move.new(move.axis, move.layer, -move.quarters, duration), false)


func can_undo() -> bool:
	return _history.size() > (_scramble_end if _playing else 0)


func is_turning() -> bool:
	return _turning


## True from [method scramble] until the cube is solved, reset or rebuilt.
func is_playing() -> bool:
	return _playing


## True when every face shows a single color. It compares the stickers' home
## faces, not transforms, so a cube that is solved but turned as a whole
## counts too.
func is_solved() -> bool:
	var home_at := {}  # current outward normal -> home face found there
	for i in stickers.size():
		var home_normal := Vector3(FACE_NORMALS[sticker_faces[i]])
		var normal := Vector3i((_sticker_owners[i].rot * home_normal).round())
		var home: int = home_at.get(normal, sticker_faces[i])
		if home != sticker_faces[i]:
			return false
		home_at[normal] = home
	return true


## Axis (0 = X, 1 = Y, 2 = Z) that a [enum Face] is perpendicular to.
static func axis_of(face: int) -> int:
	return FACE_NORMALS[face].abs().max_axis_index()


## Doubled grid coordinate of the layer [param depth] steps in from [param face].
func layer_of(face: int, depth: int) -> int:
	var s := _dot(FACE_NORMALS[face], Vector3i.ONE)
	return s * (size - 1 - 2 * clampi(depth, 0, size - 1))


## Half the cube's edge length at rest, stickers included.
func half_extent() -> float:
	return (size - 1) * _pitch() * 0.5 + _cubie_size * 0.5 + _sticker_height


## Cube notation for a layer: the face letter for an outer one (R, U, F ...),
## a number in front for those further in (2R, 3R ...), and M / E / S for the
## middle slice of an odd-sized cube.
func layer_name(axis: int, layer: int) -> String:
	if layer == 0:
		return SLICE_LETTERS[axis]
	var letter := LAYER_LETTERS[axis][1 if layer > 0 else 0]
	@warning_ignore("integer_division")
	var depth := (size - 1 - absi(layer)) / 2  # always even, so exact
	return letter if depth == 0 else "%d%s" % [depth + 1, letter]


## What a ray (in global space) hits first: the face it enters the cube
## through, the cubie there and the entry point. A plain ray-vs-box test --
## no physics bodies, no colliders.
func pick(from: Vector3, direction: Vector3) -> Pick:
	var hit := Pick.new()
	var inverse := global_transform.affine_inverse()
	var origin := inverse * from
	var dir := inverse.basis * direction
	var half := half_extent()
	var t_enter := -INF
	var t_exit := INF
	for axis in 3:
		if is_zero_approx(dir[axis]):
			if absf(origin[axis]) > half:
				hit.face = -1  # parallel to this slab and outside it: a miss
				return hit
			continue
		var t_neg := (-half - origin[axis]) / dir[axis]
		var t_pos := (half - origin[axis]) / dir[axis]
		if minf(t_neg, t_pos) > t_enter:
			t_enter = minf(t_neg, t_pos)
			var normal := Vector3i.ZERO
			normal[axis] = 1 if t_pos < t_neg else -1
			hit.face = FACE_NORMALS.find(normal)
		t_exit = minf(t_exit, maxf(t_neg, t_pos))
	if t_enter > t_exit or t_exit < 0.0:
		hit.face = -1
		return hit
	hit.point = origin + dir * t_enter
	var normal_axis := axis_of(hit.face)
	var cell := Vector3i.ZERO
	for axis in 3:
		if axis == normal_axis:
			cell[axis] = FACE_NORMALS[hit.face][axis] * (size - 1)
		else:
			var index := clampi(floori(hit.point[axis] / _pitch() + size * 0.5), 0, size - 1)
			cell[axis] = 2 * index - (size - 1)
	hit.cell = cell
	return hit


## Outlines the layer at doubled grid coordinate [param layer] along
## [param axis]; axis -1 hides the outline.
func highlight_layer(axis: int, layer: int) -> void:
	_highlight_axis = axis
	_highlight_layer = layer
	_update_highlight()


func _add_cubie(pos: Vector3i) -> void:
	var cubie := Cubie.new()
	cubie.pos = pos
	cubie.node = MeshInstance3D.new()
	cubie.node.mesh = BODY_MESH
	add_child(cubie.node)
	_cubies.append(cubie)
	bodies.append(cubie.node)
	# A sticker on every side that faces outwards. How many that are is all
	# that makes a cubie a corner (3), an edge (2), a center (1) or an inner
	# one (0) -- the three types need no code of their own.
	for face in FACE_NORMALS.size():
		var normal := FACE_NORMALS[face]
		if _dot(pos, normal) != size - 1:
			continue
		var sticker := MeshInstance3D.new()
		sticker.mesh = STICKER_MESH
		sticker.transform = _sticker_transform(normal)
		cubie.node.add_child(sticker)
		stickers.append(sticker)
		sticker_faces.append(face)
		_sticker_owners.append(cubie)


## Stands the sticker (modeled facing +Y) up on the cubie side with outward
## [param normal]. It is square, so how it is rolled around that axis does
## not matter.
func _sticker_transform(normal: Vector3i) -> Transform3D:
	var up := Vector3(normal)
	var side := Vector3.RIGHT if normal.x == 0 else Vector3.BACK
	return Transform3D(Basis(side, up, side.cross(up)), up * _cubie_size * 0.5)


func _place_all() -> void:
	for cubie in _cubies:
		cubie.node.transform = _rest_transform(cubie)
	_update_highlight()


func _rest_transform(cubie: Cubie) -> Transform3D:
	return Transform3D(cubie.rot, Vector3(cubie.pos) * _pitch() * 0.5)


## Center-to-center distance of neighboring cubies.
func _pitch() -> float:
	return _cubie_size * (1.0 + gap)


func _enqueue(move: Move, record: bool) -> void:
	if record:
		_history.append(move)
	_queue.append(move)
	if not _turning:
		_next_turn()


func _next_turn() -> void:
	while not _queue.is_empty():
		var move: Move = _queue.pop_front()
		var members := _layer_members(move.axis, move.layer)
		var duration := _duration_of(move)
		if duration <= 0.0:
			_commit(move, members)
			continue
		_turning = true
		_animate(move, members, duration)
		return
	_turning = false
	settled.emit()
	if _playing and is_solved():
		_stop_game()
		solved.emit()


func _stop_game() -> void:
	if _playing:
		_playing = false
		game_changed.emit()


func _layer_members(axis: int, layer: int) -> Array[Cubie]:
	var members: Array[Cubie] = []
	for cubie in _cubies:
		if cubie.pos[axis] == layer:
			members.append(cubie)
	return members


func _duration_of(move: Move) -> float:
	if turn_duration <= 0.0:
		return 0.0
	if move.duration >= 0.0:
		return move.duration
	# A half turn takes a little longer; a backlog of wheel clicks catches up.
	return turn_duration * sqrt(float(absi(move.quarters))) / (1.0 + 0.5 * _queue.size())


## Rotates the whole layer around the cube's center -- a real turn, the
## stickers ride along on their cubies and keep their looks.
func _animate(move: Move, members: Array[Cubie], duration: float) -> void:
	var axis := Vector3.ZERO
	axis[move.axis] = 1.0
	var starts: Array[Transform3D] = []
	for cubie in members:
		starts.append(cubie.node.transform)
	var spin := func(angle: float) -> void:
		var spin_transform := Transform3D(Basis(axis, angle), Vector3.ZERO)
		for i in members.size():
			members[i].node.transform = spin_transform * starts[i]
	var finish := func() -> void:
		_commit(move, members)
		_next_turn()
	_tween = create_tween()
	if move.duration < 0.0:
		# A small overshoot that settles back: the click of a real cube.
		_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(spin, 0.0, move.quarters * PI / 2.0, duration)
	_tween.tween_callback(finish)


## Applies [param move] to the integer state and snaps the nodes onto it.
func _commit(move: Move, members: Array[Cubie]) -> void:
	var axis := Vector3.ZERO
	axis[move.axis] = 1.0
	var q := _snapped(Basis(axis, move.quarters * PI / 2.0))
	for cubie in members:
		cubie.pos = Vector3i((q * Vector3(cubie.pos)).round())
		cubie.rot = _snapped(q * cubie.rot)
		cubie.node.transform = _rest_transform(cubie)


func _update_highlight() -> void:
	if _highlight == null:
		return
	_highlight.visible = _highlight_axis >= 0
	if _highlight_axis < 0:
		return
	var margin := _cubie_size * 0.05
	var extent := Vector3.ONE * (half_extent() * 2.0 + margin)
	extent[_highlight_axis] = _cubie_size + _sticker_height * 2.0 + margin
	var center := Vector3.ZERO
	center[_highlight_axis] = _highlight_layer * _pitch() * 0.5
	_highlight.transform = Transform3D(Basis.from_scale(extent), center)


## A unit box drawn as lines; scaled onto the picked layer.
func _make_highlight() -> MeshInstance3D:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for axis in 3:
		for a in [-0.5, 0.5]:
			for b in [-0.5, 0.5]:
				var from := Vector3.ZERO
				from[(axis + 1) % 3] = a
				from[(axis + 2) % 3] = b
				var to := from
				from[axis] = -0.5
				to[axis] = 0.5
				mesh.surface_add_vertex(from)
				mesh.surface_add_vertex(to)
	mesh.surface_end()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 1.0, 1.0, 0.9)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func _dot(a: Vector3i, b: Vector3i) -> int:
	return a.x * b.x + a.y * b.y + a.z * b.z


## Rounds an axis-aligned rotation to exact -1 / 0 / 1 entries.
static func _snapped(b: Basis) -> Basis:
	return Basis(b.x.round(), b.y.round(), b.z.round())
