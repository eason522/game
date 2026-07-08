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


func compare_run_to_baseline(run_state) -> Dictionary:
	if run_state == null or not run_state.has_method("get_run_pacing_summary") or not run_state.has_method("get_battle_pacing_records"):
		return {
			"recorded_battles": 0,
			"total_battles": 0,
			"lines": ["等待首场实机记录"],
			"attention": "校准关注：先补齐实机样本",
		}

	var current_pacing: Dictionary = run_state.get_run_pacing_summary()
	var records: Array = run_state.get_battle_pacing_records()
	var recorded_battles: int = current_pacing.get("recorded_battle_nodes", 0)
	var total_battles: int = current_pacing.get("total_battle_nodes", 0)

	if recorded_battles <= 0 or records.is_empty():
		return {
			"recorded_battles": 0,
			"total_battles": total_battles,
			"lines": ["等待首场实机记录"],
			"attention": "校准关注：先补齐实机样本",
		}

	var baseline_report := run_baseline()
	var baseline_pacing: Dictionary = baseline_report.get("pacing", {})
	var baseline_records_by_index := _records_by_node_index(baseline_report.get("battle_records", []))
	var current_average: int = current_pacing.get("actual_turn_average", 0)
	var baseline_average: int = baseline_pacing.get("actual_turn_average", 0)
	var average_delta := current_average - baseline_average
	var biggest_delta_record := _biggest_baseline_delta_record(records, baseline_records_by_index)
	var lines: Array = [
		"已测 %d/%d，均值 %d 手，较基准 %s，目标内 %d/%d，星砂 %d，奖励 %d" % [
			recorded_battles,
			total_battles,
			current_average,
			_signed_int_text(average_delta),
			current_pacing.get("on_target_count", 0),
			recorded_battles,
			run_state.coins,
			run_state.rewards.size(),
		],
	]

	if not biggest_delta_record.is_empty():
		lines.append("最大偏差：%s 较基准 %s 手（%s）" % [
			biggest_delta_record.get("title", "战斗"),
			_signed_int_text(biggest_delta_record.get("baseline_delta", 0)),
			_pacing_result_label(biggest_delta_record.get("actual_pacing_result", "")),
		])

	var attention := _comparison_attention_line(current_pacing, biggest_delta_record, recorded_battles, total_battles)
	lines.append(attention)

	return {
		"recorded_battles": recorded_battles,
		"total_battles": total_battles,
		"average_delta": average_delta,
		"biggest_delta_record": biggest_delta_record,
		"lines": lines,
		"attention": attention,
	}


func _turn_sample_for_node(node: Dictionary, actual_turn_counts: Array, sample_index: int) -> int:
	if sample_index >= 0 and sample_index < actual_turn_counts.size():
		return max(1, int(actual_turn_counts[sample_index]))

	var target_min: int = node.get("target_turn_min", 0)
	var target_max: int = node.get("target_turn_max", 0)

	if target_min > 0 and target_max > 0:
		return int(round(float(target_min + target_max) * 0.5))

	return 1


func _records_by_node_index(records: Array) -> Dictionary:
	var indexed := {}

	for record in records:
		indexed[record.get("node_index", -1)] = record

	return indexed


func _biggest_baseline_delta_record(records: Array, baseline_records_by_index: Dictionary) -> Dictionary:
	var biggest := {}
	var biggest_abs_delta := -1

	for record in records:
		var node_index: int = record.get("node_index", -1)
		var baseline_record: Dictionary = baseline_records_by_index.get(node_index, {})

		if baseline_record.is_empty():
			continue

		var delta: int = record.get("actual_turn_count", 0) - baseline_record.get("actual_turn_count", 0)
		var abs_delta: int = abs(delta)

		if abs_delta <= biggest_abs_delta:
			continue

		biggest_abs_delta = abs_delta
		biggest = record.duplicate(true)
		biggest["baseline_turn_count"] = baseline_record.get("actual_turn_count", 0)
		biggest["baseline_delta"] = delta

	return biggest


func _comparison_attention_line(pacing: Dictionary, biggest_delta_record: Dictionary, recorded_battles: int, total_battles: int) -> String:
	if recorded_battles < total_battles:
		return "校准关注：继续补齐完整 Run 样本"

	var under_count: int = pacing.get("under_target_count", 0)
	var over_count: int = pacing.get("over_target_count", 0)

	if over_count > under_count:
		return "校准关注：多场偏慢，优先检查后段奖励强度和 Boss 目标手数"

	if under_count > over_count:
		return "校准关注：多场偏快，优先放缓早期奖励或上调普通战斗目标"

	if not biggest_delta_record.is_empty() and biggest_delta_record.get("type", "") == RunStateScript.NODE_BOSS:
		var boss_delta: int = biggest_delta_record.get("baseline_delta", 0)

		if boss_delta > 0:
			return "校准关注：Boss 较基准偏慢，优先提升后段构筑资源或下调 Boss 目标"

		if boss_delta < 0:
			return "校准关注：Boss 较基准偏快，优先观察岩阵压制是否不足"

	return "校准关注：实测接近基准，先保持数值并观察手感"


func _signed_int_text(value: int) -> String:
	if value > 0:
		return "+%d" % value

	return str(value)


func _pacing_result_label(result: String) -> String:
	match result:
		"under":
			return "偏快"
		"over":
			return "偏慢"
		"target":
			return "目标内"
		_:
			return "待判断"


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
