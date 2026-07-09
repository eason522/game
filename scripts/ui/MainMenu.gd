extends Control

const RUN_STATE_META := "tymj_run_state"
const RUN_MAP_SCENE_PATH := "res://scenes/roguelike/RunMapScene.tscn"
const BATTLE_SCENE_PATH := "res://scenes/game/BattleScene.tscn"
const RunSaveScript := preload("res://scripts/roguelike/RunSave.gd")
const RunStateScript := preload("res://scripts/roguelike/RunState.gd")
const RunPlaytestSimulatorScript := preload("res://scripts/roguelike/RunPlaytestSimulator.gd")

var title_label: Label
var subtitle_label: Label
var summary_label: Label
var status_label: Label
var start_button: Button
var continue_button: Button
var battle_button: Button
var playtest_simulator := RunPlaytestSimulatorScript.new()
var panel_style: StyleBoxFlat
var button_style: StyleBoxFlat
var button_hover_style: StyleBoxFlat
var button_disabled_style: StyleBoxFlat


func _ready() -> void:
	_create_styles()
	_build_layout()
	_refresh_continue_state()


func _create_styles() -> void:
	panel_style = _make_panel_style(Color("#202832"), Color("#43505e"))
	button_style = _make_panel_style(Color("#314353"), Color("#668195"))
	button_hover_style = _make_panel_style(Color("#3a5265"), Color("#86a8bd"))
	button_disabled_style = _make_panel_style(Color("#242b33"), Color("#343b45"))


func _make_panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style


func _build_layout() -> void:
	var background := ColorRect.new()
	background.color = Color("#10151b")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var root_margin := MarginContainer.new()
	root_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 72)
	root_margin.add_theme_constant_override("margin_top", 58)
	root_margin.add_theme_constant_override("margin_right", 72)
	root_margin.add_theme_constant_override("margin_bottom", 56)
	add_child(root_margin)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 34)
	root_margin.add_child(root)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 18)
	root.add_child(left)

	var title_spacer := Control.new()
	title_spacer.custom_minimum_size = Vector2(0, 58)
	left.add_child(title_spacer)

	title_label = Label.new()
	title_label.text = "天元迷局"
	title_label.add_theme_font_size_override("font_size", 52)
	title_label.add_theme_color_override("font_color", Color("#f1dfb7"))
	left.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "岩之国 Demo"
	subtitle_label.add_theme_font_size_override("font_size", 20)
	subtitle_label.add_theme_color_override("font_color", Color("#91a7b6"))
	left.add_child(subtitle_label)

	var summary_panel := PanelContainer.new()
	summary_panel.add_theme_stylebox_override("panel", panel_style)
	summary_panel.custom_minimum_size = Vector2(0, 184)
	left.add_child(summary_panel)

	summary_label = Label.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.add_theme_font_size_override("font_size", 16)
	summary_label.add_theme_color_override("font_color", Color("#cde8df"))
	summary_panel.add_child(summary_label)

	var right_panel := PanelContainer.new()
	right_panel.custom_minimum_size = Vector2(360, 0)
	right_panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(right_panel)

	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	right_panel.add_child(actions)

	var action_title := Label.new()
	action_title.text = "开始"
	action_title.add_theme_font_size_override("font_size", 26)
	action_title.add_theme_color_override("font_color", Color("#f1dfb7"))
	actions.add_child(action_title)

	continue_button = _make_action_button("继续 Run")
	continue_button.pressed.connect(_continue_run)
	actions.add_child(continue_button)

	start_button = _make_action_button("新的 Run")
	start_button.pressed.connect(_start_new_run)
	actions.add_child(start_button)

	battle_button = _make_action_button("单局战斗")
	battle_button.pressed.connect(_start_single_battle)
	actions.add_child(battle_button)

	var divider := HSeparator.new()
	actions.add_child(divider)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color("#91a7b6"))
	actions.add_child(status_label)


func _make_action_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 54)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_stylebox_override("normal", button_style)
	button.add_theme_stylebox_override("hover", button_hover_style)
	button.add_theme_stylebox_override("pressed", button_hover_style)
	button.add_theme_stylebox_override("disabled", button_disabled_style)
	button.add_theme_color_override("font_color", Color("#edf6f2"))
	button.add_theme_color_override("font_disabled_color", Color("#74838c"))
	return button


