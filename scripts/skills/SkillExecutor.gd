class_name SkillExecutor
extends RefCounted

const SKILL_ROCK_CREATE := "rock_create"
const SKILL_ROCK_BREAK := "rock_break"
const SKILL_WARNING := "warning"
const SKILL_BREAK_ARRAY := "break_array"
const SKILL_TWIN_PIECE := "twin_piece"
const SKILL_SEAL_MOVE := "seal_move"

const SKILL_ORDER := [
	SKILL_BREAK_ARRAY,
	SKILL_TWIN_PIECE,
	SKILL_ROCK_CREATE,
	SKILL_ROCK_BREAK,
	SKILL_SEAL_MOVE,
	SKILL_WARNING,
]

const SKILL_DATA := {
	SKILL_BREAK_ARRAY: {
		"name": "破阵",
		"cost": 1,
		"description": "下一手若形成三连或以上，回复 1 点能量。",
		"requires_target": false,
	},
	SKILL_TWIN_PIECE: {
		"name": "双生子",
		"cost": 3,
		"description": "下一手落子后，在相邻空格生成一颗持续 2 回合的临时棋。",
		"requires_target": false,
	},
	SKILL_ROCK_CREATE: {
		"name": "立岩",
		"cost": 2,
		"description": "在一个空格生成岩石，阻断落子与连线。",
		"requires_target": true,
	},
	SKILL_ROCK_BREAK: {
		"name": "碎岩",
		"cost": 2,
		"description": "移除一处岩石。",
		"requires_target": true,
	},
	SKILL_SEAL_MOVE: {
		"name": "封手",
		"cost": 3,
		"description": "封锁一个空格，使敌方下一手不能在此落子。",
		"requires_target": true,
	},
	SKILL_WARNING: {
		"name": "预警",
		"cost": 1,
		"description": "预测敌方下一手的危险落点。",
		"requires_target": false,
	},
}


func get_skill_ids() -> Array:
	return SKILL_ORDER.duplicate()


func get_skill_name(skill_id: String) -> String:
	return SKILL_DATA.get(skill_id, {}).get("name", skill_id)


func get_cost(skill_id: String) -> int:
	return SKILL_DATA.get(skill_id, {}).get("cost", 0)


func get_description(skill_id: String) -> String:
	return SKILL_DATA.get(skill_id, {}).get("description", "")


func requires_target(skill_id: String) -> bool:
	return SKILL_DATA.get(skill_id, {}).get("requires_target", true)


func can_afford(skill_id: String, energy: int) -> bool:
	return energy >= get_cost(skill_id)


func preview(board: BoardState, skill_id: String, pos: Vector2i, energy: int = -1, owner: int = BoardState.PLAYER, enemy_owner: int = BoardState.ENEMY) -> Dictionary:
	var result := {
		"skill_id": skill_id,
		"skill_name": get_skill_name(skill_id),
		"valid": false,
		"invalid_reason": "",
		"energy_cost": get_cost(skill_id),
		"energy_after": energy,
		"affected_cells": [],
		"terrain_change": "",
		"impact_notes": [],
	}

	if energy >= 0:
		result["energy_after"] = max(0, energy - get_cost(skill_id))

		if not can_afford(skill_id, energy):
			result["invalid_reason"] = "not enough energy"
			return result

	if requires_target(skill_id) and not is_valid_target(board, skill_id, pos):
		result["invalid_reason"] = "invalid target"
		return result

	result["valid"] = true

	match skill_id:
		SKILL_ROCK_CREATE:
			result["affected_cells"] = [pos]
			result["terrain_change"] = "%s -> %s" % [board.get_terrain(pos), BoardState.TERRAIN_ROCK]
			result["impact_notes"].append("生成岩石，阻断落子与连线。")

			if _would_owner_win_at(board, pos, enemy_owner):
				result["impact_notes"].append("可阻止敌方立即连五。")

			if _would_owner_win_at(board, pos, owner):
				result["impact_notes"].append("也会挡住己方胜点。")
		SKILL_ROCK_BREAK:
			result["affected_cells"] = [pos]
			result["terrain_change"] = "%s -> %s" % [BoardState.TERRAIN_ROCK, BoardState.TERRAIN_NORMAL]
			result["impact_notes"].append("移除岩石，恢复可落子。")

			var old_terrain: String = board.get_terrain(pos)
			board.set_terrain(pos, BoardState.TERRAIN_NORMAL)

			if _would_owner_win_at(board, pos, owner):
				result["impact_notes"].append("打开己方胜点。")

			if _would_owner_win_at(board, pos, enemy_owner):
				result["impact_notes"].append("也会打开敌方胜点。")

			board.set_terrain(pos, old_terrain)
		SKILL_SEAL_MOVE:
			result["affected_cells"] = [pos]
			result["impact_notes"].append("敌方下一手不能在此落子。")

			if _would_owner_win_at(board, pos, enemy_owner):
				result["impact_notes"].append("可阻止敌方立即连五。")

			if _would_owner_win_at(board, pos, owner):
				result["impact_notes"].append("己方仍可使用这个胜点。")

	return result


func is_valid_target(board: BoardState, skill_id: String, pos: Vector2i) -> bool:
	if not board.is_inside(pos):
		return false

	match skill_id:
		SKILL_ROCK_CREATE:
			return board.get_piece(pos) == BoardState.EMPTY and board.get_terrain(pos) != BoardState.TERRAIN_ROCK
		SKILL_ROCK_BREAK:
			return board.get_piece(pos) == BoardState.EMPTY and board.get_terrain(pos) == BoardState.TERRAIN_ROCK
		SKILL_SEAL_MOVE:
			return board.get_piece(pos) == BoardState.EMPTY and board.get_terrain(pos) != BoardState.TERRAIN_ROCK and not board.is_sealed(pos)
		_:
			return false


func execute(board: BoardState, skill_id: String, pos: Vector2i) -> bool:
	if not is_valid_target(board, skill_id, pos):
		return false

	match skill_id:
		SKILL_ROCK_CREATE:
			return board.set_terrain(pos, BoardState.TERRAIN_ROCK)
		SKILL_ROCK_BREAK:
			return board.set_terrain(pos, BoardState.TERRAIN_NORMAL)
		SKILL_SEAL_MOVE:
			return board.seal_cell(pos, 1)

	return false


func _would_owner_win_at(board: BoardState, pos: Vector2i, owner: int) -> bool:
	if not board.is_cell_playable(pos, owner):
		return false

	var checker := RuleChecker.new()
	board.place_piece(pos, owner)
	var creates_win := checker.has_winner(board, owner)
	board.remove_piece(pos)
	return creates_win
