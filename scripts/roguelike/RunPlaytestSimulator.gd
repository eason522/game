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
		"实机结论：证据：%s%s" % [
			String(comparison.get("attention", "校准关注：实测接近基准")).trim_prefix("校准关注："),
			_boss_opening_evidence_suffix(run_state),
		],
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

	if run_state.boss_opening_feel == RunStateScript.BOSS_OPENING_FEEL_PRESSURE:
		return ["实机判定：Boss 前 5 手仍压迫，先只复核 Boss 上限或开局资源，不动普通战斗"]

	if run_state.boss_opening_feel == RunStateScript.BOSS_OPENING_FEEL_UNCLEAR:
		return ["实机判定：Boss 前 5 手体感不明确，保持当前数值并补一轮可复盘样本"]

	var pressure_level := _boss_opening_pressure_level(run_state)

	if pressure_level == RunStateScript.BOSS_OPENING_PRESSURE_HIGH:
		return ["实机判定：Boss 快照压力偏高，先只复核 Boss 开局资源或岩阵压迫，不动普通战斗"]

	if pressure_level == RunStateScript.BOSS_OPENING_PRESSURE_REVIEW and run_state.boss_opening_feel.is_empty():
		return ["实机判定：Boss 快照需复看，先补前 5 手体感记录，再决定是否调 Boss"]

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


func get_live_run_closeout_lines(run_state) -> Array:
	if run_state == null or not run_state.has_method("get_run_pacing_summary"):
		return ["实机收口：暂无 Run 数据，先开始一轮完整试玩"]

	var pacing: Dictionary = run_state.get_run_pacing_summary()
	var recorded_battles: int = pacing.get("recorded_battle_nodes", 0)
	var total_battles: int = pacing.get("total_battle_nodes", 0)

	if recorded_battles < total_battles:
		return ["实机收口：样本未齐 %d/%d，本轮只记录过程，不关闭结论" % [recorded_battles, total_battles]]

	if run_state.run_failed:
		return ["实机收口：Run 已失败，先复盘失败节点与 Boss 前资源，不落新数值"]

	var pressure_level := _boss_opening_pressure_level(run_state)

	if pressure_level == RunStateScript.BOSS_OPENING_PRESSURE_HIGH and run_state.boss_opening_feel.is_empty():
		return ["实机收口：完整 Run 已齐且 Boss 快照压力偏高；先补体感并复核开局资源"]

	if run_state.boss_opening_feel.is_empty():
		return ["实机收口：完整 Run 已齐，但 Boss 前 5 手体感未记录；先补体感再定结论"]

	var candidates := get_single_axis_tuning_candidates(run_state)
	var first_candidate := "无明确候选"

	if not candidates.is_empty():
		first_candidate = String(candidates[0]).trim_prefix("单轴候选：")

	match run_state.boss_opening_feel:
		RunStateScript.BOSS_OPENING_FEEL_STABLE:
			if pressure_level == RunStateScript.BOSS_OPENING_PRESSURE_HIGH:
				return ["实机收口：Boss 体感更稳但快照压力偏高，先补一轮可复现样本，不动普通战斗"]

			if pressure_level == RunStateScript.BOSS_OPENING_PRESSURE_REVIEW:
				return ["实机收口：Boss 体感更稳但快照需复看，下一轮只观察 Boss 开局"]

			if _is_live_sample_close_to_baseline(pacing, compare_run_to_baseline(run_state)):
				return ["实机收口：完整 Run 可收口，静息调气体感更稳，保持当前数值"]

			return ["实机收口：Boss 体感更稳，下一轮仅按优先候选复核：%s" % first_candidate]
		RunStateScript.BOSS_OPENING_FEEL_PRESSURE:
			return ["实机收口：Boss 前 5 手仍压迫，本轮转入 Boss 手感轴，不动普通战斗"]
		RunStateScript.BOSS_OPENING_FEEL_UNCLEAR:
			return ["实机收口：Boss 体感需再测，本轮保留记录，先补一轮可复盘样本"]
		_:
			return ["实机收口：体感记录异常，先复核 Boss 前 5 手结论"]


