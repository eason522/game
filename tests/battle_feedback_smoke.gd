extends SceneTree

const BattleScene := preload("res://scenes/game/BattleScene.tscn")
const BATTLE_NODE_INDEX_META := "tymj_battle_node_index"
const BATTLE_RESULT_META := "tymj_battle_result"
const BATTLE_MOVE_COUNT_META := "tymj_battle_move_count"
const DEMO_SOUND_ENABLED_META := "tymj_demo_sound_enabled"
const DEMO_HINTS_ENABLED_META := "tymj_demo_hints_enabled"

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

	if scene.board_grid == null:
		failures.append("battle feedback: expected board grid to exist")
	else:
		var initial_board_y: float = scene.board_grid.global_position.y
		var board_bottom: float = scene.board_grid.global_position.y + scene.board_grid.size.y
		var viewport_height: float = scene.get_viewport_rect().size.y

		if board_bottom > viewport_height - 16.0:
			failures.append("battle feedback: expected full board to fit vertically in the default viewport")

		if scene.cells.is_empty() or scene.cells[0].is_empty():
			failures.append("battle feedback: expected board cells to exist")
		else:
			var first_cell: Button = scene.cells[0][0]

			if first_cell.custom_minimum_size.x > 44.0 or first_cell.custom_minimum_size.y > 44.0:
				failures.append("battle feedback: expected compact board cells for default viewport fit")

		scene._set_status("测试长状态：堡垒棋士落子于 E5，意图：防守并延长自己的连线。轮到你了。")
		scene._show_feedback("测试反馈：堡垒棋士落子 E5。", [], "")
		scene._show_feedback("测试反馈：己方落子 F6。", [], "")
		scene._show_feedback("测试反馈：己方触发灵脉：F6 回复 1 点能量。", [], "")
		await process_frame

		var shifted_board_y: float = scene.board_grid.global_position.y
		var shifted_board_bottom: float = scene.board_grid.global_position.y + scene.board_grid.size.y

		if abs(shifted_board_y - initial_board_y) > 0.5:
			failures.append("battle feedback: expected long header feedback to keep board y position stable")

		if shifted_board_bottom > viewport_height - 16.0:
			failures.append("battle feedback: expected long header feedback to keep full board visible")

		if scene.status_label == null or not scene.status_label.clip_text:
			failures.append("battle feedback: expected status label to clip long text instead of resizing")

		if scene.feedback_label == null or not scene.feedback_label.clip_text or scene.feedback_label.max_lines_visible != 3:
			failures.append("battle feedback: expected feedback label to keep a clipped three-line log")

	if scene.tutorial_hint_label == null:
		failures.append("battle feedback: expected tutorial hint label to exist")
	elif not scene.tutorial_hint_label.text.contains("中心灵脉"):
		failures.append("battle feedback: expected opening tutorial hint to mention center spirit cells")

	if scene.sound_toggle_button == null or scene.hints_toggle_button == null:
		failures.append("battle feedback: expected demo setting toggles to exist")
	else:
		if not scene.sound_toggle_button.text.contains("开") or not scene.hints_toggle_button.text.contains("开"):
			failures.append("battle feedback: expected demo setting toggles to start enabled")

		scene._on_hints_toggled(false)

		if root.get_meta(DEMO_HINTS_ENABLED_META, true):
			failures.append("battle feedback: expected hint toggle to persist disabled preference")

		if scene.tutorial_hint_label.visible or not scene.tutorial_hint_label.text.is_empty():
			failures.append("battle feedback: expected tutorial hint to hide when disabled")

		scene._on_hints_toggled(true)

		if not scene.tutorial_hint_label.visible or not scene.tutorial_hint_label.text.contains("中心灵脉"):
			failures.append("battle feedback: expected tutorial hint to return when re-enabled")

		if scene.tone_player != null:
			var previous_tone: String = scene.tone_player.last_tone_kind
			scene._on_sound_toggled(false)
			scene._play_feedback_tone("skill")

			if scene.tone_player.last_tone_kind != previous_tone:
				failures.append("battle feedback: expected disabled sound toggle to suppress tones")

			if root.get_meta(DEMO_SOUND_ENABLED_META, true):
				failures.append("battle feedback: expected sound toggle to persist disabled preference")

			scene._on_sound_toggled(true)

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

	scene.current_turn = BoardState.ENEMY
	scene._begin_turn(BoardState.ENEMY)
	scene._refresh_board()
	await process_frame

	if scene.turn_rhythm_label == null or not scene.turn_rhythm_label.text.contains("敌方思考"):
		failures.append("battle feedback: expected enemy turn rhythm label")

	if scene.tutorial_hint_label == null or not scene.tutorial_hint_label.text.contains("敌方思考"):
		failures.append("battle feedback: expected tutorial hint to react to enemy thinking")

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
	root.remove_meta(DEMO_SOUND_ENABLED_META)
	root.remove_meta(DEMO_HINTS_ENABLED_META)
	await process_frame

	if failures.is_empty():
		print("Battle feedback smoke tests passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)

	quit(1)
