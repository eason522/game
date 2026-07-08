extends Control

const BOARD_SIZE := 11
const CELL_SIZE := Vector2(48, 48)
const BASE_ENERGY_MAX := 6
const ROCK_BOSS_ROCK_INTERVAL := 3
const RUN_MAP_SCENE_PATH := "res://scenes/roguelike/RunMapScene.tscn"
const RUN_STATE_META := "tymj_run_state"
const BATTLE_NODE_INDEX_META := "tymj_battle_node_index"
const BATTLE_RESULT_META := "tymj_battle_result"
const BATTLE_ENEMY_PROFILE_META := "tymj_battle_enemy_profile_id"
const SkillExecutorScript := preload("res://scripts/skills/SkillExecutor.gd")
const RunStateScript := preload("res://scripts/roguelike/RunState.gd")
const SimpleTonePlayerScript := preload("res://scripts/audio/SimpleTonePlayer.gd")

var board := BoardState.new(BOARD_SIZE, BOARD_SIZE)
var rule_checker := RuleChecker.new()
var enemy_ai := EnemyAI.new()
var skill_executor := SkillExecutorScript.new()

var status_label: Label
var feedback_label: Label
var result_banner_label: Label
var turn_label: Label
var move_count_label: Label
var energy_label: Label
var enemy_profile_label: Label
var enemy_intent_hint_label: Label
var board_grid: GridContainer
var skill_bar: GridContainer
var reset_button: Button
var return_to_map_button: Button
var enemy_profile_button: Button
var tone_player
var cells: Array = []
var skill_buttons: Dictionary = {}
var enemy_profile_ids := [
	EnemyAI.PROFILE_NOVICE,
	EnemyAI.PROFILE_FAST_ATTACKER,
	EnemyAI.PROFILE_DEFENDER,
	EnemyAI.PROFILE_RESOURCE_SEEKER,
	EnemyAI.PROFILE_ROCK_BOSS,
]
var enemy_profile_index := 0
var launched_from_run := false
var run_node_index := -1
var forced_enemy_profile_id := ""
var current_turn := BoardState.PLAYER
var game_over := false
var winning_line: Array = []
var last_move := Vector2i(-1, -1)
var last_move_owner := BoardState.EMPTY
var move_count := 0
var enemy_turn_count := 0
var energy_max := BASE_ENERGY_MAX
var starting_player_energy_bonus := 0
var extra_spirit_cells := 0
var rock_break_refunds_per_battle := 0
var seal_refunds_per_battle := 0
var rock_break_refunds_left := 0
var seal_refunds_left := 0
var player_energy := 0
var enemy_energy := 0
var enemy_intent_hint := ""
var selected_skill_id := ""
var warning_target := Vector2i(-1, -1)
var break_array_active := false
var twin_piece_active := false
var feedback_log: Array = []
var feedback_flashes: Dictionary = {}
var feedback_flash_token := 0
var result_banner_tween: Tween

var empty_style: StyleBoxFlat
var spirit_style: StyleBoxFlat
var rock_style: StyleBoxFlat
var skill_target_style: StyleBoxFlat
var feedback_player_style: StyleBoxFlat
var feedback_enemy_style: StyleBoxFlat
var feedback_skill_style: StyleBoxFlat
var feedback_rock_style: StyleBoxFlat
var feedback_energy_style: StyleBoxFlat
var warning_style: StyleBoxFlat
var sealed_style: StyleBoxFlat
var player_style: StyleBoxFlat
var temporary_player_style: StyleBoxFlat
var enemy_style: StyleBoxFlat
var last_player_style: StyleBoxFlat
var last_enemy_style: StyleBoxFlat
var win_style: StyleBoxFlat
var panel_style: StyleBoxFlat
var board_panel_style: StyleBoxFlat
var status_panel_style: StyleBoxFlat
var action_button_style: StyleBoxFlat
var action_button_hover_style: StyleBoxFlat
var action_button_pressed_style: StyleBoxFlat
var disabled_button_style: StyleBoxFlat


func _ready() -> void:
	_read_run_context()
	_create_styles()
	_build_layout()
	_create_audio_feedback()
	_start_new_game()


func _read_run_context() -> void:
	var root := get_tree().root
	launched_from_run = root.has_meta(BATTLE_NODE_INDEX_META)

	if not launched_from_run:
		return

	run_node_index = root.get_meta(BATTLE_NODE_INDEX_META, -1)
	forced_enemy_profile_id = root.get_meta(BATTLE_ENEMY_PROFILE_META, EnemyAI.PROFILE_NOVICE)
	_load_run_build_modifiers(root)

	if enemy_profile_ids.has(forced_enemy_profile_id):
		enemy_profile_index = enemy_profile_ids.find(forced_enemy_profile_id)


