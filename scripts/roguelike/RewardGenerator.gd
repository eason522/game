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
const RARITY_COMMON := "common"
const RARITY_UNCOMMON := "uncommon"
const RARITY_RARE := "rare"

const RARITY_LABELS := {
	RARITY_COMMON: "普通",
	RARITY_UNCOMMON: "稀有",
	RARITY_RARE: "史诗",
}

const RARITY_PRICES := {
	RARITY_COMMON: 2,
	RARITY_UNCOMMON: 3,
	RARITY_RARE: 5,
}

const REST_FOCUS_SOURCE_ID := "rest_focus"
const REST_FOCUS_STARTING_ENERGY_BONUS := 2

const EXCLUSIVE_GROUP_LABELS := {
	"skill_refund": "术法返能",
	"energy_core": "开局核心",
}

const REWARD_POOL := [
	{
		"id": "deep_breath",
		"title": "灵息深蓄",
		"description": "后续战斗的己方能量上限 +1。",
		"effect": EFFECT_ENERGY_MAX,
		"amount": 1,
		"rarity": RARITY_COMMON,
		"max_stack": 3,
	},
	{
		"id": "opening_spark",
		"title": "起手星火",
		"description": "后续战斗开局额外获得 2 点能量。",
		"effect": EFFECT_STARTING_ENERGY,
		"amount": 2,
		"rarity": RARITY_COMMON,
		"max_stack": 2,
	},
	{
		"id": "spirit_trace",
		"title": "灵脉拓印",
		"description": "后续战斗额外生成 2 个灵脉格。",
		"effect": EFFECT_EXTRA_SPIRIT_CELLS,
		"amount": 2,
		"rarity": RARITY_COMMON,
		"max_stack": 2,
	},
	{
		"id": "rock_echo",
		"title": "碎岩回响",
		"description": "每场战斗第一次施放碎岩后返还 1 点能量。",
		"effect": EFFECT_ROCK_BREAK_REFUND,
		"amount": 1,
		"rarity": RARITY_UNCOMMON,
		"max_stack": 1,
		"exclusive_group": "skill_refund",
	},
	{
		"id": "seal_channel",
		"title": "封手归流",
		"description": "每场战斗第一次施放封手后返还 1 点能量。",
		"effect": EFFECT_SEAL_REFUND,
		"amount": 1,
		"rarity": RARITY_UNCOMMON,
		"max_stack": 1,
		"exclusive_group": "skill_refund",
	},
	{
		"id": "jade_breath",
		"title": "玉府开息",
		"description": "后续战斗的己方能量上限 +2。",
		"effect": EFFECT_ENERGY_MAX,
		"amount": 2,
		"rarity": RARITY_RARE,
		"max_stack": 1,
		"exclusive_group": "energy_core",
	},
	{
		"id": "star_origin",
		"title": "星源先兆",
		"description": "后续战斗开局额外获得 3 点能量。",
		"effect": EFFECT_STARTING_ENERGY,
		"amount": 3,
		"rarity": RARITY_RARE,
		"max_stack": 1,
		"exclusive_group": "energy_core",
	},
]


func generate_options(run_state, node: Dictionary) -> Array:
	var options: Array = []
	var node_index: int = node.get("index", 0)
	var start_index: int = (node_index * 2 + run_state.rewards.size()) % REWARD_POOL.size()

	for offset in range(3):
		var template := _find_available_template(run_state, start_index + offset, offset)
		var reward := _make_reward(template, "%d_%d" % [node_index, offset])
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
	var reward_template := _find_available_template(run_state, node_index + run_state.rewards.size(), 1)
	var reward := _make_reward(reward_template, "event_%d" % node_index)
	reward["choice_type"] = CHOICE_REWARD
	var risky_template := _find_available_template(run_state, node_index + run_state.rewards.size() + 4, 2)
	var risky_reward := _make_reward(risky_template, "risky_event_%d" % node_index)
	risky_reward["choice_type"] = CHOICE_REWARD
	risky_reward["cost"] = 1
	risky_reward["title"] = "冒险破译：%s" % risky_reward.get("title", "残谱")
	risky_reward["description"] = "%s 需要消耗 1 枚星砂，换取更强构筑线索。" % risky_reward.get("description", "")

	return [
		{
			"id": "event_starsand_%d" % node_index,
			"title": "收拢星砂",
			"description": "获得 2 枚星砂，可在商店购买棋印。",
			"choice_type": CHOICE_COINS,
			"amount": 2,
		},
		risky_reward,
		{
			"id": "event_safe_%d" % node_index,
			"title": "稳读残谱：%s" % reward.get("title", "残谱奖励"),
			"description": "%s 不消耗星砂，但收益更稳。" % reward.get("description", ""),
			"choice_type": CHOICE_REWARD,
			"effect": reward.get("effect", ""),
			"amount": reward.get("amount", 0),
			"source_id": reward.get("source_id", reward.get("id", "")),
			"rarity": reward.get("rarity", RARITY_COMMON),
			"max_stack": reward.get("max_stack", 0),
			"exclusive_group": reward.get("exclusive_group", ""),
		},
	]


