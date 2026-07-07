class_name RewardGenerator
extends RefCounted

const EFFECT_ENERGY_MAX := "energy_max"
const EFFECT_STARTING_ENERGY := "starting_energy"
const EFFECT_EXTRA_SPIRIT_CELLS := "extra_spirit_cells"
const EFFECT_ROCK_BREAK_REFUND := "rock_break_refund"
const EFFECT_SEAL_REFUND := "seal_refund"

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