func _load_run_build_modifiers(root: Window) -> void:
	if not root.has_meta(RUN_STATE_META):
		return

	var restored_run := RunStateScript.new()
	restored_run.load_from_dict(root.get_meta(RUN_STATE_META))
	var modifiers := restored_run.get_battle_modifiers()

	energy_max = BASE_ENERGY_MAX + modifiers.get("energy_max_bonus", 0)
	starting_player_energy_bonus = modifiers.get("starting_energy_bonus", 0)
	extra_spirit_cells = modifiers.get("extra_spirit_cells", 0)
	rock_break_refunds_per_battle = modifiers.get("rock_break_refund_per_battle", 0)
	seal_refunds_per_battle = modifiers.get("seal_refund_per_battle", 0)


func _create_styles() -> void:
	empty_style = _make_cell_style(Color("#d9bc78"), Color("#6d5427"))
	spirit_style = _make_cell_style(Color("#3fa58e"), Color("#bdebdc"), 3)
	rock_style = _make_cell_style(Color("#4a4540"), Color("#27231f"))
	skill_target_style = _make_cell_style(Color("#7e5ec5"), Color("#f0e7ff"), 4)
	feedback_player_style = _make_cell_style(Color("#f8e8a7"), Color("#4fa6d8"), 5)
	feedback_enemy_style = _make_cell_style(Color("#4c5d6f"), Color("#e27965"), 5)
	feedback_skill_style = _make_cell_style(Color("#8066cf"), Color("#fff3ba"), 5)
	feedback_rock_style = _make_cell_style(Color("#665347"), Color("#f2b35e"), 5)
	feedback_energy_style = _make_cell_style(Color("#4eb39d"), Color("#d7fff1"), 5)
	warning_style = _make_cell_style(Color("#c25345"), Color("#fff0bf"), 4)
	sealed_style = _make_cell_style(Color("#5e6572"), Color("#f0c65a"), 4)
	player_style = _make_cell_style(Color("#f3ead1"), Color("#2f4050"), 3)
	temporary_player_style = _make_cell_style(Color("#dec98f"), Color("#7a8793"), 3)
	enemy_style = _make_cell_style(Color("#2f3a46"), Color("#d4dbe1"), 3)
	last_player_style = _make_cell_style(Color("#fff5d2"), Color("#2f88c9"), 4)
	last_enemy_style = _make_cell_style(Color("#3e4a57"), Color("#d85f4f"), 4)
	win_style = _make_cell_style(Color("#e5a544"), Color("#6a3b12"), 4)
	panel_style = _make_panel_style(Color("#222832"), Color("#3a4655"))
	board_panel_style = _make_panel_style(Color("#262019"), Color("#725936"))
	status_panel_style = _make_panel_style(Color("#182129"), Color("#2e8c7e"))
	action_button_style = _make_panel_style(Color("#314353"), Color("#668195"))
	action_button_hover_style = _make_panel_style(Color("#3a5265"), Color("#86a8bd"))
	action_button_pressed_style = _make_panel_style(Color("#273743"), Color("#f0c65a"))
	disabled_button_style = _make_panel_style(Color("#252b33"), Color("#343b45"))


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


