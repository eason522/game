extends SceneTree

const MainMenuScene := preload("res://scenes/ui/MainMenu.tscn")
const RunSaveScript := preload("res://scripts/roguelike/RunSave.gd")
const RunStateScript := preload("res://scripts/roguelike/RunState.gd")
const MapGeneratorScript := preload("res://scripts/roguelike/MapGenerator.gd")
const RUN_STATE_META := "tymj_run_state"

var failures: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	RunSaveScript.delete_save()

	if root.has_meta(RUN_STATE_META):
		root.remove_meta(RUN_STATE_META)

	var scene = MainMenuScene.instantiate()
	root.add_child(scene)
	await process_frame

	if ProjectSettings.get_setting("application/run/main_scene", "") != "res://scenes/ui/MainMenu.tscn":
		failures.append("main menu: expected project main scene to point at the demo menu")

	if scene.title_label == null or scene.title_label.text != "天元迷局":
		failures.append("main menu: expected title label")

	if scene.subtitle_label == null or not scene.subtitle_label.text.contains("Demo"):
		failures.append("main menu: expected demo subtitle")

	if scene.start_button == null or scene.start_button.text != "新的 Run":
		failures.append("main menu: expected new run button")

	if scene.continue_button == null or not scene.continue_button.disabled:
		failures.append("main menu: expected continue button to be disabled without a save")
	elif scene.continue_button.text != "继续 Run":
		failures.append("main menu: expected disabled continue button to use the default label")

	if scene.battle_button == null or scene.battle_button.text != "单局战斗":
		failures.append("main menu: expected single-battle button")

	if scene.status_label == null or not scene.status_label.text.contains("暂无存档"):
		failures.append("main menu: expected no-save status text")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单进度") or not scene.summary_label.text.contains("暂无 Run 数据"):
		failures.append("main menu: expected no-save progress overview")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单速览") or not scene.summary_label.text.contains("等待首战记录"):
		failures.append("main menu: expected no-save playtest overview")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单核对") or not scene.summary_label.text.contains("继续按钮禁用"):
		failures.append("main menu: expected no-save launch check line")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单基准") or not scene.summary_label.text.contains("4/4 场目标内"):
		failures.append("main menu: expected no-save baseline playtest line")

	var run_state := RunStateScript.new(MapGeneratorScript.new().generate_linear_route())
	RunSaveScript.save_state(run_state)
	scene._refresh_continue_state()

	if scene.continue_button.disabled:
		failures.append("main menu: expected continue button to enable when save exists")
	elif not scene.continue_button.text.contains("进入试锋之局"):
		failures.append("main menu: expected continue button to name the current battle")

	if scene.status_label == null or not scene.status_label.text.contains("可继续"):
		failures.append("main menu: expected continue status text")

	if scene.status_label == null or not scene.status_label.text.contains("进入试锋之局"):
		failures.append("main menu: expected continue status to show editor next action")

	if scene.summary_label == null or not scene.summary_label.text.contains("编辑器收口包") or not scene.summary_label.text.contains("等待首战记录"):
		failures.append("main menu: expected save-aware editor closeout overview")

	if scene.summary_label == null or not scene.summary_label.text.contains("当前 试锋之局") or not scene.summary_label.text.contains("实测 0/4 场"):
		failures.append("main menu: expected saved-run progress overview")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单核对") or not scene.summary_label.text.contains("进入试锋之局"):
		failures.append("main menu: expected saved-run launch check line")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单基准") or not scene.summary_label.text.contains("总"):
		failures.append("main menu: expected saved-run baseline playtest line")

	run_state.resolve_current_node(true, [{
		"id": "smoke_reward",
		"title": "测试奖励",
		"effect": "starting_energy",
		"amount": 1,
		"rarity": "common",
		"max_stack": 2,
	}], 12)
	RunSaveScript.save_state(run_state)
	scene._refresh_continue_state()

	if scene.continue_button == null or not scene.continue_button.text.contains("领取战利品"):
		failures.append("main menu: expected continue button to point at pending rewards")

	if scene.summary_label == null or not scene.summary_label.text.contains("实测 1/4 场"):
		failures.append("main menu: expected progress overview to reflect recorded battle count")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单核对") or not scene.summary_label.text.contains("领取战利品"):
		failures.append("main menu: expected launch check to reflect pending rewards")

	run_state.pending_rewards.clear()
	run_state.pending_reward_node_index = -1
	run_state.run_completed = true
	RunSaveScript.save_state(run_state)
	scene._refresh_continue_state()

	if scene.continue_button == null or not scene.continue_button.text.contains("记录 Boss 体感"):
		failures.append("main menu: expected completed run to point at boss feel recording")

	run_state.record_boss_opening_feel(RunStateScript.BOSS_OPENING_FEEL_STABLE)
	RunSaveScript.save_state(run_state)
	scene._refresh_continue_state()

	if scene.continue_button == null or not scene.continue_button.text.contains("查看验收结果"):
		failures.append("main menu: expected accepted run to point at acceptance review")

	scene.queue_free()
	RunSaveScript.delete_save()

	if root.has_meta(RUN_STATE_META):
		root.remove_meta(RUN_STATE_META)

	await process_frame

	if failures.is_empty():
		print("Main menu smoke tests passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)

	quit(1)
