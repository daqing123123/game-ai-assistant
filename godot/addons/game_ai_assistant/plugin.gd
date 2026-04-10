@tool
extends EditorPlugin

# Game AI Assistant - 游戏AI助手插件 v1.2
# 像有经验的程序员朋友在身边，边聊边帮你做游戏

const VERSION = "1.2.0"
const AUTHOR = "Octopus Team"

# UI组件
var main_panel: Control
var dock_panel: Control
var config_dialog: Control

# 核心模块
var ai_handler: Node
var editor_agent: Node
var asset_searcher: Node
var code_generator: Node
var project_reader: Node
var code_applier: Node

# Phase 4 模块
var screenshot_handler: Node
var daily_learning: Node
var knowledge_base: Node
var shortcuts_handler: Node

func _enter_tree() -> void:
	print("🐙 Game AI Assistant v%s 正在启动..." % VERSION)
	
	# 初始化核心模块
	_init_core_modules()
	_init_phase4_modules()
	
	# 创建UI
	_create_main_panel()
	_create_dock_panel()
	
	print("✅ Game AI Assistant 启动完成!")
	print("   使用 Window → Game AI Assistant 打开助手")

func _init_core_modules() -> void:
	# AI处理器
	ai_handler = preload("res://addons/game_ai_assistant/core/ai_handler.gd").new()
	ai_handler.name = "GameAIHandler"
	get_tree().root.add_child(ai_handler)
	
	# 编辑器智能体（Ziva风格：自动上下文+直接操作节点）
	editor_agent = preload("res://addons/game_ai_assistant/core/editor_agent.gd").new()
	editor_agent.name = "EditorAgent"
	get_tree().root.add_child(editor_agent)
	
	# 素材搜索器
	asset_searcher = preload("res://addons/game_ai_assistant/core/asset_searcher.gd").new()
	asset_searcher.name = "AssetSearcher"
	get_tree().root.add_child(asset_searcher)
	
	# 代码生成器
	code_generator = preload("res://addons/game_ai_assistant/core/code_generator.gd").new()
	code_generator.name = "CodeGenerator"
	get_tree().root.add_child(code_generator)
	
	# 项目读取器
	project_reader = preload("res://addons/game_ai_assistant/core/project_reader.gd").new()
	project_reader.name = "ProjectReader"
	get_tree().root.add_child(project_reader)
	
	# 代码应用器
	code_applier = preload("res://addons/game_ai_assistant/core/code_applier.gd").new()
	code_applier.name = "CodeApplier"
	get_tree().root.add_child(code_applier)
	
	print("   ✓ AI处理器已加载")
	print("   ✓ 素材搜索器已加载")
	print("   ✓ 代码生成器已加载")
	print("   ✓ 项目读取器已加载")
	print("   ✓ 代码应用器已加载")

func _init_phase4_modules() -> void:
	# 截图处理器
	screenshot_handler = preload("res://addons/game_ai_assistant/core/screenshot_handler.gd").new()
	screenshot_handler.name = "ScreenshotHandler"
	get_tree().root.add_child(screenshot_handler)
	
	# 每日学习
	daily_learning = preload("res://addons/game_ai_assistant/core/daily_learning.gd").new()
	daily_learning.name = "DailyLearning"
	get_tree().root.add_child(daily_learning)
	
	# 知识库
	knowledge_base = preload("res://addons/game_ai_assistant/core/knowledge_base.gd").new()
	knowledge_base.name = "KnowledgeBase"
	get_tree().root.add_child(knowledge_base)
	
	# 快捷键管理器
	shortcuts_handler = preload("res://addons/game_ai_assistant/core/shortcuts_handler.gd").new()
	shortcuts_handler.name = "ShortcutsHandler"
	get_tree().root.add_child(shortcuts_handler)
	
	print("   ✓ 截图处理器已加载 [Phase 4]")
	print("   ✓ 每日学习已加载 [Phase 4]")
	print("   ✓ 知识库已加载 [Phase 4]")
	print("   ✓ 快捷键管理器已加载 [Phase 4]")

