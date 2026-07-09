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

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单演练") or not scene.summary_label.text.contains("稳定样本 4/4 场目标内"):
		failures.append("main menu: expected no-save demo acceptance rehearsal line")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单检查") or not scene.summary_label.text.contains("先完成首场战斗"):
		failures.append("main menu: expected no-save playtest checklist line")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单 Boss 关注") or not scene.summary_label.text.contains("先推进到休息点"):
		failures.append("main menu: expected no-save boss focus line")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单 Boss 快照") or not scene.summary_label.text.contains("尚未记录前 5 手快照"):
		failures.append("main menu: expected no-save boss snapshot line")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单证据") or not scene.summary_label.text.contains("暂无 Run 数据"):
		failures.append("main menu: expected no-save evidence line")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单验收") or not scene.summary_label.text.contains("暂无 Run 数据"):
		failures.append("main menu: expected no-save acceptance gate line")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单纪要") or not scene.summary_label.text.contains("未开始"):
		failures.append("main menu: expected no-save acceptance note line")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单归档") or not scene.summary_label.text.contains("暂无 Run 数据"):
		failures.append("main menu: expected no-save archive and excerpt line")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单收口") or not scene.summary_label.text.contains("暂无 Run 数据"):
		failures.append("main menu: expected no-save closeout line")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单体验包") or not scene.summary_label.text.contains("未开始；样本 0/4"):
		failures.append("main menu: expected no-save demo acceptance packet line")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单复核") or not scene.summary_label.text.contains("暂无 Run 数据"):
		failures.append("main menu: expected no-save archive review line")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单归档校验") or not scene.summary_label.text.contains("暂无归档签名"):
		failures.append("main menu: expected no-save archive audit line")

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

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单演练") or not scene.summary_label.text.contains("可交付 Demo 验收体验包"):
		failures.append("main menu: expected saved-run demo acceptance rehearsal reference")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单检查") or not scene.summary_label.text.contains("先完成首场战斗"):
		failures.append("main menu: expected saved-run playtest checklist line")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单 Boss 关注") or not scene.summary_label.text.contains("尚未验证静息调气"):
		failures.append("main menu: expected saved-run boss focus line")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单 Boss 快照") or not scene.summary_label.text.contains("尚未记录前 5 手快照"):
		failures.append("main menu: expected saved-run boss snapshot line to wait for boss observation")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单证据") or not scene.summary_label.text.contains("样本 0/4"):
		failures.append("main menu: expected saved-run evidence line to request the first battle")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单验收") or not scene.summary_label.text.contains("实机样本未齐 0/4"):
		failures.append("main menu: expected saved-run acceptance gate line to keep the sample open")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单纪要") or not scene.summary_label.text.contains("未开始"):
		failures.append("main menu: expected saved-run acceptance note line to request the first battle")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单归档") or not scene.summary_label.text.contains("等待首战记录"):
		failures.append("main menu: expected saved-run archive line to wait for the first battle")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单收口") or not scene.summary_label.text.contains("样本未齐 0/4"):
		failures.append("main menu: expected saved-run closeout line to keep the sample open")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单体验包") or not scene.summary_label.text.contains("继续试玩；样本 0/4"):
		failures.append("main menu: expected saved-run demo acceptance packet to keep the sample open")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单复核") or not scene.summary_label.text.contains("未闭合"):
		failures.append("main menu: expected saved-run archive review to stay open")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单归档校验") or not scene.summary_label.text.contains("暂不生成归档签名"):
		failures.append("main menu: expected saved-run archive audit to wait for closed evidence")

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

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单检查") or not scene.summary_label.text.contains("继续补齐完整 Run 实测 1/4 场"):
		failures.append("main menu: expected checklist to reflect partial live run progress")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单证据") or not scene.summary_label.text.contains("样本 1/4"):
		failures.append("main menu: expected evidence line to reflect partial live run progress")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单验收") or not scene.summary_label.text.contains("实机样本未齐 1/4"):
		failures.append("main menu: expected acceptance gate line to reflect partial live run progress")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单纪要") or not scene.summary_label.text.contains("样本 1/4"):
		failures.append("main menu: expected acceptance note line to keep partial saved runs open")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单归档") or not scene.summary_label.text.contains("样本 1/4 未齐"):
		failures.append("main menu: expected archive line to keep partial saved runs open")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单收口") or not scene.summary_label.text.contains("继续完整 Run"):
		failures.append("main menu: expected closeout line to point partial saved runs back into the full run")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单体验包") or not scene.summary_label.text.contains("继续试玩；样本 1/4"):
		failures.append("main menu: expected partial saved-run demo acceptance packet to request a full run")

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

	var high_pressure_state = scene.playtest_simulator.run_baseline().get("state")
	high_pressure_state.record_boss_opening_observation({
		"enemy": "岩王",
		"total_moves": 5,
		"snapshots": [
			{
				"move_count": 1,
				"actor": "己方",
				"position": "F6",
				"player_energy": 2,
				"rock_count": 8,
				"playable_count": 112,
				"focus": "开局岩阵",
			},
			{
				"move_count": 3,
				"actor": "己方",
				"position": "F7",
				"player_energy": 2,
				"rock_count": 9,
				"playable_count": 106,
				"focus": "能量与岩阵",
			},
			{
				"move_count": 5,
				"actor": "己方",
				"position": "G7",
				"player_energy": 2,
				"rock_count": 9,
				"playable_count": 104,
				"focus": "反制点",
			},
		],
	})
	RunSaveScript.save_state(high_pressure_state)
	scene._refresh_continue_state()

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单 Boss 快照") or not scene.summary_label.text.contains("压力偏高"):
		failures.append("main menu: expected high-pressure boss snapshot result on the menu")

	var accepted_state = scene.playtest_simulator.build_demo_acceptance_sample().get("state")
	RunSaveScript.save_state(accepted_state)
	scene._refresh_continue_state()

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单归档") or not scene.summary_label.text.contains("可归档 Demo 验收"):
		failures.append("main menu: expected accepted run archive result on the menu")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单证据") or not scene.summary_label.text.contains("可归档 Demo 验收证据"):
		failures.append("main menu: expected accepted run evidence result on the menu")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单 Boss 快照") or not scene.summary_label.text.contains("暂稳"):
		failures.append("main menu: expected accepted run boss snapshot result on the menu")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单验收") or not scene.summary_label.text.contains("可作为本轮 Demo 实机验收"):
		failures.append("main menu: expected accepted run acceptance gate result on the menu")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单纪要") or not scene.summary_label.text.contains("Demo 验收通过"):
		failures.append("main menu: expected accepted run acceptance note on the menu")

	if scene.summary_label == null or not scene.summary_label.text.contains("摘录：Demo 验收通过"):
		failures.append("main menu: expected accepted run recap excerpt on the menu")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单收口") or not scene.summary_label.text.contains("保持当前数值"):
		failures.append("main menu: expected accepted run closeout result on the menu")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单体验包") or not scene.summary_label.text.contains("可交付 Demo 验收体验包"):
		failures.append("main menu: expected accepted run demo acceptance packet on the menu")

	if scene.summary_label == null or not scene.summary_label.text.contains("记录：已保存 Demo 验收通过"):
		failures.append("main menu: expected accepted run demo archive record on the menu")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单复核") or not scene.summary_label.text.contains("已保存"):
		failures.append("main menu: expected accepted run archive review on the menu")

	if scene.summary_label == null or not scene.summary_label.text.contains("主菜单归档校验") or not scene.summary_label.text.contains("签名 DEMO-"):
		failures.append("main menu: expected accepted run archive audit signature on the menu")

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
