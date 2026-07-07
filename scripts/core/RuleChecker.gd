class_name RuleChecker
extends RefCounted

const WIN_LENGTH := 5


func find_five_in_row(board: BoardState, owner: int) -> Array:
	for y in range(board.height):
		for x in range(board.width):
			var start := Vector2i(x, y)

			if board.get_piece(start) != owner:
				continue

			for direction in _directions():
				var line := _collect_line(board, start, direction, owner)

				if line.size() >= WIN_LENGTH:
					for offset in range(line.size() - WIN_LENGTH + 1):
						var window := line.slice(offset, offset + WIN_LENGTH)

						if not _contains_temporary_piece(board, window):
							return window

	return []


func has_winner(board: BoardState, owner: int) -> bool:
	return not find_five_in_row(board, owner).is_empty()


func find_longest_line_through(board: BoardState, pos: Vector2i, owner: int) -> Array:
	if not board.is_inside(pos) or board.get_piece(pos) != owner:
		return []

	var best_line: Array = [pos]

	for direction in _directions():
		var line := _collect_one_side(board, pos, -direction, owner)
		line.reverse()
		line.append(pos)
		line.append_array(_collect_one_side(board, pos, direction, owner))

		if line.size() > best_line.size():
			best_line = line

	return best_line


func _collect_line(board: BoardState, start: Vector2i, direction: Vector2i, owner: int) -> Array:
	var line: Array = []
	var cursor := start

	while board.is_inside(cursor):
		if board.get_terrain(cursor) == BoardState.TERRAIN_ROCK:
			break

		if board.get_piece(cursor) != owner:
			break

		line.append(cursor)
		cursor += direction

	return line


func _collect_one_side(board: BoardState, start: Vector2i, direction: Vector2i, owner: int) -> Array:
	var line: Array = []
	var cursor := start + direction

	while board.is_inside(cursor):
		if board.get_terrain(cursor) == BoardState.TERRAIN_ROCK:
			break

		if board.get_piece(cursor) != owner:
			break

		line.append(cursor)
		cursor += direction

	return line


func _contains_temporary_piece(board: BoardState, line: Array) -> bool:
	for pos in line:
		if board.is_temporary_piece(pos):
			return true

	return false


func _directions() -> Array:
	return [
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(1, 1),
		Vector2i(1, -1),
	]
