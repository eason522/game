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


func run_sample_matrix() -> Dictionary:
	var scenarios: Array = [
		{"id": "baseline", "label": "基准", "turns": []},
		{"id": "fast", "label": "偏快", "turns": [8, 11, 13, 19]},
		{"id": "slow", "label": "偏慢", "turns": [18, 24, 26, 34]},
		{"id": "boss_pressure", "label": "Boss 压力", "turns": [13, 17, 19, 36]},
	]
	var samples: Array = []
	var summary_lines: Array = []

	for scenario in scenarios:
		var report := run_baseline(scenario.get("turns", []))
		var pacing: Dictionary = report.get("pacing", {})
		var sample := {
			"id": scenario.get("id", ""),
			"label": scenario.get("label", ""),
			"completed": report.get("completed", false) and not report.get("safety_exhausted", false),
			"recorded_battles": pacing.get("recorded_battle_nodes", 0),
			"on_target_battles": pacing.get("on_target_count", 0),
			"total_turns": pacing.get("actual_turn_total", 0),
			"coins": report.get("coins", 0),
			"reward_count": report.get("reward_count", 0),
			"summary": _sample_matrix_line(scenario.get("label", ""), report),
		}
		samples.append(sample)
		summary_lines.append(sample.get("summary", ""))

	var focus_lines := _sample_matrix_focus_lines(samples)
	var action_lines := _sample_matrix_action_lines(samples)
	return {
		"samples": samples,
		"summary_lines": summary_lines,
		"focus_lines": focus_lines,
		"action_lines": action_lines,
		"display_lines": summary_lines + focus_lines + action_lines,
	}


func get_live_playtest_checklist(run_state) -> Array:
	var baseline_report := run_baseline()
	var baseline_pacing: Dictionary = baseline_report.get("pacing", {})
	var comparison := compare_run_to_baseline(run_state)
	var matrix := run_sample_matrix()
	var current_pacing: Dictionary = {}

	if run_state != null and run_state.has_method("get_run_pacing_summary"):
		current_pacing = run_state.get_run_pacing_summary()

	var recorded_battles: int = current_pacing.get("recorded_battle_nodes", comparison.get("recorded_battles", 0))
	var total_battles: int = current_pacing.get("total_battle_nodes", comparison.get("total_battles", 0))
	var lines: Array = []

	if total_battles <= 0:
		total_battles = baseline_pacing.get("recorded_battle_nodes", 4)

	if recorded_battles <= 0:
		lines.append("试玩检查：先完成首场战斗，记录实际手数后再看偏差")
	elif recorded_battles < total_battles:
		lines.append("试玩检查：继续补齐完整 Run 实测 %d/%d 场，至少打到 Boss 结算" % [recorded_battles, total_battles])
	else:
		lines.append("试玩检查：完整 Run 实测已齐，按最大偏差节点做小步调参")

	lines.append("试玩检查：基准 %d/%d 场目标内，总 %d 手，星砂 %d，奖励 %d" % [
		baseline_pacing.get("on_target_count", 0),
		baseline_pacing.get("recorded_battle_nodes", 0),
		baseline_pacing.get("actual_turn_total", 0),
		baseline_report.get("coins", 0),
		baseline_report.get("reward_count", 0),
	])

	var attention: String = comparison.get("attention", "")

	if not attention.is_empty():
		lines.append("试玩检查：%s" % attention.trim_prefix("校准关注："))

	var action_lines: Array = matrix.get("action_lines", [])

	if not action_lines.is_empty():
		lines.append("试玩检查：%s" % String(action_lines[0]).trim_prefix("矩阵落点："))

	lines.append("试玩检查：每轮只调整普通战斗目标、星砂价格或 Boss 手数中的一项")
	return lines


