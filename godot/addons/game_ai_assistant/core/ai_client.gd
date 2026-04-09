extends Node

# AI客户端
# 支持多种AI模型：DeepSeek、Claude、GPT、本地Ollama

signal config_received(config: Dictionary)
signal response_received(response: String)
signal error_occurred(error: String)
signal status_changed(status: String)

var config_manager: Node = null
var current_model: String = ""
var http_request: HTTPRequest = null
var is_requesting: bool = false

# 系统提示词
const SYSTEM_PROMPT = """你是一个专业的游戏开发AI助手。

你的能力：
1. 生成Unity/C#和Godot/GDScript代码
2. 搜索免费可商用的游戏素材
3. 解释代码逻辑
4. 诊断和修复Bug
5. 提供游戏开发建议

回答要简洁实用，代码要有注释。
如果用户需要代码，请用代码块格式输出。

当前项目信息：
- 引擎: Godot
- 项目路径: {project_path}
- 用户正在开发: {project_type}
"""

func _init() -> void:
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

func configure(cfg: Dictionary) -> void:
	config_manager = cfg.get("config_manager", null)
	if config_manager:
		current_model = config_manager.get_model_name()

# 发送消息
func send_message(message: String, history: Array = [], context: Dictionary = {}) -> void:
	if is_requesting:
		error_occurred.emit("正在处理上一个请求，请稍候...")
		return
	
	is_requesting = true
	status_changed.emit("正在思考...")
	
	# 构建请求
	var model_config = get_model_config()
	var endpoint = model_config.get("endpoint", "")
	var api_key = model_config.get("api_key", "")
	var model = model_config.get("model", "")
	
	if endpoint.is_empty() or model.is_empty():
		error_occurred.emit("请先配置AI模型")
		is_requesting = false
		return
	
	# 构建消息
	var messages = build_messages(message, history, context)
	
	# 发送请求
	var model_type = model_config.get("type", "openai_compatible")
	match model_type:
		"anthropic":
			await send_anthropic_request(endpoint, api_key, model, messages)
		"gemini":
			await send_gemini_request(endpoint, api_key, model, messages)
		"ernie":
			await send_ernie_request(endpoint, api_key, model, messages)
		"spark":
			await send_spark_request(endpoint, api_key, model, messages)
		"cohere":
			await send_cohere_request(endpoint, api_key, model, messages)
		_:
			await send_openai_request(endpoint, api_key, model, messages)
	
	is_requesting = false

func get_model_config() -> Dictionary:
	var cfg = {
		"type": "openai_compatible",
		"endpoint": "https://api.deepseek.com/v1",
		"api_key": "",
		"model": "deepseek-chat"
	}
	
	if config_manager and config_manager.is_cloud_model():
		var model_name = config_manager.config.get("model_name", "deepseek")
		match model_name:
			"claude":
				cfg["type"] = "anthropic"
				cfg["endpoint"] = "https://api.anthropic.com/v1"
				cfg["model"] = "claude-3-5-sonnet-20240620"
			"deepseek":
				cfg["endpoint"] = "https://api.deepseek.com/v1"
				cfg["model"] = "deepseek-chat"
			"gpt":
				cfg["endpoint"] = "https://api.openai.com/v1"
				cfg["model"] = "gpt-4o"
			# 国际模型
			"gemini":
				cfg["type"] = "gemini"
				cfg["endpoint"] = "https://generativelanguage.googleapis.com"
				cfg["model"] = "gemini-1.5-pro"
			"mistral":
				cfg["endpoint"] = "https://api.mistral.ai/v1"
				cfg["model"] = "mistral-large-latest"
			"groq":
				cfg["endpoint"] = "https://api.groq.com/openai/v1"
				cfg["model"] = "llama-3.1-70b-versatile"
			"cohere":
				cfg["type"] = "cohere"
				cfg["endpoint"] = "https://api.cohere.ai/v1"
				cfg["model"] = "command-r-plus"
			"azure":
				cfg["endpoint"] = config_manager.config.get("azure_endpoint", "")
				cfg["model"] = config_manager.config.get("azure_deployment", "")
			# 国内模型
			"qwen":
				cfg["endpoint"] = "https://dashscope.aliyuncs.com/compatible-mode/v1"
				cfg["model"] = "qwen-plus"
			"ernie":
				cfg["type"] = "ernie"
				cfg["endpoint"] = "https://qianfan.baidubce.com/v2"
				cfg["model"] = "ernie-4.0-8k-latest"
			"spark":
				cfg["type"] = "spark"
				cfg["endpoint"] = "https://spark-api.xf-yun.com"
				cfg["model"] = "generalv3.5"
			"glm":
				cfg["endpoint"] = "https://open.bigmodel.cn/api/paas/v4"
				cfg["model"] = "glm-4"
			"kimi":
				cfg["endpoint"] = "https://api.moonshot.cn/v1"
				cfg["model"] = "moonshot-v1-8k"
		cfg["api_key"] = config_manager.config.get("api_key", "")
	elif config_manager and config_manager.is_local_model():
		cfg["type"] = "openai_compatible"
		cfg["endpoint"] = config_manager.config.get("local_url", "http://localhost:11434/v1")
		cfg["model"] = config_manager.config.get("model_name", "qwen2.5:3b")
		cfg["api_key"] = ""
	
	return cfg

