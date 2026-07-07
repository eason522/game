class_name MapGenerator
extends RefCounted

const NODE_START := "start"
const NODE_BATTLE := "battle"
const NODE_EVENT := "event"
const NODE_SHOP := "shop"
const NODE_REST := "rest"
const NODE_BOSS := "boss"


func generate_linear_route() -> Array:
	return [
		_make_node(0, NODE_START, "入局", "整备完成，踏入天元迷局。", ""),
		_make_node(1, NODE_BATTLE, "试锋之局", "新手棋魂会用均衡棋风试探你的布局。", EnemyAI.PROFILE_NOVICE),
		_make_node(2, NODE_EVENT, "星痕岔路", "一枚残谱漂浮在棋路旁，可换取资源或强化。", ""),
		_make_node(3, NODE_BATTLE, "急攻之局", "快攻棋士偏向主动连线，逼你及时应对。", EnemyAI.PROFILE_FAST_ATTACKER),
		_make_node(4, NODE_SHOP, "云游棋肆", "游商摆出几枚棋印，只收一路积攒的星砂。", ""),
		_make_node(5, NODE_BATTLE, "守势之局", "堡垒棋士会优先堵住你的关键威胁。", EnemyAI.PROFILE_DEFENDER),
		_make_node(6, NODE_REST, "静息石台", "在岩王之前调息整备，选择一项稳定构筑。", ""),
		_make_node(7, NODE_BOSS, "岩王之局", "岩王会布置岩阵，并周期性压缩棋盘空间。", EnemyAI.PROFILE_ROCK_BOSS),
	]


func _make_node(index: int, node_type: String, title: String, description: String, enemy_profile_id: String) -> Dictionary:
	return {
		"id": "node_%d" % index,
		"index": index,
		"type": node_type,
		"title": title,
		"description": description,
		"enemy_profile_id": enemy_profile_id,
		"status": "locked",
	}