func _generate_shop_choices(run_state, node: Dictionary) -> Array:
	var options: Array = []
	var node_index: int = node.get("index", 0)
	var start_index: int = (node_index + run_state.rewards.size() + run_state.coins) % REWARD_POOL.size()

	for offset in range(2):
		var template := _find_available_template(run_state, start_index + offset, offset)
		var reward := _make_reward(template, "shop_%d_%d" % [node_index, offset])
		var cost := get_price_for_reward(reward)
		reward["description"] = "%s 花费 %d 枚星砂。" % [template.get("description", ""), cost]
		reward["choice_type"] = CHOICE_REWARD
		reward["cost"] = cost
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
			"description": "后续战斗开局额外获得 %d 点能量。" % REST_FOCUS_STARTING_ENERGY_BONUS,
			"choice_type": CHOICE_REWARD,
			"effect": EFFECT_STARTING_ENERGY,
			"amount": REST_FOCUS_STARTING_ENERGY_BONUS,
			"source_id": REST_FOCUS_SOURCE_ID,
			"rarity": RARITY_COMMON,
			"max_stack": 2,
		},
		{
			"id": "rest_vein_%d" % node_index,
			"title": "描摹灵脉",
			"description": "后续战斗额外生成 1 个灵脉格。",
			"choice_type": CHOICE_REWARD,
			"effect": EFFECT_EXTRA_SPIRIT_CELLS,
			"amount": 1,
			"source_id": "rest_vein",
			"rarity": RARITY_COMMON,
			"max_stack": 2,
		},
		{
			"id": "rest_starsand_%d" % node_index,
			"title": "拾取残砂",
			"description": "获得 1 枚星砂。",
			"choice_type": CHOICE_COINS,
			"amount": 1,
		},
	]


func get_rarity_label(reward: Dictionary) -> String:
	return RARITY_LABELS.get(reward.get("rarity", RARITY_COMMON), "普通")


func get_price_for_reward(reward: Dictionary) -> int:
	return RARITY_PRICES.get(reward.get("rarity", RARITY_COMMON), 2)


func get_shop_price_range_text() -> String:
	return "%d/%d/%d" % [
		RARITY_PRICES.get(RARITY_COMMON, 2),
		RARITY_PRICES.get(RARITY_UNCOMMON, 3),
		RARITY_PRICES.get(RARITY_RARE, 5),
	]


func get_reward_effect_summary(reward: Dictionary) -> String:
	var amount: int = reward.get("amount", 0)

	match reward.get("effect", ""):
		EFFECT_ENERGY_MAX:
			return "能量上限 +%d" % amount
		EFFECT_STARTING_ENERGY:
			return "开局能量 +%d" % amount
		EFFECT_EXTRA_SPIRIT_CELLS:
			return "额外灵脉 +%d" % amount
		EFFECT_ROCK_BREAK_REFUND:
			return "碎岩返能 +%d/场" % amount
		EFFECT_SEAL_REFUND:
			return "封手返能 +%d/场" % amount
		_:
			return "无构筑效果"


func get_reward_limit_summary(reward: Dictionary) -> String:
	var notes: Array = []
	var max_stack: int = reward.get("max_stack", 0)

	if max_stack > 0:
		notes.append("最多 %d 层" % max_stack)

	var exclusive_group: String = reward.get("exclusive_group", "")

	if not exclusive_group.is_empty():
		notes.append("互斥：%s" % EXCLUSIVE_GROUP_LABELS.get(exclusive_group, exclusive_group))

	return " · ".join(notes)


