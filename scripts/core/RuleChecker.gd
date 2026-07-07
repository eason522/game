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
					return line.slice(0, WIN_LENGTH)

	return []


func has_winner(board: BoardState, owner: int) -> bool:
	return not find_five_in_row(board, owner).is_empty()


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


func _directions() -> Array:
	return [
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(1, 1),
		Vector2i(1, -1),
	]
