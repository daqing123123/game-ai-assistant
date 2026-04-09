extends Node

# 代码应用器 - 应用代码并管理撤销历史
# v1.4: 添加确认机制和预览功能

signal code_applied(file_path: String, success: bool, message: String)
signal undo_performed(success: bool, message: String)
signal redo_performed(success: bool, message: String)
signal history_updated(history_count: int, redo_count: int)
signal preview_requested(blocks: Array)  # 预览请求信号
signal confirm_requested(action: String, data: Dictionary, callback: Callable)  # 确认请求信号

# 撤销历史
var undo_stack: Array = []
var redo_stack: Array = []
const MAX_HISTORY = 50

# 待应用代码（用于预览）
var pending_blocks: Array = []

# 备份目录
var backup_dir: String = "user://code_backups/"

# 确认设置
var confirm_before_apply: bool = true  # 应用前确认
var confirm_before_overwrite: bool = true  # 覆盖前确认
var confirm_before_delete: bool = true  # 删除前确认

func _ready() -> void:
	_ensure_backup_dir()
	load_settings()
	print("↩️ 代码应用器已就绪 (确认机制已启用)")

func _ensure_backup_dir() -> void:
	if not DirAccess.dir_exists_absolute(backup_dir):
		DirAccess.make_dir_recursive_absolute(backup_dir)

func load_settings() -> void:
	var config_path = "user://ai_config.json"
	if FileAccess.file_exists(config_path):
		var file = FileAccess.open(config_path, FileAccess.READ)
		if file:
			var json = JSON.parse_string(file.get_as_text())
			file.close()
			if json and json is Dictionary:
				confirm_before_apply = json.get("confirm_apply", true)
				confirm_before_overwrite = json.get("confirm_overwrite", true)
				confirm_before_delete = json.get("confirm_delete", true)

# ==================== 预览功能 ====================

# 设置待预览的代码块
func set_pending_blocks(blocks: Array) -> void:
	pending_blocks = blocks
	preview_requested.emit(blocks)

# 获取预览报告
func generate_preview_report() -> String:
	if pending_blocks.is_empty():
		return "⚠️ 没有待应用的代码"
	
	var report = """
📋 代码预览
━━━━━━━━━━━━━━━━━━━━━━━

📊 共 %d 个代码块:
""" % pending_blocks.size()
	
	for i in range(pending_blocks.size()):
		var block = pending_blocks[i]
		var file_name = block.get("file_name", "未知")
		var code = block.get("code", "")
		var lines = code.split("\n").size()
		
		report += """

[%d] 📄 %s
   📏 %d 行代码
""" % [i + 1, file_name, lines]
	
	report += """
━━━━━━━━━━━━━━━━━━━━━━━

💡 操作选项:
• 「应用代码」- 应用所有代码
• 「应用 1」- 只应用第1个
• 「跳过」- 放弃当前代码
• 「撤销」- 撤销上一次操作
"""
	
	return report

# ==================== 单个代码块预览 ====================

func preview_single_block(index: int) -> String:
	if index < 0 or index >= pending_blocks.size():
		return "⚠️ 无效的索引: %d" % index
	
	var block = pending_blocks[index]
	var file_name = block.get("file_name", "未知")
	var code = block.get("code", "")
	var directory = block.get("directory", "res://scripts/")
	
	var file_path = directory + "/" + file_name if not directory.ends_with("/") else directory + file_name
	
	var report = """
📄 代码预览 [%d/%d]
━━━━━━━━━━━━━━━━━━━━━━━

📁 文件: %s
📂 路径: %s
📏 行数: %d

━━━━━━━━━━━━━━━━━━━━━━━
代码内容:
━━━━━━━━━━━━━━━━━━━━━━━
%s
━━━━━━━━━━━━━━━━━━━━━━━
""" % [index + 1, pending_blocks.size(), file_name, file_path, code.split("\n").size(), code]
	
	# 检查文件是否存在
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var original = file.get_as_text()
			file.close()
			
			report += """

⚠️ 此操作将覆盖现有文件！
   现有代码行数: %d 行

输入「应用 %d」确认覆盖
""" % [original.split("\n").size(), index + 1]
	
	return report

# ==================== 确认机制 ====================

# 请求确认
func request_confirm(action: String, data: Dictionary, callback: Callable) -> void:
	confirm_requested.emit(action, data, callback)