func get_boss_pressure_followup_lines(run_state) -> Array:
	if run_state == null or not run_state.has_method("get_run_pacing_summary") or not run_state.has_method("get_battle_pacing_records"):
		return ["Boss 复核：暂无 Run 数据，先推进到 Boss 结算"]

	var pacing: Dictionary = run_state.get_run_pacing_summary()
	var recorded_battles: int = pacing.get("recorded_battle_nodes", 0)
	var total_battles: int = pacing.get("total_battle_nodes", 0)

	if recorded_battles < total_battles:
		return ["Boss 复核：样本未齐 %d/%d，进 Boss 前保留静息调气、开局能量、奖励数和星砂记录" % [recorded_battles, total_battles]]

	var boss_record := _boss_pacing_record(run_state.get_battle_pacing_records())

	if boss_record.is_empty():
		return ["Boss 复核：完整样本缺少 Boss 记录，先复核路线结算回传"]

	var rest_text := "静息调气已生效" if _has_reward_source(run_state, RewardGeneratorScript.REST_FOCUS_SOURCE_ID) else "静息调气未验证"
	var feel_label: String = run_state.get_boss_opening_feel_label() if run_state.has_method("get_boss_opening_feel_label") else "未记录"
	var pressure_lines: Array = run_state.get_boss_opening_pressure_lines() if run_state.has_method("get_boss_opening_pressure_lines") else []
	var lines: Array = [
		"Boss 复核：%s %d 手，%s，前 5 手：%s" % [
			boss_record.get("title", "Boss"),
			boss_record.get("actual_turn_count", 0),
			rest_text,
			feel_label,
		],
	]

	if not pressure_lines.is_empty():
		lines.append("Boss 复核：%s" % String(pressure_lines[0]).trim_prefix("Boss 快照判读："))

	if run_state.boss_opening_feel.is_empty():
		lines.append("Boss 复核：先补体感按钮，再判断是否复核 Boss 上限")
		return lines

	match run_state.boss_opening_feel:
		RunStateScript.BOSS_OPENING_FEEL_STABLE:
			if boss_record.get("actual_pacing_result", "") == "target":
				lines.append("Boss 复核：体感更稳且目标内，下一轮只观察是否可复现")
			else:
				lines.append("Boss 复核：体感更稳但手数有偏差，下一轮只看最大偏差节点")
		RunStateScript.BOSS_OPENING_FEEL_PRESSURE:
			lines.append("Boss 复核：下一轮只看开局岩阵压迫、可用能量和 5 手内反制点")
		RunStateScript.BOSS_OPENING_FEEL_UNCLEAR:
			lines.append("Boss 复核：下一轮补一场可复盘样本，记录第 1/3/5 手局面")
		_:
			lines.append("Boss 复核：体感记录异常，先复核按钮写入")

	return lines


func get_rest_focus_feel_audit_lines(run_state) -> Array:
	if run_state == null or not run_state.has_method("get_run_pacing_summary") or not run_state.has_method("get_battle_pacing_records"):
		return ["静息复核：暂无 Run 数据，先推进到休息点和 Boss"]

	var pacing: Dictionary = run_state.get_run_pacing_summary()
	var recorded_battles: int = pacing.get("recorded_battle_nodes", 0)
	var total_battles: int = pacing.get("total_battle_nodes", 0)
	var has_rest_focus := _has_reward_source(run_state, RewardGeneratorScript.REST_FOCUS_SOURCE_ID)

	if recorded_battles < total_battles:
		if has_rest_focus:
			return ["静息复核：静息调气已拿到，继续补齐 Boss 样本后判断前 5 手压力"]

		if _is_rest_step_active(run_state):
			return ["静息复核：当前在休息点，优先选择或记录未选静息调气"]

		return ["静息复核：样本未齐 %d/%d，先确认休息点是否拿到静息调气" % [recorded_battles, total_battles]]

	var boss_record := _boss_pacing_record(run_state.get_battle_pacing_records())

	if boss_record.is_empty():
		return ["静息复核：完整样本缺少 Boss 记录，先复核结算回传"]

	var rest_text := "静息调气已生效" if has_rest_focus else "静息调气未验证"
	var feel_label: String = run_state.get_boss_opening_feel_label() if run_state.has_method("get_boss_opening_feel_label") else "未记录"
	var pressure_level := _boss_opening_pressure_level(run_state)
	var lines: Array = [
		"静息复核：%s，Boss %d 手，前 5 手：%s" % [
			rest_text,
			boss_record.get("actual_turn_count", 0),
			feel_label,
		],
	]

	match pressure_level:
		RunStateScript.BOSS_OPENING_PRESSURE_HIGH:
			if has_rest_focus:
				lines.append("静息复核：已补强但快照仍高压，下一轮只看开局岩阵、能量和反制点")
			else:
				lines.append("静息复核：快照高压且未验证静息调气，先复核休息点选择")
		RunStateScript.BOSS_OPENING_PRESSURE_REVIEW:
			lines.append("静息复核：快照需复看，先补体感记录再判断补强是否足够")
		RunStateScript.BOSS_OPENING_PRESSURE_STABLE:
			if run_state.boss_opening_feel == RunStateScript.BOSS_OPENING_FEEL_STABLE:
				lines.append("静息复核：快照暂稳且体感更稳，补强可保留")
			elif run_state.boss_opening_feel == RunStateScript.BOSS_OPENING_FEEL_PRESSURE:
				lines.append("静息复核：快照暂稳但体感仍压迫，下一轮只复核 Boss 手感")
			else:
				lines.append("静息复核：快照暂稳，先补前 5 手体感再收口")
		_:
			lines.append("静息复核：尚无快照判读，先完成 Boss 前 5 手自动记录")

	return lines


