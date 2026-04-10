extends Node

# =============================================================================
# EditorAgent - Ziva 风格编辑器智能体 v1.0
# 自动读取上下文 + 直接操作节点 + TileMap编辑 + 截图调试
# =============================================================================

signal context_ready(ctx: Dictionary)
signal operation_completed(op: String, success: bool, message: String)
signal screenshot_captured(image_data: Dictionary)

# 截图缓存
var _last_screenshot: Image = null
var _last_screenshot_base64: String = ""

# =============================================================================
# A. 自动上下文读取 - 像 Ziva 一样
# =============================================================================

# Ziva 核心：自动收集上下文
func auto_gather_context(user_input: String = "") -> Dictionary:
	var ctx: Dictionary = {
		"scene_info": _read_scene_context(),
		"selected_nodes": _read_selected_nodes_info(),
		"console_errors": _read_console_errors(),
		"hierarchy": _read_hierarchy(),
		"project_path": _get_project_path(),
		"engine_version": _get_engine_version(),
		"timestamp": Time.get_datetime_string_from_system()
	}
	context_ready.emit(ctx)
	return ctx

# 获取场景上下文
func _read_scene_context() -> Dictionary:
	var result: Dictionary = {
		"scene_name": "无场景",
		"scene_path": "",
		"root_nodes": [],
		"node_count": 0,
		"has_tilemap": false,
		"has_player": false,
		"autoloads": []
	}
	
	# 获取当前场景根节点
	var scene_root = _get_scene_root()
	if not scene_root:
		return result
	
	result["scene_path"] = scene_root.get_scene_file_path()
	result["scene_name"] = scene_root.name
	
	# 扫描根节点下的直接子节点
	for child in scene_root.get_children():
		var info = _node_to_dict(child, 1)
		result["root_nodes"].append(info)
		result["node_count"] += 1 + _count_descendants(child)
		
		# 检测特殊节点
		if "TileMap" in child.name or child is TileMap:
			result["has_tilemap"] = true
		if "Player" in child.name or "player" in child.name.to_lower():
			result["has_player"] = true
	
	# 获取自动加载
	result["autoloads"] = _get_autoloads()
	
	return result

# 读取选中节点详情（Ziva 风格）
func _read_selected_nodes_info() -> Array:
	var selected: Array = []
	var selection = _get_editor_selection()
	if not selection:
		return selected
	
	for node in selection.get_selected_nodes():
		if not node:
			continue
		var info = _node_to_dict(node, 0)
		selected.append(info)
	
	return selected

