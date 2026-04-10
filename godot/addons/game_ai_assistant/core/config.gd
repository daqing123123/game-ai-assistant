extends RefCounted

# 配置管理器
# 管理AI模型配置、本地存储

const CONFIG_FILE = "user://game_ai_config.json"

# 默认配置
var config: Dictionary = {
	"model_type": "",       # "cloud" / "local"
	"model_name": "",
	"api_key": "",
	"endpoint": "",
	"local_url": "http://localhost:11434/v1",
	"auto_mode": true,       # 自动确认模式
	"confirm_mode": "auto",  # "step" / "auto" / "important"
	"language": "auto",       # "auto" / "zh" / "en"
	# 额外配置（特定模型需要）
	"azure_endpoint": "",
	"azure_deployment": "",
	"spark_app_id": "",
	"spark_api_secret": ""
}

# 双语翻译字典
var translations: Dictionary = {
	"zh": {
		"send": "发送",
		"settings": "设置",
		"help": "帮助",
		"apply": "应用",
		"preview": "预览",
		"knowledge_base": "知识库",
		"daily_learning": "每日学习",
		"project_scan": "扫描项目",
		"search_assets": "搜索素材",
		"undo": "撤销",
		"redo": "重做",
		"history": "历史",
		"syncing": "同步中...",
		"sync_success": "同步成功",
		"sync_failed": "同步失败",
		"generating_code": "正在生成代码...",
		"code_applied": "代码已应用",
		"api_key_required": "请先配置 API Key",
		"select_model": "请选择 AI 模型",
		"connecting": "连接中...",
		"connected": "已连接",
		"error": "错误",
		"success": "成功",
		"cancel": "取消",
		"confirm": "确认",
		"close": "关闭",
		"save": "保存",
		"loading": "加载中...",
		"no_results": "未找到结果",
		"search_hint": "输入你的问题...",
		"help_text": "帮助信息",
		"settings_title": "设置",
		"language": "语言",
		"chinese": "中文",
		"english": "English",
		"auto_detect": "自动",
		"ready": "就绪",
		"thinking": "思考中...",
		"complete": "完成",
		"pending_blocks": "个待应用",
		"model_not_configured": "未配置",
		"clear_history": "清空历史",
		"skip": "跳过",
		"accept": "接受",
		"debug": "调试",
		"search": "搜索",
		"test_generate": "测试生成",
		"diff_compare": "差异对比",
		"project_template": "项目模板",
		"scene_generate": "场景生成",
	},
	"en": {
		"send": "Send",
		"settings": "Settings",
		"help": "Help",
		"apply": "Apply",
		"preview": "Preview",
		"knowledge_base": "Knowledge Base",
		"daily_learning": "Daily Learning",
		"project_scan": "Scan Project",
		"search_assets": "Search Assets",
		"undo": "Undo",
		"redo": "Redo",
		"history": "History",
		"syncing": "Syncing...",
		"sync_success": "Sync successful",
		"sync_failed": "Sync failed",
		"generating_code": "Generating code...",
		"code_applied": "Code applied",
		"api_key_required": "Please configure API Key first",
		"select_model": "Please select AI model",
		"connecting": "Connecting...",
		"connected": "Connected",
		"error": "Error",
		"success": "Success",
		"cancel": "Cancel",
		"confirm": "Confirm",
		"close": "Close",
		"save": "Save",
		"loading": "Loading...",
		"no_results": "No results found",
		"search_hint": "Ask me anything...",
		"help_text": "Help",
		"settings_title": "Settings",
		"language": "Language",
		"chinese": "中文",
		"english": "English",
		"auto_detect": "Auto",
		"ready": "Ready",
		"thinking": "Thinking...",
		"complete": "Complete",
		"pending_blocks": " pending",
		"model_not_configured": "Not configured",
		"clear_history": "Clear",
		"skip": "Skip",
		"accept": "Accept",
		"debug": "Debug",
		"search": "Search",
		"test_generate": "Test",
		"diff_compare": "Diff",
		"project_template": "Template",
		"scene_generate": "Scene",
	}
}

# 获取翻译文本
func _tr(key: String) -> String:
	var lang = config.get("language", "auto")
	if lang == "auto":
		lang = "zh" if OS.get_locale_language() == "zh" else "en"
	return translations.get(lang, translations["en"]).get(key, key)

# 获取当前语言
func get_current_language() -> String:
	var lang = config.get("language", "auto")
	if lang == "auto":
		return "zh" if OS.get_locale_language() == "zh" else "en"
	return lang

