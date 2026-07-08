extends SceneTree

const MapGeneratorScript := preload("res://scripts/roguelike/MapGenerator.gd")
const RunStateScript := preload("res://scripts/roguelike/RunState.gd")
const RunMapScene := preload("res://scenes/roguelike/RunMapScene.tscn")
const RUN_STATE_META := "tymj_run_state"
const DEMO_SOUND_ENABLED_META := "tymj_demo_sound_enabled"
const DEMO_HINTS_ENABLED_META := "tymj_demo_hints_enabled"

var failures: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var state := RunStateScript.new(MapGeneratorScript.new().generate_linear_route())
	root.set_meta(RUN_STATE_META, state.to_dict())

	var scene := RunMapScene.instantiate()
	root.add_child(scene)

	await process_frame

	if scene.tone_player == null:
		failures.append("run map feedback: expected tone player to exist")
	elif scene.tone_player.last_tone_kind != "run_start":
		failures.append("run map feedback: expected initial run feedback to trigger a run-start tone")

	if scene.build_summary_label == null or not scene.build_summary_label.text.contains("Run 节奏"):
		failures.append("run map feedback: expected build panel to show run pacing")

	if scene.build_summary_label == null or not scene.build_summary_label.text.contains("调参建议"):
		failures.append("run map feedback: expected build panel to show tuning suggestions")

	if scene.build_summary_label == null or not scene.build_summary_label.text.contains("基准试玩"):
		failures.append("run map feedback: expected build panel to show baseline playtest summary")

	if scene.build_summary_label == null or not scene.build_summary_label.text.contains("样本矩阵"):
		failures.append("run map feedback: expected build panel to show sample matrix summary")

	if scene.build_summary_label == null or not scene.build_summary_label.text.contains("矩阵关注"):
		failures.append("run map feedback: expected sample matrix to show a focus line")

	if scene.build_summary_label == null or not scene.build_summary_label.text.contains("矩阵落点"):
		failures.append("run map feedback: expected sample matrix to show actionable tuning lines")

	if scene.build_summary_label == null or not scene.build_summary_label.text.contains("Boss 上限"):
		failures.append("run map feedback: expected matrix action lines to mention boss cap review")

	if scene.build_summary_label == null or not scene.build_summary_label.text.contains("4/4 场目标内"):
		failures.append("run map feedback: expected baseline playtest to summarize on-target battles")

	if scene.build_summary_label == null or not scene.build_summary_label.text.contains("实测对照：等待首场实机记录"):
		failures.append("run map feedback: expected playtest comparison to wait for actual records")

	if scene.build_summary_label == null or not scene.build_summary_label.text.contains("剩余目标 60-88 手"):
		failures.append("run map feedback: expected run pacing to summarize remaining turn target")

	if scene.node_buttons.size() <= 1 or not scene.node_buttons[1].tooltip_text.contains("目标节奏：10-16 手"):
		failures.append("run map feedback: expected battle tooltip to show target turn pacing")

	if scene.route_guide_label == null:
		failures.append("run map feedback: expected route guide label to exist")
	elif not scene.route_guide_label.text.contains("试锋之局"):
		failures.append("run map feedback: expected opening route guide to point at first battle")

	if scene.sound_toggle_button == null or scene.hints_toggle_button == null:
		failures.append("run map feedback: expected demo setting toggles to exist")
	else:
		if not scene.sound_toggle_button.text.contains("开") or not scene.hints_toggle_button.text.contains("开"):
			failures.append("run map feedback: expected demo setting toggles to start enabled")

		scene._on_hints_toggled(false)

		if root.get_meta(DEMO_HINTS_ENABLED_META, true):
			failures.append("run map feedback: expected hint toggle to persist disabled preference")

		if scene.route_guide_label.visible or not scene.route_guide_label.text.is_empty():
			failures.append("run map feedback: expected route guide to hide when disabled")

		scene._on_hints_toggled(true)

		if not scene.route_guide_label.visible or not scene.route_guide_label.text.contains("试锋之局"):
			failures.append("run map feedback: expected route guide to return when re-enabled")

		if scene.tone_player != null:
			var previous_tone: String = scene.tone_player.last_tone_kind
			scene._on_sound_toggled(false)
			scene._play_feedback_tone("progress")

			if scene.tone_player.last_tone_kind != previous_tone:
				failures.append("run map feedback: expected disabled sound toggle to suppress tones")

			if root.get_meta(DEMO_SOUND_ENABLED_META, true):
				failures.append("run map feedback: expected sound toggle to persist disabled preference")

			scene._on_sound_toggled(true)

	if scene.last_pulsed_node_index != 1 or scene.last_pulsed_node_status != RunStateScript.STATUS_AVAILABLE:
		failures.append("run map feedback: expected available route node to receive an entry pulse")

	if scene.route_node_pulse_seconds < 0.29 or scene.route_node_pulse_seconds > 0.31:
		failures.append("run map feedback: expected route node pulse timing to be tuned")

	scene.run_state.nodes[1]["actual_turn_count"] = 14
	scene.run_state.nodes[1]["actual_pacing_result"] = "target"
	scene._refresh()

	await process_frame

	if scene.node_buttons.size() <= 1 or not scene.node_buttons[1].text.contains("实测 14 手"):
		failures.append("run map feedback: expected battle node button to show actual pacing")

	if scene.node_buttons.size() <= 1 or not scene.node_buttons[1].tooltip_text.contains("实测节奏：14 手"):
		failures.append("run map feedback: expected battle tooltip to show actual pacing")

	if scene.build_summary_label == null or not scene.build_summary_label.text.contains("实测 1 场，均值 14 手"):
		failures.append("run map feedback: expected build panel to show actual pacing summary")

	if scene.build_summary_label == null or not scene.build_summary_label.text.contains("实测对照：已测 1/4"):
		failures.append("run map feedback: expected playtest comparison to show recorded battle count")

	if scene.build_summary_label == null or not scene.build_summary_label.text.contains("目标内 1/1"):
		failures.append("run map feedback: expected playtest comparison to show on-target actual count")

	if scene.build_summary_label == null or not scene.build_summary_label.text.contains("最大偏差：试锋之局"):
		failures.append("run map feedback: expected playtest comparison to show largest baseline delta")

	if scene.build_summary_label == null or not scene.build_summary_label.text.contains("校准关注"):
		failures.append("run map feedback: expected playtest comparison to show calibration focus")

	var reward_options: Array = scene.reward_generator.generate_options(scene.run_state, scene.run_state.get_current_node())
	scene.run_state.resolve_current_node(true, reward_options, 14)
	scene._refresh()

	await process_frame

	if scene.route_guide_label == null or not scene.route_guide_label.text.contains("战利品"):
		failures.append("run map feedback: expected pending reward guide to explain reward choice")

	scene._claim_reward_at(0)

	await process_frame

	if scene.settlement_label == null or not scene.settlement_label.text.contains("奖励领取"):
		failures.append("run map feedback: expected typed settlement label")

	if scene.tone_player == null or scene.tone_player.last_tone_kind != "reward_claimed":
		failures.append("run map feedback: expected reward feedback to trigger a reward tone")
	elif scene.tone_player.last_tone_count != 3:
		failures.append("run map feedback: expected reward feedback to use a brighter three-note tone")

	if scene.reward_label == null or not scene.reward_label.text.contains("刚获得"):
		failures.append("run map feedback: expected reward panel to keep the claimed reward visible")

	if scene.last_pulsed_node_status != RunStateScript.STATUS_AVAILABLE or scene.last_pulsed_node_index != 2:
		failures.append("run map feedback: expected next route node to pulse after reward claim")

	scene.run_state.pending_node_choices.clear()
	scene.run_state.pending_choice_node_index = -1
	scene.run_state.current_index = 4
	scene.run_state.nodes[4]["status"] = RunStateScript.STATUS_AVAILABLE
	var shop_choices: Array = scene.reward_generator.generate_node_choices(scene.run_state, scene.run_state.nodes[4])
	scene.run_state.open_node_choices(shop_choices)
	scene._refresh()

	await process_frame

	if scene.route_guide_label == null or not scene.route_guide_label.text.contains("商店") or not scene.route_guide_label.text.contains("星砂"):
		failures.append("run map feedback: expected shop guide to mention shop and starsand")

	scene.queue_free()
	root.remove_meta(RUN_STATE_META)
	root.remove_meta(DEMO_SOUND_ENABLED_META)
	root.remove_meta(DEMO_HINTS_ENABLED_META)
	await process_frame

	if failures.is_empty():
		print("Run map feedback smoke tests passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)

	quit(1)
