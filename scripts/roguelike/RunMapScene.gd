extends Control

const RUN_STATE_META := "tymj_run_state"
const BATTLE_NODE_INDEX_META := "tymj_battle_node_index"
const BATTLE_RESULT_META := "tymj_battle_result"
const BATTLE_MOVE_COUNT_META := "tymj_battle_move_count"
const BATTLE_ENEMY_PROFILE_META := "tymj_battle_enemy_profile_id"
const DEMO_SOUND_ENABLED_META := "tymj_demo_sound_enabled"
const DEMO_HINTS_ENABLED_META := "tymj_demo_hints_enabled"
const BATTLE_SCENE_PATH := "res://scenes/game/BattleScene.tscn"
const MapGeneratorScript := preload("res://scripts/roguelike/MapGenerator.gd")
const RunStateScript := preload("res://scripts/roguelike/RunState.gd")
const RunSaveScript := preload("res://scripts/roguelike/RunSave.gd")
const RewardGeneratorScript := preload("res://scripts/roguelike/RewardGenerator.gd")
const RunPlaytestSimulatorScript := preload("res://scripts/roguelike/RunPlaytestSimulator.gd")
const SimpleTonePlayerScript := preload("res://scripts/audio/SimpleTonePlayer.gd")
const ROUTE_NODE_PULSE_IN_SECONDS := 0.14
const ROUTE_NODE_PULSE_OUT_SECONDS := 0.16
const ROUTE_NODE_PULSE_SCALE := Vector2(1.012, 1.012)

var map_generator := MapGeneratorScript.new()
var reward_generator := RewardGeneratorScript.new()
var playtest_simulator := RunPlaytestSimulatorScript.new()
var run_state := RunStateScript.new()
var loaded_from_save := false
var status_label: Label
var settlement_label: Label
var route_guide_label: Label
var reward_label: Label
var build_summary_label: Label
var sound_toggle_button: Button
var hints_toggle_button: Button
var tone_player
var node_list: VBoxContainer
var node_buttons: Array = []
var reward_buttons: Array = []
var last_rendered_feedback := ""
var last_claimed_reward_summary := ""
var last_rendered_node_statuses: Dictionary = {}
var node_button_tweens: Dictionary = {}
var last_pulsed_node_index := -1
var last_pulsed_node_status := ""
var route_node_pulse_seconds := ROUTE_NODE_PULSE_IN_SECONDS + ROUTE_NODE_PULSE_OUT_SECONDS
var sound_feedback_enabled := true
var route_hints_enabled := true
var settlement_tween: Tween
var reward_panel_tween: Tween
var panel_style: StyleBoxFlat
var button_style: StyleBoxFlat
var button_hover_style: StyleBoxFlat
var button_disabled_style: StyleBoxFlat
var event_button_style: StyleBoxFlat
var event_button_hover_style: StyleBoxFlat
var shop_button_style: StyleBoxFlat
var shop_button_hover_style: StyleBoxFlat
var rest_button_style: StyleBoxFlat
var rest_button_hover_style: StyleBoxFlat
var completed_button_style: StyleBoxFlat
var boss_button_style: StyleBoxFlat
var boss_button_hover_style: StyleBoxFlat


func _ready() -> void:
	_read_demo_preferences()
	_create_styles()
	_load_or_create_run_state()
	_apply_pending_battle_result()
	_build_layout()
	_create_audio_feedback()
	_refresh()


func _read_demo_preferences() -> void:
	var root := get_tree().root
	sound_feedback_enabled = root.get_meta(DEMO_SOUND_ENABLED_META, true)
	route_hints_enabled = root.get_meta(DEMO_HINTS_ENABLED_META, true)


