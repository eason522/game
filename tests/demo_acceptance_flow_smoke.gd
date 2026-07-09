extends SceneTree

const MainMenuScene := preload("res://scenes/ui/MainMenu.tscn")
const RunMapScene := preload("res://scenes/roguelike/RunMapScene.tscn")
const RunSaveScript := preload("res://scripts/roguelike/RunSave.gd")
const RunPlaytestSimulatorScript := preload("res://scripts/roguelike/RunPlaytestSimulator.gd")
const RunStateScript := preload("res://scripts/roguelike/RunState.gd")
const RUN_STATE_META := "tymj_run_state"

var failures: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	RunSaveScript.delete_save()

	if root.has_meta(RUN_STATE_META):
		root.remove_meta(RUN_STATE_META)

	var simulator := RunPlaytestSimulatorScript.new()
	var sample_report: Dictionary = simulator.build_demo_acceptance_sample()
	var accepted_state = sample_report.get("state")

	if accepted_state == null:
		failures.append("demo acceptance flow: expected simulator to build an accepted state")
	else:
		var packet_lines: Array = simulator.get_demo_acceptance_packet_lines(accepted_state)

		if not accepted_state.run_completed:
			failures.append("demo acceptance flow: expected accepted sample to be completed")

		if accepted_state.boss_opening_feel != RunStateScript.BOSS_OPENING_FEEL_STABLE:
			failures.append("demo acceptance flow: expected accepted sample to record stable boss feel")

		if " / ".join(packet_lines).find("可交付 Demo 验收体验包") == -1:
			failures.append("demo acceptance flow: expected simulator packet to mark the sample deliverable")

	if accepted_state != null:
		RunSaveScript.save_state(accepted_state)

	var menu = MainMenuScene.instantiate()
	root.add_child(menu)
	await process_frame

	if menu.continue_button == null or not menu.continue_button.text.contains("查看验收结果"):
		failures.append("demo acceptance flow: expected main menu to route accepted save to review")

	if menu.summary_label == null or not menu.summary_label.text.contains("主菜单演练") or not menu.summary_label.text.contains("稳定样本 4/4"):
		failures.append("demo acceptance flow: expected main menu to show the rehearsal reference")

	if menu.summary_label == null or not menu.summary_label.text.contains("主菜单体验包") or not menu.summary_label.text.contains("可交付 Demo 验收体验包"):
		failures.append("demo acceptance flow: expected main menu to show accepted demo packet")

	menu.queue_free()
	await process_frame

	var run_map = RunMapScene.instantiate()
	root.add_child(run_map)
	await process_frame

	if not run_map.loaded_from_save:
		failures.append("demo acceptance flow: expected run map to restore the accepted save")

	if not run_map.run_state.run_completed:
		failures.append("demo acceptance flow: expected restored run map state to remain completed")

	if run_map.reward_label == null or not run_map.reward_label.text.contains("当前记录：静息调气后更稳"):
		failures.append("demo acceptance flow: expected run map boss feel panel to preserve stable feel")

	if run_map.build_summary_label == null or not run_map.build_summary_label.text.contains("Demo 演练") or not run_map.build_summary_label.text.contains("可交付 Demo 验收体验包"):
		failures.append("demo acceptance flow: expected run map to show rehearsal and accepted packet")

	if run_map.build_summary_label == null or not run_map.build_summary_label.text.contains("保持当前数值并归档"):
		failures.append("demo acceptance flow: expected accepted packet to preserve archive next action")

	run_map.queue_free()
	RunSaveScript.delete_save()

	if root.has_meta(RUN_STATE_META):
		root.remove_meta(RUN_STATE_META)

	await process_frame

	if failures.is_empty():
		print("Demo acceptance flow smoke tests passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)

	quit(1)
