extends PanelContainer

# 主面板 - AI对话界面 v1.5
# 添加测试生成和差异对比功能
# 双语支持

var config: Node

@onready var status_icon: Label = $Margin/VBox/StatusBar/HBox/StatusIcon
@onready var status_text: Label = $Margin/VBox/StatusBar/HBox/StatusText
@onready var model_label: Label = $Margin/VBox/StatusBar/HBox/ModelLabel
@onready var history_label: Label = $Margin/VBox/StatusBar/HBox/HistoryLabel
@onready var pending_label: Label = $Margin/VBox/StatusBar/HBox/PendingLabel
@onready var chat_container: VBoxContainer = $Margin/VBox/ChatScroll/ChatContainer
@onready var input: TextEdit = $Margin/VBox/InputArea/HBox/InputScroll/Input
@onready var send_btn: Button = $Margin/VBox/InputArea/HBox/VBox/SendBtn
@onready var clear_btn: Button = $Margin/VBox/InputArea/HBox/VBox/ClearBtn
@onready var undo_btn: Button = $Margin/VBox/InputArea/HBox/VBox/UndoBtn
@onready var redo_btn: Button = $Margin/VBox/InputArea/HBox/VBox/RedoBtn
@onready var preview_btn: Button = $Margin/VBox/InputArea/HBox/VBox/PreviewBtn
@onready var apply_btn: Button = $Margin/VBox/InputArea/HBox/VBox/ApplyBtn
@onready var config_btn: Button = $Margin/VBox/Header/HBox/ConfigBtn
@onready var templates_btn: Button = $Margin/VBox/BottomBar/TemplatesBtn
@onready var assets_btn: Button = $Margin/VBox/BottomBar/AssetsBtn
@onready var help_btn: Button = $Margin/VBox/BottomBar/HelpBtn
@onready var project_btn: Button = $Margin/VBox/BottomBar/ProjectBtn
@onready var learning_btn: Button = $Margin/VBox/BottomBar/LearningBtn
@onready var knowledge_btn: Button = $Margin/VBox/BottomBar/KnowledgeBtn
@onready var project_template_btn: Button = $Margin/VBox/BottomBar/ProjectTemplateBtn
@onready var scene_gen_btn: Button = $Margin/VBox/BottomBar/SceneGenBtn
@onready var debug_btn: Button = $Margin/VBox/BottomBar/DebugBtn
@onready var search_btn: Button = $Margin/VBox/BottomBar/SearchBtn

# ==================== 测试生成相关 ====================
@onready var test_btn: Button = $Margin/VBox/BottomBar/TestBtn
@onready var diff_btn: Button = $Margin/VBox/BottomBar/DiffBtn

# 状态
var pending_code_blocks: Array = []
var pending_preview_index: int = -1
var _selected_code: String = ""  # 用户选中的代码（用于解释/优化）

# ==================== 差异对比相关 ====================
var current_diff_info: Dictionary = {}
var current_original_code: String = ""
var current_new_code: String = ""
var diff_chunks: Array = []
var current_diff_index: int = -1
var is_showing_diff: bool = false

# 核心模块
var ai_handler: Node
var project_reader: Node
var code_applier: Node
var code_generator: Node
var screenshot_handler: Node
var daily_learning: Node
var knowledge_base: Node

func _ready() -> void:
	send_btn.pressed.connect(_on_send)
	clear_btn.pressed.connect(_on_clear)
	undo_btn.pressed.connect(_on_undo)
	redo_btn.pressed.connect(_on_redo)
	preview_btn.pressed.connect(_on_preview)
	apply_btn.pressed.connect(_on_apply)
	apply_btn.disabled = true
	config_btn.pressed.connect(_on_config)
	templates_btn.pressed.connect(_on_templates)
	assets_btn.pressed.connect(_on_assets)
	help_btn.pressed.connect(_on_help)
	project_btn.pressed.connect(_on_scan_project)
	learning_btn.pressed.connect(_on_today_learning)
	knowledge_btn.pressed.connect(_on_open_knowledge)
	project_template_btn.pressed.connect(_on_project_template)
	scene_gen_btn.pressed.connect(_on_scene_generation)
	
	# 测试和差异对比按钮
	test_btn.pressed.connect(_on_generate_test)
	diff_btn.pressed.connect(_on_show_diff)
	
	# 调试助手和代码搜索按钮
	debug_btn.pressed.connect(_on_debug_assist)
	search_btn.pressed.connect(_on_code_search)
	
	input.text_submitted.connect(_on_input_submitted)
	
	_setup_modules()
	_update_status()
	_update_history_label()

func _setup_modules() -> void:
	ai_handler = get_node_or_valid("/root/GameAIHandler")
	project_reader = get_node_or_valid("/root/ProjectReader")
	code_applier = get_node_or_valid("/root/CodeApplier")
	screenshot_handler = get_node_or_valid("/root/ScreenshotHandler")
	daily_learning = get_node_or_valid("/root/DailyLearning")
	knowledge_base = get_node_or_valid("/root/KnowledgeBase")
	config = get_node_or_valid("/root/GameAIConfig")
	
	if ai_handler:
		ai_handler.thinking_started.connect(_on_thinking_started)
		ai_handler.thinking_finished.connect(_on_thinking_finished)
		ai_handler.errorOccurred.connect(_on_error)
		ai_handler.code_analysis_finished.connect(_on_code_analysis_finished)
		ai_handler.test_generation_requested.connect(_on_ai_test_requested)
		ai_handler.diff_requested.connect(_on_ai_diff_requested)
	
	if code_applier:
		code_applier.history_updated.connect(_on_history_updated)
		code_applier.code_applied.connect(_on_code_applied)
		code_applier.preview_requested.connect(_on_preview_requested)
	
	# 获取代码生成器
	code_generator = get_node_or_valid("/root/CodeGenerator")
	
	load_config()

func _on_ai_test_requested(target_file: String, framework: String) -> void:
	"""处理AI触发的测试生成请求"""
	_on_generate_test_with_text("为 " + target_file + " 生成测试")

