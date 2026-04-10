extends Node

# 代码生成器
# 根据AI响应生成游戏代码

signal code_generated(code: String, language: String)
signal code_applied(success: bool, message: String)

var current_project_path: String = ""

# 支持的语言
enum Language {
	GDSCRIPT,
	C_SHARP,
	CSHARP = C_SHARP
}

func _init() -> void:
	pass

# 解析AI响应中的代码
func parse_code_response(response: String) -> Dictionary:
	var result = {
		"has_code": false,
		"code": "",
		"language": "gdscript",
		"description": response
	}
	
	# 查找代码块
	var code_start = response.find("```")
	if code_start == -1:
		return result
	
	# 提取语言标识
	var lang_start = code_start + 3
	var lang_end = response.find("\n", lang_start)
	if lang_end == -1:
		return result
	
	var language = response.substr(lang_start, lang_end - lang_start).strip_edges().to_lower()
	
	# 确定语言
	match language:
		"gdscript", "gd", "godot":
			result["language"] = "gdscript"
		"csharp", "cs", "c#":
			result["language"] = "csharp"
		"python", "py":
			result["language"] = "python"
		"javascript", "js":
			result["language"] = "javascript"
		_:
			result["language"] = "gdscript"  # 默认GDScript
	
	# 提取代码内容
	var code_content_start = response.find("\n", lang_end) + 1
	var code_end = response.find("```", code_content_start)
	if code_end == -1:
		code_end = response.length()
	
	result["code"] = response.substr(code_content_start, code_end - code_content_start).strip_edges()
	result["has_code"] = not result["code"].is_empty()
	
	# 提取描述（代码前后的文字）
	var desc_start = 0
	var desc_end = code_start
	result["description"] = response.substr(desc_start, desc_end).strip_edges()
	
	return result

# 应用代码到项目
func apply_code(code_info: Dictionary) -> void:
	var code = code_info.get("code", "")
	var language = code_info.get("language", "gdscript")
	var file_name = code_info.get("file_name", "")
	
	if code.is_empty():
		code_applied.emit(false, "代码为空")
		return
	
	# 确定文件名
	if file_name.is_empty():
		file_name = generate_file_name(code, language)
	
	# 保存文件
	var save_path = "res://" + file_name
	
	# 如果文件已存在，备份
	if FileAccess.file_exists(save_path):
		backup_file(save_path)
	
	# 写入文件
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(code)
		file.close()
		code_applied.emit(true, "已保存到: " + save_path)
	else:
		code_applied.emit(false, "无法创建文件: " + save_path)

func generate_file_name(code: String, language: String) -> String:
	var ext = "gd"
	match language:
		"csharp":
			ext = "cs"
		"python":
			ext = "py"
		"javascript":
			ext = "js"
	
	# 尝试从代码中提取类名
	var extracted_class = extract_class_name(code, language)
	if not extracted_class.is_empty():
		return extracted_class + "." + ext
	
	# 默认文件名
	return "generated_script." + ext

func extract_class_name(code: String, language: String) -> String:
	match language:
		"gdscript":
			# 查找 "class_name Xxx" 或 "class Xxx"
			var patterns = ["class_name ", "class "]
			for pattern in patterns:
				var idx = code.find(pattern)
				if idx != -1:
					idx += pattern.length()
					var end = code.find(" ", idx)
					if end == -1:
						end = code.find("\n", idx)
					if end == -1:
						end = code.length()
					return code.substr(idx, end - idx).strip_edges()
		"csharp":
			# 查找 "public class Xxx"
			var idx = code.find("class ")
			if idx != -1:
				idx += 6
				var end = code.find(" ", idx)
				if end == -1:
					end = code.length()
				return code.substr(idx, end - idx).strip_edges()
	
	return ""

func backup_file(path: String) -> void:
	if FileAccess.file_exists(path):
		var backup_path = path + ".backup"
		var src_file = FileAccess.open(path, FileAccess.READ)
		var dst_file = FileAccess.open(backup_path, FileAccess.WRITE)
		
		if src_file and dst_file:
			dst_file.store_string(src_file.get_as_text())
			src_file.close()
			dst_file.close()

# ==================== 测试生成功能 ====================

signal test_generated(test_code: String, file_path: String, framework: String)

const TEST_FRAMEWORKS = {
	"gdunit": {
		"name": "GdUnit",
		"extension": "gd",
		"test_dir": "res://tests/",
		"template": "gdunit"
	},
	"nunit": {
		"name": "NUnit",
		"extension": "cs",
		"test_dir": "Assets/Tests/",
		"template": "nunit"
	}
}

func generate_test_code(target_code: String, target_file: String = "", framework: String = "gdunit") -> Dictionary:
	"""生成测试代码
	
	Args:
		target_code: 目标代码
		target_file: 目标文件路径
		framework: 测试框架
	
	Returns:
		Dictionary with test_code, file_path, and metadata
	"""
	var result = {
		"success": false,
		"test_code": "",
		"file_path": "",
		"framework": framework,
		"test_cases": []
	}
	
	# 确定测试框架
	var fw = TEST_FRAMEWORKS.get(framework, TEST_FRAMEWORKS["gdunit"])
	
	# 生成测试文件路径
	var file_name = generate_test_file_name(target_file, fw["extension"])
	var test_dir = fw["test_dir"]
	var test_path = test_dir + file_name
	
	result["file_path"] = test_path
	
	# 根据框架生成测试代码
	match framework:
		"gdunit":
			result["test_code"] = _generate_gdunit_test(target_code, target_file)
		"nunit":
			result["test_code"] = _generate_nunit_test(target_code, target_file)
		_:
			result["test_code"] = _generate_gdunit_test(target_code, target_file)
	
	result["success"] = true
	
	# 提取测试用例信息
	result["test_cases"] = _extract_test_cases(result["test_code"], framework)
	
	test_generated.emit(result["test_code"], test_path, framework)
	
	return result

func generate_test_file_name(target_file: String, extension: String) -> String:
	"""生成测试文件名"""
	var base_name = "Test_"
	
	if not target_file.is_empty():
		# 从目标文件提取类名
		var extracted_class = extract_class_name_from_path(target_file)
		if not extracted_class.is_empty():
			base_name += extracted_class + "_"
		else:
			# 使用文件名
			var file_name = target_file.get_file()
			if file_name.get_extension() == extension:
				file_name = file_name.trim_suffix("." + extension)
			base_name += file_name + "_"
	
	# 添加时间戳
	var timestamp = Time.get_datetime_string_from_system()
	timestamp = timestamp.replace(":", "-").replace("T", "_")
	base_name += timestamp
	
	return base_name + "." + extension

func extract_class_name_from_path(file_path: String) -> String:
	"""从文件路径提取类名"""
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return ""
	
	var content = file.get_as_text()
	file.close()
	
	# 查找 class_name 或 class
	var patterns = ["class_name ", "class "]
	for pattern in patterns:
		var idx = content.find(pattern)
		if idx != -1:
			idx += pattern.length()
			var end = content.find(" ", idx)
			if end == -1:
				end = content.find("\n", idx)
			if end == -1:
				end = content.length()
			return content.substr(idx, end - idx).strip_edges()
	
	return ""

func _generate_gdunit_test(target_code: String, target_file: String) -> String:
	"""生成 GdUnit 测试代码"""
	var extracted_class = extract_class_name(target_code, "gdscript")
	var test_cases = _analyze_functions(target_code, "gdscript")
	
	var test_template = """
extends GdUnitTestSuite
## %s 的单元测试

const TARGET_CLASS = "%s"

func test_%s_creation():
	# 测试实例创建
	var instance = auto_free(TARGET_CLASS.new())
	assert_that(instance).is_not_null()

"""
	
	var output = """extends GdUnitTestSuite
## {class_name} 的单元测试
## 生成时间: {timestamp}

# 导入目标类
const TARGET_CLASS = "{class_class}"

func set_up():
	# 每个测试前调用
	pass

func tear_down():
	# 每个测试后调用
	pass

""".format({
		"class_name": extracted_class,
		"timestamp": Time.get_datetime_string_from_system(),
		"class_class": extracted_class
	})
	
	# 为每个公共方法生成测试
	for func_info in test_cases:
		output += _generate_gdunit_function_test(func_info)
	
	return output.strip_edges()

