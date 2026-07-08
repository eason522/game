class_name RunState
extends RefCounted

const STATUS_LOCKED := "locked"
const STATUS_AVAILABLE := "available"
const STATUS_COMPLETED := "completed"
const STATUS_FAILED := "failed"
const NODE_START := "start"
const NODE_BATTLE := "battle"
const NODE_EVENT := "event"
const NODE_SHOP := "shop"
const NODE_REST := "rest"
const NODE_BOSS := "boss"

var nodes: Array = []
var rewards: Array = []
var pending_rewards: Array = []
var pending_node_choices: Array = []
var current_index := 0
var pending_reward_node_index := -1
var pending_choice_node_index := -1
var run_completed := false
var run_failed := false
var coins := 2
var last_feedback := ""
var last_feedback_kind := ""


func _init(route_nodes: Array = []) -> void:
	if not route_nodes.is_empty():
		setup(route_nodes)


func setup(route_nodes: Array) -> void:
	nodes.clear()

	for node in route_nodes:
		nodes.append(node.duplicate(true))

	rewards.clear()
	pending_rewards.clear()
	pending_node_choices.clear()
	current_index = 0
	pending_reward_node_index = -1
	pending_choice_node_index = -1
	run_completed = false
	run_failed = false
	coins = 2
	last_feedback = "新的试炼已展开。"
	last_feedback_kind = "run_start"

	if nodes.is_empty():
		return

	nodes[0]["status"] = STATUS_COMPLETED
	current_index = _find_next_playable_index(0)

	if current_index != -1:
		nodes[current_index]["status"] = STATUS_AVAILABLE


func can_enter_node(index: int) -> bool:
	if run_completed or run_failed:
		return false

	if has_pending_reward() or has_pending_node_choice() or index < 0 or index >= nodes.size():
		return false

	var node: Dictionary = nodes[index]
	var node_type: String = node.get("type", "")
	return index == current_index and node.get("status", STATUS_LOCKED) == STATUS_AVAILABLE and node_type != NODE_START


func get_current_node() -> Dictionary:
	if current_index < 0 or current_index >= nodes.size():
		return {}

	return nodes[current_index]


func resolve_current_node(victory: bool, reward_options: Array = [], actual_turn_count: int = 0) -> void:
	if current_index < 0 or current_index >= nodes.size():
		return

	pending_rewards.clear()
	pending_reward_node_index = -1
	pending_node_choices.clear()
	pending_choice_node_index = -1
	_record_battle_pacing(current_index, actual_turn_count)
	var pacing_feedback := _format_battle_pacing_feedback(nodes[current_index])

	if not victory:
		nodes[current_index]["status"] = STATUS_FAILED
		run_failed = true
		last_feedback = "%s 失利：本轮 Run 已锁定。%s" % [nodes[current_index].get("title", "战斗"), pacing_feedback]
		last_feedback_kind = "defeat"
		return

	nodes[current_index]["status"] = STATUS_COMPLETED

	if nodes[current_index].get("type", "") == NODE_BOSS:
		run_completed = true
		last_feedback = "%s 胜利：岩王之局告破。%s" % [nodes[current_index].get("title", "Boss"), pacing_feedback]
		last_feedback_kind = "complete"
		return

	if not reward_options.is_empty():
		pending_rewards = reward_options.duplicate(true)
		pending_reward_node_index = current_index
		last_feedback = "%s 胜利：选择一个战利品后继续前进。%s" % [nodes[current_index].get("title", "战斗"), pacing_feedback]
		last_feedback_kind = "victory"
		return

	var completed_title: String = nodes[current_index].get("title", "路线节点")
	_advance_after_completed_node()
	last_feedback = "%s 完成。%s" % [completed_title, _current_progress_feedback()]
	last_feedback_kind = "progress"


