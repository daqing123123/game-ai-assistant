extends Node

# 快捷键管理器 - 全局快捷键支持
# Phase 4 功能

signal shortcut_triggered(action: String)

# 快捷键配置
var shortcuts: Dictionary = {
	"toggle_panel": {
		"label": "切换助手面板",
		"key": KEY_F1,
		"mods": 0,
		"enabled": true
	},
	"quick_search": {
		"label": "快速搜索素材",
		"key": KEY_F2,
		"mods": 0,
		"enabled": true
	},
	"generate_code": {
		"label": "快速生成代码",
		"key": KEY_F3,
		"mods": 0,
		"enabled": true
	},
	"capture_screenshot": {
		"label": "截取场景图",
		"key": KEY_F4,
		"mods": 0,
		"enabled": true
	},
	"today_learning": {
		"label": "今日学习",
		"key": KEY_F5,
		"mods": 0,
		"enabled": true
	},
	"open_knowledge": {
		"label": "打开知识库",
		"key": KEY_F6,
		"mods": 0,
		"enabled": true
	}
}

var main_panel: Control = null
var is_enabled: bool = true

func _ready() -> void:
	_load_shortcuts()
	print("⌨️ 快捷键管理器已就绪")

func _input(event: InputEvent) -> void:
	if not is_enabled:
		return
	
	# 只处理按键按下事件
	if not (event is InputEventKey):
		return
	
	var key_event = event as InputEventKey
	
	if not key_event.pressed:
		return
	
	# 检查每个快捷键
	for action in shortcuts:
		var shortcut = shortcuts[action]
		if not shortcut["enabled"]:
			continue
		
		if _match_shortcut(key_event, shortcut):
			shortcut_triggered.emit(action)
			_handle_action(action)
			break

func _match_shortcut(event: InputEventKey, shortcut: Dictionary) -> bool:
	# 检查主要按键
	if event.keycode != shortcut["key"]:
		return false
	
	# 检查修饰键
	var mods = shortcut["mods"]
	
	if (mods & KEY_MASK_CTRL) and not (event.ctrl_pressed):
		return false
	if (mods & KEY_MASK_SHIFT) and not (event.shift_pressed):
		return false
	if (mods & KEY_MASK_ALT) and not (event.alt_pressed):
		return false
	
	# 检查没有意外的其他修饰键
	if not (event.ctrl_pressed or event.shift_pressed or event.alt_pressed):
		if mods == 0:
			return true
	
	return (event.ctrl_pressed == bool(mods & KEY_MASK_CTRL) and
			event.shift_pressed == bool(mods & KEY_MASK_SHIFT) and
			event.alt_pressed == bool(mods & KEY_MASK_ALT))

func _handle_action(action: String) -> void:
	match action:
		"toggle_panel":
			_toggle_panel()
		"quick_search":
			_quick_search()
		"generate_code":
			_generate_code()
		"capture_screenshot":
			_capture_screenshot()
		"today_learning":
			_show_today_learning()
		"open_knowledge":
			_open_knowledge()

func _toggle_panel() -> void:
	if main_panel:
		main_panel.visible = not main_panel.visible
	else:
		# 查找主面板
		var base = Engine.get_main_loop().root
		_find_and_toggle_panel(base)

func _find_and_toggle_panel(node: Node) -> void:
	if node.name == "MainPanel":
		node.visible = not node.visible
		return
	
	for child in node.get_children():
		_find_and_toggle_panel(child)

func _quick_search() -> void:
	if main_panel and main_panel.has_method("execute_quick_command"):
		main_panel.execute_quick_command("素材")

func _generate_code() -> void:
	if main_panel and main_panel.has_method("execute_quick_command"):
		main_panel.execute_quick_command("模板")

func _capture_screenshot() -> void:
	# 触发截图
	var screenshot_handler = get_node_or_null("/root/ScreenshotHandler")
	if screenshot_handler:
		screenshot_handler.capture_editor_viewport()
		print("📸 截图已捕获")

