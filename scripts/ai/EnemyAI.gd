class_name EnemyAI
extends RefCounted

var rule_checker := RuleChecker.new()


func choose_move(board: BoardState, enemy_owner: int = BoardState.ENEMY, player_owner: int = BoardState.PLAYER) -> Vector2i:
	var playable_cells := board.get_playable_cells()

	if playable_cells.is_empty():
		return Vector2i(-1, -1)

	var winning_move := _find_finishing_move(board, playable_cells, enemy_owner)

	if winning_move != Vector2i(-1, -1):
		return winning_move

	var blocking_move := _find_finishing_move(board, playable_cells, player_owner)

	if blocking_move != Vector2i(-1, -1):
		return blocking_move

	return _find_best_scored_move(board, playable_cells, enemy_owner, player_owner)


func _find_finishing_move(board: BoardState, playable_cells: Array, owner: int) -> Vector2i:
	for cell in playable_cells:
		board.place_piece(cell, owner)
		var creates_win := rule_checker.has_winner(board, owner)
		board.remove_piece(cell)

		if creates_win:
			return cell

	return Vector2i(-1, -1)


func _find_best_scored_move(board: BoardState, playable_cells: Array, enemy_owner: int, player_owner: int) -> Vector2i:
	var best_cell: Vector2i = playable_cells[0]
	var best_score := -INF

	for cell in playable_cells:
		var score := _score_cell(board, cell, enemy_owner, player_owner)

		if score > best_score:
			best_score = score
			best_cell = cell

	return best_cell


func _score_cell(board: BoardState, cell: Vector2i, enemy_owner: int, player_owner: int) -> float:
	var center := Vector2((board.width - 1) * 0.5, (board.height - 1) * 0.5)
	var distance_to_center := Vector2(cell).distance_to(center)
	var score := 100.0 - distance_to_center * 4.0

	score += _line_potential(board, cell, enemy_owner) * 3.0
	score += _line_potential(board, cell, player_owner) * 2.2

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


func _directions() -> Array:
	return [
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(1, 1),
		Vector2i(1, -1),
	]