func _create_styles() -> void:
	panel_style = _make_panel_style(Color("#202832"), Color("#43505e"))
	button_style = _make_panel_style(Color("#314353"), Color("#668195"))
	button_hover_style = _make_panel_style(Color("#3a5265"), Color("#86a8bd"))
	button_disabled_style = _make_panel_style(Color("#242b33"), Color("#343b45"))
	event_button_style = _make_panel_style(Color("#3d354e"), Color("#9077bd"))
	event_button_hover_style = _make_panel_style(Color("#4b4160"), Color("#b59be1"))
	shop_button_style = _make_panel_style(Color("#423b2b"), Color("#c59a45"))
	shop_button_hover_style = _make_panel_style(Color("#514832"), Color("#e1bd6f"))
	rest_button_style = _make_panel_style(Color("#2f493f"), Color("#72b597"))
	rest_button_hover_style = _make_panel_style(Color("#385848"), Color("#9ed6bc"))
	completed_button_style = _make_panel_style(Color("#273038"), Color("#566271"))
	boss_button_style = _make_panel_style(Color("#4a3030"), Color("#c06b55"))
	boss_button_hover_style = _make_panel_style(Color("#5a3835"), Color("#de8972"))


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

	var saved_state := RunSaveScript.load_dict()

	if not saved_state.is_empty():
		run_state = RunStateScript.new()
		run_state.load_from_dict(saved_state)
		loaded_from_save = true
		root.set_meta(RUN_STATE_META, run_state.to_dict())
		return

	run_state.setup(map_generator.generate_linear_route())
	_persist_run_state()


func _apply_pending_battle_result() -> void:
	var root := get_tree().root

	if not root.has_meta(BATTLE_RESULT_META):
		return

	var result: String = root.get_meta(BATTLE_RESULT_META)
	var node_index: int = root.get_meta(BATTLE_NODE_INDEX_META, -1)
	var move_count: int = root.get_meta(BATTLE_MOVE_COUNT_META, 0)

	if node_index == run_state.current_index:
		var reward_options: Array = []

		if result == "victory":
			var current_node := run_state.get_current_node()

			if current_node.get("type", "") != RunStateScript.NODE_BOSS:
				reward_options = reward_generator.generate_options(run_state, current_node)

		run_state.resolve_current_node(result == "victory", reward_options, move_count)

	_persist_run_state()
	root.remove_meta(BATTLE_RESULT_META)
	root.remove_meta(BATTLE_NODE_INDEX_META)
	root.remove_meta(BATTLE_MOVE_COUNT_META)
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

	settlement_label = Label.new()
	settlement_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settlement_label.add_theme_font_size_override("font_size", 15)
	settlement_label.add_theme_color_override("font_color", Color("#f1dfb7"))
	settlement_label.add_theme_stylebox_override("normal", panel_style)
	side.add_child(settlement_label)

	route_guide_label = Label.new()
	route_guide_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	route_guide_label.add_theme_font_size_override("font_size", 15)
	route_guide_label.add_theme_color_override("font_color", Color("#91a7b6"))
	route_guide_label.add_theme_stylebox_override("normal", panel_style)
	side.add_child(route_guide_label)

	var settings_panel := _create_settings_panel()
	side.add_child(settings_panel)

	_create_reward_panel(side)
	_create_node_buttons()


func _create_settings_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

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
	title.text = "Demo 设置"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("#b8c5d0"))
	box.add_child(title)

	sound_toggle_button = Button.new()
	sound_toggle_button.toggle_mode = true
	sound_toggle_button.button_pressed = sound_feedback_enabled
	sound_toggle_button.custom_minimum_size = Vector2(0, 38)
	sound_toggle_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sound_toggle_button.toggled.connect(_on_sound_toggled)
	_apply_button_theme(sound_toggle_button)
	box.add_child(sound_toggle_button)

	hints_toggle_button = Button.new()
	hints_toggle_button.toggle_mode = true
	hints_toggle_button.button_pressed = route_hints_enabled
	hints_toggle_button.custom_minimum_size = Vector2(0, 38)
	hints_toggle_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hints_toggle_button.toggled.connect(_on_hints_toggled)
	_apply_button_theme(hints_toggle_button)
	box.add_child(hints_toggle_button)

	_refresh_demo_setting_buttons()
	return panel


func _create_reward_panel(parent: Control) -> void:
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

	reward_label = Label.new()
	reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward_label.add_theme_font_size_override("font_size", 16)
	reward_label.add_theme_color_override("font_color", Color("#f1dfb7"))
	box.add_child(reward_label)

	build_summary_label = Label.new()
	build_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build_summary_label.add_theme_font_size_override("font_size", 14)
	build_summary_label.add_theme_color_override("font_color", Color("#a9c7bd"))
	box.add_child(build_summary_label)

	for index in range(3):
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 76)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_claim_panel_choice_at.bind(index))
		_apply_button_theme(button)
		box.add_child(button)
		reward_buttons.append(button)


