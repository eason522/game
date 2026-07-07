extends SceneTree

const SkillExecutorScript := preload("res://scripts/skills/SkillExecutor.gd")

var failures: Array = []


func _init() -> void:
	_run()

	if failures.is_empty():
		print("Skill system smoke tests passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)

	quit(1)


func _run() -> void:
	_assert_all_mvp_skills_are_listed()
	_assert_break_array_skill_metadata()
	_assert_twin_piece_skill_metadata_and_temporary_rules()
	_assert_rock_create_skill()
	_assert_rock_break_skill()
	_assert_seal_move_skill()
	_assert_warning_skill_metadata()
	_assert_targeted_skill_previews()


func _assert_all_mvp_skills_are_listed() -> void:
	var skills := SkillExecutorScript.new()

	if skills.get_skill_ids().size() != 6:
		failures.append("skill list: expected 6 MVP skills")


func _assert_break_array_skill_metadata() -> void:
	var skills := SkillExecutorScript.new()

	if skills.requires_target("break_array"):
		failures.append("break array: expected instant skill without target")

	if skills.get_cost("break_array") != 1:
		failures.append("break array: expected cost 1")


func _assert_twin_piece_skill_metadata_and_temporary_rules() -> void:
	var board := BoardState.new(11, 11)
	var skills := SkillExecutorScript.new()
	var checker := RuleChecker.new()

	if skills.requires_target("twin_piece"):
		failures.append("twin piece: expected instant skill without target")

	if skills.get_cost("twin_piece") != 3:
		failures.append("twin piece: expected cost 3")

	for x in range(1, 5):
		board.place_piece(Vector2i(x, 5), BoardState.PLAYER)

	board.place_piece(Vector2i(5, 5), BoardState.PLAYER, 2)

	if checker.has_winner(board, BoardState.PLAYER):
		failures.append("twin piece: temporary piece should not directly complete five")
		return

	board.decay_temporary_pieces(BoardState.PLAYER)

	if board.get_piece(Vector2i(5, 5)) != BoardState.PLAYER:
		failures.append("twin piece: temporary piece should remain after first decay")
		return

	board.decay_temporary_pieces(BoardState.PLAYER)

	if board.get_piece(Vector2i(5, 5)) != BoardState.EMPTY:
		failures.append("twin piece: temporary piece should expire after second decay")


func _assert_rock_create_skill() -> void:
	var board := BoardState.new(11, 11)
	var skills := SkillExecutorScript.new()
	var target := Vector2i(5, 5)

	if not skills.is_valid_target(board, "rock_create", target):
		failures.append("rock create: expected empty normal cell to be valid")
		return

	if not skills.execute(board, "rock_create", target):
		failures.append("rock create: execute returned false")
		return

	if board.get_terrain(target) != BoardState.TERRAIN_ROCK:
		failures.append("rock create: target terrain should become rock")
		return

	if board.is_cell_playable(target):
		failures.append("rock create: created rock should block placement")


func _assert_rock_break_skill() -> void:
	var board := BoardState.new(11, 11)
	var skills := SkillExecutorScript.new()
	var target := Vector2i(4, 4)

	board.set_terrain(target, BoardState.TERRAIN_ROCK)

	if not skills.is_valid_target(board, "rock_break", target):
		failures.append("rock break: expected empty rock cell to be valid")
		return

	if not skills.execute(board, "rock_break", target):
		failures.append("rock break: execute returned false")
		return

	if board.get_terrain(target) != BoardState.TERRAIN_NORMAL:
		failures.append("rock break: target terrain should become normal")


func _assert_seal_move_skill() -> void:
	var board := BoardState.new(11, 11)
	var skills := SkillExecutorScript.new()
	var ai := EnemyAI.new()
	var target := Vector2i(4, 4)

	if not skills.is_valid_target(board, "seal_move", target):
		failures.append("seal move: expected empty normal cell to be valid")
		return

	if not skills.execute(board, "seal_move", target):
		failures.append("seal move: execute returned false")
		return

	if not board.is_sealed(target):
		failures.append("seal move: target should be sealed")
		return

	if board.is_cell_playable(target, BoardState.ENEMY):
		failures.append("seal move: enemy should not be able to play sealed target")
		return

	if not board.is_cell_playable(target, BoardState.PLAYER):
		failures.append("seal move: player should still be able to play sealed target")
		return

	for x in range(4):
		board.place_piece(Vector2i(x, 4), BoardState.ENEMY)

	var move := ai.choose_move(board)

	if move == target:
		failures.append("seal move: AI should avoid sealed target")
		return

	board.decay_seals()

	if board.is_sealed(target):
		failures.append("seal move: seal should expire after decay")


func _assert_warning_skill_metadata() -> void:
	var skills := SkillExecutorScript.new()

	if skills.requires_target("warning"):
		failures.append("warning: expected instant skill without target")

	if skills.get_cost("warning") != 1:
		failures.append("warning: expected cost 1")

	if skills.can_afford("warning", 0):
		failures.append("warning: should not be affordable at 0 energy")

	if not skills.can_afford("warning", 1):
		failures.append("warning: should be affordable at 1 energy")


func _assert_targeted_skill_previews() -> void:
	var skills := SkillExecutorScript.new()
	var board := BoardState.new(11, 11)
	var enemy_win_target := Vector2i(4, 4)

	for x in range(4):
		board.place_piece(Vector2i(x, 4), BoardState.ENEMY)

	var rock_preview := skills.preview(board, "rock_create", enemy_win_target, 6)

	if not rock_preview.get("valid", false):
		failures.append("preview rock create: expected valid preview")
		return

	if rock_preview.get("energy_after", -1) != 4:
		failures.append("preview rock create: expected energy after cost to be 4")
		return

	if not rock_preview.get("affected_cells", []).has(enemy_win_target):
		failures.append("preview rock create: expected target in affected cells")
		return

	if not rock_preview.get("impact_notes", []).has("Blocks enemy immediate win."):
		failures.append("preview rock create: expected enemy win block note")
		return

	var rock_target := Vector2i(4, 6)
	board = BoardState.new(11, 11)

	for x in range(4):
		board.place_piece(Vector2i(x, 6), BoardState.PLAYER)

	board.set_terrain(rock_target, BoardState.TERRAIN_ROCK)

	var break_preview := skills.preview(board, "rock_break", rock_target, 6)

	if not break_preview.get("valid", false):
		failures.append("preview rock break: expected valid preview")
		return

	if not break_preview.get("impact_notes", []).has("Opens a winning point for you."):
		failures.append("preview rock break: expected player winning point note")
		return

	var seal_preview := skills.preview(board, "seal_move", Vector2i(9, 9), 2)

	if seal_preview.get("valid", false):
		failures.append("preview seal move: expected insufficient energy to be invalid")
		return

	if seal_preview.get("invalid_reason", "") != "not enough energy":
		failures.append("preview seal move: expected not enough energy reason")