func _make_panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _build_layout() -> void:
	var background := ColorRect.new()
	background.color = Color("#12161b")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 30)
	root.add_theme_constant_override("margin_top", 22)
	root.add_theme_constant_override("margin_right", 30)
	root.add_theme_constant_override("margin_bottom", 24)
	add_child(root)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 14)
	root.add_child(main)

	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 18)
	main.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)

	var title := Label.new()
	title.text = "天元迷局"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#f1dfb7"))
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "五子棋战斗原型"
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color("#8da0af"))
	title_box.add_child(subtitle)

	var status_box := VBoxContainer.new()
	status_box.custom_minimum_size = Vector2(490, 76)
	status_box.add_theme_constant_override("separation", 6)
	header.add_child(status_box)

	status_label = Label.new()
	status_label.custom_minimum_size = Vector2(490, 52)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 17)
	status_label.add_theme_color_override("font_color", Color("#cde8df"))
	status_label.add_theme_stylebox_override("normal", status_panel_style)
	status_box.add_child(status_label)

	feedback_label = Label.new()
	feedback_label.custom_minimum_size = Vector2(490, 48)
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.add_theme_font_size_override("font_size", 13)
	feedback_label.add_theme_color_override("font_color", Color("#f1dfb7"))
	feedback_label.add_theme_stylebox_override("normal", panel_style)
	status_box.add_child(feedback_label)

	result_banner_label = Label.new()
	result_banner_label.visible = false
	result_banner_label.custom_minimum_size = Vector2(0, 58)
	result_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_banner_label.add_theme_font_size_override("font_size", 24)
	result_banner_label.add_theme_color_override("font_color", Color("#fff4d6"))
	result_banner_label.add_theme_stylebox_override("normal", status_panel_style)
	main.add_child(result_banner_label)

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 20)
	main.add_child(content)

	var board_panel := PanelContainer.new()
	board_panel.add_theme_stylebox_override("panel", board_panel_style)
	board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(board_panel)

	var board_margin := MarginContainer.new()
	board_margin.add_theme_constant_override("margin_left", 20)
	board_margin.add_theme_constant_override("margin_top", 18)
	board_margin.add_theme_constant_override("margin_right", 20)
	board_margin.add_theme_constant_override("margin_bottom", 18)
	board_panel.add_child(board_margin)

	var board_box := VBoxContainer.new()
	board_box.alignment = BoxContainer.ALIGNMENT_CENTER
	board_box.add_theme_constant_override("separation", 12)
	board_margin.add_child(board_box)

	var board_header := HBoxContainer.new()
	board_header.alignment = BoxContainer.ALIGNMENT_CENTER
	board_header.add_theme_constant_override("separation", 16)
	board_box.add_child(board_header)

	turn_label = Label.new()
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_label.add_theme_font_size_override("font_size", 20)
	turn_label.add_theme_color_override("font_color", Color("#f1dfb7"))
	board_header.add_child(turn_label)

	move_count_label = Label.new()
	move_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	move_count_label.add_theme_font_size_override("font_size", 15)
	move_count_label.add_theme_color_override("font_color", Color("#9fb0c1"))
	board_header.add_child(move_count_label)

	board_grid = GridContainer.new()
	board_grid.columns = BOARD_SIZE
	board_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	board_grid.add_theme_constant_override("h_separation", 4)
	board_grid.add_theme_constant_override("v_separation", 4)
	board_box.add_child(board_grid)

	var legend := Label.new()
	legend.text = "X 己方  /  O 敌方  /  + 灵脉  /  # 岩石  /  ! 预警"
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.add_theme_font_size_override("font_size", 14)
	legend.add_theme_color_override("font_color", Color("#b6a785"))
	board_box.add_child(legend)

	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size = Vector2(360, 0)
	sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_constant_override("separation", 12)
	content.add_child(sidebar)

	var enemy_panel := _create_side_panel(sidebar, "敌方")

	enemy_profile_label = Label.new()
	enemy_profile_label.add_theme_font_size_override("font_size", 22)
	enemy_profile_label.add_theme_color_override("font_color", Color("#f0c65a"))
	enemy_panel.add_child(enemy_profile_label)

	enemy_intent_hint_label = Label.new()
	enemy_intent_hint_label.text = "意图会随棋风变化"
	enemy_intent_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	enemy_intent_hint_label.add_theme_font_size_override("font_size", 14)
	enemy_intent_hint_label.add_theme_color_override("font_color", Color("#91a7b6"))
	enemy_panel.add_child(enemy_intent_hint_label)

	var resource_panel := _create_side_panel(sidebar, "战况")

	energy_label = Label.new()
	energy_label.add_theme_font_size_override("font_size", 17)
	energy_label.add_theme_color_override("font_color", Color("#87d1b7"))
	resource_panel.add_child(energy_label)

	var skill_panel := _create_side_panel(sidebar, "术法")

	skill_bar = GridContainer.new()
	skill_bar.columns = 2
	skill_bar.add_theme_constant_override("h_separation", 8)
	skill_bar.add_theme_constant_override("v_separation", 8)
	skill_panel.add_child(skill_bar)

	var controls_panel := _create_side_panel(sidebar, "设置")

	enemy_profile_button = Button.new()
	enemy_profile_button.custom_minimum_size = Vector2(0, 44)
	enemy_profile_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_profile_button.pressed.connect(_cycle_enemy_profile)
	_apply_button_theme(enemy_profile_button)
	controls_panel.add_child(enemy_profile_button)

	reset_button = Button.new()
	reset_button.text = "重新开始"
	reset_button.custom_minimum_size = Vector2(0, 44)
	reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_button.pressed.connect(_start_new_game)
	_apply_button_theme(reset_button)
	controls_panel.add_child(reset_button)

	return_to_map_button = Button.new()
	return_to_map_button.text = "返回路线"
	return_to_map_button.custom_minimum_size = Vector2(0, 44)
	return_to_map_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return_to_map_button.visible = launched_from_run
	return_to_map_button.disabled = true
	return_to_map_button.pressed.connect(_return_to_run_map)
	_apply_button_theme(return_to_map_button)
	controls_panel.add_child(return_to_map_button)

	_create_cells()
	_create_skill_buttons()