func get_build_summary_lines(run_state) -> Array:
	if run_state == null or not run_state.has_method("get_battle_modifiers"):
		return ["暂未形成构筑"]

	var modifiers: Dictionary = run_state.get_battle_modifiers()
	var lines: Array = []

	if modifiers.get("energy_max_bonus", 0) > 0:
		lines.append("能量上限 +%d" % modifiers.get("energy_max_bonus", 0))

	if modifiers.get("starting_energy_bonus", 0) > 0:
		lines.append("开局能量 +%d" % modifiers.get("starting_energy_bonus", 0))

	if modifiers.get("extra_spirit_cells", 0) > 0:
		lines.append("额外灵脉格 +%d" % modifiers.get("extra_spirit_cells", 0))

	if modifiers.get("rock_break_refund_per_battle", 0) > 0:
		lines.append("碎岩首次返能 +%d/场" % modifiers.get("rock_break_refund_per_battle", 0))

	if modifiers.get("seal_refund_per_battle", 0) > 0:
		lines.append("封手首次返能 +%d/场" % modifiers.get("seal_refund_per_battle", 0))

	if lines.is_empty():
		lines.append("暂未形成构筑")

	return lines


func get_run_pacing_lines(run_state) -> Array:
	if run_state == null or not run_state.has_method("get_run_pacing_summary"):
		return ["暂无节奏数据"]

	var pacing: Dictionary = run_state.get_run_pacing_summary()
	var total_battles: int = pacing.get("total_battle_nodes", 0)
	var completed_battles: int = pacing.get("completed_battle_nodes", 0)
	var remaining_battles: int = pacing.get("remaining_battle_nodes", 0)
	var remaining_min: int = pacing.get("remaining_turn_min", 0)
	var remaining_max: int = pacing.get("remaining_turn_max", 0)
	var current_min: int = pacing.get("current_target_turn_min", 0)
	var current_max: int = pacing.get("current_target_turn_max", 0)
	var recorded_battles: int = pacing.get("recorded_battle_nodes", 0)
	var actual_average: int = pacing.get("actual_turn_average", 0)
	var lines: Array = [
		"战斗进度 %d/%d，剩余 %d 场" % [completed_battles, total_battles, remaining_battles],
	]

	if remaining_min > 0 and remaining_max > 0:
		lines.append("剩余目标 %d-%d 手" % [remaining_min, remaining_max])

	if current_min > 0 and current_max > 0:
		lines.append("当前目标 %d-%d 手" % [current_min, current_max])

	if recorded_battles > 0:
		lines.append("实测 %d 场，均值 %d 手，目标内 %d/偏快 %d/偏慢 %d" % [
			recorded_battles,
			actual_average,
			pacing.get("on_target_count", 0),
			pacing.get("under_target_count", 0),
			pacing.get("over_target_count", 0),
		])

	lines.append("星砂 %d，商店价 %s" % [run_state.coins, get_shop_price_range_text()])
	return lines


func get_run_tuning_lines(run_state) -> Array:
	if run_state == null or not run_state.has_method("get_run_pacing_summary"):
		return ["调参建议：暂无数据"]

	var pacing: Dictionary = run_state.get_run_pacing_summary()
	var lines: Array = [_battle_tuning_line(pacing)]
	lines.append(_economy_tuning_line(run_state))
	lines.append(_reward_tuning_line(run_state, pacing))
	return lines


func get_boss_prep_lines(run_state) -> Array:
	if run_state == null or not run_state.has_method("get_battle_modifiers"):
		return ["Boss 准备：暂无 Run 数据"]

	if not _has_remaining_boss(run_state):
		return ["Boss 准备：岩王已结算，记录本轮手感"]

	var modifiers: Dictionary = run_state.get_battle_modifiers()
	var rest_focus_bonus := _sum_reward_amount_from_source(run_state, REST_FOCUS_SOURCE_ID)
	var lines: Array = [
		"Boss 准备：开局能量 +%d，能量上限 +%d，额外灵脉 +%d，奖励 %d，星砂 %d" % [
			modifiers.get("starting_energy_bonus", 0),
			modifiers.get("energy_max_bonus", 0),
			modifiers.get("extra_spirit_cells", 0),
			run_state.rewards.size(),
			run_state.coins,
		],
	]

	if rest_focus_bonus > 0:
		lines.append("Boss 准备：静息调气已生效（开局能量 +%d），观察岩王前 5 手是否更稳" % rest_focus_bonus)
	elif _is_rest_step_active(run_state):
		lines.append("Boss 准备：休息点可选静息调气 +%d，适合补岩王开局压力" % REST_FOCUS_STARTING_ENERGY_BONUS)
	else:
		lines.append("Boss 准备：尚未拿到静息调气，先观察现有构筑能否扛住岩王开局")

	return lines


