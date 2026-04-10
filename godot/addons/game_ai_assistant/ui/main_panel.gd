extends PanelContainer

# 涓婚潰鏉?- AI瀵硅瘽鐣岄潰 v1.5
# 娣诲姞娴嬭瘯鐢熸垚鍜屽樊寮傚姣斿姛鑳?# 鍙岃鏀寔

var config: Node

@onready var status_icon: Label = $Margin/VBox/StatusBar/HBox/StatusIcon
@onready var status_text: Label = $Margin/VBox/StatusBar/HBox/StatusText
@onready var model_label: Label = $Margin/VBox/StatusBar/HBox/ModelLabel
@onready var history_label: Label = $Margin/VBox/StatusBar/HBox/HistoryLabel
@onready var pending_label: Label = $Margin/VBox/StatusBar/HBox/PendingLabel
@onready var chat_container: VBoxContainer = $Margin/VBox/ChatScroll/ChatContainer
@onready var input: TextEdit = $Margin/VBox/InputArea/HBox/InputScroll/Input
@onready var send_btn: Button = $Margin/VBox/InputArea/HBox/VBox/SendBtn
@onready var clear_btn: Button = $Margin/VBox/InputArea/HBox/VBox/ClearBtn
@onready var undo_btn: Button = $Margin/VBox/InputArea/HBox/VBox/UndoBtn
@onready var redo_btn: Button = $Margin/VBox/InputArea/HBox/VBox/RedoBtn
@onready var preview_btn: Button = $Margin/VBox/InputArea/HBox/VBox/PreviewBtn
@onready var apply_btn: Button = $Margin/VBox/InputArea/HBox/VBox/ApplyBtn
@onready var config_btn: Button = $Margin/VBox/Header/HBox/ConfigBtn
@onready var templates_btn: Button = $Margin/VBox/BottomBar/TemplatesBtn
@onready var assets_btn: Button = $Margin/VBox/BottomBar/AssetsBtn
@onready var help_btn: Button = $Margin/VBox/BottomBar/HelpBtn
@onready var project_btn: Button = $Margin/VBox/BottomBar/ProjectBtn
@onready var learning_btn: Button = $Margin/VBox/BottomBar/LearningBtn
@onready var knowledge_btn: Button = $Margin/VBox/BottomBar/KnowledgeBtn
@onready var project_template_btn: Button = $Margin/VBox/BottomBar/ProjectTemplateBtn
@onready var scene_gen_btn: Button = $Margin/VBox/BottomBar/SceneGenBtn
@onready var debug_btn: Button = $Margin/VBox/BottomBar/DebugBtn
@onready var search_btn: Button = $Margin/VBox/BottomBar/SearchBtn

# ==================== 娴嬭瘯鐢熸垚鐩稿叧 ====================
@onready var test_btn: Button = $Margin/VBox/BottomBar/TestBtn
@onready var diff_btn: Button = $Margin/VBox/BottomBar/DiffBtn

# 鐘舵€?var pending_code_blocks: Array = []
var pending_preview_index: int = -1
var _selected_code: String = ""  # 鐢ㄦ埛閫変腑鐨勪唬鐮侊紙鐢ㄤ簬瑙ｉ噴/浼樺寲锛?
# ==================== 宸紓瀵规瘮鐩稿叧 ====================
var current_diff_info: Dictionary = {}
var current_original_code: String = ""
var current_new_code: String = ""
var diff_chunks: Array = []
var current_diff_index: int = -1
var is_showing_diff: bool = false

# 鏍稿績妯″潡
var ai_handler: Node
var project_reader: Node
var code_applier: Node
var code_generator: Node
var screenshot_handler: Node
var daily_learning: Node
var knowledge_base: Node

func _ready() -> void:
	send_btn.pressed.connect(_on_send)
	clear_btn.pressed.connect(_on_clear)
	undo_btn.pressed.connect(_on_undo)
	redo_btn.pressed.connect(_on_redo)
	preview_btn.pressed.connect(_on_preview)
	apply_btn.pressed.connect(_on_apply)
	apply_btn.disabled = true
	config_btn.pressed.connect(_on_config)
	templates_btn.pressed.connect(_on_templates)
	assets_btn.pressed.connect(_on_assets)
	help_btn.pressed.connect(_on_help)
	project_btn.pressed.connect(_on_scan_project)
	learning_btn.pressed.connect(_on_today_learning)
	knowledge_btn.pressed.connect(_on_open_knowledge)
	project_template_btn.pressed.connect(_on_project_template)
	scene_gen_btn.pressed.connect(_on_scene_generation)
	
	# 娴嬭瘯鍜屽樊寮傚姣旀寜閽?	test_btn.pressed.connect(_on_generate_test)
	diff_btn.pressed.connect(_on_show_diff)
	
	# 璋冭瘯鍔╂墜鍜屼唬鐮佹悳绱㈡寜閽?	debug_btn.pressed.connect(_on_debug_assist)
	search_btn.pressed.connect(_on_code_search)
	
	input.text_submitted.connect(_on_input_submitted)
	
	_setup_modules()
	_update_status()
	_update_history_label()

func _setup_modules() -> void:
	ai_handler = get_node_or_null("/root/GameAIHandler")
	project_reader = get_node_or_null("/root/ProjectReader")
	code_applier = get_node_or_null("/root/CodeApplier")
	screenshot_handler = get_node_or_null("/root/ScreenshotHandler")
	daily_learning = get_node_or_null("/root/DailyLearning")
	knowledge_base = get_node_or_null("/root/KnowledgeBase")
	config = get_node_or_null("/root/GameAIConfig")
	
	if ai_handler:
		ai_handler.thinking_started.connect(_on_thinking_started)
		ai_handler.thinking_finished.connect(_on_thinking_finished)
		ai_handler.errorOccurred.connect(_on_error)
		ai_handler.code_analysis_finished.connect(_on_code_analysis_finished)
		ai_handler.test_generation_requested.connect(_on_ai_test_requested)
		ai_handler.diff_requested.connect(_on_ai_diff_requested)
	
	if code_applier:
		code_applier.history_updated.connect(_on_history_updated)
		code_applier.code_applied.connect(_on_code_applied)
		code_applier.preview_requested.connect(_on_preview_requested)
	
	# 鑾峰彇浠ｇ爜鐢熸垚鍣?	code_generator = get_node_or_null("/root/CodeGenerator")
	
	load_config()

func _on_ai_test_requested(target_file: String, framework: String) -> void:
	"""澶勭悊AI瑙﹀彂鐨勬祴璇曠敓鎴愯姹?""
	_on_generate_test_with_text("涓?" + target_file + " 鐢熸垚娴嬭瘯")

func _on_ai_diff_requested(original_code: String, new_code: String, file_path: String) -> void:
	"""澶勭悊AI瑙﹀彂鐨勫樊寮傚姣旇姹?""
	set_diff_state(original_code, new_code, file_path)

func load_config() -> Dictionary:
	var config_path = "user://ai_config.json"
	if FileAccess.file_exists(config_path):
		var file = FileAccess.open(config_path, FileAccess.READ)
		if file:
			var json = JSON.parse_string(file.get_as_text())
			file.close()
			if json and json is Dictionary:
				update_status_from_config(json)
				if ai_handler:
					ai_handler.configure(json)
				return json
	return {}

func update_status_from_config(cfg: Dictionary) -> void:
	var model_type = cfg.get("model_type", "")
	var lang = cfg.get("language", "auto")
	if lang == "auto":
		lang = "zh" if OS.get_locale_language() == "zh" else "en"
	match model_type:
		"deepseek":
			model_label.text = "DeepSeek V3"
		"claude":
			model_label.text = "Claude 3.5"
		"gpt":
			model_label.text = "GPT-4o"
		"local":
			model_label.text = "馃實 Local" if lang == "en" else "馃實 鏈湴妯″瀷"
		_:
			model_label.text = "鈿狅笍 Not Set" if lang == "en" else "鈿狅笍 鏈厤缃?

