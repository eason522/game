class_name EnemyAI
extends RefCounted

const PROFILE_NOVICE := "novice"
const PROFILE_FAST_ATTACKER := "fast_attacker"
const PROFILE_DEFENDER := "defender"
const PROFILE_RESOURCE_SEEKER := "resource_seeker"
const PROFILE_ROCK_BOSS := "rock_boss"
const DEFAULT_PROFILE_ID := PROFILE_NOVICE

const PROFILES := {
	PROFILE_NOVICE: {
		"name": "Novice Spirit",
		"intent": "balanced",
		"center_weight": 1.0,
		"attack_weight": 2.0,
		"defense_weight": 1.6,
		"resource_weight": 35.0,
		"make_three": 80.0,
		"block_three": 70.0,
		"make_four": 320.0,
		"block_four": 360.0,
		"rock_adjacency_weight": 0.0,
	},
	PROFILE_FAST_ATTACKER: {
		"name": "Fast Attacker",
		"intent": "attack",
		"center_weight": 0.6,
		"attack_weight": 4.0,
		"defense_weight": 0.9,
		"resource_weight": 12.0,
		"make_three": 220.0,
		"block_three": 50.0,
		"make_four": 650.0,
		"block_four": 260.0,
		"rock_adjacency_weight": 0.0,
	},
	PROFILE_DEFENDER: {
		"name": "Fortress Defender",
		"intent": "defense",
		"center_weight": 0.7,
		"attack_weight": 1.1,
		"defense_weight": 4.0,
		"resource_weight": 15.0,
		"make_three": 45.0,
		"block_three": 220.0,
		"make_four": 260.0,
		"block_four": 700.0,
		"rock_adjacency_weight": 40.0,
	},
	PROFILE_RESOURCE_SEEKER: {
		"name": "Vein Seeker",
		"intent": "resource",
		"center_weight": 0.7,
		"attack_weight": 1.2,
		"defense_weight": 1.1,
		"resource_weight": 240.0,
		"make_three": 55.0,
		"block_three": 50.0,
		"make_four": 250.0,
		"block_four": 260.0,
		"rock_adjacency_weight": 0.0,
	},
	PROFILE_ROCK_BOSS: {
		"name": "Rock King",
		"intent": "boss",
		"center_weight": 0.8,
		"attack_weight": 2.0,
		"defense_weight": 2.5,
		"resource_weight": 30.0,
		"make_three": 90.0,
		"block_three": 140.0,
		"make_four": 360.0,
		"block_four": 520.0,
		"rock_adjacency_weight": 95.0,
	},
}

var rule_checker := RuleChecker.new()
var profile_id := DEFAULT_PROFILE_ID


func _init(starting_profile_id: String = DEFAULT_PROFILE_ID) -> void:
	set_profile(starting_profile_id)


func set_profile(new_profile_id: String) -> void:
	profile_id = new_profile_id if PROFILES.has(new_profile_id) else DEFAULT_PROFILE_ID


func get_profile_id() -> String:
	return profile_id


func get_profile_name() -> String:
	return get_profile_name_for_id(profile_id)


func get_profile_intent() -> String:
	return PROFILES.get(profile_id, PROFILES[DEFAULT_PROFILE_ID]).get("intent", "balanced")


func get_profile_ids() -> Array:
	return PROFILES.keys()


static func get_profile_name_for_id(profile_id_to_read: String) -> String:
	return PROFILES.get(profile_id_to_read, PROFILES[DEFAULT_PROFILE_ID]).get("name", profile_id_to_read)


func choose_move(board: BoardState, enemy_owner: int = BoardState.ENEMY, player_owner: int = BoardState.PLAYER, override_profile_id: String = "") -> Vector2i:
	var playable_cells := board.get_playable_cells(enemy_owner)

	if playable_cells.is_empty():
		return Vector2i(-1, -1)

	var winning_move := _find_finishing_move(board, playable_cells, enemy_owner)

	if winning_move != Vector2i(-1, -1):
		return winning_move

	var blocking_move := _find_finishing_move(board, playable_cells, player_owner)

	if blocking_move != Vector2i(-1, -1):
		return blocking_move

	var active_profile_id := profile_id if override_profile_id.is_empty() else override_profile_id
	var profile: Dictionary = PROFILES.get(active_profile_id, PROFILES[DEFAULT_PROFILE_ID])
	return _find_best_scored_move(board, playable_cells, enemy_owner, player_owner, profile)


func _find_finishing_move(board: BoardState, playable_cells: Array, owner: int) -> Vector2i:
	for cell in playable_cells:
		board.place_piece(cell, owner)
		var creates_win := rule_checker.has_winner(board, owner)
		board.remove_piece(cell)

		if creates_win:
			return cell

	return Vector2i(-1, -1)


func _find_best_scored_move(board: BoardState, playable_cells: Array, enemy_owner: int, player_owner: int, profile: Dictionary) -> Vector2i:
	var best_cell: Vector2i = playable_cells[0]
	var best_score := -INF

	for cell in playable_cells:
		var score := _score_cell(board, cell, enemy_owner, player_owner, profile)

		if score > best_score:
			best_score = score
			best_cell = cell

	return best_cell


func _score_cell(board: BoardState, cell: Vector2i, enemy_owner: int, player_owner: int, profile: Dictionary) -> float:
	var center := Vector2((board.width - 1) * 0.5, (board.height - 1) * 0.5)
	var distance_to_center := Vector2(cell).distance_to(center)
	var center_score: float = max(0.0, 100.0 - distance_to_center * 10.0)
	var enemy_line := _line_potential(board, cell, enemy_owner)
	var player_line := _line_potential(board, cell, player_owner)
	var score: float = center_score * profile.get("center_weight", 1.0)

	score += enemy_line * enemy_line * 10.0 * profile.get("attack_weight", 1.0)
	score += player_line * player_line * 10.0 * profile.get("defense_weight", 1.0)

	if enemy_line >= 4:
		score += profile.get("make_four", 0.0)
	elif enemy_line >= 3:
		score += profile.get("make_three", 0.0)

	if player_line >= 4:
		score += profile.get("block_four", 0.0)
	elif player_line >= 3:
		score += profile.get("block_three", 0.0)

	if board.get_terrain(cell) == BoardState.TERRAIN_SPIRIT:
		score += profile.get("resource_weight", 0.0)

	score += _adjacent_rock_count(board, cell) * profile.get("rock_adjacency_weight", 0.0)

	return score


func _line_potential(board: BoardState, cell: Vector2i, owner: int) -> int:
	var best := 0

	for direction in _directions():
		var connected := 1
		connected += _count_direction(board, cell, direction, owner)
		connected += _count_direction(board, cell, -direction, owner)
		best = max(best, connected)

	return best


func _count_direction(board: BoardState, start: Vector2i, direction: Vector2i, owner: int) -> int:
	var count := 0
	var cursor := start + direction

	while board.is_inside(cursor):
		if board.get_terrain(cursor) == BoardState.TERRAIN_ROCK:
			break

		if board.get_piece(cursor) != owner:
			break

		count += 1
		cursor += direction

	return count


func _adjacent_rock_count(board: BoardState, cell: Vector2i) -> int:
	var count := 0

	for y in range(-1, 2):
		for x in range(-1, 2):
			if x == 0 and y == 0:
				continue

			var nearby := cell + Vector2i(x, y)

			if board.is_inside(nearby) and board.get_terrain(nearby) == BoardState.TERRAIN_ROCK:
				count += 1

	return count


func _directions() -> Array:
	return [
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(1, 1),
		Vector2i(1, -1),
	]