func _battle_tuning_line(pacing: Dictionary) -> String:
	var recorded_battles: int = pacing.get("recorded_battle_nodes", 0)

	if recorded_battles <= 0:
		return "手数：先完成 1 场以上实测再微调"

	var under_count: int = pacing.get("under_target_count", 0)
	var over_count: int = pacing.get("over_target_count", 0)
	var on_target_count: int = pacing.get("on_target_count", 0)
	var majority_threshold: int = max(1, int(ceil(float(recorded_battles) * 0.5)))

	if under_count >= majority_threshold and under_count > over_count:
		return "手数：多场偏快，普通战斗目标可上调 2 手或放缓早期奖励"

	if over_count >= majority_threshold and over_count > under_count:
		return "手数：多场偏慢，普通战斗目标可下调 2 手或提高早期资源"

	if on_target_count >= under_count + over_count:
		return "手数：当前样本落在目标内，暂不改普通战斗目标"

	return "手数：样本分化，优先按偏差最大的节点微调"


func _economy_tuning_line(run_state) -> String:
	var common_price: int = RARITY_PRICES.get(RARITY_COMMON, 2)
	var rare_price: int = RARITY_PRICES.get(RARITY_RARE, 5)

	if not _has_upcoming_shop(run_state):
		return "星砂：后续无商店，重点观察事件支出吸引力"

	if run_state.coins < common_price:
		return "星砂：到店前不足普通商品，事件收入可 +1 或普通价格 -1"

	if run_state.coins >= rare_price:
		return "星砂：已可买史诗商品，先观察商店是否过宽"

	return "星砂：可覆盖普通商店价，价格梯度暂稳"


func _reward_tuning_line(run_state, pacing: Dictionary) -> String:
	var completed_battles: int = pacing.get("completed_battle_nodes", 0)
	var reward_count: int = run_state.rewards.size()

	if run_state.has_method("has_pending_reward") and run_state.has_pending_reward():
		return "奖励：待领奖状态正常，领取后再看构筑增速"

	if completed_battles <= 0:
		return "奖励：首战后检查三选一是否过早定型"

	if reward_count < completed_battles:
		return "奖励：已完成战斗多于已获奖励，确认是否被路线选择阻塞"

	if reward_count >= 3 and _has_remaining_boss(run_state):
		return "奖励：Boss 前构筑较饱满，留意奖励密度是否偏高"

	return "奖励：胜利奖励节奏稳定，继续收集完整 Run 样本"


func _has_upcoming_shop(run_state) -> bool:
	if run_state == null:
		return false

	for node in run_state.nodes:
		if node.get("index", -1) < run_state.current_index:
			continue

		if node.get("type", "") == NODE_SHOP and node.get("status", "") != "completed":
			return true

	return false


func _has_remaining_boss(run_state) -> bool:
	if run_state == null:
		return false

	for node in run_state.nodes:
		if node.get("index", -1) < run_state.current_index:
			continue

		if node.get("type", "") == "boss" and node.get("status", "") != "completed":
			return true

	return false


func _is_rest_step_active(run_state) -> bool:
	if run_state == null:
		return false

	if run_state.has_method("has_pending_node_choice") and run_state.has_pending_node_choice():
		var choice_index: int = run_state.pending_choice_node_index

		if choice_index >= 0 and choice_index < run_state.nodes.size():
			return run_state.nodes[choice_index].get("type", "") == NODE_REST

	var current_node: Dictionary = run_state.get_current_node() if run_state.has_method("get_current_node") else {}
	return current_node.get("type", "") == NODE_REST


func _sum_reward_amount_from_source(run_state, source_id: String) -> int:
	if run_state == null:
		return 0

	var total := 0

	for reward in run_state.rewards:
		if reward.get("source_id", reward.get("id", "")) == source_id:
			total += reward.get("amount", 0)

	return total


func _make_reward(template: Dictionary, suffix: String) -> Dictionary:
	var reward := template.duplicate(true)
	var source_id: String = template.get("id", "reward")
	reward["source_id"] = source_id
	reward["id"] = "%s_%s" % [source_id, suffix]
	return reward


func _find_available_template(run_state, start_index: int, fallback_offset: int) -> Dictionary:
	for offset in range(REWARD_POOL.size()):
		var template: Dictionary = REWARD_POOL[(start_index + offset) % REWARD_POOL.size()]

		if run_state == null or not run_state.has_method("can_add_reward") or run_state.can_add_reward(template):
			return template

	return REWARD_POOL[(start_index + fallback_offset) % REWARD_POOL.size()]
