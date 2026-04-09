extends Node

# 本地知识库 - 存储和管理项目知识
# Phase 4 功能

signal knowledge_added(entry: Dictionary)
signal knowledge_updated(entry: Dictionary)
signal knowledge_searched(results: Array)

const MAX_ENTRIES = 1000

var knowledge_entries: Array = []
var tags_index: Dictionary = {}
var last_save_time: int = 0

func _ready() -> void:
	print("📖 知识库已就绪")
	_load_knowledge()

# 添加知识条目
func add_entry(title: String, content: String, tags: Array = [], source: String = "") -> Dictionary:
	var entry = {
		"id": _generate_id(),
		"title": title,
		"content": content,
		"tags": tags,
		"source": source,
		"created_at": Time.get_datetime_string_from_system(),
		"updated_at": Time.get_datetime_string_from_system(),
		"access_count": 0,
		"last_accessed": ""
	}
	
	# 限制条目数量
	if knowledge_entries.size() >= MAX_ENTRIES:
		_remove_oldest_entry()
	
	knowledge_entries.append(entry)
	_index_entry(entry)
	_save_knowledge()
	
	knowledge_added.emit(entry)
	return entry

# 更新知识条目
func update_entry(entry_id: String, updates: Dictionary) -> bool:
	for i in range(knowledge_entries.size()):
		var entry = knowledge_entries[i]
		if entry["id"] == entry_id:
			# 移除旧索引
			_deindex_entry(entry)
			
			# 更新字段
			for key in updates:
				if key in entry:
					entry[key] = updates[key]
			
			entry["updated_at"] = Time.get_datetime_string_from_system()
			
			# 重新索引
			_index_entry(entry)
			_save_knowledge()
			
			knowledge_updated.emit(entry)
			return true
	
	return false

# 删除知识条目
func delete_entry(entry_id: String) -> bool:
	for i in range(knowledge_entries.size()):
		if knowledge_entries[i]["id"] == entry_id:
			_deindex_entry(knowledge_entries[i])
			knowledge_entries.remove_at(i)
			_save_knowledge()
			return true
	return false

# 搜索知识
func search(query: String, max_results: int = 10) -> Array:
	var results = []
	var lower_query = query.to_lower()
	
	# 评分搜索
	var scored_results = []
	
	for entry in knowledge_entries:
		var score = 0
		var matched = false
		
		# 标题匹配（最高权重）
		if entry["title"].to_lower().contains(lower_query):
			score += 10
			matched = true
		
		# 内容匹配
		if entry["content"].to_lower().contains(lower_query):
			score += 5
			matched = true
		
		# 标签匹配
		for tag in entry["tags"]:
			if tag.to_lower().contains(lower_query):
				score += 3
				matched = true
		
		# 来源匹配
		if entry["source"].to_lower().contains(lower_query):
			score += 2
			matched = true
		
		if matched:
			# 更新访问记录
			entry["access_count"] += 1
			entry["last_accessed"] = Time.get_datetime_string_from_system()
			
			scored_results.append({
				"entry": entry,
				"score": score
			})
	
	# 按分数排序
	scored_results.sort_custom(func(a, b): return a["score"] > b["score"])
	
	# 取前N个结果
	for i in range(min(max_results, scored_results.size())):
		results.append(scored_results[i]["entry"])
	
	knowledge_searched.emit(results)
	return results

# 按标签搜索
func search_by_tag(tag: String, max_results: int = 20) -> Array:
	var results = []
	
	for entry in knowledge_entries:
		if tag in entry["tags"]:
			results.append(entry)
			if results.size() >= max_results:
				break
	
	return results

# 获取随机条目（用于推荐）
func get_random_entry() -> Dictionary:
	if knowledge_entries.is_empty():
		return {}
	
	var random_index = randi() % knowledge_entries.size()
	return knowledge_entries[random_index]

# 获取所有标签
func get_all_tags() -> Array:
	return tags_index.keys()

# 获取标签统计
func get_tag_stats() -> Dictionary:
	var stats = {}
	for tag in tags_index:
		stats[tag] = tags_index[tag].size()
	return stats