func get_live_playtest_snapshot_lines(run_state) -> Array:
	if run_state == null or not run_state.has_method("get_run_pacing_summary"):
		return ["实机快照：暂无 Run 数据，先从路线图开始一轮 Run"]

	var pacing: Dictionary = run_state.get_run_pacing_summary()
	var current_node: Dictionary = run_state.get_current_node() if run_state.has_method("get_current_node") else {}
	var current_title: String = current_node.get("title", "无当前节点")
	var current_type: String = _snapshot_node_type_label(current_node.get("type", ""))
	var recorded_battles: int = pacing.get("recorded_battle_nodes", 0)
	var total_battles: int = pacing.get("total_battle_nodes", 0)
	var on_target_count: int = pacing.get("on_target_count", 0)
	var lines: Array = [
		"实机快照：当前 %s（%s），实测 %d/%d 场，目标内 %d/%d" % [
			current_title,
			current_type,
			recorded_battles,
			total_battles,
			on_target_count,
			recorded_battles,
		],
	]

	if recorded_battles <= 0:
		var baseline_report := run_baseline()
		var baseline_pacing: Dictionary = baseline_report.get("pacing", {})
		lines.append("实机快照：基准 %d/%d 场目标内，总 %d 手；先记录首场实测手数" % [
			baseline_pacing.get("on_target_count", 0),
			baseline_pacing.get("recorded_battle_nodes", 0),
			baseline_pacing.get("actual_turn_total", 0),
		])
	elif recorded_battles < total_battles:
		var comparison := compare_run_to_baseline(run_state)
		lines.append("实机快照：%s" % String(comparison.get("attention", "校准关注：继续补齐完整 Run 样本")).trim_prefix("校准关注："))
	else:
		var comparison := compare_run_to_baseline(run_state)
		var biggest_delta_record: Dictionary = comparison.get("biggest_delta_record", {})

		if biggest_delta_record.is_empty():
			lines.append("实机快照：完整样本已齐，暂未发现明显最大偏差")
		else:
			lines.append("实机快照：完整样本已齐，最大偏差 %s %s 手" % [
				biggest_delta_record.get("title", "战斗"),
				_signed_int_text(biggest_delta_record.get("baseline_delta", 0)),
			])

	lines.append(_live_playtest_next_step_line(run_state, recorded_battles, total_battles))
	return lines


func get_live_playtest_decision_lines(run_state) -> Array:
	if run_state == null or not run_state.has_method("get_run_pacing_summary"):
		return ["实机结论：暂无 Run 数据，不落数值"]

	var pacing: Dictionary = run_state.get_run_pacing_summary()
	var recorded_battles: int = pacing.get("recorded_battle_nodes", 0)
	var total_battles: int = pacing.get("total_battle_nodes", 0)

	if recorded_battles < total_battles:
		return ["实机结论：样本未齐 %d/%d，不落数值；先补完整 Run" % [recorded_battles, total_battles]]

	if run_state.run_failed:
		return ["实机结论：Run 已失败，先记录失败节点，不直接调数值"]

	var comparison := compare_run_to_baseline(run_state)
	var candidates := get_single_axis_tuning_candidates(run_state)
	var first_candidate := "无明确候选"

	if not candidates.is_empty():
		first_candidate = String(candidates[0]).trim_prefix("单轴候选：")

	var status_text := "已通关" if run_state.run_completed else "样本已齐"
	return [
		"实机结论：完整 Run %s，目标内 %d/%d，总 %d 手，进入单轴决策" % [
			status_text,
			pacing.get("on_target_count", 0),
			recorded_battles,
			pacing.get("actual_turn_total", 0),
		],
		"实机结论：优先候选：%s" % first_candidate,
		"实机结论：证据：%s" % String(comparison.get("attention", "校准关注：实测接近基准")).trim_prefix("校准关注："),
	]


