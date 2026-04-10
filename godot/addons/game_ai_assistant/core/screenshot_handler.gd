extends Node

# 截图处理器 - 捕获编辑器截图供AI分析
# Phase 4 功能

signal screenshot_captured(image: Image)
signal screenshot_ready(data: Dictionary)

var _screenshot_cache: Image

func _ready() -> void:
	print("📸 截图处理器已就绪")

# 捕获编辑器视口截图
func capture_editor_viewport() -> Image:
	var viewport = Engine.get_main_loop().root
	
	# 获取视口纹理
	var texture = viewport.get_texture()
	if not texture:
		push_error("无法获取视口纹理")
		return null
	
	var image = texture.get_image()
	if not image:
		push_error("无法获取截图")
		return null
	
	_screenshot_cache = image
	screenshot_captured.emit(image)
	
	return image

# 捕获指定区域
func capture_region(rect: Rect2) -> Image:
	var full = capture_editor_viewport()
	if not full:
		return null
	
	# 裁剪指定区域
	var region = Image.create(int(rect.size.x), int(rect.size.y), false, Image.FORMAT_RGBA8)
	region.blit_rect(full, rect, Vector2i.ZERO)
	
	return region

# 获取截图数据（用于发送给AI）
func get_screenshot_data() -> Dictionary:
	var image = _screenshot_cache
	if not image:
		image = capture_editor_viewport()
	
	if not image:
		return {}
	
	# 压缩为PNG获取base64
	var png_data = image.save_png_to_buffer()
	var base64_data = Marshalls.raw_to_base64(png_data)
	
	return {
		"base64": base64_data,
		"width": image.get_width(),
		"height": image.get_height(),
		"format": "png"
	}

# 保存截图到文件
func save_screenshot(path: String) -> bool:
	var image = _screenshot_cache
	if not image:
		image = capture_editor_viewport()
	
	if not image:
		return false
	
	var result = image.save_png(path)
	return result == OK

# 获取缩略图（用于预览）
func get_thumbnail(max_size: int = 256) -> Image:
	var image = _screenshot_cache
	if not image:
		return null
	
	# 计算缩放比例
	var scale = float(max_size) / max(image.get_width(), image.get_height())
	if scale >= 1.0:
		return image
	
	# 创建缩略图
	var thumb = image.duplicate()
	thumb.resize(int(image.get_width() * scale), int(image.get_height() * scale))
	return thumb

# 生成场景描述（简化版本）
func generate_scene_description() -> String:
	var image = _screenshot_cache
	if not image:
		return "无法获取场景截图"
	
	var desc = "编辑器截图 "
	desc += "尺寸: %dx%d" % [image.get_width(), image.get_height()]
	
	return desc
