class_name CubeScheme
extends Resource

## A color scheme for [PuzzleCube]: one named look per face.
##
## Every slot is an [LpcSinglecolorResource] -- a palette cell plus a preset --
## so a scheme can make faces shine or glow as well as color them. Author new
## schemes as .tres files in the inspector and add them to CubeLooks.schemes;
## the scheme's [member Resource.resource_name] is what the demo's menu shows.

## Slot property per [enum PuzzleCube.Face], in that enum's order.
const SLOTS: Array[StringName] = [&"up", &"down", &"front", &"back", &"right", &"left"]

@export var up: LpcSinglecolorResource
@export var down: LpcSinglecolorResource
@export var front: LpcSinglecolorResource
@export var back: LpcSinglecolorResource
@export var right: LpcSinglecolorResource
@export var left: LpcSinglecolorResource


## The look of a [enum PuzzleCube.Face].
func get_look(face: int) -> LpcSinglecolorResource:
	return get(SLOTS[face])


func set_look(face: int, look: LpcSinglecolorResource) -> void:
	set(SLOTS[face], look)