func get_live_playtest_verdict_lines(run_state) -> Array:
	if run_state == null or not run_state.has_method("get_run_pacing_summary"):
		return ["实机判定：暂无 Run 数据，不进入调参"]

	var pacing: Dictionary = run_state.get_run_pacing_summary()
	var recorded_battles: int = pacing.get("recorded_battle_nodes", 0)
	var total_battles: int = pacing.get("total_battle_nodes", 0)

	if recorded_battles < total_battles:
		return ["实机判定：样本未齐 %d/%d，不进入调参" % [recorded_battles, total_battles]]

	if run_state.run_failed:
		return ["实机判定：Run 已失败，先复盘失败节点，不直接改数值"]

	var comparison := compare_run_to_baseline(run_state)
	var candidates := get_single_axis_tuning_candidates(run_state)
	var first_candidate := ""

	if not candidates.is_empty():
		first_candidate = String(candidates[0]).trim_prefix("单轴候选：")

	if _is_live_sample_close_to_baseline(pacing, comparison):
		return ["实机判定：保持当前数值，进入下一轮手感观察"]

	if first_candidate.contains("Boss 手数轴"):
		return ["实机判定：只动 Boss 手数轴，先复核 Boss 上限与静息调气体感"]

	if first_candidate.contains("普通战斗轴"):
		return ["实机判定：只动普通战斗轴，下一轮按最大偏差节点小步改目标手数"]

	if first_candidate.contains("星砂轴"):
		return ["实机判定：只动星砂轴，先验证商店前购买压力"]

	if first_candidate.contains("奖励轴"):
		return ["实机判定：只动奖励轴，先验证 Boss 前构筑密度"]

	return ["实机判定：候选不明确，保持当前数值并补一轮实机样本"]


func get_live_playtest_review_lines(run_state) -> Array:
	if run_state == null or not run_state.has_method("get_run_pacing_summary"):
		return ["实机复盘：暂无 Run 数据，先开始一轮完整试玩"]

	var pacing: Dictionary = run_state.get_run_pacing_summary()
	var recorded_battles: int = pacing.get("recorded_battle_nodes", 0)
	var total_battles: int = pacing.get("total_battle_nodes", 0)

	if recorded_battles < total_battles:
		return [
			"实机复盘：样本未齐 %d/%d，暂只记录体感，不落结论" % [recorded_battles, total_battles],
			"实机复盘：%s" % _rest_focus_review_text(run_state, false),
		]

	if run_state.run_failed:
		return [
			"实机复盘：Run 已失败，先记录失败节点与 Boss 前资源",
			"实机复盘：%s" % _rest_focus_review_text(run_state, true),
		]

	var comparison := compare_run_to_baseline(run_state)
	var candidates := get_single_axis_tuning_candidates(run_state)
	var first_candidate := "无明确候选"

	if not candidates.is_empty():
		first_candidate = String(candidates[0]).trim_prefix("单轴候选：")

	return [
		"实机复盘：完整 Run 已齐，目标内 %d/%d，总 %d 手" % [
			pacing.get("on_target_count", 0),
			recorded_battles,
			pacing.get("actual_turn_total", 0),
		],
		"实机复盘：%s" % _boss_pressure_review_text(comparison.get("biggest_delta_record", {})),
		"实机复盘：%s；优先候选：%s" % [_rest_focus_review_text(run_state, true), first_candidate],
	]


func get_single_axis_tuning_candidates(run_state) -> Array:
	if run_state == null or not run_state.has_method("get_run_pacing_summary"):
		return ["单轴候选：暂无 Run 数据，先完成一次实机记录"]

	var pacing: Dictionary = run_state.get_run_pacing_summary()
	var recorded_battles: int = pacing.get("recorded_battle_nodes", 0)
	var total_battles: int = pacing.get("total_battle_nodes", 0)

	if recorded_battles <= 0:
		return ["单轴候选：等待首场实测，不先改数值"]

	if recorded_battles < total_battles:
		return ["单轴候选：样本未齐，先补到 Boss 再决定调普通战斗、星砂或奖励"]

	var comparison := compare_run_to_baseline(run_state)
	var biggest_delta_record: Dictionary = comparison.get("biggest_delta_record", {})
	var lines: Array = []

	if not biggest_delta_record.is_empty():
		lines.append(_candidate_line_for_biggest_delta(biggest_delta_record))
	else:
		lines.append("单轴候选：无明显最大偏差，先保持本轮目标手数")

	lines.append(_candidate_line_for_economy(run_state))
	lines.append(_candidate_line_for_rewards(run_state, pacing))
	return lines


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


