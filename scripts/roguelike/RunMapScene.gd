extends Control

const RUN_STATE_META := "tymj_run_state"
const BATTLE_NODE_INDEX_META := "tymj_battle_node_index"
const BATTLE_RESULT_META := "tymj_battle_result"
const BATTLE_ENEMY_PROFILE_META := "tymj_battle_enemy_profile_id"
const BATTLE_SCENE_PATH := "res://scenes/game/BattleScene.tscn"
const MapGeneratorScript := preload("res://scripts/roguelike/MapGenerator.gd")
const RunStateScript := preload("res://scripts/roguelike/RunState.gd")

var map_generator := MapGeneratorScript.new()
var run_state := RunStateScript.new()
var status_label: Label
var node_list: VBoxContainer
var node_buttons: Array = []
var panel_style: StyleBoxFlat
var button_style: StyleBoxFlat
var button_hover_style: StyleBoxFlat
var button_disabled_style: StyleBoxFlat
var boss_button_style: StyleBoxFlat


func _ready() -> void:
	_create_styles()
	_load_or_create_run_state()
	_apply_pending_battle_result()
	_build_layout()
	_refresh()


func _create_styles() -> void:
	panel_style = _make_panel_style(Color("#202832"), Color("#43505e"))
	button_style = _make_panel_style(Color("#314353"), Color("#668195"))
	button_hover_style = _make_panel_style(Color("#3a5265"), Color("#86a8bd"))
	button_disabled_style = _make_panel_style(Color("#242b33"), Color("#343b45"))
	boss_button_style = _make_panel_style(Color("#4a3030"), Color("#c06b55"))


func _make_panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _load_or_create_run_state() -> void:
	var root := get_tree().root

	if root.has_meta(RUN_STATE_META):
		run_state = RunStateScript.new()
		run_state.load_from_dict(root.get_meta(RUN_STATE_META))
		return

	run_state.setup(map_generator.generate_linear_route())
	root.set_meta(RUN_STATE_META, run_state.to_dict())


func _apply_pending_battle_result() -> void:
	var root := get_tree().root

	if not root.has_meta(BATTLE_RESULT_META):
		return

	var result: String = root.get_meta(BATTLE_RESULT_META)
	var node_index: int = root.get_meta(BATTLE_NODE_INDEX_META, -1)

	if node_index == run_state.current_index:
		run_state.resolve_current_node(result == "victory")

	root.set_meta(RUN_STATE_META, run_state.to_dict())
	root.remove_meta(BATTLE_RESULT_META)
	root.remove_meta(BATTLE_NODE_INDEX_META)
	root.remove_meta(BATTLE_ENEMY_PROFILE_META)


func _build_layout() -> void:
	var background := ColorRect.new()
	background.color = Color("#11161c")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var root_margin := MarginContainer.new()
	root_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 42)
	root_margin.add_theme_constant_override("margin_top", 30)
	root_margin.add_theme_constant_override("margin_right", 42)
	root_margin.add_theme_constant_override("margin_bottom", 34)
	add_child(root_margin)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 16)
	root_margin.add_child(main)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	main.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)

	var title := Label.new()
	title.text = "天元迷局"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("#f1dfb7"))
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "一线试炼路线"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color("#91a7b6"))
	title_box.add_child(subtitle)

	var new_run_button := Button.new()
	new_run_button.text = "重新开始 Run"
	new_run_button.custom_minimum_size = Vector2(190, 48)
	new_run_button.pressed.connect(_restart_run)
	_apply_button_theme(new_run_button)
	header.add_child(new_run_button)

	var content_panel := PanelContainer.new()
	content_panel.add_theme_stylebox_override("panel", panel_style)
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(content_panel)

	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 24)
	content_margin.add_theme_constant_override("margin_top", 22)
	content_margin.add_theme_constant_override("margin_right", 24)
	content_margin.add_theme_constant_override("margin_bottom", 24)
	content_panel.add_child(content_margin)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 24)
	content_margin.add_child(content)

	node_list = VBoxContainer.new()
	node_list.custom_minimum_size = Vector2(640, 0)
	node_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	node_list.add_theme_constant_override("separation", 10)
	content.add_child(node_list)

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(360, 0)
	side.add_theme_constant_override("separation", 12)
	content.add_child(side)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color("#cde8df"))
	status_label.add_theme_stylebox_override("normal", panel_style)
	side.add_child(status_label)

	var tip := Label.new()
	tip.text = "胜利会解锁下一局；失败后可重新开始 Run。"
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_size_override("font_size", 15)
	tip.add_theme_color_override("font_color", Color("#91a7b6"))
	tip.add_theme_stylebox_override("normal", panel_style)
	side.add_child(tip)

	_create_node_buttons()


