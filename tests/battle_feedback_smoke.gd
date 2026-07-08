extends SceneTree

const BattleScene := preload("res://scenes/game/BattleScene.tscn")
const BATTLE_NODE_INDEX_META := "tymj_battle_node_index"
const BATTLE_RESULT_META := "tymj_battle_result"
const BATTLE_MOVE_COUNT_META := "tymj_battle_move_count"

var failures: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.set_meta(BATTLE_NODE_INDEX_META, 1)
	var scene := BattleScene.instantiate()
	root.add_child(scene)

	await process_frame

	if scene.feedback_label == null:
		failures.append("battle feedback: expected feedback label to exist")
	else:
		var initial_text: String = scene.feedback_label.text

		if not initial_text.contains("战斗开始"):
			failures.append("battle feedback: expected initial feedback text")

	if scene.result_banner_label == null:
		failures.append("battle feedback: expected result banner label to exist")
	elif scene.result_banner_label.visible:
		failures.append("battle feedback: result banner should start hidden")

	if scene.tone_player == null:
		failures.append("battle feedback: expected tone player to exist")
	elif scene.tone_player.last_tone_kind != "turn_player":
		failures.append("battle feedback: expected initial player turn to trigger a turn tone")
	elif scene.tone_player.last_tone_duration > 0.03 or scene.tone_player.last_tone_volume > 0.06:
		failures.append("battle feedback: expected tuned player turn tone to stay short and quiet")

	if scene.turn_rhythm_label == null:
		failures.append("battle feedback: expected turn rhythm label to exist")
	elif not scene.turn_rhythm_label.text.contains("己方行动"):
		failures.append("battle feedback: expected initial rhythm label to show player action")

	if scene.enemy_think_delay_seconds < 0.4:
		failures.append("battle feedback: expected enemy think delay to leave a readable beat")

	if scene.turn_rhythm_pulse_seconds < 0.24 or scene.turn_rhythm_pulse_seconds > 0.3:
		failures.append("battle feedback: expected tuned turn rhythm pulse duration")

	if scene.feedback_flash_seconds < 0.6 or scene.feedback_flash_seconds > 0.65:
		failures.append("battle feedback: expected cell flash timing to be tuned for readability")

	scene._show_feedback("测试反馈：术法作用于 A1。", [Vector2i(0, 0)], "skill")
	await process_frame

	if scene.feedback_label == null or not scene.feedback_label.text.contains("测试反馈"):
		failures.append("battle feedback: expected feedback log to update")

	if not scene.feedback_flashes.has(Vector2i(0, 0)):
		failures.append("battle feedback: expected target cell to be flashed")

	if scene.tone_player == null or scene.tone_player.last_tone_kind != "skill":
		failures.append("battle feedback: expected skill feedback to trigger a skill tone")

	scene._begin_turn(BoardState.ENEMY)
	await process_frame

	if scene.turn_rhythm_label == null or not scene.turn_rhythm_label.text.contains("敌方思考"):
		failures.append("battle feedback: expected enemy turn rhythm label")

	if scene.tone_player == null or scene.tone_player.last_tone_kind != "turn_enemy":
		failures.append("battle feedback: expected enemy turn to trigger a turn tone")
	elif scene.tone_player.last_tone_duration > 0.035:
		failures.append("battle feedback: expected enemy turn tone to stay brief")

	scene._show_result_banner(true, "A1-E1")
	await process_frame

	if scene.result_banner_label == null or not scene.result_banner_label.visible:
		failures.append("battle feedback: expected result banner to become visible")
	elif not scene.result_banner_label.text.contains("胜利") or not scene.result_banner_label.text.contains("A1-E1"):
		failures.append("battle feedback: expected result banner to describe the outcome")

	if scene.tone_player == null or scene.tone_player.last_tone_kind != "victory":
		failures.append("battle feedback: expected victory banner to trigger a victory tone")
	elif scene.tone_player.last_tone_count != 3:
		failures.append("battle feedback: expected victory tone to use three notes")

	if scene.result_banner_animation_seconds < 0.44 or scene.result_banner_animation_seconds > 0.48:
		failures.append("battle feedback: expected result banner animation timing to be tuned")

	scene.move_count = 17
	scene._record_battle_result(true)

	if root.get_meta(BATTLE_RESULT_META, "") != "victory":
		failures.append("battle feedback: expected run battle result metadata")

	if root.get_meta(BATTLE_MOVE_COUNT_META, 0) != 17:
		failures.append("battle feedback: expected run battle move-count metadata")

	scene.queue_free()
	root.remove_meta(BATTLE_NODE_INDEX_META)
	root.remove_meta(BATTLE_RESULT_META)
	root.remove_meta(BATTLE_MOVE_COUNT_META)
	await process_frame

	if failures.is_empty():
		print("Battle feedback smoke tests passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)

	quit(1)
