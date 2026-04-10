extends PanelContainer

# 主面板 - AI对话界面 v2.0
# 极简设计：对话框 + 快捷按钮
# 双语支持

var config: Node

# UI 节点引用（匹配 main_panel.tscn v2.0）
@onready var model_label: Label = $Margin/VBox/Header/HBox/ModelLabel
@onready var status_icon: Label = $Margin/VBox/Header/HBox/StatusIcon
@onready var config_btn: Button = $Margin/VBox/Header/HBox/ConfigBtn
@onready var chat_container: VBoxContainer = $Margin/VBox/ChatScroll/ChatContainer
@onready var input: TextEdit = $Margin/VBox/InputPanel/VBox/Input
@onready var send_btn: Button = $Margin/VBox/InputPanel/VBox/HBox/SendBtn
@onready var clear_btn: Button = $Margin/VBox/InputPanel/VBox/HBox/ClearBtn
@onready var undo_btn: Button = $Margin/VBox/InputPanel/VBox/HBox/UndoBtn
@onready var apply_btn: Button = $Margin/VBox/InputPanel/VBox/HBox/ApplyBtn

# 核心模块引用
var ai_handler: Node
var code_applier: Node
var code_generator: Node

# 状态
var _selected_code: String = ""
var _is_first_message: bool = true

func _ready() -> void:
	# 按钮信号
	send_btn.pressed.connect(_on_send)
	clear_btn.pressed.connect(_on_clear)
	undo_btn.pressed.connect(_on_undo)
	apply_btn.pressed.connect(_on_apply)
	config_btn.pressed.connect(_on_config)
	input.text_submitted.connect(_on_input_submitted)

	_setup_modules()
	_update_status()
	_update_apply_btn()

# ==================== 模块初始化 ====================

func _setup_modules() -> void:
	ai_handler = get_node_or_null("/root/GameAIHandler")
	code_applier = get_node_or_null("/root/CodeApplier")
	code_generator = get_node_or_null("/root/CodeGenerator")

	if ai_handler:
		ai_handler.thinking_started.connect(_on_thinking_started)
		ai_handler.thinking_finished.connect(_on_thinking_finished)
		ai_handler.errorOccurred.connect(_on_error)

	if code_applier:
		code_applier.history_updated.connect(_on_history_updated)
		code_applier.code_applied.connect(_on_code_applied)
		code_applier.preview_requested.connect(_on_preview_requested)

	load_config()

func load_config() -> Dictionary:
	var config_path = "user://ai_config.json"
	if FileAccess.file_exists(config_path):
		var file = FileAccess.open(config_path, FileAccess.READ)
		if file:
			var json = JSON.parse_string(file.get_as_text())
			file.close()
			if json and json is Dictionary:
				if ai_handler:
					ai_handler.configure(json)
				update_status_from_config(json)
				return json
	return {}

func update_status_from_config(cfg: Dictionary) -> void:
	var model_type = cfg.get("model_type", "")
	match model_type:
		"deepseek": model_label.text = "DeepSeek V3"
		"claude": model_label.text = "Claude 3.5"
		"gpt": model_label.text = "GPT-4o"
		"local": model_label.text = "本地模型"
		_: model_label.text = "未配置"

# ==================== 状态更新 ====================

func _update_status() -> void:
	status_icon.text = "⏸️"

func _update_apply_btn() -> void:
	if code_applier and not code_applier.pending_blocks.is_empty():
		var count = code_applier.pending_blocks.size()
		apply_btn.text = "✅ 应用代码 (%d)" % count
		apply_btn.disabled = false
	else:
		apply_btn.text = "✅ 应用代码"
		apply_btn.disabled = true

# ==================== 发送消息 ====================

func _on_input_submitted(text: String) -> void:
	_on_send()

func _on_send() -> void:
	var text = input.text.strip_edges()
	if text.is_empty():
		return

	# 提取代码块（用于解释/优化）
	_extract_code_from_text(text)

	add_user_message(text)
	input.text = ""

	var special_response = _check_special_command(text)
	if special_response:
		add_assistant_message(special_response)
		return

	if ai_handler:
		_is_first_message = false
		ai_handler.process_message(text)
	else:
		add_assistant_message("⚠️ AI处理器未加载，请先点击「配置」设置AI模型")

# 提取代码块用于解释/优化
func _extract_code_from_text(text: String) -> void:
	var code_start = text.find("```")
	if code_start == -1:
		return
	var lang_end = text.find("\n", code_start + 3)
	if lang_end == -1:
		return
	var code_content_start = lang_end + 1
	var code_end = text.find("```", code_content_start)
	if code_end == -1:
		return
	_selected_code = text.substr(code_content_start, code_end - code_content_start).strip_edges()

# ==================== 特殊命令 ====================

