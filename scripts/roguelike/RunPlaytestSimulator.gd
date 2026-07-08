class_name RunPlaytestSimulator
extends RefCounted

const MapGeneratorScript := preload("res://scripts/roguelike/MapGenerator.gd")
const RewardGeneratorScript := preload("res://scripts/roguelike/RewardGenerator.gd")
const RunStateScript := preload("res://scripts/roguelike/RunState.gd")


func run_baseline(actual_turn_counts: Array = []) -> Dictionary:
	var reward_generator := RewardGeneratorScript.new()
	var state := RunStateScript.new(MapGeneratorScript.new().generate_linear_route())
	var visited_nodes: Array = []
	var claimed_choices: Array = []
	var safety_limit := 32
	var battle_sample_index := 0

	while not state.run_completed and not state.run_failed and safety_limit > 0:
		safety_limit -= 1
		var node := state.get_current_node()

		if node.is_empty():
			break

		visited_nodes.append(node.get("index", -1))

		match node.get("type", ""):
			RunStateScript.NODE_BATTLE:
				var reward_options := reward_generator.generate_options(state, node)
				state.resolve_current_node(true, reward_options, _turn_sample_for_node(node, actual_turn_counts, battle_sample_index))
				battle_sample_index += 1
				_claim_first_available_reward(state, reward_options)
			RunStateScript.NODE_BOSS:
				state.resolve_current_node(true, [], _turn_sample_for_node(node, actual_turn_counts, battle_sample_index))
				battle_sample_index += 1
			RunStateScript.NODE_EVENT, RunStateScript.NODE_SHOP, RunStateScript.NODE_REST:
				var choices := reward_generator.generate_node_choices(state, node)
				state.open_node_choices(choices)
				var choice_id := _choose_route_option(state, choices, node.get("type", ""))

				if choice_id.is_empty() or not state.claim_node_choice(choice_id):
					break

				claimed_choices.append(choice_id)
			_:
				break

	var pacing := state.get_run_pacing_summary()
	return {
		"state": state,
		"visited_nodes": visited_nodes,
		"claimed_choices": claimed_choices,
		"battle_records": state.get_battle_pacing_records(),
		"pacing": pacing,
		"tuning_lines": reward_generator.get_run_tuning_lines(state),
		"completed": state.run_completed,
		"failed": state.run_failed,
		"safety_exhausted": safety_limit <= 0,
		"reward_count": state.rewards.size(),
		"coins": state.coins,
	}


func _turn_sample_for_node(node: Dictionary, actual_turn_counts: Array, sample_index: int) -> int:
	if sample_index >= 0 and sample_index < actual_turn_counts.size():
		return max(1, int(actual_turn_counts[sample_index]))

	var target_min: int = node.get("target_turn_min", 0)
	var target_max: int = node.get("target_turn_max", 0)

	if target_min > 0 and target_max > 0:
		return int(round(float(target_min + target_max) * 0.5))

	return 1


func _claim_first_available_reward(state, reward_options: Array) -> void:
	for reward in reward_options:
		var reward_id: String = reward.get("id", "")

		if state.claim_reward(reward_id):
			return


func _choose_route_option(state, choices: Array, node_type: String) -> String:
	match node_type:
		RunStateScript.NODE_EVENT:
			return _first_claimable_choice(state, choices, RewardGeneratorScript.CHOICE_COINS)
		RunStateScript.NODE_SHOP:
			var reward_choice := _first_claimable_choice(state, choices, RewardGeneratorScript.CHOICE_REWARD)

			if not reward_choice.is_empty():
				return reward_choice

			return _first_claimable_choice(state, choices, RewardGeneratorScript.CHOICE_SKIP)
		RunStateScript.NODE_REST:
			var rest_reward := _first_claimable_choice(state, choices, RewardGeneratorScript.CHOICE_REWARD)

			if not rest_reward.is_empty():
				return rest_reward

			return _first_claimable_choice(state, choices, RewardGeneratorScript.CHOICE_COINS)
		_:
			return ""


func _first_claimable_choice(state, choices: Array, choice_type: String) -> String:
	for choice in choices:
		if choice.get("choice_type", "") != choice_type:
			continue

		var choice_id: String = choice.get("id", "")

		if state.can_claim_node_choice(choice_id):
			return choice_id

	return ""