func _generate_gdunit_function_test(func_info: Dictionary) -> String:
	"""生成单个函数的测试"""
	var func_name = func_info.get("name", "")
	var params = func_info.get("params", [])
	var return_type = func_info.get("return_type", "")
	
	var test_code = """
func test_{func_name}():
	# 测试 {func_name} 函数
	# 返回类型: {return_type}
	# 参数: {params_str}
	
	var instance = auto_free(TARGET_CLASS.new())
	# TODO: 根据函数功能编写具体测试
	
	# 示例测试
	# var result = instance.{func_name}({param_defaults})
	# assert_that(result).is_not_null()
	pass

""".format({
		"func_name": func_name,
		"return_type": return_type if not return_type.is_empty() else "void",
		"params_str": ", ".join(params) if params.size() > 0 else "无",
		"param_defaults": ", ".join(Array(params).map(func(p: String) -> String: return "null"))
	})
	
	return test_code

func _generate_nunit_test(target_code: String, target_file: String) -> String:
	"""生成 NUnit 测试代码"""
	var extracted_class = extract_class_name(target_code, "csharp")
	var test_cases = _analyze_functions(target_code, "csharp")
	var namespace = _extract_namespace(target_code)
	
	var output = """using NUnit.Framework;
using UnityEngine;
using System.Collections;

namespace {namespace}
{{
    /// <summary>
    /// {class_name} 的单元测试
    /// 生成时间: {timestamp}
    /// </summary>
    [TestFixture]
    public class {class_name}Test
    {{
        private {class_name} _instance;

        [SetUp]
        public void SetUp()
        {{
            // 每个测试前创建实例
            _instance = new GameObject().AddComponent<{class_name}>();
        }}

        [TearDown]
        public void TearDown()
        {{
            // 每个测试后清理
            if (_instance != null)
            {{
                Object.DestroyImmediate(_instance.gameObject);
            }}
        }}

""".format({
		"namespace": namespace if not namespace.is_empty() else "GameAIAssistant.Tests",
		"class_name": extracted_class,
		"timestamp": Time.get_datetime_string_from_system()
	})
	
	# 为每个公共方法生成测试
	for func_info in test_cases:
		output += _generate_nunit_function_test(func_info)
	
	output += """    }
}
"""
	
	return output.strip_edges()

func _generate_nunit_function_test(func_info: Dictionary) -> String:
	"""生成单个函数的测试"""
	var func_name = func_info.get("name", "")
	var params = func_info.get("params", [])
	var return_type = func_info.get("return_type", "")
	
	var test_code = """
        [Test]
        public void {func_name}_Test()
        {{
            // 测试 {func_name}
            // 返回类型: {return_type}
            // 参数: {params_str}
            
            // TODO: 根据函数功能编写具体测试
            
            // 示例:
            // var result = _instance.{func_name}({param_defaults});
            // Assert.IsNotNull(result);
        }}
""".format({
		"func_name": func_name,
		"return_type": return_type if not return_type.is_empty() else "void",
		"params_str": ", ".join(params) if params.size() > 0 else "无",
		"param_defaults": ", ".join(Array(params).map(func(p: String) -> String: return "default"))
	})
	
	return test_code

func _analyze_functions(code: String, language: String) -> Array:
	"""分析代码中的函数"""
	var functions: Array = []
	
	match language:
		"gdscript":
			functions = _analyze_gdscript_functions(code)
		"csharp":
			functions = _analyze_csharp_functions(code)
	
	return functions

func _analyze_gdscript_functions(code: String) -> Array:
	"""分析 GDScript 函数"""
	var functions: Array = []
	var lines = code.split("\n")
	var i = 0
	
	while i < lines.size():
		var line = lines[i].strip_edges()
		
		# 查找 func 定义
		if line.begins_with("func "):
			var func_info = {"name": "", "params": [], "return_type": ""}
			
			# 提取函数名
			var func_start = 5
			var func_end = line.find("(")
			if func_end == -1:
				func_end = line.find(":")
			if func_end == -1:
				func_end = line.length()
			
			func_info["name"] = line.substr(func_start, func_end - func_start).strip_edges()
			
			# 提取参数
			if line.find("(") != -1 and line.find(")") != -1:
				var params_start = line.find("(") + 1
				var params_end = line.find(")")
				var params_str = line.substr(params_start, params_end - params_start)
				if not params_str.is_empty():
					var params = params_str.split(",")
					for p in params:
						var param_name = p.strip_edges().split(":")[0].strip_edges()
						if not param_name.is_empty() and not param_name.begins_with("_"):
							func_info["params"].append(param_name)
			
			# 查找返回类型（向后看几行）
			for j in range(i + 1, min(i + 5, lines.size())):
				var next_line = lines[j].strip_edges()
				if next_line.begins_with("->"):
					func_info["return_type"] = next_line.substr(2).strip_edges()
					break
				if next_line.begins_with("var ") or next_line.begins_with("@export"):
					break
			
			if not func_info["name"].is_empty() and not func_info["name"].begins_with("_"):
				functions.append(func_info)
		
		i += 1
	
	return functions

func _analyze_csharp_functions(code: String) -> Array:
	"""分析 C# 函数"""
	var functions: Array = []
	var lines = code.split("\n")
	var i = 0
	
	while i < lines.size():
		var line = lines[i].strip_edges()
		
		# 查找 public/private 方法
		if (line.begins_with("public ") or line.begins_with("private ") or line.begins_with("protected ")) and \
		   (line.find("(") != -1):
			
			# 跳过字段
			if line.find("=") != -1 and line.find("(") > line.find("="):
				i += 1
				continue
			
			var func_info = {"name": "", "params": [], "return_type": ""}
			
			# 提取返回类型
			var parts = line.split(" ")
			if parts.size() >= 2:
				func_info["return_type"] = parts[1]
				
				# 提取方法名
				var name_start = 2
				if parts[1] == "async":
					func_info["return_type"] = "Task"
					name_start = 3
				
				if name_start < parts.size():
					var func_name = parts[name_start]
					func_name = func_name.replace("(", "").strip_edges()
					func_info["name"] = func_name
			
			# 提取参数
			var params_start = line.find("(")
			var params_end = line.find(")")
			if params_start != -1 and params_end != -1:
				var params_str = line.substr(params_start + 1, params_end - params_start - 1)
				if not params_str.is_empty():
					var params = params_str.split(",")
					for p in params:
						var param_parts = p.strip_edges().split(" ")
						if param_parts.size() >= 2:
							func_info["params"].append(param_parts[1])
			
			if not func_info["name"].is_empty() and \
			   not func_info["name"].begins_with("_") and \
			   not func_info["name"].begins_with("get_") and \
			   not func_info["name"].begins_with("set_"):
				functions.append(func_info)
		
		i += 1
	
	return functions

func _extract_namespace(code: String) -> String:
	"""提取 C# 命名空间"""
	var lines = code.split("\n")
	for line in lines:
		line = line.strip_edges()
		if line.begins_with("namespace "):
			return line.substr(9).strip_edges().replace("{", "")
	return ""

