using UnityEngine;
using UnityEditor;
using System.Collections;
using System.Collections.Generic;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;

namespace GameAIAssistant
{
    /// <summary>
    /// 游戏AI助手 - Unity编辑器扩�?v1.5
    /// 集成调试助手、代码搜索功�?    /// </summary>
    public class GameAIAssistant : EditorWindow
    {
        // ==================== 窗口状�?====================
        private string inputText = "";
        private Vector2 scrollPosition;
        private List<ChatMessage> chatHistory = new List<ChatMessage>();
        private bool isProcessing = false;

        // ==================== 项目信息 ====================
        private ProjectInfo currentProject;

        // ==================== 待应用的代码 ====================
        private List<CodeBlock> pendingCodeBlocks = new List<CodeBlock>();

        // ==================== 撤销/重做 ====================
        private List<UndoHistory> undoStack = new List<UndoHistory>();
        private List<UndoHistory> redoStack = new List<UndoHistory>();
        private const int MAX_HISTORY = 50;

        // ==================== 预览和确�?====================
        private bool confirmBeforeApply = true;
        private bool confirmBeforeOverwrite = true;
        private List<CodeBlock> pendingPreviewBlocks = new List<CodeBlock>();
        private int pendingPreviewIndex = -1;

        // ==================== Phase 4: 知识库====================
        private KnowledgeBase knowledgeBase = new KnowledgeBase();

        // ==================== Phase 5: 测试生成 ====================
        private string pendingTestFile = "";
        private string selectedTestFramework = "NUnit";
        private List<TestCase> generatedTestCases = new List<TestCase>();

        // ==================== Phase 5: 差异对比 ====================
        private string originalCodeCache = "";
        private string newCodeCache = "";
        private string currentDiffFilePath = "";
        private List<DiffChunk> diffChunks = new List<DiffChunk>();
        private bool isShowingDiff = false;

        // ==================== 配置 ====================
        private string apiKey = "";
        private string modelName = "DeepSeek V3";
        private string modelEndpoint = "https://api.deepseek.com/v1";
        private string modelId = "deepseek-chat";
        private bool useCloud = true;
        private string localUrl = "http://localhost:11434/v1";
        private string localModel = "qwen2.5:3b";

        // ==================== 新增模型配置 ====================
        // 国际模型
        private string azureEndpoint = "";
        private string azureDeployment = "";
        // 讯飞星火额外配置
        private string sparkAppId = "";
        private string sparkApiSecret = "";

        // ==================== 状�?====================
        private string statusText = "";
        private bool isConnected = false;

        // ==================== 语言配置 ====================
        private string currentLanguage = "auto";  // "auto" | "zh" | "en"

        // 双语翻译字典
        private Dictionary<string, Dictionary<string, string>> translations = new Dictionary<string, Dictionary<string, string>>()
        {
            {
                "zh", new Dictionary<string, string>
                {
                    {"send", "发送"},
                    {"settings", "设置"},
                    {"help", "帮助"},
                    {"apply", "应用"},
                    {"preview", "预览"},
                    {"knowledge_base", "知识库"},
                    {"daily_learning", "每日学习"},
                    {"project_scan", "扫描项目"},
                    {"search_assets", "搜索素材"},
                    {"undo", "撤销"},
                    {"redo", "重做"},
                    {"history", "历史"},
                    {"syncing", "同步中..."},
                    {"sync_success", "同步成功"},
                    {"sync_failed", "同步失败"},
                    {"generating_code", "正在生成代码..."},
                    {"code_applied", "代码已应用"},
                    {"api_key_required", "请先配置 API Key"},
                    {"select_model", "请选择 AI 模型"},
                    {"connecting", "连接中..."},
                    {"connected", "已连接"},
                    {"error", "错误"},
                    {"success", "成功"},
                    {"cancel", "取消"},
                    {"confirm", "确认"},
                    {"close", "关闭"},
                    {"save", "保存"},
                    {"loading", "加载中..."},
                    {"no_results", "未找到结果"},
                    {"search_hint", "输入你的问题..."},
                    {"help_text", "帮助信息"},
                    {"settings_title", "设置"},
                    {"language", "语言"},
                    {"chinese", "中文"},
                    {"english", "English"},
                    {"auto_detect", "自动"},
                    {"ready", "就绪"},
                    {"thinking", "思考中..."},
                    {"complete", "完成"},
                    {"pending_blocks", "个待应用"},
                    {"model_not_configured", "未配置"},
                    {"clear_history", "清空历史"},
                    {"skip", "跳过"},
                    {"accept", "接受"},
                    {"debug", "调试"},
                    {"search", "搜索"},
                    {"test_generate", "测试生成"},
                    {"diff_compare", "差异对比"},
                    {"project_template", "项目模板"},
                    {"scene_generate", "场景生成"},
                    {"not_configured", "未配置"},
                    {"not_connected", "未连接"},
                    {"configured", "已配置"},
                    {"connected_status", "已连接"},
                }
            },
            {
                "en", new Dictionary<string, string>
                {
                    {"send", "Send"},
                    {"settings", "Settings"},
                    {"help", "Help"},
                    {"apply", "Apply"},
                    {"preview", "Preview"},
                    {"knowledge_base", "Knowledge Base"},
                    {"daily_learning", "Daily Learning"},
                    {"project_scan", "Scan Project"},
                    {"search_assets", "Search Assets"},
                    {"undo", "Undo"},
                    {"redo", "Redo"},
                    {"history", "History"},
                    {"syncing", "Syncing..."},
                    {"sync_success", "Sync successful"},
                    {"sync_failed", "Sync failed"},
                    {"generating_code", "Generating code..."},
                    {"code_applied", "Code applied"},
                    {"api_key_required", "Please configure API Key first"},
                    {"select_model", "Please select AI model"},
                    {"connecting", "Connecting..."},
                    {"connected", "Connected"},
                    {"error", "Error"},
                    {"success", "Success"},
                    {"cancel", "Cancel"},
                    {"confirm", "Confirm"},
                    {"close", "Close"},
                    {"save", "Save"},
                    {"loading", "Loading..."},
                    {"no_results", "No results found"},
                    {"search_hint", "Ask me anything..."},
                    {"help_text", "Help"},
                    {"settings_title", "Settings"},
                    {"language", "Language"},
                    {"chinese", "中文"},
                    {"english", "English"},
                    {"auto_detect", "Auto"},
                    {"ready", "Ready"},
                    {"thinking", "Thinking..."},
                    {"complete", "Complete"},
                    {"pending_blocks", " pending"},
                    {"model_not_configured", "Not configured"},
                    {"clear_history", "Clear"},
                    {"skip", "Skip"},
                    {"accept", "Accept"},
                    {"debug", "Debug"},
                    {"search", "Search"},
                    {"test_generate", "Test"},
                    {"diff_compare", "Diff"},
                    {"project_template", "Template"},
                    {"scene_generate", "Scene"},
                    {"not_configured", "Not configured"},
                    {"not_connected", "Disconnected"},
                    {"configured", "Configured"},
                    {"connected_status", "Connected"},
                }
            }
        };

        // 获取翻译文本
        private string Tr(string key)
        {
            string lang = currentLanguage;
            if (lang == "auto")
            {
                lang = Application.systemLanguage == SystemLanguage.Chinese ? "zh" : "en";
            }
            if (translations.ContainsKey(lang) && translations[lang].ContainsKey(key))
            {
                return translations[lang][key];
            }
            if (translations["en"].ContainsKey(key))
            {
                return translations["en"][key];
            }
            return key;
        }

        // 获取当前语言
        private string GetCurrentLang()
        {
            if (currentLanguage == "auto")
            {
                return Application.systemLanguage == SystemLanguage.Chinese ? "zh" : "en";
            }
            return currentLanguage;
        }

        // 设置语言
        private void SetLanguage(string lang)
        {
            currentLanguage = lang;
        }

        // ==================== HTTP ====================
        private HttpClient httpClient;

        // ==================== GUI样式 ====================
        private GUIStyle headerStyle;
        private GUIStyle statusStyle;

        // ==================== 初始�?====================

        [MenuItem("Window/🐙 Game AI Assistant")]
        public static void ShowWindow()
        {
            var window = GetWindow<GameAIAssistant>("AI助手");
            window.minSize = new Vector2(400, 500);
            window.Show();
        }

        void OnEnable()
        {
            LoadConfig();
            LoadKnowledge();
            InitStyles();
            httpClient = new HttpClient();
            httpClient.Timeout = TimeSpan.FromSeconds(60);
        }

        void OnDisable()
        {
            SaveKnowledge();
            if (httpClient != null)
            {
                httpClient.Dispose();
            }
        }

        void InitStyles()
        {
            headerStyle = new GUIStyle(EditorStyles.boldLabel)
            {
                alignment = TextAnchor.MiddleCenter,
                fontSize = 16,
                fontStyle = FontStyle.Bold
            };

            statusStyle = new GUIStyle(EditorStyles.miniLabel)
            {
                alignment = TextAnchor.MiddleCenter
            };
        }

        // ==================== GUI绘制 ====================

        void OnGUI()
        {
            DrawHeader();
            DrawStatusBar();
            EditorGUILayout.Space(5);
            DrawChatArea();
            EditorGUILayout.Space(5);
            DrawInputArea();
            DrawBottomBar();
            DrawProjectTemplateWindow();
            DrawSceneGenWindow();
        }

        void DrawHeader()
        {
            EditorGUILayout.BeginVertical("helpBox");
            GUILayout.Space(8);
            GUILayout.Label("🐙 Game AI Assistant v1.5", headerStyle);
            GUILayout.Label("游戏开发AI助手 - Phase 5", statusStyle);
            GUILayout.Space(8);
            EditorGUILayout.EndVertical();
        }

        void DrawStatusBar()
        {
            EditorGUILayout.BeginHorizontal("helpBox");

            GUI.color = isConnected ? Color.green : Color.red;
            GUILayout.Label(isConnected ? "�?已连�? : "�?未配�?, GUILayout.Width(80));
            GUI.color = Color.white;

            string displayModel = useCloud ? modelName : $"本地: {localModel}";
            GUILayout.Label($"{(GetCurrentLang() == "zh" ? "Model:" : "Model:")} {displayModel}", GUILayout.Width(150));

            GUILayout.Label($"状�? {statusText}", GUILayout.ExpandWidth(true));

            if (GUILayout.Button("⚙️", GUILayout.Width(40)))
            {
                ShowSettings();
            }

            EditorGUILayout.EndHorizontal();
        }

        void DrawChatArea()
        {
            scrollPosition = EditorGUILayout.BeginScrollView(scrollPosition, GUILayout.Height(280));

            EditorGUILayout.BeginVertical();

            if (chatHistory.Count == 0)
            {
                DrawWelcomeMessage();
            }

            foreach (var msg in chatHistory)
            {
                DrawMessage(msg);
            }

            if (isProcessing)
            {
                EditorGUILayout.BeginHorizontal();
                GUILayout.FlexibleSpace();
                GUILayout.Label("�?AI正在思考中...", statusStyle);
                GUILayout.FlexibleSpace();
                EditorGUILayout.EndHorizontal();
            }

            EditorGUILayout.EndVertical();
            EditorGUILayout.EndScrollView();
        }

