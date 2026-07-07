extends Control

const BOARD_SIZE := 11
const CELL_SIZE := Vector2(48, 48)
const ENERGY_MAX := 6
const SkillExecutorScript := preload("res://scripts/skills/SkillExecutor.gd")

var board := BoardState.new(BOARD_SIZE, BOARD_SIZE)
var rule_checker := RuleChecker.new()
var enemy_ai := EnemyAI.new()
var skill_executor := SkillExecutorScript.new()

var status_label: Label
var turn_label: Label
var move_count_label: Label
var energy_label: Label
var board_grid: GridContainer
var skill_bar: HBoxContainer
var reset_button: Button
var cells: Array = []
var skill_buttons: Dictionary = {}
var current_turn := BoardState.PLAYER
var game_over := false
var winning_line: Array = []
var last_move := Vector2i(-1, -1)
var last_move_owner := BoardState.EMPTY
var move_count := 0
var player_energy := 0
var enemy_energy := 0
var selected_skill_id := ""
var warning_target := Vector2i(-1, -1)
var break_array_active := false
var twin_piece_active := false

var empty_style: StyleBoxFlat
var spirit_style: StyleBoxFlat
var rock_style: StyleBoxFlat
var skill_target_style: StyleBoxFlat
var warning_style: StyleBoxFlat
var sealed_style: StyleBoxFlat
var player_style: StyleBoxFlat
var temporary_player_style: StyleBoxFlat
var enemy_style: StyleBoxFlat
var last_player_style: StyleBoxFlat
var last_enemy_style: StyleBoxFlat
var win_style: StyleBoxFlat


func _ready() -> void:
	_create_styles()
	_build_layout()
	_start_new_game()


func _create_styles() -> void:
	empty_style = _make_cell_style(Color("#dcc58a"), Color("#5a4725"))
	spirit_style = _make_cell_style(Color("#76c7ad"), Color("#e2f5e9"))
	rock_style = _make_cell_style(Color("#59524a"), Color("#2f2a25"))
	skill_target_style = _make_cell_style(Color("#9164d8"), Color("#efe5ff"), 4)
	warning_style = _make_cell_style(Color("#d65f4b"), Color("#fff2cd"), 4)
	sealed_style = _make_cell_style(Color("#686c74"), Color("#f1c75b"), 4)
	player_style = _make_cell_style(Color("#f7f2df"), Color("#36404a"))
	temporary_player_style = _make_cell_style(Color("#efe2bd"), Color("#7c8794"), 3)
	enemy_style = _make_cell_style(Color("#3f4a56"), Color("#cbd3dc"))
	last_player_style = _make_cell_style(Color("#fff7dc"), Color("#2f89d7"), 4)
	last_enemy_style = _make_cell_style(Color("#4b5865"), Color("#dc6c55"), 4)
	win_style = _make_cell_style(Color("#e7a541"), Color("#6a3c13"))


func _make_cell_style(fill: Color, border: Color, border_width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
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

	var info_row := HBoxContainer.new()
	info_row.alignment = BoxContainer.ALIGNMENT_CENTER
	info_row.add_theme_constant_override("separation", 20)
	main.add_child(info_row)

	turn_label = Label.new()
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_label.add_theme_font_size_override("font_size", 16)
	turn_label.add_theme_color_override("font_color", Color("#f0e6c8"))
	info_row.add_child(turn_label)

	move_count_label = Label.new()
	move_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	move_count_label.add_theme_font_size_override("font_size", 16)
	move_count_label.add_theme_color_override("font_color", Color("#9fb0c1"))
	info_row.add_child(move_count_label)

	energy_label = Label.new()
	energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energy_label.add_theme_font_size_override("font_size", 16)
	energy_label.add_theme_color_override("font_color", Color("#76c7ad"))
	info_row.add_child(energy_label)

	board_grid = GridContainer.new()
	board_grid.columns = BOARD_SIZE
	board_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_grid.add_theme_constant_override("h_separation", 4)
	board_grid.add_theme_constant_override("v_separation", 4)
	main.add_child(board_grid)

	skill_bar = HBoxContainer.new()
	skill_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	skill_bar.add_theme_constant_override("separation", 10)
	main.add_child(skill_bar)

	reset_button = Button.new()
	reset_button.text = "New Game"
	reset_button.custom_minimum_size = Vector2(160, 42)
	reset_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reset_button.pressed.connect(_start_new_game)
	main.add_child(reset_button)

	_create_cells()
	_create_skill_buttons()


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
			button.mouse_entered.connect(_on_cell_hovered.bind(pos))
			board_grid.add_child(button)
			row.append(button)

		cells.append(row)


func _create_skill_buttons() -> void:
	skill_buttons.clear()

	for skill_id in skill_executor.get_skill_ids():
		var button := Button.new()
		button.custom_minimum_size = Vector2(138, 40)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_skill_pressed.bind(skill_id))
		skill_bar.add_child(button)
		skill_buttons[skill_id] = button


