#!/usr/bin/env python3
import sys

# Read the file
with open(r'C:\Users\a1478\.qclaw\workspace\game-ai-assistant\unity\Assets\GameAIAssistant\GameAIAssistant.cs', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix encoding issue
content = content.replace('知识?)', '知识库)')

# Find the knowledge base section and add new commands after it
search_marker = 'if (lowerMsg.Contains("添加知识:"))'
insert_text = '''// 项目模板命令
            if (lowerMsg.Contains("创建项目") || lowerMsg.Contains("新建项目") || lowerMsg.Contains("项目模板"))
            {
                ShowProjectTemplates();
                isProcessing = false;
                statusText = "就绪";
                return;
            }

            // 创建指定模板
            if (lowerMsg.Contains("创建"))
            {
                ProcessCreateTemplateCommand(message);
                isProcessing = false;
                statusText = "就绪";
                return;
            }

            // 场景生成命令
            if (lowerMsg.Contains("生成场景") || lowerMsg.Contains("创建场景") || lowerMsg.Contains("场景向导"))
            {
                ShowSceneGenerator();
                isProcessing = false;
                statusText = "就绪";
                return;
            }

            // 快捷场景生成
            if (lowerMsg.Contains("生成简单关卡") || lowerMsg.Contains("生成战斗场景") || lowerMsg.Contains("生成boss"))
            {
                ProcessSceneGenCommand(message);
                isProcessing = false;
                statusText = "就绪";
                return;
            }

'''

if search_marker in content:
    content = content.replace(search_marker, insert_text + search_marker)
    print("Successfully added template and scene commands")
else:
    print("Search marker not found!")
    sys.exit(1)

# Write back
with open(r'C:\Users\a1478\.qclaw\workspace\game-ai-assistant\unity\Assets\GameAIAssistant\GameAIAssistant.cs', 'w', encoding='utf-8') as f:
    f.write(content)

print("File saved successfully")