func _create_side_panel(parent: Control, title_text: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("#b8c5d0"))
	box.add_child(title)

	return box


func _apply_button_theme(button: Button) -> void:
	button.add_theme_stylebox_override("normal", action_button_style)
	button.add_theme_stylebox_override("hover", action_button_hover_style)
	button.add_theme_stylebox_override("pressed", action_button_pressed_style)
	button.add_theme_stylebox_override("disabled", disabled_button_style)
	button.add_theme_color_override("font_color", Color("#f3ead1"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("#f0c65a"))
	button.add_theme_color_override("font_disabled_color", Color("#77828c"))
	button.add_theme_font_size_override("font_size", 15)


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
		button.custom_minimum_size = Vector2(148, 58)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_skill_pressed.bind(skill_id))
		_apply_button_theme(button)
		skill_bar.add_child(button)
		skill_buttons[skill_id] = button


func _create_audio_feedback() -> void:
	tone_player = SimpleTonePlayerScript.new()
	tone_player.name = "BattleTonePlayer"
	add_child(tone_player)


func _start_new_game() -> void:
	board = BoardState.new(BOARD_SIZE, BOARD_SIZE)
	enemy_ai.set_profile(forced_enemy_profile_id if launched_from_run else enemy_profile_ids[enemy_profile_index])
	_setup_demo_terrain()
	current_turn = BoardState.PLAYER
	game_over = false
	winning_line.clear()
	last_move = Vector2i(-1, -1)
	last_move_owner = BoardState.EMPTY
	move_count = 0
	enemy_turn_count = 0
	rock_break_refunds_left = rock_break_refunds_per_battle
	seal_refunds_left = seal_refunds_per_battle
	player_energy = min(energy_max, starting_player_energy_bonus)
	enemy_energy = 0
	enemy_intent_hint = _format_enemy_intro()
	selected_skill_id = ""
	warning_target = Vector2i(-1, -1)
	break_array_active = false
	twin_piece_active = false
	_clear_feedback()
	_hide_result_banner()
	_begin_turn(BoardState.PLAYER)
	_set_status("对阵 %s：选择空格落子，或先使用术法。" % enemy_ai.get_profile_name())
	_show_feedback("战斗开始：己方获得起始能量 %d/%d。" % [player_energy, energy_max], [], "")
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
	var bonus_spirit_cells := [
		Vector2i(2, 2),
		Vector2i(8, 8),
		Vector2i(2, 8),
		Vector2i(8, 2),
		Vector2i(1, 5),
		Vector2i(9, 5),
	]

	if enemy_ai.get_profile_id() == EnemyAI.PROFILE_ROCK_BOSS:
		rock_cells = [
			Vector2i(2, 5),
			Vector2i(4, 3),
			Vector2i(6, 3),
			Vector2i(8, 5),
			Vector2i(4, 7),
			Vector2i(6, 7),
		]

	for pos in spirit_cells:
		board.set_terrain(pos, BoardState.TERRAIN_SPIRIT)

	for index in range(min(extra_spirit_cells, bonus_spirit_cells.size())):
		var pos: Vector2i = bonus_spirit_cells[index]

		if board.get_terrain(pos) != BoardState.TERRAIN_ROCK:
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
	_show_feedback("己方落子 %s。" % _format_board_pos(pos), [pos], "player")
	_finish_turn(BoardState.PLAYER)

	if game_over:
		return

	current_turn = BoardState.ENEMY
	_begin_turn(BoardState.ENEMY)
	var note_text := "" if skill_notes.is_empty() else " %s" % " ".join(skill_notes)
	_set_status("你落子于 %s。%s敌方正在思考。" % [_format_board_pos(pos), note_text])
	_refresh_board()

	await get_tree().create_timer(0.35).timeout
	_play_enemy_turn()


func _play_enemy_turn() -> void:
	if game_over:
		return

	var plan := enemy_ai.choose_move_plan(board)
	var move: Vector2i = plan.get("move", Vector2i(-1, -1))

	if move == Vector2i(-1, -1):
		_set_draw()
		return

	board.place_piece(move, BoardState.ENEMY)
	_record_move(move, BoardState.ENEMY)
	_apply_terrain_reward(move, BoardState.ENEMY)
	_show_feedback("%s 落子 %s。" % [enemy_ai.get_profile_name(), _format_board_pos(move)], [move], "enemy")
	_finish_turn(BoardState.ENEMY)

	if not game_over:
		enemy_turn_count += 1
		var rock_note := _resolve_rock_boss_pressure()

		if board.get_playable_cells().is_empty():
			_set_draw()
			return

		board.decay_seals()
		current_turn = BoardState.PLAYER
		_begin_turn(BoardState.PLAYER)
		var move_intent_hint := "%s：%s" % [plan.get("intent", enemy_ai.get_profile_intent()), plan.get("reason", "")]
		enemy_intent_hint = move_intent_hint if enemy_intent_hint.is_empty() or rock_note.is_empty() else "%s\n%s" % [move_intent_hint, enemy_intent_hint]
		_set_status("%s 落子于 %s，意图：%s。%s轮到你了。" % [
			enemy_ai.get_profile_name(),
			_format_board_pos(move),
			plan.get("intent", enemy_ai.get_profile_intent()),
			rock_note,
		])
		_refresh_board()


