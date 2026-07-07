extends Control

const BOARD_SIZE := 11
const CELL_SIZE := Vector2(48, 48)

var board := BoardState.new(BOARD_SIZE, BOARD_SIZE)
var rule_checker := RuleChecker.new()
var enemy_ai := EnemyAI.new()

var status_label: Label
var board_grid: GridContainer
var reset_button: Button
var cells: Array = []
var current_turn := BoardState.PLAYER
var game_over := false
var winning_line: Array = []

var empty_style: StyleBoxFlat
var player_style: StyleBoxFlat
var enemy_style: StyleBoxFlat
var win_style: StyleBoxFlat


func _ready() -> void:
	_create_styles()
	_build_layout()
	_start_new_game()


func _create_styles() -> void:
	empty_style = _make_cell_style(Color("#dcc58a"), Color("#5a4725"))
	player_style = _make_cell_style(Color("#f7f2df"), Color("#36404a"))
	enemy_style = _make_cell_style(Color("#3f4a56"), Color("#cbd3dc"))
	win_style = _make_cell_style(Color("#e7a541"), Color("#6a3c13"))


func _make_cell_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style


func _build_layout() -> void:
	var background := ColorRect.new()
	background.color = Color("#20242a")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var main := VBoxContainer.new()
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	main.offset_left = 36
	main.offset_top = 28
	main.offset_right = -36
	main.offset_bottom = -28
	main.alignment = BoxContainer.ALIGNMENT_CENTER
	main.add_theme_constant_override("separation", 14)
	add_child(main)

	var title := Label.new()
	title.text = "Tian Yuan Mi Ju"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#f0e6c8"))
	main.add_child(title)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color("#c9d2dc"))
	main.add_child(status_label)

	board_grid = GridContainer.new()
	board_grid.columns = BOARD_SIZE
	board_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_grid.add_theme_constant_override("h_separation", 4)
	board_grid.add_theme_constant_override("v_separation", 4)
	main.add_child(board_grid)

	reset_button = Button.new()
	reset_button.text = "New Game"
	reset_button.custom_minimum_size = Vector2(160, 42)
	reset_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reset_button.pressed.connect(_start_new_game)
	main.add_child(reset_button)

	_create_cells()


func _create_cells() -> void:
	cells.clear()

	for y in range(BOARD_SIZE):
		var row: Array = []

		for x in range(BOARD_SIZE):
			var pos := Vector2i(x, y)
			var button := Button.new()
			button.custom_minimum_size = CELL_SIZE
			button.focus_mode = Control.FOCUS_NONE
			button.add_theme_font_size_override("font_size", 24)
			button.add_theme_color_override("font_color", Color("#1c2229"))
			button.add_theme_color_override("font_hover_color", Color("#1c2229"))
			button.add_theme_color_override("font_pressed_color", Color("#1c2229"))
			button.add_theme_color_override("font_disabled_color", Color("#10151a"))
			button.pressed.connect(_on_cell_pressed.bind(pos))
			board_grid.add_child(button)
			row.append(button)

		cells.append(row)


func _start_new_game() -> void:
	board = BoardState.new(BOARD_SIZE, BOARD_SIZE)
	current_turn = BoardState.PLAYER
	game_over = false
	winning_line.clear()
	_set_status("Your turn. Place X to make five in a row.")
	_refresh_board()


func _on_cell_pressed(pos: Vector2i) -> void:
	if game_over or current_turn != BoardState.PLAYER:
		return

	if not board.place_piece(pos, BoardState.PLAYER):
		return

	_finish_turn(BoardState.PLAYER)

	if game_over:
		return

	current_turn = BoardState.ENEMY
	_set_status("Enemy thinking...")
	_refresh_board()

	await get_tree().create_timer(0.35).timeout
	_play_enemy_turn()


func _play_enemy_turn() -> void:
	if game_over:
		return

	var move := enemy_ai.choose_move(board)

	if move == Vector2i(-1, -1):
		_set_draw()
		return

	board.place_piece(move, BoardState.ENEMY)
	_finish_turn(BoardState.ENEMY)

	if not game_over:
		current_turn = BoardState.PLAYER
		_set_status("Your turn. Place X to make five in a row.")
		_refresh_board()


func _finish_turn(owner: int) -> void:
	winning_line = rule_checker.find_five_in_row(board, owner)

	if not winning_line.is_empty():
		game_over = true
		var winner := "You win!" if owner == BoardState.PLAYER else "Enemy wins."
		_set_status(winner + " Press New Game to play again.")
		_refresh_board()
		return

	if board.get_playable_cells().is_empty():
		_set_draw()
		return

	_refresh_board()


func _set_draw() -> void:
	game_over = true
	_set_status("Draw. Press New Game to play again.")
	_refresh_board()


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text


func _refresh_board() -> void:
	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var pos := Vector2i(x, y)
			var button: Button = cells[y][x]
			var owner := board.get_piece(pos)
			var style := empty_style

			button.text = ""

			if winning_line.has(pos):
				style = win_style
			elif owner == BoardState.PLAYER:
				button.text = "X"
				style = player_style
			elif owner == BoardState.ENEMY:
				button.text = "O"
				style = enemy_style

			button.disabled = game_over or current_turn != BoardState.PLAYER or not board.is_cell_playable(pos)
			button.add_theme_stylebox_override("normal", style)
			button.add_theme_stylebox_override("hover", style)
			button.add_theme_stylebox_override("pressed", style)
			button.add_theme_stylebox_override("disabled", style)
