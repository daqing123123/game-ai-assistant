extends Node

## 代码生成器 - 根据用户需求生成 Godot/GDScript 代码

var ai_handler: Node

const CODE_TEMPLATES = {
	"player_controller": '''
## 玩家控制器模板
## 使用方法: 创建 Player 节点，挂载此脚本，添加 CharacterBody2D

extends CharacterBody2D

@export var speed: float = 300.0
@export var jump_velocity: float = -400.0
@export var gravity: float = 980.0

func _physics_process(delta: float) -> void:
	# 重力
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# 水平移动
	var direction := Input.get_axis("ui_left", "ui_right")
	velocity.x = direction * speed if direction != 0 else 0
	
	# 跳跃
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity
	
	move_and_slide()
''',

	"platform": '''
## 平台基类模板
## 使用方法: 创建 StaticBody2D 节点，挂载此脚本

extends StaticBody2D

@export var platform_type: String = "normal"  # normal / moving / breakable

func _ready() -> void:
	add_to_group("platforms")
''',

	"enemy": '''
## 敌人AI模板
## 使用方法: 创建 CharacterBody2D 节点，挂载此脚本

extends CharacterBody2D

@export var speed: float = 100.0
@export var detection_range: float = 200.0
@export var health: float = 100.0

var player: Node2D = null
var state: String = "idle"

func _physics_process(delta: float) -> void:
	match state:
		"idle":
			_find_player()
		"chase":
			_chase_player(delta)
		"attack":
			_attack_player()

func _find_player() -> void:
	# 检测玩家
	pass

func _chase_player(_delta: float) -> void:
	# 追击玩家
	pass

func _attack_player() -> void:
	# 攻击玩家
	pass
''',

	"game_manager": '''
## 游戏管理器模板
## 使用方法: 创建 GameManager 节点，挂载此脚本

extends Node2D

signal score_changed(new_score: int)
signal game_over()
signal game_paused(is_paused: bool)

@export var initial_lives: int = 3
@export var score: int = 0:
	set(value):
		score = value
		emit_signal("score_changed", score)

var lives: int = 3
var is_game_over: bool = false
var is_paused: bool = false

func _ready() -> void:
	lives = initial_lives

func add_score(points: int) -> void:
	score += points

func take_damage() -> void:
	lives -= 1
	if lives <= 0:
		end_game()

func end_game() -> void:
	is_game_over = true
	emit_signal("game_over")

func pause_game() -> void:
	is_paused = true
	get_tree().paused = true
	emit_signal("game_paused", true)

func resume_game() -> void:
	is_paused = false
	get_tree().paused = false
	emit_signal("game_paused", false)
'''
}

func _ready() -> void:
	ai_handler = get_parent().get_node("ai_handler") if get_parent().has_node("ai_handler") else null

## 获取可用模板列表
func get_templates() -> Array:
	var templates: Array = []
	for key in CODE_TEMPLATES.keys():
		templates.append({
			"id": key,
			"name": _get_template_name(key),
			"description": _get_template_description(key)
		})
	return templates

func _get_template_name(key: String) -> String:
	var names = {
		"player_controller": "玩家控制器",
		"platform": "平台系统",
		"enemy": "敌人AI",
		"game_manager": "游戏管理器"
	}
	return names.get(key, key)

func _get_template_description(key: String) -> String:
	var descs = {
		"player_controller": "2D平台跳跃玩家控制，包含移动、跳跃、重力",
		"platform": "可配置平台，支持普通/移动/可破坏类型",
		"enemy": "基础敌人AI，支持巡逻/追击/攻击状态",
		"game_manager": "游戏状态管理，积分/生命/暂停"
	}
	return descs.get(key, "")

## 使用模板创建代码
func create_from_template(template_id: String, customizations: Dictionary = {}) -> String:
	if CODE_TEMPLATES.has(template_id):
		var code = CODE_TEMPLATES[template_id]
		# TODO: 应用自定义设置
		return code
	return ""

## 根据描述生成代码 (需要AI)
func generate_code(description: String, callback: Callable) -> void:
	if ai_handler == null:
		callback.call("错误: AI未配置")
		return
	
	var system_prompt = '''你是一个 Godot 4.x 游戏开发助手。
请根据用户需求生成 GDScript 代码。
要求:
1. 使用 Godot 4.x 语法 (@export, @onready 等)
2. 代码完整可运行
3. 添加中文注释
4. 只输出代码，不要解释'''
	
	var user_prompt = "用户需求: " + description + "\n\n请生成对应的 GDScript 代码:"
	
	ai_handler.send_message(user_prompt, system_prompt)
	
	# 连接信号获取结果
	if not ai_handler.response_received.is_connected(callback):
		ai_handler.response_received.connect(callback)

## 保存代码到文件
func save_code_to_file(code: String, file_path: String) -> bool:
	var dir = DirAccess.open("res://")
	if dir == null:
		push_error("无法打开 res:// 目录")
		return false
	
	# 确保目录存在
	var parts = file_path.trim_prefix("res://").split("/")
	if parts.size() > 1:
		var current_path = "res://"
		for i in range(parts.size() - 1):
			current_path += parts[i] + "/"
			if not dir.dir_exists(current_path):
				dir.make_dir(current_path)
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("无法创建文件: " + file_path)
		return false
	
	file.store_string(code)
	file.close()
	print("[GameAI] 代码已保存: " + file_path)
	return true

## 获取项目脚本列表
func get_project_scripts() -> Array:
	var scripts: Array = []
	var dir = DirAccess.open("res://")
	if dir:
		_scan_scripts_recursive(dir, "res://", scripts)
	return scripts

func _scan_scripts_recursive(dir: DirAccess, base_path: String, scripts: Array) -> void:
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir():
			if file_name != "." and file_name != "..":
				var subdir = DirAccess.open(base_path + file_name)
				if subdir:
					_scan_scripts_recursive(subdir, base_path + file_name + "/", scripts)
		elif file_name.ends_with(".gd"):
			scripts.append({
				"name": file_name,
				"path": base_path + file_name
			})
		file_name = dir.get_next()
