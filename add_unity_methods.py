#!/usr/bin/env python3

# Read the file
with open(r'C:\Users\a1478\.qclaw\workspace\game-ai-assistant\unity\Assets\GameAIAssistant\GameAIAssistant.cs', 'r', encoding='utf-8') as f:
    content = f.read()

# Find the Project Template section end and add methods before it
# We'll insert before "// ==================== 项目扫描 ===================="

insert_marker = '// ==================== 项目扫描 ===================='
insert_text = '''// ==================== 命令处理方法 ====================

        void ProcessCreateTemplateCommand(string message)
        {
            string lower = message.ToLower();
            
            // 数字索引
            var numMatch = System.Text.RegularExpressions.Regex.Match(message, @"创建(\d+)");
            if (numMatch.Success)
            {
                int idx = int.Parse(numMatch.Groups[1].Value) - 1;
                if (idx >= 0 && idx < projectTemplates.Length)
                {
                    CreateProjectTemplate(projectTemplates[idx]);
                    return;
                }
            }
            
            // 关键字匹配
            if (lower.Contains("2d平台") || lower.Contains("平台跳跃") || lower.Contains("平台"))
            {
                CreateProjectTemplate(projectTemplates[0]);
                return;
            }
            if (lower.Contains("fps") || lower.Contains("第一人称") || lower.Contains("射击"))
            {
                CreateProjectTemplate(projectTemplates[1]);
                return;
            }
            if (lower.Contains("俯视角") || lower.Contains("俯视射击"))
            {
                CreateProjectTemplate(projectTemplates[2]);
                return;
            }
            if (lower.Contains("第三人称") || lower.Contains("动作"))
            {
                CreateProjectTemplate(projectTemplates[3]);
                return;
            }
            if (lower.Contains("休闲") || lower.Contains("益智"))
            {
                CreateProjectTemplate(projectTemplates[4]);
                return;
            }
            if (lower.Contains("rpg") || lower.Contains("角色扮演"))
            {
                CreateProjectTemplate(projectTemplates[5]);
                return;
            }
            
            AddMessage("⚠️ 未找到匹配的模板类型", false);
        }

        void ProcessSceneGenCommand(string message)
        {
            string lower = message.ToLower();
            
            if (lower.Contains("简单关卡") || lower.Contains("基础关卡"))
            {
                GenerateScene("simple_level");
                return;
            }
            
            if (lower.Contains("战斗") || lower.Contains("arena"))
            {
                GenerateScene("battle_arena");
                return;
            }
            
            if (lower.Contains("boss"))
            {
                GenerateScene("boss_room");
                return;
            }
            
            AddMessage("⚠️ 请使用「生成简单关卡」「生成战斗场景」或「生成boss」命令", false);
        }

'''

if insert_marker in content:
    content = content.replace(insert_marker, insert_text + insert_marker)
    print("Successfully added command processing methods")
else:
    print("Insert marker not found!")

# Write back
with open(r'C:\Users\a1478\.qclaw\workspace\game-ai-assistant\unity\Assets\GameAIAssistant\GameAIAssistant.cs', 'w', encoding='utf-8') as f:
    f.write(content)

print("File saved successfully")
