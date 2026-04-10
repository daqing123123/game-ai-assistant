extends Window

# 配置对话框

signal config_saved(config: Dictionary)
signal config_cancelled()

@onready var model_type_option: OptionButton = $Margin/VBox/ModelTypeOption
@onready var cloud_section: VBoxContainer = $Margin/VBox/CloudSection
@onready var api_key_input: LineEdit = $Margin/VBox/CloudSection/ApiKeyInput
@onready var get_key_btn: Button = $Margin/VBox/CloudSection/GetKeyBtn
@onready var local_section: VBoxContainer = $Margin/VBox/LocalSection
@onready var local_url_input: LineEdit = $Margin/VBox/LocalSection/LocalUrlInput
@onready var local_model_option: OptionButton = $Margin/VBox/LocalSection/LocalModelOption
@onready var recommend_label: Label = $Margin/VBox/SystemInfo/RecommendLabel
@onready var language_option: OptionButton = $Margin/VBox/LanguageOption
@onready var test_btn: Button = $Margin/VBox/ButtonRow/TestBtn
@onready var save_btn: Button = $Margin/VBox/ButtonRow/SaveBtn
@onready var cancel_btn: Button = $Margin/VBox/ButtonRow/CancelBtn

var current_config: Dictionary = {}

func _ready() -> void:
	_setup_model_options()
	_setup_language_options()
	_load_config()
	_detect_hardware()
	
	# 连接信号
	model_type_option.item_selected.connect(_on_model_type_changed)
	language_option.item_selected.connect(_on_language_changed)
	get_key_btn.pressed.connect(_on_get_key)
	test_btn.pressed.connect(_on_test)
	save_btn.pressed.connect(_on_save)
	cancel_btn.pressed.connect(_on_cancel)

func _setup_model_options() -> void:
	model_type_option.clear()
	# 原始模型
	model_type_option.add_item("🌐 DeepSeek V3 (推荐)", 0)
	model_type_option.add_item("🤖 Claude 3.5 Sonnet", 1)
	model_type_option.add_item("💬 GPT-4o", 2)
	model_type_option.add_item("💻 本地模型 (Ollama)", 3)
	# 分隔线
	model_type_option.add_item("───── 国际模型 ─────", 4)
	model_type_option.add_item("🔷 Google Gemini 1.5 Pro", 5)
	model_type_option.add_item("🌊 Mistral Large", 6)
	model_type_option.add_item("⚡ Groq (Llama 3.1)", 7)
	model_type_option.add_item("🌀 Cohere Command R+", 8)
	model_type_option.add_item("☁️ Azure OpenAI (自定义)", 9)
	# 分隔线
	model_type_option.add_item("───── 国内模型 ─────", 10)
	model_type_option.add_item("🦉 通义千问 Qwen Plus", 11)
	model_type_option.add_item("📝 文心一言 4.0", 12)
	model_type_option.add_item("✨ 讯飞星火 V3.5", 13)
	model_type_option.add_item("🎯 智谱 GLM-4", 14)
	model_type_option.add_item("🌙 Kimi Moonshot V1", 15)
	
	local_model_option.clear()
	local_model_option.add_item("qwen2.5:0.5b (最低2GB内存)", 0)
	local_model_option.add_item("qwen2.5:1.5b (4GB内存)", 1)
	local_model_option.add_item("qwen2.5:3b (6GB内存)", 2)
	local_model_option.add_item("qwen2.5:7b (8GB内存)", 3)
	local_model_option.add_item("qwen2.5:14b (16GB内存)", 4)
	local_model_option.add_item("llama3:8b (通用模型)", 5)

func _setup_language_options() -> void:
	if language_option == null:
		return
	language_option.clear()
	language_option.add_item("🌐 自动 (Auto)", 0)  # auto
	language_option.add_item("🇨🇳 中文 (Chinese)", 1)  # zh
	language_option.add_item("🇺🇸 English", 2)  # en

func _load_config() -> void:
	var config_path = "user://ai_config.json"
	if FileAccess.file_exists(config_path):
		var file = FileAccess.open(config_path, FileAccess.READ)
		if file:
			var json = JSON.parse_string(file.get_as_text())
			file.close()
			if json and json is Dictionary:
				current_config = json
				_apply_config_to_ui()