func _create_node_buttons() -> void:
	node_buttons.clear()

	for node in run_state.nodes:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 76)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_enter_node.bind(node.get("index", -1)))
		_apply_button_theme(button)
		node_list.add_child(button)
		node_buttons.append(button)


func _apply_button_theme(button: Button) -> void:
	button.add_theme_stylebox_override("normal", button_style)
	button.add_theme_stylebox_override("hover", button_hover_style)
	button.add_theme_stylebox_override("pressed", button_hover_style)
	button.add_theme_stylebox_override("disabled", button_disabled_style)
	button.add_theme_color_override("font_color", Color("#f3ead1"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("#f0c65a"))
	button.add_theme_color_override("font_disabled_color", Color("#77828c"))
	button.add_theme_font_size_override("font_size", 17)


func _restart_run() -> void:
	run_state.setup(map_generator.generate_linear_route())
	get_tree().root.set_meta(RUN_STATE_META, run_state.to_dict())
	_refresh()


func _enter_node(index: int) -> void:
	if not run_state.can_enter_node(index):
		return

	var node: Dictionary = run_state.nodes[index]
	var root := get_tree().root
	root.set_meta(RUN_STATE_META, run_state.to_dict())
	root.set_meta(BATTLE_NODE_INDEX_META, index)
	root.set_meta(BATTLE_ENEMY_PROFILE_META, node.get("enemy_profile_id", EnemyAI.PROFILE_NOVICE))
	get_tree().change_scene_to_file(BATTLE_SCENE_PATH)


func _refresh() -> void:
	for index in range(node_buttons.size()):
		var node: Dictionary = run_state.nodes[index]
		var button: Button = node_buttons[index]
		var status_text := _status_text(node.get("status", RunStateScript.STATUS_LOCKED))
		var enemy_text := _enemy_text(node)

		button.text = "%s  %s\n%s%s" % [
			_type_mark(node.get("type", "")),
			node.get("title", ""),
			status_text,
			enemy_text,
		]
		button.disabled = not run_state.can_enter_node(index)

		if node.get("type", "") == RunStateScript.NODE_BOSS and node.get("status", "") == RunStateScript.STATUS_AVAILABLE:
			button.add_theme_stylebox_override("normal", boss_button_style)
			button.add_theme_stylebox_override("hover", boss_button_style)
		else:
			button.add_theme_stylebox_override("normal", button_style)
			button.add_theme_stylebox_override("hover", button_hover_style)

	if status_label == null:
		return

	if run_state.run_completed:
		status_label.text = "本轮 Run 已通关：岩王之局告破。"
	elif run_state.run_failed:
		status_label.text = "本轮 Run 已失败。重新开始后可再次挑战。"
	else:
		var current := run_state.get_current_node()
		status_label.text = "当前节点：%s\n%s" % [current.get("title", "无"), current.get("description", "")]


func _type_mark(node_type: String) -> String:
	match node_type:
		RunStateScript.NODE_START:
			return "起"
		RunStateScript.NODE_BOSS:
			return "王"
		_:
			return "战"


func _status_text(status: String) -> String:
	match status:
		RunStateScript.STATUS_COMPLETED:
			return "已完成"
		RunStateScript.STATUS_AVAILABLE:
			return "可挑战"
		RunStateScript.STATUS_FAILED:
			return "失败"
		_:
			return "未解锁"


func _enemy_text(node: Dictionary) -> String:
	var profile_id: String = node.get("enemy_profile_id", "")

	if profile_id.is_empty():
		return ""

	return " · 对阵 %s" % EnemyAI.get_profile_name_for_id(profile_id)
