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


func resolve_current_node(victory: bool, reward_options: Array = []) -> void:
	if current_index < 0 or current_index >= nodes.size():
		return

	pending_rewards.clear()
	pending_reward_node_index = -1
	pending_node_choices.clear()
	pending_choice_node_index = -1

	if not victory:
		nodes[current_index]["status"] = STATUS_FAILED
		run_failed = true
		return

	nodes[current_index]["status"] = STATUS_COMPLETED

	if nodes[current_index].get("type", "") == NODE_BOSS:
		run_completed = true
		return

	if not reward_options.is_empty():
		pending_rewards = reward_options.duplicate(true)
		pending_reward_node_index = current_index
		return

	_advance_after_completed_node()


func claim_reward(reward_id: String) -> bool:
	if not has_pending_reward():
		return false

	for reward in pending_rewards:
		if reward.get("id", "") != reward_id:
			continue

		rewards.append(reward.duplicate(true))
		pending_rewards.clear()
		pending_reward_node_index = -1
		_advance_after_completed_node()
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

		coins -= cost
		_apply_node_choice(choice)
		nodes[pending_choice_node_index]["status"] = STATUS_COMPLETED
		pending_node_choices.clear()
		pending_choice_node_index = -1
		_advance_after_completed_node()
		return true

	return false


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
			if not choice.get("effect", "").is_empty():
				rewards.append(choice.duplicate(true))