func _refresh_continue_state() -> void:
	var resume_state = _load_resume_state()
	var has_run := resume_state != null
	continue_button.disabled = not has_run

	if has_run:
		var next_action_lines: Array = playtest_simulator.get_editor_next_action_lines(resume_state)
		var closeout_lines: Array = playtest_simulator.get_editor_closeout_packet_lines(resume_state)
		var snapshot_lines: Array = playtest_simulator.get_live_playtest_snapshot_lines(resume_state)
		continue_button.text = _resume_button_text(resume_state)
		status_label.text = "检测到可继续的 Run。\n%s" % _first_line(next_action_lines)
		summary_label.text = "%s\n主菜单进度：%s\n主菜单速览：%s\n%s\n%s" % [
			_base_summary_text(),
			_first_line(snapshot_lines).trim_prefix("实机快照："),
			" / ".join(closeout_lines),
			_get_main_menu_check_line(resume_state, snapshot_lines, closeout_lines),
			_get_main_menu_baseline_line(),
		]
	else:
		continue_button.text = "继续 Run"
		status_label.text = "暂无存档，从新的 Run 开始。"
		summary_label.text = "%s\n主菜单进度：暂无 Run 数据\n主菜单速览：等待首战记录。\n主菜单核对：继续按钮禁用；暂无 Run 数据；从新的 Run 开始首战。\n%s" % [
			_base_summary_text(),
			_get_main_menu_baseline_line(),
		]


func _base_summary_text() -> String:
	return "当前目标：完成一轮从试锋之局到岩王的 Roguelike Run。\n验收重点：记录实测手数、Boss 前 5 手快照、静息调气体感与编辑器收口包。"


func _load_resume_state():
	var data := {}

	if get_tree().root.has_meta(RUN_STATE_META):
		var root_state = get_tree().root.get_meta(RUN_STATE_META)

		if typeof(root_state) == TYPE_DICTIONARY:
			data = root_state

	if data.is_empty() and RunSaveScript.has_save():
		data = RunSaveScript.load_dict()

	if data.is_empty():
		return null

	var state := RunStateScript.new()
	state.load_from_dict(data)
	return state


func _first_line(lines: Array) -> String:
	if lines.is_empty():
		return "编辑器指引：从路线图开始完整 Run"

	return String(lines[0])


func _get_main_menu_check_line(run_state, snapshot_lines: Array, closeout_lines: Array) -> String:
	var action_text := _resume_button_text(run_state).trim_prefix("继续：")
	var progress_text := _first_line(snapshot_lines).trim_prefix("实机快照：")
	var closeout_text := _first_line(closeout_lines).trim_prefix("编辑器收口包：")
	return "主菜单核对：%s；%s；%s" % [action_text, progress_text, closeout_text]


func _get_main_menu_baseline_line() -> String:
	var report: Dictionary = playtest_simulator.run_baseline()
	var pacing: Dictionary = report.get("pacing", {})
	return "主菜单基准：%d/%d 场目标内，总 %d 手，星砂 %d，奖励 %d" % [
		pacing.get("on_target_count", 0),
		pacing.get("recorded_battle_nodes", 0),
		pacing.get("actual_turn_total", 0),
		report.get("coins", 0),
		report.get("reward_count", 0),
	]


func _resume_button_text(run_state) -> String:
	if run_state == null:
		return "继续 Run"

	if run_state.run_failed:
		return "继续：复盘失败"

	if run_state.run_completed:
		if run_state.boss_opening_feel.is_empty():
			return "继续：记录 Boss 体感"

		return "继续：查看验收结果"

	if run_state.has_pending_reward():
		return "继续：领取战利品"

	if run_state.has_pending_node_choice():
		return "继续：处理路线选择"

	var current_node: Dictionary = run_state.get_current_node() if run_state.has_method("get_current_node") else {}
	var title: String = current_node.get("title", "当前节点")

	match current_node.get("type", ""):
		RunStateScript.NODE_BATTLE, RunStateScript.NODE_BOSS:
			return "继续：进入%s" % title
		RunStateScript.NODE_EVENT, RunStateScript.NODE_SHOP, RunStateScript.NODE_REST:
			return "继续：处理%s" % title
		_:
			return "继续 Run"


func _start_new_run() -> void:
	if get_tree().root.has_meta(RUN_STATE_META):
		get_tree().root.remove_meta(RUN_STATE_META)

	RunSaveScript.delete_save()
	get_tree().change_scene_to_file(RUN_MAP_SCENE_PATH)


func _continue_run() -> void:
	get_tree().change_scene_to_file(RUN_MAP_SCENE_PATH)


func _start_single_battle() -> void:
	get_tree().change_scene_to_file(BATTLE_SCENE_PATH)
