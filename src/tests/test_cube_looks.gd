extends "res://tests/test_case.gd"

## CubeLooks and the look resources it is fed with.

const MAIN_SCENE := preload("res://main.tscn")
const SCHEME_DIR := "res://looks/schemes/"


func test_every_scheme_shows_six_different_faces() -> void:
	for scheme in _scheme_files():
		var seen := {}
		for face in PuzzleCube.FACE_NORMALS.size():
			var look := scheme.get_look(face)
			if look == null:
				check(false, "%s has no look for face %d" % [scheme.resource_path, face])
				continue
			seen[_key(look)] = true
		check_eq(seen.size(), 6, "different faces in " + scheme.resource_path)


func test_the_demo_offers_every_scheme() -> void:
	var main := MAIN_SCENE.instantiate()
	var looks: CubeLooks
	for node in main.find_children("*", "", true, false):
		if node is CubeLooks:
			looks = node
	check(looks != null, "main.tscn has a CubeLooks node")
	if looks:
		for scheme in _scheme_files():
			check(looks.schemes.has(scheme), scheme.resource_path + " is offered in the demo")
		check(not looks.body_looks.is_empty(), "the demo offers body looks")
	main.free()


func test_apply_puts_each_face_look_on_its_stickers() -> void:
	var looks := _new_looks()
	var face_looks := looks.face_looks()
	for i in looks.cube.stickers.size():
		var sticker := looks.cube.stickers[i]
		var look := face_looks[looks.cube.sticker_faces[i]]
		if sticker.get_instance_shader_parameter(&"lpc_palette_cell_x") != look.palette_cell_x \
				or sticker.get_instance_shader_parameter(&"lpc_palette_cell_y") != look.palette_cell_y:
			check(false, "sticker %d does not show the look of its face" % i)
			return
	for body in looks.cube.bodies:
		if body.get_instance_shader_parameter(&"lpc_palette_cell_x") != looks.body_look.palette_cell_x:
			check(false, "a body does not show the body look")
			return


func test_uniform_preset_reaches_every_sticker() -> void:
	var looks := _new_looks()
	looks.set_preset_mode(CubeLooks.PresetMode.UNIFORM, LpcSinglecolorResource.Preset.METALLIC)
	for sticker in looks.cube.stickers:
		if sticker.get_instance_shader_parameter(&"lpc_preset_position") != LpcSinglecolorResource.Preset.METALLIC:
			check(false, "a sticker missed the uniform preset")
			return


func test_shifts_and_presets_leave_the_schemes_untouched() -> void:
	var looks := _new_looks()
	var before := _keys(looks.scheme)
	looks.hue_shift = 5
	looks.row_shift = 2
	looks.set_preset_mode(CubeLooks.PresetMode.UNIFORM, LpcSinglecolorResource.Preset.EMISSION)
	looks.set_preset_mode(CubeLooks.PresetMode.RANDOM_PER_FACE)
	check_eq(_keys(looks.scheme), before, "the scheme's looks after shifting and re-presetting")


func test_hue_shift_wraps_around_the_wheel() -> void:
	var hues := LpcSinglecolorResource.PALETTE_COLS - 1
	check_eq(CubeLooks.shift_column(0, 3), 0, "the greyscale column stays")
	check_eq(CubeLooks.shift_column(1, hues), 1, "a full turn of the wheel")
	check_eq(CubeLooks.shift_column(1, -1), LpcSinglecolorResource.PALETTE_COLS - 1, "one step back from the first hue")


func test_random_schemes_are_always_playable() -> void:
	seed(3)
	var looks := _new_looks()
	for i in 100:
		var scheme := looks.random_scheme()
		var seen := {}
		for face in PuzzleCube.FACE_NORMALS.size():
			seen[_key(scheme.get_look(face))] = true
		if seen.size() != 6:
			check(false, "random scheme %d repeats a look" % i)
			return


func _new_looks() -> CubeLooks:
	var cube := PuzzleCube.new()
	cube.turn_duration = 0.0
	add(cube)
	var looks := CubeLooks.new()
	looks.cube = cube
	looks.schemes = _scheme_files()
	looks.body_looks.append(load("res://looks/body/black.tres"))
	add(looks)
	return looks


func _scheme_files() -> Array[CubeScheme]:
	var schemes: Array[CubeScheme] = []
	for file in DirAccess.get_files_at(SCHEME_DIR):
		if file.ends_with(".tres"):
			schemes.append(load(SCHEME_DIR + file))
	return schemes


## What tells two looks apart on the cube.
func _key(look: LpcSinglecolorResource) -> Array:
	return [look.palette_cell_x, look.palette_cell_y, look.preset, look.emission_override]


func _keys(scheme: CubeScheme) -> Array:
	var keys := []
	for face in PuzzleCube.FACE_NORMALS.size():
		keys.append(_key(scheme.get_look(face)))
	return keys
