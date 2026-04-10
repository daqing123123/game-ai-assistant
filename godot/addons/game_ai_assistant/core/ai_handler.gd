extends Node

# AI处理器 - 核心AI逻辑
# 处理用户输入，调用AI，返回结果

signal thinking_started()
signal thinking_finished(response: String)
signal errorOccurred(error: String)
signal debug_analysis_ready(analysis: Dictionary)
signal code_search_ready(results: Array)
signal code_analysis_finished(response: String, analysis_type: String)

var config: Dictionary = {}
var http_request: HTTPRequest
var is_processing: bool = false
var conversation_history: Array = []

# 调试助手相关
var last_error_context: Dictionary = {}
var debug_suggestions: Array = []

# 代码搜索相关
var last_search_results: Array = []
var last_search_query: String = ""
var _analysis_mode: String = ""  # "explain" | "optimize" | ""
var _pending_user_message: String = ""

# 系统提示词（双语）
const SYSTEM_PROMPT_ZH = """你是一个专业的游戏开发AI助手，名字叫八爪鱼。

## 你的能力
1. 生成Unity(C#)和Godot(GDScript)代码
2. 修改现有代码
3. 搜索免费可商用的游戏素材
4. 解释游戏开发概念
5. 诊断和修复Bug
6. 提供游戏开发建议

## 代码格式要求
- GDScript使用extends Node
- C#使用UnityEngine命名空间
- 代码要有注释
- 重要代码用中文注释

## 素材搜索
如果用户要找素材，返回JSON格式：
{"action": "search_assets", "query": "搜索关键词", "type": "sound|model|texture|sprite"}

## 代码解释
如果用户请求解释代码（"解释代码"、"解释这段代码"、"分析代码"、"这段代码做了什么"等），返回JSON格式：
{"action": "explain_code", "code": "用户选中的代码"}

## 代码优化
如果用户请求优化代码（"优化代码"、"优化这段代码"、"代码优化"、"如何改进"等），返回JSON格式：
{"action": "optimize_code", "code": "用户选中的代码"}

## 模板请求
如果用户要代码模板，返回JSON格式：
{"action": "generate_template", "template": "模板名称"}

## 项目信息
- 引擎: Godot 4.2
- 项目路径: {project_path}

回答要简洁实用，像和朋友聊天一样自然。"""

const SYSTEM_PROMPT_EN = """You are a professional game development AI assistant named Octopus.

## Your Capabilities
1. Generate Unity(C#) and Godot(GDScript) code
2. Modify existing code
3. Search for free commercially-usable game assets
4. Explain game development concepts
5. Diagnose and fix bugs
6. Provide game development advice

## Code Format Requirements
- GDScript uses extends Node
- C# uses UnityEngine namespace
- Code should have comments
- Use English comments

## Asset Search
If user wants to find assets, return JSON format:
{"action": "search_assets", "query": "search keywords", "type": "sound|model|texture|sprite"}

## Code Explanation
If user requests code explanation ("explain code", "what does this code do", "analyze code", etc.), return JSON:
{"action": "explain_code", "code": "user selected code"}

## Code Optimization
If user requests code optimization ("optimize code", "improve this code", "how to improve", etc.), return JSON:
{"action": "optimize_code", "code": "user selected code"}

## Template Request
If user wants code template, return JSON:
{"action": "generate_template", "template": "template name"}

## Project Info
- Engine: Godot 4.2
- Project Path: {project_path}

Be concise and practical, like chatting with a friend."""

# 获取系统提示词（根据语言设置）
func get_system_prompt() -> String:
	var lang = config.get("language", "auto")
	if lang == "auto":
		lang = "zh" if OS.get_locale_language() == "zh" else "en"
	return SYSTEM_PROMPT_ZH if lang == "zh" else SYSTEM_PROMPT_EN

func _init():
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

func configure(cfg: Dictionary):
	config = cfg

# 处理用户输入
func process_message(user_input: String) -> void:
	if is_processing:
		errorOccurred.emit("正在处理上一个请求，请稍候...")
		return
	
	is_processing = true
	thinking_started.emit()
	
	# 解析特殊命令
	var special_result = parse_special_command(user_input)
	if special_result:
		await get_tree().create_timer(0.5).timeout
		is_processing = false
		thinking_finished.emit(special_result)
		return
	
	# 调用AI
	await call_ai(user_input)
	is_processing = false

# ==================== 项目模板功能 ====================

func get_project_templates() -> Array:
	return [
		{
			"id": "2d_platformer",
			"name": "2D 平台跳跃",
			"description": "经典的横版平台跳跃游戏模板",
			"features": ["玩家角色", "平台", "金币收集", "敌人", "关卡切换"]
		},
		{
			"id": "3d_fps",
			"name": "3D 第一人称射击",
			"description": "第一人称射击游戏模板",
			"features": ["FPS控制器", "武器系统", "敌人AI", "弹药管理", "分数系统"]
		},
		{
			"id": "2d_topdown_shooter",
			"name": "2D 俯视角射击",
			"description": "俯视角射击游戏模板",
			"features": ["玩家控制器", "弹幕系统", "道具掉落", "波次系统", "商店"]
		},
		{
			"id": "3d_third_person",
			"name": "3D 第三人称动作",
			"description": "第三人称动作冒险游戏模板",
			"features": ["角色控制器", "相机跟随", "攻击系统", "敌人AI", "生命值"]
		},
		{
			"id": "casual_puzzle",
			"name": "休闲益智游戏",
			"description": "轻松休闲的益智游戏模板",
			"features": ["关卡系统", "计时器", "分数系统", "道具使用", "通关判定"]
		},
		{
			"id": "rpg",
			"name": "RPG 角色扮演",
			"description": "经典RPG角色扮演游戏模板",
			"features": ["角色属性", "装备系统", "技能树", "任务系统", "商店交易"]
		}
	]

func create_project_template(template_id: String) -> Dictionary:
	var templates = get_project_templates()
	var selected_template = null
	
	for t in templates:
		if t["id"] == template_id:
			selected_template = t
			break
	
	if not selected_template:
		return {"success": false, "message": "未找到指定的模板"}
	
	# 获取代码生成器
	var code_gen = get_node_or_null("/root/CodeGenerator")
	if not code_gen:
		return {"success": false, "message": "代码生成器未加载"}
	
	# 生成项目结构
	var result = code_gen.generate_project_template(template_id, selected_template)
	
	return result