# 模型列表
const CLOUD_MODELS: Dictionary = {
	"deepseek": {
		"name": "DeepSeek V3",
		"endpoint": "https://api.deepseek.com/v1",
		"model": "deepseek-chat",
		"free_credit": true,
		"china_friendly": true
	},
	"claude": {
		"name": "Claude 3.5 Sonnet",
		"endpoint": "https://api.anthropic.com/v1",
		"model": "claude-3-5-sonnet-20240620",
		"free_credit": false,
		"china_friendly": false
	},
	"gpt": {
		"name": "GPT-4o",
		"endpoint": "https://api.openai.com/v1",
		"model": "gpt-4o",
		"free_credit": false,
		"china_friendly": false
	},
	# 国际模型
	"gemini": {
		"name": "Google Gemini 1.5 Pro",
		"endpoint": "https://generativelanguage.googleapis.com",
		"model": "gemini-1.5-pro",
		"free_credit": true,
		"china_friendly": false
	},
	"mistral": {
		"name": "Mistral Large",
		"endpoint": "https://api.mistral.ai/v1",
		"model": "mistral-large-latest",
		"free_credit": false,
		"china_friendly": false
	},
	"groq": {
		"name": "Groq (Llama 3.1)",
		"endpoint": "https://api.groq.com/openai/v1",
		"model": "llama-3.1-70b-versatile",
		"free_credit": true,
		"china_friendly": false
	},
	"cohere": {
		"name": "Cohere Command R+",
		"endpoint": "https://api.cohere.ai/v1",
		"model": "command-r-plus",
		"free_credit": false,
		"china_friendly": false
	},
	"azure": {
		"name": "Azure OpenAI",
		"endpoint": "",
		"model": "",
		"free_credit": false,
		"china_friendly": true,
		"custom_endpoint": true
	},
	# 国内模型
	"qwen": {
		"name": "通义千问 Qwen Plus",
		"endpoint": "https://dashscope.aliyuncs.com/compatible-mode/v1",
		"model": "qwen-plus",
		"free_credit": true,
		"china_friendly": true
	},
	"ernie": {
		"name": "文心一言 4.0",
		"endpoint": "https://qianfan.baidubce.com/v2",
		"model": "ernie-4.0-8k-latest",
		"free_credit": false,
		"china_friendly": true
	},
	"spark": {
		"name": "讯飞星火 V3.5",
		"endpoint": "https://spark-api.xf-yun.com",
		"model": "generalv3.5",
		"free_credit": true,
		"china_friendly": true,
		"needs_extra_config": ["spark_app_id", "spark_api_secret"]
	},
	"glm": {
		"name": "智谱 GLM-4",
		"endpoint": "https://open.bigmodel.cn/api/paas/v4",
		"model": "glm-4",
		"free_credit": true,
		"china_friendly": true
	},
	"kimi": {
		"name": "Kimi Moonshot V1",
		"endpoint": "https://api.moonshot.cn/v1",
		"model": "moonshot-v1-8k",
		"free_credit": true,
		"china_friendly": true
	}
}

const LOCAL_MODELS: Dictionary = {
	"qwen2.5:0.5b": {"name": "Qwen 2.5 0.5B", "min_ram": "2GB", "speed": "极快", "suitable": "老电脑"},
	"qwen2.5:1.5b": {"name": "Qwen 2.5 1.5B", "min_ram": "4GB", "speed": "快", "suitable": "普通笔记本"},
	"qwen2.5:3b": {"name": "Qwen 2.5 3B", "min_ram": "6GB", "speed": "较快", "suitable": "游戏本"},
	"qwen2.5:7b": {"name": "Qwen 2.5 7B", "min_ram": "8GB", "speed": "中等", "suitable": "游戏本"},
	"qwen2.5:14b": {"name": "Qwen 2.5 14B", "min_ram": "16GB", "speed": "慢", "suitable": "高端电脑"},
	"llama3:8b": {"name": "Llama 3 8B", "min_ram": "8GB", "speed": "中等", "suitable": "游戏本"},
	"codellama:7b": {"name": "Code Llama 7B", "min_ram": "8GB", "speed": "中等", "suitable": "代码专用"}
}

signal config_changed(config: Dictionary)
signal validation_result(is_valid: bool, message: String)

func _init() -> void:
	load_config()

func load_config() -> bool:
	if FileAccess.file_exists(CONFIG_FILE):
		var file = FileAccess.open(CONFIG_FILE, FileAccess.READ)
		if file:
			var data = JSON.parse_string(file.get_as_text())
			if data:
				config.merge(data, true)
			file.close()
			return true
	return false