func get_boss_pressure_validation_lines(run_state) -> Array:
	if run_state == null or not run_state.has_method("get_run_pacing_summary") or not run_state.has_method("get_battle_pacing_records"):
		return ["Boss 校验：暂无 Run 数据，先完成一轮实机记录"]

	var pacing: Dictionary = run_state.get_run_pacing_summary()
	var recorded_battles: int = pacing.get("recorded_battle_nodes", 0)
	var total_battles: int = pacing.get("total_battle_nodes", 0)

	if recorded_battles < total_battles:
		return ["Boss 校验：样本未齐 %d/%d，先打到 Boss 结算再判断压力" % [recorded_battles, total_battles]]

	var boss_record := _boss_pacing_record(run_state.get_battle_pacing_records())

	if boss_record.is_empty():
		return ["Boss 校验：完整样本缺少 Boss 记录，先复核路线结算回传"]

	var baseline_boss := _boss_pacing_record(run_baseline().get("battle_records", []))
	var baseline_turns: int = baseline_boss.get("actual_turn_count", 0)
	var baseline_delta: int = boss_record.get("actual_turn_count", 0) - baseline_turns
	var rest_text := "静息调气已生效" if _has_reward_source(run_state, RewardGeneratorScript.REST_FOCUS_SOURCE_ID) else "静息调气未验证"
	var lines: Array = [
		"Boss 校验：%s %d 手，目标 %d-%d，较基准 %s，%s" % [
			boss_record.get("title", "Boss"),
			boss_record.get("actual_turn_count", 0),
			boss_record.get("target_turn_min", 0),
			boss_record.get("target_turn_max", 0),
			_signed_int_text(baseline_delta),
			rest_text,
		],
	]
	var feel_line := _boss_opening_feel_line(run_state)

	if not feel_line.is_empty():
		lines.append(feel_line)

	if run_state.has_method("get_boss_opening_pressure_lines"):
		var pressure_lines: Array = run_state.get_boss_opening_pressure_lines()

		if not pressure_lines.is_empty():
			lines.append("Boss 校验：%s" % String(pressure_lines[0]).trim_prefix("Boss 快照判读："))

	match boss_record.get("actual_pacing_result", ""):
		"over":
			lines.append("Boss 校验：Boss 偏慢，本轮只复核 Boss 上限或休息点体感")
		"under":
			lines.append("Boss 校验：Boss 偏快，先观察岩阵压制是否不足")
		"target":
			lines.append("Boss 校验：Boss 落在目标内，暂不动 Boss 上限")
		_:
			lines.append("Boss 校验：Boss 节奏待判断，先补一次可复盘记录")

	return lines


func get_boss_live_checklist_lines(run_state) -> Array:
	if run_state == null or not run_state.has_method("get_run_pacing_summary") or not run_state.has_method("get_battle_pacing_records"):
		return ["Boss 实机检查：暂无 Run 数据，先推进到休息点并记录 Boss 前构筑"]

	var pacing: Dictionary = run_state.get_run_pacing_summary()
	var recorded_battles: int = pacing.get("recorded_battle_nodes", 0)
	var total_battles: int = pacing.get("total_battle_nodes", 0)
	var boss_record := _boss_pacing_record(run_state.get_battle_pacing_records())
	var lines: Array = []

	if boss_record.is_empty():
		lines.append(_boss_pre_entry_check_line(run_state))
	else:
		lines.append("Boss 实机检查：岩王已记录 %d 手，核对目标 %d-%d 与静息调气体感" % [
			boss_record.get("actual_turn_count", 0),
			boss_record.get("target_turn_min", 0),
			boss_record.get("target_turn_max", 0),
		])
		lines.append(_boss_opening_feel_prompt_line(run_state))

	if recorded_battles < total_battles:
		lines.append("Boss 实机检查：继续打到 Boss 结算，再判断 Boss 上限是否需要单轴调整")
	elif boss_record.is_empty():
		lines.append("Boss 实机检查：完整样本缺少 Boss 记录，先复核路线结算回传")
	else:
		lines.append(_boss_post_entry_check_line(boss_record))

	return lines


func get_editor_run_acceptance_lines(run_state) -> Array:
	if run_state == null or not run_state.has_method("get_run_pacing_summary") or not run_state.has_method("get_battle_pacing_records"):
		return ["编辑器验收：暂无 Run 数据，先从路线图开始完整试玩"]

	var pacing: Dictionary = run_state.get_run_pacing_summary()
	var recorded_battles: int = pacing.get("recorded_battle_nodes", 0)
	var total_battles: int = pacing.get("total_battle_nodes", 0)

	if recorded_battles < total_battles:
		return [
			"编辑器验收：实机样本未齐 %d/%d，继续按路线打到 Boss 结算" % [recorded_battles, total_battles],
			"编辑器验收：Boss 结算后补前 5 手体感，再看快照判读与静息复核",
		]

	if run_state.run_failed:
		return ["编辑器验收：Run 已失败，先记录失败节点、Boss 前资源与重开原因"]

	var boss_record := _boss_pacing_record(run_state.get_battle_pacing_records())

	if boss_record.is_empty():
		return ["编辑器验收：完整样本缺少 Boss 记录，先复核结算回传"]

	var pressure_level := _boss_opening_pressure_level(run_state)
	var pressure_text := _boss_opening_pressure_acceptance_label(pressure_level)
	var feel_label: String = run_state.get_boss_opening_feel_label() if run_state.has_method("get_boss_opening_feel_label") else "未记录"
	var rest_text := "静息调气已生效" if _has_reward_source(run_state, RewardGeneratorScript.REST_FOCUS_SOURCE_ID) else "静息调气未验证"
	var lines: Array = [
		"编辑器验收：完整 Run %d/%d 场，目标内 %d/%d，总 %d 手，%s" % [
			recorded_battles,
			total_battles,
			pacing.get("on_target_count", 0),
			recorded_battles,
			pacing.get("actual_turn_total", 0),
			rest_text,
		],
		"编辑器验收：Boss %d 手，快照%s，体感：%s" % [
			boss_record.get("actual_turn_count", 0),
			pressure_text,
			feel_label,
		],
	]

	if pressure_level == RunStateScript.BOSS_OPENING_PRESSURE_HIGH:
		lines.append("编辑器验收：压力偏高，只做 Boss-only 复核，不动普通战斗")
		return lines

	if run_state.boss_opening_feel.is_empty():
		lines.append("编辑器验收：先点选 Boss 前 5 手体感，本轮暂不关闭结论")
		return lines

	match run_state.boss_opening_feel:
		RunStateScript.BOSS_OPENING_FEEL_STABLE:
			if pressure_level == RunStateScript.BOSS_OPENING_PRESSURE_STABLE and pacing.get("on_target_count", 0) == recorded_battles:
				lines.append("编辑器验收：可作为本轮 Demo 实机验收，保持当前数值")
			else:
				lines.append("编辑器验收：体感更稳但仍需复看一轮 Boss 开局")
		RunStateScript.BOSS_OPENING_FEEL_PRESSURE:
			lines.append("编辑器验收：体感仍压迫，转入 Boss 手感轴复核")
		RunStateScript.BOSS_OPENING_FEEL_UNCLEAR:
			lines.append("编辑器验收：体感不明确，保留记录并补一轮可复盘样本")
		_:
			lines.append("编辑器验收：体感记录异常，先复核按钮写入")

	return lines


