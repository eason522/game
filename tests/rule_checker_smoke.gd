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
	_assert_rock_blocks_line()
	_assert_rock_is_not_playable()
	_assert_ai_prefers_spirit_cell()


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


func _assert_rock_blocks_line() -> void:
	var board := BoardState.new(11, 11)
	var checker := RuleChecker.new()
	var positions := [
		Vector2i(1, 5),
		Vector2i(2, 5),
		Vector2i(3, 5),
		Vector2i(5, 5),
		Vector2i(6, 5),
	]

	board.set_terrain(Vector2i(4, 5), BoardState.TERRAIN_ROCK)

	for pos in positions:
		board.place_piece(pos, BoardState.PLAYER)

	if checker.has_winner(board, BoardState.PLAYER):
		failures.append("rock blocks line: expected no winner across rock terrain")


func _assert_rock_is_not_playable() -> void:
	var board := BoardState.new(11, 11)
	var rock_pos := Vector2i(5, 5)

	board.set_terrain(rock_pos, BoardState.TERRAIN_ROCK)

	if board.is_cell_playable(rock_pos):
		failures.append("rock is not playable: rock cell should reject placement")
		return

	if board.place_piece(rock_pos, BoardState.PLAYER):
		failures.append("rock is not playable: place_piece should fail on rock cell")


func _assert_ai_prefers_spirit_cell() -> void:
	var board := BoardState.new(11, 11)
	var ai := EnemyAI.new()
	var spirit_pos := Vector2i(3, 3)

	board.set_terrain(spirit_pos, BoardState.TERRAIN_SPIRIT)

	var move := ai.choose_move(board)

	if move != spirit_pos:
		failures.append("ai prefers spirit cell: expected %s, got %s" % [spirit_pos, move])