func _start_new_game() -> void:
	board = BoardState.new(BOARD_SIZE, BOARD_SIZE)
	_setup_demo_terrain()
	current_turn = BoardState.PLAYER
	game_over = false
	winning_line.clear()
	last_move = Vector2i(-1, -1)
	last_move_owner = BoardState.EMPTY
	move_count = 0
	player_energy = 0
	enemy_energy = 0
	selected_skill_id = ""
	warning_target = Vector2i(-1, -1)
	break_array_active = false
	twin_piece_active = false
	_begin_turn(BoardState.PLAYER)
	_set_status("Your move: place X, or spend energy on a skill first.")
	_refresh_board()


func _setup_demo_terrain() -> void:
	var spirit_cells := [
		Vector2i(5, 5),
		Vector2i(4, 5),
		Vector2i(6, 5),
		Vector2i(5, 4),
		Vector2i(5, 6),
	]
	var rock_cells := [
		Vector2i(3, 3),
		Vector2i(7, 3),
		Vector2i(3, 7),
		Vector2i(7, 7),
	]

	for pos in spirit_cells:
		board.set_terrain(pos, BoardState.TERRAIN_SPIRIT)

	for pos in rock_cells:
		board.set_terrain(pos, BoardState.TERRAIN_ROCK)


func _on_cell_pressed(pos: Vector2i) -> void:
	if game_over or current_turn != BoardState.PLAYER:
		return

	if not selected_skill_id.is_empty():
		_try_use_targeted_skill(pos)
		return

	if not board.place_piece(pos, BoardState.PLAYER):
		return

	warning_target = Vector2i(-1, -1)
	_record_move(pos, BoardState.PLAYER)
	_apply_terrain_reward(pos, BoardState.PLAYER)
	var skill_notes := _resolve_player_piece_skills(pos)
	_finish_turn(BoardState.PLAYER)

	if game_over:
		return

	current_turn = BoardState.ENEMY
	_begin_turn(BoardState.ENEMY)
	var note_text := "" if skill_notes.is_empty() else " %s" % " ".join(skill_notes)
	_set_status("Enemy is thinking after your move at %s.%s" % [_format_board_pos(pos), note_text])
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
	_record_move(move, BoardState.ENEMY)
	_apply_terrain_reward(move, BoardState.ENEMY)
	_finish_turn(BoardState.ENEMY)
	board.decay_seals()

	if not game_over:
		current_turn = BoardState.PLAYER
		_begin_turn(BoardState.PLAYER)
		_set_status("Enemy placed O at %s. Your move." % _format_board_pos(move))
		_refresh_board()


func _begin_turn(owner: int) -> void:
	board.decay_temporary_pieces(owner)
	_gain_energy(owner, 1)


func _apply_terrain_reward(pos: Vector2i, owner: int) -> void:
	if board.get_terrain(pos) != BoardState.TERRAIN_SPIRIT:
		return

	_gain_energy(owner, 1)