func _create_node_buttons() -> void:
	node_buttons.clear()

	for node in run_state.nodes:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 76)
		button.pivot_offset = Vector2(320, 38)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_enter_node.bind(node.get("index", -1)))
		_apply_button_theme(button)
		node_list.add_child(button)
		node_buttons.append(button)


func _create_audio_feedback() -> void:
	tone_player = SimpleTonePlayerScript.new()
	tone_player.name = "RunMapTonePlayer"
	add_child(tone_player)
	tone_player.set_feedback_enabled(sound_feedback_enabled)


func _on_sound_toggled(enabled: bool) -> void:
	sound_feedback_enabled = enabled
	get_tree().root.set_meta(DEMO_SOUND_ENABLED_META, sound_feedback_enabled)

	if tone_player != null:
		tone_player.set_feedback_enabled(sound_feedback_enabled)

	_refresh_demo_setting_buttons()


func _on_hints_toggled(enabled: bool) -> void:
	route_hints_enabled = enabled
	get_tree().root.set_meta(DEMO_HINTS_ENABLED_META, route_hints_enabled)
	_refresh_demo_setting_buttons()
	_refresh()


func _refresh_demo_setting_buttons() -> void:
	if sound_toggle_button != null:
		sound_toggle_button.text = "音效提示：开" if sound_feedback_enabled else "音效提示：关"
		sound_toggle_button.button_pressed = sound_feedback_enabled

	if hints_toggle_button != null:
		hints_toggle_button.text = "入门提示：开" if route_hints_enabled else "入门提示：关"
		hints_toggle_button.button_pressed = route_hints_enabled


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
	loaded_from_save = false
	_persist_run_state()
	_refresh()


func _enter_node(index: int) -> void:
	if not run_state.can_enter_node(index):
		return

	var node: Dictionary = run_state.nodes[index]
	var node_type: String = node.get("type", "")

	if node_type != RunStateScript.NODE_BATTLE and node_type != RunStateScript.NODE_BOSS:
		_open_route_choice_node(index)
		return

	var root := get_tree().root
	_persist_run_state()
	root.set_meta(BATTLE_NODE_INDEX_META, index)
	root.set_meta(BATTLE_ENEMY_PROFILE_META, node.get("enemy_profile_id", EnemyAI.PROFILE_NOVICE))
	get_tree().change_scene_to_file(BATTLE_SCENE_PATH)


func _open_route_choice_node(index: int) -> void:
	var node: Dictionary = run_state.nodes[index]
	var choices := reward_generator.generate_node_choices(run_state, node)

	if choices.is_empty():
		run_state.resolve_current_node(true)
	else:
		run_state.open_node_choices(choices)

	_persist_run_state()
	_refresh()


func _claim_panel_choice_at(index: int) -> void:
	if run_state.has_pending_reward():
		_claim_reward_at(index)
		return

	_claim_node_choice_at(index)


func _claim_reward_at(index: int) -> void:
	if index < 0 or index >= run_state.pending_rewards.size():
		return

	var reward: Dictionary = run_state.pending_rewards[index]

	if run_state.claim_reward(reward.get("id", "")):
		_mark_claimed_reward_feedback(reward)
		_persist_run_state()
		_refresh()


func _claim_node_choice_at(index: int) -> void:
	if index < 0 or index >= run_state.pending_node_choices.size():
		return

	var choice: Dictionary = run_state.pending_node_choices[index]

	if run_state.claim_node_choice(choice.get("id", "")):
		_persist_run_state()
		_refresh()


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
			"%s%s" % [enemy_text, _node_pacing_text(node)],
		]
		button.tooltip_text = _node_tooltip(node)
		button.disabled = not run_state.can_enter_node(index)
		_apply_node_button_style(button, node)
		_pulse_node_button_if_changed(index, node, button)

	if status_label == null:
		return

	if settlement_label != null:
		_refresh_settlement_feedback()

	if run_state.run_completed:
		status_label.text = "本轮 Run 已通关：岩王之局告破。可以开始新 Run。"
	elif run_state.run_failed:
		status_label.text = "本轮 Run 已失败。重新开始后可再次挑战。"
	elif run_state.has_pending_reward():
		status_label.text = "战斗胜利：选择一个奖励后继续前进。"
	elif run_state.has_pending_node_choice():
		var choice_node: Dictionary = run_state.nodes[run_state.pending_choice_node_index]
		status_label.text = "%s：选择一项处理方式后继续前进。\n星砂：%d" % [choice_node.get("title", "路线节点"), run_state.coins]
	else:
		var current := run_state.get_current_node()
		var save_prefix := "已恢复上次 Run\n" if loaded_from_save else ""
		status_label.text = "%s当前节点：%s\n%s\n星砂：%d" % [save_prefix, current.get("title", "无"), current.get("description", ""), run_state.coins]

	if route_guide_label != null:
		route_guide_label.visible = route_hints_enabled
		route_guide_label.text = _route_guide_text() if route_hints_enabled else ""

	_refresh_reward_panel()


