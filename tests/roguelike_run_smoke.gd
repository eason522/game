extends SceneTree

const MapGeneratorScript := preload("res://scripts/roguelike/MapGenerator.gd")
const RunStateScript := preload("res://scripts/roguelike/RunState.gd")

var failures: Array = []


func _init() -> void:
	_run()

	if failures.is_empty():
		print("Roguelike run smoke tests passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)

	quit(1)


func _run() -> void:
	_assert_linear_route_shape()
	_assert_victories_unlock_boss()
	_assert_defeat_locks_run()
	_assert_state_roundtrip()


func _assert_linear_route_shape() -> void:
	var generator := MapGeneratorScript.new()
	var nodes := generator.generate_linear_route()

	if nodes.size() != 5:
		failures.append("run route: expected 5 linear nodes")
		return

	if nodes[0].get("type", "") != RunStateScript.NODE_START:
		failures.append("run route: first node should be start")
		return

	if nodes[4].get("type", "") != RunStateScript.NODE_BOSS:
		failures.append("run route: last node should be boss")
		return

	if nodes[4].get("enemy_profile_id", "") != EnemyAI.PROFILE_ROCK_BOSS:
		failures.append("run route: boss node should use rock boss profile")


func _assert_victories_unlock_boss() -> void:
	var state := RunStateScript.new(MapGeneratorScript.new().generate_linear_route())

	if state.current_index != 1:
		failures.append("run progress: first playable node should be index 1")
		return

	if not state.can_enter_node(1):
		failures.append("run progress: first battle should be enterable")
		return

	for expected_index in [2, 3, 4]:
		state.resolve_current_node(true)

		if state.current_index != expected_index:
			failures.append("run progress: expected current index %d, got %d" % [expected_index, state.current_index])
			return

		if not state.can_enter_node(expected_index):
			failures.append("run progress: expected node %d to be enterable" % expected_index)
			return

	state.resolve_current_node(true)

	if not state.run_completed:
		failures.append("run progress: boss victory should complete run")


func _assert_defeat_locks_run() -> void:
	var state := RunStateScript.new(MapGeneratorScript.new().generate_linear_route())
	state.resolve_current_node(false)

	if not state.run_failed:
		failures.append("run defeat: defeat should fail the run")
		return

	if state.can_enter_node(state.current_index):
		failures.append("run defeat: failed run should not allow entering current node")


func _assert_state_roundtrip() -> void:
	var state := RunStateScript.new(MapGeneratorScript.new().generate_linear_route())
	state.resolve_current_node(true)

	var restored := RunStateScript.new()
	restored.load_from_dict(state.to_dict())

	if restored.current_index != state.current_index:
		failures.append("run save: restored current index mismatch")
		return

	if restored.nodes[1].get("status", "") != RunStateScript.STATUS_COMPLETED:
		failures.append("run save: restored completed node status mismatch")
		return

	if not restored.can_enter_node(2):
		failures.append("run save: restored state should keep next node enterable")