func _extract_test_cases(test_code: String, framework: String) -> Array:
	"""提取测试用例列表"""
	var cases: Array = []
	var lines = test_code.split("\n")
	
	for line in lines:
		line = line.strip_edges()
		match framework:
			"gdunit":
				if line.begins_with("func test_"):
					var func_name = line.substr(10).replace("():", "").strip_edges()
					cases.append({"name": func_name, "type": "test"})
			"nunit":
				if line.begins_with("public void test_") or line.begins_with("[Test]"):
					pass  # NUnit测试用例提取
	
	return cases

func save_test_file(test_code: String, file_path: String) -> bool:
	"""保存测试文件"""
	# 确保目录存在
	var dir = file_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(test_code)
		file.close()
		return true
	return false

# ==================== 差异对比功能 ====================

func format_diff(original: String, new_code: String, file_path: String = "") -> Dictionary:
	"""格式化代码差异
	
	Args:
		original: 原始代码
		new_code: 新代码
		file_path: 文件路径
	
	Returns:
		Dictionary with diff info
	"""
	var result = {
		"success": false,
		"original": original,
		"new_code": new_code,
		"file_path": file_path,
		"chunks": [],
		"summary": {
			"additions": 0,
			"deletions": 0,
			"unchanged": 0
		}
	}
	
	var old_lines = original.split("\n")
	var new_lines = new_code.split("\n")
	
	var additions: Array = []
	var deletions: Array = []
	var unchanged: Array = []
	var current_chunk: Dictionary = {"type": "unchanged", "lines": []}
	var chunks: Array = []
	
	# 逐行对比
	for i in range(max(old_lines.size(), new_lines.size())):
		var old_line = old_lines[i] if i < old_lines.size() else null
		var new_line = new_lines[i] if i < new_lines.size() else null
		
		if old_line == new_line:
			# 相等行
			if current_chunk.get("type") != "unchanged" and current_chunk.get("lines").size() > 0:
				chunks.append(current_chunk)
				current_chunk = {"type": "unchanged", "lines": []}
			
			if old_line != null:
				unchanged.append({"line": i + 1, "text": old_line})
				current_chunk["lines"].append({"type": " ", "text": old_line, "line": i + 1})
		else:
			# 变化行
			if current_chunk.get("type") == "unchanged" and current_chunk.get("lines").size() > 0:
				chunks.append(current_chunk)
				current_chunk = {"type": "changed", "added": [], "removed": [], "start_line": i + 1}
			
			if current_chunk.get("type") == "unchanged":
				current_chunk = {"type": "changed", "added": [], "removed": [], "start_line": i + 1}
			
			if old_line != null:
				deletions.append({"line": i + 1, "text": old_line})
				current_chunk["removed"].append({"line": i + 1, "text": old_line})
			if new_line != null:
				additions.append({"line": i + 1, "text": new_line})
				current_chunk["added"].append({"line": i + 1, "text": new_line})
	
	# 添加最后一个块
	if current_chunk.get("lines").size() > 0 or current_chunk.get("added").size() > 0:
		chunks.append(current_chunk)
	
	result["chunks"] = chunks
	result["summary"] = {
		"additions": additions.size(),
		"deletions": deletions.size(),
		"unchanged": unchanged.size(),
		"total_changes": additions.size() + deletions.size()
	}
	result["success"] = true
	
	return result

func format_diff_text(diff_info: Dictionary) -> String:
	"""将diff信息格式化为文本"""
	var output: Array = []
	
	if not diff_info.get("file_path", "").is_empty():
		output.append("📄 文件: " + diff_info["file_path"])
	
	var summary = diff_info.get("summary", {})
	output.append("━".repeat(40))
	output.append("📊 差异统计:")
	output.append("   ➕ 新增: " + str(summary.get("additions", 0)) + " 行")
	output.append("   ➖ 删除: " + str(summary.get("deletions", 0)) + " 行")
	output.append("   📝 未变: " + str(summary.get("unchanged", 0)) + " 行")
	
	var chunks = diff_info.get("chunks", [])
	if chunks.size() > 0:
		output.append("\n" + "━".repeat(40))
		output.append("📝 详细变更:")
		output.append("━".repeat(40))
		
		var chunk_num = 1
		for chunk in chunks:
			if chunk.get("type") == "changed":
				var removed = chunk.get("removed", [])
				var added = chunk.get("added", [])
				
				if removed.size() > 0 or added.size() > 0:
					output.append("\n变更块 #" + str(chunk_num) + ":")
					
					for item in removed:
						output.append("-" + item.get("text", ""))
					
					for item in added:
						output.append("+" + item.get("text", ""))
					
					chunk_num += 1
	
	output.append("\n" + "━".repeat(40))
	output.append("\n💡 操作选项:")
	output.append("• 「接受」或「确认」- 应用此修改")
	output.append("• 「接受 1」- 只接受第1个变更块")
	output.append("• 「取消」- 放弃此修改")
	
	return "\n".join(output)

func apply_diff_to_file(file_path: String, original: String, new_code: String, chunk_indices: Array = []) -> Dictionary:
	"""应用diff到文件
	
	Args:
		file_path: 文件路径
		original: 原始代码
		new_code: 新代码
		chunk_indices: 要应用的块索引（空=全部）
	
	Returns:
		结果信息
	"""
	var result = {
		"success": false,
		"message": "",
		"applied_chunks": 0
	}
	
	# 读取当前文件内容
	if not FileAccess.file_exists(file_path):
		result["message"] = "文件不存在: " + file_path
		return result
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		result["message"] = "无法打开文件: " + file_path
		return result
	
	var current_content = file.get_as_text()
	file.close()
	
	# 简单替换策略：如果有变更，直接替换整个文件
	# 实际应用中应该更精确地处理
	if chunk_indices.is_empty():
		# 应用所有变更
		var output_file = FileAccess.open(file_path, FileAccess.WRITE)
		if output_file:
			output_file.store_string(new_code)
			output_file.close()
			result["success"] = true
			result["message"] = "已应用所有修改"
			result["applied_chunks"] = -1  # -1 表示全部
		else:
			result["message"] = "无法写入文件: " + file_path
	else:
		# 只应用指定的块
		result["message"] = "部分应用暂不支持，请使用「接受」应用全部修改"
	
	return result

# 创建节点并挂载脚本
func create_node_with_script(parent_path: String, node_name: String, script_path: String) -> bool:
	# 这个需要在编辑器上下文中执行
	# 简化版本：返回指令
	return true

# 生成特定类型的代码模板
func generate_template(template_type: String) -> String:
	var templates = {
		"player": '''extends CharacterBody2D
## 玩家角色脚本

@export var speed: float = 300.0
@export var jump_force: float = -500.0

@export var gravity: float = 980.0

func _physics_process(delta: float) -> void:
	# 水平移动
	var direction = Input.get_axis("ui_left", "ui_right")
	velocity.x = direction * speed
	
	# 跳跃
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_force
	
	# 重力
	velocity.y += gravity * delta
	
	move_and_slide()
''',
		"enemy": '''extends CharacterBody2D
## 敌人AI脚本

@export var speed: float = 100.0
@export var patrol_range: float = 200.0

var start_position: Vector2
var move_direction: int = 1

func _ready() -> void:
	start_position = global_position

func _physics_process(delta: float) -> void:
	# 巡逻移动
	velocity.x = speed * move_direction
	move_and_slide()
	
	# 超出巡逻范围则反转方向
	if abs(global_position.x - start_position.x) > patrol_range:
		move_direction *= -1
		scale.x *= -1
''',
		"collectible": '''extends Area2D
## 可收集物品脚本

@export var item_type: String = "coin"
@export var value: int = 10

signal collected(item_type: String, value: int)

func _ready() -> void:
	connect("body_entered", _on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		emit_signal("collected", item_type, value)
		queue_free()
''',
		"platform": '''extends StaticBody2D
## 平台脚本

@export var moving: bool = false
@export var move_speed: float = 100.0
@export var move_distance: float = 100.0

var start_position: Vector2
var move_direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	start_position = global_position

func _physics_process(delta: float) -> void:
	if moving:
		position += move_direction * move_speed * delta
		if abs(position.x - start_position.x) > move_distance:
			move_direction.x *= -1
'''
	}
	
	return templates.get(template_type, "# 未找到模板: " + template_type)

