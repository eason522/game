extends SceneTree

var failures: Array = []


func _init() -> void:
	_run()

	if failures.is_empty():
		print("RuleChecker smoke tests passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)

	quit(1)


func _run() -> void:
	_assert_five_line(
		"horizontal",
		[
			Vector2i(2, 4),
			Vector2i(3, 4),
			Vector2i(4, 4),
			Vector2i(5, 4),
			Vector2i(6, 4),
		]
	)
	_assert_five_line(
		"vertical",
		[
			Vector2i(7, 1),
			Vector2i(7, 2),
			Vector2i(7, 3),
			Vector2i(7, 4),
			Vector2i(7, 5),
		]
	)
	_assert_five_line(
		"diagonal down",
		[
			Vector2i(1, 1),
			Vector2i(2, 2),
			Vector2i(3, 3),
			Vector2i(4, 4),
			Vector2i(5, 5),
		]
	)
	_assert_five_line(
		"diagonal up",
		[
			Vector2i(2, 7),
			Vector2i(3, 6),
			Vector2i(4, 5),
			Vector2i(5, 4),
			Vector2i(6, 3),
		]
	)


func _assert_five_line(case_name: String, positions: Array) -> void:
	var board := BoardState.new(11, 11)
	var checker := RuleChecker.new()

	for pos in positions:
		var placed := board.place_piece(pos, BoardState.PLAYER)

		if not placed:
			failures.append("%s: failed to place test piece at %s" % [case_name, pos])
			return

	var line := checker.find_five_in_row(board, BoardState.PLAYER)

	if line.size() != positions.size():
		failures.append("%s: expected %d cells, got %d" % [case_name, positions.size(), line.size()])
		return

	for index in range(positions.size()):
		if line[index] != positions[index]:
			failures.append("%s: expected %s at index %d, got %s" % [case_name, positions[index], index, line[index]])
			return