func _update_status() -> void:
	status_text.text = _tr("ready")
	status_icon.text = "鈴革笍"

func _tr(key: String) -> String:
	if config and config.has_method("tr"):
		return config.tr(key)
	return key

func _update_history_label() -> void:
	if code_applier:
		var status = code_applier.get_history_status()
		history_label.text = "鈫╋笍%d 鈫笍%d" % [status["undo_count"], status["redo_count"]]
		history_label.modulate = Color.WHITE if status["undo_count"] > 0 else Color.GRAY
		
		# 鏇存柊寰呭簲鐢ㄤ唬鐮佹寚绀?		_update_pending_indicator()
	else:
		history_label.text = ""
		pending_label.text = ""

func _update_pending_indicator() -> void:
	if code_applier:
		var blocks = code_applier.pending_blocks
		if not blocks.is_empty():
			pending_label.text = "馃搵 %d %s" % [blocks.size(), _tr("pending_blocks")]
			pending_label.modulate = Color.YELLOW
			apply_btn.disabled = false
			preview_btn.disabled = false
		else:
			pending_label.text = ""
			apply_btn.disabled = true
			preview_btn.disabled = true
	else:
		pending_label.text = ""

# ==================== 鍙戦€佹秷鎭?====================

func _on_send() -> void:
	var text = input.text.strip_edges()
	if text.is_empty():
		return
	
	# 鎻愬彇浠ｇ爜鍧楋紙鐢ㄤ簬瑙ｉ噴/浼樺寲鍔熻兘锛?	_extract_code_from_text(text)
	
	add_user_message(text)
	input.text = ""
	
	var special_response = check_special_command(text)
	if special_response:
		add_assistant_message(special_response)
		return
	
	if ai_handler:
		ai_handler.process_message(text)

func _extract_code_from_text(text: String) -> void:
	"""浠庤緭鍏ユ枃鏈腑鎻愬彇浠ｇ爜鍧楋紝瀛樺偍鍒?_selected_code"""
	var code_start = text.find("```")
	if code_start != -1:
		# 鎵惧埌浠ｇ爜鍧楄瑷€鏍囪瘑鍚庣殑鎹㈣
		var lang_end = text.find("\n", code_start + 3)
		if lang_end == -1:
			return
		var code_content_start = lang_end + 1
		var code_end = text.find("```", code_content_start)
		if code_end == -1:
			return
		_selected_code = text.substr(code_content_start, code_end - code_content_start).strip_edges()
		return
	
	# 濡傛灉娌℃湁浠ｇ爜鍧楁牸寮忥紝妫€鏌ユ槸鍚﹀叏鏄唬鐮侊紙澶氳锛屾棤涓枃锛?	var lines = text.split("\n")
	if lines.size() > 2:
		var has_code_chars = false
		for ch in text:
			if ch == "{" or ch == "}" or ch == "(" or ch == ")" or ch == "->" or ch == "func " or ch == "var " or ch == "extends " or ch == "class ":
				has_code_chars = true
				break
		if has_code_chars:
			_selected_code = text
			return
	
	# 鍚﹀垯涓嶆彁鍙栦唬鐮侊紙淇濇寔涓婃閫夋嫨鐨勪唬鐮侊級

func _on_input_submitted(text: String) -> void:
	_on_send()