func _create_main_panel() -> void:
	var main_panel_scene = preload("res://addons/game_ai_assistant/ui/main_panel.tscn")
	main_panel = main_panel_scene.instantiate()
	main_panel.visible = false
	
	# 传递模块引用
	if main_panel.has_method("set_modules"):
		main_panel.set_modules({
			"ai_handler": ai_handler,
			"asset_searcher": asset_searcher,
			"code_generator": code_generator,
			"project_reader": project_reader,
			"code_applier": code_applier,
			"screenshot_handler": screenshot_handler,
			"daily_learning": daily_learning,
			"knowledge_base": knowledge_base
		})
	
	# 设置主面板引用给快捷键
	shortcuts_handler.set_main_panel(main_panel)
	
	get_editor_interface().get_base_control().add_child(main_panel)
	add_tool_menu_item("🐙 Game AI Assistant", _show_main_panel)

func _create_dock_panel() -> void:
	var dock_scene = preload("res://addons/game_ai_assistant/ui/dock_panel.tscn")
	dock_panel = dock_scene.instantiate()
	dock_panel.action_requested.connect(_on_dock_action)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock_panel)
	print("   ✓ 停靠面板已添加")

func _show_main_panel() -> void:
	if main_panel:
		main_panel.visible = true
		main_panel.grab_focus()

func _on_dock_action(action: String, data: Dictionary) -> void:
	match action:
		"new_project":
			_show_main_panel()
		"templates":
			if main_panel and main_panel.has_method("execute_quick_command"):
				main_panel.execute_quick_command("模板")
		"assets":
			if main_panel and main_panel.has_method("execute_quick_command"):
				main_panel.execute_quick_command("素材")
		"project":
			if main_panel and main_panel.has_method("execute_quick_command"):
				main_panel.execute_quick_command("扫描项目")
		"learning":
			if main_panel and main_panel.has_method("execute_quick_command"):
				main_panel.execute_quick_command("今日学习")
		"knowledge":
			if main_panel and main_panel.has_method("execute_quick_command"):
				main_panel.execute_quick_command("知识库")
		"shortcuts":
			if main_panel and main_panel.has_method("execute_quick_command"):
				main_panel.execute_quick_command("快捷键")
		"config":
			_show_config_dialog()

func _show_config_dialog() -> void:
	if not config_dialog:
		var config_scene = preload("res://addons/game_ai_assistant/ui/config_dialog.tscn")
		config_dialog = config_scene.instantiate()
		get_editor_interface().get_base_control().add_child(config_dialog)
	config_dialog.popup_centered()

func _exit_tree() -> void:
	# 清理UI
	if main_panel:
		main_panel.queue_free()
	if dock_panel:
		remove_control_from_docks(dock_panel)
		dock_panel.queue_free()
	if config_dialog:
		config_dialog.queue_free()
	
	# 清理核心模块
	if ai_handler:
		ai_handler.queue_free()
	if editor_agent:
		editor_agent.queue_free()
	if asset_searcher:
		asset_searcher.queue_free()
	if code_generator:
		code_generator.queue_free()
	if project_reader:
		project_reader.queue_free()
	if code_applier:
		code_applier.queue_free()
	
	# 清理 Phase 4 模块
	if screenshot_handler:
		screenshot_handler.queue_free()
	if daily_learning:
		daily_learning.queue_free()
	if knowledge_base:
		knowledge_base.queue_free()
	if shortcuts_handler:
		shortcuts_handler.queue_free()
	
	remove_tool_menu_item("🐙 Game AI Assistant")
	print("🐙 Game AI Assistant 已关闭")

func get_config() -> Dictionary:
	return {
		"ai_handler": ai_handler,
		"asset_searcher": asset_searcher,
		"code_generator": code_generator,
		"project_reader": project_reader,
		"code_applier": code_applier,
		"screenshot_handler": screenshot_handler,
		"daily_learning": daily_learning,
		"knowledge_base": knowledge_base,
		"shortcuts_handler": shortcuts_handler
	}