# ==================== 项目模板生成 ====================

func generate_project_template(template_id: String, template_info: Dictionary) -> Dictionary:
	var result = {
		"success": true,
		"files": [],
		"scenes": [],
		"message": ""
	}
	
	match template_id:
		"2d_platformer":
			result = _generate_2d_platformer_template(template_info)
		"3d_fps":
			result = _generate_3d_fps_template(template_info)
		"2d_topdown_shooter":
			result = _generate_2d_topdown_shooter_template(template_info)
		"3d_third_person":
			result = _generate_3d_third_person_template(template_info)
		"casual_puzzle":
			result = _generate_casual_puzzle_template(template_info)
		"rpg":
			result = _generate_rpg_template(template_info)
		_:
			result["success"] = false
			result["message"] = "不支持的模板类型"
	
	return result

func _generate_2d_platformer_template(info: Dictionary) -> Dictionary:
	var files = []
	
	# 主场景
	var scene_content = _generate_tscn_header("res://scenes/Main.tscn", "Node2D")
	files.append({"path": "res://scenes/Main.tscn", "content": scene_content})
	
	# 玩家脚本
	files.append({
		"path": "res://scripts/player/PlayerController.gd",
		"content": '''extends CharacterBody2D
## 2D平台跳跃玩家控制器

@export var speed: float = 300.0
@export var jump_force: float = -500.0
@export var gravity: float = 980.0

@export var max_jumps: int = 2
var jump_count: int = 0

# 动画
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var dust_particles: GPUParticles2D = $DustParticles

func _physics_process(delta: float) -> void:
	# 重力
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		jump_count = 0
	
	# 水平移动
	var direction = Input.get_axis("ui_left", "ui_right")
	velocity.x = direction * speed
	
	# 跳跃
	if Input.is_action_just_pressed("ui_accept"):
		if is_on_floor() or jump_count < max_jumps:
			velocity.y = jump_force
			jump_count += 1
			_spawn_dust()
	
	# 动画更新
	_update_animation(direction)
	
	move_and_slide()

func _update_animation(direction: float) -> void:
	if anim:
		if direction != 0:
			anim.play("walk")
			anim.flip_h = direction < 0
		else:
			anim.play("idle")
	
	if direction != 0:
		scale.x = direction

func _spawn_dust() -> void:
	if dust_particles:
		dust_particles.emitting = true

func take_damage(amount: float) -> void:
	# 受伤闪烁效果
	modulate = Color(1, 0.5, 0.5)
	await get_tree().create_timer(0.2).timeout
	modulate = Color.WHITE
'''
	})
	
	# 敌人脚本
	files.append({
		"path": "res://scripts/enemy/PatrolEnemy.gd",
		"content": '''extends CharacterBody2D
## 巡逻敌人AI

@export var speed: float = 80.0
@export var patrol_distance: float = 200.0
@export var health: float = 100.0
@export var damage: float = 20.0

var start_position: Vector2
var move_direction: int = 1
var player_in_range: bool = false

@onready var detection_range: Area2D = $DetectionRange
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

signal died()

func _ready() -> void:
	start_position = global_position
	detection_range.body_entered.connect(_on_player_entered)
	detection_range.body_exited.connect(_on_player_exited)

func _physics_process(delta: float) -> void:
	if player_in_range:
		_chase_player()
	else:
		_patrol()
	
	_update_animation()
	move_and_slide()

func _patrol() -> void:
	velocity.x = speed * move_direction
	if abs(global_position.x - start_position.x) > patrol_distance:
		move_direction *= -1

func _chase_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var direction = sign(player.global_position.x - global_position.x)
		velocity.x = speed * 1.5 * direction
		move_direction = direction

func _update_animation() -> void:
	if anim:
		anim.flip_h = velocity.x < 0
		anim.play("walk" if abs(velocity.x) > 0 else "idle")

func _on_player_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true

func _on_player_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false

func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0:
		died.emit()
		queue_free()
'''
	})
	
	# 收集物脚本
	files.append({
		"path": "res://scripts/items/Collectible.gd",
		"content": '''extends Area2D
## 可收集物品脚本

@export var item_type: String = "coin"
@export var value: int = 10
@export var spin_speed: float = 2.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

signal collected(type: String, value: int)

func _process(delta: float) -> void:
	# 旋转动画
	if sprite:
		sprite.rotation += spin_speed * delta

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		emit_signal("collected", item_type, value)
		_create_collect_effect()
		queue_free()

func _create_collect_effect() -> void:
	# 收集特效（可扩展为粒子效果）
	modulate.a = 0
'''
	})
	
	# 游戏管理器
	files.append({
		"path": "res://scripts/game/GameManager.gd",
		"content": '''extends Node
## 游戏管理器

var score: int = 0
var lives: int = 3
var current_level: int = 1
var is_paused: bool = false

signal score_changed(new_score: int)
signal lives_changed(new_lives: int)
signal game_over()
signal level_completed()

func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)

func lose_life() -> void:
	lives -= 1
	lives_changed.emit(lives)
	if lives <= 0:
		game_over.emit()

func next_level() -> void:
	current_level += 1
	level_completed.emit()

func pause_game() -> void:
	is_paused = true
	get_tree().paused = true

func resume_game() -> void:
	is_paused = false
	get_tree().paused = false

func reset_game() -> void:
	score = 0
	lives = 3
	current_level = 1
	is_paused = false
'''
	})
	
	# UI脚本
	files.append({
		"path": "res://scripts/ui/GameUI.gd",
		"content": '''extends CanvasLayer

@onready var score_label: Label = $VBox/ScoreLabel
@onready var lives_label: Label = $VBox/LivesLabel
@onready var game_over_screen: Control = $GameOverScreen
@onready var level_complete_screen: Control = $LevelCompleteScreen

func _ready() -> void:
	game_over_screen.visible = false
	level_complete_screen.visible = false
	
	# 连接信号
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.score_changed.connect(_on_score_changed)
		game_manager.lives_changed.connect(_on_lives_changed)
		game_manager.game_over.connect(_on_game_over)
		game_manager.level_completed.connect(_on_level_completed)

func _on_score_changed(score: int) -> void:
	score_label.text = "分数: %d" % score

func _on_lives_changed(lives: int) -> void:
	lives_label.text = "生命: %s" % "❤️".repeat(lives)

func _on_game_over() -> void:
	game_over_screen.visible = true

func _on_level_completed() -> void:
	level_complete_screen.visible = true
'''
	})
	
	return {
		"success": true,
		"files": files,
		"message": "2D平台跳跃模板已生成，包含 %d 个文件" % files.size()
	}