func _persist_run_state() -> void:
	var data := run_state.to_dict()
	get_tree().root.set_meta(RUN_STATE_META, data)
	RunSaveScript.save_state(run_state)


func _refresh_reward_panel() -> void:
	if reward_label == null:
		return

	var reward_titles := run_state.get_reward_titles()
	_refresh_build_summary()

	if run_state.has_pending_reward():
		reward_label.text = "战利品三选一\n已获奖励：%s" % ["无" if reward_titles.is_empty() else "、".join(reward_titles)]

		for index in range(reward_buttons.size()):
			var button: Button = reward_buttons[index]
			var has_option := index < run_state.pending_rewards.size()
			button.visible = has_option
			button.disabled = not has_option

			if has_option:
				var reward: Dictionary = run_state.pending_rewards[index]
				button.text = "%s\n%s\n%s" % [
					_format_reward_title(reward),
					reward_generator.get_reward_effect_summary(reward),
					reward.get("description", ""),
				]
				button.tooltip_text = _format_reward_tooltip(reward)

		return

	if run_state.has_pending_node_choice():
		var choice_node: Dictionary = run_state.nodes[run_state.pending_choice_node_index]
		reward_label.text = "%s\n星砂：%d  ·  已获奖励：%s" % [
			choice_node.get("title", "路线选择"),
			run_state.coins,
			"无" if reward_titles.is_empty() else "、".join(reward_titles),
		]

		for index in range(reward_buttons.size()):
			var button: Button = reward_buttons[index]
			var has_option := index < run_state.pending_node_choices.size()
			button.visible = has_option
			button.disabled = not has_option

			if has_option:
				var choice: Dictionary = run_state.pending_node_choices[index]
				var cost: int = choice.get("cost", 0)
				var cost_text := "" if cost <= 0 else "（花费 %d 星砂）" % cost
				var effect_text := reward_generator.get_reward_effect_summary(choice) if _is_reward_like_choice(choice) else _choice_effect_summary(choice)
				button.text = "%s%s\n%s\n%s" % [_format_choice_title(choice), cost_text, effect_text, choice.get("description", "")]
				button.tooltip_text = _format_reward_tooltip(choice) if _is_reward_like_choice(choice) else choice.get("description", "")
				button.disabled = not run_state.can_claim_node_choice(choice.get("id", ""))

		return

	var claimed_text := "" if last_claimed_reward_summary.is_empty() else "\n刚获得：%s" % last_claimed_reward_summary
	reward_label.text = "当前构筑%s\n星砂：%d\n已获奖励：%s" % [
		claimed_text,
		run_state.coins,
		"无" if reward_titles.is_empty() else "、".join(reward_titles),
	]

	for button in reward_buttons:
		button.visible = false
		button.tooltip_text = ""


func _mark_claimed_reward_feedback(reward: Dictionary) -> void:
	last_claimed_reward_summary = "%s · %s" % [
		reward.get("title", "未知奖励"),
		reward_generator.get_reward_effect_summary(reward),
	]
	_pulse_reward_panel()


func _pulse_reward_panel() -> void:
	if reward_label == null:
		return

	if reward_panel_tween != null:
		reward_panel_tween.kill()

	reward_label.modulate = Color(1, 1, 1, 0.66)
	reward_label.scale = Vector2(0.99, 0.99)
	reward_panel_tween = create_tween()
	reward_panel_tween.tween_property(reward_label, "modulate", Color(1, 1, 1, 1), 0.18)
	reward_panel_tween.parallel().tween_property(reward_label, "scale", Vector2(1.015, 1.015), 0.18)
	reward_panel_tween.tween_property(reward_label, "scale", Vector2.ONE, 0.12)