func _check_special_command(text: String) -> String:
	var lower = text.to_lower()

	# 帮助
	if lower == "帮助" or lower == "help":
		return _get_help_text()

	# 解释代码
	if lower == "解释代码" or lower == "解释":
		if _selected_code.is_empty():
			return "📋 请先在输入框粘贴要解释的代码，然后输入「解释代码」"
		if ai_handler:
			ai_handler.analyze_code(_selected_code, "explain")
			return "🔍 正在分析代码..."
		return "⚠️ AI处理器未加载"

	# 优化代码
	if lower == "优化代码" or lower == "优化":
		if _selected_code.is_empty():
			return "📋 请先在输入框粘贴要优化的代码，然后输入「优化代码」"
		if ai_handler:
			ai_handler.analyze_code(_selected_code, "optimize")
			return "🔧 正在优化代码..."
		return "⚠️ AI处理器未加载"

	# 撤销
	if lower == "撤销" or lower == "undo":
		return _on_undo()

	# 预览
	if lower.begins_with("预览"):
		return _on_preview_all()

	# 应用代码
	if lower == "应用" or lower == "应用代码" or lower == "apply":
		return _on_apply()

	# 跳过
	if lower == "跳过" or lower == "skip":
		return _on_skip()

	# 扫描项目
	if lower == "扫描项目" or lower == "项目结构":
		_on_scan_project()
		return "⏳ 正在扫描项目..."

	# 今日学习
	if lower == "今日学习" or lower == "学习":
		_on_today_learning()
		return ""

	# 知识库
	if lower == "知识库" or lower == "知识":
		_on_open_knowledge()
		return ""

	# 快捷键
	if lower == "快捷键" or lower == "shortcuts":
		return _get_shortcuts_text()

	return ""

# ==================== 按钮事件 ====================

func _on_config() -> void:
	if not config:
		var cfg_scene = preload("res://addons/game_ai_assistant/ui/config_dialog.tscn")
		config = cfg_scene.instantiate()
		get_node("/root").add_child(config)
	config.popup_centered()

func _on_clear() -> void:
	# 清空对话（保留欢迎消息）
	for child in chat_container.get_children():
		if child.name != "WelcomeMsg":
			child.queue_free()
	_is_first_message = true

func _on_undo() -> String:
	if not code_applier:
		return "⚠️ 代码应用器未加载"
	var success = code_applier.undo()
	if success:
		return "↩️ 已撤销上一次操作"
	return "⚠️ 没有可撤销的操作"

func _on_apply() -> String:
	if not code_applier:
		return "⚠️ 代码应用器未加载"
	if code_applier.pending_blocks.is_empty():
		return "📋 没有待应用的代码"
	var results = code_applier.apply_all()
	var report = _generate_apply_report(results)
	code_applier.pending_blocks.clear()
	_update_apply_btn()
	return report

func _on_preview_all() -> String:
	if not code_applier:
		return "⚠️ 代码应用器未加载"
	if code_applier.pending_blocks.is_empty():
		return "📋 没有待预览的代码"
	var blocks = code_applier.pending_blocks
	var report = "📋 代码预览（共 %d 个）:\n\n" % blocks.size()
	for i in range(blocks.size()):
		var block = blocks[i]
		var file_name = block.get("file_name", "未知.gd")
		var code = block.get("code", "")
		var lines = code.split("\n").size()
		report += "[%d] 📄 %s (%d行)\n" % [i + 1, file_name, lines]
		report += "━━━━━━━━━━━━━━━━━━━━━\n"
		report += code.substr(0, 300)
		if code.length() > 300:
			report += "\n... (省略 %d 行)" % (lines - 15)
		report += "\n━━━━━━━━━━━━━━━━━━━━━\n\n"
	report += "💡 输入「应用」确认应用全部代码"
	return report

func _on_skip() -> String:
	if not code_applier:
		return ""
	var count = code_applier.pending_blocks.size()
	code_applier.pending_blocks.clear()
	_update_apply_btn()
	return "⏭️ 已跳过 %d 个代码块" % count

func _on_scan_project() -> void:
	var reader = get_node_or_null("/root/ProjectReader")
	if not reader:
		add_assistant_message("⚠️ 项目读取器未加载")
		return
	add_assistant_message("⏳ 正在扫描项目...")
	var result = reader.scan_project()
	add_assistant_message(result)

func _on_today_learning() -> void:
	var learning = get_node_or_null("/root/DailyLearning")
	if not learning:
		add_assistant_message("⚠️ 每日学习模块未加载")
		return
	var report = learning.generate_learning_report()
	add_assistant_message(report)

func _on_open_knowledge() -> void:
	var kb = get_node_or_null("/root/KnowledgeBase")
	if not kb:
		add_assistant_message("⚠️ 知识库模块未加载")
		return
	var report = kb.generate_report()
	add_assistant_message(report)
	add_assistant_message("💡 搜索知识: 输入「知识:关键词」\n📝 添加知识: 输入「添加知识:标题|内容」")

# ==================== AI 事件回调 ====================

func _on_thinking_started() -> void:
	status_icon.text = "🤔"
	send_btn.disabled = true
	undo_btn.disabled = true

