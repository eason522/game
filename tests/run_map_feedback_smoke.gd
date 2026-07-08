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

	if scene.build_summary_label == null or not scene.build_summary_label.text.contains("剩余目标 58-84 手"):
		failures.append("run map feedback: expected run pacing to summarize remaining turn target")

	if scene.node_buttons.size() <= 1 or not scene.node_buttons[1].tooltip_text.contains("目标节奏：10-16 手"):
		failures.append("run map feedback: expected battle tooltip to show target turn pacing")

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
