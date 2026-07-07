class_name RewardGenerator
extends RefCounted

const EFFECT_ENERGY_MAX := "energy_max"
const EFFECT_STARTING_ENERGY := "starting_energy"
const EFFECT_EXTRA_SPIRIT_CELLS := "extra_spirit_cells"
const EFFECT_ROCK_BREAK_REFUND := "rock_break_refund"
const EFFECT_SEAL_REFUND := "seal_refund"
const CHOICE_REWARD := "reward"
const CHOICE_COINS := "coins"
const CHOICE_SKIP := "skip"
const NODE_EVENT := "event"
const NODE_SHOP := "shop"
const NODE_REST := "rest"

const REWARD_POOL := [
	{
		"id": "deep_breath",
		"title": "灵息深蓄",
		"description": "后续战斗的己方能量上限 +1。",
		"effect": EFFECT_ENERGY_MAX,
		"amount": 1,
	},
	{
		"id": "opening_spark",
		"title": "起手星火",
		"description": "后续战斗开局额外获得 2 点能量。",
		"effect": EFFECT_STARTING_ENERGY,
		"amount": 2,
	},
	{
		"id": "spirit_trace",
		"title": "灵脉拓印",
		"description": "后续战斗额外生成 2 个灵脉格。",
		"effect": EFFECT_EXTRA_SPIRIT_CELLS,
		"amount": 2,
	},
	{
		"id": "rock_echo",
		"title": "碎岩回响",
		"description": "每场战斗第一次施放碎岩后返还 1 点能量。",
		"effect": EFFECT_ROCK_BREAK_REFUND,
		"amount": 1,
	},
	{
		"id": "seal_channel",
		"title": "封手归流",
		"description": "每场战斗第一次施放封手后返还 1 点能量。",
		"effect": EFFECT_SEAL_REFUND,
		"amount": 1,
	},
]


func generate_options(run_state, node: Dictionary) -> Array:
	var options: Array = []
	var node_index: int = node.get("index", 0)
	var start_index: int = (node_index * 2 + run_state.rewards.size()) % REWARD_POOL.size()

	for offset in range(3):
		var template: Dictionary = REWARD_POOL[(start_index + offset) % REWARD_POOL.size()]
		var reward := template.duplicate(true)
		reward["id"] = "%s_%d_%d" % [template.get("id", "reward"), node_index, offset]
		options.append(reward)

	return options


func generate_node_choices(run_state, node: Dictionary) -> Array:
	match node.get("type", ""):
		NODE_EVENT:
			return _generate_event_choices(run_state, node)
		NODE_SHOP:
			return _generate_shop_choices(run_state, node)
		NODE_REST:
			return _generate_rest_choices(node)
		_:
			return []


func _generate_event_choices(run_state, node: Dictionary) -> Array:
	var node_index: int = node.get("index", 0)
	var reward_template: Dictionary = REWARD_POOL[(node_index + run_state.rewards.size()) % REWARD_POOL.size()]
	var reward := reward_template.duplicate(true)
	reward["id"] = "%s_event_%d" % [reward_template.get("id", "reward"), node_index]
	reward["choice_type"] = CHOICE_REWARD

	return [
		{
			"id": "event_starsand_%d" % node_index,
			"title": "收拢星砂",
			"description": "获得 2 枚星砂，可在商店购买棋印。",
			"choice_type": CHOICE_COINS,
			"amount": 2,
		},
		reward,
		{
			"id": "event_skip_%d" % node_index,
			"title": "谨慎离开",
			"description": "不拿取残谱，直接继续前进。",
			"choice_type": CHOICE_SKIP,
		},
	]


func _generate_shop_choices(run_state, node: Dictionary) -> Array:
	var options: Array = []
	var node_index: int = node.get("index", 0)
	var start_index: int = (node_index + run_state.rewards.size() + run_state.coins) % REWARD_POOL.size()

	for offset in range(2):
		var template: Dictionary = REWARD_POOL[(start_index + offset) % REWARD_POOL.size()]
		var reward := template.duplicate(true)
		reward["id"] = "%s_shop_%d_%d" % [template.get("id", "reward"), node_index, offset]
		reward["description"] = "%s 花费 2 枚星砂。" % template.get("description", "")
		reward["choice_type"] = CHOICE_REWARD
		reward["cost"] = 2
		options.append(reward)

	options.append({
		"id": "shop_leave_%d" % node_index,
		"title": "暂不购买",
		"description": "保留星砂，直接离开商店。",
		"choice_type": CHOICE_SKIP,
	})
	return options


func _generate_rest_choices(node: Dictionary) -> Array:
	var node_index: int = node.get("index", 0)

	return [
		{
			"id": "rest_focus_%d" % node_index,
			"title": "静息调气",
			"description": "后续战斗开局额外获得 1 点能量。",
			"choice_type": CHOICE_REWARD,
			"effect": EFFECT_STARTING_ENERGY,
			"amount": 1,
		},
		{
			"id": "rest_vein_%d" % node_index,
			"title": "描摹灵脉",
			"description": "后续战斗额外生成 1 个灵脉格。",
			"choice_type": CHOICE_REWARD,
			"effect": EFFECT_EXTRA_SPIRIT_CELLS,
			"amount": 1,
		},
		{
			"id": "rest_starsand_%d" % node_index,
			"title": "拾取残砂",
			"description": "获得 1 枚星砂。",
			"choice_type": CHOICE_COINS,
			"amount": 1,
		},
	]
