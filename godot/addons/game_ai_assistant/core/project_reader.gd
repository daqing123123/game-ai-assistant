extends Node

# 项目读取器 - 读取Unity/Godot项目结构
# 为AI提供项目上下文

signal project_loaded(project_info: Dictionary)
signal scene_loaded(scene_path: String, nodes: Array)
signal errorOccurred(error: String)

var current_project_path: String = ""
var project_info: Dictionary = {}
var scene_cache: Dictionary = {}

# 项目类型
enum ProjectType {
	UNKNOWN,
	GODOT_2D,
	GODOT_3D,
	UNITY_2D,
	UNITY_3D
}

func _init() -> void:
	pass

# 扫描项目
func scan_project(project_path: String = "") -> Dictionary:
	if project_path.is_empty():
		project_path = ProjectSettings.globalize_path("res://")
	
	current_project_path = project_path
	project_info = {
		"path": project_path,
		"type": detect_project_type(),
		"scenes": [],
		"scripts": [],
		"resources": [],
		"nodes": 0,
		"scene_count": 0,
		"script_count": 0
	}
	
	# 扫描场景文件
	_scan_directory(project_path, ["*.tscn", "*.scn"], project_info["scenes"])
	
	# 扫描脚本文件
	_scan_directory(project_path, ["*.gd", "*.gdscript"], project_info["scripts"])
	
	# 扫描资源
	_scan_resources(project_path)
	
	project_loaded.emit(project_info)
	return project_info

func _scan_directory(base_path: String, patterns: Array, result: Array) -> void:
	var dir = DirAccess.open(base_path)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				var sub_path = base_path + "/" + file_name
				_scan_directory(sub_path, patterns, result)
		else:
			for pattern in patterns:
				if file_name.match(pattern):
					var file_path = base_path + "/" + file_name
					var rel_path = file_path.replace(base_path + "/", "")
					result.append({
						"name": file_name,
						"path": file_path,
						"relative": rel_path,
						"size": FileAccess.file_exists(file_path)
					})
					break
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func _scan_resources(base_path: String) -> void:
	var resources: Array = []
	var types = {
		"images": ["*.png", "*.jpg", "*.webp", "*.svg"],
		"audio": ["*.wav", "*.ogg", "*.mp3"],
		"fonts": ["*.ttf", "*.otf"],
		"models": ["*.obj", "*.glb", ".gltf"],
		"other": ["*.tres", "*.res"]
	}
	
	for type_name in types:
		var type_resources: Array = []
		for pattern in types[type_name]:
			_scan_directory(base_path, [pattern], type_resources)
		if not type_resources.is_empty():
			resources.append({
				"type": type_name,
				"files": type_resources,
				"count": type_resources.size()
			})
	
	project_info["resources"] = resources
	project_info["scene_count"] = project_info["scenes"].size()
	project_info["script_count"] = project_info["scripts"].size()

func detect_project_type() -> String:
	# 检测项目类型
	var config_file = current_project_path + "/project.godot"
	if FileAccess.file_exists(config_file):
		return "Godot Project"
	
	var unity_file = current_project_path + "/ProjectSettings/ProjectVersion.txt"
	if FileAccess.file_exists(unity_file):
		return "Unity Project"
	
	return "Unknown"

# 读取场景内容
func read_scene(scene_path: String) -> Dictionary:
	if scene_cache.has(scene_path):
		return scene_cache[scene_path]
	
	var result = {
		"path": scene_path,
		"name": scene_path.get_file(),
		"nodes": [],
		"structure": ""
	}
	
	var file = FileAccess.open(scene_path, FileAccess.READ)
	if not file:
		errorOccurred.emit("无法打开场景: " + scene_path)
		return result
	
	var content = file.get_as_text()
	file.close()
	
	# 解析场景内容
	result["nodes"] = _parse_scene_nodes(content)
	result["structure"] = _generate_scene_tree(result["nodes"])
	
	scene_cache[scene_path] = result
	return result