func show_project_template_list() -> String:
	var templates = get_project_templates()
	var msg = """
🏗️ **项目模板**

请选择要创建的项目类型：

**常用模板**
1️⃣ [2D 平台跳跃] - 经典横版跳跃游戏
2️⃣ [2D 俯视角射击] - 俯视角射击游戏
3️⃣ [3D 第三人称动作] - 动作冒险游戏

**进阶模板**
4️⃣ [3D 第一人称射击] - FPS射击游戏
5️⃣ [休闲益智游戏] - 轻松休闲游戏
6️⃣ [RPG 角色扮演] - 角色扮演游戏

━━━━━━━━━━━━━━━
💡 输入「创建1」选择第1个模板
💡 输入「创建 2D 平台」快速选择
"""
	return msg

# ==================== 场景生成功能 ====================

func generate_scene(scene_config: Dictionary) -> Dictionary:
	var code_gen = get_node_or_null("/root/CodeGenerator")
	if not code_gen:
		return {"success": false, "message": "代码生成器未加载"}
	
	var result = code_gen.generate_scene(scene_config)
	return result

func show_scene_generation_help() -> String:
	return """
🎬 **场景生成向导**

告诉我你想要什么场景，我来帮你生成！

**场景元素**
• 🧍 玩家出生点 - PlayerSpawn
• 👹 敌人 - Enemy
• 🪙 金币/道具 - Collectible
• 🧱 障碍物 - Obstacle
• 🏁 终点 - Goal

**示例描述**
「创建一个平台跳跃关卡，有玩家出生点、3个金币、2个敌人和终点」

**快捷命令**
• 「生成简单关卡」- 创建基础平台关卡
• 「生成战斗场景」- 创建包含敌人的战斗场景
• 「生成Boss房间」- 创建Boss战场景
"""

func get_scene_element_types() -> Array:
	return [
		{"id": "player_spawn", "name": "玩家出生点", "icon": "🧍"},
		{"id": "enemy", "name": "敌人", "icon": "👹"},
		{"id": "collectible", "name": "可收集物", "icon": "🪙"},
		{"id": "obstacle", "name": "障碍物", "icon": "🧱"},
		{"id": "platform", "name": "平台", "icon": "⬜"},
		{"id": "goal", "name": "终点/门", "icon": "🏁"},
		{"id": "spawner", "name": "敌人出生点", "icon": "💀"},
		{"id": "trap", "name": "陷阱", "icon": "⚠️"}
	]

# 解析特殊命令
func parse_special_command(input: String) -> String:
	var lower_input = input.to_lower()
	
	# 帮助命令
	if lower_input.begins_with("帮助") or lower_input.begins_with("help"):
		return get_help_text()
	
	# 模板命令
	if lower_input.begins_with("模板") or lower_input.begins_with("template"):
		return get_template_list()
	
	# 项目模板命令
	if lower_input.begins_with("创建项目") or lower_input.begins_with("新建项目") or lower_input.begins_with("项目模板"):
		return show_project_template_list()
	
	# 创建指定模板
	if lower_input.begins_with("创建"):
		return parse_create_template_command(input)
	
	# 场景生成命令
	if lower_input.begins_with("生成场景") or lower_input.begins_with("创建场景") or lower_input.begins_with("场景向导"):
		return show_scene_generation_help()
	
	# 场景生成快捷命令
	if lower_input.begins_with("生成"):
		return parse_scene_generation_command(input)
	
	# 设置命令
	if lower_input.begins_with("设置") or lower_input.begins_with("config"):
		return "请打开侧边栏的「设置」面板配置AI模型。"
	
	# 清理历史
	if lower_input.begins_with("清除") or lower_input.begins_with("clear"):
		conversation_history.clear()
		return "已清除对话历史！"
	
	# 搜索素材
	if lower_input.begins_with("找") or lower_input.begins_with("搜索") or lower_input.begins_with("search"):
		var query = input.substr(1).strip_edges()
		if query.is_empty():
			return "请告诉我你想找什么素材？\n比如：「找爆炸音效」或「搜索科幻角色模型」"
		return generate_search_prompt(query)
	
	# 调试助手命令
	if lower_input.begins_with("调试") or lower_input.begins_with("找bug") or lower_input.begins_with("帮我找bug") or lower_input.contains("报错了") or lower_input.contains("出错了"):
		return _handle_debug_command(input)
	
	# 代码搜索命令
	if lower_input.begins_with("搜索代码") or lower_input.begins_with("找代码") or lower_input.begins_with("查找代码") or lower_input.begins_with("找找"):
		return _handle_search_code_command(input)
	
	return ""

# 解析创建模板命令
func parse_create_template_command(input: String) -> String:
	var lower = input.to_lower()
	var templates = get_project_templates()
	
	# 数字索引
	if input.begins_with("创建"):
		var num_str = input.substr(2).strip_edges()
		if num_str.is_valid_int():
			var idx = num_str.to_int() - 1
			if idx >= 0 and idx < templates.size():
				return "⏳ 正在创建【" + templates[idx]["name"] + "】模板..."
	
	# 关键字匹配
	for i in range(templates.size()):
		var t = templates[i]
		var keywords = {
			"2d_platformer": ["2d平台", "平台跳跃", "平台"],
			"3d_fps": ["fps", "第一人称", "射击"],
			"2d_topdown_shooter": ["俯视角", "俯视射击", "topdown"],
			"3d_third_person": ["第三人称", "动作", "3d动作"],
			"casual_puzzle": ["休闲", "益智", "puzzle"],
			"rpg": ["rpg", "角色扮演", "角色"]
		}
		var kw_list = keywords.get(t["id"], [])
		for kw in kw_list:
			if lower.contains(kw):
				return "⏳ 正在创建【" + t["name"] + "】模板..."
	
	# 通用创建命令
	if lower.contains("创建"):
		return show_project_template_list()
	
	return ""