# 内部确认回调处理
func _on_confirm_yes(action: String, data: Dictionary) -> void:
	match action:
		"apply_single":
			_apply_single_with_backup(
				data.get("code", ""),
				data.get("file_name", ""),
				data.get("directory", "res://scripts/")
			)
		"apply_all":
			_apply_all_confirmed()
		"overwrite":
			_apply_single_with_backup(
				data.get("code", ""),
				data.get("file_name", ""),
				data.get("directory", "res://scripts/")
			)
		"delete":
			_delete_file_confirmed(data.get("file_path", ""))

# ==================== 应用单个代码块（带确认） ====================

func apply_single_block(index: int) -> Dictionary:
	if index < 0 or index >= pending_blocks.size():
		var result = {"success": false, "message": "无效的索引: %d" % index}
		code_applied.emit("", false, result["message"])
		return result
	
	var block = pending_blocks[index]
	return apply_code(
		block.get("code", ""),
		block.get("file_name", ""),
		block.get("directory", "res://scripts/")
	)

# 应用单个代码块（直接，无确认）
func apply_code(code: String, file_name: String, directory: String = "res://scripts/") -> Dictionary:
	var result = {
		"success": false,
		"file_path": "",
		"message": "",
		"backup_path": ""
	}
	
	if code.is_empty() or file_name.is_empty():
		result["message"] = "⚠️ 代码或文件名为空"
		code_applied.emit(result["file_path"], false, result["message"])
		return result
	
	# 确保目录存在
	if not _ensure_directory(directory):
		result["message"] = "❌ 目录不存在且无法创建: " + directory
		code_applied.emit(result["file_path"], false, result["message"])
		return result
	
	var file_path = directory + "/" + file_name if not directory.ends_with("/") else directory + file_name
	
	# 如果文件存在，检查是否需要覆盖确认
	var original_content = ""
	var has_backup = false
	
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			original_content = file.get_as_text()
			file.close()
		
		# 如果内容相同，跳过
		if original_content.strip_edges() == code.strip_edges():
			result["success"] = true
			result["file_path"] = file_path
			result["message"] = "ℹ️ 文件内容相同，无需更新: %s" % file_name
			code_applied.emit(result["file_path"], true, result["message"])
			return result
		
		# 需要覆盖确认
		if confirm_before_overwrite:
			result["message"] = "⚠️ 将覆盖文件: %s\n\n新代码:\n%s\n\n输入「覆盖」确认或「取消」" % [file_name, code.substr(0, min(500, code.length()))]
			code_applied.emit(result["file_path"], false, result["message"])
			
			# 存储待确认的操作
			store_pending_overwrite(code, file_name, directory, original_content)
			return result
		
		# 创建备份
		var backup_path = _create_backup(file_path, original_content)
		if backup_path != "":
			result["backup_path"] = backup_path
			has_backup = true
	
	# 写入新代码
	var write_result = _write_code(file_path, code)
	
	if write_result["success"]:
		# 添加到撤销历史
		var history_entry = {
			"action": "apply",
			"file_path": file_path,
			"file_name": file_name,
			"directory": directory,
			"new_code": code,
			"original_code": original_content if has_backup else "",
			"has_backup": has_backup,
			"backup_path": result["backup_path"],
			"timestamp": Time.get_datetime_string_from_system()
		}
		
		_add_to_undo_stack(history_entry)
		redo_stack.clear()
		
		result["success"] = true
		result["file_path"] = file_path
		result["message"] = "✅ 代码已保存到: %s" % file_name
		
		# 从待处理列表移除
		_remove_from_pending(file_name)
	else:
		result["message"] = "❌ 写入失败: " + write_result["error"]
	
	code_applied.emit(result["file_path"], result["success"], result["message"])
	_notify_history_update()
	
	return result