func _generate_3d_fps_template(info: Dictionary) -> Dictionary:
	var files = []
	
	# FPS控制器
	files.append({
		"path": "res://scripts/player/FPSController.gd",
		"content": '''extends CharacterBody3D
## 3D FPS控制器

@export var move_speed: float = 5.0
@export var jump_force: float = 5.0
@export var mouse_sensitivity: float = 0.3

@onready var camera: Camera3D = $Camera3D
@onready var weapon_anchor: Node3D = $WeaponAnchor

var gravity: float = 9.8
var is_grounded: bool = true

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_rotation_camera(event.relative)

func _physics_process(delta: float) -> void:
	_movement(delta)
	_weapon_bobbing(delta)

func _rotation_camera(motion: Vector2) -> void:
	rotate_y(deg_to_rad(-motion.x * mouse_sensitivity))
	camera.rotate_x(deg_to_rad(-motion.y * mouse_sensitivity))
	camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

func _movement(delta: float) -> void:
	var direction = Vector3()
	
	# 获取输入方向
	var input_x = Input.get_axis("ui_left", "ui_right")
	var input_z = Input.get_axis("ui_up", "ui_down")
	
	direction.x = input_x
	direction.z = input_z
	direction = direction.rotated(Vector3.UP, rotation.y)
	
	# 重力
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# 跳跃
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_force
	
	# 移动
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	
	move_and_slide()
	is_grounded = is_on_floor()

func _weapon_bobbing(delta: float) -> void:
	# 武器轻微晃动效果（可在添加武器后实现）
	pass
'''
	})
	
	# 武器系统
	files.append({
		"path": "res://scripts/weapon/WeaponSystem.gd",
		"content": '''extends Node3D
## FPS武器系统

@export var damage: float = 25.0
@export var fire_rate: float = 0.1
@export var reload_time: float = 2.0
@export var max_ammo: int = 30
@export var max_reserve: int = 90

var current_ammo: int = 30
var reserve_ammo: int = 90
var is_reloading: bool = false
var can_fire: bool = true

@onready var muzzle_flash: OmniLight3D = $MuzzleFlash
@onready var raycast: RayCast3D = $RayCast

signal shot_fired()
signal reload_started()
signal reload_finished()
signal ammo_changed(current: int, reserve: int)

func _ready() -> void:
	muzzle_flash.light_energy = 0
	ammo_changed.emit(current_ammo, reserve_ammo)

func _process(delta: float) -> void:
	if Input.is_action_pressed("ui_focus_next") and can_fire and not is_reloading:
		_fire()

func _fire() -> void:
	if current_ammo <= 0:
		reload()
		return
	
	current_ammo -= 1
	can_fire = false
	shot_fired.emit()
	ammo_changed.emit(current_ammo, reserve_ammo)
	
	# 发射光线检测
	if raycast.is_colliding():
		var hit_body = raycast.get_collider()
		if hit_body and hit_body.has_method("take_damage"):
			hit_body.take_damage(damage)
	
	# 枪口闪光
	_show_muzzle_flash()
	
	await get_tree().create_timer(fire_rate).timeout
	can_fire = true
	
	if current_ammo <= 0:
		reload()

func reload() -> void:
	if is_reloading or reserve_ammo <= 0:
		return
	
	is_reloading = true
	reload_started.emit()
	
	await get_tree().create_timer(reload_time).timeout
	
	var needed = max_ammo - current_ammo
	var to_reload = mini(needed, reserve_ammo)
	current_ammo += to_reload
	reserve_ammo -= to_reload
	
	is_reloading = false
	reload_finished.emit()
	ammo_changed.emit(current_ammo, reserve_ammo)

func _show_muzzle_flash() -> void:
	muzzle_flash.light_energy = 2
	await get_tree().create_timer(0.05).timeout
	muzzle_flash.light_energy = 0
'''
	})
	
	# 敌人AI
	files.append({
		"path": "res://scripts/enemy/EnemyAI.gd",
		"content": '''extends CharacterBody3D
## FPS敌人AI

@export var health: float = 100.0
@export var damage: float = 10.0
@export var attack_range: float = 3.0
@export var move_speed: float = 2.0

var player: Node3D = null
var is_alive: bool = true

func _ready() -> void:
	# 尝试找到玩家
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	
	if player:
		var to_player = player.global_position - global_position
		var distance = to_player.length()
		
		if distance < attack_range:
			_attack_player()
		else:
			_move_toward_player(delta, to_player.normalized())

func _move_toward_player(delta: float, direction: Vector3) -> void:
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	look_at(player.global_position, Vector3.UP)
	move_and_slide()

func _attack_player() -> void:
	if player and player.has_method("take_damage"):
		player.take_damage(damage)

func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0:
		is_alive = false
		die()

func die() -> void:
	queue_free()
'''
	})
	
	return {
		"success": true,
		"files": files,
		"message": "3D FPS模板已生成，包含 %d 个文件" % files.size()
	}

func _generate_2d_topdown_shooter_template(info: Dictionary) -> Dictionary:
	var files = []
	
	# 俯视角玩家控制器
	files.append({
		"path": "res://scripts/player/TopDownController.gd",
		"content": '''extends CharacterBody2D
## 俯视角射击玩家控制器

@export var move_speed: float = 200.0
@export var rotation_speed: float = 5.0
@export var fire_rate: float = 0.2
@export var bullet_speed: float = 400.0
@export var bullet_damage: float = 10.0

var can_fire: bool = true
var aim_direction: Vector2 = Vector2.RIGHT

@onready var aim_line: Line2D = $AimLine

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_aim()
	_handle_shoot()

func _handle_movement(delta: float) -> void:
	var direction = Vector2()
	direction.x = Input.get_axis("ui_left", "ui_right")
	direction.y = Input.get_axis("ui_up", "ui_down")
	
	if direction.length() > 0:
		direction = direction.normalized()
	
	velocity = direction * move_speed
	move_and_slide()

func _handle_aim() -> void:
	var mouse_pos = get_global_mouse_position()
	aim_direction = (mouse_pos - global_position).normalized()
	
	rotation = lerp_angle(rotation, aim_direction.angle(), rotation_speed * get_process_delta_time())
	
	# 更新瞄准线
	if aim_line:
		aim_line.points[1] = aim_direction * 100

func _handle_shoot() -> void:
	if Input.is_action_pressed("ui_focus_next") and can_fire:
		_shoot()

func _shoot() -> void:
	can_fire = false
	
	var bullet = preload("res://scenes/Bullet.tscn").instantiate()
	bullet.setup(aim_direction * bullet_speed, bullet_damage)
	bullet.global_position = global_position + aim_direction * 30
	bullet.rotation = aim_direction.angle()
	get_parent().add_child(bullet)
	
	await get_tree().create_timer(fire_rate).timeout
	can_fire = true
'''
	})
	
	# 波次系统
	files.append({
		"path": "res://scripts/game/WaveSystem.gd",
		"content": '''extends Node
## 波次系统

signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal all_waves_completed()

@export var total_waves: int = 10
@export var enemies_per_wave_base: int = 5
@export var spawn_delay: float = 1.0

var current_wave: int = 0
var enemies_remaining: int = 0
var is_wave_active: bool = false

@onready var enemy_spawner: Node2D = $EnemySpawner

func start_wave() -> void:
	if is_wave_active:
		return
	
	current_wave += 1
	is_wave_active = true
	wave_started.emit(current_wave)
	
	var enemy_count = enemies_per_wave_base + current_wave * 2
	_spawn_enemies(enemy_count)

func _spawn_enemies(count: int) -> void:
	enemies_remaining = count
	for i in range(count):
		_spawn_single_enemy()
		await get_tree().create_timer(spawn_delay).timeout

func _spawn_single_enemy() -> void:
	# 在屏幕边缘生成敌人
	var spawn_pos = _get_spawn_position()
	# 这里调用具体的敌人生成逻辑
	print("生成敌人于: ", spawn_pos)

func _get_spawn_position() -> Vector2:
	var screen_size = get_viewport_rect().size
	var side = randi() % 4
	
	match side:
		0: return Vector2(randf() * screen_size.x, -50)  # 上
		1: return Vector2(randf() * screen_size.x, screen_size.y + 50)  # 下
		2: return Vector2(-50, randf() * screen_size.y)  # 左
		_: return Vector2(screen_size.x + 50, randf() * screen_size.y)  # 右

func enemy_defeated() -> void:
	enemies_remaining -= 1
	if enemies_remaining <= 0:
		wave_completed.emit(current_wave)
		is_wave_active = false
		
		if current_wave >= total_waves:
			all_waves_completed.emit()
'''
	})
	
	return {
		"success": true,
		"files": files,
		"message": "2D俯视角射击模板已生成，包含 %d 个文件" % files.size()
	}