# 解析场景生成命令
func parse_scene_generation_command(input: String) -> String:
	var lower = input.to_lower()
	
	# 简单关卡
	if lower.contains("简单关卡") or lower.contains("基础关卡"):
		var config = {
			"type": "platformer_level",
			"elements": [
				{"type": "player_spawn", "pos": Vector2(100, 400), "name": "PlayerSpawn"},
				{"type": "platform", "pos": Vector2(400, 500), "size": Vector2(600, 50)},
				{"type": "collectible", "pos": Vector2(300, 400), "name": "Coin1"},
				{"type": "collectible", "pos": Vector2(500, 400), "name": "Coin2"},
				{"type": "goal", "pos": Vector2(700, 450), "name": "Goal"}
			]
		}
		return "⏳ 正在生成简单关卡..."
	
	# 战斗场景
	if lower.contains("战斗") or lower.contains("enemy") or lower.contains("敌人"):
		return "⏳ 正在生成战斗场景..."
	
	# Boss房间
	if lower.contains("boss"):
		return "⏳ 正在生成Boss房间..."
	
	return ""

func generate_search_prompt(query: String) -> String:
	return """我帮你搜索「%s」相关的素材！

🎨 **免费可商用素材源**：

**音效类**
• freesound.org - 全球最大免费音效库
• kenney.nl - CC0协议，高质量

**模型类**
• kenney.nl - 3D模型、角色
• opengameart.org - 社区素材

**精灵图类**
• kenney.nl - 2D游戏素材
• game-icons.net - 图标素材

需要我帮你搜索吗？输入「开始搜索」继续。""" % query

# ==================== 调试助手功能 ====================

func _handle_debug_command(input: String) -> String:
	"""处理调试命令"""
	var lower = input.to_lower()
	
	# 检查是否是直接粘贴错误日志
	if "error" in lower or "exception" in lower or "null" in lower or "nullreference" in lower:
		return _analyze_error_log(input)
	
	# 通用调试模式
	last_error_context = {
		"user_description": input,
		"timestamp": Time.get_datetime_string_from_system()
	}
	
	return """🐛 **调试助手已启动**

请告诉我：
1. **错误信息** - 粘贴完整的错误日志
2. **问题描述** - 什么情况下出现问题
3. **期望行为** - 你想要什么效果

**常用调试命令**
• 「调试」- 启动调试模式
• 「分析这段代码」- AI帮你分析代码问题
• 「添加日志」- 生成调试日志代码

💡 直接粘贴错误信息，AI会自动分析原因！"""

func _analyze_error_log(error_log: String) -> String:
	"""分析错误日志并提供解决方案"""
	debug_suggestions.clear()
	
	# 提取关键错误信息
	var error_type = _extract_error_type(error_log)
	var error_msg = _extract_error_message(error_log)
	var possible_causes = _analyze_error_type(error_type)
	
	# 保存错误上下文
	last_error_context = {
		"error_type": error_type,
		"error_message": error_msg,
		"timestamp": Time.get_datetime_string_from_system()
	}
	
	var report = """
🐛 **错误分析报告**

**错误类型:** %s
**错误信息:** %s

━━━━━━━━━━━━━━━━━━━━━━━

**🔍 可能原因:**

""" % [error_type, error_msg]
	
	for i in range(possible_causes.size()):
		report += "%d. %s\n" % [i + 1, possible_causes[i]]
	
	report += """
━━━━━━━━━━━━━━━━━━━━━━━

**🔧 解决方案建议:**

"""
	
	var solutions = _get_solution_suggestions(error_type)
	for i in range(solutions.size()):
		report += "**%d. %s**\n%s\n\n" % [i + 1, solutions[i].title, solutions[i].description]
	
	report += """
━━━━━━━━━━━━━━━━━━━━━━━

**💡 调试技巧**

• 使用 `print()` 输出变量值
• 使用 `push_error()` 输出错误信息
• 使用断点暂停程序查看状态
• 检查空值引用 `if node != null:`

**下一步操作**
• 输入「添加断点」- 生成断点建议代码
• 输入「生成日志」- 生成调试日志代码
• 输入「查看相关代码」- AI搜索相关代码文件
"""
	
	return report

func _extract_error_type(log: String) -> String:
	"""提取错误类型"""
	var lower = log.to_lower()
	
	if "null" in lower and ("reference" in lower or "pointer" in lower):
		return "空引用异常 (NullReferenceException)"
	if "index" in lower and "out of range" in lower:
		return "数组越界 (IndexOutOfRangeException)"
	if "invalid call" in lower or "call" in lower and "none" in lower:
		return "无效方法调用"
	if "parsing" in lower or "syntax" in lower:
		return "语法错误 (Syntax Error)"
	if "type" in lower and "mismatch" in lower:
		return "类型不匹配 (Type Mismatch)"
	if "file" in lower and "not found" in lower:
		return "文件未找到"
	if "permission" in lower or "access" in lower:
		return "权限访问错误"
	
	return "未知错误类型"

func _extract_error_message(log: String) -> String:
	"""提取错误消息"""
	var lines = log.split("\n")
	for line in lines:
		if "error" in line.to_lower() or "exception" in line.to_lower():
			return line.strip_edges()
	return "未找到具体错误信息"

func _analyze_error_type(error_type: String) -> Array:
	"""分析错误类型可能的原因"""
	var causes: Array = []
	
	match error_type:
		"空引用异常 (NullReferenceException)":
			causes = [
				"变量未初始化就使用",
				"节点路径错误或节点不存在",
				"异步加载的节点尚未加载完成",
				"数组/字典访问了不存在的索引"
			]
		"数组越界 (IndexOutOfRangeException)":
			causes = [
				"循环索引超出数组长度",
				"使用 -1 作为索引访问",
				"数组为空时访问第一个元素"
			]
		"无效方法调用":
			causes = [
				"调用了不存在的函数",
				"在对象为null时调用其方法",
				"参数数量或类型不匹配"
			]
		"语法错误 (Syntax Error)":
			causes = [
				"缺少分号或括号",
				"关键字拼写错误",
				"字符串未正确闭合"
			]
		_:
			causes = [
				"参数传递错误",
				"资源加载失败",
				"外部依赖未正确配置"
			]
	
	return causes