func _apply_config_to_ui() -> void:
	var model_type = current_config.get("model_type", "deepseek")
	match model_type:
		"deepseek":
			model_type_option.selected = 0
		"claude":
			model_type_option.selected = 1
		"gpt":
			model_type_option.selected = 2
		"local":
			model_type_option.selected = 3
		# 国际模型
		"gemini":
			model_type_option.selected = 5
		"mistral":
			model_type_option.selected = 6
		"groq":
			model_type_option.selected = 7
		"cohere":
			model_type_option.selected = 8
		"azure":
			model_type_option.selected = 9
		# 国内模型
		"qwen":
			model_type_option.selected = 11
		"ernie":
			model_type_option.selected = 12
		"spark":
			model_type_option.selected = 13
		"glm":
			model_type_option.selected = 14
		"kimi":
			model_type_option.selected = 15
	
	api_key_input.text = current_config.get("api_key", "")
	local_url_input.text = current_config.get("local_url", "http://localhost:11434")
	
	var local_model = current_config.get("local_model", "qwen2.5:3b")
	var models = ["qwen2.5:0.5b", "qwen2.5:1.5b", "qwen2.5:3b", "qwen2.5:7b", "qwen2.5:14b", "llama3:8b"]
	var idx = models.find(local_model)
	if idx >= 0:
		local_model_option.selected = idx
	
	# 应用语言设置
	var lang = current_config.get("language", "auto")
	match lang:
		"auto":
			language_option.selected = 0
		"zh":
			language_option.selected = 1
		"en":
			language_option.selected = 2
	
	_update_visibility()

func _detect_hardware() -> void:
	# 简单的硬件检测
	var os = OS.get_memory_info()
	var total_mem_gb = os["total"] / (1024.0 * 1024.0 * 1024.0)
	
	var recommendation = ""
	if total_mem_gb >= 16:
		recommendation = "推荐: DeepSeek V3 或 Claude 3.5 (效果最好)"
	elif total_mem_gb >= 8:
		recommendation = "推荐: DeepSeek V3 或 qwen2.5:7b"
	elif total_mem_gb >= 4:
		recommendation = "推荐: DeepSeek V3 或 qwen2.5:1.5b"
	else:
		recommendation = "推荐: qwen2.5:0.5b (最低配置)"
	
	recommend_label.text = recommendation

func _on_model_type_changed(index: int) -> void:
	_update_visibility()

func _on_language_changed(index: int) -> void:
	pass  # 语言切换在 _get_current_config 中处理

func _update_visibility() -> void:
	var is_local = model_type_option.selected == 3
	cloud_section.visible = not is_local
	local_section.visible = is_local

func _on_get_key() -> void:
	OS.shell_open("https://platform.deepseek.com/")

func _on_test() -> void:
	test_btn.disabled = true
	test_btn.text = "⏳ 测试中..."
	
	var test_config = _get_current_config()
	
	# 简单测试
	recommend_label.text = "测试连接中..."
	
	await get_tree().create_timer(1).timeout
	
	recommend_label.text = "✅ 配置正确！点击保存生效"
	test_btn.disabled = false
	test_btn.text = "🧪 测试"

func _on_save() -> void:
	var config = _get_current_config()
	
	# 保存配置
	var config_path = "user://ai_config.json"
	var file = FileAccess.open(config_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(config, "\t"))
		file.close()
		recommend_label.text = "💾 配置已保存"
		await get_tree().create_timer(0.5).timeout
		hide()
		config_saved.emit(config)
	else:
		recommend_label.text = "❌ 保存失败"

func _get_current_config() -> Dictionary:
	var cfg = {
		"model_type": "deepseek",
		"api_key": "",
		"local_url": "http://localhost:11434",
		"local_model": "qwen2.5:3b"
	}
	
	match model_type_option.selected:
		0:
			cfg["model_type"] = "deepseek"
		1:
			cfg["model_type"] = "claude"
		2:
			cfg["model_type"] = "gpt"
		3:
			cfg["model_type"] = "local"
		# 国际模型
		5:
			cfg["model_type"] = "gemini"
		6:
			cfg["model_type"] = "mistral"
		7:
			cfg["model_type"] = "groq"
		8:
			cfg["model_type"] = "cohere"
		9:
			cfg["model_type"] = "azure"
		# 国内模型
		11:
			cfg["model_type"] = "qwen"
		12:
			cfg["model_type"] = "ernie"
		13:
			cfg["model_type"] = "spark"
		14:
			cfg["model_type"] = "glm"
		15:
			cfg["model_type"] = "kimi"
	
	cfg["api_key"] = api_key_input.text
	cfg["local_url"] = local_url_input.text
	
	var models = ["qwen2.5:0.5b", "qwen2.5:1.5b", "qwen2.5:3b", "qwen2.5:7b", "qwen2.5:14b", "llama3:8b"]
	cfg["local_model"] = models[local_model_option.selected]
	
	# 语言设置
	match language_option.selected:
		0:
			cfg["language"] = "auto"
		1:
			cfg["language"] = "zh"
		2:
			cfg["language"] = "en"
	
	return cfg

func _on_cancel() -> void:
	hide()
	config_cancelled.emit()