func _resolve_rock_boss_pressure() -> String:
	if enemy_ai.get_profile_id() != EnemyAI.PROFILE_ROCK_BOSS:
		return ""

	var turns_until_rock := ROCK_BOSS_ROCK_INTERVAL - enemy_turn_count % ROCK_BOSS_ROCK_INTERVAL

	if enemy_turn_count % ROCK_BOSS_ROCK_INTERVAL != 0:
		enemy_intent_hint = "岩阵压制：%d 个敌方回合后尝试生成岩石。" % turns_until_rock
		return "岩阵正在聚势，%d 回合后生成岩石。" % turns_until_rock

	var rock_target := enemy_ai.choose_rock_target(board)

	if rock_target == Vector2i(-1, -1):
		enemy_intent_hint = "岩阵压制：棋盘已无可生成岩石的位置。"
		return "岩阵没有找到可生成的位置。"

	board.set_terrain(rock_target, BoardState.TERRAIN_ROCK)
	enemy_intent_hint = "岩阵压制：在 %s 生成岩石，压缩你的连线空间。" % _format_board_pos(rock_target)
	_show_feedback("岩王造岩：%s 被岩石封住。" % _format_board_pos(rock_target), [rock_target], "rock")
	return "岩王在 %s 生成岩石。" % _format_board_pos(rock_target)


func _cycle_enemy_profile() -> void:
	if launched_from_run:
		return

	if enemy_profile_ids.is_empty():
		return

	enemy_profile_index = (enemy_profile_index + 1) % enemy_profile_ids.size()
	_start_new_game()


func _begin_turn(owner: int) -> void:
	board.decay_temporary_pieces(owner)
	_gain_energy(owner, 1)


func _apply_terrain_reward(pos: Vector2i, owner: int) -> void:
	if board.get_terrain(pos) != BoardState.TERRAIN_SPIRIT:
		return

	_gain_energy(owner, 1)
	var owner_text := "己方" if owner == BoardState.PLAYER else "敌方"
	_show_feedback("%s触发灵脉：%s 回复 1 点能量。" % [owner_text, _format_board_pos(pos)], [pos], "energy")


func _gain_energy(owner: int, amount: int) -> void:
	if owner == BoardState.PLAYER:
		player_energy = min(energy_max, player_energy + amount)
	else:
		enemy_energy = min(BASE_ENERGY_MAX, enemy_energy + amount)


func _spend_player_energy(amount: int) -> void:
	player_energy = max(0, player_energy - amount)


func _get_skill_cost(skill_id: String) -> int:
	return skill_executor.get_cost(skill_id)


func _can_afford_skill(skill_id: String) -> bool:
	return player_energy >= _get_skill_cost(skill_id)


func _preview_skill(skill_id: String, pos: Vector2i) -> Dictionary:
	var preview := skill_executor.preview(board, skill_id, pos, player_energy)
	var cost := _get_skill_cost(skill_id)
	preview["energy_cost"] = cost
	preview["energy_after"] = max(0, player_energy - cost)

	if player_energy < cost:
		preview["valid"] = false
		preview["invalid_reason"] = "not enough energy"

	return preview


func _consume_skill_refund(skill_id: String) -> int:
	if skill_id == SkillExecutorScript.SKILL_ROCK_BREAK and rock_break_refunds_left > 0:
		rock_break_refunds_left -= 1
		return 1

	if skill_id == SkillExecutorScript.SKILL_SEAL_MOVE and seal_refunds_left > 0:
		seal_refunds_left -= 1
		return 1

	return 0


func _on_skill_pressed(skill_id: String) -> void:
	if game_over or current_turn != BoardState.PLAYER:
		return

	if not _can_afford_skill(skill_id):
		_set_status("%s 需要 %d 点能量。" % [skill_executor.get_skill_name(skill_id), _get_skill_cost(skill_id)])
		return

	if not skill_executor.requires_target(skill_id):
		_use_instant_skill(skill_id)
		return

	if selected_skill_id == skill_id:
		selected_skill_id = ""
		_set_status("已取消术法。可以落子，或选择其他术法。")
	else:
		selected_skill_id = skill_id
		_set_status(_format_selected_skill_prompt(skill_id))

	_refresh_board()