func _on_ai_diff_requested(original_code: String, new_code: String, file_path: String) -> void:
	"""处理AI触发的差异对比请求"""
	set_diff_state(original_code, new_code, file_path)

func load_config() -> Dictionary:
	var config_path = "user://ai_config.json"
	if FileAccess.file_exists(config_path):
		var file = FileAccess.open(config_path, FileAccess.READ)
		if file:
			var json = JSON.parse_string(file.get_as_text())
			file.close()
			if json and json is Dictionary:
				update_status_from_config(json)
				if ai_handler:
					ai_handler.configure(json)
				return json
	return {}

func update_status_from_config(cfg: Dictionary) -> void:
	var model_type = cfg.get("model_type", "")
	var lang = cfg.get("language", "auto")
	if lang == "auto":
		lang = "zh" if OS.get_locale_language() == "zh" else "en"
	match model_type:
		"deepseek":
			model_label.text = "DeepSeek V3"
		"claude":
			model_label.text = "Claude 3.5"
		"gpt":
			model_label.text = "GPT-4o"
		"local":
			model_label.text = "🌍 Local" if lang == "en" else "🌍 本地模型"
		_:
			model_label.text = "⚠️ Not Set" if lang == "en" else "⚠️ 未配置"

func _update_status() -> void:
	status_text.text = _tr("ready")
	status_icon.text = "⏸️"

func _tr(key: String) -> String:
	if config and config.has_method("tr"):
		return config.tr(key)
	return key

func _update_history_label() -> void:
	if code_applier:
		var status = code_applier.get_history_status()
		history_label.text = "↩️%d ↪️%d" % [status["undo_count"], status["redo_count"]]
		history_label.modulate = Color.WHITE if status["undo_count"] > 0 else Color.GRAY
		
		# 更新待应用代码指示
		_update_pending_indicator()
	else:
		history_label.text = ""
		pending_label.text = ""

func _update_pending_indicator() -> void:
	if code_applier:
		var blocks = code_applier.pending_blocks
		if not blocks.is_empty():
			pending_label.text = "📋 %d %s" % [blocks.size(), _tr("pending_blocks")]
			pending_label.modulate = Color.YELLOW
			apply_btn.disabled = false
			preview_btn.disabled = false
		else:
			pending_label.text = ""
			apply_btn.disabled = true
			preview_btn.disabled = true
	else:
		pending_label.text = ""

# ==================== 发送消息 ====================

func _on_send() -> void:
	var text = input.text.strip_edges()
	if text.is_empty():
		return
	
	# 提取代码块（用于解释/优化功能）
	_extract_code_from_text(text)
	
	add_user_message(text)
	input.text = ""
	
	var special_response = check_special_command(text)
	if special_response:
		add_assistant_message(special_response)
		return
	
	if ai_handler:
		ai_handler.process_message(text)

func _extract_code_from_text(text: String) -> void:
	"""从输入文本中提取代码块，存储到 _selected_code"""
	var code_start = text.find("```")
	if code_start != -1:
		# 找到代码块语言标识后的换行
		var lang_end = text.find("\n", code_start + 3)
		if lang_end == -1:
			return
		var code_content_start = lang_end + 1
		var code_end = text.find("```", code_content_start)
		if code_end == -1:
			return
		_selected_code = text.substr(code_content_start, code_end - code_content_start).strip_edges()
		return
	
	# 如果没有代码块格式，检查是否全是代码（多行，无中文）
	var lines = text.split("\n")
	if lines.size() > 2:
		var has_code_chars = false
		for ch in text:
			if ch == "{" or ch == "}" or ch == "(" or ch == ")" or ch == "->" or ch == "func " or ch == "var " or ch == "extends " or ch == "class ":
				has_code_chars = true
				break
		if has_code_chars:
			_selected_code = text
			return
	
	# 否则不提取代码（保持上次选择的代码）

func _on_input_submitted(text: String) -> void:
	_on_send()