func get_editor_next_action_lines(run_state) -> Array:
	if run_state == null or not run_state.has_method("get_current_node"):
		return ["编辑器指引：从路线图开始完整 Run"]

	if run_state.run_failed:
		return ["编辑器指引：记录失败节点、失败前资源和重开原因后开始新 Run"]

	if run_state.run_completed:
		var pressure_level := _boss_opening_pressure_level(run_state)

		if pressure_level == RunStateScript.BOSS_OPENING_PRESSURE_HIGH:
			return ["编辑器指引：本轮先不改普通战斗，下一轮只复核 Boss 开局资源和岩阵压迫"]

		if run_state.boss_opening_feel.is_empty():
			return ["编辑器指引：点击 Boss 前 5 手体感按钮，完成本轮主观记录"]

		match run_state.boss_opening_feel:
			RunStateScript.BOSS_OPENING_FEEL_STABLE:
				return ["编辑器指引：本轮可停手，记录 Demo 验收结论并保持当前数值"]
			RunStateScript.BOSS_OPENING_FEEL_PRESSURE:
				return ["编辑器指引：下一轮只复核 Boss 手感轴，不动普通战斗"]
			RunStateScript.BOSS_OPENING_FEEL_UNCLEAR:
				return ["编辑器指引：保留记录，补一轮可复盘样本"]

	if run_state.has_pending_reward():
		return ["编辑器指引：先领取战利品，再看构筑摘要和下一站目标手数"]

	if run_state.has_pending_node_choice():
		return ["编辑器指引：处理%s选择，记录星砂、奖励和是否拿到静息调气" % _pending_choice_type_label(run_state)]

	var current_node: Dictionary = run_state.get_current_node()
	var title: String = current_node.get("title", "当前节点")

	match current_node.get("type", ""):
		RunStateScript.NODE_BATTLE:
			return ["编辑器指引：进入%s，结束后核对实测手数和奖励选择" % title]
		RunStateScript.NODE_BOSS:
			return ["编辑器指引：进入%s，重点看第 1/3/5 手快照、可用能量和反制点" % title]
		RunStateScript.NODE_EVENT:
			return ["编辑器指引：处理%s，记录星砂变化是否支撑后续商店" % title]
		RunStateScript.NODE_SHOP:
			return ["编辑器指引：处理%s，优先验证星砂能否买到目标奖励" % title]
		RunStateScript.NODE_REST:
			return ["编辑器指引：处理%s，优先选择或记录未选静息调气" % title]
		_:
			return ["编辑器指引：选择当前可进入节点继续完整 Run"]