func claim_reward(reward_id: String) -> bool:
	if not has_pending_reward():
		return false

	for reward in pending_rewards:
		if reward.get("id", "") != reward_id:
			continue

		if not can_add_reward(reward):
			return false

		rewards.append(reward.duplicate(true))
		pending_rewards.clear()
		pending_reward_node_index = -1
		_advance_after_completed_node()
		last_feedback = "获得奖励：%s。%s" % [reward.get("title", "未知奖励"), _current_progress_feedback()]
		last_feedback_kind = "reward_claimed"
		return true

	return false


func open_node_choices(choice_options: Array) -> bool:
	if current_index < 0 or current_index >= nodes.size():
		return false

	if has_pending_reward() or has_pending_node_choice():
		return false

	var node: Dictionary = nodes[current_index]
	var node_type: String = node.get("type", "")

	if node_type == NODE_START or node_type == NODE_BATTLE or node_type == NODE_BOSS:
		return false

	pending_node_choices = choice_options.duplicate(true)
	pending_choice_node_index = current_index
	last_feedback = "%s：选择一项处理方式后继续前进。" % node.get("title", "路线节点")
	last_feedback_kind = "choice_pending"
	return true


func claim_node_choice(choice_id: String) -> bool:
	if not has_pending_node_choice():
		return false

	for choice in pending_node_choices:
		if choice.get("id", "") != choice_id:
			continue

		var cost: int = choice.get("cost", 0)

		if coins < cost:
			return false

		if _is_reward_choice(choice) and not can_add_reward(choice):
			return false

		coins -= cost
		_apply_node_choice(choice)
		nodes[pending_choice_node_index]["status"] = STATUS_COMPLETED
		var completed_title: String = nodes[pending_choice_node_index].get("title", "路线节点")
		pending_node_choices.clear()
		pending_choice_node_index = -1
		_advance_after_completed_node()
		last_feedback = "%s 完成：%s。%s" % [completed_title, choice.get("title", "路线选择"), _current_progress_feedback()]
		last_feedback_kind = "choice_claimed"
		return true

	return false


func can_claim_node_choice(choice_id: String) -> bool:
	if not has_pending_node_choice():
		return false

	for choice in pending_node_choices:
		if choice.get("id", "") != choice_id:
			continue

		if coins < choice.get("cost", 0):
			return false

		if _is_reward_choice(choice):
			return can_add_reward(choice)

		return true

	return false


func can_add_reward(reward: Dictionary) -> bool:
	var source_id := _reward_source_id(reward)
	var max_stack: int = reward.get("max_stack", 0)

	if max_stack > 0 and _count_rewards_from_source(source_id) >= max_stack:
		return false

	var exclusive_group: String = reward.get("exclusive_group", "")

	if exclusive_group.is_empty():
		return true

	for owned_reward in rewards:
		if owned_reward.get("exclusive_group", "") != exclusive_group:
			continue

		if _reward_source_id(owned_reward) != source_id:
			return false

	return true


func has_pending_reward() -> bool:
	return not pending_rewards.is_empty()


func has_pending_node_choice() -> bool:
	return not pending_node_choices.is_empty()


func get_battle_modifiers() -> Dictionary:
	var modifiers := {
		"energy_max_bonus": 0,
		"starting_energy_bonus": 0,
		"extra_spirit_cells": 0,
		"rock_break_refund_per_battle": 0,
		"seal_refund_per_battle": 0,
	}

	for reward in rewards:
		var amount: int = reward.get("amount", 0)

		match reward.get("effect", ""):
			"energy_max":
				modifiers["energy_max_bonus"] += amount
			"starting_energy":
				modifiers["starting_energy_bonus"] += amount
			"extra_spirit_cells":
				modifiers["extra_spirit_cells"] += amount
			"rock_break_refund":
				modifiers["rock_break_refund_per_battle"] += amount
			"seal_refund":
				modifiers["seal_refund_per_battle"] += amount

	return modifiers


func get_reward_titles() -> Array:
	var titles: Array = []

	for reward in rewards:
		titles.append(reward.get("title", "未知奖励"))

	return titles


func get_choice_titles() -> Array:
	var titles: Array = []

	for choice in pending_node_choices:
		titles.append(choice.get("title", "未知选项"))

	return titles


