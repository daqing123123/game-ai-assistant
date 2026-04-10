extends Node

# AI澶勭悊鍣?- 鏍稿績AI閫昏緫
# 澶勭悊鐢ㄦ埛杈撳叆锛岃皟鐢ˋI锛岃繑鍥炵粨鏋?
signal thinking_started()
signal thinking_finished(response: String)
signal errorOccurred(error: String)
signal debug_analysis_ready(analysis: Dictionary)
signal code_search_ready(results: Array)
signal code_analysis_finished(response: String, analysis_type: String)

var config: Dictionary = {}
var http_request: HTTPRequest
var is_processing: bool = false
var conversation_history: Array = []

# 璋冭瘯鍔╂墜鐩稿叧
var last_error_context: Dictionary = {}
var debug_suggestions: Array = []

# 浠ｇ爜鎼滅储鐩稿叧
var last_search_results: Array = []
var last_search_query: String = ""
var _analysis_mode: String = ""  # "explain" | "optimize" | ""
var _pending_user_message: String = ""

# 绯荤粺鎻愮ず璇嶏紙鍙岃锛?const SYSTEM_PROMPT_ZH = """浣犳槸涓€涓笓涓氱殑娓告垙寮€鍙慉I鍔╂墜锛屽悕瀛楀彨鍏埅楸笺€?
## 浣犵殑鑳藉姏
1. 鐢熸垚Unity(C#)鍜孏odot(GDScript)浠ｇ爜
2. 淇敼鐜版湁浠ｇ爜
3. 鎼滅储鍏嶈垂鍙晢鐢ㄧ殑娓告垙绱犳潗
4. 瑙ｉ噴娓告垙寮€鍙戞蹇?5. 璇婃柇鍜屼慨澶岯ug
6. 鎻愪緵娓告垙寮€鍙戝缓璁?
## 浠ｇ爜鏍煎紡瑕佹眰
- GDScript浣跨敤extends Node
- C#浣跨敤UnityEngine鍛藉悕绌洪棿
- 浠ｇ爜瑕佹湁娉ㄩ噴
- 閲嶈浠ｇ爜鐢ㄤ腑鏂囨敞閲?
## 绱犳潗鎼滅储
濡傛灉鐢ㄦ埛瑕佹壘绱犳潗锛岃繑鍥濲SON鏍煎紡锛?{"action": "search_assets", "query": "鎼滅储鍏抽敭璇?, "type": "sound|model|texture|sprite"}

## 浠ｇ爜瑙ｉ噴
濡傛灉鐢ㄦ埛璇锋眰瑙ｉ噴浠ｇ爜锛?瑙ｉ噴浠ｇ爜"銆?瑙ｉ噴杩欐浠ｇ爜"銆?鍒嗘瀽浠ｇ爜"銆?杩欐浠ｇ爜鍋氫簡浠€涔?绛夛級锛岃繑鍥濲SON鏍煎紡锛?{"action": "explain_code", "code": "鐢ㄦ埛閫変腑鐨勪唬鐮?}

## 浠ｇ爜浼樺寲
濡傛灉鐢ㄦ埛璇锋眰浼樺寲浠ｇ爜锛?浼樺寲浠ｇ爜"銆?浼樺寲杩欐浠ｇ爜"銆?浠ｇ爜浼樺寲"銆?濡備綍鏀硅繘"绛夛級锛岃繑鍥濲SON鏍煎紡锛?{"action": "optimize_code", "code": "鐢ㄦ埛閫変腑鐨勪唬鐮?}

## 妯℃澘璇锋眰
濡傛灉鐢ㄦ埛瑕佷唬鐮佹ā鏉匡紝杩斿洖JSON鏍煎紡锛?{"action": "generate_template", "template": "妯℃澘鍚嶇О"}

## 椤圭洰淇℃伅
- 寮曟搸: Godot 4.2
- 椤圭洰璺緞: {project_path}

鍥炵瓟瑕佺畝娲佸疄鐢紝鍍忓拰鏈嬪弸鑱婂ぉ涓€鏍疯嚜鐒躲€?""

const SYSTEM_PROMPT_EN = """You are a professional game development AI assistant named Octopus.

## Your Capabilities
1. Generate Unity(C#) and Godot(GDScript) code
2. Modify existing code
3. Search for free commercially-usable game assets
4. Explain game development concepts
5. Diagnose and fix bugs
6. Provide game development advice

## Code Format Requirements
- GDScript uses extends Node
- C# uses UnityEngine namespace
- Code should have comments
- Use English comments

## Asset Search
If user wants to find assets, return JSON format:
{"action": "search_assets", "query": "search keywords", "type": "sound|model|texture|sprite"}

## Code Explanation
If user requests code explanation ("explain code", "what does this code do", "analyze code", etc.), return JSON:
{"action": "explain_code", "code": "user selected code"}

## Code Optimization
If user requests code optimization ("optimize code", "improve this code", "how to improve", etc.), return JSON:
{"action": "optimize_code", "code": "user selected code"}

## Template Request
If user wants code template, return JSON:
{"action": "generate_template", "template": "template name"}

## Project Info
- Engine: Godot 4.2
- Project Path: {project_path}

Be concise and practical, like chatting with a friend."""

# 鑾峰彇绯荤粺鎻愮ず璇嶏紙鏍规嵁璇█璁剧疆锛?func get_system_prompt() -> String:
	var lang = config.get("language", "auto")
	if lang == "auto":
		lang = "zh" if OS.get_locale_language() == "zh" else "en"
	return SYSTEM_PROMPT_ZH if lang == "zh" else SYSTEM_PROMPT_EN

func _init():
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

func configure(cfg: Dictionary):
	config = cfg

# 澶勭悊鐢ㄦ埛杈撳叆
func process_message(user_input: String) -> void:
	if is_processing:
		errorOccurred.emit("姝ｅ湪澶勭悊涓婁竴涓姹傦紝璇风◢鍊?..")
		return
	
	is_processing = true
	thinking_started.emit()
	
	# 瑙ｆ瀽鐗规畩鍛戒护
	var special_result = parse_special_command(user_input)
	if special_result:
		await get_tree().create_timer(0.5).timeout
		is_processing = false
		thinking_finished.emit(special_result)
		return
	
	# 璋冪敤AI
	await call_ai(user_input)
	is_processing = false

# ==================== 椤圭洰妯℃澘鍔熻兘 ====================

func get_project_templates() -> Array:
	return [
		{
			"id": "2d_platformer",
			"name": "2D 骞冲彴璺宠穬",
			"description": "缁忓吀鐨勬í鐗堝钩鍙拌烦璺冩父鎴忔ā鏉?,
			"features": ["鐜╁瑙掕壊", "骞冲彴", "閲戝竵鏀堕泦", "鏁屼汉", "鍏冲崱鍒囨崲"]
		},
		{
			"id": "3d_fps",
			"name": "3D 绗竴浜虹О灏勫嚮",
			"description": "绗竴浜虹О灏勫嚮娓告垙妯℃澘",
			"features": ["FPS鎺у埗鍣?, "姝﹀櫒绯荤粺", "鏁屼汉AI", "寮硅嵂绠＄悊", "鍒嗘暟绯荤粺"]
		},
		{
			"id": "2d_topdown_shooter",
			"name": "2D 淇瑙掑皠鍑?,
			"description": "淇瑙掑皠鍑绘父鎴忔ā鏉?,
			"features": ["鐜╁鎺у埗鍣?, "寮瑰箷绯荤粺", "閬撳叿鎺夎惤", "娉㈡绯荤粺", "鍟嗗簵"]
		},
		{
			"id": "3d_third_person",
			"name": "3D 绗笁浜虹О鍔ㄤ綔",
			"description": "绗笁浜虹О鍔ㄤ綔鍐掗櫓娓告垙妯℃澘",
			"features": ["瑙掕壊鎺у埗鍣?, "鐩告満璺熼殢", "鏀诲嚮绯荤粺", "鏁屼汉AI", "鐢熷懡鍊?]
		},
		{
			"id": "casual_puzzle",
			"name": "浼戦棽鐩婃櫤娓告垙",
			"description": "杞绘澗浼戦棽鐨勭泭鏅烘父鎴忔ā鏉?,
			"features": ["鍏冲崱绯荤粺", "璁℃椂鍣?, "鍒嗘暟绯荤粺", "閬撳叿浣跨敤", "閫氬叧鍒ゅ畾"]
		},
		{
			"id": "rpg",
			"name": "RPG 瑙掕壊鎵紨",
			"description": "缁忓吀RPG瑙掕壊鎵紨娓告垙妯℃澘",
			"features": ["瑙掕壊灞炴€?, "瑁呭绯荤粺", "鎶€鑳芥爲", "浠诲姟绯荤粺", "鍟嗗簵浜ゆ槗"]
		}
	]

func create_project_template(template_id: String) -> Dictionary:
	var templates = get_project_templates()
	var selected_template = null
	
	for t in templates:
		if t["id"] == template_id:
			selected_template = t
			break
	
	if not selected_template:
		return {"success": false, "message": "鏈壘鍒版寚瀹氱殑妯℃澘"}
	
	# 鑾峰彇浠ｇ爜鐢熸垚鍣?	var code_gen = get_node_or_null("/root/CodeGenerator")
	if not code_gen:
		return {"success": false, "message": "浠ｇ爜鐢熸垚鍣ㄦ湭鍔犺浇"}
	
	# 鐢熸垚椤圭洰缁撴瀯
	var result = code_gen.generate_project_template(template_id, selected_template)
	
	return result

func show_project_template_list() -> String:
	var templates = get_project_templates()
	var msg = """
馃彈锔?**椤圭洰妯℃澘**

璇烽€夋嫨瑕佸垱寤虹殑椤圭洰绫诲瀷锛?
**甯哥敤妯℃澘**
1锔忊儯 [2D 骞冲彴璺宠穬] - 缁忓吀妯増璺宠穬娓告垙
2锔忊儯 [2D 淇瑙掑皠鍑籡 - 淇瑙掑皠鍑绘父鎴?3锔忊儯 [3D 绗笁浜虹О鍔ㄤ綔] - 鍔ㄤ綔鍐掗櫓娓告垙

**杩涢樁妯℃澘**
4锔忊儯 [3D 绗竴浜虹О灏勫嚮] - FPS灏勫嚮娓告垙
5锔忊儯 [浼戦棽鐩婃櫤娓告垙] - 杞绘澗浼戦棽娓告垙
6锔忊儯 [RPG 瑙掕壊鎵紨] - 瑙掕壊鎵紨娓告垙

鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹?馃挕 杈撳叆銆屽垱寤?銆嶉€夋嫨绗?涓ā鏉?馃挕 杈撳叆銆屽垱寤?2D 骞冲彴銆嶅揩閫熼€夋嫨
"""
	return msg

# ==================== 鍦烘櫙鐢熸垚鍔熻兘 ====================

func generate_scene(scene_config: Dictionary) -> Dictionary:
	var code_gen = get_node_or_null("/root/CodeGenerator")
	if not code_gen:
		return {"success": false, "message": "浠ｇ爜鐢熸垚鍣ㄦ湭鍔犺浇"}
	
	var result = code_gen.generate_scene(scene_config)
	return result

func show_scene_generation_help() -> String:
	return """
馃幀 **鍦烘櫙鐢熸垚鍚戝**

鍛婅瘔鎴戜綘鎯宠浠€涔堝満鏅紝鎴戞潵甯綘鐢熸垚锛?
**鍦烘櫙鍏冪礌**
鈥?馃 鐜╁鍑虹敓鐐?- PlayerSpawn
鈥?馃懝 鏁屼汉 - Enemy
鈥?馃獧 閲戝竵/閬撳叿 - Collectible
鈥?馃П 闅滅鐗?- Obstacle
鈥?馃弫 缁堢偣 - Goal

**绀轰緥鎻忚堪**
銆屽垱寤轰竴涓钩鍙拌烦璺冨叧鍗★紝鏈夌帺瀹跺嚭鐢熺偣銆?涓噾甯併€?涓晫浜哄拰缁堢偣銆?
**蹇嵎鍛戒护**
鈥?銆岀敓鎴愮畝鍗曞叧鍗°€? 鍒涘缓鍩虹骞冲彴鍏冲崱
鈥?銆岀敓鎴愭垬鏂楀満鏅€? 鍒涘缓鍖呭惈鏁屼汉鐨勬垬鏂楀満鏅?鈥?銆岀敓鎴怋oss鎴块棿銆? 鍒涘缓Boss鎴樺満鏅?"""

func get_scene_element_types() -> Array:
	return [
		{"id": "player_spawn", "name": "鐜╁鍑虹敓鐐?, "icon": "馃"},
		{"id": "enemy", "name": "鏁屼汉", "icon": "馃懝"},
		{"id": "collectible", "name": "鍙敹闆嗙墿", "icon": "馃獧"},
		{"id": "obstacle", "name": "闅滅鐗?, "icon": "馃П"},
		{"id": "platform", "name": "骞冲彴", "icon": "猬?},
		{"id": "goal", "name": "缁堢偣/闂?, "icon": "馃弫"},
		{"id": "spawner", "name": "鏁屼汉鍑虹敓鐐?, "icon": "馃拃"},
		{"id": "trap", "name": "闄烽槺", "icon": "鈿狅笍"}
	]

# 瑙ｆ瀽鐗规畩鍛戒护
func parse_special_command(input: String) -> String:
	var lower_input = input.to_lower()
	
	# 甯姪鍛戒护
	if lower_input.begins_with("甯姪") or lower_input.begins_with("help"):
		return get_help_text()
	
	# 妯℃澘鍛戒护
	if lower_input.begins_with("妯℃澘") or lower_input.begins_with("template"):
		return get_template_list()
	
	# 椤圭洰妯℃澘鍛戒护
	if lower_input.begins_with("鍒涘缓椤圭洰") or lower_input.begins_with("鏂板缓椤圭洰") or lower_input.begins_with("椤圭洰妯℃澘"):
		return show_project_template_list()
	
	# 鍒涘缓鎸囧畾妯℃澘
	if lower_input.begins_with("鍒涘缓"):
		return parse_create_template_command(input)
	
	# 鍦烘櫙鐢熸垚鍛戒护
	if lower_input.begins_with("鐢熸垚鍦烘櫙") or lower_input.begins_with("鍒涘缓鍦烘櫙") or lower_input.begins_with("鍦烘櫙鍚戝"):
		return show_scene_generation_help()
	
	# 鍦烘櫙鐢熸垚蹇嵎鍛戒护
	if lower_input.begins_with("鐢熸垚"):
		return parse_scene_generation_command(input)
	
	# 璁剧疆鍛戒护
	if lower_input.begins_with("璁剧疆") or lower_input.begins_with("config"):
		return "璇锋墦寮€渚ц竟鏍忕殑銆岃缃€嶉潰鏉块厤缃瓵I妯″瀷銆?
	
	# 娓呯悊鍘嗗彶
	if lower_input.begins_with("娓呴櫎") or lower_input.begins_with("clear"):
		conversation_history.clear()
		return "宸叉竻闄ゅ璇濆巻鍙诧紒"
	
	# 鎼滅储绱犳潗
	if lower_input.begins_with("鎵?) or lower_input.begins_with("鎼滅储") or lower_input.begins_with("search"):
		var query = input.substr(1).strip_edges()
		if query.is_empty():
			return "璇峰憡璇夋垜浣犳兂鎵句粈涔堢礌鏉愶紵\n姣斿锛氥€屾壘鐖嗙偢闊虫晥銆嶆垨銆屾悳绱㈢骞昏鑹叉ā鍨嬨€?
		return generate_search_prompt(query)
	
	# 璋冭瘯鍔╂墜鍛戒护
	if lower_input.begins_with("璋冭瘯") or lower_input.begins_with("鎵綽ug") or lower_input.begins_with("甯垜鎵綽ug") or lower_input.contains("鎶ラ敊浜?) or lower_input.contains("鍑洪敊浜?):
		return _handle_debug_command(input)
	
	# 浠ｇ爜鎼滅储鍛戒护
	if lower_input.begins_with("鎼滅储浠ｇ爜") or lower_input.begins_with("鎵句唬鐮?) or lower_input.begins_with("鏌ユ壘浠ｇ爜") or lower_input.begins_with("鎵炬壘"):
		return _handle_search_code_command(input)
	
	return ""

# 瑙ｆ瀽鍒涘缓妯℃澘鍛戒护
func parse_create_template_command(input: String) -> String:
	var lower = input.to_lower()
	var templates = get_project_templates()
	
	# 鏁板瓧绱㈠紩
	if input.begins_with("鍒涘缓"):
		var num_str = input.substr(2).strip_edges()
		if num_str.is_valid_int():
			var idx = num_str.to_int() - 1
			if idx >= 0 and idx < templates.size():
				return "鈴?姝ｅ湪鍒涘缓銆? + templates[idx]["name"] + "銆戞ā鏉?.."
	
	# 鍏抽敭瀛楀尮閰?	for i in range(templates.size()):
		var t = templates[i]
		var keywords = {
			"2d_platformer": ["2d骞冲彴", "骞冲彴璺宠穬", "骞冲彴"],
			"3d_fps": ["fps", "绗竴浜虹О", "灏勫嚮"],
			"2d_topdown_shooter": ["淇瑙?, "淇灏勫嚮", "topdown"],
			"3d_third_person": ["绗笁浜虹О", "鍔ㄤ綔", "3d鍔ㄤ綔"],
			"casual_puzzle": ["浼戦棽", "鐩婃櫤", "puzzle"],
			"rpg": ["rpg", "瑙掕壊鎵紨", "瑙掕壊"]
		}
		var kw_list = keywords.get(t["id"], [])
		for kw in kw_list:
			if lower.contains(kw):
				return "鈴?姝ｅ湪鍒涘缓銆? + t["name"] + "銆戞ā鏉?.."
	
	# 閫氱敤鍒涘缓鍛戒护
	if lower.contains("鍒涘缓"):
		return show_project_template_list()
	
	return ""

# 瑙ｆ瀽鍦烘櫙鐢熸垚鍛戒护
func parse_scene_generation_command(input: String) -> String:
	var lower = input.to_lower()
	
	# 绠€鍗曞叧鍗?	if lower.contains("绠€鍗曞叧鍗?) or lower.contains("鍩虹鍏冲崱"):
		var config = {
			"type": "platformer_level",
			"elements": [
				{"type": "player_spawn", "pos": Vector2(100, 400), "name": "PlayerSpawn"},
				{"type": "platform", "pos": Vector2(400, 500), "size": Vector2(600, 50)},
				{"type": "collectible", "pos": Vector2(300, 400), "name": "Coin1"},
				{"type": "collectible", "pos": Vector2(500, 400), "name": "Coin2"},
				{"type": "goal", "pos": Vector2(700, 450), "name": "Goal"}
			]
		}
		return "鈴?姝ｅ湪鐢熸垚绠€鍗曞叧鍗?.."
	
	# 鎴樻枟鍦烘櫙
	if lower.contains("鎴樻枟") or lower.contains("enemy") or lower.contains("鏁屼汉"):
		return "鈴?姝ｅ湪鐢熸垚鎴樻枟鍦烘櫙..."
	
	# Boss鎴块棿
	if lower.contains("boss"):
		return "鈴?姝ｅ湪鐢熸垚Boss鎴块棿..."
	
	return ""

func generate_search_prompt(query: String) -> String:
	return """鎴戝府浣犳悳绱€?s銆嶇浉鍏崇殑绱犳潗锛?
馃帹 **鍏嶈垂鍙晢鐢ㄧ礌鏉愭簮**锛?
**闊虫晥绫?*
鈥?freesound.org - 鍏ㄧ悆鏈€澶у厤璐归煶鏁堝簱
鈥?kenney.nl - CC0鍗忚锛岄珮璐ㄩ噺

**妯″瀷绫?*
鈥?kenney.nl - 3D妯″瀷銆佽鑹?鈥?opengameart.org - 绀惧尯绱犳潗

**绮剧伒鍥剧被**
鈥?kenney.nl - 2D娓告垙绱犳潗
鈥?game-icons.net - 鍥炬爣绱犳潗

闇€瑕佹垜甯綘鎼滅储鍚楋紵杈撳叆銆屽紑濮嬫悳绱€嶇户缁€?"" % query

# ==================== 璋冭瘯鍔╂墜鍔熻兘 ====================

func _handle_debug_command(input: String) -> String:
	"""澶勭悊璋冭瘯鍛戒护"""
	var lower = input.to_lower()
	
	# 妫€鏌ユ槸鍚︽槸鐩存帴绮樿创閿欒鏃ュ織
	if "error" in lower or "exception" in lower or "null" in lower or "nullreference" in lower:
		return _analyze_error_log(input)
	
	# 閫氱敤璋冭瘯妯″紡
	last_error_context = {
		"user_description": input,
		"timestamp": Time.get_datetime_string_from_system()
	}
	
	return """馃悰 **璋冭瘯鍔╂墜宸插惎鍔?*

璇峰憡璇夋垜锛?1. **閿欒淇℃伅** - 绮樿创瀹屾暣鐨勯敊璇棩蹇?2. **闂鎻忚堪** - 浠€涔堟儏鍐典笅鍑虹幇闂
3. **鏈熸湜琛屼负** - 浣犳兂瑕佷粈涔堟晥鏋?
**甯哥敤璋冭瘯鍛戒护**
鈥?銆岃皟璇曘€? 鍚姩璋冭瘯妯″紡
鈥?銆屽垎鏋愯繖娈典唬鐮併€? AI甯綘鍒嗘瀽浠ｇ爜闂
鈥?銆屾坊鍔犳棩蹇椼€? 鐢熸垚璋冭瘯鏃ュ織浠ｇ爜

馃挕 鐩存帴绮樿创閿欒淇℃伅锛孉I浼氳嚜鍔ㄥ垎鏋愬師鍥狅紒"""

func _analyze_error_log(error_log: String) -> String:
	"""鍒嗘瀽閿欒鏃ュ織骞舵彁渚涜В鍐虫柟妗?""
	debug_suggestions.clear()
	
	# 鎻愬彇鍏抽敭閿欒淇℃伅
	var error_type = _extract_error_type(error_log)
	var error_msg = _extract_error_message(error_log)
	var possible_causes = _analyze_error_type(error_type)
	
	# 淇濆瓨閿欒涓婁笅鏂?	last_error_context = {
		"error_type": error_type,
		"error_message": error_msg,
		"timestamp": Time.get_datetime_string_from_system()
	}
	
	var report = """
馃悰 **閿欒鍒嗘瀽鎶ュ憡**

**閿欒绫诲瀷:** %s
**閿欒淇℃伅:** %s

鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹?
**馃攳 鍙兘鍘熷洜:**

""" % [error_type, error_msg]
	
	for i in range(possible_causes.size()):
		report += "%d. %s\n" % [i + 1, possible_causes[i]]
	
	report += """
鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹?
**馃敡 瑙ｅ喅鏂规寤鸿:**

"""
	
	var solutions = _get_solution_suggestions(error_type)
	for i in range(solutions.size()):
		report += "**%d. %s**\n%s\n\n" % [i + 1, solutions[i].title, solutions[i].description]
	
	report += """
鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹?
**馃挕 璋冭瘯鎶€宸?*

鈥?浣跨敤 `print()` 杈撳嚭鍙橀噺鍊?鈥?浣跨敤 `push_error()` 杈撳嚭閿欒淇℃伅
鈥?浣跨敤鏂偣鏆傚仠绋嬪簭鏌ョ湅鐘舵€?鈥?妫€鏌ョ┖鍊煎紩鐢?`if node != null:`

**涓嬩竴姝ユ搷浣?*
鈥?杈撳叆銆屾坊鍔犳柇鐐广€? 鐢熸垚鏂偣寤鸿浠ｇ爜
鈥?杈撳叆銆岀敓鎴愭棩蹇椼€? 鐢熸垚璋冭瘯鏃ュ織浠ｇ爜
鈥?杈撳叆銆屾煡鐪嬬浉鍏充唬鐮併€? AI鎼滅储鐩稿叧浠ｇ爜鏂囦欢
"""
	
	return report

func _extract_error_type(log: String) -> String:
	"""鎻愬彇閿欒绫诲瀷"""
	var lower = log.to_lower()
	
	if "null" in lower and ("reference" in lower or "pointer" in lower):
		return "绌哄紩鐢ㄥ紓甯?(NullReferenceException)"
	if "index" in lower and "out of range" in lower:
		return "鏁扮粍瓒婄晫 (IndexOutOfRangeException)"
	if "invalid call" in lower or "call" in lower and "none" in lower:
		return "鏃犳晥鏂规硶璋冪敤"
	if "parsing" in lower or "syntax" in lower:
		return "璇硶閿欒 (Syntax Error)"
	if "type" in lower and "mismatch" in lower:
		return "绫诲瀷涓嶅尮閰?(Type Mismatch)"
	if "file" in lower and "not found" in lower:
		return "鏂囦欢鏈壘鍒?
	if "permission" in lower or "access" in lower:
		return "鏉冮檺璁块棶閿欒"
	
	return "鏈煡閿欒绫诲瀷"

func _extract_error_message(log: String) -> String:
	"""鎻愬彇閿欒娑堟伅"""
	var lines = log.split("\n")
	for line in lines:
		if "error" in line.to_lower() or "exception" in line.to_lower():
			return line.strip_edges()
	return "鏈壘鍒板叿浣撻敊璇俊鎭?

func _analyze_error_type(error_type: String) -> Array:
	"""鍒嗘瀽閿欒绫诲瀷鍙兘鐨勫師鍥?""
	var causes: Array = []
	
	match error_type:
		"绌哄紩鐢ㄥ紓甯?(NullReferenceException)":
			causes = [
				"鍙橀噺鏈垵濮嬪寲灏变娇鐢?,
				"鑺傜偣璺緞閿欒鎴栬妭鐐逛笉瀛樺湪",
				"寮傛鍔犺浇鐨勮妭鐐瑰皻鏈姞杞藉畬鎴?,
				"鏁扮粍/瀛楀吀璁块棶浜嗕笉瀛樺湪鐨勭储寮?
			]
		"鏁扮粍瓒婄晫 (IndexOutOfRangeException)":
			causes = [
				"寰幆绱㈠紩瓒呭嚭鏁扮粍闀垮害",
				"浣跨敤 -1 浣滀负绱㈠紩璁块棶",
				"鏁扮粍涓虹┖鏃惰闂涓€涓厓绱?
			]
		"鏃犳晥鏂规硶璋冪敤":
			causes = [
				"璋冪敤浜嗕笉瀛樺湪鐨勫嚱鏁?,
				"鍦ㄥ璞′负null鏃惰皟鐢ㄥ叾鏂规硶",
				"鍙傛暟鏁伴噺鎴栫被鍨嬩笉鍖归厤"
			]
		"璇硶閿欒 (Syntax Error)":
			causes = [
				"缂哄皯鍒嗗彿鎴栨嫭鍙?,
				"鍏抽敭瀛楁嫾鍐欓敊璇?,
				"瀛楃涓叉湭姝ｇ‘闂悎"
			]
		_:
			causes = [
				"鍙傛暟浼犻€掗敊璇?,
				"璧勬簮鍔犺浇澶辫触",
				"澶栭儴渚濊禆鏈纭厤缃?
			]
	
	return causes

func _get_solution_suggestions(error_type: String) -> Array:
	"""鑾峰彇閽堝鐗瑰畾閿欒鐨勮В鍐虫柟妗?""
	var solutions: Array = []
	
	match error_type:
		"绌哄紩鐢ㄥ紓甯?(NullReferenceException)":
			solutions = [
				{
					"title": "娣诲姞绌哄€兼鏌?,
					"description": "鍦ㄨ闂璞″墠妫€鏌ユ槸鍚︿负null\n```gdscript\nif node != null:\n    node.do_something()\n```"
				},
				{
					"title": "浣跨敤瀹夊叏瀵艰埅",
					"description": "浣跨敤 `?.` 杩愮畻绗﹀畨鍏ㄨ闂睘鎬n```gdscript\nvar value = node?.some_property\n```"
				},
				{
					"title": "纭繚鑺傜偣瀛樺湪",
					"description": "鍦?_ready() 涓幏鍙栬妭鐐瑰苟妫€鏌n```gdscript\nfunc _ready():\n    node = get_node_or_null(\"Path/To/Node\")\n    if node == null:\n        push_error(\"Node not found!\")\n```"
				}
			]
		"鏁扮粍瓒婄晫 (IndexOutOfRangeException)":
			solutions = [
				{
					"title": "妫€鏌ユ暟缁勯暱搴?,
					"description": "璁块棶鍓嶆鏌ョ储寮曟槸鍚︽湁鏁圽n```gdscript\nif index >= 0 and index < array.size():\n    var value = array[index]\n```"
				},
				{
					"title": "浣跨敤 clamp() 闄愬埗鑼冨洿",
					"description": "闄愬埗绱㈠紩鍦ㄦ湁鏁堣寖鍥村唴\n```gdscript\nvar safe_index = clamp(index, 0, array.size() - 1)\n```"
				}
			]
		_:
			solutions = [
				{
					"title": "娣诲姞鏃ュ織杈撳嚭",
					"description": "鍦ㄥ叧閿綅缃坊鍔?print() 甯姪瀹氫綅闂"
				},
				{
					"title": "浣跨敤鏂偣璋冭瘯",
					"description": "鍦ㄥ彲鐤戜唬鐮佸璁剧疆鏂偣锛岄€愭鎵ц鏌ョ湅鍙橀噺鍊?
				}
			]
	
	return solutions

# 璋冭瘯鍔╂墜 - 娣诲姞鏂偣寤鸿
func generate_breakpoint_suggestions(error_context: Dictionary = {}) -> String:
	"""鐢熸垚鏂偣璁剧疆寤鸿"""
	var context = error_context if not error_context.is_empty() else last_error_context
	
	return """
馃敶 **鏂偣璁剧疆寤鸿**

鏍规嵁閿欒淇℃伅锛屽缓璁湪浠ヤ笅浣嶇疆璁剧疆鏂偣锛?
**1. 鍙橀噺鍒濆鍖栧**
```gdscript
func _ready():\n    # 鍦ㄨ繖閲岃缃柇鐐癸紝妫€鏌ュ彉閲忔槸鍚︽纭垵濮嬪寲
    player = get_node_or_null("Player")
    print(\"Player node: \", player)  # 娣诲姞鏃ュ織
```

**2. 绌哄€间娇鐢ㄥ墠**
```gdscript
# 浣跨敤杩欎釜杈呭姪鍑芥暟妫€鏌?func safe_call(node: Node, method: String) -> void:\n    if node and node.has_method(method):\n        node.call(method)\n```

**3. 鏁扮粍璁块棶澶?*
```gdscript
func get_item(index: int) -> Variant:\n    if index < 0 or index >= items.size():\n        push_error(\"Invalid index: %d\" % index)\n        return null\n    return items[index]
```

馃挕 **璋冭瘯鎶€宸?*
鈥?F6 寮€濮嬭皟璇?鈥?F8 鍗曟鎵ц
鈥?F9 鍒囨崲鏂偣
"""

# 璋冭瘯鍔╂墜 - 鐢熸垚鏃ュ織寤鸿
func generate_debug_log_suggestions(error_context: Dictionary = {}) -> String:
	"""鐢熸垚璋冭瘯鏃ュ織浠ｇ爜寤鸿"""
	var context = error_context if not error_context.is_empty() else last_error_context
	var error_type = context.get("error_type", "鏈煡")
	
	var log_template = """
馃摑 **璋冭瘯鏃ュ織浠ｇ爜**

鍦ㄥ叧閿綅缃坊鍔犱互涓嬫棩蹇椾唬鐮侊細

**1. 鍑芥暟鍏ュ彛鏃ュ織**
```gdscript
func _process(delta: float) -> void:\n    print(\"[DEBUG] _process called, delta=\", delta)\n```

**2. 鍙橀噺鐘舵€佹棩蹇?*
```gdscript
func update() -> void:\n    print(\"[DEBUG] health=\", health, \" speed=\", speed)\n    if health <= 0:\n        push_error(\"[CRITICAL] Health reached zero!\")\n```

**3. 鏉′欢鍒嗘敮鏃ュ織**
```gdscript
if condition:\n    print(\"[DEBUG] Condition met\")\nelse:\n    print(\"[DEBUG] Condition not met, expected values:\", expected)\n```

**4. 寮傛鎿嶄綔鏃ュ織**
```gdscript
func load_resource(path: String) -> void:\n    print(\"[DEBUG] Loading: \", path)\n    var result = await ResourceLoader.load_threaded_request(path)\n    print(\"[DEBUG] Load complete: \", result)\n```

**5. 閿欒鏃ュ織锛堟帹鑽愶級**
```gdscript
push_error(\"[ERROR] Failed to initialize: \" + str(error_code))\npush_warning(\"[WARN] Null value detected in \", var_name)\n```
"""
	
	return log_template

# 浠ｇ爜鎼滅储鍔熻兘
func _handle_search_code_command(input: String) -> String:
	"""澶勭悊浠ｇ爜鎼滅储鍛戒护"""
	var lower = input.to_lower()
	var query = ""
	
	# 鎻愬彇鎼滅储鍏抽敭璇?	if lower.begins_with("鎼滅储浠ｇ爜") or lower.begins_with("鎵句唬鐮?) or lower.begins_with("鏌ユ壘浠ｇ爜"):
		query = input.substr(4 if lower.begins_with("鎼滅储") or lower.begins_with("鎵句唬鐮?) else 3).strip_edges()
	elif lower.begins_with("鎵炬壘"):
		query = input.substr(2).strip_edges()
	
	if query.is_empty():
		return """馃攳 **浠ｇ爜鎼滅储**

璇峰憡璇夋垜浣犳兂鎼滅储浠€涔堬紵

**绀轰緥**
鈥?銆屾悳绱唬鐮?绉诲姩銆? 鎼滅储绉诲姩鐩稿叧浠ｇ爜
鈥?銆屾壘鎵綪layer銆? 鎼滅储Player鐩稿叧浠ｇ爜
鈥?銆屾悳绱唬鐮?纰版挒妫€娴嬨€? 鎼滅储纰版挒妫€娴嬩唬鐮?
馃挕 鍙互鎼滅储鍑芥暟鍚嶃€佸彉閲忓悕銆佺被鍚嶆垨鍏抽敭璇?""

	# 璋冪敤椤圭洰璇诲彇鍣ㄨ繘琛屾悳绱?	var project_reader = get_node_or_null("/root/ProjectReader")
	if project_reader:
		last_search_query = query
		var report = project_reader.generate_search_report(query)
		last_search_results = project_reader.search_code(query)
		return report
	else:
		return "鈿狅笍 椤圭洰璇诲彇鍣ㄦ湭鍔犺浇锛屾棤娉曟悳绱唬鐮?

# ==================== 浠ｇ爜瑙ｉ噴鍜屼紭鍖?====================

func analyze_code(code: String, analysis_type: String) -> void:
	"""鍒嗘瀽浠ｇ爜锛堣В閲婃垨浼樺寲锛?""
	if is_processing:
		errorOccurred.emit("姝ｅ湪澶勭悊涓婁竴涓姹傦紝璇风◢鍊?..")
		return
	
	is_processing = true
	thinking_started.emit()
	
	var prompt = ""
	match analysis_type:
		"explain":
			prompt = build_explain_prompt(code)
		"optimize":
			prompt = build_optimize_prompt(code)
		_:
			is_processing = false
			thinking_finished.emit("鉂?鏈煡鐨勫垎鏋愮被鍨?)
			return
	
	await call_ai_for_analysis(prompt, analysis_type)
	is_processing = false

func build_explain_prompt(code: String) -> String:
	return """璇疯缁嗚В閲婁互涓嬩唬鐮佺殑鍔熻兘銆侀€昏緫鍜岀敤閫斻€?
## 浠ｇ爜
```
%s
```

## 瑙ｉ噴瑕佹眰
璇蜂粠浠ヤ笅鍑犱釜缁村害杩涜瑙ｉ噴锛?1. **鏁翠綋鍔熻兘** - 杩欐浠ｇ爜鍋氫粈涔?2. **閫愯/閫愭瑙ｆ瀽** - 鍏抽敭閮ㄥ垎鐨勯€昏緫
3. **鏍稿績鍙橀噺鍜屽嚱鏁?* - 閲嶈鍏冪礌鐨勪綔鐢?4. **浣跨敤鍦烘櫙** - 閫傚悎鍦ㄤ粈涔堟儏鍐典笅浣跨敤

璇风敤涓枃鍥炵瓟锛岃瑷€瑕佺畝娲佹槗鎳傘€傚鏋滀唬鐮佹槸GDScript璇风敤GDScript鏈锛屽鏋滄槸C#璇风敤C#鏈銆?"" % code

func build_optimize_prompt(code: String) -> String:
	return """璇峰垎鏋愪互涓嬩唬鐮侊紝骞舵彁渚涗紭鍖栧缓璁拰浼樺寲鍚庣殑浠ｇ爜銆?
## 浠ｇ爜
```
%s
```

## 浼樺寲瑕佹眰
璇蜂粠浠ヤ笅鍑犱釜缁村害杩涜鍒嗘瀽锛?1. **鎬ц兘** - 鏄惁鏈夋€ц兘闂锛屽浣曟敼杩?2. **鍙鎬?* - 浠ｇ爜鏄惁娓呮櫚鏄撹锛屽浣曚紭鍖?3. **瀹夊叏鎬?* - 鏄惁鏈夋綔鍦ㄧ殑瀹夊叏椋庨櫓
4. **鏈€浣冲疄璺?* - 鏄惁閬靛惊Godot/C#寮€鍙戣鑼?
鐒跺悗鎻愪緵浼樺寲鍚庣殑浠ｇ爜锛岀敤```gdscript鎴朻``csharp鍖呰９銆?
璇风敤涓枃鍥炵瓟銆?"" % code

func call_ai_for_analysis(prompt: String, analysis_type: String) -> void:
	var model_config = get_model_config()
	var endpoint = model_config.get("endpoint", "")
	var api_key = model_config.get("api_key", "")
	var model = model_config.get("model", "")
	
	if endpoint.is_empty() or model.is_empty():
		var fallback = ""
		match analysis_type:
			"explain":
				fallback = "鉂?璇峰厛鍦ㄨ缃腑閰嶇疆AI妯″瀷锛乗n\n馃搵 浠ヤ笅鏄唬鐮佺殑绠€瑕佽鏄庯細\n锛堥渶瑕丄I鎵嶈兘鎻愪緵璇︾粏瑙ｉ噴锛?
			"optimize":
				fallback = "鉂?璇峰厛鍦ㄨ缃腑閰嶇疆AI妯″瀷锛乗n\n馃搵 浠ヤ笅鏄唬鐮佺殑绠€瑕佷紭鍖栧缓璁細\n锛堥渶瑕丄I鎵嶈兘鎻愪緵璇︾粏浼樺寲鏂规锛?
		code_analysis_finished.emit(fallback, analysis_type)
		return
	
	var messages: Array = [{"role": "user", "content": prompt}]
	
	var headers = ["Content-Type: application/json"]
	if not api_key.is_empty():
		headers.append("Authorization: Bearer " + api_key)
	
	var body = {
		"model": model,
		"messages": messages,
		"temperature": 0.5,
		"max_tokens": 3000
	}
	
	var error = http_request.request(
		endpoint + "/chat/completions",
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)
	
	if error != OK:
		thinking_finished.emit("鉂?缃戠粶璇锋眰澶辫触锛岃妫€鏌ョ綉缁滆繛鎺?)

func _on_request_completed(result: int, response_code: int, headers: Array, body: PackedByteArray) -> void:
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json and json is Dictionary:
			var response_text = extract_response(json)
			
			# 淇濆瓨鍒板巻鍙诧紙浠呮櫘閫氬璇濇ā寮忥級
			if _analysis_mode == "":
				conversation_history.append({"role": "user", "content": _pending_user_message})
				conversation_history.append({"role": "assistant", "content": response_text})
				if conversation_history.size() > 40:
					conversation_history = conversation_history.slice(0, 40)
				thinking_finished.emit(response_text)
			else:
				# 浠ｇ爜鍒嗘瀽妯″紡
				var analysis_type = _analysis_mode
				_analysis_mode = ""
				_pending_user_message = ""
				code_analysis_finished.emit(response_text, analysis_type)
		else:
			_analysis_mode = ""
			_pending_user_message = ""
			thinking_finished.emit("鉂?瑙ｆ瀽鍝嶅簲澶辫触")
	elif response_code == 401:
		_analysis_mode = ""
		_pending_user_message = ""
		thinking_finished.emit("鉂?API Key鏃犳晥锛岃妫€鏌ラ厤缃?)
	elif response_code == 429:
		_analysis_mode = ""
		_pending_user_message = ""
		thinking_finished.emit("鈴?璇锋眰杩囦簬棰戠箒锛岃绋嶅悗鍐嶈瘯")
	else:
		_analysis_mode = ""
		_pending_user_message = ""
		thinking_finished.emit("鉂?璇锋眰澶辫触: " + str(response_code))

func get_help_text() -> String:
	var lang = config.get("language", "auto")
	if lang == "auto":
		lang = "zh" if OS.get_locale_language() == "zh" else "en"
	
	if lang == "zh":
		return """馃摉 **浣跨敤甯姪**

**甯哥敤鍛戒护**
鈥?銆屽府鎴戝仛XXX娓告垙銆? 鐢熸垚娓告垙浠ｇ爜
鈥?銆岀粰鐜╁鍔燲XX鍔熻兘銆? 淇敼浠ｇ爜
鈥?銆屾壘XXX绱犳潗銆? 鎼滅储绱犳潗
鈥?銆屼粈涔堟槸XXX銆? 瑙ｇ瓟闂
鈥?銆屾ā鏉裤€? 鏌ョ湅浠ｇ爜妯℃澘
鈥?銆屾竻闄ゃ€? 娓呯┖瀵硅瘽鍘嗗彶

**浠ｇ爜鍒嗘瀽涓庝紭鍖?*
鈥?銆岃В閲婁唬鐮併€? 閫変腑浠ｇ爜鍚庤緭鍏ワ紝AI鍒嗘瀽浠ｇ爜鍔熻兘
鈥?銆屼紭鍖栦唬鐮併€? 閫変腑浠ｇ爜鍚庤緭鍏ワ紝AI鎻愪緵浼樺寲寤鸿
鈥?銆屼唬鐮佽В閲娿€? 鍚屼笂锛岃В閲婇€変腑浠ｇ爜
鈥?銆屼唬鐮佷紭鍖栥€? 鍚屼笂锛屼紭鍖栭€変腑浠ｇ爜

**蹇嵎鎿嶄綔**
鈥?浠ｇ爜妯℃澘 - 蹇€熺敓鎴?鈥?绱犳潗鎼滅储 - 鎼滅储鍏嶈垂绱犳潗
鈥?AI閰嶇疆 - 璁剧疆妯″瀷

鏈変粈涔堥棶棰樺敖绠￠棶锛侌煇?""
	else:
		return """馃摉 **Help**

**Common Commands**
鈥?"Make a XXX game" - Generate game code
鈥?"Add XXX feature" - Modify code
鈥?"Find XXX assets" - Search assets
鈥?"What is XXX" - Ask questions
鈥?"Template" - View code templates
鈥?"Clear" - Clear chat history

**Code Analysis & Optimization**
鈥?"Explain code" - Select code then input, AI analyzes code
鈥?"Optimize code" - Select code then input, AI provides optimization suggestions

**Quick Actions**
鈥?Code Templates - Quick generate
鈥?Asset Search - Search free assets
鈥?AI Settings - Configure model

Feel free to ask anything! 馃悪"""

func get_template_list() -> String:
	var lang = config.get("language", "auto")
	if lang == "auto":
		lang = "zh" if OS.get_locale_language() == "zh" else "en"
	
	if lang == "zh":
		return """馃搵 **浠ｇ爜妯℃澘**

銆?D娓告垙妯℃澘銆?鈥?鐜╁瑙掕壊 - 绉诲姩+璺宠穬
鈥?鏁屼汉AI - 宸￠€?鏀诲嚮
鈥?瀛愬脊绯荤粺 - 鍙戝皠+纰版挒
鈥?UI琛€鏉?- 璺熼殢+鍔ㄧ敾

銆?D娓告垙妯℃澘銆?鈥?FPS鎺у埗鍣?鈥?绗笁浜虹О瑙掕壊
鈥?鎽勫儚鏈鸿窡闅?
銆愮郴缁熸ā鏉裤€?鈥?瀛樻。绯荤粺
鈥?鍟嗗簵绯荤粺
鈥?鎴愬氨绯荤粺

杈撳叆銆岀敓鎴怷XX妯℃澘銆嶈幏鍙栦唬鐮侊紒"""
	else:
		return """馃搵 **Code Templates**

銆?D Game Templates銆?鈥?Player Character - Move+Jump
鈥?Enemy AI - Patrol+Attack
鈥?Bullet System - Fire+Collision
鈥?UI Health Bar - Follow+Animation

銆?D Game Templates銆?鈥?FPS Controller
鈥?Third Person Character
鈥?Camera Follow

銆怱ystem Templates銆?鈥?Save System
鈥?Shop System
鈥?Achievement System

Type "Generate XXX template" to get code!"""

# 璋冪敤AI API
func call_ai(user_message: String) -> void:
	_pending_user_message = user_message
	var model_config = get_model_config()
	var endpoint = model_config.get("endpoint", "")
	var api_key = model_config.get("api_key", "")
	var model = model_config.get("model", "")
	
	if endpoint.is_empty() or model.is_empty():
		thinking_finished.emit("鉂?璇峰厛鍦ㄨ缃腑閰嶇疆AI妯″瀷锛?)
		return
	
	# 鏋勫缓娑堟伅
	var messages = build_messages(user_message)
	
	# 鍙戦€佽姹?	var headers = ["Content-Type: application/json"]
	if not api_key.is_empty():
		headers.append("Authorization: Bearer " + api_key)
	
	var body = {
		"model": model,
		"messages": messages,
		"temperature": 0.7,
		"max_tokens": 2000
	}
	
	var error = http_request.request(
		endpoint + "/chat/completions",
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)
	
	if error != OK:
		thinking_finished.emit("鉂?缃戠粶璇锋眰澶辫触锛岃妫€鏌ョ綉缁滆繛鎺?)

func get_model_config() -> Dictionary:
	var cfg = {
		"type": "openai_compatible",
		"endpoint": "https://api.deepseek.com/v1",
		"api_key": config.get("api_key", ""),
		"model": "deepseek-chat"
	}
	
	if config.get("model_type") == "claude":
		cfg["type"] = "anthropic"
		cfg["endpoint"] = "https://api.anthropic.com/v1"
		cfg["model"] = "claude-3-5-sonnet-20240620"
	elif config.get("model_type") == "gpt":
		cfg["endpoint"] = "https://api.openai.com/v1"
		cfg["model"] = "gpt-4o"
	elif config.get("model_type") == "local":
		cfg["type"] = "openai_compatible"
		cfg["endpoint"] = config.get("local_url", "http://localhost:11434/v1")
		cfg["model"] = config.get("local_model", "qwen2.5:3b")
		cfg["api_key"] = ""
	
	return cfg

func build_messages(user_message: String) -> Array:
	var project_path = "鏈煡"
	var lang = config.get("language", "auto")
	if lang == "auto":
		lang = "zh" if OS.get_locale_language() == "zh" else "en"
	if lang == "en":
		project_path = "Unknown"
	if Engine.get_main_loop() and Engine.get_main_loop().root:
		project_path = ProjectSettings.globalize_path("res://")
	
	var system = get_system_prompt().format({"project_path": project_path})
	var messages: Array = [{"role": "system", "content": system}]
	
	# 娣诲姞鍘嗗彶锛堟渶杩?0杞級
	var history_limit = min(conversation_history.size(), 20)
	for i in range(history_limit):
		messages.append(conversation_history[i])
	
	# 娣诲姞鏂版秷鎭?	messages.append({"role": "user", "content": user_message})
	
	return messages



func extract_response(json: Dictionary) -> String:
	if json.has("choices"):
		var choices = json["choices"]
		if choices is Array and choices.size() > 0:
			return choices[0].get("message", {}).get("content", "")
	return "鏃犳硶瑙ｆ瀽鍝嶅簲"

# ==================== 娴嬭瘯鐢熸垚鍔熻兘 ====================

signal test_generation_requested(target_file: String, test_framework: String)
signal diff_requested(original_code: String, new_code: String, file_path: String)

const TEST_COMMANDS = ["鐢熸垚娴嬭瘯", "鍐欏崟鍏冩祴璇?, "鍗曞厓娴嬭瘯", "鍐欐祴璇?, "娴嬭瘯浠ｇ爜", "create test"]

func generate_tests(target_file: String = "", framework: String = "gdunit") -> String:
	"""鐢熸垚娴嬭瘯浠ｇ爜
	
	Args:
		target_file: 鐩爣鏂囦欢璺緞锛堝彲閫夛級
		framework: 娴嬭瘯妗嗘灦 (gdunit/nunit)
	"""
	var message = ""
	
	if not target_file.is_empty():
		message = "涓轰互涓嬫枃浠剁敓鎴愬崟鍏冩祴璇曪細\n" + target_file + "\n浣跨敤 " + framework + " 妗嗘灦"
	else:
		message = "璇峰憡璇夋垜瑕佷负鍝釜鏂囦欢鐢熸垚娴嬭瘯锛焅n\n鏀寔鐨勬祴璇曟鏋讹細\n鈥?GdUnit - Godot 鍗曞厓娴嬭瘯\n鈥?NUnit - Unity 鍗曞厓娴嬭瘯\n\n鍛戒护鏍煎紡锛氥€屼负 Player.gd 鐢熸垚娴嬭瘯銆?
	
	return message

func request_test_generation(target_file: String, test_framework: String = "gdunit") -> void:
	"""瑙﹀彂娴嬭瘯鐢熸垚淇″彿"""
	test_generation_requested.emit(target_file, test_framework)

# ==================== 宸紓瀵规瘮鍔熻兘 ====================

var original_code_cache: Dictionary = {}

func show_diff(original_code: String, new_code: String, file_path: String = "") -> String:
	"""鏄剧ず浠ｇ爜宸紓
	
	Args:
		original_code: 鍘熷浠ｇ爜
		new_code: 鏂颁唬鐮?		file_path: 鏂囦欢璺緞
	
	Returns:
		鏍煎紡鍖栫殑diff瀛楃涓?	"""
	# 缂撳瓨鍘熷浠ｇ爜
	if not file_path.is_empty():
		original_code_cache[file_path] = original_code
	
	return format_diff(original_code, new_code, file_path)

func format_diff(original: String, new_code: String, file_path: String = "") -> String:
	"""鏍煎紡鍖杁iff杈撳嚭"""
	var lines: Array = []
	
	# 鏂囦欢澶?	if not file_path.is_empty():
		lines.append("馃搫 鏂囦欢: " + file_path)
		lines.append("鈹?.repeat(40))
	
	# 浣跨敤绠€鍗曡瀵规瘮
	var old_lines = original.split("\n")
	var new_lines = new_code.split("\n")
	
	var additions = 0
	var deletions = 0
	var unchanged = 0
	
	# 缁熻鍙樺寲
	for new_line in new_lines:
		if not old_lines.has(new_line):
			additions += 1
	
	for old_line in old_lines:
		if not new_lines.has(old_line):
			deletions += 1
	
	# 鐢熸垚缁熶竴鏍煎紡diff
	lines.append("\n馃搳 宸紓缁熻:")
	lines.append("   鉃?鏂板: " + str(additions) + " 琛?)
	lines.append("   鉃?鍒犻櫎: " + str(deletions) + " 琛?)
	
	lines.append("\n" + "鈹?.repeat(40))
	lines.append("馃摑 璇︾粏鍙樻洿:")
	lines.append("鈹?.repeat(40))
	
	# 閫愯瀵规瘮
	var max_lines = max(old_lines.size(), new_lines.size())
	var context = 3  # 涓婁笅鏂囪鏁?	
	for i in range(max_lines):
		var old_line_text = old_lines[i] if i < old_lines.size() else null
		var new_line_text = new_lines[i] if i < new_lines.size() else null
		
		if old_line_text == new_line_text:
			if old_line_text != null:
				lines.append("  " + old_line_text)
				unchanged += 1
		else:
			if old_line_text != null:
				lines.append("-" + old_line_text)
			if new_line_text != null:
				lines.append("+" + new_line_text)
	
	lines.append("鈹?.repeat(40))
	
	# 鎿嶄綔寤鸿
	lines.append("\n馃挕 鎿嶄綔閫夐」:")
	lines.append("鈥?銆屾帴鍙椼€嶆垨銆岀‘璁ゃ€? 搴旂敤姝や慨鏀?)
	lines.append("鈥?銆屽彇娑堛€? 鏀惧純姝や慨鏀?)
	lines.append("鈥?銆岄€愬潡纭銆? 閫愪釜鎺ュ彈鍙樻洿鍧?)
	
	return "\n".join(lines)

func get_diff_chunk(original: String, new_code: String, start_line: int, count: int) -> Dictionary:
	"""鑾峰彇鎸囧畾鑼冨洿鐨刣iff鍧?	
	Args:
		original: 鍘熷浠ｇ爜
		new_code: 鏂颁唬鐮?		start_line: 璧峰琛屽彿
		count: 鍧楀ぇ灏?	
	Returns:
		Dictionary with 'added', 'removed', 'unchanged' arrays
	"""
	var result = {
		"added": [],
		"removed": [],
		"unchanged": [],
		"start_line": start_line
	}
	
	var old_lines = original.split("\n")
	var new_lines = new_code.split("\n")
	
	var end_line = min(start_line + count, max(old_lines.size(), new_lines.size()))
	
	for i in range(start_line, end_line):
		var old_line_text = old_lines[i] if i < old_lines.size() else null
		var new_line_text = new_lines[i] if i < new_lines.size() else null
		
		if old_line_text == new_line_text:
			if old_line_text != null:
				result["unchanged"].append(old_line_text)
		else:
			if old_line_text != null:
				result["removed"].append({"line": i + 1, "text": old_line_text})
			if new_line_text != null:
				result["added"].append({"line": i + 1, "text": new_line_text})
	
	return result

func apply_diff_chunk(file_path: String, chunk: Dictionary) -> bool:
	"""搴旂敤鍗曚釜diff鍧?	
	Args:
		file_path: 鏂囦欢璺緞
		chunk: diff鍧?	
	Returns:
		鏄惁鎴愬姛
	"""
	if not FileAccess.file_exists(file_path):
		return false
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return false
	
	var content = file.get_as_text()
	file.close()
	
	# 搴旂敤鍙樻洿
	# 杩欓噷绠€鍖栧鐞嗭紝瀹為檯搴旇鏇寸簿纭?	return true

# ==================== 鍘熸湁鍔熻兘 ====================

# 鍋滄澶勭悊
func cancel():
	if is_processing:
		http_request.cancel_request()
		is_processing = false
		emit_signal("thinking_finished", "宸插彇娑?)

# ==================== Git闆嗘垚鍔熻兘 ====================

# Git鐘舵€?func git_status() -> Dictionary:
	var output = []
	var result = OS.execute("git", ["status", "--porcelain"], output, true)
	
	var status_data = {
		"success": result == 0,
		"modified": [],
		"untracked": [],
		"staged": [],
		"output": ""
	}
	
	if result == 0 and output.size() > 0:
		status_data["output"] = output[0]
		var lines = output[0].split("\n")
		for line in lines:
			if line.is_empty():
				continue
			if line.begins_with("M ") or line.begins_with(" M"):
				status_data["modified"].append(line.substr(3).strip_edges())
			elif line.begins_with("A ") or line.begins_with("A"):
				status_data["staged"].append(line.substr(2).strip_edges())
			elif line.begins_with("??") or line.begins_with("??"):
				status_data["untracked"].append(line.substr(3).strip_edges())
	
	return status_data

# 鑾峰彇Git鍙樻洿缁熻
func git_diff_stats() -> String:
	var output = []
	var result = OS.execute("git", ["diff", "--stat"], output, true)
	
	if result == 0 and output.size() > 0:
		return output[0]
	return ""

# 鐢熸垚鎻愪氦淇℃伅
func generate_commit_message() -> String:
	var status = git_status()
	var diff_stats = git_diff_stats()
	
	var files_changed = status["modified"].size() + status["staged"].size() + status["untracked"].size()
	if files_changed == 0:
		return ""
	
	var changes_summary = ""
	if status["modified"].size() > 0:
		changes_summary += "淇敼: " + str(status["modified"].size()) + "涓枃浠禱n"
	if status["staged"].size() > 0:
		changes_summary += "鏂板: " + str(status["staged"].size()) + "涓枃浠禱n"
	if status["untracked"].size() > 0:
		changes_summary += "鏈窡韪? " + str(status["untracked"].size()) + "涓枃浠禱n"
	
	return """馃摑 **鎻愪氦淇℃伅寤鸿**

**鍙樻洿缁熻**
%s
**diff缁熻**
```
%s
```

馃挕 杈撳叆銆岀‘璁ゆ彁浜ゃ€嶅畬鎴愭彁浜わ紝鎴栦慨鏀逛笂杩颁俊鎭悗銆岀‘璁ゆ彁浜ゃ€?""

# Git鎻愪氦
func git_commit(message: String = "") -> Dictionary:
	var result_data = {
		"success": false,
		"message": ""
	}
	
	# 妫€鏌ユ槸鍚︽湁鍙樻洿
	var status = git_status()
	var total_changes = status["modified"].size() + status["staged"].size() + status["untracked"].size()
	
	if total_changes == 0:
		result_data["message"] = "鈿狅笍 娌℃湁鍙彁浜ょ殑鍐呭"
		return result_data
	
	# 濡傛灉娌℃湁鎻愪緵鎻愪氦淇℃伅锛屽厛妫€鏌ユ殏瀛樺尯
	if message.is_empty():
		var staged_output = []
		OS.execute("git", ["diff", "--cached", "--stat"], staged_output, true)
		if staged_output.size() > 0 and not staged_output[0].is_empty():
			result_data["message"] = "馃搵 妫€娴嬪埌宸叉殏瀛樼殑鍙樻洿:\n" + staged_output[0] + "\n\n璇锋彁渚涙彁浜や俊鎭?
		else:
			result_data["message"] = "馃搵 璇峰厛浣跨敤銆屾殏瀛樻枃浠躲€嶆垨銆屾坊鍔犳墍鏈夈€嶅悗鍐嶆彁浜?
		return result_data
	
	# 鎵ц鎻愪氦
	var output = []
	var result = OS.execute("git", ["commit", "-m", message], output, true)
	
	if result == 0:
		result_data["success"] = true
		result_data["message"] = "鉁?鎻愪氦鎴愬姛!\n\n" + message
	else:
		result_data["message"] = "鉂?鎻愪氦澶辫触: " + (output[0] if output.size() > 0 else "鏈煡閿欒")
	
	return result_data

# Git鏆傚瓨鏂囦欢
func git_add(files: Array = []) -> Dictionary:
	var result_data = {
		"success": false,
		"message": ""
	}
	
	var output = []
	var args = ["add"]
	
	if files.is_empty():
		args.append("-A")  # 娣诲姞鎵€鏈?	else:
		args.append_array(files)
	
	var result = OS.execute("git", args, output, true)
	
	if result == 0:
		result_data["success"] = true
		result_data["message"] = "鉁?鏂囦欢宸叉殏瀛榎n\n" + (output[0] if output.size() > 0 else "")
	else:
		result_data["message"] = "鉂?鏆傚瓨澶辫触: " + (output[0] if output.size() > 0 else "鏈煡閿欒")
	
	return result_data

# Git鍘嗗彶
func git_log(limit: int = 10) -> String:
	var output = []
	var result = OS.execute("git", ["log", "--oneline", "--graph", "--decorate", "-n", str(limit)], output, true)
	
	if result == 0 and output.size() > 0:
		return "馃摐 **鎻愪氦鍘嗗彶**\n\n```\n" + output[0] + "```"
	else:
		return "鈿狅笍 鏃犳硶鑾峰彇鎻愪氦鍘嗗彶"
	
# 鑾峰彇鍒嗘敮淇℃伅
func git_branch() -> Dictionary:
	var output = []
	var result = OS.execute("git", ["branch", "-v"], output, true)
	
	var branch_data = {
		"success": result == 0,
		"current": "",
		"all": []
	}
	
	if result == 0 and output.size() > 0:
		var lines = output[0].split("\n")
		for line in lines:
			if line.begins_with("*"):
				branch_data["current"] = line.substr(2).strip_edges()
			branch_data["all"].append(line.strip_edges())
	
	return branch_data

# Git鎷夊彇
func git_pull() -> Dictionary:
	var output = []
	var result = OS.execute("git", ["pull"], output, true)
	
	return {
		"success": result == 0,
		"message": (output[0] if output.size() > 0 else "") if result == 0 else ("鉂?鎷夊彇澶辫触: " + (output[0] if output.size() > 0 else ""))
	}

# Git鎺ㄩ€?func git_push() -> Dictionary:
	var output = []
	var result = OS.execute("git", ["push"], output, true)
	
	return {
		"success": result == 0,
		"message": (output[0] if output.size() > 0 else "") if result == 0 else ("鉂?鎺ㄩ€佸け璐? " + (output[0] if output.size() > 0 else ""))
	}

# ==================== 澶氱鍚屾鍔熻兘 ====================

# 鍚屾閰嶇疆鍒颁簯绔?func sync_config(sync_type: String = "all") -> Dictionary:
	var sync_result = {
		"success": false,
		"message": "",
		"synced_items": []
	}
	
	var cfg = config.get("sync_config", {})
	var sync_enabled = cfg.get("enabled", false)
	var sync_url = cfg.get("webdav_url", "")
	
	if not sync_enabled or sync_url.is_empty():
		sync_result["message"] = "鈿狅笍 鍚屾鏈厤缃紝璇峰湪璁剧疆涓厤缃悓姝ユ湇鍔?
		return sync_result
	
	# 鍑嗗鍚屾鏁版嵁
	var sync_data = {
		"timestamp": Time.get_datetime_string_from_system(),
		"version": "1.0",
		"config": {},
		"knowledge": [],
		"shortcuts": {}
	}
	
	# 鍚屾璁剧疆
	if sync_type == "all" or sync_type == "settings":
		sync_data["config"] = _get_syncable_config()
		sync_result["synced_items"].append("璁剧疆")
	
	# 鍚屾鐭ヨ瘑搴?	if sync_type == "all" or sync_type == "knowledge":
		sync_data["knowledge"] = _get_knowledge_data()
		sync_result["synced_items"].append("鐭ヨ瘑搴?)
	
	# 鍚屾蹇嵎閿?	if sync_type == "all" or sync_type == "shortcuts":
		sync_data["shortcuts"] = _get_shortcuts_data()
		sync_result["synced_items"].append("蹇嵎閿厤缃?)
	
	# 涓婁紶鍒颁簯绔?	var json_data = JSON.stringify(sync_data)
	var result = _upload_to_webdav(sync_url, json_data)
	
	if result["success"]:
		sync_result["success"] = true
		sync_result["message"] = "鉁?鍚屾鎴愬姛!\n\n宸插悓姝? " + ", ".join(sync_result["synced_items"])
	else:
		sync_result["message"] = "鉂?鍚屾澶辫触: " + result.get("error", "鏈煡閿欒")
	
	return sync_result

# 浠庝簯绔仮澶嶉厤缃?func restore_config() -> Dictionary:
	var restore_result = {
		"success": false,
		"message": "",
		"restored_items": []
	}
	
	var cfg = config.get("sync_config", {})
	var sync_url = cfg.get("webdav_url", "")
	
	if sync_url.is_empty():
		restore_result["message"] = "鈿狅笍 鏈厤缃悓姝ユ湇鍔?
		return restore_result
	
	var result = _download_from_webdav(sync_url)
	
	if not result["success"]:
		restore_result["message"] = "鉂?涓嬭浇澶辫触: " + result.get("error", "鏈煡閿欒")
		return restore_result
	
	var sync_data = JSON.parse_string(result["data"])
	if not sync_data:
		restore_result["message"] = "鉂?瑙ｆ瀽浜戠鏁版嵁澶辫触"
		return restore_result
	
	# 鎭㈠璁剧疆
	if sync_data.has("config") and sync_data["config"].size() > 0:
		_apply_config(sync_data["config"])
		restore_result["restored_items"].append("璁剧疆")
	
	# 鎭㈠鐭ヨ瘑搴?	if sync_data.has("knowledge") and sync_data["knowledge"].size() > 0:
		_apply_knowledge(sync_data["knowledge"])
		restore_result["restored_items"].append("鐭ヨ瘑搴?)
	
	# 鎭㈠蹇嵎閿?	if sync_data.has("shortcuts") and sync_data["shortcuts"].size() > 0:
		_apply_shortcuts(sync_data["shortcuts"])
		restore_result["restored_items"].append("蹇嵎閿厤缃?)
	
	restore_result["success"] = true
	restore_result["message"] = "鉁?鎭㈠鎴愬姛!\n\n宸叉仮澶? " + ", ".join(restore_result["restored_items"])
	
	return restore_result

# 鑾峰彇鍙悓姝ョ殑閰嶇疆
func _get_syncable_config() -> Dictionary:
	var syncable = {
		"model_type": config.get("model_type", ""),
		"model_name": config.get("model_name", ""),
		"api_key": config.get("api_key", ""),
		"endpoint": config.get("endpoint", ""),
		"auto_mode": config.get("auto_mode", true),
		"confirm_mode": config.get("confirm_mode", "auto")
	}
	return syncable

# 鑾峰彇鐭ヨ瘑搴撴暟鎹?func _get_knowledge_data() -> Array:
	var knowledge_data: Array = []
	var kb = get_node_or_null("/root/KnowledgeBase")
	if kb and kb.has_method("get_all_entries"):
		knowledge_data = kb.get_all_entries()
	return knowledge_data

# 鑾峰彇蹇嵎閿厤缃?func _get_shortcuts_data() -> Dictionary:
	# 浠庨」鐩缃幏鍙栧揩鎹烽敭
	var shortcuts: Dictionary = {}
	# 杩欓噷绠€鍖栧鐞嗭紝瀹為檯鍙互浠嶶I閰嶇疆璇诲彇
	return shortcuts

# 搴旂敤閰嶇疆
func _apply_config(cfg: Dictionary) -> void:
	config.merge(cfg, true)

# 搴旂敤鐭ヨ瘑搴?func _apply_knowledge(entries: Array) -> void:
	var kb = get_node_or_null("/root/KnowledgeBase")
	if kb and kb.has_method("batch_import"):
		kb.batch_import(entries)

# 搴旂敤蹇嵎閿?func _apply_shortcuts(shortcuts: Dictionary) -> void:
	# 搴旂敤蹇嵎閿厤缃?	pass

# 涓婁紶鍒癢ebDAV
func _upload_to_webdav(url: String, data: String) -> Dictionary:
	var result = {"success": false, "error": ""}
	
	var temp_file = "user://sync_temp.json"
	var file = FileAccess.open(temp_file, FileAccess.WRITE)
	if file:
		file.store_string(data)
		file.close()
		
		var output = []
		var args = ["-X", "PUT", "-d", "@" + temp_file, "-H", "Content-Type: application/json", url]
		var exec_result = OS.execute("curl", args, output, true)
		
		if exec_result == 0:
			result["success"] = true
		else:
			result["error"] = output[0] if output.size() > 0 else "涓婁紶澶辫触"
		
		# 鍒犻櫎涓存椂鏂囦欢
		DirAccess.remove_absolute(temp_file)
	else:
		result["error"] = "鏃犳硶鍒涘缓涓存椂鏂囦欢"
	
	return result

# 浠嶹ebDAV涓嬭浇
func _download_from_webdav(url: String) -> Dictionary:
	var result = {"success": false, "error": "", "data": ""}
	
	var temp_file = "user://sync_download.json"
	var output = []
	var args = ["-X", "GET", "-o", temp_file, url]
	var exec_result = OS.execute("curl", args, output, true)
	
	if exec_result == 0 and FileAccess.file_exists(temp_file):
		var file = FileAccess.open(temp_file, FileAccess.READ)
		if file:
			result["data"] = file.get_as_text()
			result["success"] = true
			file.close()
		DirAccess.remove_absolute(temp_file)
	else:
		result["error"] = output[0] if output.size() > 0 else "涓嬭浇澶辫触"
	
	return result

# 鑾峰彇鍚屾鐘舵€?func get_sync_status() -> Dictionary:
	var cfg = config.get("sync_config", {})
	var enabled = cfg.get("enabled", false)
	var last_sync = cfg.get("last_sync", "")
	var sync_url = cfg.get("webdav_url", "")
	
	return {
		"enabled": enabled,
		"last_sync": last_sync,
		"configured": not sync_url.is_empty(),
		"sync_type": cfg.get("type", "webdav")  # webdav 鎴?api
	}