func _on_cell_hovered(pos: Vector2i) -> void:
	if game_over or current_turn != BoardState.PLAYER or selected_skill_id.is_empty():
		return

	if not skill_executor.is_valid_target(board, selected_skill_id, pos):
		return

	var preview := _preview_skill(selected_skill_id, pos)
	_set_status(_format_skill_preview(preview))


func _try_use_targeted_skill(pos: Vector2i) -> void:
	if not _can_afford_skill(selected_skill_id):
		_set_status("%s 需要 %d 点能量。" % [skill_executor.get_skill_name(selected_skill_id), _get_skill_cost(selected_skill_id)])
		selected_skill_id = ""
		_refresh_board()
		return

	if not skill_executor.is_valid_target(board, selected_skill_id, pos):
		_set_status("%s 不能以该格为目标。" % skill_executor.get_skill_name(selected_skill_id))
		return

	var skill_name: String = skill_executor.get_skill_name(selected_skill_id)
	var cost: int = _get_skill_cost(selected_skill_id)

	if not skill_executor.execute(board, selected_skill_id, pos):
		_set_status("%s 在 %s 施放失败。" % [skill_name, _format_board_pos(pos)])
		return

	_spend_player_energy(cost)
	var feedback_kind := "skill"
	var feedback_text := "%s 生效：%s。" % [skill_name, _format_board_pos(pos)]

	if selected_skill_id == SkillExecutorScript.SKILL_ROCK_CREATE:
		feedback_kind = "rock"
		feedback_text = "%s 生效：%s 生成岩石。" % [skill_name, _format_board_pos(pos)]
	elif selected_skill_id == SkillExecutorScript.SKILL_ROCK_BREAK:
		feedback_kind = "rock"
		feedback_text = "%s 生效：%s 的岩石被移除。" % [skill_name, _format_board_pos(pos)]

	var refund := _consume_skill_refund(selected_skill_id)
	var refund_note := ""

	if refund > 0:
		_gain_energy(BoardState.PLAYER, refund)
		refund_note = " 触发奖励，返还 %d 点能量。" % refund

	selected_skill_id = ""
	warning_target = Vector2i(-1, -1)
	_set_status("%s 已作用于 %s。%s请落子结束本回合。" % [skill_name, _format_board_pos(pos), refund_note])
	_show_feedback("%s%s" % [feedback_text, refund_note], [pos], feedback_kind)
	_refresh_board()


func _use_instant_skill(skill_id: String) -> void:
	var skill_name: String = skill_executor.get_skill_name(skill_id)
	var cost := _get_skill_cost(skill_id)

	if skill_id == SkillExecutorScript.SKILL_BREAK_ARRAY:
		break_array_active = true
		_spend_player_energy(cost)
		selected_skill_id = ""
		warning_target = Vector2i(-1, -1)
		_set_status("%s 已准备：下一手若形成三连或以上，回复 1 点能量。" % skill_name)
		_show_feedback("%s 已准备：等待下一手触发。" % skill_name, [], "skill")
		_refresh_board()
		return

	if skill_id == SkillExecutorScript.SKILL_TWIN_PIECE:
		twin_piece_active = true
		_spend_player_energy(cost)
		selected_skill_id = ""
		warning_target = Vector2i(-1, -1)
		_set_status("%s 已准备：下一手旁边会生成一颗持续 2 回合的临时棋。" % skill_name)
		_show_feedback("%s 已准备：下一手会寻找相邻空格。" % skill_name, [], "skill")
		_refresh_board()
		return

	var predicted_move := enemy_ai.choose_move(board)

	_spend_player_energy(cost)
	selected_skill_id = ""
	warning_target = predicted_move

	if predicted_move == Vector2i(-1, -1):
		_set_status("%s 未发现敌方合法落点。" % skill_name)
		_show_feedback("%s 未发现敌方合法落点。" % skill_name, [], "skill")
	else:
		_set_status("%s 预判危险点在 %s。" % [skill_name, _format_board_pos(predicted_move)])
		_show_feedback("%s 标记危险点：%s。" % [skill_name, _format_board_pos(predicted_move)], [predicted_move], "skill")

	_refresh_board()


