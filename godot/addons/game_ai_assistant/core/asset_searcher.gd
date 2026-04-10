extends Node

# 素材搜索器
# 搜索免费可商用的游戏素材

signal search_started(query: String)
signal search_progress(current: int, total: int)
signal search_completed(results: Array)
signal error_occurred(error: String)

# 素材源配置
const ASSET_SOURCES = {
	"kenney": {
		"name": "Kenney.nl",
		"url": "https://kenney.nl/assets",
		"types": ["sprites", "audio", "3d", "tools"],
		"license": "CC0 1.0",
		"free": true
	},
	"freesound": {
		"name": "Freesound",
		"url": "https://freesound.org",
		"types": ["audio", "sfx", "music"],
		"license": "Creative Commons",
		"free": true
	},
	"opengameart": {
		"name": "OpenGameArt",
		"url": "https://opengameart.org",
		"types": ["sprites", "audio", "3d", "fonts"],
		"license": "Various",
		"free": true
	},
	"mixamo": {
		"name": "Mixamo",
		"url": "https://www.mixamo.com",
		"types": ["animations", "characters"],
		"license": "Free with account",
		"free": true
	},
	"gameicons": {
		"name": "Game Icons",
		"url": "https://game-icons.net",
		"types": ["icons", "sprites"],
		"license": "CC BY 3.0",
		"free": true
	},
	"polyhaven": {
		"name": "Poly Haven",
		"url": "https://polyhaven.com",
		"types": ["3d", "textures", "hdri"],
		"license": "CC0 1.0",
		"free": true
	},
	"itchio": {
		"name": "Itch.io",
		"url": "https://itch.io/game-assets/free",
		"types": ["sprites", "audio", "3d", "tools"],
		"license": "Various",
		"free": true
	},
	"craftpix": {
		"name": "Craftpix",
		"url": "https://craftpix.net/freebies/",
		"types": ["sprites", "gui"],
		"license": "Free with attribution",
		"free": true
	}
}

# 搜索缓存
var search_cache: Dictionary = {}
var http_request: HTTPRequest

func _init():
	http_request = HTTPRequest.new()
	add_child(http_request)

# 搜索素材
func search(query: String, asset_type: String = "") -> void:
	search_started.emit(query)
	
	# 检查缓存
	var cache_key = query + "_" + asset_type
	if search_cache.has(cache_key):
		search_completed.emit(search_cache[cache_key])
		return
	
	# 执行搜索
	var results = await _perform_search(query, asset_type)
	
	# 缓存结果
	search_cache[cache_key] = results
	
	search_completed.emit(results)

func _perform_search(query: String, asset_type: String) -> Array:
	var results: Array = []
	var lower_query = query.to_lower()
	
	# 根据查询词分类
	var category = _categorize_query(lower_query)
	
	# 搜索各个素材源
	var tasks = []
	
	match category:
		"audio", "sound", "sfx", "音效", "声音":
			tasks = _search_audio_sources(query)
		"sprite", "image", "图片", "精灵", "像素":
			tasks = _search_sprite_sources(query)
		"model", "3d", "模型", "角色":
			tasks = _search_model_sources(query)
		"animation", "anim", "动画":
			tasks = _search_animation_sources(query)
		"icon", "图标":
			tasks = _search_icon_sources(query)
		_:
			# 全类别搜索
			tasks = _get_all_sources(query)
	
	# 模拟搜索结果（实际应该调用API）
	results = _generate_mock_results(query, category)
	
	return results

func _categorize_query(query: String) -> String:
	var categories = {
		"audio": ["音效", "声音", "爆炸", "射击", "跳跃", "背景音乐", "音乐", "sfx", "sound", "audio", "effect"],
		"sprite": ["精灵", "像素", "图片", "图像", "sprite", "image", "pixel"],
		"model": ["模型", "3d", "角色", "道具", "场景", "model", "character", "obj"],
		"animation": ["动画", "anim", "animation", "mixamo"],
		"icon": ["图标", "icon", "ui"]
	}
	
	for cat in categories:
		for keyword in categories[cat]:
			if query.contains(keyword):
				return cat
	
	return "general"

func _search_audio_sources(query: String) -> Array:
	return ["freesound", "kenney", "opengameart"]

func _search_sprite_sources(query: String) -> Array:
	return ["kenney", "craftpix", "opengameart", "itchio"]

func _search_model_sources(query: String) -> Array:
	return ["kenney", "polyhaven", "opengameart", "mixamo"]

func _search_animation_sources(query: String) -> Array:
	return ["mixamo", "kenney", "opengameart"]

func _search_icon_sources(query: String) -> Array:
	return ["gameicons", "kenney"]

func _get_all_sources(query: String) -> Array:
	return ASSET_SOURCES.keys()