func _get_solution_suggestions(error_type: String) -> Array:
	"""获取针对特定错误的解决方案"""
	var solutions: Array = []
	
	match error_type:
		"空引用异常 (NullReferenceException)":
			solutions = [
				{
					"title": "添加空值检查",
					"description": "在访问对象前检查是否为null\n```gdscript\nif node != null:\n    node.do_something()\n```"
				},
				{
					"title": "使用安全导航",
					"description": "使用 `?.` 运算符安全访问属性\n```gdscript\nvar value = node?.some_property\n```"
				},
				{
					"title": "确保节点存在",
					"description": "在 _ready() 中获取节点并检查\n```gdscript\nfunc _ready():\n    node = get_node_or_null(\"Path/To/Node\")\n    if node == null:\n        push_error(\"Node not found!\")\n```"
				}
			]
		"数组越界 (IndexOutOfRangeException)":
			solutions = [
				{
					"title": "检查数组长度",
					"description": "访问前检查索引是否有效\n```gdscript\nif index >= 0 and index < array.size():\n    var value = array[index]\n```"
				},
				{
					"title": "使用 clamp() 限制范围",
					"description": "限制索引在有效范围内\n```gdscript\nvar safe_index = clamp(index, 0, array.size() - 1)\n```"
				}
			]
		_:
			solutions = [
				{
					"title": "添加日志输出",
					"description": "在关键位置添加 print() 帮助定位问题"
				},
				{
					"title": "使用断点调试",
					"description": "在可疑代码处设置断点，逐步执行查看变量值"
				}
			]
	
	return solutions

# 调试助手 - 添加断点建议
func generate_breakpoint_suggestions(error_context: Dictionary = {}) -> String:
	"""生成断点设置建议"""
	var context = error_context if not error_context.is_empty() else last_error_context
	
	return """
🔴 **断点设置建议**

根据错误信息，建议在以下位置设置断点：

**1. 变量初始化处**
```gdscript
func _ready():\n    # 在这里设置断点，检查变量是否正确初始化
    player = get_node_or_null("Player")
    print(\"Player node: \", player)  # 添加日志
```

**2. 空值使用前**
```gdscript
# 使用这个辅助函数检查
func safe_call(node: Node, method: String) -> void:\n    if node and node.has_method(method):\n        node.call(method)\n```

**3. 数组访问处**
```gdscript
func get_item(index: int) -> Variant:\n    if index < 0 or index >= items.size():\n        push_error(\"Invalid index: %d\" % index)\n        return null\n    return items[index]
```

💡 **调试技巧**
• F6 开始调试
• F8 单步执行
• F9 切换断点
"""

# 调试助手 - 生成日志建议
func generate_debug_log_suggestions(error_context: Dictionary = {}) -> String:
	"""生成调试日志代码建议"""
	var context = error_context if not error_context.is_empty() else last_error_context
	var error_type = context.get("error_type", "未知")
	
	var log_template = """
📝 **调试日志代码**

在关键位置添加以下日志代码：

**1. 函数入口日志**
```gdscript
func _process(delta: float) -> void:\n    print(\"[DEBUG] _process called, delta=\", delta)\n```

**2. 变量状态日志**
```gdscript
func update() -> void:\n    print(\"[DEBUG] health=\", health, \" speed=\", speed)\n    if health <= 0:\n        push_error(\"[CRITICAL] Health reached zero!\")\n```

**3. 条件分支日志**
```gdscript
if condition:\n    print(\"[DEBUG] Condition met\")\nelse:\n    print(\"[DEBUG] Condition not met, expected values:\", expected)\n```

**4. 异步操作日志**
```gdscript
func load_resource(path: String) -> void:\n    print(\"[DEBUG] Loading: \", path)\n    var result = await ResourceLoader.load_threaded_request(path)\n    print(\"[DEBUG] Load complete: \", result)\n```

**5. 错误日志（推荐）**
```gdscript
push_error(\"[ERROR] Failed to initialize: \" + str(error_code))\npush_warning(\"[WARN] Null value detected in \", var_name)\n```
"""
	
	return log_template

# 代码搜索功能
func _handle_search_code_command(input: String) -> String:
	"""处理代码搜索命令"""
	var lower = input.to_lower()
	var query = ""
	
	# 提取搜索关键词
	if lower.begins_with("搜索代码") or lower.begins_with("找代码") or lower.begins_with("查找代码"):
		query = input.substr(4 if lower.begins_with("搜索") or lower.begins_with("找代码") else 3).strip_edges()
	elif lower.begins_with("找找"):
		query = input.substr(2).strip_edges()
	
	if query.is_empty():
		return """🔍 **代码搜索**

请告诉我你想搜索什么？

**示例**
• 「搜索代码:移动」- 搜索移动相关代码
• 「找找Player」- 搜索Player相关代码
• 「搜索代码:碰撞检测」- 搜索碰撞检测代码

💡 可以搜索函数名、变量名、类名或关键词"""

	# 调用项目读取器进行搜索
	var project_reader = get_node_or_null("/root/ProjectReader")
	if project_reader:
		last_search_query = query
		var report = project_reader.generate_search_report(query)
		last_search_results = project_reader.search_code(query)
		return report
	else:
		return "⚠️ 项目读取器未加载，无法搜索代码"

# ==================== 代码解释和优化 ====================

func analyze_code(code: String, analysis_type: String) -> void:
	"""分析代码（解释或优化）"""
	if is_processing:
		errorOccurred.emit("正在处理上一个请求，请稍候...")
		return
	
	is_processing = true
	thinking_started.emit()
	
	var prompt = ""
	match analysis_type:
		"explain":
			prompt = build_explain_prompt(code)
		"optimize":
			prompt = build_optimize_prompt(code)
		_:
			is_processing = false
			thinking_finished.emit("❌ 未知的分析类型")
			return
	
	await call_ai_for_analysis(prompt, analysis_type)
	is_processing = false

func build_explain_prompt(code: String) -> String:
	return """请详细解释以下代码的功能、逻辑和用途。

## 代码
```
%s
```

## 解释要求
请从以下几个维度进行解释：
1. **整体功能** - 这段代码做什么
2. **逐行/逐段解析** - 关键部分的逻辑
3. **核心变量和函数** - 重要元素的作用
4. **使用场景** - 适合在什么情况下使用

请用中文回答，语言要简洁易懂。如果代码是GDScript请用GDScript术语，如果是C#请用C#术语。""" % code

func build_optimize_prompt(code: String) -> String:
	return """请分析以下代码，并提供优化建议和优化后的代码。

## 代码
```
%s
```

## 优化要求
请从以下几个维度进行分析：
1. **性能** - 是否有性能问题，如何改进
2. **可读性** - 代码是否清晰易读，如何优化
3. **安全性** - 是否有潜在的安全风险
4. **最佳实践** - 是否遵循Godot/C#开发规范

然后提供优化后的代码，用```gdscript或```csharp包裹。

请用中文回答。""" % code