func _generate_3d_third_person_template(info: Dictionary) -> Dictionary:
	var files = []
	
	# 第三人称控制器
	files.append({
		"path": "res://scripts/player/ThirdPersonController.gd",
		"content": '''extends CharacterBody3D
## 第三人称角色控制器

@export var move_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_force: float = 5.0
@export var gravity: float = 9.8

@onready var camera_pivot: Node3D = $CameraPivot
@export var mouse_sensitivity: float = 0.3

var current_speed: float = 5.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_rotate_camera(event.relative)

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_jump(delta)

func _rotate_camera(motion: Vector2) -> void:
	camera_pivot.rotate_y(deg_to_rad(-motion.x * mouse_sensitivity))

func _handle_movement(delta: float) -> void:
	var direction = Vector3()
	
	# 获取相机方向
	var camera_forward = camera_pivot.global_transform.basis.z
	var camera_right = camera_pivot.global_transform.basis.x
	
	var input_forward = Input.get_axis("ui_up", "ui_down")
	var input_right = Input.get_axis("ui_left", "ui_right")
	
	direction = camera_forward * input_forward + camera_right * input_right
	direction.y = 0
	direction = direction.normalized()
	
	# 冲刺
	current_speed = sprint_speed if Input.is_action_pressed("ui_text_backspace") else move_speed
	
	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed
	
	# 旋转角色朝向
	if direction.length() > 0:
		look_at(global_position + direction, Vector3.UP)
	
	move_and_slide()

func _handle_jump(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_force
'''
	})
	
	return {
		"success": true,
		"files": files,
		"message": "3D第三人称动作模板已生成，包含 %d 个文件" % files.size()
	}

func _generate_casual_puzzle_template(info: Dictionary) -> Dictionary:
	var files = []
	
	# 关卡管理器
	files.append({
		"path": "res://scripts/level/LevelManager.gd",
		"content": '''extends Node
## 休闲益智游戏关卡管理器

signal level_started(level_num: int)
signal level_completed(level_num: int, stars: int)
signal level_failed(reason: String)

@export var levels_data: Array[Dictionary] = []

var current_level: int = 0
var level_time: float = 0.0
var moves_count: int = 0
var score: int = 0

func _process(delta: float) -> void:
	level_time += delta

func start_level(level_num: int) -> void:
	current_level = level_num
	level_time = 0.0
	moves_count = 0
	score = 0
	level_started.emit(current_level)

func record_move() -> void:
	moves_count += 1

func add_score(points: int) -> void:
	score += points

func complete_level() -> void:
	var stars = _calculate_stars()
	level_completed.emit(current_level, stars)

func fail_level(reason: String) -> void:
	level_failed.emit(reason)

func _calculate_stars() -> int:
	# 根据分数/时间/步数计算星星
	# 子类可重写此方法实现不同逻辑
	if score >= 1000:
		return 3
	elif score >= 500:
		return 2
	return 1

func get_level_data(level_num: int) -> Dictionary:
	if level_num < levels_data.size():
		return levels_data[level_num]
	return {}
'''
	})
	
	return {
		"success": true,
		"files": files,
		"message": "休闲益智游戏模板已生成，包含 %d 个文件" % files.size()
	}

func _generate_rpg_template(info: Dictionary) -> Dictionary:
	var files = []
	
	# 角色属性系统
	files.append({
		"path": "res://scripts/character/CharacterStats.gd",
		"content": '''extends Node
## RPG角色属性系统

signal stats_changed()
signal level_up(new_level: int)
signal health_depleted()
signal mana_depleted()

# 基础属性
@export var max_health: float = 100.0
@export var max_mana: float = 100.0
@export var strength: float = 10.0
@export var intelligence: float = 10.0
@export var defense: float = 5.0
@export var speed: float = 5.0

var current_health: float = 100.0
var current_mana: float = 100.0
var level: int = 1
var experience: int = 0
var experience_to_next_level: int = 100

func _ready() -> void:
	current_health = max_health
	current_mana = max_mana

func take_damage(amount: float) -> void:
	var actual_damage = max(0, amount - defense)
	current_health -= actual_damage
	stats_changed.emit()
	
	if current_health <= 0:
		health_depleted.emit()

func heal(amount: float) -> void:
	current_health = min(max_health, current_health + amount)
	stats_changed.emit()

func use_mana(cost: float) -> bool:
	if current_mana >= cost:
		current_mana -= cost
		stats_changed.emit()
		return true
	return false

func gain_experience(amount: int) -> void:
	experience += amount
	while experience >= experience_to_next_level:
		_level_up()

func _level_up() -> void:
	experience -= experience_to_next_level
	level += 1
	
	# 升级属性增长
	max_health += 10
	max_mana += 5
	strength += 2
	intelligence += 2
	
	current_health = max_health
	current_mana = max_mana
	
	experience_to_next_level = level * 100
	
	level_up.emit(level)

func is_alive() -> bool:
	return current_health > 0
'''
	})
	
	# 技能系统
	files.append({
		"path": "res://scripts/skill/SkillSystem.gd",
		"content": '''extends Node
## RPG技能系统

signal skill_learned(skill_id: String)
signal skill_used(skill_id: String, target)

class Skill:
	var id: String
	var name: String
	var description: String
	var mana_cost: float
	var cooldown: float
	var damage: float
	var healing: float
	
	func _init(
		p_id: String = "",
		p_name: String = "",
		p_desc: String = "",
		p_mana: float = 0,
		p_cd: float = 0,
		p_dmg: float = 0,
		p_heal: float = 0
	) -> void:
		id = p_id
		name = p_name
		description = p_desc
		mana_cost = p_mana
		cooldown = p_cd
		damage = p_dmg
		healing = p_heal

var learned_skills: Array = []
var skill_cooldowns: Dictionary = {}

func _ready() -> void:
	_init_default_skills()

func _init_default_skills() -> void:
	# 默认技能
	var skills = [
		Skill.new("attack", "普通攻击", "基础攻击", 0, 0, 10, 0),
		Skill.new("fireball", "火球术", "发射火球造成伤害", 20, 3, 50, 0),
		Skill.new("heal", "治疗术", "恢复生命值", 30, 5, 0, 40),
		Skill.new("shield", "护盾", "增加防御", 15, 8, 0, 0)
	]
	
	for skill in skills:
		learn_skill(skill)

func learn_skill(skill: Skill) -> void:
	if not has_skill(skill.id):
		learned_skills.append(skill)
		skill_learned.emit(skill.id)

func has_skill(skill_id: String) -> bool:
	for skill in learned_skills:
		if skill.id == skill_id:
			return true
	return false

func can_use_skill(skill_id: String, current_mana: float) -> bool:
	var skill = get_skill(skill_id)
	if not skill:
		return false
	
	if skill_cooldowns.has(skill_id) and skill_cooldowns[skill_id] > 0:
		return false
	
	return current_mana >= skill.mana_cost

func use_skill(skill_id: String, target = null) -> Dictionary:
	var skill = get_skill(skill_id)
	if not skill:
		return {"success": false, "message": "技能不存在"}
	
	skill_cooldowns[skill_id] = skill.cooldown
	skill_used.emit(skill_id, target)
	
	return {
		"success": true,
		"damage": skill.damage,
		"healing": skill.healing,
		"message": "使用了 " + skill.name
	}

func get_skill(skill_id: String) -> Skill:
	for skill in learned_skills:
		if skill.id == skill_id:
			return skill
	return null

func _process(delta: float) -> void:
	# 更新冷却
	var to_remove = []
	for skill_id in skill_cooldowns:
		skill_cooldowns[skill_id] -= delta
		if skill_cooldowns[skill_id] <= 0:
			to_remove.append(skill_id)
	for skill_id in to_remove:
		skill_cooldowns.erase(skill_id)
'''
	})
	
	# 任务系统
	files.append({
		"path": "res://scripts/quest/QuestSystem.gd",
		"content": '''extends Node
## RPG任务系统

signal quest_started(quest)
signal quest_updated(quest)
signal quest_completed(quest)
signal quest_failed(quest)

class Quest:
	var id: String
	var title: String
	var description: String
	var objectives: Array
	var rewards: Dictionary
	var is_completed: bool = false
	var is_active: bool = false
	
	func _init(
		p_id: String = "",
		p_title: String = "",
		p_desc: String = "",
		p_objectives: Array = [],
		p_rewards: Dictionary = {}
	) -> void:
		id = p_id
		title = p_title
		description = p_desc
		objectives = p_objectives
		rewards = p_rewards

var active_quests: Array = []
var completed_quests: Array = []

func start_quest(quest: Quest) -> void:
	if has_quest(quest.id):
		return
	
	quest.is_active = true
	active_quests.append(quest)
	quest_started.emit(quest)

func update_quest_objective(quest_id: String, objective_index: int, progress: int) -> void:
	var quest = get_quest(quest_id)
	if not quest or not quest.is_active:
		return
	
	if objective_index < quest.objectives.size():
		var obj = quest.objectives[objective_index]
		obj["current"] = progress
		
		if obj["current"] >= obj["required"]:
			obj["completed"] = true
		
		quest_updated.emit(quest)
		_check_quest_completion(quest)

func _check_quest_completion(quest: Quest) -> void:
	var all_complete = true
	for obj in quest.objectives:
		if not obj.get("completed", false):
			all_complete = false
			break
	
	if all_complete:
		complete_quest(quest)

func complete_quest(quest: Quest) -> void:
	quest.is_completed = true
	quest.is_active = false
	active_quests.erase(quest)
	completed_quests.append(quest)
	
	# 发放奖励
	_grant_rewards(quest)
	
	quest_completed.emit(quest)

func fail_quest(quest: Quest) -> void:
	quest.is_active = false
	active_quests.erase(quest)
	quest_failed.emit(quest)

func get_quest(quest_id: String) -> Quest:
	for quest in active_quests:
		if quest.id == quest_id:
			return quest
	return null

func has_quest(quest_id: String) -> bool:
	return get_quest(quest_id) != null

func _grant_rewards(quest: Quest) -> void:
	var rewards = quest.rewards
	if rewards.has("experience"):
		print("获得经验: ", rewards["experience"])
	if rewards.has("gold"):
		print("获得金币: ", rewards["gold"])
'''
	})
	
	return {
		"success": true,
		"files": files,
		"message": "RPG角色扮演模板已生成，包含 %d 个文件" % files.size()
	}