func _generate_mock_results(query: String, category: String) -> Array:
	var results: Array = []
	
	# Kenney 素材
	var kenney_result = {
		"source": "Kenney.nl",
		"source_id": "kenney",
		"title": _get_kenney_asset_title(query, category),
		"description": "高质量免费游戏素材，CC0协议可商用",
		"url": "https://kenney.nl/assets",
		"license": "CC0 1.0",
		"free": true,
		"types": _get_asset_types(category),
		"preview": ""
	}
	results.append(kenney_result)
	
	# Freesound
	if category in ["audio", "sound", "sfx"]:
		var freesound_result = {
			"source": "Freesound",
			"source_id": "freesound",
			"title": _get_freesound_asset_title(query),
			"description": "全球最大免费音效库，Creative Commons许可",
			"url": "https://freesound.org/search/?q=" + query.uri_encode(),
			"license": "CC0 / CC-BY",
			"free": true,
			"types": ["audio"],
			"preview": ""
		}
		results.append(freesound_result)
	
	# Mixamo
	if category in ["model", "animation"]:
		var mixamo_result = {
			"source": "Mixamo",
			"source_id": "mixamo",
			"title": "Mixamo 角色动画库",
			"description": "免费角色和动画，自动绑定骨骼",
			"url": "https://www.mixamo.com",
			"license": "Free with account",
			"free": true,
			"types": ["animations", "characters"],
			"preview": ""
		}
		results.append(mixamo_result)
	
	# Game Icons
	if category == "icon":
		var gameicons_result = {
			"source": "Game Icons",
			"source_id": "gameicons",
			"title": "Game Icons 3000+ 图标",
			"description": "超过3000个免费游戏图标，SVG/PNG格式",
			"url": "https://game-icons.net",
			"license": "CC BY 3.0",
			"free": true,
			"types": ["icons"],
			"preview": ""
		}
		results.append(gameicons_result)
	
	# Poly Haven
	if category == "model":
		var polyhaven_result = {
			"source": "Poly Haven",
			"source_id": "polyhaven",
			"title": "Poly Haven 3D模型库",
			"description": "免费高质量3D模型和纹理，CC0协议",
			"url": "https://polyhaven.com/models",
			"license": "CC0 1.0",
			"free": true,
			"types": ["3d", "textures"],
			"preview": ""
		}
		results.append(polyhaven_result)
	
	# Itch.io
	var itchio_result = {
		"source": "Itch.io",
		"source_id": "itchio",
		"title": "Itch.io 免费素材",
		"description": "独立游戏社区的免费素材包",
		"url": "https://itch.io/game-assets/free",
		"license": "Various",
		"free": true,
		"types": ["sprites", "audio", "3d"],
		"preview": ""
	}
	results.append(itchio_result)
	
	return results

func _get_kenney_asset_title(query: String, category: String) -> String:
	var titles = {
		"audio": "Kenney 音效素材包",
		"sprite": "Kenney 2D 精灵图",
		"model": "Kenney 3D 模型包",
		"animation": "Kenney 角色素材",
		"icon": "Kenney UI 套件"
	}
	return titles.get(category, "Kenney 游戏素材包")

func _get_freesound_asset_title(query: String) -> String:
	return "Freesound 音效: " + query

func _get_asset_types(category: String) -> Array:
	var types = {
		"audio": ["audio", "sfx"],
		"sprite": ["sprites", "tileset"],
		"model": ["3d", "model"],
		"animation": ["animation"],
		"icon": ["icons"]
	}
	return types.get(category, ["general"])

# 获取推荐素材
func get_recommended_assets(category: String = "") -> Array:
	var recommended: Array = []
	
	# Kenney 必推
	recommended.append({
		"source": "Kenney.nl",
		"title": "Kenney 1-bit Pack",
		"description": "精美像素风格素材，经典2D游戏风格",
		"url": "https://kenney.nl/assets/bitmaps",
		"types": ["sprites"],
		"rating": 5
	})
	
	# Freesound 音效
	if category.is_empty() or category == "audio":
		recommended.append({
			"source": "Freesound",
			"title": "Game Sounds Pack",
			"description": "常用游戏音效集合",
			"url": "https://freesound.org/search/?q=game+sounds",
			"types": ["audio"],
			"rating": 5
		})
	
	# Mixamo 动画
	if category.is_empty() or category == "animation":
		recommended.append({
			"source": "Mixamo",
			"title": "Mixamo 动画库",
			"description": "免费角色动画，自动rig",
			"url": "https://www.mixamo.com",
			"types": ["animation", "characters"],
			"rating": 5
		})
	
	# Game Icons
	if category.is_empty() or category == "icon":
		recommended.append({
			"source": "Game Icons",
			"title": "Game Icons 3000+",
			"description": "海量游戏图标",
			"url": "https://game-icons.net",
			"types": ["icons"],
			"rating": 5
		})
	
	return recommended

# 获取所有素材源
func get_all_sources() -> Dictionary:
	return ASSET_SOURCES

# 打开素材网站
func open_source(source_id: String) -> void:
	if ASSET_SOURCES.has(source_id):
		OS.shell_open(ASSET_SOURCES[source_id].url)

# 清除缓存
func clear_cache() -> void:
	search_cache.clear()
