class_name BoardState
extends RefCounted

const EMPTY := 0
const PLAYER := 1
const ENEMY := 2

const TERRAIN_NORMAL := "normal"
const TERRAIN_SPIRIT := "spirit"
const TERRAIN_ROCK := "rock"

var width: int
var height: int
var pieces: Array = []
var temporary_turns: Array = []
var terrains: Array = []
var sealed_turns: Array = []


func _init(board_width: int = 11, board_height: int = 11) -> void:
	width = board_width
	height = board_height
	reset()


func reset() -> void:
	pieces.clear()
	temporary_turns.clear()
	terrains.clear()
	sealed_turns.clear()

	for y in range(height):
		var piece_row: Array = []
		var temporary_row: Array = []
		var terrain_row: Array = []
		var sealed_row: Array = []

		for x in range(width):
			piece_row.append(EMPTY)
			temporary_row.append(0)
			terrain_row.append(TERRAIN_NORMAL)
			sealed_row.append(0)

		pieces.append(piece_row)
		temporary_turns.append(temporary_row)
		terrains.append(terrain_row)
		sealed_turns.append(sealed_row)


func is_inside(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < width and pos.y < height


func get_piece(pos: Vector2i) -> int:
	if not is_inside(pos):
		return EMPTY

	return pieces[pos.y][pos.x]


func get_temporary_turns(pos: Vector2i) -> int:
	if not is_inside(pos):
		return 0

	return temporary_turns[pos.y][pos.x]


func is_temporary_piece(pos: Vector2i) -> bool:
	return get_piece(pos) != EMPTY and get_temporary_turns(pos) > 0


func get_terrain(pos: Vector2i) -> String:
	if not is_inside(pos):
		return TERRAIN_NORMAL

	return terrains[pos.y][pos.x]


func set_terrain(pos: Vector2i, terrain: String) -> bool:
	if not is_inside(pos):
		return false

	terrains[pos.y][pos.x] = terrain
	return true


func is_cell_playable(pos: Vector2i, owner: int = EMPTY) -> bool:
	if not is_inside(pos):
		return false

	if get_piece(pos) != EMPTY:
		return false

	if get_terrain(pos) == TERRAIN_ROCK:
		return false

	if owner == ENEMY and is_sealed(pos):
		return false

	return true


func place_piece(pos: Vector2i, owner: int, temporary_duration: int = 0) -> bool:
	if not is_cell_playable(pos, owner):
		return false

	pieces[pos.y][pos.x] = owner
	temporary_turns[pos.y][pos.x] = max(0, temporary_duration)
	sealed_turns[pos.y][pos.x] = 0
	return true


func remove_piece(pos: Vector2i) -> bool:
	if not is_inside(pos):
		return false

	pieces[pos.y][pos.x] = EMPTY
	temporary_turns[pos.y][pos.x] = 0
	return true


func seal_cell(pos: Vector2i, duration: int = 1) -> bool:
	if not is_inside(pos):
		return false

	if get_piece(pos) != EMPTY or get_terrain(pos) == TERRAIN_ROCK:
		return false

	sealed_turns[pos.y][pos.x] = max(sealed_turns[pos.y][pos.x], duration)
	return true


func get_seal_turns(pos: Vector2i) -> int:
	if not is_inside(pos):
		return 0

	return sealed_turns[pos.y][pos.x]


func is_sealed(pos: Vector2i) -> bool:
	return get_seal_turns(pos) > 0


func decay_seals() -> void:
	for y in range(height):
		for x in range(width):
			sealed_turns[y][x] = max(0, sealed_turns[y][x] - 1)


func decay_temporary_pieces(owner: int) -> void:
	for y in range(height):
		for x in range(width):
			if pieces[y][x] != owner or temporary_turns[y][x] <= 0:
				continue

			temporary_turns[y][x] -= 1

			if temporary_turns[y][x] <= 0:
				remove_piece(Vector2i(x, y))


func get_playable_cells(owner: int = EMPTY) -> Array:
	var cells: Array = []

	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)

			if is_cell_playable(pos, owner):
				cells.append(pos)

	return cells