func check_special_command(text: String) -> String:
	var lower = text.to_lower()
	
	# 项目模板命令
	if lower.begins_with("创建项目") or lower.begins_with("新建项目") or lower.begins_with("项目模板"):
		_on_project_template()
		return ""
	
	if lower.begins_with("创建"):
		if handle_create_template(text):
			return ""
	
	# 场景生成命令
	if lower.begins_with("生成场景") or lower.begins_with("创建场景") or lower.begins_with("场景向导"):
		_on_scene_generation()
		return ""
	
	if lower.begins_with("生成"):
		if handle_scene_generation(text):
			return ""
	
	# 代码解释命令
	if lower.begins_with("解释代码") or lower.begins_with("解释这段代码") or lower.begins_with("代码解释") or lower.begins_with("分析代码") or lower.begins_with("这段代码做了什么") or lower.begins_with("分析这段代码"):
		if ai_handler and not _selected_code.is_empty():
			add_assistant_message("🔍 正在分析代码，请稍候...")
			ai_handler.analyze_code(_selected_code, "explain")
			_selected_code = ""
			return ""  # 异步处理
		else:
			return "📋 请先在输入框中粘贴要解释的代码，然后输入「解释代码」"
	
	# 代码优化命令
	if lower.begins_with("优化代码") or lower.begins_with("优化这段代码") or lower.begins_with("代码优化") or lower.begins_with("改进代码") or lower.begins_with("如何优化") or lower.begins_with("如何改进"):
		if ai_handler and not _selected_code.is_empty():
			add_assistant_message("🔧 正在优化代码，请稍候...")
			ai_handler.analyze_code(_selected_code, "optimize")
			_selected_code = ""
			return ""  # 异步处理
		else:
			return "📋 请先在输入框中粘贴要优化的代码，然后输入「优化代码」"
	
	# 撤销/重做
	if lower.begins_with("撤销"):
		_on_undo()
		return ""
	
	if lower.begins_with("重做"):
		_on_redo()
		return ""
	
	# 预览
	if lower.begins_with("预览"):
		var parts = text.split(" ")
		if parts.size() > 1:
			var idx = parts[1].to_int() - 1
			_on_preview_index(idx)
		else:
			_on_preview_all()
		return ""
	
	# 应用
	if lower.begins_with("应用"):
		var parts = text.split(" ")
		if parts.size() > 1 and parts[1].is_valid_int():
			var idx = parts[1].to_int() - 1
			_on_apply_single(idx)
		else:
			_on_apply()
		return ""
	
	# 确认操作
	if lower.begins_with("确认") or lower.begins_with("覆盖"):
		_on_confirm()
		return ""
	
	if lower.begins_with("取消"):
		_on_cancel()
		return ""
	
	if lower.begins_with("跳过"):
		_on_skip()
		return ""
	
	if lower.begins_with("历史"):
		return _get_history_report()
	
	if lower.begins_with("扫描项目") or lower.begins_with("项目结构"):
		_on_scan_project()
		return ""
	
	if lower.begins_with("今日学习") or lower.begins_with("学习"):
		_on_today_learning()
		return ""
	
	if lower.begins_with("知识库"):
		_on_open_knowledge()
		return ""
	
	if lower.begins_with("快捷键") or lower.begins_with("帮助"):
		_on_help()
		return ""
	
	if lower.begins_with("截图"):
		_on_capture_screenshot()
		return ""
	
	if lower.begins_with("生成") and lower.contains("模板"):
		var template_name = extract_template_name(text)
		if not template_name.is_empty():
			generate_template_code(template_name)
		return ""
	
	if lower.begins_with("添加知识"):
		var parts = text.split(":", 1)
		if parts.size() > 1:
			add_knowledge_entry(parts[1].strip_edges())
		return ""
	
	if lower.begins_with("搜索知识") or lower.begins_with("查找知识"):
		var parts = text.split(":", 1)
		if parts.size() > 1:
			search_knowledge(parts[1].strip_edges())
		return ""
	
	# 测试生成命令
	if lower.begins_with("生成测试") or lower.begins_with("写单元测试") or \
	   lower.begins_with("单元测试") or lower.begins_with("写测试") or \
	   lower.begins_with("测试代码"):
		_on_generate_test_with_text(text)
		return ""
	
	# 差异对比命令
	if lower.begins_with("diff") or lower.begins_with("差异") or \
	   lower.begins_with("对比") or lower.begins_with("show diff"):
		_on_show_diff_with_text(text)
		return ""
	
	# 接受差异
	if lower.begins_with("接受") or lower.begins_with("确认") or lower == "apply":
		_on_accept_diff()
		return ""
	
	# 接受单个变更块
	if lower.begins_with("接受 ") and text.length() > 4:
		var parts = text.split(" ")
		if parts.size() > 1 and parts[1].is_valid_int():
			var idx = parts[1].to_int() - 1
			_on_accept_diff_chunk(idx)
		return ""
	
	return ""

func extract_template_name(text: String) -> String:
	var keywords = ["玩家", "敌人", "敌人ai", "子弹", "血条", "敌人", "存档", "商店", "成就", "ui"]
	for keyword in keywords:
		if text.to_lower().contains(keyword):
			return keyword
	return ""

# ==================== 预览功能 ====================

func _on_preview() -> void:
	if not code_applier or code_applier.pending_blocks.is_empty():
		add_assistant_message("⚠️ 没有待预览的代码")
		return
	_on_preview_all()

func _on_preview_all() -> void:
	if not code_applier:
		return
	
	var report = code_applier.generate_preview_report()
	add_assistant_message(report)

func _on_preview_index(index: int) -> void:
	if not code_applier or code_applier.pending_blocks.is_empty():
		add_assistant_message("⚠️ 没有待预览的代码")
		return
	
	var report = code_applier.preview_single_block(index)
	add_assistant_message(report)

func _on_preview_requested(blocks: Array) -> void:
	_update_pending_indicator()
	if not blocks.is_empty():
		add_assistant_message("📋 检测到 %d 个代码块\n输入「预览」查看详情\n输入「应用」确认应用" % blocks.size())

# ==================== 应用功能 ====================

func _on_apply() -> void:
	if not code_applier:
		add_assistant_message("⚠️ 代码应用器未加载")
		return
	
	if code_applier.pending_blocks.is_empty():
		add_assistant_message("⚠️ 没有待应用的代码")
		return
	
	add_assistant_message("⏳ 正在应用代码...")
	var results = code_applier.apply_multiple_blocks(code_applier.pending_blocks)
	
	if results.size() > 0 and results[0].get("message", "") == "等待确认...":
		return
	
	var report = code_applier.generate_apply_report(results)
	add_assistant_message(report)

func _on_apply_single(index: int) -> void:
	if not code_applier:
		return
	
	var result = code_applier.apply_single_block(index)
	if result.get("success", false):
		add_assistant_message("✅ 已应用: %s" % result.get("file_name", ""))
	else:
		add_assistant_message(result.get("message", "应用失败"))

# ==================== 确认机制 ====================

func _on_confirm() -> void:
	if not code_applier:
		return
	
	# 确认覆盖操作
	if not code_applier._pending_overwrite.is_empty():
		var result = code_applier.confirm_overwrite()
		if result.get("success", false):
			add_assistant_message("✅ 已确认覆盖")
		else:
			add_assistant_message(result.get("message", "覆盖失败"))
		return
	
	# 确认批量应用
	if not code_applier.pending_blocks.is_empty():
		var results = code_applier._apply_all_confirmed()
		var report = code_applier.generate_apply_report(results)
		add_assistant_message(report)

func _on_cancel() -> void:
	if not code_applier:
		return
	
	# 取消覆盖
	if not code_applier._pending_overwrite.is_empty():
		code_applier.cancel_overwrite()
		add_assistant_message("❌ 已取消覆盖操作")
		return
	
	# 跳过代码
	_on_skip()