func call_ai_for_analysis(prompt: String, analysis_type: String) -> void:
	var model_config = get_model_config()
	var endpoint = model_config.get("endpoint", "")
	var api_key = model_config.get("api_key", "")
	var model = model_config.get("model", "")
	
	if endpoint.is_empty() or model.is_empty():
		var fallback = ""
		match analysis_type:
			"explain":
				fallback = "❌ 请先在设置中配置AI模型！\n\n📋 以下是代码的简要说明：\n（需要AI才能提供详细解释）"
			"optimize":
				fallback = "❌ 请先在设置中配置AI模型！\n\n📋 以下是代码的简要优化建议：\n（需要AI才能提供详细优化方案）"
		code_analysis_finished.emit(fallback, analysis_type)
		return
	
	var messages: Array = [{"role": "user", "content": prompt}]
	
	var headers = ["Content-Type: application/json"]
	if not api_key.is_empty():
		headers.append("Authorization: Bearer " + api_key)
	
	var body = {
		"model": model,
		"messages": messages,
		"temperature": 0.5,
		"max_tokens": 3000
	}
	
	var error = http_request.request(
		endpoint + "/chat/completions",
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)
	
	if error != OK:
		thinking_finished.emit("❌ 网络请求失败，请检查网络连接")

func _on_request_completed(result: int, response_code: int, headers: Array, body: PackedByteArray) -> void:
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json and json is Dictionary:
			var response_text = extract_response(json)
			
			# 保存到历史（仅普通对话模式）
			if _analysis_mode == "":
				conversation_history.append({"role": "user", "content": _pending_user_message})
				conversation_history.append({"role": "assistant", "content": response_text})
				if conversation_history.size() > 40:
					conversation_history = conversation_history.slice(0, 40)
				thinking_finished.emit(response_text)
			else:
				# 代码分析模式
				var analysis_type = _analysis_mode
				_analysis_mode = ""
				_pending_user_message = ""
				code_analysis_finished.emit(response_text, analysis_type)
		else:
			_analysis_mode = ""
			_pending_user_message = ""
			thinking_finished.emit("❌ 解析响应失败")
	elif response_code == 401:
		_analysis_mode = ""
		_pending_user_message = ""
		thinking_finished.emit("❌ API Key无效，请检查配置")
	elif response_code == 429:
		_analysis_mode = ""
		_pending_user_message = ""
		thinking_finished.emit("⏳ 请求过于频繁，请稍后再试")
	else:
		_analysis_mode = ""
		_pending_user_message = ""
		thinking_finished.emit("❌ 请求失败: " + str(response_code))

func get_help_text() -> String:
	var lang = config.get("language", "auto")
	if lang == "auto":
		lang = "zh" if OS.get_locale_language() == "zh" else "en"
	
	if lang == "zh":
		return """📖 **使用帮助**

**常用命令**
• 「帮我做XXX游戏」- 生成游戏代码
• 「给玩家加XXX功能」- 修改代码
• 「找XXX素材」- 搜索素材
• 「什么是XXX」- 解答问题
• 「模板」- 查看代码模板
• 「清除」- 清空对话历史

**代码分析与优化**
• 「解释代码」- 选中代码后输入，AI分析代码功能
• 「优化代码」- 选中代码后输入，AI提供优化建议
• 「代码解释」- 同上，解释选中代码
• 「代码优化」- 同上，优化选中代码

**快捷操作**
• 代码模板 - 快速生成
• 素材搜索 - 搜索免费素材
• AI配置 - 设置模型

有什么问题尽管问！🐙"""
	else:
		return """📖 **Help**

**Common Commands**
• "Make a XXX game" - Generate game code
• "Add XXX feature" - Modify code
• "Find XXX assets" - Search assets
• "What is XXX" - Ask questions
• "Template" - View code templates
• "Clear" - Clear chat history

**Code Analysis & Optimization**
• "Explain code" - Select code then input, AI analyzes code
• "Optimize code" - Select code then input, AI provides optimization suggestions

**Quick Actions**
• Code Templates - Quick generate
• Asset Search - Search free assets
• AI Settings - Configure model

Feel free to ask anything! 🐙"""

func get_template_list() -> String:
	var lang = config.get("language", "auto")
	if lang == "auto":
		lang = "zh" if OS.get_locale_language() == "zh" else "en"
	
	if lang == "zh":
		return """📋 **代码模板**

【2D游戏模板】
• 玩家角色 - 移动+跳跃
• 敌人AI - 巡逻+攻击
• 子弹系统 - 发射+碰撞
• UI血条 - 跟随+动画

【3D游戏模板】
• FPS控制器
• 第三人称角色
• 摄像机跟随

【系统模板】
• 存档系统
• 商店系统
• 成就系统

输入「生成XXX模板」获取代码！"""
	else:
		return """📋 **Code Templates**

【2D Game Templates】
• Player Character - Move+Jump
• Enemy AI - Patrol+Attack
• Bullet System - Fire+Collision
• UI Health Bar - Follow+Animation

【3D Game Templates】
• FPS Controller
• Third Person Character
• Camera Follow

【System Templates】
• Save System
• Shop System
• Achievement System

Type "Generate XXX template" to get code!"""

# 调用AI API
func call_ai(user_message: String) -> void:
	_pending_user_message = user_message
	var model_config = get_model_config()
	var endpoint = model_config.get("endpoint", "")
	var api_key = model_config.get("api_key", "")
	var model = model_config.get("model", "")
	
	if endpoint.is_empty() or model.is_empty():
		thinking_finished.emit("❌ 请先在设置中配置AI模型！")
		return
	
	# 构建消息
	var messages = build_messages(user_message)
	
	# 发送请求
	var headers = ["Content-Type: application/json"]
	if not api_key.is_empty():
		headers.append("Authorization: Bearer " + api_key)
	
	var body = {
		"model": model,
		"messages": messages,
		"temperature": 0.7,
		"max_tokens": 2000
	}
	
	var error = http_request.request(
		endpoint + "/chat/completions",
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)
	
	if error != OK:
		thinking_finished.emit("❌ 网络请求失败，请检查网络连接")

