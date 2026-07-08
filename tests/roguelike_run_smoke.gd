extends SceneTree

const MapGeneratorScript := preload("res://scripts/roguelike/MapGenerator.gd")
const RunStateScript := preload("res://scripts/roguelike/RunState.gd")
const RunSaveScript := preload("res://scripts/roguelike/RunSave.gd")
const RewardGeneratorScript := preload("res://scripts/roguelike/RewardGenerator.gd")

const TEST_SAVE_PATH := "user://tymj_run_save_smoke.json"

var failures: Array = []


func _init() -> void:
	_run()

	if failures.is_empty():
		print("Roguelike run smoke tests passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)

	quit(1)


func _run() -> void:
	_assert_linear_route_shape()
	_assert_run_pacing_summary()
	_assert_battle_pacing_records_and_roundtrip()
	_assert_victories_unlock_boss()
	_assert_defeat_locks_run()
	_assert_reward_choice_blocks_progress_and_applies_modifier()
	_assert_route_choices_block_progress_and_apply_effects()
	_assert_reward_rarity_stack_limits_and_prices()
	_assert_reward_build_summary_text()
	_assert_settlement_feedback_roundtrip()
	_assert_state_roundtrip()
	_assert_local_save_roundtrip()


func _assert_linear_route_shape() -> void:
	var generator := MapGeneratorScript.new()
	var nodes := generator.generate_linear_route()

	if nodes.size() != 8:
		failures.append("run route: expected 8 linear nodes")
		return

	if nodes[0].get("type", "") != RunStateScript.NODE_START:
		failures.append("run route: first node should be start")
		return

	if nodes[2].get("type", "") != RunStateScript.NODE_EVENT:
		failures.append("run route: third node should be event")
		return

	if nodes[4].get("type", "") != RunStateScript.NODE_SHOP:
		failures.append("run route: fifth node should be shop")
		return

	if nodes[6].get("type", "") != RunStateScript.NODE_REST:
		failures.append("run route: seventh node should be rest")
		return

	if nodes[7].get("type", "") != RunStateScript.NODE_BOSS:
		failures.append("run route: last node should be boss")
		return

	if nodes[7].get("enemy_profile_id", "") != EnemyAI.PROFILE_ROCK_BOSS:
		failures.append("run route: boss node should use rock boss profile")

	if nodes[1].get("target_turn_min", 0) != 10 or nodes[1].get("target_turn_max", 0) != 16:
		failures.append("run route: first battle should include target turn pacing")

	if nodes[7].get("target_turn_min", 0) != 22 or nodes[7].get("target_turn_max", 0) != 30:
		failures.append("run route: boss should include target turn pacing")


func _assert_run_pacing_summary() -> void:
	var state := RunStateScript.new(MapGeneratorScript.new().generate_linear_route())
	var generator := RewardGeneratorScript.new()
	var pacing := state.get_run_pacing_summary()

	if pacing.get("total_battle_nodes", 0) != 4:
		failures.append("run pacing: expected three battles plus boss")
		return

	if pacing.get("remaining_battle_nodes", 0) != 4:
		failures.append("run pacing: fresh run should have four remaining battle nodes")
		return

	if pacing.get("remaining_turn_min", 0) != 58 or pacing.get("remaining_turn_max", 0) != 84:
		failures.append("run pacing: fresh run should summarize full target turn range")
		return

	if pacing.get("current_target_turn_min", 0) != 10 or pacing.get("current_target_turn_max", 0) != 16:
		failures.append("run pacing: current battle should expose its target turn range")
		return

	var reward_options := generator.generate_options(state, state.get_current_node())
	state.resolve_current_node(true, reward_options)
	state.claim_reward(reward_options[0].get("id", ""))
	pacing = state.get_run_pacing_summary()

	if pacing.get("completed_battle_nodes", 0) != 1 or pacing.get("remaining_battle_nodes", 0) != 3:
		failures.append("run pacing: battle completion should update battle counts")
		return

	if pacing.get("remaining_turn_min", 0) != 48 or pacing.get("remaining_turn_max", 0) != 68:
		failures.append("run pacing: battle completion should remove the first battle turn target")
		return

	var pacing_lines := generator.get_run_pacing_lines(state)

	if not pacing_lines.has("战斗进度 1/4，剩余 3 场"):
		failures.append("run pacing: display lines should include battle progress")
		return

	if not pacing_lines.has("星砂 2，商店价 2/3/4"):
		failures.append("run pacing: display lines should include starsand and shop price gradient")


func _assert_battle_pacing_records_and_roundtrip() -> void:
	var state := RunStateScript.new(MapGeneratorScript.new().generate_linear_route())
	var generator := RewardGeneratorScript.new()
	var reward_options := generator.generate_options(state, state.get_current_node())
	state.resolve_current_node(true, reward_options, 14)
	var records := state.get_battle_pacing_records()

	if records.size() != 1:
		failures.append("run pacing records: expected first battle record")
		return

	if records[0].get("actual_turn_count", 0) != 14:
		failures.append("run pacing records: expected actual turn count to be stored")
		return

	if records[0].get("actual_pacing_result", "") != "target":
		failures.append("run pacing records: expected first battle to be inside target range")
		return

	var pacing := state.get_run_pacing_summary()

	if pacing.get("recorded_battle_nodes", 0) != 1 or pacing.get("actual_turn_average", 0) != 14:
		failures.append("run pacing records: expected recorded battle average")
		return

	if pacing.get("on_target_count", 0) != 1:
		failures.append("run pacing records: expected target-range count")
		return

	var pacing_lines := generator.get_run_pacing_lines(state)
	var found_actual_line := false

	for line in pacing_lines:
		if line.contains("实测 1 场") and line.contains("均值 14 手"):
			found_actual_line = true
			break

	if not found_actual_line:
		failures.append("run pacing records: expected display lines to include actual pacing summary")
		return

	if not state.last_feedback.contains("本场 14 手"):
		failures.append("run pacing records: expected settlement feedback to include actual turn count")
		return

	var restored := RunStateScript.new()
	restored.load_from_dict(state.to_dict())
	var restored_records := restored.get_battle_pacing_records()

	if restored_records.size() != 1 or restored_records[0].get("actual_turn_count", 0) != 14:
		failures.append("run pacing records: expected actual counts to roundtrip through save data")


func _assert_victories_unlock_boss() -> void:
	var state := RunStateScript.new(MapGeneratorScript.new().generate_linear_route())

	if state.current_index != 1:
		failures.append("run progress: first playable node should be index 1")
		return

	if not state.can_enter_node(1):
		failures.append("run progress: first battle should be enterable")
		return

	for expected_index in [2, 3, 4, 5, 6, 7]:
		state.resolve_current_node(true)

		if state.current_index != expected_index:
			failures.append("run progress: expected current index %d, got %d" % [expected_index, state.current_index])
			return

		if not state.can_enter_node(expected_index):
			failures.append("run progress: expected node %d to be enterable" % expected_index)
			return

	state.resolve_current_node(true)

	if not state.run_completed:
		failures.append("run progress: boss victory should complete run")


func _assert_defeat_locks_run() -> void:
	var state := RunStateScript.new(MapGeneratorScript.new().generate_linear_route())
	state.resolve_current_node(false)

	if not state.run_failed:
		failures.append("run defeat: defeat should fail the run")
		return

	if state.can_enter_node(state.current_index):
		failures.append("run defeat: failed run should not allow entering current node")


func _assert_reward_choice_blocks_progress_and_applies_modifier() -> void:
	var state := RunStateScript.new(MapGeneratorScript.new().generate_linear_route())
	var generator := RewardGeneratorScript.new()
	var reward_options := generator.generate_options(state, state.get_current_node())

	if reward_options.size() != 3:
		failures.append("run reward: expected three reward options")
		return

	state.resolve_current_node(true, reward_options)

	if not state.has_pending_reward():
		failures.append("run reward: victory should create pending rewards")
		return

	if state.current_index != 1:
		failures.append("run reward: current node should wait while reward is pending")
		return

	if state.can_enter_node(2):
		failures.append("run reward: next node should stay locked before reward claim")
		return

	var claimed_reward: Dictionary = reward_options[0]

	if not state.claim_reward(claimed_reward.get("id", "")):
		failures.append("run reward: expected reward claim to succeed")
		return

	if state.has_pending_reward():
		failures.append("run reward: pending rewards should clear after claim")
		return

	if not state.can_enter_node(2):
		failures.append("run reward: next node should unlock after reward claim")
		return

	var modifiers := state.get_battle_modifiers()

	match claimed_reward.get("effect", ""):
		"energy_max":
			if modifiers.get("energy_max_bonus", 0) <= 0:
				failures.append("run reward: energy max reward should affect battle modifiers")
		"starting_energy":
			if modifiers.get("starting_energy_bonus", 0) <= 0:
				failures.append("run reward: starting energy reward should affect battle modifiers")
		"extra_spirit_cells":
			if modifiers.get("extra_spirit_cells", 0) <= 0:
				failures.append("run reward: spirit reward should affect battle modifiers")
		"rock_break_refund":
			if modifiers.get("rock_break_refund_per_battle", 0) <= 0:
				failures.append("run reward: rock refund reward should affect battle modifiers")
		"seal_refund":
			if modifiers.get("seal_refund_per_battle", 0) <= 0:
				failures.append("run reward: seal refund reward should affect battle modifiers")


func _assert_state_roundtrip() -> void:
	var state := RunStateScript.new(MapGeneratorScript.new().generate_linear_route())
	var reward_options := RewardGeneratorScript.new().generate_options(state, state.get_current_node())
	state.resolve_current_node(true, reward_options)
	state.claim_reward(reward_options[0].get("id", ""))

	var restored := RunStateScript.new()
	restored.load_from_dict(state.to_dict())

	if restored.current_index != state.current_index:
		failures.append("run save: restored current index mismatch")
		return

	if restored.nodes[1].get("status", "") != RunStateScript.STATUS_COMPLETED:
		failures.append("run save: restored completed node status mismatch")
		return

	if not restored.can_enter_node(2):
		failures.append("run save: restored state should keep next node enterable")

	if restored.rewards.size() != 1:
		failures.append("run save: restored rewards mismatch")


func _assert_local_save_roundtrip() -> void:
	RunSaveScript.delete_save(TEST_SAVE_PATH)

	var state := RunStateScript.new(MapGeneratorScript.new().generate_linear_route())
	var reward_options := RewardGeneratorScript.new().generate_options(state, state.get_current_node())
	state.resolve_current_node(true, reward_options)
	state.claim_reward(reward_options[1].get("id", ""))

	if not RunSaveScript.save_state(state, TEST_SAVE_PATH):
		failures.append("run local save: expected save to succeed")
		return

	if not RunSaveScript.has_save(TEST_SAVE_PATH):
		failures.append("run local save: expected save file to exist")
		return

	var restored := RunStateScript.new()
	restored.load_from_dict(RunSaveScript.load_dict(TEST_SAVE_PATH))

	if restored.current_index != state.current_index:
		failures.append("run local save: restored current index mismatch")
		return

	if restored.get_reward_titles() != state.get_reward_titles():
		failures.append("run local save: restored rewards mismatch")
		return

	if not RunSaveScript.delete_save(TEST_SAVE_PATH):
		failures.append("run local save: expected delete to succeed")
		return

	if RunSaveScript.has_save(TEST_SAVE_PATH):
		failures.append("run local save: expected save file to be removed")


func _assert_route_choices_block_progress_and_apply_effects() -> void:
	var state := RunStateScript.new(MapGeneratorScript.new().generate_linear_route())
	var generator := RewardGeneratorScript.new()
	state.resolve_current_node(true)

	if state.current_index != 2 or not state.can_enter_node(2):
		failures.append("run route choice: event should unlock after first battle")
		return

	var event_choices := generator.generate_node_choices(state, state.get_current_node())

	if event_choices.size() != 3:
		failures.append("run route choice: event should offer three choices")
		return

	if event_choices[1].get("cost", 0) <= 0:
		failures.append("run route choice: event risky reward should have a starsand cost")
		return

	if not state.open_node_choices(event_choices):
		failures.append("run route choice: expected event choices to open")
		return

	if state.can_enter_node(2) or state.can_enter_node(3):
		failures.append("run route choice: pending event choice should block node entry")
		return

	if not state.claim_node_choice(event_choices[0].get("id", "")):
		failures.append("run route choice: expected event coin choice to succeed")
		return

	if state.coins != 4:
		failures.append("run route choice: event coin choice should add starsand")
		return

	if state.current_index != 3 or not state.can_enter_node(3):
		failures.append("run route choice: event choice should advance to next battle")
		return

	state.resolve_current_node(true)
	var shop_choices := generator.generate_node_choices(state, state.get_current_node())
	state.open_node_choices(shop_choices)
	var coins_before_shop := state.coins
	var shop_cost: int = shop_choices[0].get("cost", 0)

	if not state.claim_node_choice(shop_choices[0].get("id", "")):
		failures.append("run route choice: expected affordable shop purchase to succeed")
		return

	if state.coins != coins_before_shop - shop_cost:
		failures.append("run route choice: shop purchase should spend its rarity-based starsand cost")
		return

	if state.rewards.is_empty():
		failures.append("run route choice: shop purchase should add a build reward")


func _assert_reward_rarity_stack_limits_and_prices() -> void:
	var state := RunStateScript.new(MapGeneratorScript.new().generate_linear_route())
	var generator := RewardGeneratorScript.new()
	var reward_options := generator.generate_options(state, state.get_current_node())

	if reward_options.size() != 3:
		failures.append("run reward tuning: expected three generated reward options")
		return

	for reward in reward_options:
		if reward.get("rarity", "").is_empty():
			failures.append("run reward tuning: generated reward should include rarity")
			return

		if reward.get("source_id", "").is_empty():
			failures.append("run reward tuning: generated reward should include source id")
			return

	var limited_reward := {
		"id": "limited_a",
		"source_id": "limited",
		"effect": "starting_energy",
		"amount": 1,
		"max_stack": 1,
	}
	state.rewards.append(limited_reward)

	if state.can_add_reward(limited_reward):
		failures.append("run reward tuning: max stack should block duplicate reward source")
		return

	var rock_refund := {
		"id": "rock_refund",
		"source_id": "rock_echo",
		"effect": "rock_break_refund",
		"amount": 1,
		"exclusive_group": "skill_refund",
	}
	var seal_refund := {
		"id": "seal_refund",
		"source_id": "seal_channel",
		"effect": "seal_refund",
		"amount": 1,
		"exclusive_group": "skill_refund",
	}
	state.rewards.clear()
	state.rewards.append(rock_refund)

	if state.can_add_reward(seal_refund):
		failures.append("run reward tuning: exclusive group should block competing refund reward")
		return

	if generator.get_price_for_reward({"rarity": RewardGeneratorScript.RARITY_RARE}) <= generator.get_price_for_reward({"rarity": RewardGeneratorScript.RARITY_COMMON}):
		failures.append("run reward tuning: rare rewards should cost more than common rewards")


func _assert_reward_build_summary_text() -> void:
	var state := RunStateScript.new(MapGeneratorScript.new().generate_linear_route())
	var generator := RewardGeneratorScript.new()
	state.rewards.append({
		"id": "summary_energy",
		"source_id": "summary_energy",
		"title": "灵息深蓄",
		"effect": RewardGeneratorScript.EFFECT_ENERGY_MAX,
		"amount": 1,
		"rarity": RewardGeneratorScript.RARITY_COMMON,
		"max_stack": 3,
	})
	state.rewards.append({
		"id": "summary_refund",
		"source_id": "rock_echo",
		"title": "碎岩回响",
		"effect": RewardGeneratorScript.EFFECT_ROCK_BREAK_REFUND,
		"amount": 1,
		"rarity": RewardGeneratorScript.RARITY_UNCOMMON,
		"max_stack": 1,
		"exclusive_group": "skill_refund",
	})

	var summary_lines := generator.get_build_summary_lines(state)

	if not summary_lines.has("能量上限 +1"):
		failures.append("run reward display: build summary should include energy max bonus")
		return

	if not summary_lines.has("碎岩首次返能 +1/场"):
		failures.append("run reward display: build summary should include rock refund")
		return

	if generator.get_reward_effect_summary(state.rewards[0]) != "能量上限 +1":
		failures.append("run reward display: reward effect summary should describe energy max")
		return

	var limit_text := generator.get_reward_limit_summary(state.rewards[1])

	if not limit_text.contains("最多 1 层") or not limit_text.contains("互斥：术法返能"):
		failures.append("run reward display: reward limit summary should describe stack and exclusive group")


func _assert_settlement_feedback_roundtrip() -> void:
	var state := RunStateScript.new(MapGeneratorScript.new().generate_linear_route())
	var generator := RewardGeneratorScript.new()
	var reward_options := generator.generate_options(state, state.get_current_node())
	state.resolve_current_node(true, reward_options)

	if not state.last_feedback.contains("胜利") or not state.last_feedback.contains("战利品"):
		failures.append("run settlement feedback: victory should explain pending reward")
		return

	if state.last_feedback_kind != "victory":
		failures.append("run settlement feedback: victory should be typed for UI feedback")
		return

	var claimed_reward: Dictionary = reward_options[0]
	state.claim_reward(claimed_reward.get("id", ""))

	if not state.last_feedback.contains("获得奖励") or not state.last_feedback.contains("下一站"):
		failures.append("run settlement feedback: reward claim should explain progression")
		return

	if state.last_feedback_kind != "reward_claimed":
		failures.append("run settlement feedback: reward claim should be typed for UI feedback")
		return

	var choices := generator.generate_node_choices(state, state.get_current_node())
	state.open_node_choices(choices)

	if not state.last_feedback.contains("选择一项"):
		failures.append("run settlement feedback: route choice should explain pending choice")
		return

	if state.last_feedback_kind != "choice_pending":
		failures.append("run settlement feedback: route choice should be typed for UI feedback")
		return

	state.claim_node_choice(choices[0].get("id", ""))

	if not state.last_feedback.contains("完成") or not state.last_feedback.contains("下一站"):
		failures.append("run settlement feedback: route choice claim should explain progression")
		return

	if state.last_feedback_kind != "choice_claimed":
		failures.append("run settlement feedback: route choice claim should be typed for UI feedback")
		return

	var restored := RunStateScript.new()
	restored.load_from_dict(state.to_dict())

	if restored.last_feedback != state.last_feedback:
		failures.append("run settlement feedback: feedback should roundtrip through save data")

	if restored.last_feedback_kind != state.last_feedback_kind:
		failures.append("run settlement feedback: feedback type should roundtrip through save data")