func save_config(new_config: Dictionary = {}) -> bool:
	if not new_config.is_empty():
		config.merge(new_config, true)
	
	var file = FileAccess.open(CONFIG_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(config, "\t"))
		file.close()
		config_changed.emit(config)
		return true
	return false

func is_configured() -> bool:
	if config.get("model_type") == "cloud":
		return config.get("api_key", "").length() > 0
	elif config.get("model_type") == "local":
		return config.get("model_name", "").length() > 0
	return false

func is_cloud_model() -> bool:
	return config.get("model_type") == "cloud"

func is_local_model() -> bool:
	return config.get("model_type") == "local"

func get_model_name() -> String:
	if config.get("model_type") == "cloud":
		return CLOUD_MODELS.get(config.get("model_name", ""), {}).get("name", "未配置")
	elif config.get("model_type") == "local":
		return LOCAL_MODELS.get(config.get("model_name", ""), {}).get("name", "未配置")
	return "未配置"

func get_model_config() -> Dictionary:
	var result = {}
	if config.get("model_type") == "cloud":
		var model_info = CLOUD_MODELS.get(config.get("model_name", ""))
		if model_info:
			result = model_info.duplicate()
			result["api_key"] = config.get("api_key", "")
	elif config.get("model_type") == "local":
		result["endpoint"] = config.get("local_url", "http://localhost:11434/v1")
		result["model"] = config.get("model_name", "")
		result["api_key"] = ""  # 本地不需要Key
	
	return result

# 获取系统信息
func get_system_info() -> Dictionary:
	return {
		"os": OS.get_name(),
		"locale": OS.get_locale_language(),
		"driver_name": "unknown",
		"current_memory": OS.get_static_memory_usage() / 1024 / 1024,  # MB
		"available_memory": OS.get_memory_info().available / 1024 / 1024  # MB
	}

# 推荐模型
func recommend_model() -> Array:
	var sys_info = get_system_info()
	var ram_mb = sys_info.get("available_memory", 4096)
	var ram_gb = ram_mb / 1024.0
	var recommendations: Array = []
	
	# 云端推荐（适合所有人）
	recommendations.append({
		"type": "cloud",
		"model": "deepseek",
		"reason": "国内可用，有免费额度，适合所有配置"
	})
	
	# 本地推荐（根据内存）
	if ram_gb >= 16:
		recommendations.append({
			"type": "local",
			"model": "qwen2.5:7b",
			"reason": "你的电脑配置不错，可以使用7B模型"
		})
	elif ram_gb >= 8:
		recommendations.append({
			"type": "local",
			"model": "qwen2.5:3b",
			"reason": "推荐3B模型，速度快效果也不错"
		})
	elif ram_gb >= 4:
		recommendations.append({
			"type": "local",
			"model": "qwen2.5:1.5b",
			"reason": "老电脑也能用，推荐1.5B模型"
		})
	
	return recommendations

# 验证配置
func validate_config(model_type: String, model_name: String, api_key: String = "") -> bool:
	if model_type == "cloud":
		if api_key.is_empty():
			validation_result.emit(false, "云端模型需要API Key")
			return false
		# 简单的Key格式验证
		if not api_key.begins_with("sk-"):
			validation_result.emit(false, "API Key格式错误，应以sk-开头")
			return false
		validation_result.emit(true, "API Key验证通过")
		return true
	elif model_type == "local":
		# 检查Ollama是否运行
		var http = HTTPRequest.new()
		var tree = Engine.get_main_loop().root
		tree.add_child(http)
		
		var result = await http.request("http://localhost:11434/api/tags")
		tree.remove_child(http)
		http.queue_free()
		
		if result == HTTPRequest.RESULT_SUCCESS:
			validation_result.emit(true, "Ollama连接成功")
			return true
		else:
			validation_result.emit(false, "无法连接Ollama，请确保已安装并运行")
			return false
	
	return false

# 获取模型详情
func get_model_details(model_type: String, model_name: String) -> Dictionary:
	if model_type == "cloud":
		return CLOUD_MODELS.get(model_name, {})
	elif model_type == "local":
		return LOCAL_MODELS.get(model_name, {})
	return {}

# 清除配置
func clear_config() -> void:
	config = {
		"model_type": "",
		"model_name": "",
		"api_key": "",
		"endpoint": "",
		"local_url": "http://localhost:11434/v1",
		"auto_mode": true,
		"confirm_mode": "auto",
		"language": "auto"
	}
	save_config()