func _on_skip() -> void:
	if not code_applier:
		return
	
	var count = code_applier.pending_blocks.size()
	code_applier.pending_blocks.clear()
	pending_code_blocks.clear()
	add_assistant_message("⏭️ 已跳过 %d 个代码块" % count)

# ==================== 撤销/重做 ====================

func _on_undo() -> void:
	if not code_applier:
		add_assistant_message("⚠️ 代码应用器未加载")
		return
	
	var success = code_applier.undo()
	if success:
		add_assistant_message("↩️ 已撤销上一次操作")
	else:
		add_assistant_message("⚠️ 没有可撤销的操作")

func _on_redo() -> void:
	if not code_applier:
		add_assistant_message("⚠️ 代码应用器未加载")
		return
	
	var success = code_applier.redo()
	if success:
		add_assistant_message("↪️ 已重做操作")
	else:
		add_assistant_message("⚠️ 没有可重做的操作")

func _get_history_report() -> String:
	if not code_applier:
		return "⚠️ 代码应用器未加载"
	
	var status = code_applier.get_history_status()
	var history_list = code_applier.get_history_list(5)
	
	var report = """
📜 操作历史
━━━━━━━━━━━━━━━━━━━━━━━

↩️ 可撤销: %d 次
↪️ 可重做: %d 次

最近操作:
""" % [status["undo_count"], status["redo_count"]]
	
	if history_list.is_empty():
		report += "暂无操作记录"
	else:
		for h in history_list:
			report += "• %s - %s\n" % [h["file_name"], h["timestamp"]]
	
	return report

func _on_history_updated(undo_count: int, redo_count: int) -> void:
	_update_history_label()

func _on_code_applied(file_path: String, success: bool, message: String) -> void:
	_update_history_label()

# ==================== AI事件处理 ====================

func _on_thinking_started() -> void:
	status_icon.text = "🤔"
	status_text.text = _tr("thinking")
	send_btn.disabled = true

func _on_thinking_finished(response: String) -> void:
	status_icon.text = "✅"
	status_text.text = _tr("complete")
	send_btn.disabled = false
	
	parse_and_store_codes(response)
	add_assistant_message(response)
	
	await get_tree().create_timer(2).timeout
	_update_status()

func _on_error(error: String) -> void:
	status_icon.text = "❌"
	status_text.text = _tr("error")
	send_btn.disabled = false
	add_assistant_message("⚠️ " + error)
	await get_tree().create_timer(2).timeout
	_update_status()

func _on_code_analysis_finished(response: String, analysis_type: String) -> void:
	"""代码解释/优化分析完成回调"""
	status_icon.text = "✅"
	status_text.text = _tr("complete")
	send_btn.disabled = false
	
	add_assistant_message(response)
	
	# 如果是优化结果，询问是否应用优化后的代码
	if analysis_type == "optimize":
		var hint = "\n💡 " + ("请复制上面的代码块后输入「" + _tr("apply") + "」" if get_current_lang() == "zh" else "Copy the code block above and enter 「" + _tr("apply") + "」")
		add_assistant_message(hint)
	
	await get_tree().create_timer(2).timeout
	_update_status()

func get_current_lang() -> String:
	if config and config.has_method("get_current_language"):
		return config.get_current_language()
	return "zh"

# ==================== 项目模板功能 ====================

func _on_project_template() -> void:
	if not ai_handler:
		add_assistant_message("⚠️ AI处理器未加载")
		return
	
	var template_list = ai_handler.show_project_template_list()
	add_user_message("项目模板")
	add_assistant_message(template_list)
	add_assistant_message("\n💡 输入「创建1」或「创建 2D 平台」快速选择模板")

func _on_scene_generation() -> void:
	if not ai_handler:
		add_assistant_message("⚠️ AI处理器未加载")
		return
	
	var scene_help = ai_handler.show_scene_generation_help()
	add_user_message("场景生成")
	add_assistant_message(scene_help)
	add_assistant_message("\n💡 输入「生成简单关卡」或描述你想要的场景")

# ==================== 项目模板命令处理 ====================

func handle_create_template(text: String) -> bool:
	if not text.to_lower().begins_with("创建"):
		return false
	
	if not ai_handler:
		return false
	
	var templates = ai_handler.get_project_templates()
	var lower = text.to_lower()
	
	# 数字索引匹配
	var num_match = text.substr(2).strip_edges()
	if num_match.is_valid_int():
		var idx = num_match.to_int() - 1
		if idx >= 0 and idx < templates.size():
			_create_template_by_id(templates[idx]["id"], templates[idx]["name"])
			return true
	
	# 关键字匹配
	var keywords = {
		"2d_platformer": ["2d平台", "平台跳跃", "平台"],
		"3d_fps": ["fps", "第一人称", "射击"],
		"2d_topdown_shooter": ["俯视角", "俯视射击"],
		"3d_third_person": ["第三人称", "动作"],
		"casual_puzzle": ["休闲", "益智"],
		"rpg": ["rpg", "角色扮演", "角色"]
	}
	
	for template_id in keywords:
		for kw in keywords[template_id]:
			if lower.contains(kw):
				_create_template_by_id(template_id, "")
				return true
	
	return false

func _create_template_by_id(template_id: String, template_name: String) -> void:
	if template_name.is_empty():
		var templates = ai_handler.get_project_templates()
		for t in templates:
			if t["id"] == template_id:
				template_name = t["name"]
				break
	
	add_assistant_message("⏳ 正在创建【" + template_name + "】模板...")
	
	var code_gen = get_node_or_valid("/root/CodeGenerator")
	if code_gen:
		var result = code_gen.generate_project_template(template_id, {"name": template_name})
		if result.get("success", false):
			var files = result.get("files", [])
			var report = "✅ 【" + template_name + "】模板创建成功！\n\n"
			report += "📁 生成的文件:\n"
			for f in files:
				report += "• " + f["path"] + "\n"
			
			# 应用代码
			for f in files:
				code_applier.apply_code(f["content"], f["path"].get_file(), f["path"].get_base_dir() + "/")
			
			add_assistant_message(report)
		else:
			add_assistant_message("❌ 创建失败: " + result.get("message", "未知错误"))
	else:
		add_assistant_message("⚠️ 代码生成器未加载")

