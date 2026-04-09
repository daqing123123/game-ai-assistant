extends Node

## AI 处理核心 - 支持 Ollama、DeepSeek 等多种模型

var config: Dictionary = {}
var http_client: HTTPRequest
var conversation_history: Array = []
var is_busy: bool = false

signal response_received(text: String)
signal error_occurred(message: String)
signal connection_status_changed(connected: bool)

func _ready() -> void:
	http_client = HTTPRequest.new()
	add_child(http_client)
	http_client.request_completed.connect(_on_request_completed)
	_load_config()

func _load_config() -> void:
	var config_file = "user://game_ai_assistant_config.json"
	if FileAccess.file_exists(config_file):
		var file = FileAccess.open(config_file, FileAccess.READ)
		if file:
			config = JSON.parse_string(file.get_as_text())
			file.close()

func set_config(new_config: Dictionary) -> void:
	config = new_config
	var file = FileAccess.open("user://game_ai_assistant_config.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(config, "\t"))
		file.close()

## 发送消息到 AI
func send_message(message: String, system_prompt: String = "") -> void:
	if is_busy:
		emit_signal("error_occurred", "AI 正在处理中，请稍候...")
		return
	
	is_busy = true
	
	# 添加用户消息到历史
	conversation_history.append({
		"role": "user",
		"content": message
	})
	
	# 构建请求
	var url = config.get("ai_url", "http://localhost:11434/v1")
	var model = config.get("ai_model", "qwen2.5:7b")
	
	# 构建消息列表
	var messages: Array = []
	if system_prompt != "":
		messages.append({"role": "system", "content": system_prompt})
	messages.append_array(conversation_history)
	
	var body = JSON.stringify({
		"model": model,
		"messages": messages,
		"stream": false,
		"temperature": 0.7,
		"max_tokens": 4096
	})
	
	var headers = ["Content-Type: application/json"]
	if config.get("api_key", "") != "":
		headers.append("Authorization: Bearer " + config.get("api_key"))
	
	var result = http_client.request(url + "/chat/completions", headers, HTTPClient.METHOD_POST, body)
	if result != OK:
		is_busy = false
		emit_signal("error_occurred", "请求失败，请检查网络和配置")

func _on_request_completed(result: int, response_code: int, headers: Array, body: PackedByteArray) -> void:
	is_busy = false
	
	if response_code != 200:
		emit_signal("error_occurred", "AI 返回错误: " + str(response_code))
		return
	
	var json_str = body.get_string_from_utf8()
	var json = JSON.parse_string(json_str)
	
	if json and json.has("choices"):
		var assistant_message = json["choices"][0]["message"]["content"]
		conversation_history.append({
			"role": "assistant",
			"content": assistant_message
		})
		emit_signal("response_received", assistant_message)
		emit_signal("connection_status_changed", true)
	else:
		emit_signal("error_occurred", "AI 返回格式错误")

## 测试连接
func test_connection() -> bool:
	if is_busy:
		return false
	
	is_busy = true
	
	var url = config.get("ai_url", "http://localhost:11434/v1")
	var body = JSON.stringify({
		"model": config.get("ai_model", "qwen2.5:7b"),
		"messages": [{"role": "user", "content": "Hi"}],
		"stream": false
	})
	
	var headers = ["Content-Type: application/json"]
	if config.get("api_key", "") != "":
		headers.append("Authorization: Bearer " + config.get("api_key"))
	
	var result = http_client.request(url + "/chat/completions", headers, HTTPClient.METHOD_POST, body)
	if result != OK:
		is_busy = false
		return false
	return true

## 清除对话历史
func clear_history() -> void:
	conversation_history.clear()

## 获取配置信息
func get_status() -> Dictionary:
	return {
		"provider": config.get("ai_provider", "ollama"),
		"model": config.get("ai_model", "qwen2.5:7b"),
		"url": config.get("ai_url", ""),
		"is_connected": not is_busy,
		"history_count": conversation_history.size()
	}