func _show_today_learning() -> void:
	var daily_learning = get_node_or_null("/root/DailyLearning")
	if daily_learning:
		var learning = daily_learning.get_today_learning()
		if main_panel and main_panel.has_method("add_assistant_message"):
			main_panel.add_assistant_message(learning["tip"])

func _open_knowledge() -> void:
	var knowledge_base = get_node_or_null("/root/KnowledgeBase")
	if knowledge_base and main_panel and main_panel.has_method("add_assistant_message"):
		var entry = knowledge_base.get_random_entry()
		if entry:
			var msg = "📖 知识库推荐:\n\n"
			msg += "**%s**\n%s" % [entry["title"], entry["content"]]
			main_panel.add_assistant_message(msg)
		else:
			main_panel.add_assistant_message("知识库为空，试试添加一些知识吧！")

# 设置主面板引用
func set_main_panel(panel: Control) -> void:
	main_panel = panel

# 启用/禁用
func set_enabled(enabled: bool) -> void:
	is_enabled = enabled

# 启用/禁用特定快捷键
func set_shortcut_enabled(action: String, enabled: bool) -> bool:
	if shortcuts.has(action):
		shortcuts[action]["enabled"] = enabled
		_save_shortcuts()
		return true
	return false

# 修改快捷键
func set_shortcut_key(action: String, key: int, mods: int = 0) -> bool:
	if shortcuts.has(action):
		shortcuts[action]["key"] = key
		shortcuts[action]["mods"] = mods
		_save_shortcuts()
		return true
	return false

# 获取快捷键列表
func get_shortcuts() -> Dictionary:
	return shortcuts.duplicate(true)

# 获取快捷键描述
func get_shortcut_label(action: String) -> String:
	if shortcuts.has(action):
		return shortcuts[action]["label"]
	return ""

# 获取快捷键显示文本
func get_shortcut_text(action: String) -> String:
	if shortcuts.has(action):
		var shortcut = shortcuts[action]
		var text = ""
		
		if shortcut["mods"] & KEY_MASK_CTRL:
			text += "Ctrl+"
		if shortcut["mods"] & KEY_MASK_SHIFT:
			text += "Shift+"
		if shortcut["mods"] & KEY_MASK_ALT:
			text += "Alt+"
		
		text += _key_to_string(shortcut["key"])
		return text
	
	return ""

func _key_to_string(key: int) -> String:
	var key_names = {
		KEY_F1: "F1", KEY_F2: "F2", KEY_F3: "F3", KEY_F4: "F4",
		KEY_F5: "F5", KEY_F6: "F6", KEY_F7: "F7", KEY_F8: "F8",
		KEY_F9: "F9", KEY_F10: "F10", KEY_F11: "F11", KEY_F12: "F12",
		KEY_SPACE: "Space", KEY_ENTER: "Enter", KEY_ESCAPE: "Esc",
		KEY_TAB: "Tab", KEY_BACKSPACE: "Backspace"
	}
	
	if key_names.has(key):
		return key_names[key]
	
	# 尝试获取单字符
	if key >= KEY_A and key <= KEY_Z:
		return char(key)
	if key >= KEY_0 and key <= KEY_9:
		return char(key)
	
	return "Key%d" % key

# 生成快捷键帮助文本
func generate_shortcuts_help() -> String:
	var help = """
⌨️ 快捷键列表
━━━━━━━━━━━━━━━━━━━━━━━
"""
	
	for action in shortcuts:
		var shortcut = shortcuts[action]
		var status = "✅" if shortcut["enabled"] else "❌"
		var key_text = get_shortcut_text(action)
		
		help += "\n%s %s [%s]\n" % [status, shortcut["label"], key_text]
	
	help += """
💡 提示: 在编辑器中按对应快捷键触发
"""
	
	return help

# 保存/加载
func _save_shortcuts() -> void:
	var config_path = "user://shortcuts.json"
	var file = FileAccess.open(config_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(shortcuts))
		file.close()

func _load_shortcuts() -> void:
	var config_path = "user://shortcuts.json"
	if FileAccess.file_exists(config_path):
		var file = FileAccess.open(config_path, FileAccess.READ)
		if file:
			var json = JSON.parse_string(file.get_as_text())
			if json:
				shortcuts = json
			file.close()