# ==================== 场景生成命令处理 ====================

func handle_scene_generation(text: String) -> bool:
	var lower = text.to_lower()
	
	if not lower.begins_with("生成"):
		return false
	
	if not ai_handler or not code_applier:
		return false
	
	var scene_config = null
	
	# 简单关卡
	if lower.contains("简单关卡") or lower.contains("基础关卡"):
		scene_config = {
			"type": "platformer_level",
			"elements": [
				{"type": "player_spawn", "pos": Vector2(100, 400), "name": "PlayerSpawn"},
				{"type": "platform", "pos": Vector2(400, 500), "size": Vector2(600, 50), "name": "Ground"},
				{"type": "collectible", "pos": Vector2(300, 400), "name": "Coin1"},
				{"type": "collectible", "pos": Vector2(500, 400), "name": "Coin2"},
				{"type": "collectible", "pos": Vector2(650, 350), "name": "Coin3"},
				{"type": "enemy", "pos": Vector2(400, 460), "name": "Enemy1"},
				{"type": "goal", "pos": Vector2(750, 450), "name": "Goal"}
			]
		}
	
	# 战斗场景
	elif lower.contains("战斗") or lower.contains("arena"):
		scene_config = {
			"type": "battle_arena",
			"elements": [
				{"type": "player_spawn", "pos": Vector2(400, 300), "name": "PlayerSpawn"},
				{"type": "enemy", "pos": Vector2(200, 200), "name": "Enemy1"},
				{"type": "enemy", "pos": Vector2(600, 200), "name": "Enemy2"},
				{"type": "obstacle", "pos": Vector2(400, 400), "name": "Cover1"},
				{"type": "obstacle", "pos": Vector2(250, 450), "name": "Cover2"},
				{"type": "obstacle", "pos": Vector2(550, 450), "name": "Cover3"}
			]
		}
	
	# Boss房间
	elif lower.contains("boss"):
		scene_config = {
			"type": "boss_room",
			"elements": [
				{"type": "player_spawn", "pos": Vector2(100, 350), "name": "PlayerSpawn"},
				{"type": "spawner", "pos": Vector2(400, 300), "name": "BossSpawn"},
				{"type": "goal", "pos": Vector2(750, 350), "name": "Exit"}
			]
		}
	
	if scene_config:
		_generate_scene(scene_config)
		return true
	
	return false

func _generate_scene(config: Dictionary) -> void:
	add_assistant_message("⏳ 正在生成场景...")
	
	var code_gen = get_node_or_valid("/root/CodeGenerator")
	if code_gen:
		var result = code_gen.generate_scene(config)
		if result.get("success", false):
			var scene_file = result.get("scene_file", "")
			var script_files = result.get("script_files", [])
			
			var report = "✅ 场景生成成功！\n\n"
			report += "📄 场景文件: " + scene_file + "\n"
			
			if script_files.size() > 0:
				report += "\n📜 关联脚本:\n"
				for f in script_files:
					report += "• " + f["path"] + "\n"
			
			add_assistant_message(report)
			
			# 保存场景文件
			for f in script_files:
				code_applier.apply_code(f["content"], f["path"].get_file(), f["path"].get_base_dir() + "/")
		else:
			add_assistant_message("❌ 场景生成失败")
	else:
		add_assistant_message("⚠️ 代码生成器未加载")

# ==================== Phase 4 功能 ====================

func _on_today_learning() -> void:
	if not daily_learning:
		add_assistant_message("⚠️ 每日学习模块未加载")
		return
	
	var report = daily_learning.generate_learning_report()
	add_assistant_message(report)

func _on_open_knowledge() -> void:
	if not knowledge_base:
		add_assistant_message("⚠️ 知识库模块未加载")
		return
	
	var report = knowledge_base.generate_report()
	add_assistant_message(report)
	add_assistant_message("💡 输入「搜索知识:关键词」搜索知识库\n输入「添加知识:标题|内容」添加条目")

func _on_capture_screenshot() -> void:
	if not screenshot_handler:
		add_assistant_message("⚠️ 截图模块未加载")
		return
	
	var image = screenshot_handler.capture_editor_viewport()
	if image:
		add_assistant_message("📸 截图已捕获!\n尺寸: %dx%d" % [image.get_width(), image.get_height()])
		add_assistant_message("💡 可以将截图发送给AI分析场景")
	else:
		add_assistant_message("❌ 截图失败")

func add_knowledge_entry(content: String) -> void:
	if not knowledge_base:
		add_assistant_message("⚠️ 知识库模块未加载")
		return
	
	var parts = content.split("|")
	if parts.size() >= 2:
		var title = parts[0].strip_edges()
		var body = parts[1].strip_edges()
		var tags = []
		if parts.size() > 2:
			tags = parts[2].strip_edges().split(",")
		
		var entry = knowledge_base.add_entry(title, body, tags)
		add_assistant_message("✅ 知识已添加!\n\n📝 %s\n%s" % [title, body])
	else:
		add_assistant_message("⚠️ 格式: 添加知识:标题|内容|标签(可选)")

func search_knowledge(query: String) -> void:
	if not knowledge_base:
		add_assistant_message("⚠️ 知识库模块未加载")
		return
	
	var results = knowledge_base.search(query)
	if results.is_empty():
		add_assistant_message("🔍 没有找到相关知识: " + query)
	else:
		var msg = "🔍 搜索结果 (%d条):\n\n" % results.size()
		for entry in results.slice(0, 5):
			msg += "📝 %s\n%s\n\n" % [entry["title"], entry["content"].substr(0, 100)]
		add_assistant_message(msg)

# ==================== 代码解析 ====================