func _is_live_sample_close_to_baseline(pacing: Dictionary, comparison: Dictionary) -> bool:
	var recorded_battles: int = pacing.get("recorded_battle_nodes", 0)

	if recorded_battles <= 0:
		return false

	if pacing.get("on_target_count", 0) != recorded_battles:
		return false

	if abs(comparison.get("average_delta", 0)) > 1:
		return false

	return String(comparison.get("attention", "")).contains("实测接近基准")


func _live_playtest_next_step_line(run_state, recorded_battles: int, total_battles: int) -> String:
	if run_state == null:
		return "实机快照：下一步从路线图开始"

	if run_state.run_completed:
		return "实机快照：下一步对照单轴候选，只决定是否小步调一项"

	if run_state.run_failed:
		return "实机快照：下一步重开 Run，优先记录失败前最大压力节点"

	if run_state.has_pending_reward():
		return "实机快照：下一步先领取奖励，确认构筑摘要变化"

	if run_state.has_pending_node_choice():
		return "实机快照：下一步先处理路线选择，确认星砂/奖励变化"

	if recorded_battles < total_battles:
		return "实机快照：下一步继续推进到 Boss，补齐完整 Run 样本"

	return "实机快照：下一步复核最大偏差与 Boss 准备摘要"


func _boss_pressure_review_text(biggest_delta_record: Dictionary) -> String:
	if biggest_delta_record.is_empty():
		return "Boss 压力未形成最大偏差，先保持当前 Boss 上限"

	var title: String = biggest_delta_record.get("title", "战斗")
	var delta: int = biggest_delta_record.get("baseline_delta", 0)
	var node_type: String = biggest_delta_record.get("type", "")

	if node_type == RunStateScript.NODE_BOSS:
		if delta > 0:
			return "Boss 压力仍偏慢，%s 较基准 %s 手" % [title, _signed_int_text(delta)]

		if delta < 0:
			return "Boss 压力偏快，%s 较基准 %s 手，先看岩阵压制" % [title, _signed_int_text(delta)]

		return "Boss 压力接近基准，先保持岩王目标"

	return "最大偏差在 %s（%s 手），Boss 压力先观察" % [title, _signed_int_text(delta)]


func _rest_focus_review_text(run_state, full_sample_ready: bool) -> String:
	var has_rest_focus := _has_reward_source(run_state, RewardGeneratorScript.REST_FOCUS_SOURCE_ID)

	if has_rest_focus and full_sample_ready:
		return "静息调气已验证，复核 Boss 前 5 手是否更稳"

	if has_rest_focus:
		return "静息调气已取得，需打到 Boss 后验证体感"

	return "静息调气尚未验证，Boss 前补强结论需保留"


func _has_reward_source(run_state, source_id: String) -> bool:
	if run_state == null:
		return false

	for reward in run_state.rewards:
		if reward.get("source_id", reward.get("id", "")) == source_id:
			return true

	return false


func _snapshot_node_type_label(node_type: String) -> String:
	match node_type:
		RunStateScript.NODE_BATTLE:
			return "战斗"
		RunStateScript.NODE_EVENT:
			return "事件"
		RunStateScript.NODE_SHOP:
			return "商店"
		RunStateScript.NODE_REST:
			return "休息"
		RunStateScript.NODE_BOSS:
			return "Boss"
		_:
			return "路线"


func _sample_matrix_line(label: String, report: Dictionary) -> String:
	var pacing: Dictionary = report.get("pacing", {})
	var status_text := "可通关" if report.get("completed", false) and not report.get("safety_exhausted", false) else "需复查"
	return "%s：%s，%d/%d 目标内，总 %d 手，星砂 %d，奖励 %d" % [
		label,
		status_text,
		pacing.get("on_target_count", 0),
		pacing.get("recorded_battle_nodes", 0),
		pacing.get("actual_turn_total", 0),
		report.get("coins", 0),
		report.get("reward_count", 0),
	]