func build_messages(new_message: String, history: Array, context: Dictionary) -> Array:
	var project_path = "未知"
	var project_type = "通用游戏"
	
	# 获取项目信息
	if Engine.get_main_loop().root:
		project_path = ProjectSettings.globalize_path("res://")
	
	var system_prompt = SYSTEM_PROMPT.format({
		"project_path": project_path,
		"project_type": project_type
	})
	
	var messages: Array = [{"role": "system", "content": system_prompt}]
	
	# 添加历史（限制数量）
	var history_limit = 10
	for i in range(min(history.size(), history_limit * 2)):
		messages.append(history[i])
	
	# 添加新消息
	messages.append({"role": "user", "content": new_message})
	
	return messages

func send_openai_request(endpoint: String, api_key: String, model: String, messages: Array) -> void:
	var headers = ["Content-Type: application/json"]
	if not api_key.is_empty():
		headers.append("Authorization: Bearer " + api_key)
	
	var body = {
		"model": model,
		"messages": messages,
		"temperature": 0.7,
		"max_tokens": 2000
	}
	
	var result = await http_request.request(
		endpoint + "/chat/completions",
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)
	
	if result != HTTPRequest.RESULT_SUCCESS:
		error_occurred.emit("网络请求失败: " + str(result))

func send_anthropic_request(endpoint: String, api_key: String, model: String, messages: Array) -> void:
	# Anthropic使用不同的API格式
	var system_prompt = ""
	var last_message = ""
	
	for msg in messages:
		if msg["role"] == "system":
			system_prompt = msg["content"]
		elif msg["role"] == "user":
			last_message = msg["content"]
	
	var headers = [
		"Content-Type: application/json",
		"x-api-key: " + api_key,
		"anthropic-version: 2023-06-01"
	]
	
	var body = {
		"model": model,
		"max_tokens": 2000,
		"messages": [{"role": "user", "content": last_message}]
	}
	
	if not system_prompt.is_empty():
		body["system"] = system_prompt
	
	var result = await http_request.request(
		endpoint + "/messages",
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)
	
	if result != HTTPRequest.RESULT_SUCCESS:
		error_occurred.emit("网络请求失败: " + str(result))

func send_gemini_request(endpoint: String, api_key: String, model: String, messages: Array) -> void:
	# Google Gemini API格式
	var last_message = ""
	var system_prompt = ""
	
	for msg in messages:
		if msg["role"] == "system":
			system_prompt = msg["content"]
		elif msg["role"] == "user":
			last_message = msg["content"]
	
	var headers = [
		"Content-Type: application/json"
	]
	
	var contents = []
	if not system_prompt.is_empty():
		contents.append({"role": "user", "parts": [{"text": system_prompt + "\n\n" + last_message}]})
	else:
		contents.append({"role": "user", "parts": [{"text": last_message}]})
	
	var body = {
		"contents": contents,
		"generationConfig": {
			"temperature": 0.7,
			"maxOutputTokens": 2000
		}
	}
	
	var url = endpoint + "/v1beta/models/" + model + ":generateContent?key=" + api_key
	
	var result = await http_request.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)
	
	if result != HTTPRequest.RESULT_SUCCESS:
		error_occurred.emit("网络请求失败: " + str(result))

func send_ernie_request(endpoint: String, api_key: String, model: String, messages: Array) -> void:
	# 百度文心一言 - 需要签名认证
	var last_message = ""
	var system_prompt = ""
	
	for msg in messages:
		if msg["role"] == "system":
			system_prompt = msg["content"]
		elif msg["role"] == "user":
			last_message = msg["content"]
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	]
	
	var contents = []
	if not system_prompt.is_empty():
		contents.append({"role": "user", "content": system_prompt + "\n\n" + last_message})
	else:
		contents.append({"role": "user", "content": last_message})
	
	var body = {
		"model": model,
		"messages": contents,
		"temperature": 0.7,
		"max_tokens": 2000
	}
	
	var result = await http_request.request(
		endpoint + "/chat/completions",
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)
	
	if result != HTTPRequest.RESULT_SUCCESS:
		error_occurred.emit("网络请求失败: " + str(result))