func get_run_pacing_summary() -> Dictionary:
	var summary := {
		"total_battle_nodes": 0,
		"completed_battle_nodes": 0,
		"remaining_battle_nodes": 0,
		"total_turn_min": 0,
		"total_turn_max": 0,
		"remaining_turn_min": 0,
		"remaining_turn_max": 0,
		"current_target_turn_min": 0,
		"current_target_turn_max": 0,
		"recorded_battle_nodes": 0,
		"actual_turn_total": 0,
		"actual_turn_average": 0,
		"under_target_count": 0,
		"on_target_count": 0,
		"over_target_count": 0,
	}

	for node in nodes:
		var node_type: String = node.get("type", "")

		if node_type != NODE_BATTLE and node_type != NODE_BOSS:
			continue

		var target_min: int = node.get("target_turn_min", 0)
		var target_max: int = node.get("target_turn_max", 0)
		summary["total_battle_nodes"] += 1
		summary["total_turn_min"] += target_min
		summary["total_turn_max"] += target_max
		var actual_turn_count: int = node.get("actual_turn_count", 0)

		if actual_turn_count > 0:
			summary["recorded_battle_nodes"] += 1
			summary["actual_turn_total"] += actual_turn_count

			match node.get("actual_pacing_result", ""):
				"under":
					summary["under_target_count"] += 1
				"over":
					summary["over_target_count"] += 1
				"target":
					summary["on_target_count"] += 1

		if node.get("status", STATUS_LOCKED) == STATUS_COMPLETED:
			summary["completed_battle_nodes"] += 1
			continue

		summary["remaining_battle_nodes"] += 1
		summary["remaining_turn_min"] += target_min
		summary["remaining_turn_max"] += target_max

		if node.get("index", -1) == current_index:
			summary["current_target_turn_min"] = target_min
			summary["current_target_turn_max"] = target_max

	if summary["recorded_battle_nodes"] > 0:
		summary["actual_turn_average"] = int(round(float(summary["actual_turn_total"]) / float(summary["recorded_battle_nodes"])))

	return summary


func get_battle_pacing_records() -> Array:
	var records: Array = []

	for node in nodes:
		var node_type: String = node.get("type", "")

		if node_type != NODE_BATTLE and node_type != NODE_BOSS:
			continue

		var actual_turn_count: int = node.get("actual_turn_count", 0)

		if actual_turn_count <= 0:
			continue

		records.append({
			"node_index": node.get("index", -1),
			"title": node.get("title", ""),
			"type": node_type,
			"target_turn_min": node.get("target_turn_min", 0),
			"target_turn_max": node.get("target_turn_max", 0),
			"actual_turn_count": actual_turn_count,
			"actual_pacing_result": node.get("actual_pacing_result", ""),
			"actual_pacing_delta": node.get("actual_pacing_delta", 0),
		})

	return records


func _record_battle_pacing(node_index: int, actual_turn_count: int) -> void:
	if actual_turn_count <= 0 or node_index < 0 or node_index >= nodes.size():
		return

	var node: Dictionary = nodes[node_index]
	var node_type: String = node.get("type", "")

	if node_type != NODE_BATTLE and node_type != NODE_BOSS:
		return

	nodes[node_index]["actual_turn_count"] = actual_turn_count
	nodes[node_index]["actual_pacing_result"] = _classify_battle_pacing(node, actual_turn_count)
	nodes[node_index]["actual_pacing_delta"] = _battle_pacing_delta(node, actual_turn_count)


func _classify_battle_pacing(node: Dictionary, actual_turn_count: int) -> String:
	var target_min: int = node.get("target_turn_min", 0)
	var target_max: int = node.get("target_turn_max", 0)

	if target_min > 0 and actual_turn_count < target_min:
		return "under"

	if target_max > 0 and actual_turn_count > target_max:
		return "over"

	if target_min > 0 and target_max > 0:
		return "target"

	return "unknown"