func _sample_matrix_focus_lines(samples: Array) -> Array:
	var lines: Array = []
	var has_route_failure := false
	var slow_total := 0
	var fast_total := 0
	var boss_pressure_total := 0

	for sample in samples:
		if not sample.get("completed", false):
			has_route_failure = true

		match sample.get("id", ""):
			"slow":
				slow_total = sample.get("total_turns", 0)
			"fast":
				fast_total = sample.get("total_turns", 0)
			"boss_pressure":
				boss_pressure_total = sample.get("total_turns", 0)

	if has_route_failure:
		lines.append("矩阵关注：存在未通关样本，先检查路线推进或奖励领取阻塞")
	elif slow_total > 88 or boss_pressure_total > 88:
		lines.append("矩阵关注：压力样本越过 88 手，优先校准 Boss 手数与后段构筑强度")
	elif fast_total < 60:
		lines.append("矩阵关注：偏快样本低于 60 手，早期奖励和星砂不宜继续加速")
	else:
		lines.append("矩阵关注：样本均在总目标附近，可进入实机手感验证")

	return lines


func _sample_matrix_action_lines(samples: Array) -> Array:
	var fast_sample := _sample_by_id(samples, "fast")
	var slow_sample := _sample_by_id(samples, "slow")
	var boss_pressure_sample := _sample_by_id(samples, "boss_pressure")
	var lines: Array = []

	if not fast_sample.is_empty() and fast_sample.get("total_turns", 0) < 60:
		lines.append("矩阵落点：偏快样本低于 60 手，早期奖励与星砂先不再提速")

	if not slow_sample.is_empty() and slow_sample.get("total_turns", 0) > 88:
		lines.append("矩阵落点：偏慢样本高于 88 手，若实机接近则普通战斗目标 -2 或后段奖励 +1")

	if not boss_pressure_sample.is_empty() and boss_pressure_sample.get("on_target_battles", 0) < boss_pressure_sample.get("recorded_battles", 0):
		lines.append("矩阵落点：Boss 压力样本有越界，优先复核 Boss 上限 30 手与休息点静息调气 +2")

	if lines.is_empty():
		lines.append("矩阵落点：样本暂稳，下一轮只按实机最大偏差做小步调整")

	return lines


func _sample_by_id(samples: Array, id: String) -> Dictionary:
	for sample in samples:
		if sample.get("id", "") == id:
			return sample

	return {}


func _candidate_line_for_biggest_delta(record: Dictionary) -> String:
	var delta: int = record.get("baseline_delta", 0)
	var node_type: String = record.get("type", "")
	var title: String = record.get("title", "战斗")

	if node_type == RunStateScript.NODE_BOSS:
		if delta > 0:
			return "单轴候选：Boss 手数轴，%s 偏慢；优先复核 Boss 上限或休息点静息调气 +2" % title

		if delta < 0:
			return "单轴候选：Boss 手数轴，%s 偏快；先观察岩阵压制是否不足" % title

	if delta > 0:
		return "单轴候选：普通战斗轴，%s 偏慢；下一轮只试普通节点目标 -2" % title

	if delta < 0:
		return "单轴候选：普通战斗轴，%s 偏快；下一轮只试普通节点目标 +2" % title

	return "单轴候选：%s 接近基准，先不改目标手数" % title


func _candidate_line_for_economy(run_state) -> String:
	var common_price: int = RewardGeneratorScript.RARITY_PRICES.get(RewardGeneratorScript.RARITY_COMMON, 2)
	var rare_price: int = RewardGeneratorScript.RARITY_PRICES.get(RewardGeneratorScript.RARITY_RARE, 5)

	if run_state.coins < common_price:
		return "单轴候选：星砂轴偏紧；若商店前仍不足，优先事件星砂 +1"

	if run_state.coins >= rare_price:
		return "单轴候选：星砂轴偏宽；若史诗过早稳定购买，优先史诗价格 +1"

	return "单轴候选：星砂轴暂稳，本轮不动商店价格"


func _candidate_line_for_rewards(run_state, pacing: Dictionary) -> String:
	var reward_count: int = run_state.rewards.size()
	var completed_battles: int = pacing.get("completed_battle_nodes", 0)

	if reward_count >= completed_battles + 2:
		return "单轴候选：奖励轴偏密；若体感成型过早，优先下调非战斗奖励"

	if reward_count < completed_battles:
		return "单轴候选：奖励轴偏稀；若 Boss 前构筑不足，优先强化休息点"

	return "单轴候选：奖励轴暂稳，先不改奖励池"


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