func _gain_energy(owner: int, amount: int) -> void:
	if owner == BoardState.PLAYER:
		player_energy = min(ENERGY_MAX, player_energy + amount)
	else:
		enemy_energy = min(ENERGY_MAX, enemy_energy + amount)


func _spend_player_energy(amount: int) -> void:
	player_energy = max(0, player_energy - amount)


func _on_skill_pressed(skill_id: String) -> void:
	if game_over or current_turn != BoardState.PLAYER:
		return

	if not skill_executor.can_afford(skill_id, player_energy):
		_set_status("%s needs %d energy." % [skill_executor.get_skill_name(skill_id), skill_executor.get_cost(skill_id)])
		return

	if not skill_executor.requires_target(skill_id):
		_use_instant_skill(skill_id)
		return

	if selected_skill_id == skill_id:
		selected_skill_id = ""
		_set_status("Skill cancelled. Place X or choose another skill.")
	else:
		selected_skill_id = skill_id
		_set_status(_format_selected_skill_prompt(skill_id))

	_refresh_board()


func _on_cell_hovered(pos: Vector2i) -> void:
	if game_over or current_turn != BoardState.PLAYER or selected_skill_id.is_empty():
		return

	if not skill_executor.is_valid_target(board, selected_skill_id, pos):
		return

	var preview := skill_executor.preview(board, selected_skill_id, pos, player_energy)
	_set_status(_format_skill_preview(preview))


func _try_use_targeted_skill(pos: Vector2i) -> void:
	if not skill_executor.can_afford(selected_skill_id, player_energy):
		_set_status("%s needs %d energy." % [skill_executor.get_skill_name(selected_skill_id), skill_executor.get_cost(selected_skill_id)])
		selected_skill_id = ""
		_refresh_board()
		return

	if not skill_executor.is_valid_target(board, selected_skill_id, pos):
		_set_status("Invalid target for %s." % skill_executor.get_skill_name(selected_skill_id))
		return

	var skill_name: String = skill_executor.get_skill_name(selected_skill_id)
	var cost: int = skill_executor.get_cost(selected_skill_id)

	if not skill_executor.execute(board, selected_skill_id, pos):
		_set_status("%s failed at %s." % [skill_name, _format_board_pos(pos)])
		return

	_spend_player_energy(cost)
	selected_skill_id = ""
	warning_target = Vector2i(-1, -1)
	_set_status("%s used at %s. Place X to finish your turn." % [skill_name, _format_board_pos(pos)])
	_refresh_board()


func _use_instant_skill(skill_id: String) -> void:
	var skill_name: String = skill_executor.get_skill_name(skill_id)
	var cost := skill_executor.get_cost(skill_id)

	if skill_id == SkillExecutorScript.SKILL_BREAK_ARRAY:
		break_array_active = true
		_spend_player_energy(cost)
		selected_skill_id = ""
		warning_target = Vector2i(-1, -1)
		_set_status("%s prepared. Place X to form a line of three or more and regain 1 energy." % skill_name)
		_refresh_board()
		return

	if skill_id == SkillExecutorScript.SKILL_TWIN_PIECE:
		twin_piece_active = true
		_spend_player_energy(cost)
		selected_skill_id = ""
		warning_target = Vector2i(-1, -1)
		_set_status("%s prepared. After your next X, a temporary adjacent X will appear for 2 turns." % skill_name)
		_refresh_board()
		return

	var predicted_move := enemy_ai.choose_move(board)

	_spend_player_energy(cost)
	selected_skill_id = ""
	warning_target = predicted_move

	if predicted_move == Vector2i(-1, -1):
		_set_status("%s found no legal enemy move." % skill_name)
	else:
		_set_status("%s predicts danger at %s." % [skill_name, _format_board_pos(predicted_move)])

	_refresh_board()