func send_spark_request(endpoint: String, api_key: String, model: String, messages: Array) -> void:
	# 讯飞星火API - WebSocket优先，这里使用HTTP
	var last_message = ""
	var system_prompt = ""
	
	for msg in messages:
		if msg["role"] == "system":
			system_prompt = msg["content"]
		elif msg["role"] == "user":
			last_message = msg["content"]
	
	var app_id = config_manager.config.get("spark_app_id", "") if config_manager else ""
	var api_secret = config_manager.config.get("spark_api_secret", "") if config_manager else ""
	
	var headers = [
		"Content-Type: application/json",
		"X-Appid: " + app_id,
		"X-CurTime: " + str(int(Time.get_unix_time_from_system()))
	]
	
	var payload = {
		"header": {
			"app_id": app_id,
			"uid": "game_ai_assistant"
		},
		"parameter": {
			"chat": {
				"domain": model,
				"temperature": 0.5,
				"max_tokens": 2048
			}
		},
		"payload": {
			"message": {
				"text": []
			}
		}
	}
	
	if not system_prompt.is_empty():
		payload["payload"]["message"]["text"].append({"role": "system", "content": system_prompt})
	payload["payload"]["message"]["text"].append({"role": "user", "content": last_message})
	
	var url = endpoint + "/v3.1/chat"
	var result = await http_request.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	
	if result != HTTPRequest.RESULT_SUCCESS:
		error_occurred.emit("网络请求失败: " + str(result))

func send_cohere_request(endpoint: String, api_key: String, model: String, messages: Array) -> void:
	# Cohere API格式
	var last_message = ""
	var system_prompt = ""
	
	for msg in messages:
		if msg["role"] == "system":
			system_prompt = msg["content"]
		elif msg["role"] == "user":
			last_message = msg["content"]
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key,
		"Accept: application/json"
	]
	
	var chat_history = []
	if not system_prompt.is_empty():
		chat_history.append({"role": "SYSTEM", "message": system_prompt})
	chat_history.append({"role": "USER", "message": last_message})
	
	var body = {
		"model": model,
		"chat_history": chat_history,
		"message": last_message,
		"temperature": 0.7,
		"max_tokens": 2000
	}
	
	var result = await http_request.request(
		endpoint + "/chat",
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)
	
	if result != HTTPRequest.RESULT_SUCCESS:
		error_occurred.emit("网络请求失败: " + str(result))

func _on_request_completed(result: int, response_code: int, headers: Array, body: PackedByteArray) -> void:
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json:
			var response_text = extract_response_text(json)
			response_received.emit(response_text)
		else:
			error_occurred.emit("解析响应失败")
	elif response_code == 401:
		error_occurred.emit("API Key无效，请检查配置")
	elif response_code == 429:
		error_occurred.emit("请求过于频繁，请稍后再试")
	elif response_code == 0:
		error_occurred.emit("网络连接失败，请检查网络")
	else:
		error_occurred.emit("请求失败: " + str(response_code))

func extract_response_text(json: Dictionary) -> String:
	# OpenAI兼容格式
	if json.has("choices"):
		var choices = json["choices"]
		if choices.size() > 0:
			return choices[0].get("message", {}).get("content", "")
	
	# Anthropic格式
	if json.has("content"):
		var content = json["content"]
		if content is Array and content.size() > 0:
			return content[0].get("text", "")
	
	# Gemini格式
	if json.has("candidates"):
		var candidates = json["candidates"]
		if candidates.size() > 0:
			var content_obj = candidates[0].get("content", {})
			if content_obj.has("parts"):
				var parts = content_obj["parts"]
				if parts.size() > 0:
					return parts[0].get("text", "")
	
	# 文心一言格式
	if json.has("result"):
		return json.get("result", {}).get("generated_text", "")
	
	# Cohere格式
	if json.has("text"):
		return json.get("text", "")
	
	return "无法解析响应"

# 测试连接
func test_connection() -> bool:
	if is_requesting:
		return false
	
	var model_config = get_model_config()
	var endpoint = model_config.get("endpoint", "")
	var api_key = model_config.get("api_key", "")
	
	if endpoint.is_empty():
		return false
	
	status_changed.emit("测试连接中...")
	
	# 简单的连接测试
	var headers = ["Content-Type: application/json"]
	if not api_key.is_empty():
		headers.append("Authorization: Bearer " + api_key)
	
	var body = {
		"model": model_config.get("model", ""),
		"messages": [{"role": "user", "content": "hi"}],
		"max_tokens": 10
	}
	
	var result = await http_request.request(
		endpoint + "/chat/completions",
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)
	
	return result == HTTPRequest.RESULT_SUCCESS

# 停止请求
func cancel_request() -> void:
	if is_requesting:
		http_request.cancel_request()
		is_requesting = false
		status_changed.emit("已取消")