# 内部应用（带备份）
func _apply_single_with_backup(code: String, file_name: String, directory: String) -> Dictionary:
	var result = {
		"success": false,
		"file_path": "",
		"message": "",
		"backup_path": ""
	}
	
	var file_path = directory + "/" + file_name if not directory.ends_with("/") else directory + file_name
	
	# 备份原内容
	var original_content = ""
	var has_backup = false
	
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			original_content = file.get_as_text()
			file.close()
		
		var backup_path = _create_backup(file_path, original_content)
		if backup_path != "":
			result["backup_path"] = backup_path
			has_backup = true
	
	# 写入
	var write_result = _write_code(file_path, code)
	
	if write_result["success"]:
		var history_entry = {
			"action": "apply",
			"file_path": file_path,
			"file_name": file_name,
			"directory": directory,
			"new_code": code,
			"original_code": original_content,
			"has_backup": has_backup,
			"backup_path": result["backup_path"],
			"timestamp": Time.get_datetime_string_from_system()
		}
		
		_add_to_undo_stack(history_entry)
		redo_stack.clear()
		
		result["success"] = true
		result["file_path"] = file_path
		result["message"] = "✅ 代码已保存: %s" % file_name
	else:
		result["message"] = "❌ 写入失败: " + write_result["error"]
	
	code_applied.emit(result["file_path"], result["success"], result["message"])
	_notify_history_update()
	
	return result

# ==================== 批量应用（带确认） ====================

func apply_multiple_blocks(blocks: Array) -> Array:
	if blocks.is_empty():
		var results = [{"success": false, "message": "没有代码块"}]
		code_applied.emit("", false, "没有代码块")
		return results
	
	# 如果启用了确认，显示预览并请求确认
	if confirm_before_apply and blocks.size() > 1:
		set_pending_blocks(blocks)
		preview_requested.emit(blocks)
		return [{"success": false, "message": "等待确认..."}]
	
	return _apply_all_without_confirm(blocks)

func _apply_all_without_confirm(blocks: Array) -> Array:
	var results = []
	
	for block in blocks:
		var code = block.get("code", "")
		var file_name = block.get("file_name", "")
		var directory = block.get("directory", "res://scripts/")
		
		if not code.is_empty() and not file_name.is_empty():
			# 跳过已存在的相同文件（不备份）
			var file_path = directory + "/" + file_name if not directory.ends_with("/") else directory + file_name
			
			if FileAccess.file_exists(file_path):
				var file = FileAccess.open(file_path, FileAccess.READ)
				if file:
					var original = file.get_as_text()
					file.close()
					if original.strip_edges() == code.strip_edges():
						results.append({
							"success": true,
							"file_path": file_path,
							"file_name": file_name,
							"message": "ℹ️ 跳过（内容相同）: %s" % file_name
						})
						continue
			
			var result = _apply_single_with_backup(code, file_name, directory)
			results.append(result)
	
	return results

func _apply_all_confirmed() -> Array:
	var results = _apply_all_without_confirm(pending_blocks)
	pending_blocks.clear()
	return results

# ==================== 确认覆盖操作 ====================

var _pending_overwrite: Dictionary = {}

func store_pending_overwrite(code: String, file_name: String, directory: String, original: String) -> void:
	_pending_overwrite = {
		"code": code,
		"file_name": file_name,
		"directory": directory,
		"original": original
	}

func confirm_overwrite() -> Dictionary:
	if _pending_overwrite.is_empty():
		var result = {"success": false, "message": "没有待确认的操作"}
		code_applied.emit("", false, result["message"])
		return result
	
	var result = _apply_single_with_backup(
		_pending_overwrite.get("code", ""),
		_pending_overwrite.get("file_name", ""),
		_pending_overwrite.get("directory", "res://scripts/")
	)
	
	_pending_overwrite.clear()
	return result

func cancel_overwrite() -> void:
	_pending_overwrite.clear()
	code_applied.emit("", true, "已取消覆盖操作")

# ==================== 删除文件（带确认） ====================

