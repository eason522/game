extends SceneTree

const MapGeneratorScript := preload("res://scripts/roguelike/MapGenerator.gd")
const RunStateScript := preload("res://scripts/roguelike/RunState.gd")
const RunMapScene := preload("res://scenes/roguelike/RunMapScene.tscn")
const RUN_STATE_META := "tymj_run_state"

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

	if scene.build_summary_label == null or not scene.build_summary_label.text.contains("4/4 场目标内"):
		failures.append("run map feedback: expected baseline playtest to summarize on-target battles")

	if scene.build_summary_label == null or not scene.build_summary_label.text.contains("实测对照：等待首场实机记录"):
		failures.append("run map feedback: expected playtest comparison to wait for actual records")

	if scene.build_summary_label == null or not scene.build_summary_label.text.contains("剩余目标 60-88 手"):
		failures.append("run map feedback: expected run pacing to summarize remaining turn target")

	if scene.node_buttons.size() <= 1 or not scene.node_buttons[1].tooltip_text.contains("目标节奏：10-16 手"):
		failures.append("run map feedback: expected battle tooltip to show target turn pacing")

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

	scene.run_state.last_feedback = "获得奖励：灵息深蓄。下一站：残谱石室。"
	scene.run_state.last_feedback_kind = "reward_claimed"
	scene._refresh()

	await process_frame

	if scene.settlement_label == null or not scene.settlement_label.text.contains("奖励领取"):
		failures.append("run map feedback: expected typed settlement label")

	if scene.tone_player == null or scene.tone_player.last_tone_kind != "reward_claimed":
		failures.append("run map feedback: expected reward feedback to trigger a reward tone")

	scene.queue_free()
	root.remove_meta(RUN_STATE_META)
	await process_frame

	if failures.is_empty():
		print("Run map feedback smoke tests passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)

	quit(1)