func parse_and_store_codes(response: String) -> void:
	if not code_applier:
		return
	
	var code_blocks = code_applier.parse_code_blocks(response)
	if not code_blocks.is_empty():
		pending_code_blocks = code_blocks
		code_applier.set_pending_blocks(code_blocks)
		var hint = "\n📋 检测到 %d 个代码块\n" % code_blocks.size()
		hint += "• 输入「预览」查看详情\n"
		hint += "• 输入「预览 1」查看第1个\n"
		hint += "• 输入「应用」确认应用\n"
		hint += "• 输入「跳过」放弃代码"
		add_assistant_message(hint)

func generate_template_code(template_name: String) -> void:
	var code = ""
	match template_name:
		"玩家":
			code = """extends CharacterBody2D
## 玩家角色控制器

@export var speed: float = 300.0
@export var jump_force: float = -500.0
@export var gravity: float = 980.0

func _physics_process(delta: float) -> void:
	var direction = Input.get_axis("ui_left", "ui_right")
	velocity.x = direction * speed
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_force
	velocity.y += gravity * delta
	move_and_slide()
"""
		"敌人", "敌人ai":
			code = """extends CharacterBody2D
## 敌人AI脚本

@export var speed: float = 100.0
@export var patrol_range: float = 200.0

var start_position: Vector2
var move_direction: int = 1

func _ready() -> void:
	start_position = global_position

func _physics_process(delta: float) -> void:
	velocity.x = speed * move_direction
	move_and_slide()
	if abs(global_position.x - start_position.x) > patrol_range:
		move_direction *= -1
		scale.x *= -1
"""
		"子弹":
			code = """extends Area2D
## 子弹脚本

@export var speed: float = 500.0
@export var damage: float = 10.0

func _physics_process(delta: float) -> void:
	position += transform.x * speed * delta

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemy"):
		body.take_damage(damage)
	queue_free()
"""
		_:
			add_assistant_message("未找到模板: " + template_name)
			return
	
	var file_name = "generated_" + template_name + ".gd"
	code_applier.apply_code(code, file_name, "res://scripts/")

# ==================== 测试生成功能 ====================

func _on_generate_test() -> void:
	"""显示测试生成对话框"""
	add_user_message("生成测试")
	add_assistant_message("""
🧪 测试生成功能
━━━━━━━━━━━━━━━━━━━━━━━

**使用方法:**
• 「为 XXX.gd 生成测试」- 为指定文件生成测试
• 「写单元测试」- 查看测试生成选项
• 「测试 Player.gd」- 快速生成测试

**支持的测试框架:**
• GdUnit - Godot 单元测试框架
• NUnit - Unity 单元测试框架

**测试内容:**
• 公共函数测试
• 边界条件测试
• 错误处理测试
• 集成测试

请告诉我要为哪个文件生成测试？
""")

func _on_generate_test_with_text(text: String) -> void:
	"""根据文本生成测试"""
	add_user_message(text)
	
	# 提取目标文件
	var target_file = extract_target_file(text)
	var framework = "gdunit"
	
	# 检测框架
	if text.to_lower().contains("nunit") or text.to_lower().contains("unity") or text.to_lower().contains("csharp") or text.to_lower().contains("c#"):
		framework = "nunit"
	
	if target_file.is_empty():
		add_assistant_message("""
⚠️ 请指定要生成测试的目标文件

**使用方法:**
• 「为 Player.gd 生成测试」
• 「测试 res://scripts/Enemy.gd」
• 「为 XXX.cs 生成 NUnit 测试」
""")
		return
	
	# 检查文件是否存在
	if not target_file.begins_with("res://"):
		target_file = "res://" + target_file
	
	if not FileAccess.file_exists(target_file):
		add_assistant_message("⚠️ 文件不存在: " + target_file)
		return
	
	# 读取目标文件
	var file = FileAccess.open(target_file, FileAccess.READ)
	if not file:
		add_assistant_message("⚠️ 无法读取文件: " + target_file)
		return
	
	var target_code = file.get_as_text()
	file.close()
	
	# 获取代码生成器
	if not code_generator:
		add_assistant_message("⚠️ 代码生成器未加载")
		return
	
	# 生成测试
	add_assistant_message("⏳ 正在分析代码并生成测试...")
	var result = code_generator.generate_test_code(target_code, target_file, framework)
	
	if result.get("success", false):
		var test_code = result.get("test_code", "")
		var test_path = result.get("file_path", "")
		var test_cases = result.get("test_cases", [])
		
		# 保存测试文件
		var saved = code_generator.save_test_file(test_code, test_path)
		
		if saved:
			add_assistant_message("""
✅ 测试生成完成
━━━━━━━━━━━━━━━━━━━━━━━

📁 测试文件: %s
🧪 测试框架: %s
📋 测试用例数: %d

💡 生成的测试:
• 实例创建测试
• 公共函数测试
• 边界条件测试

⚠️ 请根据实际需求完善测试用例！
""" % [test_path, framework, test_cases.size()])
		else:
			add_assistant_message("""
✅ 测试代码已生成，但保存失败

📋 测试代码:
```
%s
```
""" % test_code.substr(0, min(500, test_code.length())))
	else:
		add_assistant_message("❌ 测试生成失败")

func extract_target_file(text: String) -> String:
	"""从文本中提取目标文件"""
	var patterns = [
		"为 ", "测试 ", "为 ", "生成测试 ",
		"write test for ", "test ", "generate test "
	]
	
	var lower = text.to_lower()
	
	for pattern in patterns:
		if lower.find(pattern) != -1:
			var idx = text.find(pattern) + pattern.length()
			var remaining = text.substr(idx).strip_edges()
			
			# 提取文件名（到空格或句号为止）
			var end = remaining.find(" ")
			if end == -1:
				end = remaining.find("。")
			if end == -1:
				end = remaining.find("。")
			if end == -1:
				end = remaining.length()
			
			var file_name = remaining.substr(0, end).strip_edges()
			
			# 清理末尾的标点
			while file_name.length() > 0 and (file_name[-1] == "." or file_name[-1] == "," or file_name[-1] == " "):
				file_name = file_name.substr(0, file_name.length() - 1)
			
			if not file_name.is_empty():
				return file_name
	
	return ""