func _resolve_player_piece_skills(pos: Vector2i) -> Array:
	var notes: Array = []

	if break_array_active:
		break_array_active = false
		var line := rule_checker.find_longest_line_through(board, pos, BoardState.PLAYER)

		if line.size() >= 3:
			_gain_energy(BoardState.PLAYER, 1)
			notes.append("破阵回复 1 点能量。")
			_show_feedback("破阵触发：形成 %d 连，回复 1 点能量。" % line.size(), line, "energy")
		else:
			notes.append("破阵未触发三连。")

	if twin_piece_active:
		twin_piece_active = false
		var twin_target := _find_twin_piece_target(pos)

		if twin_target == Vector2i(-1, -1):
			notes.append("双生子没有找到相邻空格。")
		elif board.place_piece(twin_target, BoardState.PLAYER, 2):
			notes.append("双生子在 %s 生成临时棋。" % _format_board_pos(twin_target))
			_show_feedback("双生子触发：%s 生成临时棋。" % _format_board_pos(twin_target), [twin_target], "skill")

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
		var winner := "你获胜" if owner == BoardState.PLAYER else "敌方获胜"
		_record_battle_result(owner == BoardState.PLAYER)
		_set_status("%s：连线 %s。可以重新开始。" % [winner, _format_line(winning_line)])
		_show_result_banner(owner == BoardState.PLAYER, _format_line(winning_line))
		_refresh_board()
		return

	if board.get_playable_cells().is_empty():
		_set_draw()
		return

	_refresh_board()


func _set_draw() -> void:
	game_over = true
	_record_battle_result(false)
	_set_status("平局。可以重新开始。")
	_show_result_banner(false, "棋盘已无可落子")
	_refresh_board()


func _record_battle_result(player_won: bool) -> void:
	if not launched_from_run:
		return

	get_tree().root.set_meta(BATTLE_RESULT_META, "victory" if player_won else "defeat")


func _return_to_run_map() -> void:
	if not launched_from_run or not game_over:
		return

	get_tree().change_scene_to_file(RUN_MAP_SCENE_PATH)


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text


func _clear_feedback() -> void:
	feedback_log.clear()
	feedback_flashes.clear()
	feedback_flash_token += 1

	if feedback_label != null:
		feedback_label.text = "最近动作会显示在这里。"


func _hide_result_banner() -> void:
	if result_banner_tween != null:
		result_banner_tween.kill()
		result_banner_tween = null

	if result_banner_label != null:
		result_banner_label.visible = false
		result_banner_label.modulate = Color(1, 1, 1, 1)
		result_banner_label.scale = Vector2.ONE


func _show_result_banner(player_won: bool, detail: String) -> void:
	if result_banner_label == null:
		return

	if result_banner_tween != null:
		result_banner_tween.kill()

	var title := "胜利" if player_won else "失利"
	var hint := "返回路线领取战利品" if player_won and launched_from_run else "重新整备后再战"
	var banner_style := _make_panel_style(Color("#243f35") if player_won else Color("#472e31"), Color("#f0c65a") if player_won else Color("#d87568"))

	result_banner_label.text = "%s  ·  %s\n%s" % [title, detail, hint]
	result_banner_label.add_theme_stylebox_override("normal", banner_style)
	result_banner_label.visible = true
	result_banner_label.modulate = Color(1, 1, 1, 0.0)
	result_banner_label.scale = Vector2.ONE
	result_banner_tween = create_tween()
	result_banner_tween.tween_property(result_banner_label, "modulate", Color(1, 1, 1, 1), 0.18)
	result_banner_tween.tween_property(result_banner_label, "scale", Vector2(1.02, 1.02), 0.12)
	result_banner_tween.tween_property(result_banner_label, "scale", Vector2.ONE, 0.12)
	_play_feedback_tone("victory" if player_won else "defeat")


func _show_feedback(text: String, target_cells: Array = [], kind: String = "skill") -> void:
	if not text.is_empty():
		feedback_log.push_front(text)

		while feedback_log.size() > 3:
			feedback_log.pop_back()

		if feedback_label != null:
			feedback_label.text = "\n".join(feedback_log)

		_play_feedback_tone(kind)

	if not target_cells.is_empty() and not kind.is_empty():
		_flash_cells(target_cells, kind)


func _flash_cells(target_cells: Array, kind: String) -> void:
	feedback_flash_token += 1
	var token := feedback_flash_token

	for cell in target_cells:
		if cell is Vector2i and board.is_inside(cell):
			feedback_flashes[cell] = kind

	_refresh_board()

	await get_tree().create_timer(0.55).timeout

	if token != feedback_flash_token:
		return

	feedback_flashes.clear()
	_refresh_board()


func _get_feedback_style(kind: String, fallback: StyleBoxFlat) -> StyleBoxFlat:
	match kind:
		"player":
			return feedback_player_style
		"enemy":
			return feedback_enemy_style
		"rock":
			return feedback_rock_style
		"energy":
			return feedback_energy_style
		"skill":
			return feedback_skill_style
		_:
			return fallback