func get_model_config() -> Dictionary:
	var cfg = {
		"type": "openai_compatible",
		"endpoint": "https://api.deepseek.com/v1",
		"api_key": config.get("api_key", ""),
		"model": "deepseek-chat"
	}
	
	if config.get("model_type") == "claude":
		cfg["type"] = "anthropic"
		cfg["endpoint"] = "https://api.anthropic.com/v1"
		cfg["model"] = "claude-3-5-sonnet-20240620"
	elif config.get("model_type") == "gpt":
		cfg["endpoint"] = "https://api.openai.com/v1"
		cfg["model"] = "gpt-4o"
	elif config.get("model_type") == "local":
		cfg["type"] = "openai_compatible"
		cfg["endpoint"] = config.get("local_url", "http://localhost:11434/v1")
		cfg["model"] = config.get("local_model", "qwen2.5:3b")
		cfg["api_key"] = ""
	
	return cfg

func build_messages(user_message: String) -> Array:
	var project_path = "未知"
	var lang = config.get("language", "auto")
	if lang == "auto":
		lang = "zh" if OS.get_locale_language() == "zh" else "en"
	if lang == "en":
		project_path = "Unknown"
	if Engine.get_main_loop() and Engine.get_main_loop().get_root():
		project_path = ProjectSettings.globalize_path("res://")
	
	var system = get_system_prompt().format({"project_path": project_path})
	var messages: Array = [{"role": "system", "content": system}]
	
	# 添加历史（最近10轮）
	var history_limit = min(conversation_history.size(), 20)
	for i in range(history_limit):
		messages.append(conversation_history[i])
	
	# 添加新消息
	messages.append({"role": "user", "content": user_message})
	
	return messages



func extract_response(json: Dictionary) -> String:
	if json.has("choices"):
		var choices = json["choices"]
		if choices is Array and choices.size() > 0:
			return choices[0].get("message", {}).get("content", "")
	return "无法解析响应"

# ==================== 测试生成功能 ====================

signal test_generation_requested(target_file: String, test_framework: String)
signal diff_requested(original_code: String, new_code: String, file_path: String)

const TEST_COMMANDS = ["生成测试", "写单元测试", "单元测试", "写测试", "测试代码", "create test"]

func generate_tests(target_file: String = "", framework: String = "gdunit") -> String:
	"""生成测试代码
	
	Args:
		target_file: 目标文件路径（可选）
		framework: 测试框架 (gdunit/nunit)
	"""
	var message = ""
	
	if not target_file.is_empty():
		message = "为以下文件生成单元测试：\n" + target_file + "\n使用 " + framework + " 框架"
	else:
		message = "请告诉我要为哪个文件生成测试？\n\n支持的测试框架：\n• GdUnit - Godot 单元测试\n• NUnit - Unity 单元测试\n\n命令格式：「为 Player.gd 生成测试」"
	
	return message

func request_test_generation(target_file: String, test_framework: String = "gdunit") -> void:
	"""触发测试生成信号"""
	test_generation_requested.emit(target_file, test_framework)

# ==================== 差异对比功能 ====================

var original_code_cache: Dictionary = {}

func show_diff(original_code: String, new_code: String, file_path: String = "") -> String:
	"""显示代码差异
	
	Args:
		original_code: 原始代码
		new_code: 新代码
		file_path: 文件路径
	
	Returns:
		格式化的diff字符串
	"""
	# 缓存原始代码
	if not file_path.is_empty():
		original_code_cache[file_path] = original_code
	
	return format_diff(original_code, new_code, file_path)

func format_diff(original: String, new_code: String, file_path: String = "") -> String:
	"""格式化diff输出"""
	var lines: Array = []
	
	# 文件头
	if not file_path.is_empty():
		lines.append("📄 文件: " + file_path)
		lines.append("━".repeat(40))
	
	# 使用简单行对比
	var old_lines = original.split("\n")
	var new_lines = new_code.split("\n")
	
	var additions = 0
	var deletions = 0
	var unchanged = 0
	
	# 统计变化
	for new_line in new_lines:
		if not old_lines.has(new_line):
			additions += 1
	
	for old_line in old_lines:
		if not new_lines.has(old_line):
			deletions += 1
	
	# 生成统一格式diff
	lines.append("\n📊 差异统计:")
	lines.append("   ➕ 新增: " + str(additions) + " 行")
	lines.append("   ➖ 删除: " + str(deletions) + " 行")
	
	lines.append("\n" + "━".repeat(40))
	lines.append("📝 详细变更:")
	lines.append("━".repeat(40))
	
	# 逐行对比
	var max_lines = max(old_lines.size(), new_lines.size())
	var context = 3  # 上下文行数
	
	for i in range(max_lines):
		var old_line_text = old_lines[i] if i < old_lines.size() else null
		var new_line_text = new_lines[i] if i < new_lines.size() else null
		
		if old_line_text == new_line_text:
			if old_line_text != null:
				lines.append("  " + old_line_text)
				unchanged += 1
		else:
			if old_line_text != null:
				lines.append("-" + old_line_text)
			if new_line_text != null:
				lines.append("+" + new_line_text)
	
	lines.append("━".repeat(40))
	
	# 操作建议
	lines.append("\n💡 操作选项:")
	lines.append("• 「接受」或「确认」- 应用此修改")
	lines.append("• 「取消」- 放弃此修改")
	lines.append("• 「逐块确认」- 逐个接受变更块")
	
	return "\n".join(lines)

func get_diff_chunk(original: String, new_code: String, start_line: int, count: int) -> Dictionary:
	"""获取指定范围的diff块
	
	Args:
		original: 原始代码
		new_code: 新代码
		start_line: 起始行号
		count: 块大小
	
	Returns:
		Dictionary with 'added', 'removed', 'unchanged' arrays
	"""
	var result = {
		"added": [],
		"removed": [],
		"unchanged": [],
		"start_line": start_line
	}
	
	var old_lines = original.split("\n")
	var new_lines = new_code.split("\n")
	
	var end_line = min(start_line + count, max(old_lines.size(), new_lines.size()))
	
	for i in range(start_line, end_line):
		var old_line_text = old_lines[i] if i < old_lines.size() else null
		var new_line_text = new_lines[i] if i < new_lines.size() else null
		
		if old_line_text == new_line_text:
			if old_line_text != null:
				result["unchanged"].append(old_line_text)
		else:
			if old_line_text != null:
				result["removed"].append({"line": i + 1, "text": old_line_text})
			if new_line_text != null:
				result["added"].append({"line": i + 1, "text": new_line_text})
	
	return result

