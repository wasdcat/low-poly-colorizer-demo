class_name CubeLooks
extends Node

## Everything Low Poly Colorizer does in this demo happens in this script.
##
## Bodies and stickers all share ONE material, lpc_singlecolor.tres, assigned in
## the two meshes. They can still all look different, because palette cell,
## preset and emission are *instance* uniforms: they sit on each
## MeshInstance3D, not on the material. Changing a look is four
## set_instance_shader_parameter() calls (that is all
## LpcSinglecolorResource.apply_to() does): no material duplicates, no shader
## recompiles.
##
## Nothing here ever writes into a look's .tres. Those resources are shared --
## modifying one would change every user of it -- so shifted or re-preset
## looks are always fresh copies.

## Something changed what the cube shows.
signal looks_changed

## Where the stickers' presets come from.
enum PresetMode {
	SCHEME,              ## Whatever each look of the scheme says.
	UNIFORM,             ## [member preset] on every sticker.
	RANDOM_PER_FACE,     ## One random preset per face.
	RANDOM_PER_STICKER,  ## One random preset per sticker.
}

@export var cube: RubiksCube
## The schemes to choose from; the demo offers a random one on top.
@export var schemes: Array[CubeScheme] = []
## The body looks to choose from.
@export var body_looks: Array[LpcSinglecolorResource] = []

## The scheme the stickers show.
var scheme: CubeScheme:
	set(value):
		scheme = value
		apply()

## The look every cubie body gets.
var body_look: LpcSinglecolorResource:
	set(value):
		body_look = value
		apply()

## Steps every hue column around the color wheel; the greyscale column stays.
var hue_shift := 0:
	set(value):
		hue_shift = value
		apply()

## Moves every look along the palette's rows: negative is lighter, positive
## darker (row 0 is the lightest).
var row_shift := 0:
	set(value):
		row_shift = value
		apply()

## Set both through [method set_preset_mode].
var preset_mode := PresetMode.SCHEME
var preset := LpcSinglecolorResource.Preset.SOLID

## The one material all bodies and stickers share. Its plain (non-instance)
## uniforms reach every node at once -- the counterpart to the looks.
var shared_material := RubiksCube.BODY_MESH.surface_get_material(0) as ShaderMaterial

var _face_presets := PackedInt32Array()
var _sticker_presets := PackedInt32Array()


func _ready() -> void:
	cube.rebuilt.connect(_on_cube_rebuilt)
	if body_look == null and not body_looks.is_empty():
		body_look = body_looks[0]
	if scheme == null and not schemes.is_empty():
		scheme = schemes[0]
	set_preset_mode(PresetMode.SCHEME)


## Chooses where presets come from. The random modes roll new presets on every
## call; [param uniform_preset] is used by [constant PresetMode.UNIFORM].
func set_preset_mode(mode: PresetMode, uniform_preset := LpcSinglecolorResource.Preset.SOLID) -> void:
	preset_mode = mode
	preset = uniform_preset
	_face_presets = _roll_presets(RubiksCube.FACE_NORMALS.size())
	_sticker_presets = _roll_presets(cube.stickers.size())
	apply()


## Pushes the current choices onto every body and sticker of the cube.
func apply() -> void:
	if cube == null or scheme == null:
		return
	var looks := face_looks()
	for i in cube.stickers.size():
		var sticker := cube.stickers[i]
		looks[cube.sticker_faces[i]].apply_to(sticker)
		if preset_mode == PresetMode.RANDOM_PER_STICKER and i < _sticker_presets.size():
			# A single instance uniform can also be set on its own.
			sticker.set_instance_shader_parameter(&"lpc_preset_position", _sticker_presets[i])
	if body_look:
		for body in cube.bodies:
			body_look.apply_to(body)
	looks_changed.emit()


## The six looks the faces show right now, in [enum RubiksCube.Face] order:
## the scheme's looks with the palette shifts and the preset choice applied.
## Fresh copies every call -- the scheme's own resources are never touched.
func face_looks() -> Array[LpcSinglecolorResource]:
	var looks: Array[LpcSinglecolorResource] = []
	for face in RubiksCube.FACE_NORMALS.size():
		var base := scheme.get_look(face)
		var look := base.duplicate() as LpcSinglecolorResource if base else LpcSinglecolorResource.new()
		look.palette_cell_x = shift_column(look.palette_cell_x, hue_shift)
		look.palette_cell_y = clampi(look.palette_cell_y + row_shift, 0, LpcSinglecolorResource.PALETTE_ROWS - 1)
		match preset_mode:
			PresetMode.UNIFORM:
				look.preset = preset
			PresetMode.RANDOM_PER_FACE:
				look.preset = _face_presets[face] as LpcSinglecolorResource.Preset
		looks.append(look)
	return looks


## A playable scheme rolled at random: six hues spread evenly around the color
## wheel from a random start, all in one random row -- distinct enough to solve.
## Built from the palette constants LPC exports alongside the look resource.
func random_scheme() -> CubeScheme:
	var first := _first_hue_column()
	var hues := LpcSinglecolorResource.PALETTE_COLS - first
	var start := randi() % hues
	var row := randi_range(2, LpcSinglecolorResource.PALETTE_ROWS - 3)
	var faces := range(RubiksCube.FACE_NORMALS.size())
	faces.shuffle()
	var rolled := CubeScheme.new()
	rolled.resource_name = "Random"
	for i in faces.size():
		var look := LpcSinglecolorResource.new()
		look.palette_cell_x = first + (start + roundi(i * hues / float(faces.size()))) % hues
		look.palette_cell_y = row
		rolled.set_look(faces[i], look)
	return rolled


## Material-wide: scales the emission of every node at once.
func set_emission_factor(value: float) -> void:
	shared_material.set_shader_parameter(&"emission_factor", value)


## Material-wide: the clearcoat's roughness on every node at once.
func set_clearcoat_roughness(value: float) -> void:
	shared_material.set_shader_parameter(&"clearcoat_roughness_value", value)


## Rotates a hue column around the color wheel. The greyscale column is not
## part of the wheel and stays where it is.
static func shift_column(x: int, steps: int) -> int:
	var first := _first_hue_column()
	if x < first:
		return x
	var hues := LpcSinglecolorResource.PALETTE_COLS - first
	return first + posmod(x - first + steps, hues)


## How [param look] reads on screen, for a UI swatch. The palette holds linear
## values -- the shader feeds them to ALBEDO as they are -- while a Control
## draws its Color as sRGB, so the raw get_color() would come out too dark.
static func display_color(look: LpcSinglecolorResource) -> Color:
	return look.get_color().linear_to_srgb()


static func _first_hue_column() -> int:
	return 1 if LpcSinglecolorResource.PALETTE_HAS_GREYSCALE else 0


static func _roll_presets(count: int) -> PackedInt32Array:
	var rolled := PackedInt32Array()
	for i in count:
		rolled.append(randi() % LpcSinglecolorResource.Preset.size())
	return rolled


func _on_cube_rebuilt() -> void:
	# New stickers, so per-sticker presets need rolling again.
	_sticker_presets = _roll_presets(cube.stickers.size())
	apply()