func _pulse_node_button_if_changed(index: int, node: Dictionary, button: Button) -> void:
	var status: String = node.get("status", RunStateScript.STATUS_LOCKED)
	var state_key := "%s:%s" % [status, str(node.get("actual_turn_count", 0))]
	var previous_key: String = last_rendered_node_statuses.get(index, "")
	last_rendered_node_statuses[index] = state_key

	if previous_key == state_key:
		return

	if status != RunStateScript.STATUS_AVAILABLE and status != RunStateScript.STATUS_COMPLETED and status != RunStateScript.STATUS_FAILED:
		return

	_pulse_node_button(index, button, status)


func _pulse_node_button(index: int, button: Button, status: String) -> void:
	if node_button_tweens.has(index):
		var previous_tween: Tween = node_button_tweens[index]

		if previous_tween != null:
			previous_tween.kill()

	last_pulsed_node_index = index
	last_pulsed_node_status = status
	button.modulate = Color(1, 1, 1, 0.86)
	button.scale = Vector2.ONE
	var tween := create_tween()
	node_button_tweens[index] = tween
	tween.tween_property(button, "modulate", Color(1, 1, 1, 1), ROUTE_NODE_PULSE_IN_SECONDS)
	tween.parallel().tween_property(button, "scale", ROUTE_NODE_PULSE_SCALE, ROUTE_NODE_PULSE_IN_SECONDS)
	tween.tween_property(button, "scale", Vector2.ONE, ROUTE_NODE_PULSE_OUT_SECONDS)


func _refresh_build_summary() -> void:
	if build_summary_label == null:
		return

	var build_lines := reward_generator.get_build_summary_lines(run_state)
	var pacing_lines := reward_generator.get_run_pacing_lines(run_state)
	var tuning_lines := reward_generator.get_run_tuning_lines(run_state)
	var boss_prep_lines := reward_generator.get_boss_prep_lines(run_state)
	var playtest_snapshot_lines := playtest_simulator.get_live_playtest_snapshot_lines(run_state)
	build_summary_label.text = "构筑效果：%s\nRun 节奏：%s\n%s\n%s\n调参建议：%s\n基准试玩：%s\n实测对照：%s\n样本矩阵：%s\n矩阵落点：%s\n试玩检查：%s\n调参候选：%s" % [
		" / ".join(build_lines),
		" / ".join(pacing_lines),
		" / ".join(boss_prep_lines),
		" / ".join(playtest_snapshot_lines),
		" / ".join(tuning_lines),
		_baseline_playtest_summary_text(),
		_playtest_comparison_text(),
		_sample_matrix_text(),
		_sample_matrix_action_text(),
		_live_playtest_checklist_text(),
		_single_axis_tuning_text(),
	]


func _baseline_playtest_summary_text() -> String:
	var report := playtest_simulator.run_baseline()
	var pacing: Dictionary = report.get("pacing", {})
	var recorded_battles: int = pacing.get("recorded_battle_nodes", 0)
	var on_target_battles: int = pacing.get("on_target_count", 0)
	var status_text := "可通关" if report.get("completed", false) and not report.get("safety_exhausted", false) else "需复查"

	return "%s，%d/%d 场目标内，总 %d 手，星砂 %d，奖励 %d" % [
		status_text,
		on_target_battles,
		recorded_battles,
		pacing.get("actual_turn_total", 0),
		report.get("coins", 0),
		report.get("reward_count", 0),
	]


func _playtest_comparison_text() -> String:
	var comparison := playtest_simulator.compare_run_to_baseline(run_state)
	return " / ".join(comparison.get("lines", []))


func _sample_matrix_text() -> String:
	var matrix := playtest_simulator.run_sample_matrix()
	return " / ".join(matrix.get("summary_lines", []) + matrix.get("focus_lines", []))


func _sample_matrix_action_text() -> String:
	var matrix := playtest_simulator.run_sample_matrix()
	return " / ".join(matrix.get("action_lines", []))


func _live_playtest_checklist_text() -> String:
	return " / ".join(playtest_simulator.get_live_playtest_checklist(run_state))


func _single_axis_tuning_text() -> String:
	return " / ".join(playtest_simulator.get_single_axis_tuning_candidates(run_state))