func check_special_command(text: String) -> String:
	var lower = text.to_lower()
	
	# 椤圭洰妯℃澘鍛戒护
	if lower.begins_with("鍒涘缓椤圭洰") or lower.begins_with("鏂板缓椤圭洰") or lower.begins_with("椤圭洰妯℃澘"):
		_on_project_template()
		return ""
	
	if lower.begins_with("鍒涘缓"):
		if handle_create_template(text):
			return ""
	
	# 鍦烘櫙鐢熸垚鍛戒护
	if lower.begins_with("鐢熸垚鍦烘櫙") or lower.begins_with("鍒涘缓鍦烘櫙") or lower.begins_with("鍦烘櫙鍚戝"):
		_on_scene_generation()
		return ""
	
	if lower.begins_with("鐢熸垚"):
		if handle_scene_generation(text):
			return ""
	
	# 浠ｇ爜瑙ｉ噴鍛戒护
	if lower.begins_with("瑙ｉ噴浠ｇ爜") or lower.begins_with("瑙ｉ噴杩欐浠ｇ爜") or lower.begins_with("浠ｇ爜瑙ｉ噴") or lower.begins_with("鍒嗘瀽浠ｇ爜") or lower.begins_with("杩欐浠ｇ爜鍋氫簡浠€涔?) or lower.begins_with("鍒嗘瀽杩欐浠ｇ爜"):
		if ai_handler and not _selected_code.is_empty():
			add_assistant_message("馃攳 姝ｅ湪鍒嗘瀽浠ｇ爜锛岃绋嶅€?..")
			ai_handler.analyze_code(_selected_code, "explain")
			_selected_code = ""
			return ""  # 寮傛澶勭悊
		else:
			return "馃搵 璇峰厛鍦ㄨ緭鍏ユ涓矘璐磋瑙ｉ噴鐨勪唬鐮侊紝鐒跺悗杈撳叆銆岃В閲婁唬鐮併€?
	
	# 浠ｇ爜浼樺寲鍛戒护
	if lower.begins_with("浼樺寲浠ｇ爜") or lower.begins_with("浼樺寲杩欐浠ｇ爜") or lower.begins_with("浠ｇ爜浼樺寲") or lower.begins_with("鏀硅繘浠ｇ爜") or lower.begins_with("濡備綍浼樺寲") or lower.begins_with("濡備綍鏀硅繘"):
		if ai_handler and not _selected_code.is_empty():
			add_assistant_message("馃敡 姝ｅ湪浼樺寲浠ｇ爜锛岃绋嶅€?..")
			ai_handler.analyze_code(_selected_code, "optimize")
			_selected_code = ""
			return ""  # 寮傛澶勭悊
		else:
			return "馃搵 璇峰厛鍦ㄨ緭鍏ユ涓矘璐磋浼樺寲鐨勪唬鐮侊紝鐒跺悗杈撳叆銆屼紭鍖栦唬鐮併€?
	
	# 鎾ら攢/閲嶅仛
	if lower.begins_with("鎾ら攢"):
		_on_undo()
		return ""
	
	if lower.begins_with("閲嶅仛"):
		_on_redo()
		return ""
	
	# 棰勮
	if lower.begins_with("棰勮"):
		var parts = text.split(" ")
		if parts.size() > 1:
			var idx = parts[1].to_int() - 1
			_on_preview_index(idx)
		else:
			_on_preview_all()
		return ""
	
	# 搴旂敤
	if lower.begins_with("搴旂敤"):
		var parts = text.split(" ")
		if parts.size() > 1 and parts[1].is_valid_int():
			var idx = parts[1].to_int() - 1
			_on_apply_single(idx)
		else:
			_on_apply()
		return ""
	
	# 纭鎿嶄綔
	if lower.begins_with("纭") or lower.begins_with("瑕嗙洊"):
		_on_confirm()
		return ""
	
	if lower.begins_with("鍙栨秷"):
		_on_cancel()
		return ""
	
	if lower.begins_with("璺宠繃"):
		_on_skip()
		return ""
	
	if lower.begins_with("鍘嗗彶"):
		return _get_history_report()
	
	if lower.begins_with("鎵弿椤圭洰") or lower.begins_with("椤圭洰缁撴瀯"):
		_on_scan_project()
		return ""
	
	if lower.begins_with("浠婃棩瀛︿範") or lower.begins_with("瀛︿範"):
		_on_today_learning()
		return ""
	
	if lower.begins_with("鐭ヨ瘑搴?):
		_on_open_knowledge()
		return ""
	
	if lower.begins_with("蹇嵎閿?) or lower.begins_with("甯姪"):
		_on_help()
		return ""
	
	if lower.begins_with("鎴浘"):
		_on_capture_screenshot()
		return ""
	
	if lower.begins_with("鐢熸垚") and lower.contains("妯℃澘"):
		var template_name = extract_template_name(text)
		if not template_name.is_empty():
			generate_template_code(template_name)
		return ""
	
	if lower.begins_with("娣诲姞鐭ヨ瘑"):
		var parts = text.split(":", 1)
		if parts.size() > 1:
			add_knowledge_entry(parts[1].strip_edges())
		return ""
	
	if lower.begins_with("鎼滅储鐭ヨ瘑") or lower.begins_with("鏌ユ壘鐭ヨ瘑"):
		var parts = text.split(":", 1)
		if parts.size() > 1:
			search_knowledge(parts[1].strip_edges())
		return ""
	
	# 娴嬭瘯鐢熸垚鍛戒护
	if lower.begins_with("鐢熸垚娴嬭瘯") or lower.begins_with("鍐欏崟鍏冩祴璇?) or \
	   lower.begins_with("鍗曞厓娴嬭瘯") or lower.begins_with("鍐欐祴璇?) or \
	   lower.begins_with("娴嬭瘯浠ｇ爜"):
		_on_generate_test_with_text(text)
		return ""
	
	# 宸紓瀵规瘮鍛戒护
	if lower.begins_with("diff") or lower.begins_with("宸紓") or \
	   lower.begins_with("瀵规瘮") or lower.begins_with("show diff"):
		_on_show_diff_with_text(text)
		return ""
	
	# 鎺ュ彈宸紓
	if lower.begins_with("鎺ュ彈") or lower.begins_with("纭") or lower == "apply":
		_on_accept_diff()
		return ""
	
	# 鎺ュ彈鍗曚釜鍙樻洿鍧?	if lower.begins_with("鎺ュ彈 ") and text.length() > 4:
		var parts = text.split(" ")
		if parts.size() > 1 and parts[1].is_valid_int():
			var idx = parts[1].to_int() - 1
			_on_accept_diff_chunk(idx)
		return ""
	
	return ""

func extract_template_name(text: String) -> String:
	var keywords = ["鐜╁", "鏁屼汉", "鏁屼汉ai", "瀛愬脊", "琛€鏉?, "鏁屼汉", "瀛樻。", "鍟嗗簵", "鎴愬氨", "ui"]
	for keyword in keywords:
		if text.to_lower().contains(keyword):
			return keyword
	return ""

# ==================== 棰勮鍔熻兘 ====================

func _on_preview() -> void:
	if not code_applier or code_applier.pending_blocks.is_empty():
		add_assistant_message("鈿狅笍 娌℃湁寰呴瑙堢殑浠ｇ爜")
		return
	_on_preview_all()

func _on_preview_all() -> void:
	if not code_applier:
		return
	
	var report = code_applier.generate_preview_report()
	add_assistant_message(report)

func _on_preview_index(index: int) -> void:
	if not code_applier or code_applier.pending_blocks.is_empty():
		add_assistant_message("鈿狅笍 娌℃湁寰呴瑙堢殑浠ｇ爜")
		return
	
	var report = code_applier.preview_single_block(index)
	add_assistant_message(report)

func _on_preview_requested(blocks: Array) -> void:
	_update_pending_indicator()
	if not blocks.is_empty():
		add_assistant_message("馃搵 妫€娴嬪埌 %d 涓唬鐮佸潡\n杈撳叆銆岄瑙堛€嶆煡鐪嬭鎯匼n杈撳叆銆屽簲鐢ㄣ€嶇‘璁ゅ簲鐢? % blocks.size())

# ==================== 搴旂敤鍔熻兘 ====================

func _on_apply() -> void:
	if not code_applier:
		add_assistant_message("鈿狅笍 浠ｇ爜搴旂敤鍣ㄦ湭鍔犺浇")
		return
	
	if code_applier.pending_blocks.is_empty():
		add_assistant_message("鈿狅笍 娌℃湁寰呭簲鐢ㄧ殑浠ｇ爜")
		return
	
	add_assistant_message("鈴?姝ｅ湪搴旂敤浠ｇ爜...")
	var results = code_applier.apply_multiple_blocks(code_applier.pending_blocks)
	
	if results.size() > 0 and results[0].get("message", "") == "绛夊緟纭...":
		return
	
	var report = code_applier.generate_apply_report(results)
	add_assistant_message(report)

func _on_apply_single(index: int) -> void:
	if not code_applier:
		return
	
	var result = code_applier.apply_single_block(index)
	if result.get("success", false):
		add_assistant_message("鉁?宸插簲鐢? %s" % result.get("file_name", ""))
	else:
		add_assistant_message(result.get("message", "搴旂敤澶辫触"))

# ==================== 纭鏈哄埗 ====================

func _on_confirm() -> void:
	if not code_applier:
		return
	
	# 纭瑕嗙洊鎿嶄綔
	if not code_applier._pending_overwrite.is_empty():
		var result = code_applier.confirm_overwrite()
		if result.get("success", false):
			add_assistant_message("鉁?宸茬‘璁よ鐩?)
		else:
			add_assistant_message(result.get("message", "瑕嗙洊澶辫触"))
		return
	
	# 纭鎵归噺搴旂敤
	if not code_applier.pending_blocks.is_empty():
		var results = code_applier._apply_all_confirmed()
		var report = code_applier.generate_apply_report(results)
		add_assistant_message(report)

func _on_cancel() -> void:
	if not code_applier:
		return
	
	# 鍙栨秷瑕嗙洊
	if not code_applier._pending_overwrite.is_empty():
		code_applier.cancel_overwrite()
		add_assistant_message("鉂?宸插彇娑堣鐩栨搷浣?)
		return
	
	# 璺宠繃浠ｇ爜
	_on_skip()

func _on_skip() -> void:
	if not code_applier:
		return
	
	var count = code_applier.pending_blocks.size()
	code_applier.pending_blocks.clear()
	pending_code_blocks.clear()
	add_assistant_message("鈴笍 宸茶烦杩?%d 涓唬鐮佸潡" % count)

# ==================== 鎾ら攢/閲嶅仛 ====================

func _on_undo() -> void:
	if not code_applier:
		add_assistant_message("鈿狅笍 浠ｇ爜搴旂敤鍣ㄦ湭鍔犺浇")
		return
	
	var success = code_applier.undo()
	if success:
		add_assistant_message("鈫╋笍 宸叉挙閿€涓婁竴娆℃搷浣?)
	else:
		add_assistant_message("鈿狅笍 娌℃湁鍙挙閿€鐨勬搷浣?)

func _on_redo() -> void:
	if not code_applier:
		add_assistant_message("鈿狅笍 浠ｇ爜搴旂敤鍣ㄦ湭鍔犺浇")
		return
	
	var success = code_applier.redo()
	if success:
		add_assistant_message("鈫笍 宸查噸鍋氭搷浣?)
	else:
		add_assistant_message("鈿狅笍 娌℃湁鍙噸鍋氱殑鎿嶄綔")

func _get_history_report() -> String:
	if not code_applier:
		return "鈿狅笍 浠ｇ爜搴旂敤鍣ㄦ湭鍔犺浇"
	
	var status = code_applier.get_history_status()
	var history_list = code_applier.get_history_list(5)
	
	var report = """
馃摐 鎿嶄綔鍘嗗彶
鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹?
鈫╋笍 鍙挙閿€: %d 娆?鈫笍 鍙噸鍋? %d 娆?
鏈€杩戞搷浣?
""" % [status["undo_count"], status["redo_count"]]
	
	if history_list.is_empty():
		report += "鏆傛棤鎿嶄綔璁板綍"
	else:
		for h in history_list:
			report += "鈥?%s - %s\n" % [h["file_name"], h["timestamp"]]
	
	return report

func _on_history_updated(undo_count: int, redo_count: int) -> void:
	_update_history_label()

func _on_code_applied(file_path: String, success: bool, message: String) -> void:
	_update_history_label()

# ==================== AI浜嬩欢澶勭悊 ====================

func _on_thinking_started() -> void:
	status_icon.text = "馃"
	status_text.text = _tr("thinking")
	send_btn.disabled = true

func _on_thinking_finished(response: String) -> void:
	status_icon.text = "鉁?
	status_text.text = _tr("complete")
	send_btn.disabled = false
	
	parse_and_store_codes(response)
	add_assistant_message(response)
	
	await get_tree().create_timer(2).timeout
	_update_status()

func _on_error(error: String) -> void:
	status_icon.text = "鉂?
	status_text.text = _tr("error")
	send_btn.disabled = false
	add_assistant_message("鈿狅笍 " + error)
	await get_tree().create_timer(2).timeout
	_update_status()

func _on_code_analysis_finished(response: String, analysis_type: String) -> void:
	"""浠ｇ爜瑙ｉ噴/浼樺寲鍒嗘瀽瀹屾垚鍥炶皟"""
	status_icon.text = "鉁?
	status_text.text = _tr("complete")
	send_btn.disabled = false
	
	add_assistant_message(response)
	
	# 濡傛灉鏄紭鍖栫粨鏋滐紝璇㈤棶鏄惁搴旂敤浼樺寲鍚庣殑浠ｇ爜
	if analysis_type == "optimize":
		var hint = "\n馃挕 " + ("璇峰鍒朵笂闈㈢殑浠ｇ爜鍧楀悗杈撳叆銆? + _tr("apply") + "銆? if get_current_lang() == "zh" else "Copy the code block above and enter 銆? + _tr("apply") + "銆?)
		add_assistant_message(hint)
	
	await get_tree().create_timer(2).timeout
	_update_status()

func get_current_lang() -> String:
	if config and config.has_method("get_current_language"):
		return config.get_current_language()
	return "zh"

# ==================== 椤圭洰妯℃澘鍔熻兘 ====================

func _on_project_template() -> void:
	if not ai_handler:
		add_assistant_message("鈿狅笍 AI澶勭悊鍣ㄦ湭鍔犺浇")
		return
	
	var template_list = ai_handler.show_project_template_list()
	add_user_message("椤圭洰妯℃澘")
	add_assistant_message(template_list)
	add_assistant_message("\n馃挕 杈撳叆銆屽垱寤?銆嶆垨銆屽垱寤?2D 骞冲彴銆嶅揩閫熼€夋嫨妯℃澘")

func _on_scene_generation() -> void:
	if not ai_handler:
		add_assistant_message("鈿狅笍 AI澶勭悊鍣ㄦ湭鍔犺浇")
		return
	
	var scene_help = ai_handler.show_scene_generation_help()
	add_user_message("鍦烘櫙鐢熸垚")
	add_assistant_message(scene_help)
	add_assistant_message("\n馃挕 杈撳叆銆岀敓鎴愮畝鍗曞叧鍗°€嶆垨鎻忚堪浣犳兂瑕佺殑鍦烘櫙")

# ==================== 椤圭洰妯℃澘鍛戒护澶勭悊 ====================

func handle_create_template(text: String) -> bool:
	if not text.to_lower().begins_with("鍒涘缓"):
		return false
	
	if not ai_handler:
		return false
	
	var templates = ai_handler.get_project_templates()
	var lower = text.to_lower()
	
	# 鏁板瓧绱㈠紩鍖归厤
	var num_match = text.substr(2).strip_edges()
	if num_match.is_valid_int():
		var idx = num_match.to_int() - 1
		if idx >= 0 and idx < templates.size():
			_create_template_by_id(templates[idx]["id"], templates[idx]["name"])
			return true
	
	# 鍏抽敭瀛楀尮閰?	var keywords = {
		"2d_platformer": ["2d骞冲彴", "骞冲彴璺宠穬", "骞冲彴"],
		"3d_fps": ["fps", "绗竴浜虹О", "灏勫嚮"],
		"2d_topdown_shooter": ["淇瑙?, "淇灏勫嚮"],
		"3d_third_person": ["绗笁浜虹О", "鍔ㄤ綔"],
		"casual_puzzle": ["浼戦棽", "鐩婃櫤"],
		"rpg": ["rpg", "瑙掕壊鎵紨", "瑙掕壊"]
	}
	
	for template_id in keywords:
		for kw in keywords[template_id]:
			if lower.contains(kw):
				_create_template_by_id(template_id, "")
				return true
	
	return false

func _create_template_by_id(template_id: String, template_name: String) -> void:
	if template_name.is_empty():
		var templates = ai_handler.get_project_templates()
		for t in templates:
			if t["id"] == template_id:
				template_name = t["name"]
				break
	
	add_assistant_message("鈴?姝ｅ湪鍒涘缓銆? + template_name + "銆戞ā鏉?..")
	
	var code_gen = get_node_or_null("/root/CodeGenerator")
	if code_gen:
		var result = code_gen.generate_project_template(template_id, {"name": template_name})
		if result.get("success", false):
			var files = result.get("files", [])
			var report = "鉁?銆? + template_name + "銆戞ā鏉垮垱寤烘垚鍔燂紒\n\n"
			report += "馃搧 鐢熸垚鐨勬枃浠?\n"
			for f in files:
				report += "鈥?" + f["path"] + "\n"
			
			# 搴旂敤浠ｇ爜
			for f in files:
				code_applier.apply_code(f["content"], f["path"].get_file(), f["path"].get_base_dir() + "/")
			
			add_assistant_message(report)
		else:
			add_assistant_message("鉂?鍒涘缓澶辫触: " + result.get("message", "鏈煡閿欒"))
	else:
		add_assistant_message("鈿狅笍 浠ｇ爜鐢熸垚鍣ㄦ湭鍔犺浇")

# ==================== 鍦烘櫙鐢熸垚鍛戒护澶勭悊 ====================

func handle_scene_generation(text: String) -> bool:
	var lower = text.to_lower()
	
	if not lower.begins_with("鐢熸垚"):
		return false
	
	if not ai_handler or not code_applier:
		return false
	
	var scene_config = null
	
	# 绠€鍗曞叧鍗?	if lower.contains("绠€鍗曞叧鍗?) or lower.contains("鍩虹鍏冲崱"):
		scene_config = {
			"type": "platformer_level",
			"elements": [
				{"type": "player_spawn", "pos": Vector2(100, 400), "name": "PlayerSpawn"},
				{"type": "platform", "pos": Vector2(400, 500), "size": Vector2(600, 50), "name": "Ground"},
				{"type": "collectible", "pos": Vector2(300, 400), "name": "Coin1"},
				{"type": "collectible", "pos": Vector2(500, 400), "name": "Coin2"},
				{"type": "collectible", "pos": Vector2(650, 350), "name": "Coin3"},
				{"type": "enemy", "pos": Vector2(400, 460), "name": "Enemy1"},
				{"type": "goal", "pos": Vector2(750, 450), "name": "Goal"}
			]
		}
	
	# 鎴樻枟鍦烘櫙
	elif lower.contains("鎴樻枟") or lower.contains("arena"):
		scene_config = {
			"type": "battle_arena",
			"elements": [
				{"type": "player_spawn", "pos": Vector2(400, 300), "name": "PlayerSpawn"},
				{"type": "enemy", "pos": Vector2(200, 200), "name": "Enemy1"},
				{"type": "enemy", "pos": Vector2(600, 200), "name": "Enemy2"},
				{"type": "obstacle", "pos": Vector2(400, 400), "name": "Cover1"},
				{"type": "obstacle", "pos": Vector2(250, 450), "name": "Cover2"},
				{"type": "obstacle", "pos": Vector2(550, 450), "name": "Cover3"}
			]
		}
	
	# Boss鎴块棿
	elif lower.contains("boss"):
		scene_config = {
			"type": "boss_room",
			"elements": [
				{"type": "player_spawn", "pos": Vector2(100, 350), "name": "PlayerSpawn"},
				{"type": "spawner", "pos": Vector2(400, 300), "name": "BossSpawn"},
				{"type": "goal", "pos": Vector2(750, 350), "name": "Exit"}
			]
		}
	
	if scene_config:
		_generate_scene(scene_config)
		return true
	
	return false

func _generate_scene(config: Dictionary) -> void:
	add_assistant_message("鈴?姝ｅ湪鐢熸垚鍦烘櫙...")
	
	var code_gen = get_node_or_null("/root/CodeGenerator")
	if code_gen:
		var result = code_gen.generate_scene(config)
		if result.get("success", false):
			var scene_file = result.get("scene_file", "")
			var script_files = result.get("script_files", [])
			
			var report = "鉁?鍦烘櫙鐢熸垚鎴愬姛锛乗n\n"
			report += "馃搫 鍦烘櫙鏂囦欢: " + scene_file + "\n"
			
			if script_files.size() > 0:
				report += "\n馃摐 鍏宠仈鑴氭湰:\n"
				for f in script_files:
					report += "鈥?" + f["path"] + "\n"
			
			add_assistant_message(report)
			
			# 淇濆瓨鍦烘櫙鏂囦欢
			for f in script_files:
				code_applier.apply_code(f["content"], f["path"].get_file(), f["path"].get_base_dir() + "/")
		else:
			add_assistant_message("鉂?鍦烘櫙鐢熸垚澶辫触")
	else:
		add_assistant_message("鈿狅笍 浠ｇ爜鐢熸垚鍣ㄦ湭鍔犺浇")

# ==================== Phase 4 鍔熻兘 ====================

func _on_today_learning() -> void:
	if not daily_learning:
		add_assistant_message("鈿狅笍 姣忔棩瀛︿範妯″潡鏈姞杞?)
		return
	
	var report = daily_learning.generate_learning_report()
	add_assistant_message(report)

func _on_open_knowledge() -> void:
	if not knowledge_base:
		add_assistant_message("鈿狅笍 鐭ヨ瘑搴撴ā鍧楁湭鍔犺浇")
		return
	
	var report = knowledge_base.generate_report()
	add_assistant_message(report)
	add_assistant_message("馃挕 杈撳叆銆屾悳绱㈢煡璇?鍏抽敭璇嶃€嶆悳绱㈢煡璇嗗簱\n杈撳叆銆屾坊鍔犵煡璇?鏍囬|鍐呭銆嶆坊鍔犳潯鐩?)

func _on_capture_screenshot() -> void:
	if not screenshot_handler:
		add_assistant_message("鈿狅笍 鎴浘妯″潡鏈姞杞?)
		return
	
	var image = screenshot_handler.capture_editor_viewport()
	if image:
		add_assistant_message("馃摳 鎴浘宸叉崟鑾?\n灏哄: %dx%d" % [image.get_width(), image.get_height()])
		add_assistant_message("馃挕 鍙互灏嗘埅鍥惧彂閫佺粰AI鍒嗘瀽鍦烘櫙")
	else:
		add_assistant_message("鉂?鎴浘澶辫触")

func add_knowledge_entry(content: String) -> void:
	if not knowledge_base:
		add_assistant_message("鈿狅笍 鐭ヨ瘑搴撴ā鍧楁湭鍔犺浇")
		return
	
	var parts = content.split("|")
	if parts.size() >= 2:
		var title = parts[0].strip_edges()
		var body = parts[1].strip_edges()
		var tags = []
		if parts.size() > 2:
			tags = parts[2].strip_edges().split(",")
		
		var entry = knowledge_base.add_entry(title, body, tags)
		add_assistant_message("鉁?鐭ヨ瘑宸叉坊鍔?\n\n馃摑 %s\n%s" % [title, body])
	else:
		add_assistant_message("鈿狅笍 鏍煎紡: 娣诲姞鐭ヨ瘑:鏍囬|鍐呭|鏍囩(鍙€?")

func search_knowledge(query: String) -> void:
	if not knowledge_base:
		add_assistant_message("鈿狅笍 鐭ヨ瘑搴撴ā鍧楁湭鍔犺浇")
		return
	
	var results = knowledge_base.search(query)
	if results.is_empty():
		add_assistant_message("馃攳 娌℃湁鎵惧埌鐩稿叧鐭ヨ瘑: " + query)
	else:
		var msg = "馃攳 鎼滅储缁撴灉 (%d鏉?:\n\n" % results.size()
		for entry in results.slice(0, 5):
			msg += "馃摑 %s\n%s\n\n" % [entry["title"], entry["content"].substr(0, 100)]
		add_assistant_message(msg)

# ==================== 浠ｇ爜瑙ｆ瀽 ====================

func parse_and_store_codes(response: String) -> void:
	if not code_applier:
		return
	
	var code_blocks = code_applier.parse_code_blocks(response)
	if not code_blocks.is_empty():
		pending_code_blocks = code_blocks
		code_applier.set_pending_blocks(code_blocks)
		var hint = "\n馃搵 妫€娴嬪埌 %d 涓唬鐮佸潡\n" % code_blocks.size()
		hint += "鈥?杈撳叆銆岄瑙堛€嶆煡鐪嬭鎯匼n"
		hint += "鈥?杈撳叆銆岄瑙?1銆嶆煡鐪嬬1涓猏n"
		hint += "鈥?杈撳叆銆屽簲鐢ㄣ€嶇‘璁ゅ簲鐢╘n"
		hint += "鈥?杈撳叆銆岃烦杩囥€嶆斁寮冧唬鐮?
		add_assistant_message(hint)

func generate_template_code(template_name: String) -> void:
	var code = ""
	match template_name:
		"鐜╁":
			code = """extends CharacterBody2D
## 鐜╁瑙掕壊鎺у埗鍣?
@export var speed: float = 300.0
@export var jump_force: float = -500.0
@export var gravity: float = 980.0

func _physics_process(delta: float) -> void:
	var direction = Input.get_axis("ui_left", "ui_right")
	velocity.x = direction * speed
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_force
	velocity.y += gravity * delta
	move_and_slide()
"""
		"鏁屼汉", "鏁屼汉ai":
			code = """extends CharacterBody2D
## 鏁屼汉AI鑴氭湰

@export var speed: float = 100.0
@export var patrol_range: float = 200.0

var start_position: Vector2
var move_direction: int = 1

func _ready() -> void:
	start_position = global_position

func _physics_process(delta: float) -> void:
	velocity.x = speed * move_direction
	move_and_slide()
	if abs(global_position.x - start_position.x) > patrol_range:
		move_direction *= -1
		scale.x *= -1
"""
		"瀛愬脊":
			code = """extends Area2D
## 瀛愬脊鑴氭湰

@export var speed: float = 500.0
@export var damage: float = 10.0

func _physics_process(delta: float) -> void:
	position += transform.x * speed * delta

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemy"):
		body.take_damage(damage)
	queue_free()
"""
		_:
			add_assistant_message("鏈壘鍒版ā鏉? " + template_name)
			return
	
	var file_name = "generated_" + template_name + ".gd"
	code_applier.apply_code(code, file_name, "res://scripts/")

# ==================== 娴嬭瘯鐢熸垚鍔熻兘 ====================

func _on_generate_test() -> void:
	"""鏄剧ず娴嬭瘯鐢熸垚瀵硅瘽妗?""
	add_user_message("鐢熸垚娴嬭瘯")
	add_assistant_message("""
馃И 娴嬭瘯鐢熸垚鍔熻兘
鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹?
**浣跨敤鏂规硶:**
鈥?銆屼负 XXX.gd 鐢熸垚娴嬭瘯銆? 涓烘寚瀹氭枃浠剁敓鎴愭祴璇?鈥?銆屽啓鍗曞厓娴嬭瘯銆? 鏌ョ湅娴嬭瘯鐢熸垚閫夐」
鈥?銆屾祴璇?Player.gd銆? 蹇€熺敓鎴愭祴璇?
**鏀寔鐨勬祴璇曟鏋?**
鈥?GdUnit - Godot 鍗曞厓娴嬭瘯妗嗘灦
鈥?NUnit - Unity 鍗曞厓娴嬭瘯妗嗘灦

**娴嬭瘯鍐呭:**
鈥?鍏叡鍑芥暟娴嬭瘯
鈥?杈圭晫鏉′欢娴嬭瘯
鈥?閿欒澶勭悊娴嬭瘯
鈥?闆嗘垚娴嬭瘯

璇峰憡璇夋垜瑕佷负鍝釜鏂囦欢鐢熸垚娴嬭瘯锛?""")

func _on_generate_test_with_text(text: String) -> void:
	"""鏍规嵁鏂囨湰鐢熸垚娴嬭瘯"""
	add_user_message(text)
	
	# 鎻愬彇鐩爣鏂囦欢
	var target_file = extract_target_file(text)
	var framework = "gdunit"
	
	# 妫€娴嬫鏋?	if text.to_lower().contains("nunit") or text.to_lower().contains("unity") or text.to_lower().contains("csharp") or text.to_lower().contains("c#"):
		framework = "nunit"
	
	if target_file.is_empty():
		add_assistant_message("""
鈿狅笍 璇锋寚瀹氳鐢熸垚娴嬭瘯鐨勭洰鏍囨枃浠?
**浣跨敤鏂规硶:**
鈥?銆屼负 Player.gd 鐢熸垚娴嬭瘯銆?鈥?銆屾祴璇?res://scripts/Enemy.gd銆?鈥?銆屼负 XXX.cs 鐢熸垚 NUnit 娴嬭瘯銆?""")
		return
	
	# 妫€鏌ユ枃浠舵槸鍚﹀瓨鍦?	if not target_file.begins_with("res://"):
		target_file = "res://" + target_file
	
	if not FileAccess.file_exists(target_file):
		add_assistant_message("鈿狅笍 鏂囦欢涓嶅瓨鍦? " + target_file)
		return
	
	# 璇诲彇鐩爣鏂囦欢
	var file = FileAccess.open(target_file, FileAccess.READ)
	if not file:
		add_assistant_message("鈿狅笍 鏃犳硶璇诲彇鏂囦欢: " + target_file)
		return
	
	var target_code = file.get_as_text()
	file.close()
	
	# 鑾峰彇浠ｇ爜鐢熸垚鍣?	if not code_generator:
		add_assistant_message("鈿狅笍 浠ｇ爜鐢熸垚鍣ㄦ湭鍔犺浇")
		return
	
	# 鐢熸垚娴嬭瘯
	add_assistant_message("鈴?姝ｅ湪鍒嗘瀽浠ｇ爜骞剁敓鎴愭祴璇?..")
	var result = code_generator.generate_test_code(target_code, target_file, framework)
	
	if result.get("success", false):
		var test_code = result.get("test_code", "")
		var test_path = result.get("file_path", "")
		var test_cases = result.get("test_cases", [])
		
		# 淇濆瓨娴嬭瘯鏂囦欢
		var saved = code_generator.save_test_file(test_code, test_path)
		
		if saved:
			add_assistant_message("""
鉁?娴嬭瘯鐢熸垚瀹屾垚
鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹?
馃搧 娴嬭瘯鏂囦欢: %s
馃И 娴嬭瘯妗嗘灦: %s
馃搵 娴嬭瘯鐢ㄤ緥鏁? %d

馃挕 鐢熸垚鐨勬祴璇?
鈥?瀹炰緥鍒涘缓娴嬭瘯
鈥?鍏叡鍑芥暟娴嬭瘯
鈥?杈圭晫鏉′欢娴嬭瘯

鈿狅笍 璇锋牴鎹疄闄呴渶姹傚畬鍠勬祴璇曠敤渚嬶紒
""" % [test_path, framework, test_cases.size()])
		else:
			add_assistant_message("""
鉁?娴嬭瘯浠ｇ爜宸茬敓鎴愶紝浣嗕繚瀛樺け璐?
馃搵 娴嬭瘯浠ｇ爜:
```
%s
```
""" % test_code.substr(0, min(500, test_code.length())))
	else:
		add_assistant_message("鉂?娴嬭瘯鐢熸垚澶辫触")

func extract_target_file(text: String) -> String:
	"""浠庢枃鏈腑鎻愬彇鐩爣鏂囦欢"""
	var patterns = [
		"涓?", "娴嬭瘯 ", "涓?", "鐢熸垚娴嬭瘯 ",
		"write test for ", "test ", "generate test "
	]
	
	var lower = text.to_lower()
	
	for pattern in patterns:
		if lower.find(pattern) != -1:
			var idx = text.find(pattern) + pattern.length()
			var remaining = text.substr(idx).strip_edges()
			
			# 鎻愬彇鏂囦欢鍚嶏紙鍒扮┖鏍兼垨鍙ュ彿涓烘锛?			var end = remaining.find(" ")
			if end == -1:
				end = remaining.find("銆?)
			if end == -1:
				end = remaining.find("銆?)
			if end == -1:
				end = remaining.length()
			
			var file_name = remaining.substr(0, end).strip_edges()
			
			# 娓呯悊鏈熬鐨勬爣鐐?			while file_name.length() > 0 and (file_name[-1] == "." or file_name[-1] == "," or file_name[-1] == " "):
				file_name = file_name.substr(0, file_name.length() - 1)
			
			if not file_name.is_empty():
				return file_name
	
	return ""

# ==================== 宸紓瀵规瘮鍔熻兘 ====================

func _on_show_diff() -> void:
	"""鏄剧ず宸紓瀵规瘮闈㈡澘"""
	add_user_message("宸紓瀵规瘮")
	
	if is_showing_diff and not current_diff_info.is_empty():
		var diff_text = code_generator.format_diff_text(current_diff_info)
		add_assistant_message(diff_text)
	else:
		add_assistant_message("""
馃搳 宸紓瀵规瘮鍔熻兘
鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹?
**浣跨敤鏂规硶:**
鈥?銆屽樊寮傘€? 鏌ョ湅褰撳墠宸紓
鈥?銆宒iff銆? 鏄剧ず宸紓瀵规瘮
鈥?銆屽姣斻€? 鏌ョ湅浠ｇ爜鍙樺寲

**鎿嶄綔閫夐」:**
鈥?銆屾帴鍙椼€? 搴旂敤鎵€鏈変慨鏀?鈥?銆屾帴鍙?1銆? 鍙帴鍙楃1涓彉鏇村潡
鈥?銆屽彇娑堛€? 鏀惧純淇敼

褰撲唬鐮佽淇敼鏃朵細鑷姩鏄剧ず宸紓瀵规瘮銆?""")

func _on_show_diff_with_text(text: String) -> void:
	"""鏍规嵁鏂囨湰鏄剧ず宸紓"""
	add_user_message(text)
	
	if current_diff_info.is_empty():
		add_assistant_message("鈿狅笍 娌℃湁鍙姣旂殑宸紓\n\n璇峰厛搴旂敤浠ｇ爜淇敼锛岀郴缁熶細鑷姩璁板綍宸紓銆?)
		return
	
	var diff_text = code_generator.format_diff_text(current_diff_info)
	add_assistant_message(diff_text)

func _on_accept_diff() -> void:
	"""鎺ュ彈鎵€鏈夊樊寮?""
	add_user_message("鎺ュ彈")
	
	if current_diff_info.is_empty():
		add_assistant_message("鈿狅笍 娌℃湁鍙帴鍙楃殑宸紓")
		return
	
	var file_path = current_diff_info.get("file_path", "")
	var new_code = current_diff_info.get("new_code", "")
	var original = current_diff_info.get("original", "")
	
	var result = code_generator.apply_diff_to_file(file_path, original, new_code)
	
	if result.get("success", false):
		add_assistant_message("鉁?宸插簲鐢ㄦ墍鏈変慨鏀筡n\n馃搧 " + file_path)
		
		# 娓呴櫎宸紓鐘舵€?		current_diff_info.clear()
		current_original_code = ""
		current_new_code = ""
		diff_chunks.clear()
		is_showing_diff = false
		
		# 提示用户重新加载
		if Engine.is_editor_hint():
			add_assistant_message("💡 请按 Ctrl+R 重新加载编辑器以应用更改")
	else:
		add_assistant_message("鉂?" + result.get("message", "搴旂敤澶辫触"))

func _on_accept_diff_chunk(index: int) -> void:
	"""鎺ュ彈鍗曚釜宸紓鍧?""
	add_user_message("鎺ュ彈 " + str(index + 1))
	
	var chunks = current_diff_info.get("chunks", [])
	
	if index < 0 or index >= chunks.size():
		add_assistant_message("鈿狅笍 鏃犳晥鐨勫潡绱㈠紩: " + str(index + 1))
		return
	
	add_assistant_message("鉁?鍙樻洿鍧?#" + str(index + 1) + " 宸叉爣璁版帴鍙梊n馃挕 杈撳叆銆屾帴鍙椼€嶅簲鐢ㄦ墍鏈夊彉鏇?)

# ==================== 鏇存柊宸紓鐘舵€?====================

func set_diff_state(original: String, new_code: String, file_path: String) -> void:
	"""璁剧疆宸紓鐘舵€?""
	if code_generator:
		current_diff_info = code_generator.format_diff(original, new_code, file_path)
		current_original_code = original
		current_new_code = new_code
		diff_chunks = current_diff_info.get("chunks", [])
		is_showing_diff = true
		
		# 鑷姩鏄剧ず宸紓
		var diff_text = code_generator.format_diff_text(current_diff_info)
		add_assistant_message("馃搳 浠ｇ爜宸蹭慨鏀癸紝鏄剧ず宸紓瀵规瘮:\n\n" + diff_text)

func _update_diff_indicator() -> void:
	"""鏇存柊宸紓鎸囩ず鍣?""
	if is_showing_diff and diff_btn:
		diff_btn.text = "馃搳 瀵规瘮"
		diff_btn.modulate = Color.YELLOW
	else:
		diff_btn.text = "馃搳 瀵规瘮"
		diff_btn.modulate = Color.WHITE

# ==================== 椤圭洰鎵弿 ====================

func _on_scan_project() -> void:
	if not project_reader:
		add_assistant_message("鈿狅笍 椤圭洰璇诲彇鍣ㄦ湭鍔犺浇")
		return
	
	status_icon.text = "馃搨"
	status_text.text = "鎵弿涓?.."
	
	var summary = project_reader.generate_project_summary()
	add_user_message("鎵弿椤圭洰")
	add_assistant_message(summary)
	_update_status()

# ==================== 璋冭瘯鍔╂墜鍔熻兘 ====================

func _on_debug_assist() -> void:
	"""鍚姩璋冭瘯鍔╂墜"""
	add_user_message("璋冭瘯")
	
	var debug_msg = """馃悰 **璋冭瘯鍔╂墜宸插惎鍔?*

璇锋弿杩颁綘鐨勯棶棰橈細

1. **绮樿创閿欒鏃ュ織** - 鐩存帴绮樿创瀹屾暣鐨勯敊璇俊鎭?2. **鎻忚堪闂** - 璇存槑浠€涔堟儏鍐典笅鍑虹幇闂
3. **鏈熸湜琛屼负** - 浣犳兂瑕佷粈涔堟晥鏋?
**璋冭瘯鍛戒护**
鈥?銆岃皟璇曘€? 鍚姩璋冭瘯妯″紡
鈥?銆屾坊鍔犳柇鐐广€? 鑾峰彇鏂偣璁剧疆寤鸿
鈥?銆岀敓鎴愭棩蹇椼€? 鑾峰彇璋冭瘯鏃ュ織浠ｇ爜

馃挕 鐩存帴绮樿创閿欒淇℃伅锛孉I浼氳嚜鍔ㄥ垎鏋愶紒"""
	
	add_assistant_message(debug_msg)

# ==================== 浠ｇ爜鎼滅储鍔熻兘 ====================

func _on_code_search() -> void:
	"""鍚姩浠ｇ爜鎼滅储"""
	add_user_message("鎼滅储浠ｇ爜")
	
	if not project_reader:
		add_assistant_message("鈿狅笍 椤圭洰璇诲彇鍣ㄦ湭鍔犺浇")
		return
	
	var search_msg = """馃攳 **浠ｇ爜鎼滅储**

璇峰憡璇夋垜浣犳兂鎼滅储浠€涔堬紵

**绀轰緥**
鈥?銆屾悳绱layer銆? 鎼滅储Player鐩稿叧浠ｇ爜
鈥?銆屾悳绱㈢Щ鍔ㄣ€? 鎼滅储绉诲姩鐩稿叧浠ｇ爜
鈥?銆屾壘鎵剧鎾炴娴嬨€? 鎼滅储纰版挒妫€娴嬩唬鐮?
**鎼滅储鑼冨洿**
鈥?鍑芥暟鍚嶅拰鍙橀噺鍚?鈥?绫诲悕鍜屾敞閲?鈥?浠ｇ爜鐗囨鍜岄€昏緫

馃挕 杈撳叆鍏抽敭璇嶅嵆鍙紑濮嬫悳绱紒"""
	
	add_assistant_message(search_msg)

func show_code_search_results(query: String) -> void:
	"""鏄剧ず浠ｇ爜鎼滅储缁撴灉"""
	if not project_reader:
		return
	
	var results = project_reader.search_code(query, 10)
	
	if results.is_empty():
		add_assistant_message("馃攳 娌℃湁鎵惧埌鍖归厤銆?s銆嶇殑浠ｇ爜\n\n馃挕 寤鸿锛歕n鈥?灏濊瘯鏇寸畝鐭殑鍏抽敭璇峔n鈥?妫€鏌ユ嫾鍐欐槸鍚︽纭? % query)
		return
	
	var report = "馃攳 浠ｇ爜鎼滅储缁撴灉\n鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹佲攣鈹乗n馃搳 鎵惧埌 %d 涓尮閰嶆枃浠禱n\n" % results.size()
	
	for i in range(min(5, results.size())):
		var r = results[i]
		var file_name = r.get("relative_path", r.get("path", "?")).get_file()
		var match_count = r.get("match_count", 0)
		
		report += "馃搫 %s (鍖归厤 %d 澶?\n" % [file_name, match_count]
		
		var matches = r.get("matches", [])
		if not matches.is_empty():
			var preview = matches[0].get("preview", "")
			if not preview.is_empty():
				report += "   棰勮: %s\n" % preview.substr(0, min(60, preview.length()))
		report += "\n"
	
	if results.size() > 5:
		report += "...杩樻湁 %d 涓枃浠跺尮閰? % (results.size() - 5)
	
	add_assistant_message(report)

# ==================== UI鎿嶄綔 ====================

func add_user_message(text: String) -> void:
	var msg_container = HBoxContainer.new()
	msg_container.alignment = BoxContainer.ALIGNMENT_END
	
	var msg_label = Label.new()
	msg_label.text = "馃懁 " + text
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.custom_minimum_size.x = 300
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	msg_container.add_child(spacer)
	msg_container.add_child(msg_label)
	chat_container.add_child(msg_container)
	_scroll_to_bottom()

func add_assistant_message(text: String) -> void:
	var display_text = parse_simple_format(text)
	
	var msg_container = HBoxContainer.new()
	msg_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	
	var msg_label = RichTextLabel.new()
	msg_label.text = "[color=#50c878]馃 [/color]" + display_text
	msg_label.bbcode_enabled = true
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.custom_minimum_size.x = 300
	msg_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	msg_container.add_child(msg_label)
	chat_container.add_child(msg_container)
	_scroll_to_bottom()

func parse_simple_format(text: String) -> String:
	var result = text
	result = result.replace("```", "[code]")
	result = result.replace("**", "[b]")
	result = result.replace("*", "[i]")
	return result

func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	var scroll = $Margin/VBox/ChatScroll
	scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value

# ==================== 鎸夐挳浜嬩欢 ====================

func _on_clear() -> void:
	for i in range(chat_container.get_child_count() - 1, 0, -1):
		chat_container.get_child(i).queue_free()
	
	if ai_handler:
		ai_handler.conversation_history.clear()
	pending_code_blocks.clear()
	_selected_code = ""
	if code_applier:
		code_applier.pending_blocks.clear()
	_update_status()

func _on_config() -> void:
	var config_dialog = preload("res://addons/game_ai_assistant/ui/config_dialog.tscn").instantiate()
	get_tree().root.add_child(config_dialog)
	config_dialog.config_saved.connect(_on_config_saved)

func _on_config_saved(cfg: Dictionary) -> void:
	if ai_handler:
		ai_handler.configure(cfg)
	update_status_from_config(cfg)

func _on_templates() -> void:
	add_user_message("妯℃澘")
	if ai_handler:
		ai_handler.process_message("鏄剧ず鎵€鏈変唬鐮佹ā鏉?)

func _on_assets() -> void:
	add_user_message("绱犳潗")
	if ai_handler:
		ai_handler.process_message("甯垜鎼滅储鍏嶈垂娓告垙绱犳潗")

func _on_help() -> void:
	var lang = get_current_lang()
	var help_text_zh = """
馃悪 **甯姪淇℃伅 v1.5**

**浠ｇ爜绠＄悊**
鈥?銆岄瑙堛€? 鏌ョ湅寰呭簲鐢ㄤ唬鐮?鈥?銆岄瑙?1銆? 鏌ョ湅绗?涓唬鐮?鈥?銆屽簲鐢ㄣ€? 纭搴旂敤浠ｇ爜
鈥?銆屽簲鐢?1銆? 搴旂敤绗?涓唬鐮?鈥?銆岃烦杩囥€? 鏀惧純寰呭簲鐢ㄤ唬鐮?鈥?銆岀‘璁ゃ€? 纭瑕嗙洊鎿嶄綔
鈥?銆屽彇娑堛€? 鍙栨秷褰撳墠鎿嶄綔

**鎾ら攢/閲嶅仛**
鈥?銆屾挙閿€銆? 鎾ら攢涓婁竴娆℃搷浣?鈥?銆岄噸鍋氥€? 鎭㈠鎾ら攢鐨勬搷浣?鈥?銆屽巻鍙层€? 鏌ョ湅鎿嶄綔鍘嗗彶

**馃悰 璋冭瘯鍔╂墜**
鈥?銆岃皟璇曘€? 鍚姩璋冭瘯鍔╂墜
鈥?銆屾坊鍔犳柇鐐广€? 鑾峰彇鏂偣璁剧疆寤鸿
鈥?銆岀敓鎴愭棩蹇椼€? 鑾峰彇璋冭瘯鏃ュ織浠ｇ爜

**馃敡 浠ｇ爜瑙ｉ噴涓庝紭鍖?*
鈥?銆岃В閲婁唬鐮併€? 閫変腑浠ｇ爜鍚庤緭鍏ワ紝鍒嗘瀽浠ｇ爜鍔熻兘
鈥?銆屼紭鍖栦唬鐮併€? 閫変腑浠ｇ爜鍚庤緭鍏ワ紝鎻愪緵浼樺寲寤鸿

**馃攳 浠ｇ爜鎼滅储**
鈥?銆屾悳绱唬鐮?鍏抽敭璇嶃€? 鍦ㄩ」鐩腑鎼滅储浠ｇ爜
鈥?銆屾壘鎵綳XX銆? 鎼滅储鐩稿叧浠ｇ爜

**鍏朵粬鍔熻兘**
鈥?銆屾壂鎻忛」鐩€? 鏌ョ湅椤圭洰缁撴瀯
鈥?銆屼粖鏃ュ涔犮€? 鑾峰彇瀛︿範鎶€宸?鈥?銆岀煡璇嗗簱銆? 鎵撳紑鐭ヨ瘑搴?鈥?銆屾埅鍥俱€? 鎴彇鍦烘櫙鍥?
**蹇嵎鎸夐挳**
鈥?馃搵 棰勮 - 鏌ョ湅浠ｇ爜棰勮
鈥?馃搨 搴旂敤 - 纭搴旂敤浠ｇ爜
鈥?馃悰 璋冭瘯 - 璋冭瘯鍔╂墜
鈥?馃攳 鎼滅储 - 浠ｇ爜鎼滅储
鈥?鈫╋笍 鎾ら攢 / 鈫笍 閲嶅仛 - 鎿嶄綔鍘嗗彶
鈥?馃摎 瀛︿範 - 浠婃棩瀛︿範
鈥?馃摉 鐭ヨ瘑 - 鐭ヨ瘑搴?"""
	var help_text_en = """
馃悪 **Help v1.5**

**Code Management**
鈥?銆宲review銆? View pending code
鈥?銆宲review 1銆? View first code block
鈥?銆宎pply銆? Confirm and apply code
鈥?銆宎pply 1銆? Apply first code block
鈥?銆宻kip銆? Skip pending code
鈥?銆宑onfirm銆? Confirm overwrite
鈥?銆宑ancel銆? Cancel current operation

**Undo/Redo**
鈥?銆寀ndo銆? Undo last operation
鈥?銆宺edo銆? Redo operation
鈥?銆宧istory銆? View operation history

**馃悰 Debug Assistant**
鈥?銆宒ebug銆? Start debug mode
鈥?銆宎dd breakpoint銆? Breakpoint suggestions
鈥?銆実enerate log銆? Debug log code

**馃敡 Code Explain & Optimize**
鈥?銆宔xplain code銆? Analyze selected code
鈥?銆宱ptimize code銆? Optimize selected code

**馃攳 Code Search**
鈥?銆宻earch:keyword銆? Search project code
鈥?銆宖ind XXX銆? Search related code

**Other Features**
鈥?銆宻can project銆? View project structure
鈥?銆宒aily learning銆? Learning tips
鈥?銆宬nowledge base銆? Open knowledge base
鈥?銆宻creenshot銆? Capture scene

**Quick Buttons**
鈥?馃搵 Preview - Preview code
鈥?馃搨 Apply - Apply code
鈥?馃悰 Debug - Debug assistant
鈥?馃攳 Search - Code search
鈥?鈫╋笍 Undo / 鈫笍 Redo - History
鈥?馃摎 Learn - Daily learning
鈥?馃摉 Knowledge - Knowledge base
"""
	add_user_message(_tr("help"))
	add_assistant_message(help_text_zh if lang == "zh" else help_text_en)

func execute_quick_command(command: String) -> void:
	add_user_message(command)
	
	var special_response = check_special_command(command)
	if special_response:
		add_assistant_message(special_response)
	elif ai_handler:
		ai_handler.process_message(command)