func _resolve_player_piece_skills(pos: Vector2i) -> Array:
	var notes: Array = []

	if break_array_active:
		break_array_active = false
		var line := rule_checker.find_longest_line_through(board, pos, BoardState.PLAYER)

		if line.size() >= 3:
			_gain_energy(BoardState.PLAYER, 1)
			notes.append("Po Zhen restored 1 energy.")
		else:
			notes.append("Po Zhen found no three-line.")

	if twin_piece_active:
		twin_piece_active = false
		var twin_target := _find_twin_piece_target(pos)

		if twin_target == Vector2i(-1, -1):
			notes.append("Shuang Sheng Zi found no adjacent space.")
		elif board.place_piece(twin_target, BoardState.PLAYER, 2):
			notes.append("Shuang Sheng Zi created a temporary X at %s." % _format_board_pos(twin_target))

	return notes


func _find_twin_piece_target(anchor: Vector2i) -> Vector2i:
	var best_target := Vector2i(-1, -1)
	var best_score := -INF
	var center := Vector2((BOARD_SIZE - 1) * 0.5, (BOARD_SIZE - 1) * 0.5)

	for offset in _adjacent_offsets():
		var target: Vector2i = anchor + offset

		if not board.is_cell_playable(target, BoardState.PLAYER) or board.is_sealed(target):
			continue

		board.place_piece(target, BoardState.PLAYER, 2)
		var line := rule_checker.find_longest_line_through(board, target, BoardState.PLAYER)
		board.remove_piece(target)

		var score := line.size() * 20.0 - Vector2(target).distance_to(center)

		if score > best_score:
			best_score = score
			best_target = target

	return best_target


func _finish_turn(owner: int) -> void:
	winning_line = rule_checker.find_five_in_row(board, owner)

	if not winning_line.is_empty():
		game_over = true
		var winner := "You win" if owner == BoardState.PLAYER else "Enemy wins"
		_set_status("%s with %s. Press New Game to play again." % [winner, _format_line(winning_line)])
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


func _record_move(pos: Vector2i, owner: int) -> void:
	last_move = pos
	last_move_owner = owner
	move_count += 1


func _format_board_pos(pos: Vector2i) -> String:
	var file := "ABCDEFGHIJKLMNOPQRSTUVWXYZ".substr(pos.x, 1)
	var rank := str(pos.y + 1)
	return file + rank


func _format_line(line: Array) -> String:
	if line.is_empty():
		return ""

	return "%s-%s" % [_format_board_pos(line.front()), _format_board_pos(line.back())]


func _refresh_board() -> void:
	_refresh_info_labels()
	_refresh_skill_buttons()

	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var pos := Vector2i(x, y)
			var button: Button = cells[y][x]
			var owner := board.get_piece(pos)
			var style := empty_style
			var terrain := board.get_terrain(pos)

			button.text = ""
			button.tooltip_text = ""

			if winning_line.has(pos):
				style = win_style
			elif pos == last_move and last_move_owner == BoardState.PLAYER:
				button.text = "X"
				style = last_player_style
			elif pos == last_move and last_move_owner == BoardState.ENEMY:
				button.text = "O"
				style = last_enemy_style
			elif owner == BoardState.PLAYER:
				button.text = "x" if board.is_temporary_piece(pos) else "X"
				style = temporary_player_style if board.is_temporary_piece(pos) else player_style
			elif owner == BoardState.ENEMY:
				button.text = "O"
				style = enemy_style
			elif terrain == BoardState.TERRAIN_ROCK:
				button.text = "#"
				style = rock_style
			elif board.is_sealed(pos):
				button.text = "x"
				style = sealed_style
			elif terrain == BoardState.TERRAIN_SPIRIT:
				button.text = "+"
				style = spirit_style

			if owner == BoardState.EMPTY and not selected_skill_id.is_empty() and skill_executor.is_valid_target(board, selected_skill_id, pos):
				if button.text.is_empty():
					button.text = "*"
				style = skill_target_style
				button.tooltip_text = _format_skill_preview(skill_executor.preview(board, selected_skill_id, pos, player_energy))
			elif owner == BoardState.EMPTY and pos == warning_target:
				button.text = "!"
				style = warning_style

			button.disabled = _is_cell_disabled(pos)
			button.add_theme_stylebox_override("normal", style)
			button.add_theme_stylebox_override("hover", style)
			button.add_theme_stylebox_override("pressed", style)
			button.add_theme_stylebox_override("disabled", style)


