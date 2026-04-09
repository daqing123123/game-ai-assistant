extends PanelContainer

# 停靠面板 - 快捷操作栏

signal action_requested(action: String, data: Dictionary)

@onready var templates_btn: Button = $Margin/VBox/TemplatesBtn
@onready var assets_btn: Button = $Margin/VBox/AssetsBtn
@onready var project_btn: Button = $Margin/VBox/ProjectBtn
@onready var learning_btn: Button = $Margin/VBox/LearningBtn
@onready var knowledge_btn: Button = $Margin/VBox/KnowledgeBtn
@onready var screenshot_btn: Button = $Margin/VBox/ScreenshotBtn
@onready var config_btn: Button = $Margin/VBox/ConfigBtn

func _ready() -> void:
	templates_btn.pressed.connect(_on_templates)
	assets_btn.pressed.connect(_on_assets)
	project_btn.pressed.connect(_on_project)
	learning_btn.pressed.connect(_on_learning)
	knowledge_btn.pressed.connect(_on_knowledge)
	screenshot_btn.pressed.connect(_on_screenshot)
	config_btn.pressed.connect(_on_config)

func _on_templates() -> void:
	action_requested.emit("templates", {})

func _on_assets() -> void:
	action_requested.emit("assets", {})

func _on_project() -> void:
	action_requested.emit("project", {})

func _on_learning() -> void:
	action_requested.emit("learning", {})

func _on_knowledge() -> void:
	action_requested.emit("knowledge", {})

func _on_screenshot() -> void:
	action_requested.emit("screenshot", {})

func _on_config() -> void:
	action_requested.emit("config", {})
