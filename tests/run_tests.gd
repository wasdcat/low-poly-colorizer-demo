extends SceneTree

## Runs every test_*.gd file in this folder and quits with exit code 1 if
## anything failed:
##
##     godot --headless --script res://tests/run_tests.gd
##
## A test file extends test_case.gd. Each of its methods named test_* is one
## test and runs on a fresh instance of the file.

const DIR := "res://tests/"


func _initialize() -> void:
	# root is not in the tree yet during _initialize().
	_run.call_deferred()


func _run() -> void:
	var passed := 0
	var failed := 0
	for file in DirAccess.get_files_at(DIR):
		if not (file.begins_with("test_") and file.ends_with(".gd")) or file == "test_case.gd":
			continue
		var script := load(DIR + file) as GDScript
		if script == null or not script.can_instantiate():
			printerr("FAIL  %s does not load" % file)
			failed += 1
			continue
		for method in script.get_script_method_list():
			var test: String = method.name
			if not test.begins_with("test_"):
				continue
			var case: RefCounted = script.new()
			case.tree = self
			await case.call(test)
			case.free_nodes()
			if case.failures.is_empty():
				print("ok    %s  %s" % [file, test])
				passed += 1
			else:
				printerr("FAIL  %s  %s" % [file, test])
				for failure in case.failures:
					printerr("        " + failure)
				failed += 1
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 or passed == 0 else 0)
