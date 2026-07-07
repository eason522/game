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
	_assert_rock_create_skill()
	_assert_rock_break_skill()
	_assert_warning_skill_metadata()


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
