extends Node

# 每日学习模块 - 每天学习新技术
# Phase 4 功能

signal learning_started(topic: String)
signal learning_completed(tip: String)
signal errorOccurred(error: String)

const LEARNING_TOPICS = {
	"gdscript": [
		"使用 @export 导出变量",
		"使用信号 (signals) 解耦",
		"使用 yield 进行异步操作",
		"使用 @tool 在编辑器运行代码",
		"使用 preload 预加载资源"
	],
	"godot4": [
		"4.0新特性: GDExtension",
		"4.0新特性: 改进的3D渲染",
		"4.0新特性: 更好的VR支持",
		"4.1新特性: Mac/Linux Metal",
		"4.2新特性: 改进的2D引擎"
	],
	"game_design": [
		"游戏手感: 帧数与反馈",
		"游戏手感: 移动与跳跃",
		"UI设计: 清晰与美观",
		"难度曲线设计",
		"玩家引导设计"
	],
	"unity": [
		"Addressables资源系统",
		"DOTS数据导向设计",
		"URP渲染管线",
		"C# Job System",
		"Shader Graph可视化着色器"
	],
	"performance": [
		"对象池技术",
		"LOD分级细节",
		"遮挡剔除",
		"批处理优化",
		"内存管理技巧"
	]
}

var last_learning_date: String = ""
var current_topic: String = ""
var daily_tip: String = ""
var learning_history: Array = []

func _ready() -> void:
	print("📚 每日学习模块已就绪")
	_load_history()

func _load_history() -> void:
	var config_path = "user://daily_learning.json"
	if FileAccess.file_exists(config_path):
		var file = FileAccess.open(config_path, FileAccess.READ)
		if file:
			var json = JSON.parse_string(file.get_as_text())
			if json:
				learning_history = json.get("history", [])
				last_learning_date = json.get("last_date", "")
			file.close()

func _save_history() -> void:
	var config_path = "user://daily_learning.json"
	var file = FileAccess.open(config_path, FileAccess.WRITE)
	if file:
		var data = {
			"history": learning_history,
			"last_date": last_learning_date
		}
		file.store_string(JSON.stringify(data))
		file.close()

# 获取今日学习内容
func get_today_learning() -> Dictionary:
	var today = Time.get_date_string_from_system()
	
	# 检查是否今天已经学习过
	if last_learning_date == today:
		return {
			"topic": current_topic,
			"tip": daily_tip,
			"already_learned": true
		}
	
	# 选择新的话题
	current_topic = _select_random_topic()
	daily_tip = _get_topic_tip(current_topic)
	
	# 更新状态
	last_learning_date = today
	
	# 记录历史
	learning_history.append({
		"date": today,
		"topic": current_topic,
		"tip": daily_tip
	})
	
	# 只保留最近30天的记录
	if learning_history.size() > 30:
		learning_history = learning_history.slice(-30, 30)
	
	_save_history()
	learning_started.emit(current_topic)
	
	return {
		"topic": current_topic,
		"tip": daily_tip,
		"already_learned": false
	}

func _select_random_topic() -> String:
	var topics = LEARNING_TOPICS.keys()
	var weights = {
		"gdscript": 3,
		"godot4": 2,
		"game_design": 2,
		"unity": 1,
		"performance": 2
	}
	
	# 加权随机选择
	var total_weight = 0
	for topic in topics:
		total_weight += weights.get(topic, 1)
	
	var random_value = randi() % total_weight
	var cumulative = 0
	
	for topic in topics:
		cumulative += weights.get(topic, 1)
		if random_value < cumulative:
			return topic
	
	return topics[0]

func _get_topic_tip(topic: String) -> String:
	var tips = LEARNING_TOPICS.get(topic, [])
	if tips.is_empty():
		return "今天没有找到相关技巧"
	
	var random_index = randi() % tips.size()
	return tips[random_index]

# 获取学习统计
func get_learning_stats() -> Dictionary:
	var today = Time.get_date_string_from_system()
	
	# 统计
	var total_days = learning_history.size()
	var streak = _calculate_streak()
	var categories_learned = {}
	
	for record in learning_history:
		var topic = record.get("topic", "")
		categories_learned[topic] = categories_learned.get(topic, 0) + 1
	
	return {
		"total_days": total_days,
		"current_streak": streak,
		"categories": categories_learned,
		"last_learning": last_learning_date,
		"today_learned": last_learning_date == today
	}

func _calculate_streak() -> int:
	if learning_history.is_empty():
		return 0
	
	var streak = 0
	var current_date = Time.get_date_dict_from_system()
	
	# 简化计算：检查最后一条记录
	var last_record = learning_history[-1]
	var last_date = last_record.get("date", "")
	
	# 这里简化处理，实际应该解析日期计算
	if last_date == Time.get_date_string_from_system():
		streak = 1
	
	return streak

# 生成学习报告
func generate_learning_report() -> String:
	var stats = get_learning_stats()
	var today = get_today_learning()
	
	var report = """
📚 每日学习报告
━━━━━━━━━━━━━━━━━━━━━━━

📅 今日学习
━━━━━━━━━━
📂 话题: %s
💡 技巧: %s
%s

📊 学习统计
━━━━━━━━━━
📆 总学习天数: %d
🔥 当前连续: %d 天
🎯 已学习话题: %d 类

📈 话题分布
━━━━━━━━━━
""" % [
		today["topic"],
		today["tip"],
		"✅ 今日已学习" if today["already_learned"] else "🆕 今日新内容",
		stats["total_days"],
		stats["current_streak"],
		stats["categories"].size()
	]
	
	for topic in stats["categories"]:
		var count = stats["categories"][topic]
		var bar = "▓" * min(count, 10)
		report += "%s: %s (%d)\n" % [topic, bar, count]
	
	return report

# 搜索学习内容
func search_learning(keyword: String) -> Array:
	var results = []
	var lower_keyword = keyword.to_lower()
	
	for category in LEARNING_TOPICS:
		for tip in LEARNING_TOPICS[category]:
			if tip.to_lower().contains(lower_keyword):
				results.append({
					"category": category,
					"tip": tip
				})
	
	return results

# 获取所有话题
func get_all_topics() -> Array:
	return LEARNING_TOPICS.keys()

# 获取话题详情
func get_topic_details(topic: String) -> Dictionary:
	return {
		"topic": topic,
		"tips": LEARNING_TOPICS.get(topic, []),
		"count": LEARNING_TOPICS.get(topic, []).size()
	}
