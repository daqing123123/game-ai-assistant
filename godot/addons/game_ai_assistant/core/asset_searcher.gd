extends Node

# 绱犳潗鎼滅储鍣?# 鎼滅储鍏嶈垂鍙晢鐢ㄧ殑娓告垙绱犳潗

signal search_started(query: String)
signal search_progress(current: int, total: int)
signal search_completed(results: Array)
signal error_occurred(error: String)

# 绱犳潗婧愰厤缃?const ASSET_SOURCES = {
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

# 鎼滅储缂撳瓨
var search_cache: Dictionary = {}
var http_request: HTTPRequest

func _init():
	http_request = HTTPRequest.new()
	add_child(http_request)

# 鎼滅储绱犳潗
func search(query: String, asset_type: String = "") -> void:
	search_started.emit(query)
	
	# 妫€鏌ョ紦瀛?	var cache_key = query + "_" + asset_type
	if search_cache.has(cache_key):
		search_completed.emit(search_cache[cache_key])
		return
	
	# 鎵ц鎼滅储
	var results = await _perform_search(query, asset_type)
	
	# 缂撳瓨缁撴灉
	search_cache[cache_key] = results
	
	search_completed.emit(results)

func _perform_search(query: String, asset_type: String) -> Array:
	var results: Array = []
	var lower_query = query.to_lower()
	
	# 鏍规嵁鏌ヨ璇嶅垎绫?	var category = _categorize_query(lower_query)
	
	# 鎼滅储鍚勪釜绱犳潗婧?	var tasks = []
	
	match category:
		"audio", "sound", "sfx", "闊虫晥", "澹伴煶":
			tasks = _search_audio_sources(query)
		"sprite", "image", "鍥剧墖", "绮剧伒", "鍍忕礌":
			tasks = _search_sprite_sources(query)
		"model", "3d", "妯″瀷", "瑙掕壊":
			tasks = _search_model_sources(query)
		"animation", "anim", "鍔ㄧ敾":
			tasks = _search_animation_sources(query)
		"icon", "鍥炬爣":
			tasks = _search_icon_sources(query)
		_:
			# 鍏ㄧ被鍒悳绱?			tasks = _get_all_sources(query)
	
	# 妯℃嫙鎼滅储缁撴灉锛堝疄闄呭簲璇ヨ皟鐢ˋPI锛?	results = _generate_mock_results(query, category)
	
	return results

func _categorize_query(query: String) -> String:
	var categories = {
		"audio": ["闊虫晥", "澹伴煶", "鐖嗙偢", "灏勫嚮", "璺宠穬", "鑳屾櫙闊充箰", "闊充箰", "sfx", "sound", "audio", "effect"],
		"sprite": ["绮剧伒", "鍍忕礌", "鍥剧墖", "鍥惧儚", "sprite", "image", "pixel"],
		"model": ["妯″瀷", "3d", "瑙掕壊", "閬撳叿", "鍦烘櫙", "model", "character", "obj"],
		"animation": ["鍔ㄧ敾", "anim", "animation", "mixamo"],
		"icon": ["鍥炬爣", "icon", "ui"]
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
	
	# Kenney 绱犳潗
	var kenney_result = {
		"source": "Kenney.nl",
		"source_id": "kenney",
		"title": _get_kenney_asset_title(query, category),
		"description": "楂樿川閲忓厤璐规父鎴忕礌鏉愶紝CC0鍗忚鍙晢鐢?,
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
			"description": "鍏ㄧ悆鏈€澶у厤璐归煶鏁堝簱锛孋reative Commons璁稿彲",
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
			"title": "Mixamo 瑙掕壊鍔ㄧ敾搴?,
			"description": "鍏嶈垂瑙掕壊鍜屽姩鐢伙紝鑷姩缁戝畾楠ㄩ",
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
			"title": "Game Icons 3000+ 鍥炬爣",
			"description": "瓒呰繃3000涓厤璐规父鎴忓浘鏍囷紝SVG/PNG鏍煎紡",
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
			"title": "Poly Haven 3D妯″瀷搴?,
			"description": "鍏嶈垂楂樿川閲?D妯″瀷鍜岀汗鐞嗭紝CC0鍗忚",
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
		"title": "Itch.io 鍏嶈垂绱犳潗",
		"description": "鐙珛娓告垙绀惧尯鐨勫厤璐圭礌鏉愬寘",
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
		"audio": "Kenney 闊虫晥绱犳潗鍖?,
		"sprite": "Kenney 2D 绮剧伒鍥?,
		"model": "Kenney 3D 妯″瀷鍖?,
		"animation": "Kenney 瑙掕壊绱犳潗",
		"icon": "Kenney UI 濂椾欢"
	}
	return titles.get(category, "Kenney 娓告垙绱犳潗鍖?)

func _get_freesound_asset_title(query: String) -> String:
	return "Freesound 闊虫晥: " + query

func _get_asset_types(category: String) -> Array:
	var types = {
		"audio": ["audio", "sfx"],
		"sprite": ["sprites", "tileset"],
		"model": ["3d", "model"],
		"animation": ["animation"],
		"icon": ["icons"]
	}
	return types.get(category, ["general"])

# 鑾峰彇鎺ㄨ崘绱犳潗
func get_recommended_assets(category: String = "") -> Array:
	var recommended: Array = []
	
	# Kenney 蹇呮帹
	recommended.append({
		"source": "Kenney.nl",
		"title": "Kenney 1-bit Pack",
		"description": "绮剧編鍍忕礌椋庢牸绱犳潗锛岀粡鍏?D娓告垙椋庢牸",
		"url": "https://kenney.nl/assets/bitmaps",
		"types": ["sprites"],
		"rating": 5
	})
	
	# Freesound 闊虫晥
	if category.is_empty() or category == "audio":
		recommended.append({
			"source": "Freesound",
			"title": "Game Sounds Pack",
			"description": "甯哥敤娓告垙闊虫晥闆嗗悎",
			"url": "https://freesound.org/search/?q=game+sounds",
			"types": ["audio"],
			"rating": 5
		})
	
	# Mixamo 鍔ㄧ敾
	if category.is_empty() or category == "animation":
		recommended.append({
			"source": "Mixamo",
			"title": "Mixamo 鍔ㄧ敾搴?,
			"description": "鍏嶈垂瑙掕壊鍔ㄧ敾锛岃嚜鍔╮ig",
			"url": "https://www.mixamo.com",
			"types": ["animation", "characters"],
			"rating": 5
		})
	
	# Game Icons
	if category.is_empty() or category == "icon":
		recommended.append({
			"source": "Game Icons",
			"title": "Game Icons 3000+",
			"description": "娴烽噺娓告垙鍥炬爣",
			"url": "https://game-icons.net",
			"types": ["icons"],
			"rating": 5
		})
	
	return recommended

# 鑾峰彇鎵€鏈夌礌鏉愭簮
func get_all_sources() -> Dictionary:
	return ASSET_SOURCES

# 鎵撳紑绱犳潗缃戠珯
func open_source(source_id: String) -> void:
	if ASSET_SOURCES.has(source_id):
		OS.shell_open(ASSET_SOURCES[source_id].url)

# 娓呴櫎缂撳瓨
func clear_cache() -> void:
	search_cache.clear()