func get_editor_evidence_checklist_lines(run_state) -> Array:
	if run_state == null or not run_state.has_method("get_run_pacing_summary") or not run_state.has_method("get_battle_pacing_records"):
		return ["编辑器证据：暂无 Run 数据，先开始完整 Run"]

	var pacing: Dictionary = run_state.get_run_pacing_summary()
	var recorded_battles: int = pacing.get("recorded_battle_nodes", 0)
	var total_battles: int = pacing.get("total_battle_nodes", 0)

	if recorded_battles <= 0:
		return ["编辑器证据：样本 0/%d，先完成首战并确认实测手数回传" % total_battles]

	if recorded_battles < total_battles:
		return [
			"编辑器证据：样本 %d/%d，目标内 %d/%d，总 %d 手" % [
				recorded_battles,
				total_battles,
				pacing.get("on_target_count", 0),
				recorded_battles,
				pacing.get("actual_turn_total", 0),
			],
			"编辑器证据：待补 Boss 结算、前 5 手快照和体感按钮",
		]

	if run_state.run_failed:
		return ["编辑器证据：Run 已失败，保留失败节点、失败前资源和重开原因"]

	var boss_record := _boss_pacing_record(run_state.get_battle_pacing_records())

	if boss_record.is_empty():
		return ["编辑器证据：完整样本缺少 Boss 记录，先复核结算回传"]

	var pressure_level := _boss_opening_pressure_level(run_state)
	var pressure_text := _boss_opening_pressure_acceptance_label(pressure_level)
	var rest_text := "静息调气已生效" if _has_reward_source(run_state, RewardGeneratorScript.REST_FOCUS_SOURCE_ID) else "静息调气未验证"
	var feel_label: String = run_state.get_boss_opening_feel_label() if run_state.has_method("get_boss_opening_feel_label") else "未记录"
	var lines: Array = [
		"编辑器证据：样本 %d/%d，目标内 %d/%d，总 %d 手" % [
			recorded_battles,
			total_battles,
			pacing.get("on_target_count", 0),
			recorded_battles,
			pacing.get("actual_turn_total", 0),
		],
		"编辑器证据：Boss %d 手，快照%s，%s，体感：%s" % [
			boss_record.get("actual_turn_count", 0),
			pressure_text,
			rest_text,
			feel_label,
		],
	]

	if pressure_level == RunStateScript.BOSS_OPENING_PRESSURE_HIGH:
		lines.append("编辑器证据：结论只允许 Boss-only 复核")
	elif run_state.boss_opening_feel.is_empty():
		lines.append("编辑器证据：缺少 Boss 前 5 手体感按钮记录")
	elif pressure_level == RunStateScript.BOSS_OPENING_PRESSURE_STABLE and run_state.boss_opening_feel == RunStateScript.BOSS_OPENING_FEEL_STABLE and pacing.get("on_target_count", 0) == recorded_battles:
		lines.append("编辑器证据：可归档 Demo 验收证据")
	else:
		lines.append("编辑器证据：证据未闭合，下一轮按编辑器指引复核")

	return lines


func get_editor_acceptance_note_lines(run_state) -> Array:
	if run_state == null or not run_state.has_method("get_run_pacing_summary") or not run_state.has_method("get_battle_pacing_records"):
		return ["编辑器纪要：未开始，先完成首战记录"]

	var pacing: Dictionary = run_state.get_run_pacing_summary()
	var recorded_battles: int = pacing.get("recorded_battle_nodes", 0)
	var total_battles: int = pacing.get("total_battle_nodes", 0)

	if recorded_battles <= 0:
		return ["编辑器纪要：未开始，先完成首战记录"]

	if recorded_battles < total_battles:
		return ["编辑器纪要：样本 %d/%d，暂不写验收结论" % [recorded_battles, total_battles]]

	if run_state.run_failed:
		return ["编辑器纪要：Run 失败，先记录失败节点与重开原因"]

	var boss_record := _boss_pacing_record(run_state.get_battle_pacing_records())

	if boss_record.is_empty():
		return ["编辑器纪要：完整样本缺 Boss 记录，先复核回传"]

	var pressure_level := _boss_opening_pressure_level(run_state)
	var rest_text := "静息调气已生效" if _has_reward_source(run_state, RewardGeneratorScript.REST_FOCUS_SOURCE_ID) else "静息调气未验证"

	if pressure_level == RunStateScript.BOSS_OPENING_PRESSURE_HIGH:
		return ["编辑器纪要：完整 Run 已齐但 Boss 快照压力偏高，标记 Boss-only 复核"]

	if run_state.boss_opening_feel.is_empty():
		return ["编辑器纪要：完整 Run 已齐，先补 Boss 前 5 手体感按钮"]

	match run_state.boss_opening_feel:
		RunStateScript.BOSS_OPENING_FEEL_STABLE:
			if pressure_level == RunStateScript.BOSS_OPENING_PRESSURE_STABLE and pacing.get("on_target_count", 0) == recorded_battles:
				return ["编辑器纪要：完整 Run 可记为 Demo 验收通过，%s，保持当前数值" % rest_text]
			return ["编辑器纪要：体感更稳但证据未全稳，下一轮只复看 Boss 开局"]
		RunStateScript.BOSS_OPENING_FEEL_PRESSURE:
			return ["编辑器纪要：Boss 前 5 手仍压迫，转入 Boss 手感轴复核"]
		RunStateScript.BOSS_OPENING_FEEL_UNCLEAR:
			return ["编辑器纪要：Boss 体感需再测，保留本轮记录"]
		_:
			return ["编辑器纪要：体感记录异常，先复核按钮写入"]