func _play_feedback_tone(kind: String) -> void:
	if tone_player != null:
		tone_player.play_kind(kind)


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
				button.tooltip_text = _format_skill_preview(_preview_skill(selected_skill_id, pos))
			elif owner == BoardState.EMPTY and pos == warning_target:
				button.text = "!"
				style = warning_style

			if feedback_flashes.has(pos) and not winning_line.has(pos):
				style = _get_feedback_style(feedback_flashes[pos], style)

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
	var cost := _get_skill_cost(skill_id)
	var remaining: int = max(0, player_energy - cost)
	return "已选择 %s：消耗 %d 点能量，施放后剩余 %d/%d。悬停高亮格可查看预览。" % [skill_executor.get_skill_name(skill_id), cost, remaining, energy_max]


func _format_skill_preview(preview: Dictionary) -> String:
	if not preview.get("valid", false):
		return "%s 无法预览：%s。" % [preview.get("skill_name", "术法"), _translate_invalid_reason(preview.get("invalid_reason", "invalid target"))]

	var affected_cells: Array = preview.get("affected_cells", [])
	var impact_notes: Array = preview.get("impact_notes", [])
	var parts := [
		"%s 预览：消耗 %d，剩余能量 %d/%d。" % [
			preview.get("skill_name", "术法"),
			preview.get("energy_cost", 0),
			preview.get("energy_after", player_energy),
			energy_max,
		]
	]

	if not affected_cells.is_empty():
		parts.append("影响 %s。" % _format_cell_list(affected_cells))

	var terrain_change: String = preview.get("terrain_change", "")

	if not terrain_change.is_empty():
		parts.append("地形 %s。" % terrain_change)

	if not impact_notes.is_empty():
		parts.append(" ".join(impact_notes))

	return " ".join(parts)


func _translate_invalid_reason(reason: String) -> String:
	match reason:
		"not enough energy":
			return "能量不足"
		"invalid target":
			return "目标不合法"
		_:
			return reason


func _format_cell_list(cell_list: Array) -> String:
	var formatted: Array = []

	for cell in cell_list:
		formatted.append(_format_board_pos(cell))

	return ", ".join(formatted)


func _refresh_skill_buttons() -> void:
	for skill_id in skill_buttons:
		var button: Button = skill_buttons[skill_id]
		var cost: int = _get_skill_cost(skill_id)
		var name: String = skill_executor.get_skill_name(skill_id)
		var prefix := "选中 · " if selected_skill_id == skill_id else ""
		var already_active: bool = skill_id == SkillExecutorScript.SKILL_BREAK_ARRAY and break_array_active
		already_active = already_active or skill_id == SkillExecutorScript.SKILL_TWIN_PIECE and twin_piece_active

		button.text = "%s%s\n%d 能量" % [prefix, name, cost]
		button.tooltip_text = skill_executor.get_description(skill_id)
		button.disabled = game_over or current_turn != BoardState.PLAYER or already_active or not _can_afford_skill(skill_id)


func _refresh_info_labels() -> void:
	if turn_label == null or move_count_label == null or energy_label == null or enemy_profile_label == null or enemy_intent_hint_label == null:
		return

	var turn_text := "战斗结束"

	if not game_over:
		turn_text = "己方回合" if current_turn == BoardState.PLAYER else "敌方回合"

	turn_label.text = turn_text
	move_count_label.text = "落子数：%d" % move_count
	energy_label.text = "己方能量：%d/%d\n敌方能量：%d/%d" % [player_energy, energy_max, enemy_energy, BASE_ENERGY_MAX]
	enemy_profile_label.text = "%s\n%s" % [enemy_ai.get_profile_name(), enemy_ai.get_profile_intent()]
	enemy_intent_hint_label.text = enemy_intent_hint

	if enemy_profile_button != null:
		if launched_from_run:
			enemy_profile_button.text = "路线敌人：%s" % enemy_ai.get_profile_name()
		else:
			enemy_profile_button.text = "切换敌人：%s" % enemy_ai.get_profile_name()

		enemy_profile_button.disabled = launched_from_run

	if return_to_map_button != null:
		return_to_map_button.visible = launched_from_run
		return_to_map_button.disabled = not launched_from_run or not game_over


func _format_enemy_intro() -> String:
	if enemy_ai.get_profile_id() == EnemyAI.PROFILE_ROCK_BOSS:
		return "岩王开局布置岩阵，并每 %d 个敌方回合尝试生成岩石。" % ROCK_BOSS_ROCK_INTERVAL

	return "当前棋风：%s。落子后会显示具体意图。" % enemy_ai.get_profile_intent()


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