func _parse_scene_nodes(content: String) -> Array:
	var nodes: Array = []
	
	# 简单解析 - 查找节点声明
	var lines = content.split("\n")
	var in_node = false
	var current_node: Dictionary = {}
	
	for line in lines:
		line = line.strip_edges()
		
		# 检测节点开始
		if line.begins_with("[node name="):
			in_node = true
			current_node = {"type": "unknown", "name": "", "script": ""}
			
			# 提取节点名
			var start = line.find("\"") + 1
			var end = line.find("\"", start)
			if start > 0 and end > start:
				current_node["name"] = line.substr(start, end - start)
		
		# 检测类型
		elif in_node and line.begins_with("type="):
			var start = line.find("\"") + 1
			var end = line.find("\"", start)
			if start > 0 and end > start:
				current_node["type"] = line.substr(start, end - start)
		
		# 检测脚本
		elif in_node and line.begins_with("script="):
			var start = line.find("Resource(\"res://")
			if start >= 0:
				start += 11  # "res://" 长度
				var end = line.find("\"", start)
				if end > start:
					current_node["script"] = line.substr(start, end - start)
		
		# 检测节点结束
		elif in_node and line == "" or line.begins_with("["):
			if not current_node.is_empty() and current_node.has("name"):
				nodes.append(current_node)
			in_node = false
			current_node = {}
	
	return nodes

func _generate_scene_tree(nodes: Array) -> String:
	var tree = ""
	for node in nodes:
		var name = node.get("name", "?")
		var type = node.get("type", "Node")
		var script = node.get("script", "")
		
		var line = "📦 %s [%s]" % [name, type]
		if not script.is_empty():
			var script_name = script.get_file()
			line += " → 📜 %s" % script_name
		line += "\n"
		tree += line
	
	return tree

# 获取选中节点信息
func get_selected_nodes() -> Array:
	var selected: Array = []
	
	# 检查编辑器上下文
	if Engine.is_editor_hint():
		var selection = EditorInterface.get_selection()
		var selected_nodes = selection.get_selected_nodes()
		
		for node in selected_nodes:
			selected.append({
				"name": node.name,
				"type": node.get_class(),
				"path": node.get_path()
			})
	
	return selected

# 生成项目摘要
func generate_project_summary() -> String:
	if project_info.is_empty():
		scan_project()
	
	var summary = """
📁 项目信息
━━━━━━━━━━━━━━━━━━━━━━━
• 路径: %s
• 类型: %s
• 场景数: %d
• 脚本数: %d
• 资源: %d 类

📂 场景文件:
""" % [
		project_info.get("path", "未知"),
		project_info.get("type", "未知"),
		project_info.get("scene_count", 0),
		project_info.get("script_count", 0),
		project_info.get("resources", []).size()
	]
	
	var scenes = project_info.get("scenes", [])
	for i in range(min(10, scenes.size())):
		var scene = scenes[i]
		summary += "• %s\n" % scene.get("relative", "?")
	
	if scenes.size() > 10:
		summary += "...还有 %d 个场景\n" % (scenes.size() - 10)
	
	summary += "\n📜 脚本文件:\n"
	var scripts = project_info.get("scripts", [])
	for i in range(min(10, scripts.size())):
		var script = scripts[i]
		summary += "• %s\n" % script.get("relative", "?")
	
	if scripts.size() > 10:
		summary += "...还有 %d 个脚本\n" % (scripts.size() - 10)
	
	return summary

# 获取场景树
func get_scene_tree(scene_path: String) -> String:
	var scene = read_scene(scene_path)
	return scene.get("structure", "")

# 清除缓存
func clear_cache() -> void:
	scene_cache.clear()

# 获取项目根路径
func get_project_root() -> String:
	return current_project_path if not current_project_path.is_empty() else "res://"

# ==================== 代码全文搜索 ====================
# 搜索代码中的关键词，返回匹配结果

signal search_completed(results: Array)
signal search_progress(current: int, total: int)

func search_code(query: String, max_results: int = 20) -> Array:
	"""
	在项目中全文搜索代码
	:param query: 搜索关键词
	:param max_results: 最大返回结果数
	:return: 匹配结果数组
	"""
	var results: Array = []
	var search_lower = query.to_lower()
	
	if project_info.is_empty():
		scan_project()
	
	# 获取所有代码文件
	var code_files: Array = []
	_scan_directory(current_project_path, ["*.gd", "*.gdscript", "*.cs", "*.tscn"], code_files)
	
	var total = code_files.size()
	var current = 0
	
	for file_data in code_files:
		current += 1
		search_progress.emit(current, total)
		
		var file_path = file_data.get("path", "")
		if file_path.is_empty():
			continue
		
		var matches = _search_in_file(file_path, search_lower)
		if not matches.is_empty():
			results.append({
				"file": file_data,
				"path": file_path,
				"relative_path": file_data.get("relative", file_path),
				"matches": matches,
				"match_count": matches.size()
			})
		
		# 限制结果数量
		if results.size() >= max_results:
			break
	
	search_completed.emit(results)
	return results