func _on_thinking_finished(response: String) -> void:
	status_icon.text = "✅"
	send_btn.disabled = false
	undo_btn.disabled = false
	parse_and_store_codes(response)
	add_assistant_message(response)

func _on_error(error: String) -> void:
	status_icon.text = "❌"
	send_btn.disabled = false
	undo_btn.disabled = false
	add_assistant_message("⚠️ " + error)

func _on_history_updated(undo_count: int, redo_count: int) -> void:
	undo_btn.text = "↩️ 撤销 (%d)" % undo_count if undo_count > 0 else "↩️ 撤销"

func _on_code_applied(file_path: String, success: bool, message: String) -> void:
	_update_apply_btn()

func _on_preview_requested(blocks: Array) -> void:
	_update_apply_btn()

# ==================== 消息显示 ====================

func add_user_message(text: String) -> void:
	_clear_welcome()
	_add_message(text, Color(0.2, 0.6, 1.0), "👤 你")

func add_assistant_message(text: String) -> void:
	_clear_welcome()
	_add_message(text, Color(1.0, 0.85, 0.2), "🤖 助手")

func _add_message(text: String, color: Color, sender: String) -> void:
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_stylebox(Color(0.15, 0.15, 0.2, 0.8)))

	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	var sender_label = Label.new()
	sender_label.text = sender
	sender_label.add_theme_color_override("font_color", color)
	sender_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(sender_label)

	var content = RichTextLabel.new()
	content.bbcode_enabled = true
	content.fit_content = true
	content.custom_minimum_size.y = 0
	content.text = _format_code_blocks(text)
	vbox.add_child(content)

	chat_container.add_child(panel)

	# 自动滚动到底部
	await get_tree().process_frame
	var scroll = $Margin/VBox/ChatScroll
	scroll.scroll_vertical = scroll.get_node("^").get_v_scroll_position() if scroll.has_node("^") else 999999

func _format_code_blocks(text: String) -> String:
	# 简单处理：将代码块用不同颜色显示
	var result = text
	var code_start = result.find("```")
	while code_start != -1:
		var code_end = result.find("```", code_start + 3)
		if code_end == -1:
			break
		var lang_line = result.substr(code_start + 3, code_end - code_start - 3)
		var code_content = ""
		var newline_pos = lang_line.find("\n")
		if newline_pos != -1:
			code_content = lang_line.substr(newline_pos + 1)
		else:
			code_content = lang_line
		result = result.replace("```" + lang_line + "```", "[color=#98FB98]" + code_content + "[/color]")
		code_start = result.find("```")
	return result

func _clear_welcome() -> void:
	if _is_first_message:
		var welcome = chat_container.get_node_or_null("WelcomeMsg")
		if welcome:
			welcome.visible = false
		_is_first_message = false

func _make_stylebox(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	return style

# ==================== 代码解析 ====================

func parse_and_store_codes(response: String) -> void:
	if not code_applier:
		return
	var code_blocks = code_applier.parse_code_blocks(response)
	if not code_blocks.is_empty():
		code_applier.set_pending_blocks(code_blocks)
		var hint = "📋 检测到 %d 个代码块\n" % code_blocks.size()
		hint += "• 「预览」查看详情\n"
		hint += "• 「应用」确认应用\n"
		hint += "• 「跳过」放弃"
		add_assistant_message(hint)
		_update_apply_btn()

func _generate_apply_report(results: Array) -> String:
	var success = 0
	var failed = 0
	var report = "📋 应用结果:\n"
	for r in results:
		if r.get("success", false):
			success += 1
			report += "✅ %s\n" % r.get("file_name", "未知")
		else:
			failed += 1
			report += "❌ %s: %s\n" % [r.get("file_name", "未知"), r.get("message", "")]
	return report

# ==================== 帮助文本 ====================

func _get_help_text() -> String:
	return """🐙 游戏AI助手 - 帮助

━━━ 常用功能 ━━━
• 直接说话就能让AI帮你写代码
• 「写个玩家跳跃脚本」
• 「帮我找个2D平台素材」
• 「解释这段代码」（先粘贴代码再输入）

━━━ 快捷命令 ━━━
• 撤销 - 回退上一次操作
• 预览 - 查看待应用代码
• 应用 - 确认应用所有代码
• 跳过 - 放弃待应用代码

━━━ 高级功能 ━━━
• 扫描项目 - 查看项目结构
• 今日学习 - 每天学一点
• 知识库 - 管理个人知识

━━━ 配置 ━━━
• 点击右上角「配置」设置AI模型
• 推荐使用 DeepSeek（免费额度）
"""

func _get_shortcuts_text() -> String:
	return """⌨️ 快捷键（F1-F6）
━━━━━━━━━━━━━━━━━━━━
F1 - 切换助手面板
F2 - 快速搜索素材
F3 - 快速生成代码
F4 - 截取场景图
F5 - 今日学习
F6 - 打开知识库
"""
