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
var terrains: Array = []


func _init(board_width: int = 11, board_height: int = 11) -> void:
	width = board_width
	height = board_height
	reset()


func reset() -> void:
	pieces.clear()
	terrains.clear()

	for y in range(height):
		var piece_row: Array = []
		var terrain_row: Array = []

		for x in range(width):
			piece_row.append(EMPTY)
			terrain_row.append(TERRAIN_NORMAL)

		pieces.append(piece_row)
		terrains.append(terrain_row)


func is_inside(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < width and pos.y < height


func get_piece(pos: Vector2i) -> int:
	if not is_inside(pos):
		return EMPTY

	return pieces[pos.y][pos.x]


func get_terrain(pos: Vector2i) -> String:
	if not is_inside(pos):
		return TERRAIN_NORMAL

	return terrains[pos.y][pos.x]


func set_terrain(pos: Vector2i, terrain: String) -> bool:
	if not is_inside(pos):
		return false

	terrains[pos.y][pos.x] = terrain
	return true


func is_cell_playable(pos: Vector2i) -> bool:
	return is_inside(pos) and get_piece(pos) == EMPTY and get_terrain(pos) != TERRAIN_ROCK


func place_piece(pos: Vector2i, owner: int) -> bool:
	if not is_cell_playable(pos):
		return false

	pieces[pos.y][pos.x] = owner
	return true


func remove_piece(pos: Vector2i) -> bool:
	if not is_inside(pos):
		return false

	pieces[pos.y][pos.x] = EMPTY
	return true


func get_playable_cells() -> Array:
	var cells: Array = []

	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)

			if is_cell_playable(pos):
				cells.append(pos)

	return cells
