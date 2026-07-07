extends SceneTree

var failures: Array = []


func _init() -> void:
	_run()

	if failures.is_empty():
		print("AI personality smoke tests passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)

	quit(1)


func _run() -> void:
	_assert_profiles_choose_different_priorities()
	_assert_forced_win_and_block_override_personality()
	_assert_move_plan_explains_intent()
	_assert_rock_boss_selects_pressure_rock_target()


func _assert_profiles_choose_different_priorities() -> void:
	var board := BoardState.new(11, 11)
	board.set_terrain(Vector2i(5, 5), BoardState.TERRAIN_SPIRIT)
	board.place_piece(Vector2i(1, 1), BoardState.ENEMY)
	board.place_piece(Vector2i(2, 1), BoardState.ENEMY)
	board.place_piece(Vector2i(8, 8), BoardState.PLAYER)
	board.place_piece(Vector2i(9, 8), BoardState.PLAYER)

	var fast_ai := EnemyAI.new(EnemyAI.PROFILE_FAST_ATTACKER)
	var defender_ai := EnemyAI.new(EnemyAI.PROFILE_DEFENDER)
	var resource_ai := EnemyAI.new(EnemyAI.PROFILE_RESOURCE_SEEKER)

	var fast_move := fast_ai.choose_move(board)
	var defender_move := defender_ai.choose_move(board)
	var resource_move := resource_ai.choose_move(board)

	if fast_move != Vector2i(3, 1):
		failures.append("fast attacker: expected to extend its own line at D2, got %s" % str(fast_move))
		return

	if defender_move != Vector2i(7, 8):
		failures.append("defender: expected to block player line at H9, got %s" % str(defender_move))
		return

	if resource_move != Vector2i(5, 5):
		failures.append("resource seeker: expected to claim spirit cell at F6, got %s" % str(resource_move))


func _assert_forced_win_and_block_override_personality() -> void:
	var board := BoardState.new(11, 11)
	var resource_ai := EnemyAI.new(EnemyAI.PROFILE_RESOURCE_SEEKER)

	for x in range(4):
		board.place_piece(Vector2i(x, 0), BoardState.ENEMY)

	var winning_move := resource_ai.choose_move(board)

	if winning_move != Vector2i(4, 0):
		failures.append("forced win: expected E1 before resource preference, got %s" % str(winning_move))
		return

	board = BoardState.new(11, 11)

	for x in range(4):
		board.place_piece(Vector2i(x, 2), BoardState.PLAYER)

	var fast_ai := EnemyAI.new(EnemyAI.PROFILE_FAST_ATTACKER)
	var blocking_move := fast_ai.choose_move(board)

	if blocking_move != Vector2i(4, 2):
		failures.append("forced block: expected E3 before attack preference, got %s" % str(blocking_move))


func _assert_move_plan_explains_intent() -> void:
	var board := BoardState.new(11, 11)
	var fast_ai := EnemyAI.new(EnemyAI.PROFILE_FAST_ATTACKER)

	board.place_piece(Vector2i(1, 1), BoardState.ENEMY)
	board.place_piece(Vector2i(2, 1), BoardState.ENEMY)

	var plan := fast_ai.choose_move_plan(board)

	if plan.get("move", Vector2i(-1, -1)) != Vector2i(3, 1):
		failures.append("move plan: expected fast attacker to choose D2, got %s" % str(plan.get("move", Vector2i(-1, -1))))
		return

	if plan.get("category", "") != "attack":
		failures.append("move plan: expected attack category, got %s" % plan.get("category", ""))
		return

	if String(plan.get("reason", "")).is_empty():
		failures.append("move plan: expected a readable reason")


func _assert_rock_boss_selects_pressure_rock_target() -> void:
	var board := BoardState.new(11, 11)
	var boss_ai := EnemyAI.new(EnemyAI.PROFILE_ROCK_BOSS)

	for x in range(4):
		board.place_piece(Vector2i(x, 4), BoardState.PLAYER)

	var urgent_target := boss_ai.choose_rock_target(board)

	if urgent_target != Vector2i(4, 4):
		failures.append("rock boss target: expected urgent player win block at E5, got %s" % str(urgent_target))
		return

	board = BoardState.new(11, 11)
	board.set_terrain(Vector2i(5, 5), BoardState.TERRAIN_SPIRIT)
	board.set_terrain(Vector2i(4, 4), BoardState.TERRAIN_ROCK)
	board.place_piece(Vector2i(1, 1), BoardState.PLAYER)
	board.place_piece(Vector2i(2, 1), BoardState.PLAYER)

	var pressure_target := boss_ai.choose_rock_target(board)

	if pressure_target == Vector2i(-1, -1):
		failures.append("rock boss target: expected a pressure rock target")
		return

	if board.get_terrain(pressure_target) == BoardState.TERRAIN_SPIRIT:
		failures.append("rock boss target: expected non-urgent rock generation to avoid spirit cells")