# ==================== 场景生成功能 ====================

func generate_scene(scene_config: Dictionary) -> Dictionary:
	var scene_type = scene_config.get("type", "custom")
	var elements = scene_config.get("elements", [])
	
	var result = {
		"success": true,
		"scene_file": "",
		"script_files": [],
		"message": ""
	}
	
	match scene_type:
		"platformer_level":
			result = _generate_platformer_scene(scene_config)
		"battle_arena":
			result = _generate_battle_scene(scene_config)
		"boss_room":
			result = _generate_boss_room_scene(scene_config)
		_:
			result = _generate_custom_scene(scene_config)
	
	return result

func _generate_tscn_header(path: String, type: String) -> String:
	var timestamp = Time.get_datetime_string_from_system()
	return '''[gd_scene load_steps=2 format=3 UID="%s"]

[ext_resource type="%s" path="" id="1"]

[node name="%s" type="%s"]

''' % [path, type, type, type]

func _generate_platformer_scene(config: Dictionary) -> Dictionary:
	var elements = config.get("elements", [])
	var files = []
	
	# 生成场景文件
	var scene_path = "res://scenes/GeneratedLevel.tscn"
	var scene_content = '''[gd_scene load_steps=%d format=3]

''' % (2 + elements.size())
	
	# 生成元素
	for i in range(elements.size()):
		var elem = elements[i]
		var elem_type = elem.get("type", "platform")
		var elem_name = elem.get("name", "Element" + str(i))
		
		match elem_type:
			"player_spawn":
				scene_content += '''[sub_resource type="CapsuleShape2D" id="spawn_shape_%d"]
radius = 16.0
height = 32.0

[node name="%s" type="CharacterBody2D"]
position = Vector2(%f, %f)
collision_layer = 2

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("spawn_shape_%d")

''' % [i, elem_name, elem.get("pos", Vector2(0, 0)).x, elem.get("pos", Vector2(0, 0)).y, i]
			
			"platform":
				var size = elem.get("size", Vector2(200, 20))
				scene_content += '''[sub_resource type="RectangleShape2D" id="platform_shape_%d"]
size = Vector2(%f, %f)

[node name="%s" type="StaticBody2D" parent="."]
position = Vector2(%f, %f)

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("platform_shape_%d")

[node name="Sprite2D" type="ColorRect" parent="."]
offset = Vector2(0, 0)
size = Vector2(%f, %f)
color = Color(0.4, 0.6, 0.8, 1)

''' % [i, size.x, size.y, elem_name, elem.get("pos", Vector2(0, 0)).x, elem.get("pos", Vector2(0, 0)).y, i, size.x, size.y]
			
			"collectible":
				scene_content += '''[sub_resource type="CircleShape2D" id="collectible_shape_%d"]
radius = 12.0

[node name="%s" type="Area2D" parent="."]
position = Vector2(%f, %f)
collision_layer = 4

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("collectible_shape_%d")

[node name="Sprite2D" type="CircleShape2D" parent="."]
modulate = Color(1, 0.84, 0, 1)

''' % [i, elem_name, elem.get("pos", Vector2(0, 0)).x, elem.get("pos", Vector2(0, 0)).y, i]
			
			"enemy":
				scene_content += '''[sub_resource type="CapsuleShape2D" id="enemy_shape_%d"]
radius = 16.0
height = 32.0

[node name="%s" type="CharacterBody2D" parent="."]
position = Vector2(%f, %f)
collision_layer = 8

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("enemy_shape_%d")

''' % [i, elem_name, elem.get("pos", Vector2(0, 0)).x, elem.get("pos", Vector2(0, 0)).y, i]
			
			"goal":
				scene_content += '''[sub_resource type="RectangleShape2D" id="goal_shape_%d"]
size = Vector2(40, 60)

[node name="%s" type="Area2D" parent="."]
position = Vector2(%f, %f)
collision_layer = 16

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("goal_shape_%d")

[node name="Sprite2D" type="ColorRect" parent="."]
modulate = Color(0.2, 1, 0.2, 0.8)
offset = Vector2(0, 0)
size = Vector2(40, 60)

''' % [i, elem_name, elem.get("pos", Vector2(0, 0)).x, elem.get("pos", Vector2(0, 0)).y, i]
	
	files.append({"path": scene_path, "content": scene_content})
	
	return {
		"success": true,
		"scene_file": scene_path,
		"script_files": files,
		"message": "平台跳跃场景已生成，包含 %d 个元素" % elements.size()
	}