func get_editor_archive_record_lines(run_state) -> Array:
	if run_state == null or not run_state.has_method("get_run_pacing_summary") or not run_state.has_method("get_battle_pacing_records"):
		return ["编辑器归档：暂无 Run 数据，先从路线图开始完整试玩"]

	var pacing: Dictionary = run_state.get_run_pacing_summary()
	var recorded_battles: int = pacing.get("recorded_battle_nodes", 0)
	var total_battles: int = pacing.get("total_battle_nodes", 0)

	if recorded_battles <= 0:
		return ["编辑器归档：等待首战记录，不创建验收归档"]

	if recorded_battles < total_battles:
		return ["编辑器归档：样本 %d/%d 未齐，只保留过程记录" % [recorded_battles, total_battles]]

	if run_state.run_failed:
		return ["编辑器归档：Run 失败，归档为失败复盘而非 Demo 验收"]

	var boss_record := _boss_pacing_record(run_state.get_battle_pacing_records())

	if boss_record.is_empty():
		return ["编辑器归档：完整样本缺 Boss 记录，暂不归档验收"]

	var pressure_level := _boss_opening_pressure_level(run_state)
	var pressure_text := _boss_opening_pressure_acceptance_label(pressure_level)
	var rest_text := "静息调气已生效" if _has_reward_source(run_state, RewardGeneratorScript.REST_FOCUS_SOURCE_ID) else "静息调气未验证"

	if pressure_level == RunStateScript.BOSS_OPENING_PRESSURE_HIGH:
		return ["编辑器归档：Boss 快照压力偏高，本轮归档为 Boss-only 复核"]

	if run_state.boss_opening_feel.is_empty():
		return ["编辑器归档：缺 Boss 前 5 手体感，暂不归档验收"]

	match run_state.boss_opening_feel:
		RunStateScript.BOSS_OPENING_FEEL_STABLE:
			if pressure_level == RunStateScript.BOSS_OPENING_PRESSURE_STABLE and pacing.get("on_target_count", 0) == recorded_battles:
				return ["编辑器归档：可归档 Demo 验收，目标内 %d/%d，总 %d 手，%s，保持当前数值" % [
					pacing.get("on_target_count", 0),
					recorded_battles,
					pacing.get("actual_turn_total", 0),
					rest_text,
				]]
			return ["编辑器归档：体感更稳但快照%s，归档为 Boss 开局复看" % pressure_text]
		RunStateScript.BOSS_OPENING_FEEL_PRESSURE:
			return ["编辑器归档：Boss 体感仍压迫，归档为 Boss 手感轴复核"]
		RunStateScript.BOSS_OPENING_FEEL_UNCLEAR:
			return ["编辑器归档：Boss 体感需再测，归档为待补样本"]
		_:
			return ["编辑器归档：体感记录异常，先复核按钮写入"]


func get_editor_recap_excerpt_lines(run_state) -> Array:
	if run_state == null or not run_state.has_method("get_run_pacing_summary") or not run_state.has_method("get_battle_pacing_records"):
		return ["编辑器摘录：未开始，从路线图进入首战"]

	var pacing: Dictionary = run_state.get_run_pacing_summary()
	var recorded_battles: int = pacing.get("recorded_battle_nodes", 0)
	var total_battles: int = pacing.get("total_battle_nodes", 0)

	if recorded_battles <= 0:
		return ["编辑器摘录：未开始，首战后核对实测手数回传"]

	if recorded_battles < total_battles:
		return ["编辑器摘录：样本 %d/%d，继续完整 Run，不写验收结论" % [recorded_battles, total_battles]]

	if run_state.run_failed:
		return ["编辑器摘录：Run 失败，记录失败节点、失败前资源和重开原因"]

	var boss_record := _boss_pacing_record(run_state.get_battle_pacing_records())

	if boss_record.is_empty():
		return ["编辑器摘录：完整样本缺 Boss 记录，复核结算回传"]

	var pressure_level := _boss_opening_pressure_level(run_state)
	var pressure_text := _boss_opening_pressure_acceptance_label(pressure_level)
	var rest_text := "静息调气已生效" if _has_reward_source(run_state, RewardGeneratorScript.REST_FOCUS_SOURCE_ID) else "静息调气未验证"
	var feel_label: String = run_state.get_boss_opening_feel_label() if run_state.has_method("get_boss_opening_feel_label") else "未记录"
	var outcome := "证据未闭合"

	if pressure_level == RunStateScript.BOSS_OPENING_PRESSURE_HIGH:
		outcome = "Boss-only 复核"
	elif run_state.boss_opening_feel.is_empty():
		outcome = "待补 Boss 体感"
	else:
		match run_state.boss_opening_feel:
			RunStateScript.BOSS_OPENING_FEEL_STABLE:
				if pressure_level == RunStateScript.BOSS_OPENING_PRESSURE_STABLE and pacing.get("on_target_count", 0) == recorded_battles:
					outcome = "Demo 验收通过"
				else:
					outcome = "Boss 开局复看"
			RunStateScript.BOSS_OPENING_FEEL_PRESSURE:
				outcome = "Boss 手感轴复核"
			RunStateScript.BOSS_OPENING_FEEL_UNCLEAR:
				outcome = "待补可复盘样本"
			_:
				outcome = "体感记录异常"

	return ["编辑器摘录：%s；目标内 %d/%d，总 %d 手；Boss %d 手，快照%s；%s；体感：%s" % [
		outcome,
		pacing.get("on_target_count", 0),
		recorded_battles,
		pacing.get("actual_turn_total", 0),
		boss_record.get("actual_turn_count", 0),
		pressure_text,
		rest_text,
		feel_label,
	]]


