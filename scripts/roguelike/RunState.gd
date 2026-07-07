class_name RunState
extends RefCounted

const STATUS_LOCKED := "locked"
const STATUS_AVAILABLE := "available"
const STATUS_COMPLETED := "completed"
const STATUS_FAILED := "failed"
const NODE_START := "start"
const NODE_BATTLE := "battle"
const NODE_BOSS := "boss"

var nodes: Array = []
var current_index := 0
var run_completed := false
var run_failed := false


func _init(route_nodes: Array = []) -> void:
	if not route_nodes.is_empty():
		setup(route_nodes)


func setup(route_nodes: Array) -> void:
	nodes.clear()

	for node in route_nodes:
		nodes.append(node.duplicate(true))

	current_index = 0
	run_completed = false
	run_failed = false

	if nodes.is_empty():
		return

	nodes[0]["status"] = STATUS_COMPLETED
	current_index = _find_next_playable_index(0)

	if current_index != -1:
		nodes[current_index]["status"] = STATUS_AVAILABLE


func can_enter_node(index: int) -> bool:
	if run_completed or run_failed:
		return false

	if index < 0 or index >= nodes.size():
		return false

	var node: Dictionary = nodes[index]
	var node_type: String = node.get("type", "")
	return index == current_index and node.get("status", STATUS_LOCKED) == STATUS_AVAILABLE and node_type != NODE_START


func get_current_node() -> Dictionary:
	if current_index < 0 or current_index >= nodes.size():
		return {}

	return nodes[current_index]


func resolve_current_node(victory: bool) -> void:
	if current_index < 0 or current_index >= nodes.size():
		return

	if not victory:
		nodes[current_index]["status"] = STATUS_FAILED
		run_failed = true
		return

	nodes[current_index]["status"] = STATUS_COMPLETED

	if nodes[current_index].get("type", "") == NODE_BOSS:
		run_completed = true
		return

	var next_index := _find_next_playable_index(current_index)

	if next_index == -1:
		run_completed = true
		return

	current_index = next_index
	nodes[current_index]["status"] = STATUS_AVAILABLE


func to_dict() -> Dictionary:
	return {
		"nodes": nodes.duplicate(true),
		"current_index": current_index,
		"run_completed": run_completed,
		"run_failed": run_failed,
	}


func load_from_dict(data: Dictionary) -> void:
	nodes = data.get("nodes", []).duplicate(true)
	current_index = data.get("current_index", 0)
	run_completed = data.get("run_completed", false)
	run_failed = data.get("run_failed", false)


func _find_next_playable_index(start_index: int) -> int:
	for index in range(start_index + 1, nodes.size()):
		var node_type: String = nodes[index].get("type", "")

		if node_type == NODE_BATTLE or node_type == NODE_BOSS:
			return index

	return -1