# ==================== 差异对比功能 ====================

func _on_show_diff() -> void:
	"""显示差异对比面板"""
	add_user_message("差异对比")
	
	if is_showing_diff and not current_diff_info.is_empty():
		var diff_text = code_generator.format_diff_text(current_diff_info)
		add_assistant_message(diff_text)
	else:
		add_assistant_message("""
📊 差异对比功能
━━━━━━━━━━━━━━━━━━━━━━━

**使用方法:**
• 「差异」- 查看当前差异
• 「diff」- 显示差异对比
• 「对比」- 查看代码变化

**操作选项:**
• 「接受」- 应用所有修改
• 「接受 1」- 只接受第1个变更块
• 「取消」- 放弃修改

当代码被修改时会自动显示差异对比。
""")

func _on_show_diff_with_text(text: String) -> void:
	"""根据文本显示差异"""
	add_user_message(text)
	
	if current_diff_info.is_empty():
		add_assistant_message("⚠️ 没有可对比的差异\n\n请先应用代码修改，系统会自动记录差异。")
		return
	
	var diff_text = code_generator.format_diff_text(current_diff_info)
	add_assistant_message(diff_text)

func _on_accept_diff() -> void:
	"""接受所有差异"""
	add_user_message("接受")
	
	if current_diff_info.is_empty():
		add_assistant_message("⚠️ 没有可接受的差异")
		return
	
	var file_path = current_diff_info.get("file_path", "")
	var new_code = current_diff_info.get("new_code", "")
	var original = current_diff_info.get("original", "")
	
	var result = code_generator.apply_diff_to_file(file_path, original, new_code)
	
	if result.get("success", false):
		add_assistant_message("✅ 已应用所有修改\n\n📁 " + file_path)
		
		# 清除差异状态
		current_diff_info.clear()
		current_original_code = ""
		current_new_code = ""
		diff_chunks.clear()
		is_showing_diff = false
		
		# 刷新编辑器
		if Engine.is_editor_hint():
			EditorInterface.reload_plugin()
	else:
		add_assistant_message("❌ " + result.get("message", "应用失败"))

func _on_accept_diff_chunk(index: int) -> void:
	"""接受单个差异块"""
	add_user_message("接受 " + str(index + 1))
	
	var chunks = current_diff_info.get("chunks", [])
	
	if index < 0 or index >= chunks.size():
		add_assistant_message("⚠️ 无效的块索引: " + str(index + 1))
		return
	
	add_assistant_message("✅ 变更块 #" + str(index + 1) + " 已标记接受\n💡 输入「接受」应用所有变更")

# ==================== 更新差异状态 ====================

func set_diff_state(original: String, new_code: String, file_path: String) -> void:
	"""设置差异状态"""
	if code_generator:
		current_diff_info = code_generator.format_diff(original, new_code, file_path)
		current_original_code = original
		current_new_code = new_code
		diff_chunks = current_diff_info.get("chunks", [])
		is_showing_diff = true
		
		# 自动显示差异
		var diff_text = code_generator.format_diff_text(current_diff_info)
		add_assistant_message("📊 代码已修改，显示差异对比:\n\n" + diff_text)

func _update_diff_indicator() -> void:
	"""更新差异指示器"""
	if is_showing_diff and diff_btn:
		diff_btn.text = "📊 对比"
		diff_btn.modulate = Color.YELLOW
	else:
		diff_btn.text = "📊 对比"
		diff_btn.modulate = Color.WHITE

# ==================== 项目扫描 ====================

func _on_scan_project() -> void:
	if not project_reader:
		add_assistant_message("⚠️ 项目读取器未加载")
		return
	
	status_icon.text = "📂"
	status_text.text = "扫描中..."
	
	var summary = project_reader.generate_project_summary()
	add_user_message("扫描项目")
	add_assistant_message(summary)
	_update_status()

# ==================== 调试助手功能 ====================

func _on_debug_assist() -> void:
	"""启动调试助手"""
	add_user_message("调试")
	
	var debug_msg = """🐛 **调试助手已启动**

请描述你的问题：

1. **粘贴错误日志** - 直接粘贴完整的错误信息
2. **描述问题** - 说明什么情况下出现问题
3. **期望行为** - 你想要什么效果

**调试命令**
• 「调试」- 启动调试模式
• 「添加断点」- 获取断点设置建议
• 「生成日志」- 获取调试日志代码

💡 直接粘贴错误信息，AI会自动分析！"""
	
	add_assistant_message(debug_msg)

# ==================== 代码搜索功能 ====================

func _on_code_search() -> void:
	"""启动代码搜索"""
	add_user_message("搜索代码")
	
	if not project_reader:
		add_assistant_message("⚠️ 项目读取器未加载")
		return
	
	var search_msg = """🔍 **代码搜索**

请告诉我你想搜索什么？

**示例**
• 「搜索Player」- 搜索Player相关代码
• 「搜索移动」- 搜索移动相关代码
• 「找找碰撞检测」- 搜索碰撞检测代码

**搜索范围**
• 函数名和变量名
• 类名和注释
• 代码片段和逻辑

💡 输入关键词即可开始搜索！"""
	
	add_assistant_message(search_msg)

func show_code_search_results(query: String) -> void:
	"""显示代码搜索结果"""
	if not project_reader:
		return
	
	var results = project_reader.search_code(query, 10)
	
	if results.is_empty():
		add_assistant_message("🔍 没有找到匹配「%s」的代码\n\n💡 建议：\n• 尝试更简短的关键词\n• 检查拼写是否正确" % query)
		return
	
	var report = "🔍 代码搜索结果\n━━━━━━━━━━━━━━━━━━━━━━━\n📊 找到 %d 个匹配文件\n\n" % results.size()
	
	for i in range(min(5, results.size())):
		var r = results[i]
		var file_name = r.get("relative_path", r.get("path", "?")).get_file()
		var match_count = r.get("match_count", 0)
		
		report += "📄 %s (匹配 %d 处)\n" % [file_name, match_count]
		
		var matches = r.get("matches", [])
		if not matches.is_empty():
			var preview = matches[0].get("preview", "")
			if not preview.is_empty():
				report += "   预览: %s\n" % preview.substr(0, min(60, preview.length()))
		report += "\n"
	
	if results.size() > 5:
		report += "...还有 %d 个文件匹配" % (results.size() - 5)
	
	add_assistant_message(report)