func delete_file(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		code_applied.emit(file_path, false, "文件不存在: " + file_path)
		return false
	
	# 读取内容用于撤销
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		code_applied.emit(file_path, false, "无法读取文件")
		return false
	
	var content = file.get_as_text()
	file.close()
	
	# 确认删除
	if confirm_before_delete:
		_pending_overwrite = {
			"action": "delete",
			"file_path": file_path,
			"file_name": file_path.get_file(),
			"content": content
		}
		code_applied.emit(file_path, false, "⚠️ 确认删除文件: %s？\n输入「确认删除」继续" % file_path.get_file())
		return false
	
	return _delete_file_confirmed(file_path)

func _delete_file_confirmed(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		code_applied.emit(file_path, false, "文件不存在")
		return false
	
	# 备份
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		
		_create_backup(file_path, content)
	
	# 删除
	var dir = DirAccess.open(file_path.get_base_dir())
	if dir:
		var err = dir.remove(file_path)
		if err == OK:
			# 添加到撤销历史
			var history_entry = {
				"action": "delete",
				"file_path": file_path,
				"file_name": file_path.get_file(),
				"original_code": _pending_overwrite.get("content", ""),
				"new_code": "",
				"has_backup": true,
				"timestamp": Time.get_datetime_string_from_system()
			}
			_add_to_undo_stack(history_entry)
			redo_stack.clear()
			
			code_applied.emit(file_path, true, "🗑️ 已删除: %s" % file_path.get_file())
			_notify_history_update()
			return true
	
	code_applied.emit(file_path, false, "删除失败")
	return false

# ==================== 撤销/重做 ====================

func undo() -> bool:
	if undo_stack.is_empty():
		code_applied.emit("", false, "没有可撤销的操作")
		return false
	
	var history = undo_stack.pop_back()
	var file_path = history["file_path"]
	var original_code = history["original_code"]
	
	if history["action"] == "delete" or original_code.is_empty():
		# 删除操作：需要恢复文件
		_write_code(file_path, history.get("content", ""))
		redo_stack.append(history)
		code_applied.emit(file_path, true, "↩️ 已撤销删除: %s" % history["file_name"])
		undo_performed.emit(true, "已撤销删除")
	else:
		# 恢复原代码
		var write_result = _write_code(file_path, original_code)
		if write_result["success"]:
			redo_stack.append(history)
			code_applied.emit(file_path, true, "↩️ 已撤销: %s" % history["file_name"])
			undo_performed.emit(true, "已撤销")
		else:
			code_applied.emit(file_path, false, "撤销失败: " + write_result["error"])
			undo_performed.emit(false, "撤销失败")
			return false
	
	_notify_history_update()
	return true

func redo() -> bool:
	if redo_stack.is_empty():
		code_applied.emit("", false, "没有可重做的操作")
		return false
	
	var history = redo_stack.pop_back()
	var file_path = history["file_path"]
	
	var code_to_restore = history.get("new_code", "")
	
	var write_result = _write_code(file_path, code_to_restore)
	
	if write_result["success"]:
		undo_stack.append(history)
		code_applied.emit(file_path, true, "↪️ 已重做: %s" % history["file_name"])
		redo_performed.emit(true, "已重做")
		_notify_history_update()
		return true
	else:
		code_applied.emit(file_path, false, "重做失败: " + write_result["error"])
		redo_performed.emit(false, "重做失败")
		return false

func get_history_status() -> Dictionary:
	return {
		"undo_count": undo_stack.size(),
		"redo_count": redo_stack.size(),
		"can_undo": not undo_stack.is_empty(),
		"can_redo": not redo_stack.is_empty()
	}

func get_history_list(max_items: int = 10) -> Array:
	var list = []
	
	for i in range(undo_stack.size() - 1, max(-1, undo_stack.size() - max_items - 1), -1):
		if i >= 0:
			var h = undo_stack[i]
			list.append({
				"type": "undo",
				"action": h["action"],
				"file_name": h["file_name"],
				"timestamp": h["timestamp"]
			})
	
	return list

func clear_history() -> void:
	undo_stack.clear()
	redo_stack.clear()
	_notify_history_update()
	print("🗑️ 历史记录已清除")

# ==================== 备份管理 ====================

func _create_backup(file_path: String, content: String) -> String:
	_ensure_backup_dir()
	
	var backup_name = file_path.get_file()
	var timestamp = Time.get_unix_time_from_system()
	var backup_path = backup_dir + backup_name + ".bak." + str(timestamp)
	
	var file = FileAccess.open(backup_path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
		return backup_path
	
	return ""

func cleanup_old_backups(max_backups: int = 10) -> int:
	if not DirAccess.dir_exists_absolute(backup_dir):
		return 0
	
	var dir = DirAccess.open(backup_dir)
	if not dir:
		return 0
	
	var files = dir.get_files()
	var backup_files = []
	
	for f in files:
		if f.begins_with("."):
			continue
		var full_path = backup_dir + f
		backup_files.append({
			"path": full_path,
			"modified": FileAccess.get_modified_time(full_path)
		})
	
	backup_files.sort_custom(func(a, b): return a["modified"] < b["modified"])
	
	var deleted = 0
	var to_delete = backup_files.size() - max_backups
	
	for i in range(to_delete):
		if i < backup_files.size():
			DirAccess.remove_absolute(backup_files[i]["path"])
			deleted += 1
	
	return deleted

# ==================== 辅助方法 ====================

func _ensure_directory(path: String) -> bool:
	if DirAccess.dir_exists_absolute(path):
		return true
	
	var result = DirAccess.make_dir_recursive_absolute(path)
	return result == OK

func _write_code(file_path: String, code: String) -> Dictionary:
	var result = {"success": false, "error": ""}
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(code)
		file.close()
		result["success"] = true
	else:
		result["error"] = "无法打开文件: " + file_path
	
	return result

func _add_to_undo_stack(entry: Dictionary) -> void:
	undo_stack.append(entry)
	
	while undo_stack.size() > MAX_HISTORY:
		undo_stack.pop_front()

func _notify_history_update() -> void:
	history_updated.emit(undo_stack.size(), redo_stack.size())

func _remove_from_pending(file_name: String) -> void:
	pending_blocks = pending_blocks.filter(func(b): return b.get("file_name", "") != file_name)

# ==================== 代码解析 ====================

func parse_code_blocks(text: String) -> Array:
	var blocks = []
	var lines = text.split("\n")
	var current_block = ""
	var in_code_block = false
	var code_start = -1
	
	for i in range(lines.size()):
		var line = lines[i]
		
		if line.strip_edges().begins_with("```"):
			if in_code_block:
				var block_info = _analyze_code_block(current_block)
				if not block_info["code"].is_empty():
					block_info["line_start"] = code_start
					block_info["line_end"] = i
					blocks.append(block_info)
				current_block = ""
				in_code_block = false
			else:
				in_code_block = true
				code_start = i + 1
		elif in_code_block:
			current_block += line + "\n"
	
	return blocks

func _analyze_code_block(code: String) -> Dictionary:
	var info = {
		"code": code.strip_edges(),
		"language": "",
		"file_name": "",
		"likely_name": ""
	}
	
	if "extends Node" in code or "func _ready" in code:
		info["language"] = "gdscript"
	elif "extends EditorPlugin" in code or "extends Control" in code:
		info["language"] = "gdscript"
	elif "extends MonoBehaviour" in code or "public class" in code:
		info["language"] = "csharp"
	elif "extends Node2D" in code or "extends CharacterBody2D" in code:
		info["language"] = "gdscript"
	elif "extends Spatial" in code or "extends CharacterBody" in code:
		info["language"] = "gdscript"
	
	var class_match = _extract_class_name(code)
	if class_match != "":
		info["likely_name"] = class_match
		info["file_name"] = class_match + ("." + info["language"] if info["language"] else ".gd")
	
	return info

func _extract_class_name(code: String) -> String:
	var patterns = ["class (\\w+)", "public class (\\w+)", "extends (\\w+)"]
	
	for pattern in patterns:
		var regex = RegEx.new()
		if regex.compile(pattern) == OK:
			var match = regex.search(code)
			if match:
				return match.get_string(1)
	
	return ""

# ==================== 生成报告 ====================

func generate_apply_report(results: Array) -> String:
	if results.is_empty():
		return "⚠️ 没有要应用的代码"
	
	var success = results.filter(func(r): return r.get("success", false)).size()
	var failed = results.size() - success
	
	var report = """
✅ 代码应用完成
━━━━━━━━━━━━━━━━━━━━━━━

📊 结果: %d 成功, %d 失败
""" % [success, failed]
	
	if success > 0:
		report += "\n📁 已保存文件:\n"
		for r in results:
			if r.get("success", false):
				report += "• %s\n" % r.get("file_name", "未知")
	
	if failed > 0:
		report += "\n❌ 失败文件:\n"
		for r in results:
			if not r.get("success", false):
				report += "• %s: %s\n" % [r.get("file_name", "未知"), r.get("message", "未知错误")]
	
	var status = get_history_status()
	report += """
↩️ 可撤销: %d 次 | ↪️ 可重做: %d 次
""" % [status["undo_count"], status["redo_count"]]
	
	return report