func get_editor_closeout_packet_lines(run_state) -> Array:
	if run_state == null or not run_state.has_method("get_run_pacing_summary") or not run_state.has_method("get_battle_pacing_records"):
		return ["编辑器收口包：未开始，先进入首战并保留实测手数"]

	var pacing: Dictionary = run_state.get_run_pacing_summary()
	var recorded_battles: int = pacing.get("recorded_battle_nodes", 0)
	var total_battles: int = pacing.get("total_battle_nodes", 0)

	if recorded_battles <= 0:
		return ["编辑器收口包：等待首战记录；当前不可收口"]

	if recorded_battles < total_battles:
		return ["编辑器收口包：样本 %d/%d 未齐；继续完整 Run，不写最终结论" % [recorded_battles, total_battles]]

	if run_state.run_failed:
		return ["编辑器收口包：失败复盘；记录失败节点、失败前资源和重开原因"]

	var boss_record := _boss_pacing_record(run_state.get_battle_pacing_records())

	if boss_record.is_empty():
		return ["编辑器收口包：缺 Boss 结算；先复核路线回传"]

	var pressure_level := _boss_opening_pressure_level(run_state)
	var pressure_text := _boss_opening_pressure_acceptance_label(pressure_level)
	var rest_text := "静息调气已生效" if _has_reward_source(run_state, RewardGeneratorScript.REST_FOCUS_SOURCE_ID) else "静息调气未验证"
	var feel_label: String = run_state.get_boss_opening_feel_label() if run_state.has_method("get_boss_opening_feel_label") else "未记录"
	var outcome := "证据未闭合"
	var next_action := "按编辑器指引补齐证据"

	if pressure_level == RunStateScript.BOSS_OPENING_PRESSURE_HIGH:
		outcome = "Boss-only 复核"
		next_action = "下一轮只看开局岩阵、能量和反制点"
	elif run_state.boss_opening_feel.is_empty():
		outcome = "待补 Boss 体感"
		next_action = "点选前 5 手体感后再收口"
	else:
		match run_state.boss_opening_feel:
			RunStateScript.BOSS_OPENING_FEEL_STABLE:
				if pressure_level == RunStateScript.BOSS_OPENING_PRESSURE_STABLE and pacing.get("on_target_count", 0) == recorded_battles:
					outcome = "Demo 验收通过"
					next_action = "保持当前数值并归档"
				else:
					outcome = "Boss 开局复看"
					next_action = "下一轮只复看 Boss 开局"
			RunStateScript.BOSS_OPENING_FEEL_PRESSURE:
				outcome = "Boss 手感轴复核"
				next_action = "只复核 Boss 上限、岩阵开局或静息调气体感"
			RunStateScript.BOSS_OPENING_FEEL_UNCLEAR:
				outcome = "待补可复盘样本"
				next_action = "保留记录并补一轮完整样本"
			_:
				outcome = "体感记录异常"
				next_action = "先复核按钮写入"

	return [
		"编辑器收口包：%s；目标内 %d/%d，总 %d 手；Boss %d 手，快照%s，%s，体感：%s" % [
			outcome,
			pacing.get("on_target_count", 0),
			recorded_battles,
			pacing.get("actual_turn_total", 0),
			boss_record.get("actual_turn_count", 0),
			pressure_text,
			rest_text,
			feel_label,
		],
		"编辑器收口包：下一步：%s" % next_action,
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
	var feel_candidate := _candidate_line_for_boss_opening_feel(run_state)
	var pressure_candidate := _candidate_line_for_boss_opening_pressure(run_state)

	if not feel_candidate.is_empty():
		lines.append(feel_candidate)

	if not pressure_candidate.is_empty():
		lines.append(pressure_candidate)

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


func _boss_pacing_record(records: Array) -> Dictionary:
	for record in records:
		if record.get("type", "") == RunStateScript.NODE_BOSS:
			return record

	return {}


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
	var feel_text := _boss_opening_feel_review_suffix(run_state)

	if has_rest_focus and full_sample_ready:
		return "静息调气已验证，复核 Boss 前 5 手是否更稳%s" % feel_text

	if has_rest_focus:
		return "静息调气已取得，需打到 Boss 后验证体感%s" % feel_text

	return "静息调气尚未验证，Boss 前补强结论需保留"


func _boss_pre_entry_check_line(run_state) -> String:
	if _is_rest_step_active(run_state):
		return "Boss 实机检查：当前在休息点，优先确认静息调气 +2 或记录未选原因"

	if _has_reward_source(run_state, RewardGeneratorScript.REST_FOCUS_SOURCE_ID):
		return "Boss 实机检查：静息调气已生效，进 Boss 前记录开局能量、奖励数和星砂"

	return "Boss 实机检查：尚未验证静息调气，进 Boss 前确认是否经过休息点"


func _boss_post_entry_check_line(boss_record: Dictionary) -> String:
	match boss_record.get("actual_pacing_result", ""):
		"over":
			return "Boss 实机检查：Boss 偏慢，只复核 Boss 上限或休息点体感"
		"under":
			return "Boss 实机检查：Boss 偏快，先记录岩阵压制是否不足"
		"target":
			return "Boss 实机检查：Boss 目标内，保留 Boss 上限并记录前 5 手体感"
		_:
			return "Boss 实机检查：Boss 结果待判断，补一次可复盘记录"


func _boss_opening_feel_prompt_line(run_state) -> String:
	if run_state == null or not run_state.has_method("get_boss_opening_feel_label"):
		return "Boss 实机检查：结算后记录前 5 手体感"

	var feel_label: String = run_state.get_boss_opening_feel_label()

	if run_state.boss_opening_feel.is_empty():
		return "Boss 实机检查：请记录前 5 手体感：更稳 / 仍压迫 / 需再测"

	return "Boss 实机检查：前 5 手体感已记录为：%s" % feel_label


func _boss_opening_feel_line(run_state) -> String:
	if run_state == null or not run_state.has_method("get_boss_opening_feel_label") or run_state.boss_opening_feel.is_empty():
		return "Boss 校验：前 5 手体感未记录，先补一次主观结论"

	match run_state.boss_opening_feel:
		RunStateScript.BOSS_OPENING_FEEL_STABLE:
			return "Boss 校验：前 5 手记录为更稳，静息调气补强可保留"
		RunStateScript.BOSS_OPENING_FEEL_PRESSURE:
			return "Boss 校验：前 5 手仍有压迫，下一轮优先复核 Boss 上限或开局资源"
		RunStateScript.BOSS_OPENING_FEEL_UNCLEAR:
			return "Boss 校验：前 5 手体感暂不明确，先补一轮可复盘样本"
		_:
			return ""


func _boss_opening_feel_review_suffix(run_state) -> String:
	if run_state == null or not run_state.has_method("get_boss_opening_feel_label") or run_state.boss_opening_feel.is_empty():
		return "，前 5 手体感待记录"

	return "，前 5 手：%s" % run_state.get_boss_opening_feel_label()


func _is_rest_step_active(run_state) -> bool:
	if run_state == null:
		return false

	if run_state.has_method("has_pending_node_choice") and run_state.has_pending_node_choice():
		var choice_index: int = run_state.pending_choice_node_index

		if choice_index >= 0 and choice_index < run_state.nodes.size():
			return run_state.nodes[choice_index].get("type", "") == RunStateScript.NODE_REST

	var current_node: Dictionary = run_state.get_current_node() if run_state.has_method("get_current_node") else {}
	return current_node.get("type", "") == RunStateScript.NODE_REST


func _pending_choice_type_label(run_state) -> String:
	var choice_index: int = run_state.pending_choice_node_index

	if choice_index < 0 or choice_index >= run_state.nodes.size():
		return "路线"

	return _snapshot_node_type_label(run_state.nodes[choice_index].get("type", ""))


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


func _candidate_line_for_boss_opening_feel(run_state) -> String:
	if run_state == null or not run_state.has_method("get_boss_opening_feel_label"):
		return ""

	match run_state.boss_opening_feel:
		RunStateScript.BOSS_OPENING_FEEL_PRESSURE:
			return "单轴候选：Boss 手感轴，前 5 手仍压迫；只复核 Boss 上限、岩阵开局或静息调气体感"
		RunStateScript.BOSS_OPENING_FEEL_UNCLEAR:
			return "单轴候选：Boss 体感轴，记录不明确；先补一轮可复盘样本"
		_:
			return ""


func _candidate_line_for_boss_opening_pressure(run_state) -> String:
	var pressure_level := _boss_opening_pressure_level(run_state)

	match pressure_level:
		RunStateScript.BOSS_OPENING_PRESSURE_HIGH:
			return "单轴候选：Boss 快照轴，前 5 手压力偏高；只复核开局岩阵、可用能量和反制点"
		RunStateScript.BOSS_OPENING_PRESSURE_REVIEW:
			return "单轴候选：Boss 快照轴，前 5 手需复看；先补体感记录再决定是否动 Boss 上限"
		_:
			return ""


func _boss_opening_pressure_level(run_state) -> String:
	if run_state == null or not run_state.has_method("get_boss_opening_pressure_level"):
		return ""

	return run_state.get_boss_opening_pressure_level()


func _boss_opening_pressure_acceptance_label(pressure_level: String) -> String:
	match pressure_level:
		RunStateScript.BOSS_OPENING_PRESSURE_HIGH:
			return "压力偏高"
		RunStateScript.BOSS_OPENING_PRESSURE_REVIEW:
			return "需复看"
		RunStateScript.BOSS_OPENING_PRESSURE_STABLE:
			return "暂稳"
		_:
			return "未记录"


func _boss_opening_evidence_suffix(run_state) -> String:
	if run_state == null:
		return ""

	var parts: Array = []

	if run_state.has_method("get_boss_opening_feel_label") and not run_state.boss_opening_feel.is_empty():
		parts.append("Boss 前 5 手：%s" % run_state.get_boss_opening_feel_label())

	var pressure_level := _boss_opening_pressure_level(run_state)

	match pressure_level:
		RunStateScript.BOSS_OPENING_PRESSURE_HIGH:
			parts.append("快照压力偏高")
		RunStateScript.BOSS_OPENING_PRESSURE_REVIEW:
			parts.append("快照需复看")
		RunStateScript.BOSS_OPENING_PRESSURE_STABLE:
			parts.append("快照暂稳")

	if parts.is_empty():
		return ""

	return "；%s" % "；".join(parts)


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
