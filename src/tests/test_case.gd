extends RefCounted

## Base of every test file: the scene tree to add nodes to, and checks that
## record a failure and let the test carry on. See run_tests.gd.

var tree: SceneTree
var failures: PackedStringArray = []

var _nodes: Array[Node] = []


## Adds [param node] to the running scene tree, which calls its _ready(). It is
## freed when the test ends.
func add(node: Node) -> Node:
	tree.root.add_child(node)
	_nodes.append(node)
	return node


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func check_eq(actual: Variant, expected: Variant, message: String) -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s: expected %s, got %s" % [message, expected, actual])


func free_nodes() -> void:
	for node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