        void DrawWelcomeMessage()
        {
            EditorGUILayout.BeginVertical("helpBox");

            GUILayout.Label("🐙 你好！我是游戏开发AI助手 v1.5", EditorStyles.boldLabel);
            GUILayout.Space(5);
            GUILayout.Label("�?生成Unity(C#)代码", EditorStyles.miniLabel);
            GUILayout.Label("�?修改现有代码", EditorStyles.miniLabel);
            GUILayout.Label("�?搜索免费可商用素�?, EditorStyles.miniLabel);
            GUILayout.Label("�?每日学习新技�?, EditorStyles.miniLabel);
            GUILayout.Label("�?知识库管�?, EditorStyles.miniLabel);
            GUILayout.Space(3);
            GUILayout.Label("📚 输入「今日学习」开始学�?, EditorStyles.miniLabel);
            GUILayout.Label("📖 输入「知识库」查�?搜索知识", EditorStyles.miniLabel);
            GUILayout.Space(5);
            GUILayout.Label("输入「帮助」查看所有命�?, statusStyle);

            EditorGUILayout.EndVertical();
            GUILayout.Space(10);
        }

        void DrawMessage(ChatMessage msg)
        {
            if (msg.isUser)
            {
                GUI.color = new Color(0.2f, 0.4f, 0.8f);
                EditorGUILayout.BeginHorizontal();
                GUILayout.FlexibleSpace();
                EditorGUILayout.BeginVertical("box", GUILayout.Width(300));
                GUILayout.Label($"👤 {msg.content}", EditorStyles.helpBox);
                EditorGUILayout.EndVertical();
                EditorGUILayout.EndHorizontal();
            }
            else
            {
                GUI.color = new Color(0.2f, 0.7f, 0.3f);
                EditorGUILayout.BeginHorizontal();
                EditorGUILayout.BeginVertical("box", GUILayout.Width(300));
                GUILayout.Label($"🤖 {msg.content}", EditorStyles.helpBox);
                EditorGUILayout.EndVertical();
                GUILayout.FlexibleSpace();
                EditorGUILayout.EndHorizontal();
            }
            GUI.color = Color.white;
            GUILayout.Space(3);
        }

        void DrawInputArea()
        {
            EditorGUILayout.BeginHorizontal("box");

            GUI.SetNextControlName("InputField");
            inputText = EditorGUILayout.TextArea(inputText, GUILayout.Height(60), GUILayout.ExpandWidth(true));
            GUI.FocusControl("InputField");

            EditorGUILayout.BeginVertical(GUILayout.Width(70));

            GUI.enabled = !string.IsNullOrEmpty(inputText) && !isProcessing;
            if (GUILayout.Button("发�?, GUILayout.Height(35)))
            {
                SendMessage();
            }

            if (GUILayout.Button(Tr("clear_history"), GUILayout.Height(25)))
            {
                ClearHistory();
            }
            GUI.enabled = true;

            EditorGUILayout.EndVertical();
            EditorGUILayout.EndHorizontal();
        }

        void DrawBottomBar()
        {
            EditorGUILayout.BeginHorizontal();

            GUI.enabled = !isProcessing;

            if (GUILayout.Button("📋 " + Tr("project_template")))
            {
                ShowTemplates();
            }

            if (GUILayout.Button("🎨 " + Tr("search_assets")))
            {
                ShowAssetLibrary();
            }

            if (GUILayout.Button("📂 " + Tr("project_scan")))
            {
                ScanProject();
            }

            GUI.enabled = true;

            EditorGUILayout.EndHorizontal();

            EditorGUILayout.BeginHorizontal();

            GUI.enabled = !isProcessing && pendingCodeBlocks.Count > 0;

            // 预览按钮
            GUI.backgroundColor = pendingCodeBlocks.Count > 0 ? Color.yellow : Color.gray;
            if (GUILayout.Button($"👁�?预览 ({pendingCodeBlocks.Count})"))
            {
                ShowPreview();
            }
            GUI.backgroundColor = Color.white;

            // 应用按钮
            GUI.backgroundColor = pendingCodeBlocks.Count > 0 ? Color.green : Color.gray;
            if (GUILayout.Button($"�?应用 ({pendingCodeBlocks.Count})"))
            {
                ApplyPendingCodes();
            }
            GUI.backgroundColor = Color.white;

            GUI.enabled = true;

            if (GUILayout.Button("📚 " + Tr("daily_learning")))
            {
                ShowTodayLearning();
            }
            
            if (GUILayout.Button("🏗️ " + Tr("project_template")))
            {
                ShowProjectTemplates();
            }
            
            if (GUILayout.Button("🎬 " + Tr("scene_generate")))
            {
                ShowSceneGenerator();
            }
            }

            if (GUILayout.Button("📖 " + Tr("knowledge_base")))
            {
                ShowKnowledgeBase();
            }

            if (GUILayout.Button("📝 Explain"))
            {
                ExplainSelectedCode();
            }

            if (GUILayout.Button("🔧 Optimize"))
            {
                OptimizeSelectedCode();
            }

            EditorGUILayout.EndHorizontal();
            
            EditorGUILayout.BeginHorizontal();

            if (GUILayout.Button("🐛 " + Tr("debug")))
            {
                OnDebugButtonClicked();
            }

            if (GUILayout.Button("🔍 " + Tr("search")))
            {
                OnSearchButtonClicked();
            }

            // 显示历史状态
            GUILayout.FlexibleSpace();
            GUILayout.Label(GetHistoryStatus(), EditorStyles.miniLabel);

            EditorGUILayout.EndHorizontal();
        }

        // ==================== Phase 5: 调试和搜索 ====================
        
        void OnDebugButtonClicked()
        {
            HandleDebugCommand("调试");
        }
        
        void OnSearchButtonClicked()
        {
            HandleCodeSearchCommand("搜索代码");
        }

        // ==================== 核心功能 ====================

        void SendMessage()
        {
            if (string.IsNullOrWhiteSpace(inputText)) return;

            string message = inputText.Trim();
            inputText = "";

            AddMessage(message, true);
            ProcessCommand(message);
        }

        void ProcessCommand(string message)
        {
            isProcessing = true;
            statusText = "处理�?..";
            Repaint();

            string lowerMsg = message.ToLower();

            // 特殊命令
            if (lowerMsg.Contains("帮助") || lowerMsg.Contains("help"))
            {
                ShowHelp();
                isProcessing = false;
                statusText = Tr("ready");
                return;
            }

            if (lowerMsg.Contains("模板") || lowerMsg.Contains("template"))
            {
                ShowTemplates();
                isProcessing = false;
                statusText = "就绪";
                return;
            }

            if (lowerMsg.Contains("素材") || lowerMsg.Contains("asset"))
            {
                ShowAssetLibrary();
                isProcessing = false;
                statusText = "就绪";
                return;
            }

            if (lowerMsg.Contains("扫描项目") || lowerMsg.Contains("项目结构"))
            {
                ScanProject();
                isProcessing = false;
                statusText = "就绪";
                return;
            }

            if (lowerMsg.Contains("今日学习") || lowerMsg.Contains("学习"))
            {
                ShowTodayLearning();
                isProcessing = false;
                statusText = "就绪";
                return;
            }

            if (lowerMsg.Contains("知识库) || lowerMsg.Contains("知识"))
            {
                ShowKnowledgeBase();
                isProcessing = false;
                statusText = "就绪";
                return;
            }

            // 项目模板命令
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

if (lowerMsg.Contains("添加知识:"))
            {
                AddKnowledge(message);
                isProcessing = false;
                statusText = "就绪";
                return;
            }

            if (lowerMsg.Contains("搜索知识:") || lowerMsg.Contains("查找知识:"))
            {
                SearchKnowledge(message);
                isProcessing = false;
                statusText = "就绪";
                return;
            }

            // 测试生成命令
            if (lowerMsg.Contains("生成测试") || lowerMsg.Contains("写单元测�?) ||
                lowerMsg.Contains("单元测试") || lowerMsg.Contains("写测�?) ||
                lowerMsg.Contains("测试代码") || lowerMsg.Contains("create test"))
            {
                var targetFile = ExtractTestTargetFile(message);
                if (!string.IsNullOrEmpty(targetFile))
                {
                    GenerateTest(targetFile);
                }
                else
                {
                    ShowTestGeneration();
                }
                isProcessing = false;
                statusText = "就绪";
                return;
            }

            // 差异对比命令
            if (lowerMsg.Contains("diff") || lowerMsg.Contains("差异") ||
                lowerMsg.Contains("对比") || lowerMsg.Contains("show diff"))
            {
                ShowDiffComparison();
                isProcessing = false;
                statusText = "就绪";
                return;
            }

            // 调试助手命令
            if (lowerMsg.Contains("调试") || lowerMsg.Contains("找bug") ||
                lowerMsg.Contains("报错�?) || lowerMsg.Contains("出错�?) ||
                lowerMsg.Contains("帮我找bug"))
            {
                HandleDebugCommand(message);
                isProcessing = false;
                statusText = "就绪";
                return;
            }

            // 代码搜索命令
            if (lowerMsg.Contains("搜索代码") || lowerMsg.Contains("找代�?) ||
                lowerMsg.Contains("查找代码") || lowerMsg.Contains("找找"))
            {
                HandleCodeSearchCommand(message);
                isProcessing = false;
                statusText = "就绪";
                return;
            }

            // 接受差异
            if (lowerMsg.Contains("接受") || lowerMsg.Contains("confirm") || lowerMsg == "apply")
            {
                AcceptDiff();
                isProcessing = false;
                statusText = "就绪";
                return;
            }

            // 接受单个变更�?            if (lowerMsg.Contains("接受 ") && message.Length > 4)
            {
                var parts = message.Split(' ');
                if (parts.Length > 1 && int.TryParse(parts[1].Trim(), out int idx))
                {
                    AddMessage($"�?变更�?#{idx} 已标记接受\n💡 输入「接受」应用所有变�?, false);
                }
                isProcessing = false;
                statusText = "就绪";
                return;
            }

            // 代码解释命令
            if (lowerMsg.Contains("解释代码") || lowerMsg.Contains("解释这段代码") ||
                lowerMsg.Contains("代码解释") || lowerMsg.Contains("分析代码") ||
                lowerMsg.Contains("这段代码做了什�?) || lowerMsg.Contains("分析这段代码"))
            {
                ExplainSelectedCode();
                isProcessing = false;
                statusText = "就绪";
                return;
            }

            // 代码优化命令
            if (lowerMsg.Contains("优化代码") || lowerMsg.Contains("优化这段代码") ||
                lowerMsg.Contains("代码优化") || lowerMsg.Contains("改进代码") ||
                lowerMsg.Contains("如何优化") || lowerMsg.Contains("如何改进"))
            {
                OptimizeSelectedCode();
                isProcessing = false;
                statusText = "就绪";
                return;
            }

            if (lowerMsg.Contains("清除") || lowerMsg.Contains("clear"))
            {
                ClearHistory();
                isProcessing = false;
                statusText = "就绪";
                return;
            }

            if (lowerMsg.Contains("应用") || lowerMsg.Contains("保存代码"))
            {
                ApplyPendingCodes();
                isProcessing = false;
                statusText = "就绪";
                return;
            }

            if (lowerMsg.Contains("撤销"))
            {
                PerformUndo();
                isProcessing = false;
                statusText = "就绪";
                return;
            }

            if (lowerMsg.Contains("重做") || lowerMsg.Contains("redo"))
            {
                PerformRedo();
                isProcessing = false;
                statusText = "就绪";
                return;
            }

            if (lowerMsg.Contains("历史") && !lowerMsg.Contains("历史记录"))
            {
                ShowHistory();
                isProcessing = false;
                statusText = "就绪";
                return;
            }

            // 预览命令
            if (lowerMsg.Contains("预览") && !lowerMsg.Contains("预览历史"))
            {
                // 检查是否是预览单个
                var parts = message.Split(' ');
                if (parts.Length > 1 && int.TryParse(parts[1].Trim(), out int idx))
                {
                    ShowPreviewIndex(idx - 1);
                }
                else
                {
                    ShowPreview();
                }
                isProcessing = false;
                statusText = "就绪";
                return;
            }

            // 跳过命令
            if (lowerMsg.Contains("跳过"))
            {
                SkipPending();
                isProcessing = false;
                statusText = "就绪";
                return;
            }

            // 应用单个命令
            if (lowerMsg.Contains("应用 ") && message.Length > 4)
            {
                var parts = message.Split(' ');
                if (parts.Length > 1 && int.TryParse(parts[1].Trim(), out int idx))
                {
                    ApplySingleCode(idx - 1);
                }
                isProcessing = false;
                statusText = "就绪";
                return;
            }

            // 检查配�?            if (useCloud && string.IsNullOrEmpty(apiKey))
            {
                AddMessage("⚠️ 请先配置API Key！\n\n点击右上角「⚙️」打开设置�?, false);
                isProcessing = false;
                statusText = "需要配�?;
                return;
            }

            // 发送AI请求
            StartCoroutine(SendToAI(message));
        }

        IEnumerator SendToAI(string message)
        {
            statusText = "调用AI...";

            var requestBody = new AIRequest
            {
                model = useCloud ? modelId : localModel,
                messages = new List<AIMessage>()
            };

            string projectContext = GetProjectContext();

            requestBody.messages.Add(new AIMessage
            {
                role = "system",
                content = GetSystemPrompt(projectContext)
            });

            int historyLimit = Mathf.Min(chatHistory.Count, 10);
            for (int i = chatHistory.Count - historyLimit; i < chatHistory.Count; i++)
            {
                if (i >= 0)
                {
                    requestBody.messages.Add(new AIMessage
                    {
                        role = chatHistory[i].isUser ? "user" : "assistant",
                        content = chatHistory[i].content
                    });
                }
            }

            requestBody.messages.Add(new AIMessage
            {
                role = "user",
                content = message
            });

            string json = JsonUtility.ToJson(requestBody);
            var content = new StringContent(json, Encoding.UTF8, "application/json");

            string url = useCloud ? $"{modelEndpoint}/chat/completions" : $"{localUrl}/chat/completions";

            Task<HttpResponseMessage> task = httpClient.PostAsync(url, content);

            while (!task.IsCompleted)
            {
                yield return null;
            }

            try
            {
                var response = task.Result;
                string responseJson = response.Content.ReadAsStringAsync().Result;

                if (response.IsSuccessStatusCode)
                {
                    var aiResponse = JsonUtility.FromJson<AIResponse>(responseJson);
                    if (aiResponse.choices != null && aiResponse.choices.Count > 0)
                    {
                        string aiText = aiResponse.choices[0].message.content;
                        ParseCodeBlocks(aiText);
                        AddMessage(aiText, false);
                        statusText = "完成";
                        isConnected = true;
                    }
                    else
                    {
                        AddMessage("�?无法解析AI响应", false);
                        statusText = Tr("error");
                    }
                }
                else
                {
                    string errorMsg = response.StatusCode switch
                    {
                        System.Net.HttpStatusCode.Unauthorized => "�?API Key无效",
                        System.Net.HttpStatusCode.TooManyRequests => "�?请求过于频繁",
                        _ => $"�?请求失败: {response.StatusCode}"
                    };
                    AddMessage(errorMsg, false);
                    statusText = "请求失败";
                }
            }
            catch (Exception e)
            {
                AddMessage($"�?网络错误: {e.Message}", false);
                statusText = "网络错误";
            }

            isProcessing = false;
            Repaint();
        }

        string GetProjectContext()
        {
            if (currentProject == null) return "";

            return $@"
当前Unity项目信息:
- 项目名称: {currentProject.name}
- Unity版本: {currentProject.unityVersion}
- 场景�? {currentProject.sceneCount}
- 脚本�? {currentProject.scriptCount}
- 资源类型: {string.Join(", ", currentProject.resourceTypes)}
";
        }

                string GetSystemPrompt(string projectContext)
        {
            string lang = GetCurrentLang();
            
            if (lang == "zh")
            {
                return $@"你是一个专业的Unity游戏开发AI助手。
## 你的能力
1. 生成Unity C#脚本代码
2. 修改现有代码
3. 搜索免费可商用的游戏素材
4. 解释Unity概念和API
5. 诊断和修复Bug
6. 解答游戏开发问题

## 代码格式
使用C#，引用UnityEngine和UnityEngine.UI命名空间。
代码要有中文注释。
代码块使用```csharp标记。

## 功能提示
- 如果生成了代码，提示用户可以输入「应用代码」保存
- 回答要简洁实用，像和朋友聊天一样自然
- 可以建议用户使用知识库功能保存重要信息

{projectContext}";
            }
            else
            {
                return $@"You are a professional Unity game development AI assistant named Octopus.

## Your Capabilities
1. Generate Unity C# scripts
2. Modify existing code
3. Search for free commercially-usable game assets
4. Explain Unity concepts and APIs
5. Diagnose and fix bugs
6. Answer game development questions

## Code Format
Use C#, reference UnityEngine and UnityEngine.UI namespaces.
Add comments to code.
Use ```csharp for code blocks.

## Feature Tips
- If code is generated, remind user they can type 'Apply code' to save
- Be concise and practical, like chatting with a friend
- Suggest using Knowledge Base to save important information

{projectContext}";
            }
        }

        // ==================== Phase 4: 每日学习 ====================

        string[] learningTips = new string[]
        {
            "💡 使用对象池技术减少Instantiate/Destroy开销",
            "💡 使用 @SerializeField 私有字段可在Inspector显示",
            "💡 使用协程处理延迟和异步操�?,
            "💡 使用 ScriptableObject 存储配置数据",
            "💡 使用事件系统解耦组件通信",
            "💡 使用 Addressables 管理资源加载",
            "💡 使用 DOTween 简化动画制�?,
            "💡 使用 Odin Inspector 增强调试体验",
            "💡 使用 Profiler.FindObjectUsedByIdentifier 追踪性能问题",
            "💡 使用 #if UNITY_EDITOR 进行编辑器专用代�?
        };

        string[] learningTips_en = new string[]
        {
            "Use object pooling to reduce Instantiate/Destroy overhead",
            "Use @SerializeField to show private fields in Inspector",
            "Use coroutines for delayed and async operations",
            "Use ScriptableObject to store configuration data",
            "Use event systems to decouple component communication",
            "Use Addressables for resource management",
            "Use DOTween to simplify animation creation",
            "Use Odin Inspector to enhance debugging experience",
            "Use Profiler.FindObjectUsedByIdentifier to track performance",
            "Use #if UNITY_EDITOR for editor-only code"
        };

        void ShowTodayLearning()
        {
            int dayIndex = System.DateTime.Now.DayOfYear % learningTips.Length;
            string tip = learningTips[dayIndex];

            string report = $@"
📚 今日学习
━━━━━━━━━━━━━━━━━━━━━━�?
{tip}

💡 每天学习一点，进步一大步�?";

            AddMessage(report, false);
        }

        // ==================== Phase 5: 测试生成功能 ====================

        void ShowTestGeneration()
        {
            string report = @"
🧪 测试生成功能
━━━━━━━━━━━━━━━━━━━━━━�?
**使用方法:**
�?「为 XXX.cs 生成测试�? 为指定文件生成测�?�?「写单元测试�? 查看测试生成选项
�?「测�?PlayerController.cs�? 快速生成测�?
**支持的测试框�?**
�?NUnit - Unity 单元测试框架
�?PlayMode Tests - Unity PlayMode 测试

**测试内容:**
�?公共函数测试
�?边界条件测试
�?错误处理测试
�?集成测试

请告诉我要为哪个文件生成测试�?";

            AddMessage(report, false);
        }

        void GenerateTest(string targetFile)
        {
            if (string.IsNullOrEmpty(targetFile))
            {
                AddMessage("⚠️ 请指定要生成测试的目标文件\n\n使用方法：「为 PlayerController.cs 生成测试�?, false);
                return;
            }

            // 查找目标文件
            string targetPath = FindScriptFile(targetFile);

            if (string.IsNullOrEmpty(targetPath))
            {
                AddMessage($"⚠️ 文件不存�? {targetFile}\n\n请确保文件在 Assets/Scripts/ 目录�?, false);
                return;
            }

            try
            {
                string targetCode = File.ReadAllText(targetPath);
                string className = ExtractClassName(targetCode);
                var functions = AnalyzeFunctions(targetCode);

                // 生成测试代码
                string testCode = GenerateNUnitTestCode(className, functions, targetFile);

                // 保存测试文件
                string testFolder = $"{Application.dataPath}/Tests/";
                if (!Directory.Exists(testFolder))
                {
                    Directory.CreateDirectory(testFolder);
                }

                string testFileName = $"{className}Test.cs";
                string testPath = $"{testFolder}{testFileName}";

                File.WriteAllText(testPath, testCode);
                AssetDatabase.Refresh();

                AddMessage($@"
�?测试生成完成
━━━━━━━━━━━━━━━━━━━━━━�?
📁 测试文件: {testFileName}
📂 路径: Assets/Tests/{testFileName}
🧪 测试框架: NUnit
📋 测试用例�? {functions.Count}

💡 生成的测�?
�?实例创建测试
�?公共函数测试
�?边界条件测试

⚠️ 请根据实际需求完善测试用例！
", false);
            }
            catch (Exception e)
            {
                AddMessage($"�?测试生成失败: {e.Message}", false);
            }
        }

        string FindScriptFile(string fileName)
        {
            string scriptsPath = $"{Application.dataPath}/Scripts";

            if (!Directory.Exists(scriptsPath))
                return null;

            // 搜索文件
            var files = Directory.GetFiles(scriptsPath, "*.cs", SearchOption.AllDirectories);

            foreach (var file in files)
            {
                if (file.EndsWith(fileName, StringComparison.OrdinalIgnoreCase) ||
                    file.EndsWith(fileName.Replace("/", "\\"), StringComparison.OrdinalIgnoreCase))
                {
                    return file;
                }
            }

            return null;
        }

        string ExtractClassName(string code)
        {
            var lines = code.Split('\n');
            foreach (var line in lines)
            {
                line = line.Trim();
                if (line.Contains("class ") && !line.Contains("//"))
                {
                    int idx = line.IndexOf("class ") + 6;
                    int endIdx = line.IndexOfAny(new char[] { ' ', ':', '{' }, idx);
                    if (endIdx > idx)
                    {
                        return line.Substring(idx, endIdx - idx).Trim();
                    }
                }
            }
            return "";
        }

        List<FunctionInfo> AnalyzeFunctions(string code)
        {
            var functions = new List<FunctionInfo>();
            var lines = code.Split('\n');

            for (int i = 0; i < lines.Length; i++)
            {
                var line = lines[i].Trim();

                // 查找 public/private 方法
                if ((line.StartsWith("public ") || line.StartsWith("private ") || line.StartsWith("protected ")) &&
                    line.Contains("("))
                {
                    // 跳过字段
                    if (line.Contains("=") && line.IndexOf("(") > line.IndexOf("="))
                        continue;

                    var funcInfo = new FunctionInfo();

                    // 提取返回类型
                    var parts = line.Split(' ');
                    if (parts.Length >= 2)
                    {
                        funcInfo.ReturnType = parts[1];

                        // 提取方法�?                        int nameStart = 2;
                        if (parts[1] == "async")
                        {
                            funcInfo.ReturnType = "Task";
                            nameStart = 3;
                        }

                        if (nameStart < parts.Length)
                        {
                            var funcName = parts[nameStart];
                            funcName = funcName.Replace("(", "").Trim();
                            funcInfo.Name = funcName;
                        }
                    }

                    // 提取参数
                    int paramsStart = line.IndexOf("(");
                    int paramsEnd = line.IndexOf(")");
                    if (paramsStart != -1 && paramsEnd != -1)
                    {
                        var paramsStr = line.Substring(paramsStart + 1, paramsEnd - paramsStart - 1);
                        if (!string.IsNullOrEmpty(paramsStr))
                        {
                            var paramParts = paramsStr.Split(',');
                            foreach (var p in paramParts)
                            {
                                var paramPartsInner = p.Trim().Split(' ');
                                if (paramPartsInner.Length >= 2)
                                {
                                    funcInfo.Parameters.Add(paramPartsInner[1]);
                                }
                            }
                        }
                    }

                    if (!string.IsNullOrEmpty(funcInfo.Name) &&
                        !funcInfo.Name.StartsWith("_") &&
                        !funcInfo.Name.StartsWith("get_") &&
                        !funcInfo.Name.StartsWith("set_"))
                    {
                        functions.Add(funcInfo);
                    }
                }
            }

            return functions;
        }

        string GenerateNUnitTestCode(string className, List<FunctionInfo> functions, string originalFile)
        {
            var sb = new System.Text.StringBuilder();

            sb.AppendLine("using NUnit.Framework;");
            sb.AppendLine("using UnityEngine;");
            sb.AppendLine("using System.Collections;");
            sb.AppendLine();
            sb.AppendLine("namespace GameAIAssistant.Tests");
            sb.AppendLine("{");
            sb.AppendLine("    /// <summary>");
            sb.AppendLine($"    /// {className} 的单元测�?);
            sb.AppendLine($"    /// 生成时间: {System.DateTime.Now:yyyy-MM-dd HH:mm:ss}");
            sb.AppendLine($"    /// 源文�? {originalFile}");
            sb.AppendLine("    /// </summary>");
            sb.AppendLine("    [TestFixture]");
            sb.AppendLine($"    public class {className}Test");
            sb.AppendLine("    {");
            sb.AppendLine($"        private {className} _instance;");
            sb.AppendLine("        private GameObject _testObject;");
            sb.AppendLine();
            sb.AppendLine("        [SetUp]");
            sb.AppendLine("        public void SetUp()");
            sb.AppendLine("        {");
            sb.AppendLine("            // 每个测试前创建实�?);
            sb.AppendLine("            _testObject = new GameObject();");
            sb.AppendLine($"            _instance = _testObject.AddComponent<{className}>();");
            sb.AppendLine("        }");
            sb.AppendLine();
            sb.AppendLine("        [TearDown]");
            sb.AppendLine("        public void TearDown()");
            sb.AppendLine("        {");
            sb.AppendLine("            // 每个测试后清�?);
            sb.AppendLine("            if (_instance != null)");
            sb.AppendLine("            {");
            sb.AppendLine("                Object.DestroyImmediate(_testObject);");
            sb.AppendLine("            }");
            sb.AppendLine("        }");
            sb.AppendLine();

            // 生成测试方法
            foreach (var func in functions)
            {
                sb.AppendLine();
                sb.AppendLine("        [Test]");
                sb.AppendLine($"        public void {func.Name}_Test()");
                sb.AppendLine("        {");
                sb.AppendLine($"            // 测试 {func.Name}");
                sb.AppendLine($"            // 返回类型: {func.ReturnType}");
                sb.AppendLine($"            // 参数: {(func.Parameters.Count > 0 ? string.Join(", ", func.Parameters) : "�?)}");
                sb.AppendLine("            ");
                sb.AppendLine("            // TODO: 根据函数功能编写具体测试");
                sb.AppendLine("            ");
                sb.AppendLine("            // 示例:");

                if (func.ReturnType != "void" && func.ReturnType != "IEnumerator")
                {
                    sb.AppendLine($"            // var result = _instance.{func.Name}({GetDefaultParams(func.Parameters)});");
                    sb.AppendLine("            // Assert.IsNotNull(result);");
                }
                else
                {
                    sb.AppendLine($"            // _instance.{func.Name}({GetDefaultParams(func.Parameters)});");
                    sb.AppendLine("            // Assert.Pass();");
                }
                sb.AppendLine("        }");
            }

            sb.AppendLine("    }");
            sb.AppendLine("}");

            return sb.ToString();
        }

        string GetDefaultParams(List<string> parameters)
        {
            if (parameters.Count == 0) return "";

            var defaults = new List<string>();
            foreach (var p in parameters)
            {
                defaults.Add("default");
            }
            return string.Join(", ", defaults);
        }

        // ==================== Phase 5: 代码解释与优�?====================

        string selectedCode = "";

        void ExplainSelectedCode()
        {
            selectedCode = ExtractCodeFromInput(inputText);
            if (string.IsNullOrEmpty(selectedCode))
            {
                AddMessage(@"📝 **代码解释功能**

**使用方法:**
1. 在输入框中粘贴要解释的代�?2. 输入「解释代码」或「代码解释�?
支持的语言：C#, GDScript, Python, JavaScript

AI会详细分析：
�?代码整体功能
�?逐行/逐段逻辑
�?核心变量和函�?�?使用场景和建�?", false);
                return;
            }

            AddMessage("🔍 正在分析代码，请稍�?..", false);
            StartCoroutine(AnalyzeCodeWithAI(selectedCode, "explain"));
        }

        void OptimizeSelectedCode()
        {
            selectedCode = ExtractCodeFromInput(inputText);
            if (string.IsNullOrEmpty(selectedCode))
            {
                AddMessage(@"🔧 **代码优化功能**

**使用方法:**
1. 在输入框中粘贴要优化的代�?2. 输入「优化代码」或「代码优化�?
支持的语言：C#, GDScript, Python, JavaScript

AI会分析：
�?性能问题
�?代码可读�?�?安全性风�?�?最佳实践改�?�?并提供优化后的代�?", false);
                return;
            }

            AddMessage("🔧 正在优化代码，请稍�?..", false);
            StartCoroutine(AnalyzeCodeWithAI(selectedCode, "optimize"));
        }

        string ExtractCodeFromInput(string text)
        {
            // 支持 ```csharp ... ``` 格式
            int start = text.IndexOf("```");
            if (start >= 0)
            {
                int langEnd = text.IndexOf('\n', start + 3);
                if (langEnd < 0) return "";
                int codeStart = langEnd + 1;
                int end = text.IndexOf("```", codeStart);
                if (end < 0) return "";
                return text.Substring(codeStart, end - codeStart).Trim();
            }

            // 支持纯代码（检测代码特征）
            var lines = text.Split('\n');
            if (lines.Length > 2)
            {
                bool hasCodeChars = false;
                foreach (char c in text)
                {
                    if (c == '{' || c == '}' || c == '(' || c == ')' ||
                        text.Contains("void ") || text.Contains("public ") ||
                        text.Contains("class ") || text.Contains("function ") ||
                        text.Contains("func ") || text.Contains("def "))
                    {
                        hasCodeChars = true;
                        break;
                    }
                }
                if (hasCodeChars) return text.Trim();
            }

            return "";
        }

        IEnumerator AnalyzeCodeWithAI(string code, string analysisType)
        {
            isProcessing = true;
            statusText = "分析�?..";
            Repaint();

            var requestBody = new AIRequest
            {
                model = useCloud ? modelId : localModel,
                messages = new List<AIMessage>()
            };

            string systemPrompt = analysisType == "explain"
                ? @"你是一个专业的代码解释专家。请详细解释用户提供的代码�?
## 解释要求
请从以下几个维度进行解释�?1. **整体功能** - 这段代码做什�?2. **逐行/逐段解析** - 关键部分的逻辑
3. **核心变量和函�?* - 重要元素的作�?4. **使用场景** - 适合在什么情况下使用

请用中文回答，语言要简洁易懂。如果是C#请用Unity/C#术语�?
                : @"你是一个专业的代码优化专家。请分析用户提供的代码，并提供优化建议和优化后的代码�?
## 优化要求
请从以下几个维度进行分析�?1. **性能** - 是否有性能问题，如何改�?2. **可读�?* - 代码是否清晰易读，如何优�?3. **安全�?* - 是否有潜在的安全风险
4. **最佳实�?* - 是否遵循Unity/C#开发规�?
然后提供优化后的代码，用```csharp包裹�?
请用中文回答�?;

            requestBody.messages.Add(new AIMessage { role = "system", content = systemPrompt });
            requestBody.messages.Add(new AIMessage { role = "user", content = "代码:\n" + code });

            string json = JsonUtility.ToJson(requestBody);
            var content = new StringContent(json, Encoding.UTF8, "application/json");
            string url = useCloud ? $"{modelEndpoint}/chat/completions" : $"{localUrl}/chat/completions";

            Task<HttpResponseMessage> task = httpClient.PostAsync(url, content);

            while (!task.IsCompleted)
            {
                yield return null;
            }

            try
            {
                var response = task.Result;
                string responseJson = response.Content.ReadAsStringAsync().Result;

                if (response.IsSuccessStatusCode)
                {
                    var aiResponse = JsonUtility.FromJson<AIResponse>(responseJson);
                    if (aiResponse.choices != null && aiResponse.choices.Count > 0)
                    {
                        string aiText = aiResponse.choices[0].message.content;

                        string header = analysisType == "explain"
                            ? "📖 **代码解释完成**\n━━━━━━━━━━━━━━━━━━━━━━━\n"
                            : "🔧 **代码优化完成**\n━━━━━━━━━━━━━━━━━━━━━━━\n";

                        AddMessage(header + aiText, false);

                        if (analysisType == "optimize")
                        {
                            AddMessage("\n💡 如果需要应用优化后的代码，请复制上面的代码块后输入「应用�?, false);
                        }

                        statusText = "完成";
                        isConnected = true;
                    }
                    else
                    {
                        AddMessage("�?无法解析AI响应", false);
                        statusText = Tr("error");
                    }
                }
                else
                {
                    string errorMsg = response.StatusCode switch
                    {
                        System.Net.HttpStatusCode.Unauthorized => "�?API Key无效",
                        System.Net.HttpStatusCode.TooManyRequests => "�?请求过于频繁",
                        _ => $"�?请求失败: {response.StatusCode}"
                    };
                    AddMessage(errorMsg, false);
                    statusText = "请求失败";
                }
            }
            catch (Exception e)
            {
                AddMessage($"�?网络错误: {e.Message}", false);
                statusText = "网络错误";
            }

            isProcessing = false;
            inputText = "";
            Repaint();
        }

        // ==================== Phase 5: 差异对比功能 ====================

        void ShowDiffComparison()
        {
            if (!isShowingDiff)
            {
                AddMessage(@"
📊 差异对比功能
━━━━━━━━━━━━━━━━━━━━━━�?
**使用方法:**
�?「差异�? 查看当前差异
�?「diff�? 显示差异对比
�?「对比�? 查看代码变化

**操作选项:**
�?「接受�? 应用所有修�?�?「接�?1�? 只接受第1个变更块
�?「取消�? 放弃修改

当代码被修改时会自动显示差异对比�?", false);
            }
            else
            {
                ShowCurrentDiff();
            }
        }

        void ShowCurrentDiff()
        {
            if (string.IsNullOrEmpty(currentDiffFilePath))
            {
                AddMessage("⚠️ 没有可对比的差异", false);
                return;
            }

            var diffResult = FormatDiff(originalCodeCache, newCodeCache, currentDiffFilePath);

            string report = $@"
📊 代码差异对比
━━━━━━━━━━━━━━━━━━━━━━�?
📄 文件: {currentDiffFilePath}
━━━━━━━━━━━━━━━━━━━━━━�?
📊 差异统计:
   �?新增: {diffResult.Additions} �?   �?删除: {diffResult.Deletions} �?   📝 未变: {diffResult.Unchanged} �?
━━━━━━━━━━━━━━━━━━━━━━�?📝 详细变更:
━━━━━━━━━━━━━━━━━━━━━━�?{diffResult.DiffText}
━━━━━━━━━━━━━━━━━━━━━━�?
💡 操作选项:
�?「接受�? 应用所有修�?�?「接�?1�? 只接受第1个变更块
�?「取消�? 放弃修改
";

            AddMessage(report, false);
        }

        DiffResult FormatDiff(string original, string newCode, string filePath)
        {
            var result = new DiffResult();

            var oldLines = original.Split('\n');
            var newLines = newCode.Split('\n');

            var diffText = new System.Text.StringBuilder();
            int chunkNum = 1;
            bool inChunk = false;

            for (int i = 0; i < Mathf.Max(oldLines.Length, newLines.Length); i++)
            {
                var oldLine = i < oldLines.Length ? oldLines[i] : null;
                var newLine = i < newLines.Length ? newLines[i] : null;

                if (oldLine == newLine)
                {
                    if (inChunk)
                    {
                        diffText.AppendLine("━━━━━━━━━━━━━━━━━━━━━━�?);
                        chunkNum++;
                        inChunk = false;
                    }
                    result.Unchanged++;
                    if (oldLine != null)
                        diffText.AppendLine("  " + oldLine);
                }
                else
                {
                    if (!inChunk)
                    {
                        diffText.AppendLine($"\n变更�?#{chunkNum}:");
                        inChunk = true;
                    }

                    if (oldLine != null)
                    {
                        result.Deletions++;
                        diffText.AppendLine("-" + oldLine);
                    }

                    if (newLine != null)
                    {
                        result.Additions++;
                        diffText.AppendLine("+" + newLine);
                    }
                }
            }

            result.DiffText = diffText.ToString();
            return result;
        }

        void SetDiffState(string original, string newCode, string filePath)
        {
            originalCodeCache = original;
            newCodeCache = newCode;
            currentDiffFilePath = filePath;
            isShowingDiff = true;

            ShowCurrentDiff();
        }

        void AcceptDiff()
        {
            if (!isShowingDiff || string.IsNullOrEmpty(currentDiffFilePath))
            {
                AddMessage("⚠️ 没有可接受的差异", false);
                return;
            }

            try
            {
                // 保存原始代码备份
                string backupPath = currentDiffFilePath + ".backup";
                if (File.Exists(currentDiffFilePath))
                {
                    File.Copy(currentDiffFilePath, backupPath, true);
                }

                // 应用新代�?                File.WriteAllText(currentDiffFilePath, newCodeCache);

                // 添加到撤销历史
                var history = new UndoHistory
                {
                    action = "apply",
                    filePath = currentDiffFilePath,
                    fileName = Path.GetFileName(currentDiffFilePath),
                    originalCode = originalCodeCache,
                    newCode = newCodeCache,
                    hasBackup = true,
                    timestamp = System.DateTime.Now.ToString()
                };

                undoStack.Add(history);

                // 清除差异状�?                originalCodeCache = "";
                newCodeCache = "";
                currentDiffFilePath = "";
                isShowingDiff = false;

                AssetDatabase.Refresh();

                AddMessage($"�?已应用所有修改\n\n📁 {Path.GetFileName(currentDiffFilePath)}", false);
            }
            catch (Exception e)
            {
                AddMessage($"�?应用失败: {e.Message}", false);
            }
        }

        // ==================== Phase 4: 知识库====================

        void ShowKnowledgeBase()
        {
            var stats = knowledgeBase.GetStats();

            string report = $@"
📖 知识库━━━━━━━━━━━━━━━━━━━━━━�?
📊 统计信息
━━━━━━━━━━
📚 总条目数: {stats.totalEntries}
🏷�?总标签数: {stats.totalTags}

💡 命令�?�?「添加知�?标题|内容�? 添加知识
�?「搜索知�?关键词�? 搜索知识
�?「知识库�? 查看统计

🔧 输入「帮助」查看所有命�?";

            AddMessage(report, false);
        }

        // ==================== Phase 5: 调试助手 ====================

        void HandleDebugCommand(string message)
        {
            string lowerMsg = message.ToLower();

            // 检查是否是直接粘贴错误日志
            if (lowerMsg.Contains("error") || lowerMsg.Contains("exception") ||
                lowerMsg.Contains("null") || lowerMsg.Contains("nullreference"))
            {
                AnalyzeErrorLog(message);
                return;
            }

            // 通用调试模式
            AddMessage(@"🐛 **调试助手已启�?*

请告诉我�?1. **错误信息** - 粘贴完整的错误日�?2. **问题描述** - 什么情况下出现问题
3. **期望行为** - 你想要什么效�?
**调试命令**
�?「调试�? 启动调试模式
�?「添加断点�? 获取断点设置建议
�?「生成日志�? 获取调试日志代码

💡 直接粘贴错误信息，AI会自动分析！", false);
        }

        void AnalyzeErrorLog(string errorLog)
        {
            string errorType = ExtractErrorType(errorLog);
            string errorMsg = ExtractErrorMessage(errorLog);
            var causes = AnalyzeErrorType(errorType);

            string report = $@"
🐛 **错误分析报告**

**错误类型:** {errorType}
**错误信息:** {errorMsg}

━━━━━━━━━━━━━━━━━━━━━━�?
**🔍 可能原因:**

";

            for (int i = 0; i < causes.Count; i++)
            {
                report += $"{i + 1}. {causes[i]}\n";
            }

            report += @"
━━━━━━━━━━━━━━━━━━━━━━�?
**🔧 解决方案建议:**

�?**添加空值检�?*: if (obj != null) { ... }
�?**检查数组边�?*: index >= 0 && index < array.Length
�?**使用调试日志**: Debug.Log() 输出变量�?
━━━━━━━━━━━━━━━━━━━━━━�?
**💡 调试技�?*

�?使用 Debug.Log() 输出变量�?�?使用 Debug.LogWarning() 输出警告
�?使用 Debug.LogError() 输出错误信息
�?在可疑代码处设置断点

**下一步操�?*
�?输入「添加断点�? 生成断点设置建议
�?输入「生成日志�? 生成调试日志代码
";

            AddMessage(report, false);
        }

        string ExtractErrorType(string log)
        {
            string lower = log.ToLower();

            if (lower.Contains("null") && (lower.Contains("reference") || lower.Contains("pointer")))
                return "空引用异�?(NullReferenceException)";
            if (lower.Contains("index") && lower.Contains("out of range"))
                return "数组越界 (IndexOutOfRangeException)";
            if (lower.Contains("invalid call") || (lower.Contains("call") && lower.Contains("none")))
                return "无效方法调用";
            if (lower.Contains("parsing") || lower.Contains("syntax"))
                return "语法错误 (Syntax Error)";
            if (lower.Contains("type") && lower.Contains("mismatch"))
                return "类型不匹�?(Type Mismatch)";
            if (lower.Contains("file") && lower.Contains("not found"))
                return "文件未找�?;
            if (lower.Contains("permission") || lower.Contains("access"))
                return "权限访问错误";

            return "未知错误类型";
        }

        string ExtractErrorMessage(string log)
        {
            var lines = log.Split('\n');
            foreach (var line in lines)
            {
                if (line.ToLower().Contains("error") || line.ToLower().Contains("exception"))
                    return line.Trim();
            }
            return "未找到具体错误信�?;
        }

        List<string> AnalyzeErrorType(string errorType)
        {
            var causes = new List<string>();

            if (errorType.Contains("空引�?))
            {
                causes.Add("变量未初始化就使�?);
                causes.Add("对象引用为null");
                causes.Add("异步加载的资源尚未加载完�?);
                causes.Add("数组/列表访问了不存在的索�?);
            }
            else if (errorType.Contains("数组越界"))
            {
                causes.Add("循环索引超出数组长度");
                causes.Add("使用 -1 作为索引访问");
                causes.Add("数组为空时访问第一个元�?);
            }
            else if (errorType.Contains("无效方法调用"))
            {
                causes.Add("调用了不存在的函�?);
                causes.Add("在对象为null时调用其方法");
                causes.Add("参数数量或类型不匹配");
            }
            else
            {
                causes.Add("参数传递错�?);
                causes.Add("资源加载失败");
                causes.Add("外部依赖未正确配�?);
            }

            return causes;
        }

        // ==================== Phase 5: 代码搜索 ====================

        void HandleCodeSearchCommand(string message)
        {
            string lowerMsg = message.ToLower();
            string query = "";

            // 提取搜索关键�?            if (lowerMsg.Contains("搜索代码:"))
                query = message.Substring(message.IndexOf(":") + 1).Trim();
            else if (lowerMsg.Contains("找代�?"))
                query = message.Substring(message.IndexOf(":") + 1).Trim();
            else if (lowerMsg.Contains("查找代码:"))
                query = message.Substring(message.IndexOf(":") + 1).Trim();
            else if (lowerMsg.Contains("找找"))
                query = message.Substring(message.IndexOf("找找") + 2).Trim();
            else if (lowerMsg.Contains("搜索代码"))
                query = message.Substring(message.IndexOf("搜索代码") + 4).Trim();

            if (string.IsNullOrEmpty(query))
            {
                AddMessage(@"🔍 **代码搜索**

请告诉我你想搜索什么？

**示例**
�?「搜索代�?移动�? 搜索移动相关代码
�?「找找Player�? 搜索Player相关代码
�?「搜索代�?碰撞检测�? 搜索碰撞检测代�?
💡 可以搜索函数名、变量名、类名或关键�?, false);
                return;
            }

            SearchCode(query);
        }

        void SearchCode(string query)
        {
            string projectPath = Application.dataPath;
            var results = new List<CodeSearchResult>();

            // 搜索所有C#脚本
            string[] scripts = Directory.GetFiles(projectPath, "*.cs", SearchOption.AllDirectories);

            foreach (var script in scripts)
            {
                try
                {
                    string content = File.ReadAllText(script);
                    string[] lines = content.Split('\n');
                    var matches = new List<CodeMatch>();

                    for (int i = 0; i < lines.Length; i++)
                    {
                        if (lines[i].ToLower().Contains(query.ToLower()))
                        {
                            matches.Add(new CodeMatch
                            {
                                lineNumber = i + 1,
                                content = lines[i].Trim(),
                                preview = MakePreview(lines[i], query)
                            });
                        }
                    }

                    if (matches.Count > 0)
                    {
                        string relativePath = script.Replace(projectPath + "/", "");
                        results.Add(new CodeSearchResult
                        {
                            filePath = script,
                            relativePath = relativePath,
                            fileName = Path.GetFileName(script),
                            matches = matches,
                            matchCount = matches.Count
                        });
                    }
                }
                catch { }
            }

            if (results.Count == 0)
            {
                AddMessage($"🔍 没有找到匹配「{query}」的代码\n\n💡 建议：\n�?尝试更简短的关键词\n�?检查拼写是否正确\n�?使用相关函数名或变量名搜�?, false);
                return;
            }

            string report = $"🔍 代码搜索结果\n━━━━━━━━━━━━━━━━━━━━━━━\n📊 找到 {results.Count} 个匹配文件\n\n";

            for (int i = 0; i < Mathf.Min(5, results.Count); i++)
            {
                var r = results[i];
                report += $"📄 {r.fileName} (匹配 {r.matchCount} �?\n";
                report += $"   路径: {r.relativePath}\n";

                if (r.matches.Count > 0)
                {
                    string preview = r.matches[0].preview;
                    if (preview.Length > 60)
                        preview = preview.Substring(0, 60) + "...";
                    report += $"   预览: {preview}\n";
                }
                report += "\n";
            }

            if (results.Count > 5)
                report += $"...还有 {results.Count - 5} 个文件匹配\n\n";

            report += "💡 输入「跳转到:文件名」打开对应文件";

            AddMessage(report, false);
        }

        string MakePreview(string line, string query)
        {
            string preview = line.Trim();
            if (preview.Length > 100)
            {
                int idx = preview.ToLower().IndexOf(query.ToLower());
                if (idx >= 0)
                {
                    int start = Mathf.Max(0, idx - 30);
                    int end = Mathf.Min(preview.Length, idx + query.Length + 50);
                    preview = "..." + preview.Substring(start, end - start) + "...";
                }
                else
                {
                    preview = preview.Substring(0, 100) + "...";
                }
            }
            return preview;
        }

        void AddKnowledge(string message)
        {
            // 格式: 添加知识:标题|内容
            string content = message.Substring(message.IndexOf(":") + 1);
            string[] parts = content.Split('|');

            if (parts.Length >= 2)
            {
                string title = parts[0].Trim();
                string body = parts[1].Trim();

                knowledgeBase.AddEntry(title, body);
                AddMessage($"�?知识已添�?\n\n📝 {title}\n{body}", false);
            }
            else
            {
                AddMessage("⚠️ 格式: 添加知识:标题|内容", false);
            }
        }

        void SearchKnowledge(string message)
        {
            string keyword = message.Substring(message.IndexOf(":") + 1).Trim();
            var results = knowledgeBase.Search(keyword);

            if (results.Count == 0)
            {
                AddMessage($"🔍 没有找到相关知识: {keyword}", false);
            }
            else
            {
                string report = $"🔍 搜索结果 ({results.Count}�?:\n\n";
                foreach (var entry in results.Take(5))
                {
                    report += $"📝 {entry.title}\n{entry.content.Substring(0, Mathf.Min(100, entry.content.Length))}...\n\n";
                }
                AddMessage(report, false);
            }
        }

        void LoadKnowledge()
        {
            string path = Application.persistentDataPath + "/knowledge.json";
            if (File.Exists(path))
            {
                string json = File.ReadAllText(path);
                knowledgeBase = JsonUtility.FromJson<KnowledgeBase>(json);
            }
        }

        void SaveKnowledge()
        {
            string path = Application.persistentDataPath + "/knowledge.json";
            string json = JsonUtility.ToJson(knowledgeBase);
            File.WriteAllText(path, json);
        }

        // ==================== 项目模板系统 ====================

        // 项目模板数据
        class ProjectTemplate
        {
            public string id;
            public string name;
            public string description;
            public string[] features;
        }

        private bool showProjectTemplateWindow = false;
        private Vector2 templateScrollPosition;

        private ProjectTemplate[] projectTemplates = new ProjectTemplate[]
        {
            new ProjectTemplate {
                id = "2d_platformer",
                name = "2D 平台跳跃",
                description = "经典的横版平台跳跃游�?,
                features = new string[] { "玩家角色", "平台", "金币收集", "敌人", "关卡切换" }
            },
            new ProjectTemplate {
                id = "3d_fps",
                name = "3D 第一人称射击",
                description = "第一人称射击游戏模板",
                features = new string[] { "FPS控制�?, "武器系统", "敌人AI", "弹药管理", "分数系统" }
            },
            new ProjectTemplate {
                id = "2d_topdown_shooter",
                name = "2D 俯视角射�?,
                description = "俯视角射击游戏模�?,
                features = new string[] { "玩家控制�?, "弹幕系统", "道具掉落", "波次系统", "商店" }
            },
            new ProjectTemplate {
                id = "3d_third_person",
                name = "3D 第三人称动作",
                description = "第三人称动作冒险游戏模板",
                features = new string[] { "角色控制�?, "相机跟随", "攻击系统", "敌人AI", "生命�? }
            },
            new ProjectTemplate {
                id = "casual_puzzle",
                name = "休闲益智游戏",
                description = "轻松休闲的益智游戏模�?,
                features = new string[] { "关卡系统", "计时�?, "分数系统", "道具使用", "通关判定" }
            },
            new ProjectTemplate {
                id = "rpg",
                name = "RPG 角色扮演",
                description = "经典RPG角色扮演游戏模板",
                features = new string[] { "角色属�?, "装备系统", "技能树", "任务系统", "商店交易" }
            }
        };

        // 场景生成系统
        class SceneElement
        {
            public string type;
            public string name;
            public Vector3 position;
            public Vector3 scale;
        }

        class SceneConfig
        {
            public string type;
            public List<SceneElement> elements = new List<SceneElement>();
        }

        private bool showSceneGenWindow = false;
        private Vector2 sceneScrollPosition;
        private string sceneDescription = "";

        // 快捷场景预设
        private Dictionary<string, SceneConfig> scenePresets = new Dictionary<string, SceneConfig>();

        void InitScenePresets()
        {
            // 简单关卡预�?            scenePresets["simple_level"] = new SceneConfig {
                type = "platformer_level",
                elements = new List<SceneElement> {
                    new SceneElement { type = "player_spawn", name = "PlayerSpawn", position = new Vector3(-5, 0, 0) },
                    new SceneElement { type = "platform", name = "Ground", position = new Vector3(0, -2, 0), scale = new Vector3(10, 1, 1) },
                    new SceneElement { type = "collectible", name = "Coin1", position = new Vector3(-2, 0, 0) },
                    new SceneElement { type = "collectible", name = "Coin2", position = new Vector3(2, 0, 0) },
                    new SceneElement { type = "enemy", name = "Enemy1", position = new Vector3(0, 0, 0) },
                    new SceneElement { type = "goal", name = "Goal", position = new Vector3(6, 0, 0) }
                }
            };

            // 战斗场景预设
            scenePresets["battle_arena"] = new SceneConfig {
                type = "battle_arena",
                elements = new List<SceneElement> {
                    new SceneElement { type = "player_spawn", name = "PlayerSpawn", position = new Vector3(0, 0, 0) },
                    new SceneElement { type = "enemy", name = "Enemy1", position = new Vector3(-3, 0, -3) },
                    new SceneElement { type = "enemy", name = "Enemy2", position = new Vector3(3, 0, -3) },
                    new SceneElement { type = "obstacle", name = "Cover1", position = new Vector3(0, 0, -5), scale = new Vector3(2, 2, 2) },
                    new SceneElement { type = "obstacle", name = "Cover2", position = new Vector3(-3, 0, 3), scale = new Vector3(2, 2, 2) },
                    new SceneElement { type = "obstacle", name = "Cover3", position = new Vector3(3, 0, 3), scale = new Vector3(2, 2, 2) }
                }
            };

            // Boss房间预设
            scenePresets["boss_room"] = new SceneConfig {
                type = "boss_room",
                elements = new List<SceneElement> {
                    new SceneElement { type = "player_spawn", name = "PlayerSpawn", position = new Vector3(-8, 0, 0) },
                    new SceneElement { type = "spawner", name = "BossSpawn", position = new Vector3(0, 0, 0) },
                    new SceneElement { type = "goal", name = "Exit", position = new Vector3(8, 0, 0) }
                }
            };
        }

        void ShowProjectTemplates()
        {
            showProjectTemplateWindow = true;
            showSceneGenWindow = false;
        }

        void ShowSceneGenerator()
        {
            showSceneGenWindow = true;
            showProjectTemplateWindow = false;
            if (scenePresets.Count == 0)
                InitScenePresets();
        }

        void DrawProjectTemplateWindow()
        {
            if (!showProjectTemplateWindow) return;

            GUILayout.BeginArea(new Rect(10, 300, 350, 400), "🏗�?项目模板", GUI.skin.window);

            templateScrollPosition = EditorGUILayout.BeginScrollView(templateScrollPosition);

            GUILayout.Label("选择项目类型开始创建：", EditorStyles.boldLabel);
            EditorGUILayout.Space();

            for (int i = 0; i < projectTemplates.Length; i++)
            {
                var template = projectTemplates[i];

                EditorGUILayout.BeginHorizontal("box");

                GUILayout.BeginVertical();
                GUILayout.Label($"{(i + 1)}. {template.name}", EditorStyles.boldLabel);
                GUILayout.Label(template.description, EditorStyles.miniLabel);

                GUILayout.BeginHorizontal();
                foreach (var feature in template.features)
                {
                    GUILayout.Label($"[{feature}]", EditorStyles.miniLabel);
                }
                GUILayout.EndHorizontal();
                GUILayout.EndVertical();

                if (GUILayout.Button("创建", GUILayout.Width(60)))
                {
                    CreateProjectTemplate(template);
                }

                EditorGUILayout.EndHorizontal();
                EditorGUILayout.Space(5);
            }

            EditorGUILayout.EndScrollView();

            GUILayout.Space();
            if (GUILayout.Button("关闭"))
            {
                showProjectTemplateWindow = false;
            }

            GUILayout.EndArea();
        }

        void CreateProjectTemplate(ProjectTemplate template)
        {
            AddMessage($"�?正在创建【{template.name}】模�?..", false);

            // 生成项目结构
            var generatedFiles = GenerateTemplateFiles(template);

            string report = $@"�?【{template.name}】模板创建成功！

📊 生成的文�?({generatedFiles.Count}�?�?";

            foreach (var file in generatedFiles)
            {
                report += $"�?{file.Key}\n";
            }

            report += @"
💡 下一步：
�?查看 Assets/Scripts 目录
�?在场景中添加生成的预制体
�?根据需要修改代�?";

            AddMessage(report, false);
            showProjectTemplateWindow = false;
        }

        Dictionary<string, string> GenerateTemplateFiles(ProjectTemplate template)
        {
            var files = new Dictionary<string, string>();

            switch (template.id)
            {
                case "2d_platformer":
                    files = Generate2DPlatformerFiles();
                    break;
                case "3d_fps":
                    files = Generate3DFPSFiles();
                    break;
                case "2d_topdown_shooter":
                    files = Generate2DTopDownFiles();
                    break;
                case "3d_third_person":
                    files = Generate3DThirdPersonFiles();
                    break;
                case "casual_puzzle":
                    files = GenerateCasualPuzzleFiles();
                    break;
                case "rpg":
                    files = GenerateRPGFiles();
                    break;
            }

            // 保存文件到项�?            foreach (var kvp in files)
            {
                SaveScriptFile(kvp.Key, kvp.Value);
            }

            return files;
        }

        Dictionary<string, string> Generate2DPlatformerFiles()
        {
            return new Dictionary<string, string>
            {
                ["PlayerController.cs"] = @"using UnityEngine;

/// <summary>
/// 2D平台跳跃玩家控制�?/// </summary>
public class PlayerController : MonoBehaviour
{
    [Header("移动设置")]
    public float moveSpeed = 8f;
    public float jumpForce = 12f;
    public int maxJumps = 2;

    [Header("组件引用")]
    public LayerMask groundLayer;
    public Transform groundCheck;

    private Rigidbody2D rb;
    private int jumpCount;
    private bool isGrounded;

    void Start()
    {
        rb = GetComponent<Rigidbody2D>();
    }

    void Update()
    {
        // 地面检�?        isGrounded = Physics2D.OverlapCircle(groundCheck.position, 0.1f, groundLayer);
        if (isGrounded) jumpCount = 0;

        // 水平移动
        float horizontal = Input.GetAxis(""Horizontal"");
        rb.velocity = new Vector2(horizontal * moveSpeed, rb.velocity.y);

        // 跳跃
        if (Input.GetButtonDown(""Jump"") && jumpCount < maxJumps)
        {
            rb.velocity = new Vector2(rb.velocity.x, jumpForce);
            jumpCount++;
        }
    }

    void OnTriggerEnter2D(Collider2D other)
    {
        // 收集物品
        if (other.CompareTag(""Collectible""))
        {
            other.gameObject.SetActive(false);
            GameManager.Instance.AddScore(10);
        }

        // 到达终点
        if (other.CompareTag(""Goal""))
        {
            GameManager.Instance.NextLevel();
        }
    }
}",

                ["EnemyController.cs"] = @"using UnityEngine;

/// <summary>
/// 巡逻敌人AI
/// </summary>
public class EnemyController : MonoBehaviour
{
    public float speed = 3f;
    public float patrolDistance = 5f;
    public float health = 100f;
    public float damage = 20f;

    private Vector3 startPosition;
    private int moveDirection = 1;
    private bool isChasing;

    void Start()
    {
        startPosition = transform.position;
    }

    void Update()
    {
        if (!isChasing)
        {
            // 巡�?            transform.Translate(Vector2.right * speed * moveDirection * Time.deltaTime);

            if (Vector3.Distance(transform.position, startPosition) > patrolDistance)
            {
                moveDirection *= -1;
                transform.localScale = new Vector3(-moveDirection, 1, 1);
            }
        }
    }

    void OnTriggerEnter2D(Collider2D other)
    {
        if (other.CompareTag(""Player""))
        {
            other.GetComponent<PlayerController>()?.TakeDamage(damage);
        }
    }

    public void TakeDamage(float amount)
    {
        health -= amount;
        if (health <= 0)
        {
            Destroy(gameObject);
        }
    }
}",

                ["GameManager.cs"] = @"using UnityEngine;
using UnityEngine.SceneManagement;

/// <summary>
/// 游戏管理�?/// </summary>
public class GameManager : MonoBehaviour
{
    public static GameManager Instance { get; private set; }

    [Header("游戏状�?)]
    public int score;
    public int lives = 3;
    public int currentLevel = 1;
    public bool isPaused;

    void Awake()
    {
        if (Instance == null)
            Instance = this;
        else
            Destroy(gameObject);
    }

    public void AddScore(int amount)
    {
        score += amount;
        Debug.Log($""分数: {score}"");
    }

    public void LoseLife()
    {
        lives--;
        if (lives <= 0)
        {
            GameOver();
        }
    }

    public void NextLevel()
    {
        currentLevel++;
        SceneManager.LoadScene($""Level_{currentLevel}"");
    }

    void GameOver()
    {
        Debug.Log(""游戏结束�?");
        SceneManager.LoadScene(""GameOver"");
    }
}"
            };
        }

        Dictionary<string, string> Generate3DFPSFiles()
        {
            return new Dictionary<string, string>
            {
                ["FPSController.cs"] = @"using UnityEngine;

/// <summary>
/// 3D FPS控制�?/// </summary>
public class FPSController : MonoBehaviour
{
    [Header("移动设置")]
    public float moveSpeed = 5f;
    public float jumpForce = 5f;
    public float mouseSensitivity = 2f;

    [Header("组件引用")]
    public Camera playerCamera;
    public CharacterController controller;

    private float verticalVelocity;
    private float cameraRotation;

    void Start()
    {
        Cursor.lockState = CursorLockMode.Locked;
    }

    void Update()
    {
        MovePlayer();
        RotateCamera();
    }

    void MovePlayer()
    {
        float x = Input.GetAxis(""Horizontal"");
        float z = Input.GetAxis(""Vertical"");

        Vector3 move = transform.right * x + transform.forward * z;
        move *= moveSpeed;

        // 跳跃
        if (controller.isGrounded && Input.GetButton(""Jump""))
        {
            verticalVelocity = jumpForce;
        }

        verticalVelocity += Physics.gravity.y * Time.deltaTime;
        move.y = verticalVelocity;

        controller.Move(move * Time.deltaTime);
    }

    void RotateCamera()
    {
        float mouseX = Input.GetAxis(""Mouse X"") * mouseSensitivity;
        float mouseY = Input.GetAxis(""Mouse Y"") * mouseSensitivity;

        cameraRotation -= mouseY;
        cameraRotation = Mathf.Clamp(cameraRotation, -90f, 90f);

        playerCamera.transform.localRotation = Quaternion.Euler(cameraRotation, 0, 0);
        transform.rotation *= Quaternion.Euler(0, mouseX, 0);
    }
}",

                ["WeaponSystem.cs"] = @"using UnityEngine;

/// <summary>
/// FPS武器系统
/// </summary>
public class WeaponSystem : MonoBehaviour
{
    [Header("武器属�?)]
    public float damage = 25f;
    public float fireRate = 0.1f;
    public float reloadTime = 2f;
    public int maxAmmo = 30;
    public int maxReserve = 90;

    [Header("组件引用")]
    public Camera cam;
    public ParticleSystem muzzleFlash;

    private int currentAmmo;
    private int reserveAmmo;
    private bool isReloading;
    private bool canFire = true;

    void Start()
    {
        currentAmmo = maxAmmo;
        reserveAmmo = maxReserve;
    }

    void Update()
    {
        if (Input.GetButton(""Fire1"") && canFire && !isReloading)
        {
            Fire();
        }

        if (Input.GetKeyDown(KeyCode.R))
        {
            Reload();
        }
    }

    void Fire()
    {
        if (currentAmmo <= 0)
        {
            Reload();
            return;
        }

        currentAmmo--;
        canFire = false;

        // 发射射线
        Ray ray = cam.ViewportPointToRay(new Vector3(0.5f, 0.5f, 0));
        if (Physics.Raycast(ray, out RaycastHit hit))
        {
            if (hit.collider.CompareTag(""Enemy""))
            {
                hit.collider.GetComponent<EnemyController>()?.TakeDamage(damage);
            }
        }

        // 枪口闪光
        if (muzzleFlash) muzzleFlash.Play();

        Invoke(nameof(ResetFire), fireRate);
    }

    void ResetFire()
    {
        canFire = true;
        if (currentAmmo <= 0) Reload();
    }

    void Reload()
    {
        if (isReloading || reserveAmmo <= 0) return;

        isReloading = true;
        Invoke(nameof(FinishReload), reloadTime);
    }

    void FinishReload()
    {
        int needed = maxAmmo - currentAmmo;
        int toReload = Mathf.Min(needed, reserveAmmo);
        currentAmmo += toReload;
        reserveAmmo -= toReload;
        isReloading = false;
    }
}"
            };
        }

        Dictionary<string, string> Generate2DTopDownFiles()
        {
            return new Dictionary<string, string>
            {
                ["TopDownController.cs"] = @"using UnityEngine;

/// <summary>
/// 俯视角射击玩家控制器
/// </summary>
public class TopDownController : MonoBehaviour
{
    [Header("移动设置")]
    public float moveSpeed = 200f;
    public float rotationSpeed = 5f;
    public float fireRate = 0.2f;
    public float bulletSpeed = 400f;
    public float bulletDamage = 10f;

    private bool canFire = true;
    private Vector2 aimDirection = Vector2.right;

    void Update()
    {
        HandleMovement();
        HandleAim();
        HandleShoot();
    }

    void HandleMovement()
    {
        float h = Input.GetAxis(""Horizontal"");
        float v = Input.GetAxis(""Vertical"");

        Vector2 direction = new Vector2(h, v);
        if (direction.magnitude > 0)
            direction.Normalize();

        GetComponent<Rigidbody2D>()?.MovePosition(
            transform.position + (Vector3)direction * moveSpeed * Time.deltaTime);
    }

    void HandleAim()
    {
        Vector3 mousePos = Camera.main.ScreenToWorldPoint(Input.mousePosition);
        aimDirection = (mousePos - transform.position).normalized;
        float angle = Mathf.Atan2(aimDirection.y, aimDirection.x) * Mathf.Rad2Deg;
        transform.rotation = Quaternion.Lerp(
            transform.rotation,
            Quaternion.Euler(0, 0, angle),
            rotationSpeed * Time.deltaTime);
    }

    void HandleShoot()
    {
        if (Input.GetButton(""Fire1"") && canFire)
        {
            Shoot();
        }
    }

    void Shoot()
    {
        canFire = false;

        // 生成子弹
        var bullet = Instantiate(Resources.Load(""Bullet""), transform.position, transform.rotation);
        bullet?.GetComponent<Rigidbody2D>()?.AddForce(aimDirection * bulletSpeed);

        Invoke(nameof(ResetFire), fireRate);
    }

    void ResetFire() => canFire = true;
}",

                ["WaveManager.cs"] = @"using UnityEngine;
using System.Collections;

/// <summary>
/// 波次系统
/// </summary>
public class WaveManager : MonoBehaviour
{
    public int totalWaves = 10;
    public int enemiesPerWaveBase = 5;
    public float spawnDelay = 1f;

    private int currentWave;
    private int enemiesRemaining;

    public void StartWave()
    {
        currentWave++;
        int enemyCount = enemiesPerWaveBase + currentWave * 2;

        StartCoroutine(SpawnEnemies(enemyCount));
    }

    IEnumerator SpawnEnemies(int count)
    {
        for (int i = 0; i < count; i++)
        {
            SpawnEnemy();
            yield return new WaitForSeconds(spawnDelay);
        }
    }

    void SpawnEnemy()
    {
        Vector3 spawnPos = GetRandomSpawnPosition();
        Instantiate(Resources.Load(""Enemy""), spawnPos, Quaternion.identity);
        enemiesRemaining++;
    }

    Vector3 GetRandomSpawnPosition()
    {
        Vector3 pos = Camera.main.transform.position;
        float side = Random.Range(0f, 4f);

        switch ((int)side)
        {
            case 0: return pos + Vector3.up * 8;
            case 1: return pos + Vector3.down * 8;
            case 2: return pos + Vector3.left * 12;
            default: return pos + Vector3.right * 12;
        }
    }

    public void OnEnemyDefeated()
    {
        enemiesRemaining--;
        if (enemiesRemaining <= 0)
        {
            Debug.Log($""波次 {currentWave} 完成�?");
        }
    }
}"
            };
        }

        Dictionary<string, string> Generate3DThirdPersonFiles()
        {
            return new Dictionary<string, string>
            {
                ["ThirdPersonController.cs"] = @"using UnityEngine;

/// <summary>
/// 第三人称角色控制�?/// </summary>
public class ThirdPersonController : MonoBehaviour
{
    [Header("移动设置")]
    public float moveSpeed = 5f;
    public float sprintSpeed = 8f;
    public float jumpForce = 5f;
    public float mouseSensitivity = 2f;

    [Header("组件引用")]
    public Transform cameraPivot;
    public CharacterController characterController;

    private float verticalVelocity;
    private float cameraYaw;

    void Start()
    {
        Cursor.lockState = CursorLockMode.Locked;
    }

    void Update()
    {
        MovePlayer();
        RotateCamera();
        HandleJump();
    }

    void MovePlayer()
    {
        float h = Input.GetAxis(""Horizontal"");
        float v = Input.GetAxis(""Vertical"");

        Vector3 direction = (cameraPivot.right * h + cameraPivot.forward * v).normalized;
        direction.y = 0;

        float speed = Input.GetKey(KeyCode.LeftShift) ? sprintSpeed : moveSpeed;
        characterController.Move(direction * speed * Time.deltaTime);

        if (direction.magnitude > 0)
            transform.rotation = Quaternion.LookRotation(direction);
    }

    void RotateCamera()
    {
        cameraYaw += Input.GetAxis(""Mouse X"") * mouseSensitivity;
        cameraPivot.rotation = Quaternion.Euler(0, cameraYaw, 0);
    }

    void HandleJump()
    {
        if (characterController.isGrounded)
        {
            verticalVelocity = -0.5f;
            if (Input.GetButton(""Jump""))
                verticalVelocity = jumpForce;
        }
        else
        {
            verticalVelocity += Physics.gravity.y * Time.deltaTime;
        }

        characterController.Move(Vector3.up * verticalVelocity * Time.deltaTime);
    }
}"
            };
        }

        Dictionary<string, string> GenerateCasualPuzzleFiles()
        {
            return new Dictionary<string, string>
            {
                ["LevelManager.cs"] = @"using UnityEngine;

/// <summary>
/// 休闲益智游戏关卡管理�?/// </summary>
public class LevelManager : MonoBehaviour
{
    public static LevelManager Instance { get; private set; }

    [Header("关卡配置")]
    public int currentLevel = 1;
    public float levelTime;
    public int movesCount;
    public int score;

    void Awake()
    {
        Instance = this;
    }

    void Update()
    {
        levelTime += Time.deltaTime;
    }

    public void StartLevel(int levelNum)
    {
        currentLevel = levelNum;
        levelTime = 0;
        movesCount = 0;
        score = 0;
    }

    public void RecordMove()
    {
        movesCount++;
    }

    public void AddScore(int points)
    {
        score += points;
    }

    public int CalculateStars()
    {
        if (score >= 1000) return 3;
        if (score >= 500) return 2;
        return 1;
    }
}"
            };
        }

        Dictionary<string, string> GenerateRPGFiles()
        {
            return new Dictionary<string, string>
            {
                ["CharacterStats.cs"] = @"using UnityEngine;

/// <summary>
/// RPG角色属性系�?/// </summary>
public class CharacterStats : MonoBehaviour
{
    [Header("基础属�?)]
    public float maxHealth = 100f;
    public float maxMana = 100f;
    public float strength = 10f;
    public float intelligence = 10f;
    public float defense = 5f;
    public float speed = 5f;

    private float currentHealth;
    private float currentMana;
    private int level = 1;
    private int experience;
    private int expToNextLevel = 100;

    public float CurrentHealth => currentHealth;
    public float CurrentMana => currentMana;
    public int Level => level;

    void Start()
    {
        currentHealth = maxHealth;
        currentMana = maxMana;
    }

    public void TakeDamage(float amount)
    {
        float actualDamage = Mathf.Max(0, amount - defense);
        currentHealth -= actualDamage;
        if (currentHealth <= 0)
        {
            currentHealth = 0;
            OnDeath();
        }
    }

    public void Heal(float amount)
    {
        currentHealth = Mathf.Min(maxHealth, currentHealth + amount);
    }

    public bool UseMana(float cost)
    {
        if (currentMana >= cost)
        {
            currentMana -= cost;
            return true;
        }
        return false;
    }

    public void GainExperience(int amount)
    {
        experience += amount;
        while (experience >= expToNextLevel)
        {
            LevelUp();
        }
    }

    void LevelUp()
    {
        experience -= expToNextLevel;
        level++;
        maxHealth += 10;
        maxMana += 5;
        strength += 2;
        intelligence += 2;
        currentHealth = maxHealth;
        currentMana = maxMana;
        expToNextLevel = level * 100;
    }

    void OnDeath()
    {
        Debug.Log(""角色死亡"");
    }
}",

                ["SkillSystem.cs"] = @"using UnityEngine;
using System.Collections.Generic;

/// <summary>
/// RPG技能系�?/// </summary>
public class SkillSystem : MonoBehaviour
{
    [System.Serializable]
    public class Skill
    {
        public string id;
        public string name;
        public string description;
        public float manaCost;
        public float cooldown;
        public float damage;
        public float healing;
    }

    public List<Skill> learnedSkills = new List<Skill>();
    private Dictionary<string, float> skillCooldowns = new Dictionary<string, float>();

    void Start()
    {
        // 初始化默认技�?        learnedSkills.Add(new Skill {
            id = ""attack"", name = ""普通攻�?", manaCost = 0, cooldown = 0, damage = 10
        });
        learnedSkills.Add(new Skill {
            id = ""fireball"", name = ""火球�?", manaCost = 20, cooldown = 3, damage = 50
        });
        learnedSkills.Add(new Skill {
            id = ""heal"", name = ""治疗�?", manaCost = 30, cooldown = 5, damage = 0, healing = 40
        });
    }

    void Update()
    {
        // 更新冷却
        var keys = new List<string>(skillCooldowns.Keys);
        foreach (var key in keys)
        {
            skillCooldowns[key] -= Time.deltaTime;
            if (skillCooldowns[key] <= 0)
                skillCooldowns.Remove(key);
        }
    }

    public bool CanUseSkill(string skillId, float currentMana)
    {
        var skill = learnedSkills.Find(s => s.id == skillId);
        if (skill == null) return false;
        if (skillCooldowns.ContainsKey(skillId)) return false;
        return currentMana >= skill.manaCost;
    }

    public Skill UseSkill(string skillId)
    {
        var skill = learnedSkills.Find(s => s.id == skillId);
        if (skill != null)
        {
            skillCooldowns[skillId] = skill.cooldown;
        }
        return skill;
    }
}"
            };
        }

        void SaveScriptFile(string fileName, string content)
        {
            string scriptsFolder = Application.dataPath + "/Scripts/GameAI/";
            if (!System.IO.Directory.Exists(scriptsFolder))
            {
                System.IO.Directory.CreateDirectory(scriptsFolder);
            }

            string filePath = scriptsFolder + fileName;
            System.IO.File.WriteAllText(filePath, content);

            Debug.Log($""已生�? {fileName}"");
        }

        // ==================== 场景生成功能 ====================

        void DrawSceneGenWindow()
        {
            if (!showSceneGenWindow) return;

            GUILayout.BeginArea(new Rect(10, 300, 350, 400), "🎬 场景生成�?, GUI.skin.window);

            GUILayout.Label("快速生成预设场景：", EditorStyles.boldLabel);
            EditorGUILayout.Space();

            if (GUILayout.Button("🏗�?简单关�?, GUILayout.Height(35)))
            {
                GenerateScene("simple_level");
            }

            if (GUILayout.Button("⚔️ 战斗场景", GUILayout.Height(35)))
            {
                GenerateScene("battle_arena");
            }

            if (GUILayout.Button("👹 Boss房间", GUILayout.Height(35)))
            {
                GenerateScene("boss_room");
            }

            EditorGUILayout.Space();
            GUILayout.Label("自定义场景描述：", EditorStyles.boldLabel);
            sceneDescription = EditorGUILayout.TextArea(sceneDescription, GUILayout.Height(80));

            if (GUILayout.Button("�?根据描述生成场景"))
            {
                GenerateCustomScene();
            }

            EditorGUILayout.Space();
            GUILayout.Label("场景元素说明�?, EditorStyles.miniLabel);
            GUILayout.Label("�?player_spawn - 玩家出生�?);
            GUILayout.Label("�?enemy - 敌人");
            GUILayout.Label("�?collectible - 可收集物");
            GUILayout.Label("�?obstacle - 障碍�?);
            GUILayout.Label("�?goal - 终点");
            GUILayout.Label("�?spawner - 敌人生成�?);

            EditorGUILayout.Space();
            if (GUILayout.Button("关闭"))
            {
                showSceneGenWindow = false;
            }

            GUILayout.EndArea();
        }

        void GenerateScene(string presetKey)
        {
            if (!scenePresets.ContainsKey(presetKey))
            {
                AddMessage("�?未知的场景预�?, false);
                return;
            }

            var config = scenePresets[presetKey];

            AddMessage($"�?正在生成{config.type}场景...", false);

            // 生成场景预制�?            var generatedFiles = GenerateSceneFiles(config);

            string report = $@"�?场景生成成功�?
📊 生成文件 ({generatedFiles.Count}�?�?";
            foreach (var file in generatedFiles)
            {
                report += $"�?{file.Key}\n";
            }

            report += @"
💡 下一步：
�?查看预制体并拖入场景
�?根据需要调整位置和参数
";

            AddMessage(report, false);
            showSceneGenWindow = false;
        }

        void GenerateCustomScene()
        {
            if (string.IsNullOrWhiteSpace(sceneDescription))
            {
                AddMessage("⚠️ 请输入场景描�?, false);
                return;
            }

            AddMessage($"�?正在根据描述生成场景...\n描述: {sceneDescription}", false);

            // 解析场景描述并生�?            var config = ParseSceneDescription(sceneDescription);
            var generatedFiles = GenerateSceneFiles(config);

            string report = $@"�?自定义场景生成成功！

📄 场景类型: {config.type}
📊 元素数量: {config.elements.Count}
📁 生成文件: {generatedFiles.Count}�?";

            AddMessage(report, false);
            showSceneGenWindow = false;
        }

        SceneConfig ParseSceneDescription(string description)
        {
            var config = new SceneConfig { type = "custom" };

            // 简单解析关键词
            string desc = description.ToLower();

            if (desc.Contains("平台") || desc.Contains("跳跃"))
            {
                config.type = "platformer_level";
                config.elements.Add(new SceneElement { type = "player_spawn", name = "PlayerSpawn", position = new Vector3(-5, 0, 0) });
                config.elements.Add(new SceneElement { type = "platform", name = "Ground", position = new Vector3(0, -2, 0), scale = new Vector3(15, 1, 1) });
            }

            if (desc.Contains("战斗") || desc.Contains("敌人"))
            {
                config.elements.Add(new SceneElement { type = "enemy", name = "Enemy1", position = new Vector3(0, 0, -3) });
            }

            if (desc.Contains("boss"))
            {
                config.type = "boss_room";
                config.elements.Add(new SceneElement { type = "spawner", name = "BossSpawn", position = new Vector3(0, 0, 0) });
            }

            if (desc.Contains("金币") || desc.Contains("收集"))
            {
                config.elements.Add(new SceneElement { type = "collectible", name = "Coin1", position = new Vector3(0, 0, 0) });
            }

            return config;
        }

        Dictionary<string, string> GenerateSceneFiles(SceneConfig config)
        {
            var files = new Dictionary<string, string>();

            // 生成场景管理�?            string managerContent = $@"using UnityEngine;
using System.Collections.Generic;

/// <summary>
/// 场景管理�?- {config.type}
/// </summary>
public class SceneManager_{config.type} : MonoBehaviour
{
    public List<Transform> playerSpawnPoints = new List<Transform>();
    public List<Transform> enemySpawnPoints = new List<Transform>();
    public List<Transform> collectiblePoints = new List<Transform>();

    void Start()
    {
        InitializeScene();
    }

    void InitializeScene()
    {
        Debug.Log($""场景初始�? {config.type}"");
        Debug.Log($""玩家出生�? {playerSpawnPoints.Count}"");
        Debug.Log($""敌人: {enemySpawnPoints.Count}"");
        Debug.Log($""可收集物: {collectiblePoints.Count}"");
    }
}";

            files[$"SceneManager_{config.type}.cs"] = managerContent;

            // 生成预制体脚�?            foreach (var element in config.elements)
            {
                string prefabScript = GeneratePrefabScript(element);
                files[$"{element.name}.cs"] = prefabScript;
            }

            // 保存文件
            string folder = Application.dataPath + $"/Prefabs/Scenes/{config.type}/";
            if (!System.IO.Directory.Exists(folder))
            {
                System.IO.Directory.CreateDirectory(folder);
            }

            foreach (var kvp in files)
            {
                System.IO.File.WriteAllText(folder + kvp.Key, kvp.Value);
            }

            return files;
        }

        string GeneratePrefabScript(SceneElement element)
        {
            switch (element.type)
            {
                case ""player_spawn"":
                    return $@"using UnityEngine;

/// <summary>
/// 玩家出生�?- {element.name}
/// </summary>
public class {element.name} : MonoBehaviour
{
    public static Transform spawnPoint;

    void Start()
    {
        spawnPoint = transform;
    }

    void OnDrawGizmos()
    {
        Gizmos.color = Color.green;
        Gizmos.DrawWireSphere(transform.position, 1f);
    }
}";

                case ""enemy"":
                    return $@"using UnityEngine;

/// <summary>
/// 敌人 - {element.name}
/// </summary>
public class {element.name} : MonoBehaviour
{
    public float health = 100f;
    public float damage = 20f;
    public float speed = 3f;

    void Update()
    {
        // 敌人AI逻辑
    }

    public void TakeDamage(float amount)
    {
        health -= amount;
        if (health <= 0)
        {
            Destroy(gameObject);
        }
    }
}";

                case ""collectible"":
                    return $@"using UnityEngine;

/// <summary>
/// 可收集物�?- {element.name}
/// </summary>
public class {element.name} : MonoBehaviour
{
    public int value = 10;
    public string itemType = ""coin"";

    void OnTriggerEnter(Collider other)
    {
        if (other.CompareTag(""Player""))
        {
            GameManager.Instance.AddScore(value);
            Destroy(gameObject);
        }
    }
}";

                case ""goal"":
                    return $@"using UnityEngine;

/// <summary>
/// 终点/�?- {element.name}
/// </summary>
public class {element.name} : MonoBehaviour
{
    public string nextLevel = ""Level2"";

    void OnTriggerEnter(Collider other)
    {
        if (other.CompareTag(""Player""))
        {
            Debug.Log($""到达终点: {nextLevel}"");
            // 加载下一�?        }
    }
}";

                default:
                    return $@"using UnityEngine;

/// <summary>
/// 场景元素 - {element.name}
/// </summary>
public class {element.name} : MonoBehaviour
{
    void Start()
    {
        transform.position = new Vector3({element.position.x}, {element.position.y}, {element.position.z});
        transform.localScale = new Vector3({element.scale.x}, {element.scale.y}, {element.scale.z});
    }
}";
            }
        }

        // ==================== 命令处理方法 ====================

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

// ==================== 项目扫描 ====================

        void ScanProject()
        {
            AddMessage("📂 正在扫描项目...", false);

            currentProject = new ProjectInfo
            {
                name = PlayerSettings.productName,
                unityVersion = Application.unityVersion,
                sceneCount = 0,
                scriptCount = 0,
                resourceTypes = new List<string>()
            };

            string projectPath = Application.dataPath;

            var scenes = Directory.GetFiles(projectPath, "*.unity", SearchOption.AllDirectories);
            currentProject.sceneCount = scenes.Length;

            var scripts = Directory.GetFiles(projectPath, "*.cs", SearchOption.AllDirectories);
            currentProject.scriptCount = scripts.Length;

            if (Directory.Exists($"{projectPath}/Scenes")) currentProject.resourceTypes.Add("Scenes");
            if (Directory.Exists($"{projectPath}/Scripts")) currentProject.resourceTypes.Add("Scripts");
            if (Directory.Exists($"{projectPath}/Prefabs")) currentProject.resourceTypes.Add("Prefabs");
            if (Directory.Exists($"{projectPath}/Materials")) currentProject.resourceTypes.Add("Materials");
            if (Directory.Exists($"{projectPath}/Textures")) currentProject.resourceTypes.Add("Textures");
            if (Directory.Exists($"{projectPath}/Audio")) currentProject.resourceTypes.Add("Audio");
            if (Directory.Exists($"{projectPath}/Animation")) currentProject.resourceTypes.Add("Animation");

            string report = $@"
📁 项目扫描完成
━━━━━━━━━━━━━━━━━━━━━━�?
🏷�?项目名称: {currentProject.name}
📦 Unity版本: {currentProject.unityVersion}
🎮 场景�? {currentProject.sceneCount}
📜 脚本�? {currentProject.scriptCount}
📂 资源目录: {string.Join(", ", currentProject.resourceTypes)}

💡 提示: 现在可以问我关于这个项目的任何问题！
";

            AddMessage(report, false);
        }

        // ==================== 代码解析和应�?====================

        void ParseCodeBlocks(string response)
        {
            pendingCodeBlocks.Clear();

            int startIdx = 0;
            while ((startIdx = response.IndexOf("```", startIdx)) != -1)
            {
                int codeStart = startIdx + 3;
                int codeEnd = response.IndexOf("```", codeStart);

                if (codeEnd == -1) break;

                string codeBlock = response.Substring(codeStart, codeEnd - codeStart).Trim();

                if (!string.IsNullOrWhiteSpace(codeBlock))
                {
                    pendingCodeBlocks.Add(new CodeBlock
                    {
                        code = codeBlock,
                        language = "csharp"
                    });
                }

                startIdx = codeEnd + 3;
            }

            if (pendingCodeBlocks.Count > 0)
            {
                AddMessage($"\n📋 检测到 {pendingCodeBlocks.Count} 个代码块\n输入「应用代码」保存到项目\n", false);
            }
        }

        void ApplyPendingCodes()
        {
            if (pendingCodeBlocks.Count == 0)
            {
                AddMessage("没有待应用的代码", false);
                return;
            }

            string scriptsFolder = $"{Application.dataPath}/Scripts/AIAssistant";
            if (!Directory.Exists(scriptsFolder))
            {
                Directory.CreateDirectory(scriptsFolder);
            }

            int success = 0;
            string files = "";

            for (int i = 0; i < pendingCodeBlocks.Count; i++)
            {
                var block = pendingCodeBlocks[i];
                string className = ExtractClassName(block.code);
                string fileName = string.IsNullOrEmpty(className)
                    ? $"GeneratedScript_{i + 1}.cs"
                    : $"{className}.cs";

                string filePath = $"{scriptsFolder}/{fileName}";

                try
                {
                    // 保存原内容（如果有）
                    string originalCode = "";
                    bool hadFile = File.Exists(filePath);
                    if (hadFile)
                    {
                        originalCode = File.ReadAllText(filePath);
                    }

                    // 写入新代�?                    File.WriteAllText(filePath, block.code);
                    success++;
                    files += $"�?{fileName}\n";

                    // 添加到撤销历史
                    var history = new UndoHistory
                    {
                        action = hadFile ? "apply" : "new",
                        filePath = filePath,
                        fileName = fileName,
                        originalCode = originalCode,
                        newCode = block.code,
                        hasBackup = hadFile,
                        timestamp = System.DateTime.Now.ToString()
                    };

                    undoStack.Add(history);

                    // 限制历史长度
                    while (undoStack.Count > MAX_HISTORY)
                    {
                        undoStack.RemoveAt(0);
                    }

                    // 新操作清除重做栈
                    redoStack.Clear();
                }
                catch (System.Exception e)
                {
                    Debug.LogError($"保存失败: {e.Message}");
                }
            }

            pendingCodeBlocks.Clear();
            AssetDatabase.Refresh();

            string historyStatus = GetHistoryStatus();

            string report = $@"
�?代码应用完成
━━━━━━━━━━━━━━━━━━━━━━�?
📊 结果: {success} 成功
📁 保存位置: Assets/Scripts/AIAssistant/

{files}

{historyStatus}
💡 输入「撤销」回退操作
";

            AddMessage(report, false);
        }

        string ExtractClassName(string code)
        {
            var lines = code.Split('\n');
            foreach (var line in lines)
            {
                line = line.Trim();
                if (line.Contains("class ") && !line.Contains("//"))
                {
                    int idx = line.IndexOf("class ") + 6;
                    int endIdx = line.IndexOfAny(new char[] { ' ', ':', '{' }, idx);
                    if (endIdx > idx)
                    {
                        return line.Substring(idx, endIdx - idx).Trim();
                    }
                }
            }
            return "";
        }

        // ==================== 辅助功能 ====================

        void AddMessage(string content, bool isUser)
        {
            chatHistory.Add(new ChatMessage { isUser = isUser, content = content });
            scrollPosition.y = float.MaxValue;
            Repaint();
        }

        void ClearHistory()
        {
            chatHistory.Clear();
            pendingCodeBlocks.Clear();
            statusText = "已清�?;
            Repaint();
        }

        void ShowHelp()
        {
            if (GetCurrentLang() == "zh")
            {
                AddMessage(@"📖 **帮助 v1.5**

**代码解释与优化**
• 「解释代码」- 选中代码后输入，AI分析功能
• 「优化代码」- 选中代码后输入，AI提供优化建议

**快捷按钮**
• 📝 解释 - 代码解释
• 🔧 优化 - 代码优化

**常用命令**
• 「帮我做XXX游戏」- 生成代码
• 「给玩家加XXX功能」- 修改代码
• 「找XXX素材」- 搜索素材
• 「扫描项目」- 查看项目结构
• 「今日学习」- 获取开发技巧
• 「知识库」- 查看/管理知识
• 「模板」- 查看代码模板

**快捷按钮**
• 👁️ 预览 - 查看待应用代码
• ✅ 应用 - 确认应用代码
• 📚 学习 - 每日学习
• 📖 知识 - 知识库
有什么问题尽管问！🐙", false);
            }
            else
            {
                AddMessage(@"📖 **Help v1.5**

**Code Explain & Optimize**
• 「explain code」- Select code and enter to analyze
• 「optimize code」- Select code and enter to get suggestions

**Quick Buttons**
• 📝 Explain - Code explanation
• 🔧 Optimize - Code optimization

**Common Commands**
• 「make a XXX game」- Generate code
• 「add XXX feature to player」- Modify code
• 「find XXX assets」- Search assets
• 「scan project」- View project structure
• 「daily learning」- Learning tips
• 「knowledge base」- View/manage knowledge
• 「templates」- View code templates

**Quick Buttons**
• 👁️ Preview - Preview pending code
• ✅ Apply - Apply code
• 📚 Learn - Daily learning
• 📖 Knowledge - Knowledge base
Ask me anything! 🐙", false);
            }
        }

        void ShowTemplates()
        {
            AddMessage(@"📋 **代码模板**

**2D游戏模板**
�?PlayerController - 玩家移动+跳跃
�?EnemyAI - 敌人巡�?攻击
�?BulletSystem - 子弹发射
�?HealthBar - UI血�?
**3D游戏模板**
�?FirstPersonController - FPS控制
�?ThirdPersonController - 第三人称
�?CameraFollow - 相机跟随

**系统模板**
�?SaveSystem - 存档系统
�?ShopSystem - 商店系统
�?AchievementSystem - 成就系统

输入「生成玩家脚本」获取代码！", false);
        }

        void ShowAssetLibrary()
        {
            AddMessage(@"🎨 **免费可商用素材库**

**音效**
�?freesound.org - 全球最大音效库
�?kenney.nl - CC0协议高质�?
**2D素材**
�?kenney.nl - 像素精灵�?�?craftpix.net - 游戏UI套件
�?opengameart.org - 社区素材

**3D模型**
�?kenney.nl - 3D模型�?�?polyhaven.com - CC0 3D模型

**动画**
�?mixamo.com - 自动rig+动画

**图标**
�?game-icons.net - 3000+图标

输入「找爆炸音效」开始搜索！", false);
        }

        void ShowSettings()
        {
            EditorGUILayout.BeginVertical("box");

            GUILayout.Label("⚙️ " + Tr("settings_title"), EditorStyles.boldLabel);
            EditorGUILayout.Space();

            useCloud = EditorGUILayout.Toggle("🌐 " + (GetCurrentLang() == "zh" ? "使用云端模型" : "Use Cloud Model"), useCloud);

            if (useCloud)
            {
                EditorGUILayout.BeginHorizontal();
                GUILayout.Label("模型:", GUILayout.Width(60));
                string[] modelOptions = new string[] {
                    "DeepSeek V3", "Claude 3.5", "GPT-4o",
                    "───── 国际 ─────",
                    "Google Gemini 1.5 Pro", "Mistral Large", "Groq Llama 3.1", "Cohere Command R+", "Azure OpenAI",
                    "───── 国内 ─────",
                    "通义千问 Qwen Plus", "文心一言 4.0", "讯飞星火 V3.5", "智谱 GLM-4", "Kimi Moonshot V1"
                };
                int selected = EditorGUILayout.Popup(GetModelIndex(), modelOptions);
                ApplyModelSelection(selected);
                EditorGUILayout.EndHorizontal();

                // Azure额外配置
                if (modelId == "azure")
                {
                    EditorGUILayout.BeginHorizontal();
                    GUILayout.Label("Azure Endpoint:", GUILayout.Width(100));
                    azureEndpoint = EditorGUILayout.TextField(azureEndpoint);
                    EditorGUILayout.EndHorizontal();
                    EditorGUILayout.BeginHorizontal();
                    GUILayout.Label("Deployment:", GUILayout.Width(100));
                    azureDeployment = EditorGUILayout.TextField(azureDeployment);
                    EditorGUILayout.EndHorizontal();
                }

                // 讯飞星火额外配置
                if (modelId == "spark")
                {
                    EditorGUILayout.HelpBox("讯飞星火需要额外的 AppID 和 API Secret", MessageType.Info);
                    EditorGUILayout.BeginHorizontal();
                    GUILayout.Label("AppID:", GUILayout.Width(100));
                    sparkAppId = EditorGUILayout.TextField(sparkAppId);
                    EditorGUILayout.EndHorizontal();
                    EditorGUILayout.BeginHorizontal();
                    GUILayout.Label("API Secret:", GUILayout.Width(100));
                    sparkApiSecret = EditorGUILayout.PasswordField(sparkApiSecret);
                    EditorGUILayout.EndHorizontal();
                }

                EditorGUILayout.BeginHorizontal();
                GUILayout.Label("API Key:", GUILayout.Width(60));
                apiKey = EditorGUILayout.PasswordField(apiKey);
                EditorGUILayout.EndHorizontal();

                // 根据选择显示对应的获取链接
                ShowModelLinkButton();
            }
            else
            {
                EditorGUILayout.LabelField("💻 本地模型 (Ollama)");

                EditorGUILayout.BeginHorizontal();
                GUILayout.Label(GetCurrentLang() == "zh" ? "地址:" : "Address:", GUILayout.Width(60));
                localUrl = EditorGUILayout.TextField(localUrl);
                EditorGUILayout.EndHorizontal();

                EditorGUILayout.BeginHorizontal();
                GUILayout.Label("模型:", GUILayout.Width(60));
                localModel = EditorGUILayout.TextField(localModel);
                EditorGUILayout.EndHorizontal();

                if (GUILayout.Button("📥 安装 Ollama"))
                {
                    Application.OpenURL("https://ollama.com/");
                }
            }

            EditorGUILayout.Space();

            // Language selector
            GUILayout.Space(10);
            GUILayout.Label("🌐 " + Tr("language") + ":", EditorStyles.boldLabel);
            GUILayout.BeginHorizontal();
            if (GUILayout.Button(GetCurrentLang() == "zh" ? "🇨🇳 中文 ✓" : "🇨🇳 中文", GUILayout.Width(100)))
            {
                SetLanguage("zh");
                currentLanguage = "zh";
                SaveConfig();
                Repaint();
            }
            if (GUILayout.Button(GetCurrentLang() == "en" ? "🇺🇸 English ✓" : "🇺🇸 English", GUILayout.Width(100)))
            {
                SetLanguage("en");
                currentLanguage = "en";
                SaveConfig();
                Repaint();
            }
            if (GUILayout.Button(GetCurrentLang() == "auto" ? "🌐 Auto ✓" : "🌐 Auto", GUILayout.Width(100)))
            {
                SetLanguage("auto");
                currentLanguage = "auto";
                SaveConfig();
                Repaint();
            }
            GUILayout.EndHorizontal();

            GUILayout.Space(10);
            if (GUILayout.Button("💾 " + Tr("save") + " " + (GetCurrentLang() == "zh" ? "配置" : "Settings")))
            {
                SaveConfig();
            }

            EditorGUILayout.EndVertical();
        }

        void ShowModelLinkButton()
        {
            string buttonText = "";
            string url = "";

            switch (modelId)
            {
                case "deepseek-chat":
                    buttonText = "🔗 获取 DeepSeek API Key";
                    url = "https://platform.deepseek.com/";
                    break;
                case "claude-3-5-sonnet-20240620":
                    buttonText = "🔗 获取 Claude API Key";
                    url = "https://www.anthropic.com/";
                    break;
                case "gpt-4o":
                    buttonText = "🔗 获取 OpenAI API Key";
                    url = "https://platform.openai.com/";
                    break;
                case "gemini-1.5-pro":
                    buttonText = "🔗 获取 Google AI API Key";
                    url = "https://makersuite.google.com/app/apikey";
                    break;
                case "mistral-large-latest":
                    buttonText = "🔗 获取 Mistral API Key";
                    url = "https://console.mistral.ai/";
                    break;
                case "groq":
                    buttonText = "🔗 获取 Groq API Key";
                    url = "https://console.groq.com/";
                    break;
                case "cohere":
                    buttonText = "🔗 获取 Cohere API Key";
                    url = "https://dashboard.cohere.com/";
                    break;
                case "qwen-plus":
                    buttonText = "🔗 获取阿里云百炼 API Key";
                    url = "https://bailian.console.aliyun.com/";
                    break;
                case "ernie-4.0-8k-latest":
                    buttonText = "🔗 获取文心一言 API Key";
                    url = "https://console.bce.baidu.com/";
                    break;
                case "spark":
                    buttonText = "🔗 获取讯飞星火 API";
                    url = "https://console.xfyun.cn/";
                    break;
                case "glm-4":
                    buttonText = "🔗 获取智谱 AI API Key";
                    url = "https://open.bigmodel.cn/";
                    break;
                case "moonshot-v1-8k":
                    buttonText = "🔗 获取 Kimi API Key";
                    url = "https://platform.moonshot.cn/";
                    break;
            }

            if (!string.IsNullOrEmpty(buttonText) && GUILayout.Button(buttonText))
            {
                Application.OpenURL(url);
            }
        }

        int GetModelIndex()
        {
            return modelId switch
            {
                "deepseek-chat" => 0,
                "claude-3-5-sonnet-20240620" => 1,
                "gpt-4o" => 2,
                // 国际模型
                "gemini-1.5-pro" => 4,
                "mistral-large-latest" => 5,
                "groq" => 6,
                "cohere" => 7,
                "azure" => 8,
                // 国内模型
                "qwen-plus" => 10,
                "ernie-4.0-8k-latest" => 11,
                "spark" => 12,
                "glm-4" => 13,
                "moonshot-v1-8k" => 14,
                _ => 0
            };
        }

        void ApplyModelSelection(int index)
        {
            switch (index)
            {
                case 0:
                    modelName = "DeepSeek V3";
                    modelId = "deepseek-chat";
                    modelEndpoint = "https://api.deepseek.com/v1";
                    break;
                case 1:
                    modelName = "Claude 3.5";
                    modelId = "claude-3-5-sonnet-20240620";
                    modelEndpoint = "https://api.anthropic.com/v1";
                    break;
                case 2:
                    modelName = "GPT-4o";
                    modelId = "gpt-4o";
                    modelEndpoint = "https://api.openai.com/v1";
                    break;
                // 国际模型
                case 4:
                    modelName = "Google Gemini 1.5 Pro";
                    modelId = "gemini-1.5-pro";
                    modelEndpoint = "https://generativelanguage.googleapis.com/v1beta/models";
                    break;
                case 5:
                    modelName = "Mistral Large";
                    modelId = "mistral-large-latest";
                    modelEndpoint = "https://api.mistral.ai/v1";
                    break;
                case 6:
                    modelName = "Groq Llama 3.1";
                    modelId = "llama-3.1-70b-versatile";
                    modelEndpoint = "https://api.groq.com/openai/v1";
                    break;
                case 7:
                    modelName = "Cohere Command R+";
                    modelId = "command-r-plus";
                    modelEndpoint = "https://api.cohere.ai/v1";
                    break;
                case 8:
                    modelName = "Azure OpenAI";
                    modelId = "azure";
                    modelEndpoint = azureEndpoint;
                    break;
                // 国内模型
                case 10:
                    modelName = "通义千问 Qwen Plus";
                    modelId = "qwen-plus";
                    modelEndpoint = "https://dashscope.aliyuncs.com/compatible-mode/v1";
                    break;
                case 11:
                    modelName = "文心一言 4.0";
                    modelId = "ernie-4.0-8k-latest";
                    modelEndpoint = "https://qianfan.baidubce.com/v2";
                    break;
                case 12:
                    modelName = "讯飞星火 V3.5";
                    modelId = "spark";
                    modelEndpoint = "https://spark-api.xf-yun.com";
                    break;
                case 13:
                    modelName = "智谱 GLM-4";
                    modelId = "glm-4";
                    modelEndpoint = "https://open.bigmodel.cn/api/paas/v4";
                    break;
                case 14:
                    modelName = "Kimi Moonshot V1";
                    modelId = "moonshot-v1-8k";
                    modelEndpoint = "https://api.moonshot.cn/v1";
                    break;
            }
        }

        // ==================== 配置持久化 ====================

        void LoadConfig()
        {
            apiKey = EditorPrefs.GetString("GameAI_ApiKey", "");
            modelName = EditorPrefs.GetString("GameAI_Model", "DeepSeek V3");
            modelId = EditorPrefs.GetString("GameAI_ModelId", "deepseek-chat");
            modelEndpoint = EditorPrefs.GetString("GameAI_Endpoint", "https://api.deepseek.com/v1");
            useCloud = EditorPrefs.GetBool("GameAI_UseCloud", true);
            localUrl = EditorPrefs.GetString("GameAI_LocalUrl", "http://localhost:11434/v1");
            localModel = EditorPrefs.GetString("GameAI_LocalModel", "qwen2.5:3b");

            // 新增配置
            azureEndpoint = EditorPrefs.GetString("GameAI_AzureEndpoint", "");
            azureDeployment = EditorPrefs.GetString("GameAI_AzureDeployment", "");
            sparkAppId = EditorPrefs.GetString("GameAI_SparkAppId", "");
            sparkApiSecret = EditorPrefs.GetString("GameAI_SparkSecret", "");

            isConnected = !string.IsNullOrEmpty(apiKey) || !useCloud;
        }

        void SaveConfig()
        {
            EditorPrefs.SetString("GameAI_ApiKey", apiKey);
            EditorPrefs.SetString("GameAI_Model", modelName);
            EditorPrefs.SetString("GameAI_ModelId", modelId);
            EditorPrefs.SetString("GameAI_Endpoint", modelEndpoint);
            EditorPrefs.SetBool("GameAI_UseCloud", useCloud);
            EditorPrefs.SetString("GameAI_LocalUrl", localUrl);
            EditorPrefs.SetString("GameAI_LocalModel", localModel);

            // 新增配置
            EditorPrefs.SetString("GameAI_AzureEndpoint", azureEndpoint);
            EditorPrefs.SetString("GameAI_AzureDeployment", azureDeployment);
            EditorPrefs.SetString("GameAI_SparkAppId", sparkAppId);
            EditorPrefs.SetString("GameAI_SparkSecret", sparkApiSecret);

            isConnected = !string.IsNullOrEmpty(apiKey) || !useCloud;

            EditorUtility.DisplayDialog(GetCurrentLang() == "zh" ? "保存成功" : "Saved", GetCurrentLang() == "zh" ? "AI配置已保存" : "AI settings saved", "OK");
            Repaint();
        }

        // ==================== 数据结构 ====================

        class ChatMessage
        {
            public bool isUser;
            public string content;
        }

        class CodeBlock
        {
            public string code;
            public string language;
        }

        class ProjectInfo
        {
            public string name;
            public string unityVersion;
            public int sceneCount;
            public int scriptCount;
            public List<string> resourceTypes;
        }

        class AIRequest
        {
            public string model;
            public List<AIMessage> messages;
            public float temperature = 0.7f;
            public int max_tokens = 2000;
        }

        class AIMessage
        {
            public string role;
            public string content;
        }

        class AIResponse
        {
            public List<AIChoice> choices;
        }

        class AIChoice
        {
            public AIMessage message;
        }

        // ==================== 知识库数据结�?====================

        [System.Serializable]
        class KnowledgeBase
        {
            public List<KnowledgeEntry> entries = new List<KnowledgeEntry>();

            public void AddEntry(string title, string content, string tags = "")
            {
                entries.Add(new KnowledgeEntry
                {
                    title = title,
                    content = content,
                    tags = tags,
                    createdAt = System.DateTime.Now.ToString()
                });
            }

            public List<KnowledgeEntry> Search(string keyword)
            {
                return entries.FindAll(e =>
                    e.title.Contains(keyword) ||
                    e.content.Contains(keyword) ||
                    e.tags.Contains(keyword));
            }

            public KnowledgeStats GetStats()
            {
                var allTags = new HashSet<string>();
                foreach (var e in entries)
                {
                    foreach (var tag in e.tags.Split(','))
                    {
                        if (!string.IsNullOrEmpty(tag))
                            allTags.Add(tag.Trim());
                    }
                }

                return new KnowledgeStats
                {
                    totalEntries = entries.Count,
                    totalTags = allTags.Count
                };
            }
        }

        [System.Serializable]
        class KnowledgeEntry
        {
            public string title;
            public string content;
            public string tags;
            public string createdAt;
        }

        class KnowledgeStats
        {
            public int totalEntries;
            public int totalTags;
        }
        
        // ==================== 代码搜索数据结构 ====================
        
        class CodeSearchResult
        {
            public string filePath;
            public string relativePath;
            public string fileName;
            public List<CodeMatch> matches;
            public int matchCount;
        }
        
        class CodeMatch
        {
            public int lineNumber;
            public string content;
            public string preview;
        }
        
        // ==================== 撤销/重做数据结构 ====================

        [System.Serializable]
        class UndoHistory
        {
            public string action;  // "apply" �?"delete"
            public string filePath;
            public string fileName;
            public string originalCode;  // 原始代码（apply时为原代码，delete时为空）
            public string newCode;       // 新代码（apply时为新代码，delete时为原代码）
            public bool hasBackup;
            public string timestamp;
        }

        // ==================== Phase 5: 测试生成数据结构 ====================

        class FunctionInfo
        {
            public string Name;
            public string ReturnType;
            public List<string> Parameters = new List<string>();
        }

        class TestCase
        {
            public string Name;
            public string Type;
            public string TargetFunction;
            public List<string> TestSteps = new List<string>();
        }

        // ==================== Phase 5: 差异对比数据结构 ====================

        class DiffChunk
        {
            public int StartLine;
            public List<string> AddedLines = new List<string>();
            public List<string> RemovedLines = new List<string>();
            public List<string> UnchangedLines = new List<string>();
        }

        class DiffResult
        {
            public int Additions;
            public int Deletions;
            public int Unchanged;
            public string DiffText;
            public List<DiffChunk> Chunks = new List<DiffChunk>();
        }

        // ==================== Phase 5: 辅助方法 ====================

        string ExtractTestTargetFile(string message)
        {
            string[] patterns = { "�?", "生成测试 ", "写单元测�?", "测试 " };

            foreach (var pattern in patterns)
            {
                int idx = message.ToLower().IndexOf(pattern.ToLower());
                if (idx != -1)
                {
                    int startIdx = idx + pattern.Length;
                    var remaining = message.Substring(startIdx).Trim();

                    // 提取到空格、句号或句号为止
                    int endIdx = remaining.IndexOfAny(new char[] { ' ', '�?, '.' });
                    if (endIdx == -1)
                        endIdx = remaining.Length;

                    var fileName = remaining.Substring(0, endIdx).Trim();

                    // 清理末尾标点
                    while (fileName.Length > 0 && (fileName.EndsWith(".") || fileName.EndsWith(",")))
                    {
                        fileName = fileName.Substring(0, fileName.Length - 1);
                    }

                    if (!string.IsNullOrEmpty(fileName))
                    {
                        // 确保�?.cs 扩展�?                        if (!fileName.EndsWith(".cs"))
                            fileName += ".cs";
                        return fileName;
                    }
                }
            }

            return "";
        }

        // ==================== 撤销/重做方法 ====================

        void PerformUndo()
        {
            if (undoStack.Count == 0)
            {
                AddMessage("⚠️ 没有可撤销的操�?, false);
                return;
            }

            var history = undoStack[undoStack.Count - 1];
            undoStack.RemoveAt(undoStack.Count - 1);

            if (history.action == "apply" && !string.IsNullOrEmpty(history.originalCode))
            {
                // 恢复原代�?                try
                {
                    File.WriteAllText(history.filePath, history.originalCode);
                    AssetDatabase.Refresh();

                    redoStack.Add(history);
                    AddMessage($"↩️ 已撤销: {history.fileName}", false);
                }
                catch (Exception e)
                {
                    AddMessage($"�?撤销失败: {e.Message}", false);
                }
            }
            else if (history.action == "delete" || string.IsNullOrEmpty(history.originalCode))
            {
                // 删除新建的文�?                try
                {
                    if (File.Exists(history.filePath))
                    {
                        File.Delete(history.filePath);
                        AssetDatabase.Refresh();
                    }

                    redoStack.Add(history);
                    AddMessage($"🗑�?已删除新建文�? {history.fileName}", false);
                }
                catch (Exception e)
                {
                    AddMessage($"�?撤销失败: {e.Message}", false);
                }
            }
        }

        void PerformRedo()
        {
            if (redoStack.Count == 0)
            {
                AddMessage("⚠️ 没有可重做的操作", false);
                return;
            }

            var history = redoStack[redoStack.Count - 1];
            redoStack.RemoveAt(redoStack.Count - 1);

            try
            {
                File.WriteAllText(history.filePath, history.newCode);
                AssetDatabase.Refresh();

                undoStack.Add(history);
                AddMessage($"↪️ 已重�? {history.fileName}", false);
            }
            catch (Exception e)
            {
                AddMessage($"�?重做失败: {e.Message}", false);
            }
        }

        void ShowHistory()
        {
            string report = $@"
📜 操作历史
━━━━━━━━━━━━━━━━━━━━━━�?
↩️ 可撤销: {undoStack.Count} �?↪️ 可重�? {redoStack.Count} �?
最近操�?
";

            int count = Mathf.Min(5, undoStack.Count);
            for (int i = undoStack.Count - count; i < undoStack.Count; i++)
            {
                if (i >= 0)
                {
                    var h = undoStack[i];
                    report += $"\n�?{h.fileName} - {h.timestamp}";
                }
            }

            if (undoStack.Count == 0)
            {
                report += "\n暂无操作记录";
            }

            AddMessage(report, false);
        }

        string GetHistoryStatus()
        {
            return $"↩️{undoStack.Count} ↪️{redoStack.Count}";
        }

        // ==================== 预览功能 ====================

        void ShowPreview()
        {
            if (pendingCodeBlocks.Count == 0)
            {
                AddMessage("⚠️ 没有待预览的代码", false);
                return;
            }

            string report = $@"
📋 代码预览
━━━━━━━━━━━━━━━━━━━━━━�?
📊 �?{pendingCodeBlocks.Count} 个代码块:
";

            for (int i = 0; i < pendingCodeBlocks.Count; i++)
            {
                var block = pendingCodeBlocks[i];
                string className = ExtractClassName(block.code);
                string fileName = string.IsNullOrEmpty(className)
                    ? $"GeneratedScript_{i + 1}.cs"
                    : $"{className}.cs";
                int lines = block.code.Split('\n').Length;

                report += $@"

[{i + 1}] 📄 {fileName}
   📏 {lines} 行代�?";
            }

            report += @"
━━━━━━━━━━━━━━━━━━━━━━�?
💡 操作选项:
�?「预�?1�? 查看�?个代码详�?�?「应用�? 应用所有代�?�?「应�?1�? 只应用第1�?�?「跳过�? 放弃当前代码
";

            AddMessage(report, false);
        }

        void ShowPreviewIndex(int index)
        {
            if (index < 0 || index >= pendingCodeBlocks.Count)
            {
                AddMessage($"⚠️ 无效的索�? {index + 1}", false);
                return;
            }

            var block = pendingCodeBlocks[index];
            string className = ExtractClassName(block.code);
            string fileName = string.IsNullOrEmpty(className)
                ? $"GeneratedScript_{index + 1}.cs"
                : $"{className}.cs";
            int lines = block.code.Split('\n').Length;

            string scriptsFolder = $"{Application.dataPath}/Scripts/AIAssistant";
            string filePath = $"{scriptsFolder}/{fileName}";

            bool fileExists = File.Exists(filePath);
            string originalInfo = fileExists
                ? $"\n⚠️ 此操作将覆盖现有文件�?
                : "\n�?新文件，不会覆盖任何内容";

            string report = $@"
📄 代码预览 [{index + 1}/{pendingCodeBlocks.Count}]
━━━━━━━━━━━━━━━━━━━━━━�?
📁 文件: {fileName}
📂 路径: {filePath}
📏 行数: {lines} �?{originalInfo}

━━━━━━━━━━━━━━━━━━━━━━�?代码内容:
━━━━━━━━━━━━━━━━━━━━━━�?{block.code.Substring(0, Mathf.Min(1000, block.code.Length))}
...(省略)...
━━━━━━━━━━━━━━━━━━━━━━�?
💡 输入「应�?{index + 1}」确认应用此代码
";

            AddMessage(report, false);
        }

        void SkipPending()
        {
            int count = pendingCodeBlocks.Count;
            pendingCodeBlocks.Clear();
            pendingPreviewBlocks.Clear();
            AddMessage($"⏭️ 已跳�?{count} 个代码块", false);
        }

        void ApplySingleCode(int index)
        {
            if (index < 0 || index >= pendingCodeBlocks.Count)
            {
                AddMessage($"⚠️ 无效的索�? {index + 1}", false);
                return;
            }

            var block = pendingCodeBlocks[index];
            string className = ExtractClassName(block.code);
            string fileName = string.IsNullOrEmpty(className)
                ? $"GeneratedScript_{index + 1}.cs"
                : $"{className}.cs";

            ApplySingleCodeBlock(block.code, fileName);

            // 从待处理列表移除
            pendingCodeBlocks.RemoveAt(index);
            AddMessage($"📋 剩余 {pendingCodeBlocks.Count} 个待应用代码", false);
        }
    }
}