# 读取 Console 错误（Ziva 风格 - 自动读取）
func _read_console_errors() -> Array:
	var errors: Array = []
	
	# 方法1：通过 EditorNode 的 Output
	var output_text = _get_editor_output_text()
	if not output_text.is_empty():
		var lines = output_text.split("\n")
		var recent = lines.slice(max(0, lines.size() - 100), lines.size())
		for line in recent:
			if "error" in line.to_lower() or "warning" in line.to_lower():
				errors.append(line.strip_edges())
	
	# 方法2：读取临时日志文件
	var log_path = "user://editor_log.txt"
	if FileAccess.file_exists(log_path):
		var file = FileAccess.open(log_path, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			file.close()
			var lines = content.split("\n")
			var recent = lines.slice(max(0, lines.size() - 50), lines.size())
			for line in recent:
				if "error" in line.to_lower() or "err:" in line.to_lower():
					errors.append(line.strip_edges())
	
	# 去重
	var seen: Dictionary = {}
	var unique: Array = []
	for e in errors:
		if not seen.get(e, false):
			seen[e] = true
			unique.append(e)
	
	return unique.slice(0, 30)  # 最多30条

# 读取场景层级（Ziva 风格）
func _read_hierarchy() -> String:
	var scene_root = _get_scene_root()
	if not scene_root:
		return "（无活动场景）"
	
	var lines: Array = []
	lines.append("📂 " + scene_root.name + " (" + scene_root.get_scene_file_path() + ")")
	_recursive_hierarchy(scene_root, lines, 1, 10)  # 最多10层
	return "\n".join(lines)

func _recursive_hierarchy(node: Node, lines: Array, depth: int, max_depth: int) -> void:
	if depth > max_depth:
		lines.append("  ".repeat(depth) + "... (更多子节点)")
		return
	for child in node.get_children():
		var indent = "  ".repeat(depth)
		var type_str = child.get_class()
		var extra = ""
		if child is TileMap:
			extra = " [TileMap]"
		if child is CharacterBody2D or child is CharacterBody3D:
			extra = " [CharacterBody]"
		if child is RigidBody2D or child is RigidBody3D:
			extra = " [RigidBody]"
		if child.has_method("get_child_count") and child.get_child_count() > 0:
			extra += " (+%d)" % child.get_child_count()
		lines.append(indent + "├─ " + child.name + " (" + type_str + ")" + extra)
		_recursive_hierarchy(child, lines, depth + 1, max_depth)

# 获取节点详细信息
func _node_to_dict(node: Node, depth: int) -> Dictionary:
	var info: Dictionary = {
		"name": node.name,
		"type": node.get_class(),
		"path": node.get_path(),
		"owner_path": "",
		"position": Vector2.ZERO,
		"script": "",
		"children": [],
		"signals": [],
		"properties": {}
	}
	
	# 位置信息
	if node is Node2D:
		info["position"] = node.position
	elif node is Node3D:
		info["position_3d"] = str(node.position)
	
	# 脚本路径
	if node.get_script():
		info["script"] = node.get_script().get_path()
	
	# 获取 Owner 路径
	var scene_root = _get_scene_root()
	if scene_root:
		info["owner_path"] = scene_root.get_path_to(node)
	
	# 子节点（限制深度）
	if depth < 3:
		for child in node.get_children():
			info["children"].append(_node_to_dict(child, depth + 1))
	
	# 重要属性（根据类型）
	info["properties"] = _get_node_properties(node)
	
	return info

func _get_node_properties(node: Node) -> Dictionary:
	var props: Dictionary = {}
	
	# 通用属性
	var common = ["name", "visible", "modulate", "position", "rotation", "scale"]
	for p in common:
		if p in ["position", "rotation", "scale"]:
			if node is Node2D:
				props[p] = str(node.get(p))
		elif "visible" in p:
			props[p] = node.get(p)
	
	# 类型特定属性
	match node.get_class():
		"Sprite2D":
			props["centered"] = node.centered if "centered" in node else false
		"CharacterBody2D":
			props["velocity"] = str(node.velocity) if "velocity" in node else "N/A"
		"TileMap":
			props["cell_size"] = str(node.tile_set.tile_size) if node.tile_set else "N/A"
	
	return props

# =============================================================================
# B. 直接节点操作 - Ziva 风格
# =============================================================================

# 创建节点（Ziva 直接操作）
func create_node(parent_path: String = "", node_type: String = "Node2D", node_name: String = "", position: Vector2 = Vector2.ZERO) -> Dictionary:
	var scene_root = _get_scene_root()
	if not scene_root:
		return _fail("没有打开的场景")
	
	# 确定父节点
	var parent: Node = scene_root
	if not parent_path.is_empty() and parent_path != "/root":
		parent = scene_root.get_node_or_null(parent_path)
		if not parent:
			return _fail("找不到父节点: " + parent_path)
	
	# 创建节点
	var new_node: Node = _create_node_of_type(node_type)
	if not new_node:
		return _fail("不支持的节点类型: " + node_type)
	
	# 设置名称
	if not node_name.is_empty():
		new_node.name = node_name
	else:
		new_node.name = node_type + "_new"
	
	# 设置位置
	if new_node is Node2D and position != Vector2.ZERO:
		new_node.position = position
	
	# 添加到场景（关键：设置 owner）
	parent.add_child(new_node)
	new_node.owner = scene_root
	
	# 为所有子孙节点也设置 owner
	for child in new_node.get_children():
		_set_owner_recursive(child, scene_root)
	
	operation_completed.emit("create_node", true, "已创建 " + node_type + " → " + new_node.name)
	return _ok("已创建 " + node_type + "（" + new_node.name + "）到场景中")

# 删除节点
func delete_node(node_path: String) -> Dictionary:
	var scene_root = _get_scene_root()
	if not scene_root:
		return _fail("没有打开的场景")
	
	var node = scene_root.get_node_or_null(node_path)
	if not node:
		return _fail("找不到节点: " + node_path)
	
	var name = node.name
	var parent = node.get_parent()
	parent.remove_child(node)
	node.queue_free()
	
	operation_completed.emit("delete_node", true, "已删除 " + name)
	return _ok("已删除节点: " + name)

# 修改节点属性
func modify_node_property(node_path: String, property: String, value: Variant) -> Dictionary:
	var scene_root = _get_scene_root()
	if not scene_root:
		return _fail("没有打开的场景")
	
	var node = scene_root.get_node_or_null(node_path)
	if not node:
		return _fail("找不到节点: " + node_path)
	
	# 尝试设置属性
	var old_value = node.get(property) if property in node else null
	node.set(property, value)
	
	operation_completed.emit("modify_property", true, "已修改 " + node.name + "." + property + " = " + str(value))
	return _ok("已修改 " + node.name + " 的 " + property + " = " + str(value))

# 重命名节点
func rename_node(node_path: String, new_name: String) -> Dictionary:
	var scene_root = _get_scene_root()
	if not scene_root:
		return _fail("没有打开的场景")
	
	var node = scene_root.get_node_or_null(node_path)
	if not node:
		return _fail("找不到节点: " + node_path)
	
	var old_name = node.name
	node.name = new_name
	
	operation_completed.emit("rename", true, old_name + " → " + new_name)
	return _ok("已将 " + old_name + " 重命名为 " + new_name)

# 复制节点
func duplicate_node(node_path: String, new_name: String = "") -> Dictionary:
	var scene_root = _get_scene_root()
	if not scene_root:
		return _fail("没有打开的场景")
	
	var node = scene_root.get_node_or_null(node_path)
	if not node:
		return _fail("找不到节点: " + node_path)
	
	var dup = node.duplicate()
	var parent = node.get_parent()
	parent.add_child(dup)
	dup.owner = scene_root
	_set_owner_recursive(dup, scene_root)
	
	if not new_name.is_empty():
		dup.name = new_name
	
	operation_completed.emit("duplicate", true, "已复制 " + node.name + " → " + dup.name)
	return _ok("已复制节点: " + dup.name)

# 移动节点到新父节点
func reparent_node(node_path: String, new_parent_path: String) -> Dictionary:
	var scene_root = _get_scene_root()
	if not scene_root:
		return _fail("没有打开的场景")
	
	var node = scene_root.get_node_or_null(node_path)
	if not node:
		return _fail("找不到节点: " + node_path)
	
	var new_parent = scene_root.get_node_or_null(new_parent_path)
	if not new_parent:
		return _fail("找不到新父节点: " + new_parent_path)
	
	var old_parent = node.get_parent()
	old_parent.remove_child(node)
	new_parent.add_child(node)
	node.owner = scene_root
	_set_owner_recursive(node, scene_root)
	
	operation_completed.emit("reparent", true, node.name + " 移动到 " + new_parent.name)
	return _ok(node.name + " 已移动到 " + new_parent.name + " 下")

# =============================================================================
# C. TileMap 编辑 - Ziva 风格
# =============================================================================

# 设置瓦片
func tilemap_set_cell(tilemap_path: String, coords: Vector2i, tile_id: int, layer: int = 0) -> Dictionary:
	var scene_root = _get_scene_root()
	if not scene_root:
		return _fail("没有打开的场景")
	
	var tilemap = scene_root.get_node_or_null(tilemap_path)
	if not tilemap:
		return _fail("找不到 TileMap: " + tilemap_path)
	
	tilemap.set_cell(layer, coords, tile_id)
	
	operation_completed.emit("tilemap_set_cell", true, "瓦片 [layer=%d, %s] = %d" % [layer, str(coords), tile_id])
	return _ok("已在 TileMap [layer=%d] 坐标 %s 设置瓦片 %d" % [layer, str(coords), tile_id])

# 擦除瓦片
func tilemap_erase_cell(tilemap_path: String, coords: Vector2i, layer: int = 0) -> Dictionary:
	var scene_root = _get_scene_root()
	if not scene_root:
		return _fail("没有打开的场景")
	
	var tilemap = scene_root.get_node_or_null(tilemap_path)
	if not tilemap:
		return _fail("找不到 TileMap: " + tilemap_path)
	
	tilemap.erase_cell(layer, coords)
	
	operation_completed.emit("tilemap_erase", true, "已擦除瓦片 " + str(coords))
	return _ok("已擦除瓦片 [layer=%d, %s]" % [layer, str(coords)])

# 填充区域
func tilemap_fill_area(tilemap_path: String, rect: Dictionary, tile_id: int, layer: int = 0) -> Dictionary:
	var scene_root = _get_scene_root()
	if not scene_root:
		return _fail("没有打开的场景")
	
	var tilemap = scene_root.get_node_or_null(tilemap_path)
	if not tilemap:
		return _fail("找不到 TileMap: " + tilemap_path)
	
	var origin_x = rect.get("x", 0)
	var origin_y = rect.get("y", 0)
	var size_x = rect.get("width", 1)
	var size_y = rect.get("height", 1)
	
	var count = 0
	for x in range(origin_x, origin_x + size_x):
		for y in range(origin_y, origin_y + size_y):
			tilemap.set_cell(layer, Vector2i(x, y), tile_id)
			count += 1
	
	operation_completed.emit("tilemap_fill", true, "填充了 %d 个瓦片" % count)
	return _ok("已在 [layer=%d] 区域 %dx%d 填充瓦片 %d（共 %d 个）" % [layer, size_x, size_y, tile_id, count])

# 获取 TileMap 信息
func tilemap_get_info(tilemap_path: String) -> Dictionary:
	var scene_root = _get_scene_root()
	if not scene_root:
		return {}
	
	var tilemap = scene_root.get_node_or_null(tilemap_path)
	if not tilemap or not tilemap is TileMap:
		return {}
	
	var info: Dictionary = {
		"name": tilemap.name,
		"path": scene_root.get_path_to(tilemap),
		"cell_size": str(tilemap.tile_set.tile_size) if tilemap.tile_set else "N/A",
		"used_cells": tilemap.get_used_cells(0).size(),
		"layers": []
	}
	
	# 读取各层信息
	var tile_set = tilemap.tile_set
	if tile_set and "get_layer_count" in tile_set:
		var layer_count = tile_set.get_layer_count()
		for i in range(layer_count):
			var layer_info: Dictionary = {
				"layer": i,
				"name": tile_set.get_layer_name(i) if "get_layer_name" in tile_set else "Layer " + str(i),
				"used_cells": tilemap.get_used_cells(i).size()
			}
			info["layers"].append(layer_info)
	
	return info

# =============================================================================
# D. 截图功能 - Ziva 风格
# =============================================================================

# 截取编辑器视图（Ziva 截图调试）
func capture_editor_screenshot() -> Dictionary:
	var result: Dictionary = _fail("截图失败")
	
	# 方法1：通过视口截图
	var root = Engine.get_main_loop().get_root()
	var viewport = root.get_viewport()
	var size = viewport.get_visible_rect().size
	var texture = viewport.get_texture()
	
	if texture:
		var image = texture.get_image()
		if image:
			_last_screenshot = image
			_last_screenshot_base64 = _image_to_base64(image)
			result = _ok("截图成功: %dx%d" % [image.get_width(), image.get_height()])
			screenshot_captured.emit({
				"width": image.get_width(),
				"height": image.get_height(),
				"base64": _last_screenshot_base64
			})
	
	return result

# 获取截图 Base64
func get_screenshot_base64() -> String:
	if _last_screenshot_base64.is_empty():
		capture_editor_screenshot()
	return _last_screenshot_base64

# 保存截图到项目
func save_screenshot_to_project(path: String) -> Dictionary:
	if not _last_screenshot:
		return _fail("没有可用的截图")
	
	var save_path = path
	if not save_path.begins_with("res://"):
		save_path = "res://" + save_path
	
	var err = _last_screenshot.save_png(save_path)
	if err == OK:
		return _ok("截图已保存: " + save_path)
	return _fail("保存失败: 错误码 " + str(err))

# =============================================================================
# E. AI 动作执行器 - Ziva 核心
# =============================================================================

# 解析 AI 返回的 JSON 动作并执行
func parse_and_execute(ai_response: String) -> Dictionary:
	var json_start = ai_response.find("{")
	var json_end = ai_response.rfind("}")
	
	if json_start == -1 or json_end == -1 or json_end < json_start:
		return _fail("未找到可执行的 JSON 动作")
	
	var json_str = ai_response.substr(json_start, json_end - json_start + 1)
	var json = JSON.parse_string(json_str)
	
	if not json or not json is Dictionary:
		return _fail("JSON 解析失败")
	
	var action = json.get("action", "")
	var results: Array = []
	var all_success = true
	var report = ""
	
	match action:
		"create_node":
			var r = create_node(
				json.get("parent", ""),
				json.get("type", "Node2D"),
				json.get("name", ""),
				json.get("position", Vector2.ZERO)
			)
			results.append(r)
			report = r["message"]
		
		"delete_node":
			var r = delete_node(json.get("node_path", ""))
			results.append(r)
			report = r["message"]
		
		"modify_property":
			var r = modify_node_property(
				json.get("node_path", ""),
				json.get("property", ""),
				json.get("value", "")
			)
			results.append(r)
			report = r["message"]
		
		"tilemap_set_cell":
			var coords_data = json.get("coords", [0, 0])
			var coords = Vector2i(coords_data[0], coords_data[1]) if coords_data is Array else Vector2i(0, 0)
			var r = tilemap_set_cell(
				json.get("tilemap", ""),
				coords,
				json.get("tile_id", -1),
				json.get("layer", 0)
			)
			results.append(r)
			report = r["message"]
		
		"tilemap_fill":
			var rect = json.get("rect", {})
			var r = tilemap_fill_area(
				json.get("tilemap", ""),
				rect,
				json.get("tile_id", -1),
				json.get("layer", 0)
			)
			results.append(r)
			report = r["message"]
		
		"screenshot":
			var r = capture_editor_screenshot()
			results.append(r)
			report = r["message"] + "\n\n📸 已捕获编辑器截图，可发送给 AI 分析"
		
		"show_in_editor":
			var node_path = json.get("node_path", "")
			var r = _select_node_in_editor(node_path)
			results.append(r)
			report = r["message"]
		
		"multi":
			# 批量动作
			var actions: Array = json.get("actions", [])
			for act in actions:
				var r = parse_and_execute(JSON.stringify(act))
				results.append(r)
				if not r["success"]:
					all_success = false
		
		_:
			return _fail("未知动作: " + action)
	
	# 检查整体结果
	for r in results:
		if not r.get("success", false):
			all_success = false
			break
	
	return {
		"success": all_success,
		"action": action,
		"message": report,
		"results": results
	}

# 在编辑器中选中节点
func _select_node_in_editor(node_path: String) -> Dictionary:
	var scene_root = _get_scene_root()
	if not scene_root:
		return _fail("没有打开的场景")
	
	var node = scene_root.get_node_or_null(node_path)
	if not node:
		return _fail("找不到节点: " + node_path)
	
	var selection = _get_editor_selection()
	if selection:
		selection.clear()
		selection.add_node(node)
	
	return _ok("已在编辑器中选中: " + node.name)

# =============================================================================
# F. 辅助方法
# =============================================================================

func _get_scene_root() -> Node:
	if Engine.is_editor_hint():
		var editor_data = Engine.get_main_loop()
		if editor_data and editor_data.has_method("get_editor_data"):
			var root = editor_data.get_editor_data().get_edited_scene_root()
			if root:
				return root
	# 备选：查找场景根节点
	var root_node = Engine.get_main_loop().get_root()
	for child in root_node.get_children():
		if child.name != "GameAIHandler" and child.name != "EditorAgent":
			var scene_path = child.get_scene_file_path()
			if not scene_path.is_empty():
				return child
	return null

func _get_editor_selection():
	if Engine.is_editor_hint():
		return EditorInterface.get_selection()
	return null

func _get_editor_output_text() -> String:
	# 尝试从 EditorNode 获取 Output 面板文本
	var editor_root = Engine.get_main_loop().get_root()
	for node in editor_root.get_children():
		if "Output" in node.name or "Console" in node.name:
			if "get_text" in node:
				return node.get("text") if "text" in node else ""
	return ""

func _get_project_path() -> String:
	if ProjectSettings:
		return ProjectSettings.globalize_path("res://")
	return "未知"

func _get_engine_version() -> String:
	return Engine.get_version_info()["string"]

func _get_autoloads() -> Array:
	var autoloads: Array = []
	if ProjectSettings:
		for i in range(20):
			var name = ProjectSettings.get_setting("autoload/param_%d/name" % i) if ProjectSettings else ""
			if not name.is_empty():
				autoloads.append(name)
	return autoloads

func _count_descendants(node: Node) -> int:
	var count = 0
	for child in node.get_children():
		count += 1 + _count_descendants(child)
	return count

func _create_node_of_type(type: String) -> Node:
	type = type.to_lower()
	match type:
		"node2d": return Node2D.new()
		"node3d", "spatial": return Node3D.new()
		"sprite2d": return Sprite2D.new()
		"sprite3d": return Sprite3D.new()
		"characterbody2d": return CharacterBody2D.new()
		"characterbody3d": return CharacterBody3D.new()
		"rigidbody2d": return RigidBody2D.new()
		"rigidbody3d": return RigidBody3D.new()
		"area2d": return Area2D.new()
		"area3d": return Area3D.new()
		"tilemap": return TileMap.new()
		"collisionshape2d": return CollisionShape2D.new()
		"collisionpolygon2d": return CollisionPolygon2D.new()
		"navigationregion2d": return NavigationRegion2D.new()
		"navigationagent2d": return NavigationAgent2D.new()
		"camera2d": return Camera2D.new()
		"camera3d": return Camera3D.new()
		"light2d": return DirectionalLight2D.new()
		"directionallight": return DirectionalLight3D.new()
		"omnilight": return OmniLight3D.new()
		"spotlight": return SpotLight3D.new()
		"label2d": return Label.new()
		"richtextlabel": return RichTextLabel.new()
		"control", "canvasitem": return Control.new()
		"button": return Button.new()
		"textedit": return TextEdit.new()
		"lineedit": return LineEdit.new()
		"panel": return Panel.new()
		"panelcontainer": return PanelContainer.new()
		"animationplayer": return AnimationPlayer.new()
		"animatedsprite2d": return AnimatedSprite2D.new()
		"cpuparticles2d": return CPUParticles2D.new()
		"audiostreamplayer": return AudioStreamPlayer.new()
		"timer": return Timer.new()
		"visibilitynotifier2d": return VisibilityNotifier2D.new()
		"YSort2D": return YSort2D.new()
	return Node2D.new()

func _set_owner_recursive(node: Node, owner: Node) -> void:
	node.owner = owner
	for child in node.get_children():
		_set_owner_recursive(child, owner)

func _image_to_base64(img: Image) -> String:
	var buffer = img.save_png_to_buffer()
	return buffer.get_string_from_utf8()

func _ok(msg: String) -> Dictionary:
	return {"success": true, "message": msg}

func _fail(msg: String) -> Dictionary:
	return {"success": false, "message": msg}