func _route_guide_text() -> String:
	if run_state.run_completed:
		return "入门提示：本轮已通关，可重新开始 Run 验证不同构筑路线。"

	if run_state.run_failed:
		return "入门提示：失败后直接重新开始 Run，优先尝试更早拿能量或灵脉奖励。"

	if run_state.has_pending_reward():
		return "入门提示：任选一个战利品继续前进；能量、灵脉和返能奖励都会影响后续战斗。"

	if run_state.has_pending_node_choice():
		var choice_node: Dictionary = run_state.nodes[run_state.pending_choice_node_index]
		var node_type: String = choice_node.get("type", "")

		if node_type == RunStateScript.NODE_SHOP:
			return "入门提示：商店先看星砂，再按普通/稀有/史诗价格挑一个能补强当前构筑的棋印。"

		if node_type == RunStateScript.NODE_EVENT:
			return "入门提示：事件可拿星砂或奖励；星砂紧张时优先为商店做准备。"

		if node_type == RunStateScript.NODE_REST:
			return "入门提示：休息点适合补稳定收益，进入 Boss 前优先选择能立刻生效的强化。"

		return "入门提示：路线选择会阻塞前进，处理后才会解锁下一站。"

	var current := run_state.get_current_node()
	var node_type: String = current.get("type", "")

	if current.get("index", -1) == 1:
		return "入门提示：先进入试锋之局，完成首场战斗后会出现战利品三选一。"

	if node_type == RunStateScript.NODE_BATTLE:
		return "入门提示：普通战斗后领取奖励，再观察路线侧栏的目标手数和构筑建议。"

	if node_type == RunStateScript.NODE_BOSS:
		return "入门提示：Boss 战前确认奖励数量、星砂和目标手数，岩王会持续压缩棋盘。"

	return "入门提示：选择当前可进入节点推进路线，非战斗节点会提供一次路线选择。"


func _refresh_settlement_feedback() -> void:
	var feedback := "暂无" if run_state.last_feedback.is_empty() else run_state.last_feedback
	var kind_label := _feedback_kind_label(run_state.last_feedback_kind)
	var rendered := "%s：%s" % [kind_label, feedback]
	settlement_label.text = rendered
	settlement_label.add_theme_stylebox_override("normal", _settlement_style_for_kind(run_state.last_feedback_kind))
	settlement_label.add_theme_color_override("font_color", _settlement_text_color_for_kind(run_state.last_feedback_kind))

	if rendered != last_rendered_feedback:
		last_rendered_feedback = rendered
		_pulse_settlement_feedback()
		_play_feedback_tone(run_state.last_feedback_kind)


func _pulse_settlement_feedback() -> void:
	if settlement_label == null:
		return

	if settlement_tween != null:
		settlement_tween.kill()

	settlement_label.modulate = Color(1, 1, 1, 0.62)
	settlement_tween = create_tween()
	settlement_tween.tween_property(settlement_label, "modulate", Color(1, 1, 1, 1), 0.22)


func _feedback_kind_label(kind: String) -> String:
	match kind:
		"run_start":
			return "新局"
		"victory":
			return "战斗胜利"
		"defeat":
			return "战斗失利"
		"complete":
			return "通关"
		"reward_claimed":
			return "奖励领取"
		"choice_pending":
			return "路线选择"
		"choice_claimed":
			return "节点结算"
		"progress":
			return "推进"
		_:
			return "最近结算"


func _settlement_style_for_kind(kind: String) -> StyleBoxFlat:
	match kind:
		"victory", "complete", "reward_claimed":
			return _make_panel_style(Color("#283b32"), Color("#d8b64d"))
		"defeat":
			return _make_panel_style(Color("#432d31"), Color("#d87568"))
		"choice_pending", "choice_claimed":
			return _make_panel_style(Color("#303246"), Color("#8da5d8"))
		_:
			return panel_style


func _settlement_text_color_for_kind(kind: String) -> Color:
	match kind:
		"defeat":
			return Color("#ffd0c8")
		"choice_pending", "choice_claimed":
			return Color("#dbe6ff")
		_:
			return Color("#f1dfb7")


func _play_feedback_tone(kind: String) -> void:
	if sound_feedback_enabled and tone_player != null:
		tone_player.play_kind(kind)


func _apply_node_button_style(button: Button, node: Dictionary) -> void:
	var normal_style := button_style
	var hover_style := button_hover_style

	match node.get("type", ""):
		RunStateScript.NODE_EVENT:
			normal_style = event_button_style
			hover_style = event_button_hover_style
		RunStateScript.NODE_SHOP:
			normal_style = shop_button_style
			hover_style = shop_button_hover_style
		RunStateScript.NODE_REST:
			normal_style = rest_button_style
			hover_style = rest_button_hover_style
		RunStateScript.NODE_BOSS:
			normal_style = boss_button_style
			hover_style = boss_button_hover_style

	if node.get("status", "") == RunStateScript.STATUS_COMPLETED:
		normal_style = completed_button_style
		hover_style = completed_button_style

	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", hover_style)


