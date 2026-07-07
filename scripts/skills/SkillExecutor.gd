class_name SkillExecutor
extends RefCounted

const SKILL_ROCK_CREATE := "rock_create"
const SKILL_ROCK_BREAK := "rock_break"
const SKILL_WARNING := "warning"

const SKILL_ORDER := [
	SKILL_ROCK_CREATE,
	SKILL_ROCK_BREAK,
	SKILL_WARNING,
]

const SKILL_DATA := {
	SKILL_ROCK_CREATE: {
		"name": "Li Yan",
		"cost": 2,
		"description": "Create rock on an empty cell.",
		"requires_target": true,
	},
	SKILL_ROCK_BREAK: {
		"name": "Sui Yan",
		"cost": 2,
		"description": "Remove one rock cell.",
		"requires_target": true,
	},
	SKILL_WARNING: {
		"name": "Yu Jing",
		"cost": 1,
		"description": "Reveal the enemy's likely next move.",
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


func is_valid_target(board: BoardState, skill_id: String, pos: Vector2i) -> bool:
	if not board.is_inside(pos):
		return false

	match skill_id:
		SKILL_ROCK_CREATE:
			return board.get_piece(pos) == BoardState.EMPTY and board.get_terrain(pos) != BoardState.TERRAIN_ROCK
		SKILL_ROCK_BREAK:
			return board.get_piece(pos) == BoardState.EMPTY and board.get_terrain(pos) == BoardState.TERRAIN_ROCK
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

	return false