# ==================== UI操作 ====================

func add_user_message(text: String) -> void:
	var msg_container = HBoxContainer.new()
	msg_container.alignment = BoxContainer.ALIGNMENT_END
	
	var msg_label = Label.new()
	msg_label.text = "👤 " + text
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.custom_minimum_size.x = 300
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	msg_container.add_child(spacer)
	msg_container.add_child(msg_label)
	chat_container.add_child(msg_container)
	_scroll_to_bottom()

func add_assistant_message(text: String) -> void:
	var display_text = parse_simple_format(text)
	
	var msg_container = HBoxContainer.new()
	msg_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	
	var msg_label = RichTextLabel.new()
	msg_label.text = "[color=#50c878]🤖 [/color]" + display_text
	msg_label.bbcode_enabled = true
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.custom_minimum_size.x = 300
	msg_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	msg_container.add_child(msg_label)
	chat_container.add_child(msg_container)
	_scroll_to_bottom()

func parse_simple_format(text: String) -> String:
	var result = text
	result = result.replace("```", "[code]")
	result = result.replace("**", "[b]")
	result = result.replace("*", "[i]")
	return result

func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	var scroll = $Margin/VBox/ChatScroll
	scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value

# ==================== 按钮事件 ====================

func _on_clear() -> void:
	for i in range(chat_container.get_child_count() - 1, 0, -1):
		chat_container.get_child(i).queue_free()
	
	if ai_handler:
		ai_handler.conversation_history.clear()
	pending_code_blocks.clear()
	_selected_code = ""
	if code_applier:
		code_applier.pending_blocks.clear()
	_update_status()

func _on_config() -> void:
	var config_dialog = preload("res://addons/game_ai_assistant/ui/config_dialog.tscn").instantiate()
	get_tree().root.add_child(config_dialog)
	config_dialog.config_saved.connect(_on_config_saved)

func _on_config_saved(cfg: Dictionary) -> void:
	if ai_handler:
		ai_handler.configure(cfg)
	update_status_from_config(cfg)

func _on_templates() -> void:
	add_user_message("模板")
	if ai_handler:
		ai_handler.process_message("显示所有代码模板")

func _on_assets() -> void:
	add_user_message("素材")
	if ai_handler:
		ai_handler.process_message("帮我搜索免费游戏素材")

func _on_help() -> void:
	var lang = get_current_lang()
	var help_text_zh = """
🐙 **帮助信息 v1.5**

**代码管理**
• 「预览」- 查看待应用代码
• 「预览 1」- 查看第1个代码
• 「应用」- 确认应用代码
• 「应用 1」- 应用第1个代码
• 「跳过」- 放弃待应用代码
• 「确认」- 确认覆盖操作
• 「取消」- 取消当前操作

**撤销/重做**
• 「撤销」- 撤销上一次操作
• 「重做」- 恢复撤销的操作
• 「历史」- 查看操作历史

**🐛 调试助手**
• 「调试」- 启动调试助手
• 「添加断点」- 获取断点设置建议
• 「生成日志」- 获取调试日志代码

**🔧 代码解释与优化**
• 「解释代码」- 选中代码后输入，分析代码功能
• 「优化代码」- 选中代码后输入，提供优化建议

**🔍 代码搜索**
• 「搜索代码:关键词」- 在项目中搜索代码
• 「找找XXX」- 搜索相关代码

**其他功能**
• 「扫描项目」- 查看项目结构
• 「今日学习」- 获取学习技巧
• 「知识库」- 打开知识库
• 「截图」- 截取场景图

**快捷按钮**
• 📋 预览 - 查看代码预览
• 📂 应用 - 确认应用代码
• 🐛 调试 - 调试助手
• 🔍 搜索 - 代码搜索
• ↩️ 撤销 / ↪️ 重做 - 操作历史
• 📚 学习 - 今日学习
• 📖 知识 - 知识库
"""
	var help_text_en = """
🐙 **Help v1.5**

**Code Management**
• 「preview」- View pending code
• 「preview 1」- View first code block
• 「apply」- Confirm and apply code
• 「apply 1」- Apply first code block
• 「skip」- Skip pending code
• 「confirm」- Confirm overwrite
• 「cancel」- Cancel current operation

**Undo/Redo**
• 「undo」- Undo last operation
• 「redo」- Redo operation
• 「history」- View operation history

**🐛 Debug Assistant**
• 「debug」- Start debug mode
• 「add breakpoint」- Breakpoint suggestions
• 「generate log」- Debug log code

**🔧 Code Explain & Optimize**
• 「explain code」- Analyze selected code
• 「optimize code」- Optimize selected code

**🔍 Code Search**
• 「search:keyword」- Search project code
• 「find XXX」- Search related code

**Other Features**
• 「scan project」- View project structure
• 「daily learning」- Learning tips
• 「knowledge base」- Open knowledge base
• 「screenshot」- Capture scene

**Quick Buttons**
• 📋 Preview - Preview code
• 📂 Apply - Apply code
• 🐛 Debug - Debug assistant
• 🔍 Search - Code search
• ↩️ Undo / ↪️ Redo - History
• 📚 Learn - Daily learning
• 📖 Knowledge - Knowledge base
"""
	add_user_message(_tr("help"))
	add_assistant_message(help_text_zh if lang == "zh" else help_text_en)

func execute_quick_command(command: String) -> void:
	add_user_message(command)
	
	var special_response = check_special_command(command)
	if special_response:
		add_assistant_message(special_response)
	elif ai_handler:
		ai_handler.process_message(command)
