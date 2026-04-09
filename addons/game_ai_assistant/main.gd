@tool
extends EditorPlugin

## Game AI Assistant - Godot 4.x AI 开发助手插件
## 功能：代码生成、素材搜索、AI配置、项目管理

const CONFIG_FILE = "user://game_ai_assistant_config.json"
const KNOWLEDGE_DIR = "user://game_ai_assistant_knowledge/"

var dock: Control
var config: Dictionary = {}
var ai_handler: Node
var code_generator: Node
var asset_searcher: Node

func _enter_tree() -> void:
	print("[GameAI] 插件启动中...")
	_load_config()
	_init_components()
	_create_dock()
	print("[GameAI] 插件已就绪！")

func _exit_tree() -> void:
	if dock:
		remove_control_from_dock(DOCK_SLOT_RIGHT_UL, dock)
		dock.queue_free()
	_save_config()
	print("[GameAI] 插件已关闭")

func _load_config() -> void:
	if FileAccess.file_exists(CONFIG_FILE):
		var file = FileAccess.open(CONFIG_FILE, FileAccess.READ)
		if file:
			var json_str = file.get_as_text()
			file.close()
			config = JSON.parse_string(json_str)
			if config == null:
				config = _get_default_config()
	else:
		config = _get_default_config()

func _get_default_config() -> Dictionary:
	return {
		"ai_provider": "ollama",  # ollama / deepseek / none
		"ai_url": "http://localhost:11434/v1",
		"ai_model": "qwen2.5:7b",
		"api_key": "",
		"asset_sources": {
			"kenney": true,
			"freesound": true,
			"opengameart": false
		},
		"auto_confirm": false,  # false=每步确认, true=直接完成
		"theme": "dark",
		"language": "zh_CN"
	}

func _save_config() -> void:
	var file = FileAccess.open(CONFIG_FILE, FileAccess.WRITE)
	if file:
		var json_str = JSON.stringify(config, "\t")
		file.store_string(json_str)
		file.close()

func _init_components() -> void:
	ai_handler = Node.new()
	ai_handler.set_script(load("res://addons/game_ai_assistant/ai_handler.gd"))
	add_child(ai_handler)
	
	code_generator = Node.new()
	code_generator.set_script(load("res://addons/game_ai_assistant/code_generator.gd"))
	add_child(code_generator)
	
	asset_searcher = Node.new()
	asset_searcher.set_script(load("res://addons/game_ai_assistant/asset_searcher.gd"))
	add_child(asset_searcher)

func _create_dock() -> void:
	dock = load("res://addons/game_ai_assistant/ui/main_dock.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