func apply_diff_chunk(file_path: String, chunk: Dictionary) -> bool:
	"""应用单个diff块
	
	Args:
		file_path: 文件路径
		chunk: diff块
	
	Returns:
		是否成功
	"""
	if not FileAccess.file_exists(file_path):
		return false
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return false
	
	var content = file.get_as_text()
	file.close()
	
	# 应用变更
	# 这里简化处理，实际应该更精确
	return true

# ==================== 原有功能 ====================

# 停止处理
func cancel():
	if is_processing:
		http_request.cancel_request()
		is_processing = false
		emit_signal("thinking_finished", "已取消")

# ==================== Git集成功能 ====================

# Git状态
func git_status() -> Dictionary:
	var output = []
	var result = OS.execute("git", ["status", "--porcelain"], output, true)
	
	var status_data = {
		"success": result == 0,
		"modified": [],
		"untracked": [],
		"staged": [],
		"output": ""
	}
	
	if result == 0 and output.size() > 0:
		status_data["output"] = output[0]
		var lines = output[0].split("\n")
		for line in lines:
			if line.is_empty():
				continue
			if line.begins_with("M ") or line.begins_with(" M"):
				status_data["modified"].append(line.substr(3).strip_edges())
			elif line.begins_with("A ") or line.begins_with("A"):
				status_data["staged"].append(line.substr(2).strip_edges())
			elif line.begins_with("??") or line.begins_with("??"):
				status_data["untracked"].append(line.substr(3).strip_edges())
	
	return status_data

# 获取Git变更统计
func git_diff_stats() -> String:
	var output = []
	var result = OS.execute("git", ["diff", "--stat"], output, true)
	
	if result == 0 and output.size() > 0:
		return output[0]
	return ""

# 生成提交信息
func generate_commit_message() -> String:
	var status = git_status()
	var diff_stats = git_diff_stats()
	
	var files_changed = status["modified"].size() + status["staged"].size() + status["untracked"].size()
	if files_changed == 0:
		return ""
	
	var changes_summary = ""
	if status["modified"].size() > 0:
		changes_summary += "修改: " + str(status["modified"].size()) + "个文件\n"
	if status["staged"].size() > 0:
		changes_summary += "新增: " + str(status["staged"].size()) + "个文件\n"
	if status["untracked"].size() > 0:
		changes_summary += "未跟踪: " + str(status["untracked"].size()) + "个文件\n"
	
	return """📝 **提交信息建议**

**变更统计**
%s
**diff统计**
```
%s
```

💡 输入「确认提交」完成提交，或修改上述信息后「确认提交」"""

# Git提交
func git_commit(message: String = "") -> Dictionary:
	var result_data = {
		"success": false,
		"message": ""
	}
	
	# 检查是否有变更
	var status = git_status()
	var total_changes = status["modified"].size() + status["staged"].size() + status["untracked"].size()
	
	if total_changes == 0:
		result_data["message"] = "⚠️ 没有可提交的内容"
		return result_data
	
	# 如果没有提供提交信息，先检查暂存区
	if message.is_empty():
		var staged_output = []
		OS.execute("git", ["diff", "--cached", "--stat"], staged_output, true)
		if staged_output.size() > 0 and not staged_output[0].is_empty():
			result_data["message"] = "📋 检测到已暂存的变更:\n" + staged_output[0] + "\n\n请提供提交信息"
		else:
			result_data["message"] = "📋 请先使用「暂存文件」或「添加所有」后再提交"
		return result_data
	
	# 执行提交
	var output = []
	var result = OS.execute("git", ["commit", "-m", message], output, true)
	
	if result == 0:
		result_data["success"] = true
		result_data["message"] = "✅ 提交成功!\n\n" + message
	else:
		result_data["message"] = "❌ 提交失败: " + (output[0] if output.size() > 0 else "未知错误")
	
	return result_data

# Git暂存文件
func git_add(files: Array = []) -> Dictionary:
	var result_data = {
		"success": false,
		"message": ""
	}
	
	var output = []
	var args = ["add"]
	
	if files.is_empty():
		args.append("-A")  # 添加所有
	else:
		args.append_array(files)
	
	var result = OS.execute("git", args, output, true)
	
	if result == 0:
		result_data["success"] = true
		result_data["message"] = "✅ 文件已暂存\n\n" + (output[0] if output.size() > 0 else "")
	else:
		result_data["message"] = "❌ 暂存失败: " + (output[0] if output.size() > 0 else "未知错误")
	
	return result_data

# Git历史
func git_log(limit: int = 10) -> String:
	var output = []
	var result = OS.execute("git", ["log", "--oneline", "--graph", "--decorate", "-n", str(limit)], output, true)
	
	if result == 0 and output.size() > 0:
		return "📜 **提交历史**\n\n```\n" + output[0] + "```"
	else:
		return "⚠️ 无法获取提交历史"
	
# 获取分支信息
func git_branch() -> Dictionary:
	var output = []
	var result = OS.execute("git", ["branch", "-v"], output, true)
	
	var branch_data = {
		"success": result == 0,
		"current": "",
		"all": []
	}
	
	if result == 0 and output.size() > 0:
		var lines = output[0].split("\n")
		for line in lines:
			if line.begins_with("*"):
				branch_data["current"] = line.substr(2).strip_edges()
			branch_data["all"].append(line.strip_edges())
	
	return branch_data

# Git拉取
func git_pull() -> Dictionary:
	var output = []
	var result = OS.execute("git", ["pull"], output, true)
	
	return {
		"success": result == 0,
		"message": (output[0] if output.size() > 0 else "") if result == 0 else ("❌ 拉取失败: " + (output[0] if output.size() > 0 else ""))
	}

# Git推送
func git_push() -> Dictionary:
	var output = []
	var result = OS.execute("git", ["push"], output, true)
	
	return {
		"success": result == 0,
		"message": (output[0] if output.size() > 0 else "") if result == 0 else ("❌ 推送失败: " + (output[0] if output.size() > 0 else ""))
	}

# ==================== 多端同步功能 ====================