func _is_cell_disabled(pos: Vector2i) -> bool:
	if game_over or current_turn != BoardState.PLAYER:
		return true

	if not selected_skill_id.is_empty():
		return not skill_executor.is_valid_target(board, selected_skill_id, pos)

	return not board.is_cell_playable(pos, BoardState.PLAYER)


func _format_selected_skill_prompt(skill_id: String) -> String:
	var cost := skill_executor.get_cost(skill_id)
	var remaining: int = max(0, player_energy - cost)
	return "%s selected. Cost %d energy, leaving %d/%d. Hover a highlighted target to preview it." % [skill_executor.get_skill_name(skill_id), cost, remaining, ENERGY_MAX]


func _format_skill_preview(preview: Dictionary) -> String:
	if not preview.get("valid", false):
		return "%s preview unavailable: %s." % [preview.get("skill_name", "Skill"), preview.get("invalid_reason", "invalid target")]

	var affected_cells: Array = preview.get("affected_cells", [])
	var impact_notes: Array = preview.get("impact_notes", [])
	var parts := [
		"%s preview: cost %d, energy after %d/%d." % [
			preview.get("skill_name", "Skill"),
			preview.get("energy_cost", 0),
			preview.get("energy_after", player_energy),
			ENERGY_MAX,
		]
	]

	if not affected_cells.is_empty():
		parts.append("Affects %s." % _format_cell_list(affected_cells))

	var terrain_change: String = preview.get("terrain_change", "")

	if not terrain_change.is_empty():
		parts.append("Terrain %s." % terrain_change)

	if not impact_notes.is_empty():
		parts.append(" ".join(impact_notes))

	return " ".join(parts)


func _format_cell_list(cell_list: Array) -> String:
	var formatted: Array = []

	for cell in cell_list:
		formatted.append(_format_board_pos(cell))

	return ", ".join(formatted)


func _refresh_skill_buttons() -> void:
	for skill_id in skill_buttons:
		var button: Button = skill_buttons[skill_id]
		var cost: int = skill_executor.get_cost(skill_id)
		var name: String = skill_executor.get_skill_name(skill_id)
		var prefix := "> " if selected_skill_id == skill_id else ""
		var already_active: bool = skill_id == SkillExecutorScript.SKILL_BREAK_ARRAY and break_array_active
		already_active = already_active or skill_id == SkillExecutorScript.SKILL_TWIN_PIECE and twin_piece_active

		button.text = "%s%s (%d)" % [prefix, name, cost]
		button.tooltip_text = skill_executor.get_description(skill_id)
		button.disabled = game_over or current_turn != BoardState.PLAYER or already_active or not skill_executor.can_afford(skill_id, player_energy)


func _refresh_info_labels() -> void:
	if turn_label == null or move_count_label == null or energy_label == null:
		return

	var turn_text := "Game Over"

	if not game_over:
		turn_text = "Turn: Player X" if current_turn == BoardState.PLAYER else "Turn: Enemy O"

	turn_label.text = turn_text
	move_count_label.text = "Moves: %d" % move_count
	energy_label.text = "Energy: You %d/%d / Enemy %d/%d" % [player_energy, ENERGY_MAX, enemy_energy, ENERGY_MAX]


func _adjacent_offsets() -> Array:
	return [
		Vector2i(-1, -1),
		Vector2i(0, -1),
		Vector2i(1, -1),
		Vector2i(-1, 0),
		Vector2i(1, 0),
		Vector2i(-1, 1),
		Vector2i(0, 1),
		Vector2i(1, 1),
	]
