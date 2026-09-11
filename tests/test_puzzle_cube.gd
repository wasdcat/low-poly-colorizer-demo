extends "res://tests/test_case.gd"

## The puzzle and the game in PuzzleCube. Every cube here turns instantly
## (turn_duration 0), so a turn is done by the time turn() returns.


func test_builds_every_size_solved() -> void:
	for n in range(PuzzleCube.MIN_SIZE, PuzzleCube.MAX_SIZE + 1):
		var cube := _new_cube(n)
		check_eq(cube.bodies.size(), n * n * n, "cubies of a %d-cube" % n)
		check_eq(cube.stickers.size(), 6 * n * n, "stickers of a %d-cube" % n)
		check(cube.is_solved(), "a new %d-cube is solved" % n)


func test_every_layer_turns_and_turns_back() -> void:
	for n in [2, 3, 4]:
		var cube := _new_cube(n)
		for axis in 3:
			for layer in range(-(n - 1), n, 2):
				var name := "%s on a %d-cube" % [cube.layer_name(axis, layer), n]
				cube.turn(axis, layer, 1)
				check(not cube.is_solved(), "unsolved after " + name)
				cube.turn(axis, layer, -1)
				check(cube.is_solved(), "solved after undoing " + name)


func test_four_quarter_turns_are_a_full_turn() -> void:
	var cube := _new_cube(3)
	for i in 4:
		cube.turn(0, 2, 1)
	check(cube.is_solved(), "R four times")


func test_turning_the_whole_cube_keeps_it_solved() -> void:
	var cube := _new_cube(3)
	for layer in [-2, 0, 2]:
		cube.turn(1, layer, 1)
	check(cube.is_solved(), "every layer of one axis turned is the cube turned as a whole")


func test_a_game_from_scramble_to_solved() -> void:
	seed(1)
	var cube := _new_cube(3)
	var solved_signals := [0]
	cube.solved.connect(func() -> void: solved_signals[0] += 1)
	cube.scramble(20)
	check(cube.is_playing(), "scramble starts a game")
	check(not cube.is_solved(), "the scramble mixes the cube up")
	check_eq(cube.moves, 0, "moves right after the scramble")
	check(not cube.can_undo(), "the scramble itself cannot be undone in a game")

	# Solve it by playing the scramble backwards, the way a player could.
	var scramble: Array = cube._history.duplicate()
	scramble.reverse()
	for move in scramble:
		cube.turn(move.axis, move.layer, -move.quarters)
	check(cube.is_solved(), "the scramble played backwards solves the cube")
	check(not cube.is_playing(), "solving ends the game")
	check_eq(cube.moves, 20, "every turn of the solve counted")
	check_eq(solved_signals[0], 1, "solved emitted")


func test_undo_in_a_game_stops_at_the_scramble() -> void:
	seed(2)
	var cube := _new_cube(3)
	cube.scramble(10)
	cube.turn(0, 2, 1)
	cube.turn(1, 2, 1)
	check_eq(cube.moves, 2, "moves after two turns")
	cube.undo()
	cube.undo()
	cube.undo()  # one more than the player made: must not touch the scramble
	check_eq(cube.moves, 0, "moves after undoing both")
	check(not cube.is_solved(), "undo never unmixes the scramble")
	check(cube.is_playing(), "undo does not end the game")

	cube.reset()
	check(cube.is_solved(), "reset rewinds everything")
	check(not cube.is_playing(), "reset ends the game")


func test_pick_finds_the_cubie_under_a_ray() -> void:
	var cube := _new_cube(3)
	var hit := cube.pick(Vector3(0, 0, 10), Vector3.FORWARD)
	check_eq(hit.face, PuzzleCube.Face.FRONT, "face of a ray from the front")
	check_eq(hit.cell, Vector3i(0, 0, 2), "cubie of a ray at the front center")

	var cubie := PuzzleCube.BODY_MESH.get_aabb().size.x
	hit = cube.pick(Vector3(cubie, cubie, 10), Vector3.FORWARD)
	check_eq(hit.cell, Vector3i(2, 2, 2), "cubie of a ray at the top right front corner")

	hit = cube.pick(Vector3(0, 10, 0), Vector3.DOWN)
	check_eq(hit.face, PuzzleCube.Face.UP, "face of a ray from above")

	hit = cube.pick(Vector3(0, 10, 10), Vector3.FORWARD)
	check_eq(hit.face, -1, "a ray passing above the cube")


func test_layer_names_follow_cube_notation() -> void:
	var cube := _new_cube(3)
	check_eq(cube.layer_name(0, 2), "R", "right layer")
	check_eq(cube.layer_name(0, -2), "L", "left layer")
	check_eq(cube.layer_name(1, 2), "U", "top layer")
	check_eq(cube.layer_name(2, -2), "B", "back layer")
	check_eq(cube.layer_name(0, 0), "M", "middle slice")
	cube.size = 5
	check_eq(cube.layer_name(0, 2), "2R", "second layer from the right on a 5-cube")
	check_eq(cube.layer_name(1, -2), "2D", "second layer from the bottom on a 5-cube")


func _new_cube(size: int) -> PuzzleCube:
	var cube := PuzzleCube.new()
	cube.turn_duration = 0.0
	cube.size = size
	add(cube)
	return cube