# 获取统计信息
func get_stats() -> Dictionary:
	return {
		"total_entries": knowledge_entries.size(),
		"max_entries": MAX_ENTRIES,
		"total_tags": tags_index.size(),
		"last_saved": last_save_time
	}

# 导出知识库
func export_knowledge() -> Dictionary:
	return {
		"version": "1.0",
		"exported_at": Time.get_datetime_string_from_system(),
		"entries": knowledge_entries
	}

# 导入知识库
func import_knowledge(data: Dictionary) -> int:
	var imported = 0
	
	var entries = data.get("entries", [])
	for entry_data in entries:
		# 验证格式
		if "title" in entry_data and "content" in entry_data:
			add_entry(
				entry_data["title"],
				entry_data["content"],
				entry_data.get("tags", []),
				entry_data.get("source", "")
			)
			imported += 1
	
	return imported

# 生成知识库报告
func generate_report() -> String:
	var stats = get_stats()
	var tag_stats = get_tag_stats()
	
	# 排序标签
	var sorted_tags = tag_stats.keys()
	sorted_tags.sort()
	
	var report = """
📖 知识库报告
━━━━━━━━━━━━━━━━━━━━━━━

📊 统计信息
━━━━━━━━━━
📚 总条目数: %d / %d
🏷️ 总标签数: %d
💾 最后保存: %s

🏷️ 标签分布
━━━━━━━━━━
""" % [
		stats["total_entries"],
		stats["max_entries"],
		stats["total_tags"],
		Time.get_datetime_string_from_system() if stats["last_saved"] == 0 else str(stats["last_saved"])
	]
	
	for tag in sorted_tags:
		var count = tag_stats[tag]
		var bar = "▓" * min(count, 10)
		report += "%s: %s (%d)\n" % [tag, bar, count]
	
	if knowledge_entries.size() > 0:
		report += """
📝 最近添加
━━━━━━━━━━"""
		var recent = knowledge_entries.slice(-5, knowledge_entries.size())
		for entry in recent:
			report += "\n• %s" % entry["title"]
	
	return report

# ==================== 私有方法 ====================

func _generate_id() -> String:
	return "kb_%d_%d" % [Time.get_unix_time_from_system(), randi() % 10000]

func _index_entry(entry: Dictionary) -> void:
	for tag in entry["tags"]:
		if not tags_index.has(tag):
			tags_index[tag] = []
		tags_index[tag].append(entry["id"])

func _deindex_entry(entry: Dictionary) -> void:
	for tag in entry["tags"]:
		if tags_index.has(tag):
			var ids = tags_index[tag]
			ids.erase(entry["id"])
			if ids.is_empty():
				tags_index.erase(tag)

func _remove_oldest_entry() -> void:
	if knowledge_entries.is_empty():
		return
	
	# 找到最旧且最少访问的条目
	var oldest = knowledge_entries[0]
	
	for entry in knowledge_entries:
		var entry_time = Time.get_unix_time_from_system()
		var oldest_time = Time.get_unix_time_from_system()
		
		if entry["access_count"] < oldest["access_count"]:
			oldest = entry
	
	delete_entry(oldest["id"])

func _load_knowledge() -> void:
	var config_path = "user://knowledge_base.json"
	if FileAccess.file_exists(config_path):
		var file = FileAccess.open(config_path, FileAccess.READ)
		if file:
			var json = JSON.parse_string(file.get_as_text())
			if json and json is Dictionary:
				knowledge_entries = json.get("entries", [])
				_rebuild_index()
			file.close()

func _rebuild_index() -> void:
	tags_index.clear()
	for entry in knowledge_entries:
		_index_entry(entry)

func _save_knowledge() -> void:
	var config_path = "user://knowledge_base.json"
	var file = FileAccess.open(config_path, FileAccess.WRITE)
	if file:
		var data = {
			"version": "1.0",
			"entries": knowledge_entries
		}
		file.store_string(JSON.stringify(data))
		file.close()
		last_save_time = Time.get_unix_time_from_system()
