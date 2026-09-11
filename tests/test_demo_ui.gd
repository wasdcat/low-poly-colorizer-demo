extends "res://tests/test_case.gd"

## The side panel, wired up in the real main scene.

const MAIN_SCENE := preload("res://main.tscn")


func test_one_game_at_a_time() -> void:
	var main := add(MAIN_SCENE.instantiate())
	var cube: PuzzleCube = main.get_node("Cube")
	cube.turn_duration = 0.0
	var ui := main.get_node("UI/Panel")
	var play: Button = ui._play
	var reset: Button = ui._reset
	check(not play.disabled and reset.disabled, "before a game: Scramble on, Reset off")

	play.pressed.emit()
	check(play.disabled and not reset.disabled, "in a game: Scramble off, Reset on")
	cube.turn(0, cube.size - 1, 1)
	check(play.disabled, "turning does not unlock Scramble")

	reset.pressed.emit()
	check(not play.disabled and reset.disabled, "after Reset: Scramble on, Reset off")

	play.pressed.emit()
	var scramble: Array = cube._history.duplicate()
	scramble.reverse()
	for move in scramble:
		cube.turn(move.axis, move.layer, -move.quarters)
	check(cube.is_solved(), "the scramble played backwards solves the cube")
	check(not play.disabled and reset.disabled, "after solving: Scramble on, Reset off")