func _battle_pacing_delta(node: Dictionary, actual_turn_count: int) -> int:
	var target_min: int = node.get("target_turn_min", 0)
	var target_max: int = node.get("target_turn_max", 0)

	if target_min > 0 and actual_turn_count < target_min:
		return actual_turn_count - target_min

	if target_max > 0 and actual_turn_count > target_max:
		return actual_turn_count - target_max

	return 0


func _format_battle_pacing_feedback(node: Dictionary) -> String:
	var actual_turn_count: int = node.get("actual_turn_count", 0)

	if actual_turn_count <= 0:
		return ""

	var target_min: int = node.get("target_turn_min", 0)
	var target_max: int = node.get("target_turn_max", 0)
	var result_label := _battle_pacing_label(node.get("actual_pacing_result", ""))

	if target_min > 0 and target_max > 0:
		return "本场 %d 手，目标 %d-%d 手（%s）。" % [actual_turn_count, target_min, target_max, result_label]

	return "本场 %d 手（%s）。" % [actual_turn_count, result_label]


func _battle_pacing_label(result: String) -> String:
	match result:
		"under":
			return "偏快"
		"over":
			return "偏慢"
		"target":
			return "目标内"
		_:
			return "待判断"


func _advance_after_completed_node() -> void:
	var next_index := _find_next_playable_index(current_index)

	if next_index == -1:
		run_completed = true
		return

	current_index = next_index
	nodes[current_index]["status"] = STATUS_AVAILABLE


func to_dict() -> Dictionary:
	return {
		"nodes": nodes.duplicate(true),
		"rewards": rewards.duplicate(true),
		"pending_rewards": pending_rewards.duplicate(true),
		"pending_node_choices": pending_node_choices.duplicate(true),
		"current_index": current_index,
		"pending_reward_node_index": pending_reward_node_index,
		"pending_choice_node_index": pending_choice_node_index,
		"run_completed": run_completed,
		"run_failed": run_failed,
		"coins": coins,
		"last_feedback": last_feedback,
		"last_feedback_kind": last_feedback_kind,
	}


func load_from_dict(data: Dictionary) -> void:
	nodes = data.get("nodes", []).duplicate(true)
	rewards = data.get("rewards", []).duplicate(true)
	pending_rewards = data.get("pending_rewards", []).duplicate(true)
	pending_node_choices = data.get("pending_node_choices", []).duplicate(true)
	current_index = data.get("current_index", 0)
	pending_reward_node_index = data.get("pending_reward_node_index", -1)
	pending_choice_node_index = data.get("pending_choice_node_index", -1)
	run_completed = data.get("run_completed", false)
	run_failed = data.get("run_failed", false)
	coins = data.get("coins", 2)
	last_feedback = data.get("last_feedback", "")
	last_feedback_kind = data.get("last_feedback_kind", "")


func _current_progress_feedback() -> String:
	if run_completed:
		return "本轮 Run 已通关。"

	if run_failed:
		return "本轮 Run 已失败。"

	var current := get_current_node()

	if current.is_empty():
		return "没有新的路线节点。"

	return "下一站：%s。" % current.get("title", "未知节点")


func _find_next_playable_index(start_index: int) -> int:
	for index in range(start_index + 1, nodes.size()):
		var node_type: String = nodes[index].get("type", "")

		if node_type != NODE_START:
			return index

	return -1


func _apply_node_choice(choice: Dictionary) -> void:
	match choice.get("choice_type", ""):
		"coins":
			coins += choice.get("amount", 0)
		"skip":
			return
		_:
			if _is_reward_choice(choice):
				rewards.append(choice.duplicate(true))


func _is_reward_choice(choice: Dictionary) -> bool:
	return choice.get("choice_type", "") == "reward" or not choice.get("effect", "").is_empty()


func _count_rewards_from_source(source_id: String) -> int:
	var count := 0

	for reward in rewards:
		if _reward_source_id(reward) == source_id:
			count += 1

	return count


func _reward_source_id(reward: Dictionary) -> String:
	return reward.get("source_id", reward.get("id", ""))