# 同步配置到云端
func sync_config(sync_type: String = "all") -> Dictionary:
	var sync_result = {
		"success": false,
		"message": "",
		"synced_items": []
	}
	
	var cfg = config.get("sync_config", {})
	var sync_enabled = cfg.get("enabled", false)
	var sync_url = cfg.get("webdav_url", "")
	
	if not sync_enabled or sync_url.is_empty():
		sync_result["message"] = "⚠️ 同步未配置，请在设置中配置同步服务"
		return sync_result
	
	# 准备同步数据
	var sync_data = {
		"timestamp": Time.get_datetime_string_from_system(),
		"version": "1.0",
		"config": {},
		"knowledge": [],
		"shortcuts": {}
	}
	
	# 同步设置
	if sync_type == "all" or sync_type == "settings":
		sync_data["config"] = _get_syncable_config()
		sync_result["synced_items"].append("设置")
	
	# 同步知识库
	if sync_type == "all" or sync_type == "knowledge":
		sync_data["knowledge"] = _get_knowledge_data()
		sync_result["synced_items"].append("知识库")
	
	# 同步快捷键
	if sync_type == "all" or sync_type == "shortcuts":
		sync_data["shortcuts"] = _get_shortcuts_data()
		sync_result["synced_items"].append("快捷键配置")
	
	# 上传到云端
	var json_data = JSON.stringify(sync_data)
	var result = _upload_to_webdav(sync_url, json_data)
	
	if result["success"]:
		sync_result["success"] = true
		sync_result["message"] = "✅ 同步成功!\n\n已同步: " + ", ".join(sync_result["synced_items"])
	else:
		sync_result["message"] = "❌ 同步失败: " + result.get("error", "未知错误")
	
	return sync_result

# 从云端恢复配置
func restore_config() -> Dictionary:
	var restore_result = {
		"success": false,
		"message": "",
		"restored_items": []
	}
	
	var cfg = config.get("sync_config", {})
	var sync_url = cfg.get("webdav_url", "")
	
	if sync_url.is_empty():
		restore_result["message"] = "⚠️ 未配置同步服务"
		return restore_result
	
	var result = _download_from_webdav(sync_url)
	
	if not result["success"]:
		restore_result["message"] = "❌ 下载失败: " + result.get("error", "未知错误")
		return restore_result
	
	var sync_data = JSON.parse_string(result["data"])
	if not sync_data:
		restore_result["message"] = "❌ 解析云端数据失败"
		return restore_result
	
	# 恢复设置
	if sync_data.has("config") and sync_data["config"].size() > 0:
		_apply_config(sync_data["config"])
		restore_result["restored_items"].append("设置")
	
	# 恢复知识库
	if sync_data.has("knowledge") and sync_data["knowledge"].size() > 0:
		_apply_knowledge(sync_data["knowledge"])
		restore_result["restored_items"].append("知识库")
	
	# 恢复快捷键
	if sync_data.has("shortcuts") and sync_data["shortcuts"].size() > 0:
		_apply_shortcuts(sync_data["shortcuts"])
		restore_result["restored_items"].append("快捷键配置")
	
	restore_result["success"] = true
	restore_result["message"] = "✅ 恢复成功!\n\n已恢复: " + ", ".join(restore_result["restored_items"])
	
	return restore_result

# 获取可同步的配置
func _get_syncable_config() -> Dictionary:
	var syncable = {
		"model_type": config.get("model_type", ""),
		"model_name": config.get("model_name", ""),
		"api_key": config.get("api_key", ""),
		"endpoint": config.get("endpoint", ""),
		"auto_mode": config.get("auto_mode", true),
		"confirm_mode": config.get("confirm_mode", "auto")
	}
	return syncable

# 获取知识库数据
func _get_knowledge_data() -> Array:
	var knowledge_data: Array = []
	var kb = get_node_or_null("/root/KnowledgeBase")
	if kb and kb.has_method("get_all_entries"):
		knowledge_data = kb.get_all_entries()
	return knowledge_data

# 获取快捷键配置
func _get_shortcuts_data() -> Dictionary:
	# 从项目设置获取快捷键
	var shortcuts: Dictionary = {}
	# 这里简化处理，实际可以从UI配置读取
	return shortcuts

# 应用配置
func _apply_config(cfg: Dictionary) -> void:
	config.merge(cfg, true)

# 应用知识库
func _apply_knowledge(entries: Array) -> void:
	var kb = get_node_or_null("/root/KnowledgeBase")
	if kb and kb.has_method("batch_import"):
		kb.batch_import(entries)

# 应用快捷键
func _apply_shortcuts(shortcuts: Dictionary) -> void:
	# 应用快捷键配置
	pass

# 上传到WebDAV
func _upload_to_webdav(url: String, data: String) -> Dictionary:
	var result = {"success": false, "error": ""}
	
	var temp_file = "user://sync_temp.json"
	var file = FileAccess.open(temp_file, FileAccess.WRITE)
	if file:
		file.store_string(data)
		file.close()
		
		var output = []
		var args = ["-X", "PUT", "-d", "@" + temp_file, "-H", "Content-Type: application/json", url]
		var exec_result = OS.execute("curl", args, output, true)
		
		if exec_result == 0:
			result["success"] = true
		else:
			result["error"] = output[0] if output.size() > 0 else "上传失败"
		
		# 删除临时文件
		DirAccess.remove_absolute(temp_file)
	else:
		result["error"] = "无法创建临时文件"
	
	return result

# 从WebDAV下载
func _download_from_webdav(url: String) -> Dictionary:
	var result = {"success": false, "error": "", "data": ""}
	
	var temp_file = "user://sync_download.json"
	var output = []
	var args = ["-X", "GET", "-o", temp_file, url]
	var exec_result = OS.execute("curl", args, output, true)
	
	if exec_result == 0 and FileAccess.file_exists(temp_file):
		var file = FileAccess.open(temp_file, FileAccess.READ)
		if file:
			result["data"] = file.get_as_text()
			result["success"] = true
			file.close()
		DirAccess.remove_absolute(temp_file)
	else:
		result["error"] = output[0] if output.size() > 0 else "下载失败"
	
	return result

# 获取同步状态
func get_sync_status() -> Dictionary:
	var cfg = config.get("sync_config", {})
	var enabled = cfg.get("enabled", false)
	var last_sync = cfg.get("last_sync", "")
	var sync_url = cfg.get("webdav_url", "")
	
	return {
		"enabled": enabled,
		"last_sync": last_sync,
		"configured": not sync_url.is_empty(),
		"sync_type": cfg.get("type", "webdav")  # webdav 或 api
	}