func _generate_battle_scene(config: Dictionary) -> Dictionary:
	var files = []
	var elements = config.get("elements", [])
	
	var scene_path = "res://scenes/BattleArena.tscn"
	var scene_content = '''[gd_scene load_steps=%d format=3]

[sub_resource type="RectangleShape2D" id="floor_shape"]
size = Vector2(800, 600)

[node name="BattleArena" type="Node2D"]

[node name="Floor" type="StaticBody2D" parent="."]

[node name="CollisionShape2D" type="CollisionShape2D" parent="Floor"]
shape = SubResource("floor_shape")

[node name="ColorRect" type="ColorRect" parent="Floor"]
offset = Vector2(-400, -300)
size = Vector2(800, 600)
color = Color(0.2, 0.2, 0.2, 1)

'''
	
	for i in range(elements.size()):
		var elem = elements[i]
		var elem_type = elem.get("type", "obstacle")
		var elem_name = elem.get("name", "Element" + str(i))
		
		match elem_type:
			"player_spawn":
				scene_content += '''[node name="%s" type="Marker2D" parent="."]
position = Vector2(%f, %f)

''' % [elem_name, elem.get("pos", Vector2(400, 300)).x, elem.get("pos", Vector2(400, 300)).y]
			
			"enemy", "spawner":
				scene_content += '''[node name="%s" type="Marker2D" parent="."]
position = Vector2(%f, %f)

''' % [elem_name, elem.get("pos", Vector2(0, 0)).x, elem.get("pos", Vector2(0, 0)).y]
	
	files.append({"path": scene_path, "content": scene_content})
	
	return {
		"success": true,
		"scene_file": scene_path,
		"script_files": files,
		"message": "战斗场景已生成"
	}

func _generate_boss_room_scene(config: Dictionary) -> Dictionary:
	var files = []
	
	var scene_path = "res://scenes/BossRoom.tscn"
	var scene_content = '''[gd_scene load_steps=3 format=3]

[sub_resource type="RectangleShape2D" id="boss_platform"]
size = Vector2(600, 100)

[sub_resource type="RectangleShape2D" id="boundary"]
size = Vector2(700, 500)

[node name="BossRoom" type="Node2D"]

[node name="BossPlatform" type="StaticBody2D" parent="."]
position = Vector2(400, 400)

[node name="CollisionShape2D" type="CollisionShape2D" parent="BossPlatform"]
shape = SubResource("boss_platform")

[node name="BossSpawnPoint" type="Marker2D" parent="."]
position = Vector2(400, 300)

[node name="PlayerSpawnPoint" type="Marker2D" parent="."]
position = Vector2(100, 350)

[node name="Boundary" type="StaticBody2D" parent="."]

[node name="CollisionShape2D" type="CollisionShape2D" parent="Boundary"]
shape = SubResource("boundary")

'''
	
	files.append({"path": scene_path, "content": scene_content})
	
	return {
		"success": true,
		"scene_file": scene_path,
		"script_files": files,
		"message": "Boss房间已生成"
	}

func _generate_custom_scene(config: Dictionary) -> Dictionary:
	var elements = config.get("elements", [])
	var files = []
	
	var scene_path = "res://scenes/CustomScene.tscn"
	var scene_content = "[gd_scene format=3]\n\n[node name=\"CustomScene\" type=\"Node2D\"]\n\n"
	
	for i in range(elements.size()):
		var elem = elements[i]
		var elem_name = elem.get("name", "Element" + str(i))
		var pos = elem.get("pos", Vector2(0, 0))
		
		scene_content += '''[node name="%s" type="Marker2D" parent="."]
position = Vector2(%f, %f)

''' % [elem_name, pos.x, pos.y]
	
	files.append({"path": scene_path, "content": scene_content})
	
	return {
		"success": true,
		"scene_file": scene_path,
		"script_files": files,
		"message": "自定义场景已生成，包含 %d 个元素" % elements.size()
	}

# 获取可用模板列表
func get_template_list() -> Array:
	return [
		{"id": "player", "name": "玩家角色", "description": "包含移动、跳跃的基础角色脚本"},
		{"id": "enemy", "name": "敌人AI", "description": "基础巡逻敌人脚本"},
		{"id": "collectible", "name": "可收集物", "description": "金币、道具等可收集物品"},
		{"id": "platform", "name": "移动平台", "description": "可移动的平台"}
	]

# ==================== 代码解释与优化 ====================

func generate_explanation(code: String) -> String:
	"""生成代码解释（本地模板版本，不需要AI）
	用于在AI不可用时提供基本解释
	
	Args:
		code: 要解释的代码
		
	Returns:
		格式化的解释文本
	"""
	var lines = code.split("\n")
	var lang = detect_language(code)
	var lang_name = "未知语言"
	match lang:
		"gdscript": lang_name = "GDScript (Godot)"
		"csharp": lang_name = "C# (Unity)"
		"python": lang_name = "Python"
		"javascript": lang_name = "JavaScript"
	
	var result = "📖 **代码解释**\n"
	result += "━━━━━━━━━━━━━━━━━━━━━━━\n"
	result += "📌 语言: " + lang_name + "\n"
	result += "📏 行数: %d 行\n\n" % lines.size()
	result += "**代码预览:**\n```\n%s\n```\n\n" % code.substr(0, min(500, code.length()))
	if code.length() > 500:
		result += "_（代码过长，已截断预览）_\n\n"
	
	result += "💡 **使用AI获取完整解释**\n"
	result += "请输入「解释代码」，AI会详细分析这段代码的：\n"
	result += "• 整体功能和用途\n"
	result += "• 逐行/逐段逻辑\n"
	result += "• 核心变量和函数\n"
	result += "• 潜在问题和改进建议\n"
	
	return result

func generate_optimization(code: String) -> String:
	"""生成代码优化建议（本地版本）
	
	Args:
		code: 要优化的代码
		
	Returns:
		格式化的优化建议文本
	"""
	var lines = code.split("\n")
	var lang = detect_language(code)
	
	# 基本检查
	var issues = []
	var line_count = lines.size()
	
	# 检测常见问题
	for i in range(lines.size()):
		var line = lines[i]
		if line.find("func ") != -1 and line.find("_ready") == -1 and line.find("_process") == -1 and line.find("_physics_process") == -1:
			pass  # 普通函数
		if line.find("func _ready") != -1 or line.find("func _process") != -1 or line.find("func _physics_process") != -1:
			if line.find("@onready") == -1 and line.find("get_node") != -1:
				issues.append("⚠️ [行 %d] 建议使用 @onready 缓存 get_node() 结果" % (i + 1))
	
	if line_count > 300:
		issues.append("⚠️ 代码过长（%d行），建议拆分为多个脚本" % line_count)
	
	if code.find("print(") != -1:
		issues.append("ℹ️ 检测到 print() 语句，产品发布前建议移除或替换为日志系统")
	
	if code.find("pass") != -1 and line_count < 10:
		issues.append("ℹ️ 检测到空的 pass 块或未完成函数")
	
	var result = "🔧 **代码优化建议**\n"
	result += "━━━━━━━━━━━━━━━━━━━━━━━\n"
	result += "📌 语言: " + ("GDScript (Godot)" if lang == "gdscript" else "C# (Unity)" if lang == "csharp" else lang) + "\n"
	result += "📏 行数: %d 行\n\n" % line_count
	
	if issues.is_empty():
		result += "✅ 初步检查未发现明显问题\n\n"
	else:
		result += "**发现问题:**\n"
		for issue in issues:
			result += issue + "\n"
		result += "\n"
	
	result += "💡 **使用AI获取完整优化方案**\n"
	result += "请输入「优化代码」，AI会：\n"
	result += "• 分析性能瓶颈\n"
	result += "• 评估代码可读性\n"
	result += "• 检查安全性风险\n"
	result += "• 提供优化后的完整代码\n"
	
	return result

func detect_language(code: String) -> String:
	"""检测代码语言"""
	if code.find("extends ") != -1 or code.find("@export") != -1 or code.find("func _ready") != -1 or code.find("move_and_slide") != -1:
		return "gdscript"
	if code.find("using UnityEngine") != -1 or code.find("void Start") != -1 or code.find("void Update") != -1 or code.find("[SerializeField]") != -1:
		return "csharp"
	if code.find("def ") != -1 and code.find(":") != -1:
		return "python"
	if code.find("function ") != -1 or code.find("const ") != -1 or code.find("=>") != -1:
		return "javascript"
	return "unknown"