func _type_mark(node_type: String) -> String:
	match node_type:
		RunStateScript.NODE_START:
			return "起"
		RunStateScript.NODE_EVENT:
			return "事"
		RunStateScript.NODE_SHOP:
			return "店"
		RunStateScript.NODE_REST:
			return "息"
		RunStateScript.NODE_BOSS:
			return "王"
		_:
			return "战"


func _status_text(status: String) -> String:
	match status:
		RunStateScript.STATUS_COMPLETED:
			return "已完成"
		RunStateScript.STATUS_AVAILABLE:
			return "可进入"
		RunStateScript.STATUS_FAILED:
			return "失败"
		_:
			return "未解锁"


func _enemy_text(node: Dictionary) -> String:
	var profile_id: String = node.get("enemy_profile_id", "")

	if profile_id.is_empty():
		return ""

	return " · 对阵 %s" % EnemyAI.get_profile_name_for_id(profile_id)


func _node_tooltip(node: Dictionary) -> String:
	var parts := [
		node.get("description", ""),
		"类型：%s" % _node_type_label(node.get("type", "")),
		"状态：%s" % _status_text(node.get("status", RunStateScript.STATUS_LOCKED)),
	]
	var enemy := _enemy_text(node)

	if not enemy.is_empty():
		parts.append(enemy.trim_prefix(" · "))

	var target_min: int = node.get("target_turn_min", 0)
	var target_max: int = node.get("target_turn_max", 0)

	if target_min > 0 and target_max > 0:
		parts.append("目标节奏：%d-%d 手" % [target_min, target_max])

	var actual_turn_count: int = node.get("actual_turn_count", 0)

	if actual_turn_count > 0:
		parts.append("实测节奏：%d 手，%s" % [actual_turn_count, _pacing_result_label(node.get("actual_pacing_result", ""))])

	return "\n".join(parts)


func _node_pacing_text(node: Dictionary) -> String:
	var actual_turn_count: int = node.get("actual_turn_count", 0)

	if actual_turn_count <= 0:
		return ""

	return " · 实测 %d 手（%s）" % [actual_turn_count, _pacing_result_label(node.get("actual_pacing_result", ""))]


func _pacing_result_label(result: String) -> String:
	match result:
		"under":
			return "偏快"
		"over":
			return "偏慢"
		"target":
			return "目标内"
		_:
			return "待判断"


func _node_type_label(node_type: String) -> String:
	match node_type:
		RunStateScript.NODE_START:
			return "起点"
		RunStateScript.NODE_EVENT:
			return "事件"
		RunStateScript.NODE_SHOP:
			return "商店"
		RunStateScript.NODE_REST:
			return "休息"
		RunStateScript.NODE_BOSS:
			return "Boss"
		_:
			return "战斗"


func _format_choice_title(choice: Dictionary) -> String:
	if _is_reward_like_choice(choice):
		return _format_reward_title(choice)

	return choice.get("title", "选择")


func _format_reward_title(reward: Dictionary) -> String:
	return "[%s] %s" % [reward_generator.get_rarity_label(reward), reward.get("title", "奖励")]


func _format_reward_tooltip(reward: Dictionary) -> String:
	var notes := [
		reward.get("description", ""),
		"效果：%s" % reward_generator.get_reward_effect_summary(reward),
	]
	var limit_text := reward_generator.get_reward_limit_summary(reward)

	if not limit_text.is_empty():
		notes.append(limit_text)

	return "\n".join(notes)


func _is_reward_like_choice(choice: Dictionary) -> bool:
	return choice.get("choice_type", "") == RewardGeneratorScript.CHOICE_REWARD or not choice.get("effect", "").is_empty()


func _choice_effect_summary(choice: Dictionary) -> String:
	match choice.get("choice_type", ""):
		RewardGeneratorScript.CHOICE_COINS:
			return "星砂 +%d" % choice.get("amount", 0)
		RewardGeneratorScript.CHOICE_SKIP:
			return "保留当前构筑"
		_:
			return "路线选择"
