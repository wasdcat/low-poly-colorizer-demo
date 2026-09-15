extends "res://tests/test_case.gd"

## Tests for DemoMode (Attract Mode / Showroom).

const MAIN_SCENE := preload("res://main.tscn")


func test_demo_mode_starts_at_launch() -> void:
	var main := add(MAIN_SCENE.instantiate())
	var demo: DemoMode = main.get_node("DemoMode")
	var rig: OrbitCamera = main.get_node("CameraRig")
	check(demo.active, "demo mode is active at launch")
	check(rig.demo_mode, "orbit camera is in demo mode at launch")


func test_demo_mode_stops_on_key_input() -> void:
	var main := add(MAIN_SCENE.instantiate())
	var demo: DemoMode = main.get_node("DemoMode")
	var rig: OrbitCamera = main.get_node("CameraRig")
	check(demo.active, "demo mode initially active")

	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.keycode = KEY_SPACE
	demo._input(key_event)

	check(not demo.active, "demo mode stopped after key press")
	check(not rig.demo_mode, "orbit camera demo mode disabled after key press")


func test_demo_mode_stops_on_mouse_input() -> void:
	var main := add(MAIN_SCENE.instantiate())
	var demo: DemoMode = main.get_node("DemoMode")
	var rig: OrbitCamera = main.get_node("CameraRig")

	# Mouse motion
	demo.start()
	check(demo.active, "demo mode restarted")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(10.0, 5.0)
	demo._input(motion)
	check(not demo.active, "demo mode stopped after mouse motion")

	# Mouse click
	demo.start()
	check(demo.active, "demo mode restarted")
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	demo._input(click)
	check(not demo.active, "demo mode stopped after mouse button")


func test_demo_mode_activates_after_idle_timeout() -> void:
	var main := add(MAIN_SCENE.instantiate())
	var demo: DemoMode = main.get_node("DemoMode")
	demo.stop()
	check(not demo.active, "demo mode stopped")

	demo.idle_timeout = 0.2
	demo._process(0.1)
	check(not demo.active, "still inactive before timeout")
	demo._process(0.15)
	check(demo.active, "activated after idle timeout")


func test_demo_mode_does_not_activate_in_game() -> void:
	var main := add(MAIN_SCENE.instantiate())
	var cube: PuzzleCube = main.get_node("Cube")
	cube.turn_duration = 0.0
	var demo: DemoMode = main.get_node("DemoMode")
	demo.stop()

	# Start a game
	cube.scramble(2)
	check(cube.is_playing(), "game is in progress")

	demo.idle_timeout = 0.1
	demo._process(0.5)
	check(not demo.active, "demo mode does NOT activate during a game round")


func test_demo_mode_slides_gap_and_restores_state() -> void:
	var main := add(MAIN_SCENE.instantiate())
	var cube: PuzzleCube = main.get_node("Cube")
	cube.turn_duration = 0.0
	var demo: DemoMode = main.get_node("DemoMode")

	# Run a few frames in demo mode
	demo.size_interval = 0.1
	demo._process(0.05)
	check(cube.gap > 0.0, "gap is oscillating during demo mode")

	demo._process(0.1) # trigger size change
	check(demo.active, "demo mode still active")

	# Now stop demo mode
	demo.stop()
	check(not demo.active, "demo mode stopped")
	check_eq(cube.size, 3, "cube size restored to UI default (3)")
	check_eq(cube.gap, 0.0, "cube gap restored to UI default (0.0)")

