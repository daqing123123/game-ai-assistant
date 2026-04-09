using UnityEngine;

namespace GameAIAssistant
{
    /// <summary>
    /// Unity包描述文件
    /// 拖入Project窗口即可安装
    /// </summary>
    public class GameAIAssistantSetup : MonoBehaviour
    {
        [Header("安装说明")]
        [TextArea(5, 10)]
        public string installGuide = @"
🐙 Game AI Assistant 安装指南

1. 将此脚本所在文件夹保留在 Assets 目录下
2. 打开 Unity，Window > Game AI Assistant
3. 点击 ⚙️ 配置你的 AI 模型
4. 开始使用！

支持的 AI 模型：
• DeepSeek V3 (推荐，免费额度)
• Claude 3.5 Sonnet
• GPT-4o
• 本地 Ollama 模型

遇到问题？
• 确保网络畅通
• 检查 API Key 是否正确
• 本地模型需要先安装 Ollama
";
        
        [Header("快速开始")]
        [TextArea(3, 5)]
        public string quickStart = @"
常用命令：
• 「帮我做一个2D跑酷游戏」
• 「给玩家加个二段跳功能」
• 「找个爆炸音效」
• 「什么是状态机？」
";
    }
}