func _search_in_file(file_path: String, search_lower: String) -> Array:
	"""
	在单个文件中搜索关键词
	返回匹配行信息数组
	"""
	var matches: Array = []
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return matches
	
	var line_num = 0
	while not file.eof_reached():
		line_num += 1
		var line = file.get_line()
		var line_lower = line.to_lower()
		
		if line_lower.find(search_lower) != -1:
			# 提取上下文（前2行+后2行）
			var context = _get_line_context(file_path, line_num, 2)
			matches.append({
				"line_number": line_num,
				"content": line.strip_edges(),
				"context": context,
				"preview": _make_preview(line, search_lower)
			})
	
	file.close()
	return matches

func _get_line_context(file_path: String, center_line: int, context_size: int) -> Dictionary:
	"""
	获取指定行周围的上下文
	"""
	var context: Dictionary = {
		"before": [],
		"after": [],
		"lines": []
	}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return context
	
	var line_num = 0
	var all_lines: Array = []
	
	while not file.eof_reached():
		line_num += 1
		all_lines.append(file.get_line())
	
	file.close()
	
	var start = max(0, center_line - context_size - 1)
	var end = min(all_lines.size(), center_line + context_size)
	
	for i in range(start, end):
		var is_match = (i + 1 == center_line)
		context.lines.append({
			"line_number": i + 1,
			"content": all_lines[i],
			"is_match": is_match
		})
	
	return context

func _make_preview(line: String, search_lower: String) -> String:
	"""
	在行中高亮显示匹配内容
	"""
	var preview = line.strip_edges()
	if preview.length() > 100:
		var idx = preview.to_lower().find(search_lower)
		if idx >= 0:
			var start = max(0, idx - 30)
			var end = min(preview.length(), idx + search_lower.length() + 50)
			preview = "..." + preview.substr(start, end - start) + "..."
		else:
			preview = preview.substr(0, 100) + "..."
	return preview

func search_code_regex(pattern: String, max_results: int = 20) -> Array:
	"""
	使用正则表达式搜索代码
	"""
	var results: Array = []
	
	# 简单正则匹配（Godot 4 GDScript不完全支持复杂正则，这里做简化处理）
	var search_lower = pattern.to_lower()
	
	if project_info.is_empty():
		scan_project()
	
	var code_files: Array = []
	_scan_directory(current_project_path, ["*.gd", "*.gdscript", "*.cs", "*.tscn"], code_files)
	
	var count = 0
	for file_data in code_files:
		if count >= max_results:
			break
		
		var file_path = file_data.get("path", "")
		var file = FileAccess.open(file_path, FileAccess.READ)
		if not file:
			continue
		
		var line_num = 0
		var matches: Array = []
		
		while not file.eof_reached:
			line_num += 1
			var line = file.get_line()
			var line_lower = line.to_lower()
			
			# 简单包含检查（可扩展为正则）
			if line_lower.find(search_lower) != -1:
				matches.append({
					"line_number": line_num,
					"content": line.strip_edges(),
					"preview": _make_preview(line, search_lower)
				})
		
		file.close()
		
		if not matches.is_empty():
			results.append({
				"file": file_data,
				"path": file_path,
				"relative_path": file_data.get("relative", file_path),
				"matches": matches,
				"match_count": matches.size()
			})
			count += 1
	
	return results

func generate_search_report(query: String) -> String:
	"""
	生成代码搜索报告
	"""
	var results = search_code(query, 15)
	
	if results.is_empty():
		return "🔍 没有找到匹配「%s」的代码\n\n💡 建议：\n• 尝试更简短的关键词\n• 检查拼写是否正确\n• 使用相关函数名或变量名搜索" % query
	
	var report = "🔍 代码搜索结果\n"
	report += "━━━━━━━━━━━━━━━━━━━━━━━\n"
	report += "📊 找到 %d 个匹配文件\n\n" % results.size()
	
	for i in range(min(5, results.size())):
		var r = results[i]
		var file_name = r.get("relative_path", r.get("path", "?")).get_file()
		var match_count = r.get("match_count", 0)
		
		report += "📄 %s\n" % file_name
		report += "   路径: %s\n" % r.get("relative_path", "?")
		report += "   匹配: %d 处\n" % match_count
		
		var matches = r.get("matches", [])
		if not matches.is_empty():
			var preview = matches[0].get("preview", "")
			if not preview.is_empty():
				report += "   预览: %s\n" % preview.substr(0, min(60, preview.length()))
		report += "\n"
	
	if results.size() > 5:
		report += "...还有 %d 个文件匹配\n\n" % (results.size() - 5)
	
	report += "💡 输入「查看代码:%s」查看完整结果\n" % query
	report += "💡 输入「跳转到:文件名」打开对应文件"
	
	return report
