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
using System;
using UnityEditorInternal;

// ============================================================
// GameAIAssistant.cs - Unity AI Assistant Plugin v1.8
// Supports: Cloud Models + Local Ollama Models
// ============================================================

public class GameAIAssistant : EditorWindow
{
    // --- Fields ---
    private string inputText = "";
    private Vector2 scrollPos;
    private Vector2 settingsScroll;
    private List<Message> messages = new List<Message>();
    private bool isProcessing = false;
    private string statusText = "就绪";
    private bool showSettings = false;

    // AI Config
    private string apiKey = "";
    private string selectedModel = "deepseek-chat";
    private string selectedLanguage = "zh";
    private string modelType = "cloud";  // "cloud" or "local"
    private string localUrl = "http://localhost:11434/v1";
    private string selectedLocalModel = "qwen2.5:3b";
    private bool autoContext = true;

    // Code blocks
    private List<CodeBlock> pendingCodeBlocks = new List<CodeBlock>();
    private List<PreviewBlock> pendingPreviewBlocks = new List<PreviewBlock>();

    // History
    private List<HistoryEntry> undoStack = new List<HistoryEntry>();
    private List<HistoryEntry> redoStack = new List<HistoryEntry>();

    // Assets
    private string currentProjectName = "";
    private string currentUnityVersion = "";

    // UI Layout Constants - 紧凑模式
    private const float TOOLBAR_HEIGHT = 24f;
    private const float INPUT_HEIGHT = 50f;
    private const float PADDING = 4f;
    private const float LINE_HEIGHT = 22f;
    private const int MAX_VISIBLE_MESSAGES = 8; // 最多显示8条消息

    // Message colors
    private static readonly Color COLOR_USER_BG = new Color(0.12f, 0.42f, 0.82f);
    private static readonly Color COLOR_AI_BG = new Color(0.10f, 0.20f, 0.10f);
    private static readonly Color COLOR_SYS_BG = new Color(0.18f, 0.18f, 0.18f);
    private static readonly Color COLOR_USER_TXT = Color.white;
    private static readonly Color COLOR_AI_TXT = new Color(0.75f, 1f, 0.75f);
    private static readonly Color COLOR_SYS_TXT = new Color(0.65f, 0.65f, 0.65f);
    private static readonly Color COLOR_SEND_BTN = new Color(0.18f, 0.68f, 0.28f);
    private static readonly Color COLOR_THINKING = new Color(1f, 0.78f, 0.15f);
    private static readonly Color COLOR_ORANGE = new Color(0.9f, 0.5f, 0.1f);

    // --- Model Lists ---
    private static readonly ModelInfo[] cloudModels = new ModelInfo[]
    {
        new ModelInfo("deepseek-chat", "DeepSeek V3", "deepseek", true, "国内可用，有免费额度"),
        new ModelInfo("deepseek-coder", "DeepSeek Coder", "deepseek", true, "代码专用模型"),
        new ModelInfo("gpt-4o", "GPT-4o", "openai", false, "最新最强GPT"),
        new ModelInfo("gpt-4o-mini", "GPT-4o Mini", "openai", false, "性价比高"),
        new ModelInfo("gpt-4-turbo", "GPT-4 Turbo", "openai", false, "速度快"),
        new ModelInfo("claude-3-5-sonnet-20241022", "Claude 3.5 Sonnet", "anthropic", false, "最推荐的Claude"),
        new ModelInfo("claude-3-opus-20240229", "Claude 3 Opus", "anthropic", false, "最强Claude"),
        new ModelInfo("gemini-1.5-pro", "Gemini 1.5 Pro", "google", false, "Google最强模型"),
        new ModelInfo("gemini-1.5-flash", "Gemini 1.5 Flash", "google", false, "快速响应"),
        new ModelInfo("qwen-plus", "通义千问 Plus", "qwen", true, "阿里云，国内可用"),
        new ModelInfo("qwen-turbo", "通义千问 Turbo", "qwen", true, "快速版"),
        new ModelInfo("qwen-max", "通义千问 Max", "qwen", true, "最强版"),
        new ModelInfo("qwen2.5-coder-32b-instruct", "Qwen Coder 32B", "qwen", true, "代码专用32B"),
        new ModelInfo("ernie-4.0-8k-latest", "文心一言 4.0", "baidu", true, "百度最强模型"),
        new ModelInfo("moonshot-v1-8k", "Kimi Moonshot V1", "kimi", true, "上下文8K"),
        new ModelInfo("moonshot-v1-32k", "Kimi Moonshot V1 32K", "kimi", true, "上下文32K"),
        new ModelInfo("glm-4-flash", "智谱 GLM-4 Flash", "zhipu", true, "快速免费"),
        new ModelInfo("glm-4", "智谱 GLM-4", "zhipu", true, "标准版"),
        new ModelInfo("spark-4.0", "讯飞星火 V4.0", "iflytek", true, "讯飞最新"),
        new ModelInfo("spark-3.5", "讯飞星火 V3.5", "iflytek", true, "免费额度"),
        new ModelInfo("groq/llama-3.3-70b-versatile", "Groq Llama 3.1 70B", "groq", false, "极速推理"),
        new ModelInfo("groq/mixtral-8x7b-32768", "Groq Mixtral 8x7B", "groq", false, "超快速度"),
        new ModelInfo("mistral-large-latest", "Mistral Large", "mistral", false, "欧洲最强模型"),
        new ModelInfo("cohere-command-r-plus", "Cohere Command R+", "cohere", false, "长上下文"),
    };

    private static readonly LocalModelInfo[] localModels = new LocalModelInfo[]
    {
        new LocalModelInfo("qwen2.5:0.5b", "Qwen 2.5 0.5B", "2GB", "极快", "老电脑/低配置"),
        new LocalModelInfo("qwen2.5:1.5b", "Qwen 2.5 1.5B", "4GB", "快", "普通笔记本"),
        new LocalModelInfo("qwen2.5:3b", "Qwen 2.5 3B", "6GB", "较快", "游戏本/台式机"),
        new LocalModelInfo("qwen2.5:7b", "Qwen 2.5 7B", "8GB", "中等", "游戏本/台式机"),
        new LocalModelInfo("qwen2.5:14b", "Qwen 2.5 14B", "16GB", "较慢", "高端电脑"),
        new LocalModelInfo("llama3:8b", "Llama 3 8B", "8GB", "中等", "通用英语"),
        new LocalModelInfo("codellama:7b", "Code Llama 7B", "8GB", "中等", "代码专用"),
        new LocalModelInfo("llama3.1:8b", "Llama 3.1 8B", "8GB", "中等", "最新Llama"),
        new LocalModelInfo("phi3:3.8b", "Phi-3 Mini 3.8B", "4GB", "快", "微软小模型"),
        new LocalModelInfo("mistral:7b", "Mistral 7B", "8GB", "中等", "欧洲模型"),
        new LocalModelInfo("gemma2:2b", "Gemma 2 2B", "4GB", "快", "Google小模型"),
        new LocalModelInfo("nomic-embed-text", "Nomic Embed Text", "2GB", "极快", "向量嵌入/搜索"),
    };

    // --- Learning Tips ---
    private static readonly string[] learningTips = new string[]
    {
        "编辑器暂停时(Pause)也能运行协程",
        "使用 [ContextMenu] 属性可添加右键菜单",
        "SerializedObject/SerializedProperty 支持批量修改",
        "AssetDatabase.FindAssets() 比 Directory.GetFiles 更快",
        "Undo.RecordObject() 配合 Undo.SetSnapshotGroup() 可实现多步撤销",
        "EditorUtility.SetDirty() 后不必每次调用 SaveAssets()",
        "PropertyDrawer 不支持异步操作和绘图回调",
        "预制体嵌套(PrefabNesting)可减少 DrawCall",
        "StaticBatchingUtility.Combine 可手动合批动态物体",
        "光照探针代理体(LPPV)对移动物体光照插值很有用",
        "Ollama 本地模型完全免费，无需 API Key",
        "Unity 2022+ 原生支持 WebP 纹理格式",
    };

    private static readonly string[] learningTips_en = new string[]
    {
        "Coroutines run even when Editor is paused",
        "Use [ContextMenu] attribute to add right-click menu",
        "SerializedObject/SerializedProperty supports batch modifications",
        "AssetDatabase.FindAssets() is faster than Directory.GetFiles",
        "Undo.RecordObject() with Undo.SetSnapshotGroup() enables multi-step undo",
        "No need to call SaveAssets() after EditorUtility.SetDirty()",
        "PropertyDrawer does not support async operations",
        "Prefab nesting can reduce DrawCalls",
        "StaticBatchingUtility.Combine manually batches dynamic objects",
        "LPPV is useful for moving object lighting interpolation",
        "Ollama local models are completely free",
        "Unity 2022+ has native WebP texture format support",
    };

    // --- Structs ---
    private struct ModelInfo
    {
        public string id;
        public string name;
        public string provider;
        public bool chinaFriendly;
        public string note;
        public ModelInfo(string i, string n, string p, bool c, string note)
        {
            id = i; name = n; provider = p; chinaFriendly = c; this.note = note;
        }
    }

    private struct LocalModelInfo
    {
        public string id;
        public string name;
        public string minRam;
        public string speed;
        public string suitable;
        public LocalModelInfo(string i, string n, string r, string s, string su)
        {
            id = i; name = n; minRam = r; speed = s; suitable = su;
        }
    }

    private class Message
    {
        public string role;
        public string content;
        public Message(string r, string c) { role = r; content = c; }
    }

    private class CodeBlock
    {
        public string code;
        public int index;
        public string fileName;
        public CodeBlock(string c, int i) { code = c; index = i; }
    }

    private class PreviewBlock
    {
        public string code;
        public int index;
        public string filePath;
        public string fileName;
        public int lines;
        public bool willOverwrite;
        public PreviewBlock(string c, int i, string fp, string fn, int l, bool ow)
        {
            code = c; index = i; filePath = fp; fileName = fn; lines = l; willOverwrite = ow;
        }
    }

    private class HistoryEntry
    {
        public string action;
        public string filePath;
        public string fileName;
        public string originalCode;
        public string newCode;
        public HistoryEntry(string a, string fp, string fn, string oc, string nc)
        {
            action = a; filePath = fp; fileName = fn; originalCode = oc; newCode = nc;
        }
    }

    // ============================================================
    // Menu Entry
    // ============================================================
    [MenuItem("Window/Game AI Assistant")]
    public static void ShowWindow()
    {
        var window = GetWindow<GameAIAssistant>("章鱼 AI 助手");
        window.minSize = new Vector2(380, 450);
        window.Show();
    }

    // ============================================================
    // Initialization
    // ============================================================
    void OnEnable()
    {
        LoadConfig();
        GatherProjectInfo();
        _ = DailyLearning();
    }

    void OnDisable()
    {
        SaveConfig();
    }

    void GatherProjectInfo()
    {
        currentProjectName = PlayerSettings.productName;
        currentUnityVersion = Application.unityVersion;
    }

    void LoadConfig()
    {
        string path = GetConfigPath();
        if (File.Exists(path))
        {
            try
            {
                string json = File.ReadAllText(path);
                var data = JsonUtility.FromJson<ConfigData>(json);
                if (data != null)
                {
                    apiKey = data.apiKey ?? "";
                    selectedModel = data.model ?? "deepseek-chat";
                    selectedLanguage = data.language ?? "zh";
                    modelType = data.modelType ?? "cloud";
                    localUrl = data.localUrl ?? "http://localhost:11434/v1";
                    selectedLocalModel = data.localModel ?? "qwen2.5:3b";
                    autoContext = data.autoContext;
                }
            }
            catch { }
        }
    }

    void SaveConfig()
    {
        var data = new ConfigData
        {
            apiKey = apiKey,
            model = selectedModel,
            language = selectedLanguage,
            modelType = modelType,
            localUrl = localUrl,
            localModel = selectedLocalModel,
            autoContext = autoContext
        };
        string json = JsonUtility.ToJson(data, true);
        string path = GetConfigPath();
        string dir = Path.GetDirectoryName(path);
        if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);
        File.WriteAllText(path, json);
    }

    string GetConfigPath() => "Library/GameAIAssistant/config.json";

    [Serializable]
    private class ConfigData
    {
        public string apiKey;
        public string model;
        public string language;
        public string modelType;
        public string localUrl;
        public string localModel;
        public bool autoContext;
    }

    // ============================================================
    // GUI - 极简模式：只有一个输入框
    // ============================================================
    void OnGUI()
    {
        // 处理 Enter 键
        Event e = Event.current;
        if (e.type == EventType.KeyDown && GUI.GetNameOfFocusedControl() == "ChatInput")
        {
            if ((e.keyCode == KeyCode.Return || e.keyCode == KeyCode.KeypadEnter) && !isProcessing)
            {
                if (!string.IsNullOrWhiteSpace(inputText))
                {
                    SendMessage();
                    e.Use();
                }
            }
        }

        // 顶部状态栏（极简）
        EditorGUILayout.BeginHorizontal(EditorStyles.toolbar);
        if (GUILayout.Button("🐙", EditorStyles.toolbarButton, GUILayout.Width(30)))
            showSettings = !showSettings;
        GUILayout.Label(isProcessing ? "..." : "", GUILayout.Width(20));
        GUILayout.FlexibleSpace();
        string m = modelType == "local" ? selectedLocalModel.Split(':')[0] : selectedModel.Split('-')[0];
        if (GUILayout.Button(m, EditorStyles.toolbarDropDown, GUILayout.Width(80)))
            ShowModelSelector();
        EditorGUILayout.EndHorizontal();

        // 消息显示（紧凑，最多显示5条）
        if (messages.Count > 0)
        {
            scrollPos = EditorGUILayout.BeginScrollView(scrollPos, GUILayout.Height(Mathf.Min(messages.Count, 5) * 24 + 10));
            int start = Mathf.Max(0, messages.Count - 5);
            for (int i = start; i < messages.Count; i++)
            {
                var msg = messages[i];
                string prefix = msg.isUser ? "我: " : "🐙: ";
                EditorGUILayout.LabelField(prefix + Truncate(msg.content, 80), EditorStyles.wordWrappedLabel);
            }
            EditorGUILayout.EndScrollView();
        }

        // 输入框（永远在底部）
        EditorGUILayout.BeginHorizontal();
        GUI.SetNextControlName("ChatInput");
        inputText = EditorGUILayout.TextField(inputText, GUILayout.Height(24));
        GUI.enabled = !isProcessing && !string.IsNullOrWhiteSpace(inputText);
        if (GUILayout.Button("→", GUILayout.Width(30), GUILayout.Height(24)))
            SendMessage();
        GUI.enabled = true;
        EditorGUILayout.EndHorizontal();
    }

    string Truncate(string s, int maxLen)
    {
        if (string.IsNullOrEmpty(s)) return "";
        return s.Length > maxLen ? s.Substring(0, maxLen) + "..." : s;
    }

    void DrawToolbar()
    {
        EditorGUILayout.BeginHorizontal(EditorStyles.toolbar);

        Color oldBg = GUI.backgroundColor;
        GUI.backgroundColor = COLOR_ORANGE;
        if (GUILayout.Button("章鱼 AI", EditorStyles.toolbarButton, GUILayout.Width(85)))
            showSettings = !showSettings;
        GUI.backgroundColor = oldBg;

        GUILayout.FlexibleSpace();

        // Model selector dropdown
        string modelDisplay = modelType == "local"
            ? "本地 [" + selectedLocalModel + "]"
            : "云端 [" + GetModelDisplayName(selectedModel) + "]";

        if (GUILayout.Button(modelDisplay, EditorStyles.toolbarDropDown, GUILayout.Width(200)))
        {
            ShowModelSelector();
        }

        EditorGUILayout.Space(5);

        if (GUILayout.Button("设置", EditorStyles.toolbarButton, GUILayout.Width(55)))
        {
            showSettings = !showSettings;
        }

        EditorGUILayout.EndHorizontal();
    }

    string GetModelDisplayName(string modelId)
    {
        foreach (var m in cloudModels)
            if (m.id == modelId) return m.name;
        foreach (var m in localModels)
            if (m.id == modelId) return m.name;
        return modelId;
    }

    void ShowModelSelector()
    {
        var menu = new GenericMenu();

        menu.AddItem(new GUIContent("云端模型"), modelType == "cloud", () =>
        {
            modelType = "cloud";
            SaveConfig();
        });

        foreach (var m in cloudModels)
        {
            string label = m.name + " (" + m.id + ")" + (m.chinaFriendly ? " [CN]" : "");
            menu.AddItem(new GUIContent(label), selectedModel == m.id && modelType == "cloud", () =>
            {
                modelType = "cloud";
                selectedModel = m.id;
                SaveConfig();
            });
        }

        menu.AddSeparator("");

        menu.AddItem(new GUIContent("本地模型 (Ollama)"), modelType == "local", () =>
        {
            modelType = "local";
            SaveConfig();
        });

        foreach (var m in localModels)
        {
            string label = m.name + " (" + m.id + ") - " + m.minRam;
            menu.AddItem(new GUIContent(label), selectedLocalModel == m.id && modelType == "local", () =>
            {
                modelType = "local";
                selectedLocalModel = m.id;
                SaveConfig();
            });
        }

        menu.ShowAsContext();
    }

    void DrawSettingsPanel(ref float usedHeight, float availableHeight)
    {
        float panelHeight = availableHeight - usedHeight;
        settingsScroll = EditorGUILayout.BeginScrollView(settingsScroll, GUILayout.Height(panelHeight));

        EditorGUILayout.Space(5);

        // --- Model Settings ---
        EditorGUILayout.LabelField("模型设置", EditorStyles.boldLabel);
        EditorGUILayout.BeginVertical("box");

        modelType = EditorGUILayout.Popup("模型类型", modelType == "cloud" ? 0 : 1,
            new string[] { "云端 API", "本地 Ollama" }) == 0 ? "cloud" : "local";

        if (modelType == "cloud")
        {
            int cloudIdx = -1;
            for (int i = 0; i < cloudModels.Length; i++)
                if (cloudModels[i].id == selectedModel) { cloudIdx = i; break; }
            if (cloudIdx < 0) cloudIdx = 0;
            cloudIdx = EditorGUILayout.Popup("选择模型", cloudIdx,
                Array.ConvertAll(cloudModels, m => m.name + (m.chinaFriendly ? " [国内]" : "")));
            selectedModel = cloudModels[cloudIdx].id;
            EditorGUILayout.Space(3);
            apiKey = EditorGUILayout.PasswordField("API Key", apiKey);
            EditorGUILayout.BeginHorizontal();
            if (GUILayout.Button("测试连接"))
                _ = TestCloudConnection();
            if (GUILayout.Button("获取 API Key"))
                Application.OpenURL(GetModelKeyUrl(selectedModel));
            EditorGUILayout.EndHorizontal();
        }
        else
        {
            EditorGUILayout.HelpBox("Ollama 本地模型 - 完全免费，无需 API Key\n下载地址: https://ollama.com/download", MessageType.Info);
            EditorGUILayout.Space(3);
            localUrl = EditorGUILayout.TextField("Ollama 地址", localUrl);

            int localIdx = -1;
            for (int i = 0; i < localModels.Length; i++)
                if (localModels[i].id == selectedLocalModel) { localIdx = i; break; }
            if (localIdx < 0) localIdx = 2;
            localIdx = EditorGUILayout.Popup("本地模型", localIdx,
                Array.ConvertAll(localModels, m => m.name + " (" + m.minRam + ")"));
            selectedLocalModel = localModels[localIdx].id;

            EditorGUILayout.BeginHorizontal();
            if (GUILayout.Button("检查 Ollama 状态"))
                _ = TestOllamaConnection();
            if (GUILayout.Button("下载模型"))
                Application.OpenURL("https://ollama.com/library/" + selectedLocalModel.Split(':')[0]);
            EditorGUILayout.EndHorizontal();
        }

        EditorGUILayout.EndVertical();
        EditorGUILayout.Space(5);

        // --- Language ---
        EditorGUILayout.LabelField("界面语言", EditorStyles.boldLabel);
        EditorGUILayout.BeginVertical("box");
        int langIdx = selectedLanguage == "zh" ? 0 : 1;
        langIdx = EditorGUILayout.Popup("语言", langIdx, new string[] { "中文", "English" });
        selectedLanguage = langIdx == 0 ? "zh" : "en";
        EditorGUILayout.EndVertical();
        EditorGUILayout.Space(5);

        // --- Other Settings ---
        EditorGUILayout.LabelField("其他设置", EditorStyles.boldLabel);
        EditorGUILayout.BeginVertical("box");
        autoContext = EditorGUILayout.Toggle("发送时自动附加项目信息", autoContext);

        if (GUILayout.Button("保存设置"))
        {
            SaveConfig();
            AddMessage(selectedLanguage == "zh" ? "设置已保存！" : "Settings saved!", false);
        }

        if (GUILayout.Button("打开知识库文件夹"))
            OpenKnowledgeBase();

        if (GUILayout.Button("清空对话"))
            messages.Clear();

        EditorGUILayout.EndVertical();

        EditorGUILayout.EndScrollView();
    }

    void DrawChatArea(float chatHeight)
    {
        scrollPos = EditorGUILayout.BeginScrollView(scrollPos, GUILayout.Height(chatHeight));

        if (messages.Count == 0)
        {
            DrawWelcomeMessage();
        }
        else
        {
            foreach (var msg in messages)
            {
                DrawMessage(msg);
            }
        }

        EditorGUILayout.EndScrollView();
    }

    void DrawWelcomeMessage()
    {
        Color oldBg = GUI.backgroundColor;
        GUI.backgroundColor = COLOR_AI_BG;

        EditorGUILayout.BeginVertical("box", GUILayout.MinHeight(80));
        GUILayout.Space(5);
        GUILayout.Label("🐙 章鱼 AI 助手", EditorStyles.boldLabel);
        GUILayout.Space(3);

        string welcomeText = selectedLanguage == "zh"
            ? "你好！我是章鱼 AI 助手，可以帮你：\n• 编写 Unity C# 脚本\n• 搜索免费可商用的游戏素材\n• 解释 Unity 概念和 API\n• 诊断和修复 Bug\n\n输入你的问题，然后按 发送 按钮或按 Enter 键发送！"
            : "Hello! I'm Octopus AI Assistant.\n• Write Unity C# scripts\n• Search for free game assets\n• Explain Unity concepts\n• Fix bugs\n\nType your question and press Send or Enter!";

        GUILayout.Label(welcomeText, EditorStyles.wordWrappedLabel, GUILayout.MinHeight(60));
        GUILayout.Space(5);
        EditorGUILayout.EndVertical();

        GUI.backgroundColor = oldBg;
    }

    void DrawMessage(Message msg)
    {
        Color oldBg = GUI.backgroundColor;
        Color txtColor;

        if (msg.role == "user")
        {
            GUI.backgroundColor = COLOR_USER_BG;
            txtColor = COLOR_USER_TXT;
        }
        else if (msg.role == "assistant")
        {
            GUI.backgroundColor = COLOR_AI_BG;
            txtColor = COLOR_AI_TXT;
        }
        else
        {
            GUI.backgroundColor = COLOR_SYS_BG;
            txtColor = COLOR_SYS_TXT;
        }

        string roleLabel = msg.role == "user" ? "你" : msg.role == "assistant" ? "AI" : "系统";

        EditorGUILayout.BeginVertical("box");
        EditorGUILayout.BeginHorizontal();

        Color oldTxt = GUI.contentColor;
        GUI.contentColor = txtColor;

        GUILayout.Label(roleLabel + ":", GUILayout.Width(50));

        // Copy button for AI messages with code
        if (msg.role == "assistant" && msg.content.Contains("```"))
        {
            GUILayout.FlexibleSpace();
            if (GUILayout.Button("复制代码", EditorStyles.miniButton, GUILayout.Width(70)))
            {
                string code = ExtractCode(msg.content);
                EditorGUIUtility.systemCopyBuffer = code;
                statusText = selectedLanguage == "zh" ? "代码已复制！" : "Code copied!";
            }
        }

        GUI.contentColor = oldTxt;
        EditorGUILayout.EndHorizontal();

        string display = msg.content;
        if (display.Length > 4000)
            display = display.Substring(0, 4000) + "\n... (内容过长已截断)";

        var style = new GUIStyle(EditorStyles.label) { wordWrap = true, richText = true };
        GUILayout.Label(display, style, GUILayout.ExpandHeight(true));
        GUILayout.Space(2);
        EditorGUILayout.EndVertical();

        GUILayout.Space(3);
        GUI.backgroundColor = oldBg;
    }

    void DrawPendingCodePanel()
    {
        Color oldBg = GUI.backgroundColor;
        GUI.backgroundColor = new Color(0.25f, 0.2f, 0.3f);

        EditorGUILayout.BeginVertical("box");
        string lang = selectedLanguage;
        string title = "待应用代码块 (" + pendingCodeBlocks.Count + "个)";
        EditorGUILayout.LabelField(title, EditorStyles.boldLabel);

        EditorGUILayout.BeginHorizontal();
        if (GUILayout.Button("应用 #1"))
            ApplyPending(0);
        if (pendingCodeBlocks.Count > 1 && GUILayout.Button("全部应用"))
        {
            while (pendingCodeBlocks.Count > 0)
                ApplyPending(0);
        }
        if (GUILayout.Button("跳过"))
            SkipPending();
        EditorGUILayout.EndHorizontal();
        EditorGUILayout.EndVertical();

        GUILayout.Space(PADDING);
        GUI.backgroundColor = oldBg;
    }

    void DrawInputArea()
    {
        EditorGUILayout.BeginHorizontal();

        GUI.SetNextControlName("ChatInputField");
        EditorGUI.BeginChangeCheck();
        inputText = EditorGUILayout.TextField(inputText, GUILayout.Height(INPUT_HEIGHT));
        bool textChanged = EditorGUI.EndChangeCheck();

        Color oldBg = GUI.backgroundColor;
        GUI.backgroundColor = isProcessing ? Color.gray : COLOR_SEND_BTN;
        GUI.enabled = !isProcessing && !string.IsNullOrWhiteSpace(inputText);
        if (GUILayout.Button("发送", GUILayout.Width(SEND_WIDTH), GUILayout.Height(INPUT_HEIGHT)))
        {
            SendMessage();
        }
        GUI.enabled = true;
        GUI.backgroundColor = oldBg;

        EditorGUILayout.EndHorizontal();
    }

    void DrawStatusBar()
    {
        Color oldBg = GUI.backgroundColor;
        EditorGUILayout.BeginHorizontal(EditorStyles.toolbar);

        if (isProcessing)
        {
            GUI.backgroundColor = COLOR_THINKING;
            GUILayout.Label("思考中...", EditorStyles.miniLabel);
        }
        else
        {
            GUILayout.Label(statusText, EditorStyles.miniLabel);
        }

        GUILayout.FlexibleSpace();

        string modelInfo = modelType == "local"
            ? "本地 [" + selectedLocalModel + "]"
            : "云端 [" + GetModelDisplayName(selectedModel) + "]";
        GUILayout.Label(modelInfo, EditorStyles.miniLabel);

        GUI.backgroundColor = oldBg;
        EditorGUILayout.EndHorizontal();
    }

    // ============================================================
    // Keyboard Events - Handle Enter Key
    // ============================================================
    // ============================================================
    // Message Handling
    // ============================================================
    void AddMessage(string content, bool isUser)
    {
        messages.Add(new Message(isUser ? "user" : "assistant", content));
        // Auto-scroll to bottom
        scrollPos.y = float.MaxValue;
        Repaint();
    }

    string ExtractCode(string text)
    {
        var match = Regex.Match(text, @"```(?:csharp|cs|gdscript)?\s*\n?([\s\S]*?)```");
        if (match.Success)
            return match.Groups[1].Value.Trim();
        return text;
    }

    // ============================================================
    // Send Message
    // ============================================================
    void SendMessage()
    {
        if (string.IsNullOrWhiteSpace(inputText)) return;
        if (isProcessing) return;

        string userMsg = inputText.Trim();
        inputText = "";
        GUI.FocusControl(null);
        AddMessage(userMsg, true);

        // 先尝试直接执行命令
        string execResult = GameAIExecutor.Execute(userMsg);
        if (execResult != null)
        {
            AddMessage(execResult, false);
            return;
        }

        // 再尝试斜杠命令
        if (HandleCommand(userMsg)) return;

        // 最后才发送给 AI
        isProcessing = true;
        statusText = selectedLanguage == "zh" ? "思考中..." : "Thinking...";
        Repaint();

        _ = SendToAI(userMsg);
    }

    bool HandleCommand(string cmd)
    {
        string c = cmd.Trim().ToLower();

        if (c == "/clear" || c == "/cls") { messages.Clear(); return true; }
        if (c == "/undo") { PerformUndo(); return true; }
        if (c == "/redo") { PerformRedo(); return true; }
        if (c == "/screenshot") { TakeScreenshot(); return true; }
        if (c == "/context") { AddProjectContext(); return true; }
        if (c == "/learn") { _ = DailyLearning(); return true; }
        if (c == "/help") { ShowHelp(); return true; }
        if (c == "/skip") { SkipPending(); return true; }
        if (c == "/models") { ListModels(); return true; }

        if (c.StartsWith("/apply "))
        {
            string num = c.Replace("/apply ", "").Trim();
            if (int.TryParse(num, out int idx))
                ApplyPending(idx - 1);
            return true;
        }

        return false;
    }

    void ShowHelp()
    {
        string help = selectedLanguage == "zh"
            ? "命令列表:\n/help   - 显示帮助\n/clear  - 清空对话\n/context - 添加项目信息\n/screenshot - 截图\n/learn  - 每日学习\n/apply N - 应用第N个代码\n/skip   - 跳过待应用代码\n/undo   - 撤销\n/redo   - 重做\n/models - 列出可用模型"
            : "Commands:\n/help   - Show help\n/clear  - Clear chat\n/context - Add project info\n/screenshot - Screenshot\n/learn  - Daily learning\n/apply N - Apply block N\n/skip   - Skip pending\n/undo   - Undo\n/redo   - Redo\n/models - List models";
        AddMessage(help, false);
    }

    void ListModels()
    {
        string output = selectedLanguage == "zh"
            ? "=== 云端模型 ===\n" : "=== Cloud Models ===\n";
        foreach (var m in cloudModels)
            output += m.name + ": " + m.id + "\n";

        output += "\n=== 本地 Ollama ===\n";
        foreach (var m in localModels)
            output += m.name + " (" + m.id + ") - 需要 " + m.minRam + " RAM\n";

        output += "\n当前模式: " + (modelType == "local" ? "本地" : "云端");
        AddMessage(output, false);
    }

    void AddProjectContext()
    {
        string context = selectedLanguage == "zh"
            ? "[项目信息]\n项目名: " + currentProjectName + "\nUnity: " + currentUnityVersion + "\n平台: " + Application.platform
            : "[Project Info]\nProject: " + currentProjectName + "\nUnity: " + currentUnityVersion + "\nPlatform: " + Application.platform;
        AddMessage(context, false);
    }

    // ============================================================
    // AI Integration
    // ============================================================
    async Task SendToAI(string userMessage)
    {
        try
        {
            if (modelType == "cloud" && string.IsNullOrEmpty(apiKey))
            {
                AddMessage(selectedLanguage == "zh"
                    ? "请先在设置中配置 API Key！"
                    : "Please configure your API Key in Settings!", false);
                isProcessing = false;
                statusText = "就绪";
                return;
            }

            var messages_list = BuildMessages(userMessage);
            string json = BuildRequestJson(messages_list);
            string url = GetApiUrl();
            string key = GetApiKey();

            using (var client = new HttpClient())
            {
                client.Timeout = TimeSpan.FromSeconds(modelType == "local" ? 180 : 120);
                client.DefaultRequestHeaders.Clear();
                if (!string.IsNullOrEmpty(key))
                    client.DefaultRequestHeaders.Add("Authorization", "Bearer " + key);

                var content = new StringContent(json, Encoding.UTF8, "application/json");
                var response = await client.PostAsync(url, content);
                string responseText = await response.Content.ReadAsStringAsync();

                if (!response.IsSuccessStatusCode)
                {
                    string errMsg = "错误 (" + (int)response.StatusCode + "): " + responseText.Substring(0, Math.Min(300, responseText.Length));
                    AddMessage(errMsg, false);
                }
                else
                {
                    string aiResponse = ParseAIResponse(responseText);
                    AddMessage(aiResponse, false);
                    ExtractAndPreviewCode(aiResponse);
                }
            }
        }
        catch (Exception ex)
        {
            AddMessage("错误: " + ex.Message, false);
        }
        finally
        {
            isProcessing = false;
            statusText = "就绪";
            Repaint();
        }
    }

    List<Dictionary<string, string>> BuildMessages(string userMessage)
    {
        var msgs = new List<Dictionary<string, string>>();
        msgs.Add(new Dictionary<string, string> { { "role", "system" }, { "content", GetSystemPrompt() } });

        foreach (var msg in messages)
            msgs.Add(new Dictionary<string, string> { { "role", msg.role }, { "content", msg.content } });

        msgs.Add(new Dictionary<string, string> { { "role", "user" }, { "content", userMessage } });
        return msgs;
    }

    string GetSystemPrompt()
    {
        if (selectedLanguage == "zh")
        {
            return @"你是一个专业的 Unity 游戏开发 AI 助手，名字叫章鱼。
你的能力：
1. 创建 Unity C# 脚本
2. 修改现有代码
3. 搜索免费可商用的游戏素材
4. 解释 Unity 概念和 API
5. 诊断和修复 Bug
代码格式：使用 C#，用 ```csharp 包裹代码，添加注释。
如果生成了代码，提醒用户可以用 /apply N 来保存代码。
当前项目：" + currentProjectName + "，Unity " + currentUnityVersion;
        }
        else
        {
            return @"You are a professional Unity game development AI assistant named Octopus.
Your capabilities: write C# scripts, modify code, search assets, explain APIs, fix bugs.
Code format: use C#, wrap in ```csharp, add comments.
If code is generated, remind user to use /apply N to save.
Current project: " + currentProjectName + ", Unity " + currentUnityVersion;
        }
    }

    string BuildRequestJson(List<Dictionary<string, string>> messages_list)
    {
        // JsonUtility 不能序列化 Dictionary，需要手动构建 JSON
        var sb = new StringBuilder();
        sb.Append("{");
        
        if (modelType == "local")
        {
            sb.Append("\"model\":\"").Append(EscapeJson(selectedLocalModel)).Append("\",");
        }
        else
        {
            sb.Append("\"model\":\"").Append(EscapeJson(selectedModel)).Append("\",");
            sb.Append("\"max_tokens\":4000,\"temperature\":0.7,");
        }
        
        sb.Append("\"stream\":false,");
        sb.Append("\"messages\":[");
        
        for (int i = 0; i < messages_list.Count; i++)
        {
            var msg = messages_list[i];
            if (i > 0) sb.Append(",");
            sb.Append("{\"role\":\"").Append(EscapeJson(msg["role"])).Append("\"");
            sb.Append(",\"content\":\"").Append(EscapeJson(msg["content"])).Append("\"}");
        }
        
        sb.Append("]}");
        return sb.ToString();
    }
    
    string EscapeJson(string s)
    {
        if (string.IsNullOrEmpty(s)) return "";
        return s.Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\n", "\\n").Replace("\r", "\\r").Replace("\t", "\\t");
    }

    string GetApiUrl()
    {
        if (modelType == "local") return localUrl + "/chat/completions";
        if (selectedModel.StartsWith("deepseek")) return "https://api.deepseek.com/v1/chat/completions";
        if (selectedModel.Contains("qwen")) return "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions";
        if (selectedModel.Contains("ernie")) return "https://qianfan.baidubce.com/v2/chat/completions";
        if (selectedModel.Contains("moonshot") || selectedModel.Contains("kimi")) return "https://api.moonshot.cn/v1/chat/completions";
        if (selectedModel.Contains("glm")) return "https://open.bigmodel.cn/api/paas/v4/chat/completions";
        if (selectedModel.Contains("spark")) return "https://spark-api.xf-yun.com/v3.5/chat/completions";
        if (selectedModel.Contains("groq/")) return "https://api.groq.com/openai/v1/chat/completions";
        if (selectedModel.Contains("gemini")) return "https://generativelanguage.googleapis.com/v1beta/models/" + selectedModel + ":generateContent?key=" + apiKey;
        if (selectedModel.Contains("claude")) return "https://api.anthropic.com/v1/messages";
        if (selectedModel.Contains("mistral") || selectedModel.Contains("cohere")) return "https://api.mistral.ai/v1/chat/completions";
        return "https://api.openai.com/v1/chat/completions";
    }

    string GetApiKey()
    {
        return modelType == "local" ? "" : apiKey;
    }

    string ParseAIResponse(string json)
    {
        try
        {
            if (selectedModel.Contains("claude"))
            {
                var data = JsonUtility.FromJson<ClaudeResponse>(json);
                return data?.content?[0]?.text ?? "解析响应失败";
            }
            if (selectedModel.Contains("gemini"))
            {
                var data = JsonUtility.FromJson<GeminiResponse>(json);
                return data?.candidates?[0]?.content?.parts?[0]?.text ?? "解析响应失败";
            }
            var wrapper = JsonUtility.FromJson<OpenAIResponse>(json);
            return wrapper?.choices?[0]?.message?.content ?? "解析响应失败";
        }
        catch { return json; }
    }

    [Serializable]
    private class OpenAIResponse { public List<OpenAIChoice> choices; }
    [Serializable]
    private class OpenAIChoice { public OpenAIMessage message; }
    [Serializable]
    private class OpenAIMessage { public string content; }
    [Serializable]
    private class ClaudeResponse { public List<ClaudeContent> content; }
    [Serializable]
    private class ClaudeContent { public string text; }
    [Serializable]
    private class GeminiResponse { public List<GeminiCandidate> candidates; }
    [Serializable]
    private class GeminiCandidate { public GeminiContent content; }
    [Serializable]
    private class GeminiContent { public List<GeminiPart> parts; }
    [Serializable]
    private class GeminiPart { public string text; }

    // ============================================================
    // Code Preview & Apply
    // ============================================================
    void ExtractAndPreviewCode(string aiResponse)
    {
        var codeBlocks = new List<CodeBlock>();
        int idx = 0;
        var matches = Regex.Matches(aiResponse, @"```(?:csharp|cs)?\s*\n?([\s\S]*?)```");
        foreach (Match match in matches)
        {
            codeBlocks.Add(new CodeBlock(match.Groups[1].Value.Trim(), idx++));
        }
        if (codeBlocks.Count == 0) return;

        pendingCodeBlocks.AddRange(codeBlocks);
        pendingPreviewBlocks.Clear();

        string scriptsFolder = Application.dataPath + "/Scripts/AIAssistant";
        if (!Directory.Exists(scriptsFolder))
            Directory.CreateDirectory(scriptsFolder);

        for (int i = 0; i < codeBlocks.Count; i++)
        {
            var block = codeBlocks[i];
            string className = ExtractClassName(block.code);
            string fileName = string.IsNullOrEmpty(className) ? "GeneratedScript_" + (i + 1) + ".cs" : className + ".cs";
            string filePath = scriptsFolder + "/" + fileName;
            bool fileExists = File.Exists(filePath);
            int lines = block.code.Split('\n').Length;
            pendingPreviewBlocks.Add(new PreviewBlock(block.code, i, filePath, fileName, lines, fileExists));

            string msg = selectedLanguage == "zh"
                ? "代码块 [" + (i + 1) + "]: " + fileName + " (" + lines + "行)\n" + (fileExists ? "⚠️ 将覆盖" : "✓ 新文件") + "\n输入 /apply " + (i + 1) + " 应用"
                : "Code block [" + (i + 1) + "]: " + fileName + " (" + lines + " lines)\n" + (fileExists ? "Overwrite" : "New file") + "\nUse /apply " + (i + 1);
            AddMessage(msg, false);
        }
    }

    string ExtractClassName(string code)
    {
        var match = Regex.Match(code, @"(?:public\s+)?class\s+(\w+)");
        if (match.Success) return match.Groups[1].Value;
        match = Regex.Match(code, @"class\s+(\w+)");
        if (match.Success) return match.Groups[1].Value;
        return "";
    }

    void ApplyPending(int index)
    {
        if (pendingCodeBlocks.Count == 0)
        {
            AddMessage(selectedLanguage == "zh" ? "没有待应用的代码！" : "No code to apply!", false);
            return;
        }
        if (index < 0 || index >= pendingCodeBlocks.Count)
        {
            AddMessage(selectedLanguage == "zh"
                ? "无效序号，请用 /apply 1 - " + pendingCodeBlocks.Count
                : "Invalid index, use /apply 1 - " + pendingCodeBlocks.Count, false);
            return;
        }

        var block = pendingCodeBlocks[index];
        string className = ExtractClassName(block.code);
        string fileName = string.IsNullOrEmpty(className) ? "GeneratedScript_" + (index + 1) + ".cs" : className + ".cs";
        string scriptsFolder = Application.dataPath + "/Scripts/AIAssistant";
        if (!Directory.Exists(scriptsFolder)) Directory.CreateDirectory(scriptsFolder);
        string filePath = scriptsFolder + "/" + fileName;
        bool fileExists = File.Exists(filePath);
        string originalCode = fileExists ? File.ReadAllText(filePath) : "";

        var entry = new HistoryEntry(fileExists ? "modify" : "create", filePath, fileName, originalCode, block.code);
        undoStack.Add(entry);
        redoStack.Clear();

        File.WriteAllText(filePath, block.code);
        AssetDatabase.Refresh();

        AddMessage(selectedLanguage == "zh"
            ? "已保存: " + fileName + "，还剩 " + (pendingCodeBlocks.Count - 1) + " 个"
            : "Saved: " + fileName + ", " + (pendingCodeBlocks.Count - 1) + " remaining", false);

        pendingCodeBlocks.RemoveAt(index);
        pendingPreviewBlocks.RemoveAt(index);
    }

    void SkipPending()
    {
        int count = pendingCodeBlocks.Count;
        pendingCodeBlocks.Clear();
        pendingPreviewBlocks.Clear();
        AddMessage(selectedLanguage == "zh" ? "已跳过 " + count + " 个代码块" : "Skipped " + count + " blocks", false);
    }

    // ============================================================
    // Undo / Redo
    // ============================================================
    void PerformUndo()
    {
        if (undoStack.Count == 0) { AddMessage(selectedLanguage == "zh" ? "没有可撤销的操作" : "Nothing to undo", false); return; }
        var history = undoStack[undoStack.Count - 1];
        undoStack.RemoveAt(undoStack.Count - 1);
        try
        {
            if (history.action == "create")
            {
                if (File.Exists(history.filePath)) { File.Delete(history.filePath); AssetDatabase.Refresh(); }
                redoStack.Add(history);
                AddMessage(selectedLanguage == "zh" ? "已删除: " + history.fileName : "Deleted: " + history.fileName, false);
            }
            else
            {
                File.WriteAllText(history.filePath, history.originalCode);
                AssetDatabase.Refresh();
                redoStack.Add(history);
                AddMessage(selectedLanguage == "zh" ? "已撤销: " + history.fileName : "Undone: " + history.fileName, false);
            }
        }
        catch (Exception ex) { AddMessage("撤销失败: " + ex.Message, false); }
    }

    void PerformRedo()
    {
        if (redoStack.Count == 0) { AddMessage(selectedLanguage == "zh" ? "没有可重做的操作" : "Nothing to redo", false); return; }
        var history = redoStack[redoStack.Count - 1];
        redoStack.RemoveAt(redoStack.Count - 1);
        try
        {
            File.WriteAllText(history.filePath, history.newCode);
            AssetDatabase.Refresh();
            undoStack.Add(history);
            AddMessage(selectedLanguage == "zh" ? "已重做: " + history.fileName : "Redone: " + history.fileName, false);
        }
        catch (Exception ex) { AddMessage("重做失败: " + ex.Message, false); }
    }

    // ============================================================
    // Utilities
    // ============================================================
    void OpenKnowledgeBase()
    {
        string path = Application.dataPath + "/Scripts/KnowledgeBase";
        if (!Directory.Exists(path)) Directory.CreateDirectory(path);
        EditorUtility.RevealInFinder(path);
    }

    async Task DailyLearning()
    {
        System.Random rand = new System.Random();
        int topicIdx = rand.Next(learningTips.Length);
        string tip = selectedLanguage == "zh" ? learningTips[topicIdx] : learningTips_en[topicIdx];
        AddMessage(selectedLanguage == "zh" ? "每日学习：" : "Daily Tip:", false);
        AddMessage(tip, false);
        await Task.Delay(100);
    }

    void TakeScreenshot()
    {
        string path = Application.dataPath + "/../Screenshots";
        if (!Directory.Exists(path)) Directory.CreateDirectory(path);
        ScreenCapture.CaptureScreenshot(path + "/screenshot_" + DateTime.Now.ToString("yyyyMMdd_HHmmss") + ".png");
        AddMessage(selectedLanguage == "zh" ? "截图已保存" : "Screenshot saved", false);
    }

    async Task TestCloudConnection()
    {
        try
        {
            isProcessing = true;
            statusText = selectedLanguage == "zh" ? "测试连接中..." : "Testing...";
            Repaint();

            using (var client = new HttpClient())
            {
                client.Timeout = TimeSpan.FromSeconds(15);
                var testJson = JsonUtility.ToJson(new { model = selectedModel, messages = new object[] { new { role = "user", content = "hi" } }, max_tokens = 5 });
                var content = new StringContent(testJson, Encoding.UTF8, "application/json");
                client.DefaultRequestHeaders.Clear();
                if (!string.IsNullOrEmpty(apiKey))
                    client.DefaultRequestHeaders.Add("Authorization", "Bearer " + apiKey);
                var response = await client.PostAsync(GetApiUrl(), content);
                AddMessage(response.IsSuccessStatusCode
                    ? (selectedLanguage == "zh" ? "连接成功！" : "Connection successful!")
                    : "连接失败: " + (int)response.StatusCode, false);
            }
        }
        catch (Exception ex) { AddMessage("连接错误: " + ex.Message, false); }
        finally { isProcessing = false; statusText = "就绪"; Repaint(); }
    }

    async Task TestOllamaConnection()
    {
        try
        {
            isProcessing = true;
            statusText = selectedLanguage == "zh" ? "检查 Ollama..." : "Checking Ollama...";
            Repaint();

            using (var client = new HttpClient())
            {
                client.Timeout = TimeSpan.FromSeconds(10);
                var response = await client.GetAsync(localUrl.Replace("/v1", "") + "/api/tags");
                if (response.IsSuccessStatusCode)
                {
                    string body = await response.Content.ReadAsStringAsync();
                    var tags = JsonUtility.FromJson<OllamaTagsResponse>(body);
                    string modelList = "";
                    if (tags?.models != null)
                        foreach (var m in tags.models) modelList += "- " + m.name + "\n";
                    AddMessage(selectedLanguage == "zh"
                        ? "Ollama 连接成功！\n已安装模型：\n" + modelList
                        : "Ollama connected!\nInstalled models:\n" + modelList, false);
                }
                else
                {
                    AddMessage(selectedLanguage == "zh"
                        ? "无法连接 Ollama (HTTP " + (int)response.StatusCode + ")\n请确认 Ollama 已启动"
                        : "Cannot connect to Ollama (HTTP " + (int)response.StatusCode + ")\nMake sure Ollama is running", false);
                }
            }
        }
        catch (Exception ex)
        {
            AddMessage(selectedLanguage == "zh"
                ? "Ollama 连接失败: " + ex.Message + "\n请确认 Ollama 已安装并运行"
                : "Ollama failed: " + ex.Message + "\nMake sure Ollama is installed and running", false);
        }
        finally { isProcessing = false; statusText = "就绪"; Repaint(); }
    }

    private class OllamaTagsResponse { public List<OllamaModel> models; }
    private class OllamaModel { public string name; }

    string GetModelKeyUrl(string modelId)
    {
        if (modelId.Contains("deepseek")) return "https://platform.deepseek.com/api_keys";
        if (modelId.Contains("qwen")) return "https://dashscope.console.aliyun.com/apiKey";
        if (modelId.Contains("ernie")) return "https://console.bce.baidu.com/qianfan/ais/console";
        if (modelId.Contains("moonshot") || modelId.Contains("kimi")) return "https://platform.moonshot.cn/console/api-keys";
        if (modelId.Contains("glm")) return "https://open.bigmodel.cn/usercenter/apikeys";
        if (modelId.Contains("spark")) return "https://xinghuo.xfyun.cn/sparkapi";
        if (modelId.StartsWith("gpt")) return "https://platform.openai.com/api-keys";
        if (modelId.Contains("claude")) return "https://console.anthropic.com/settings/keys";
        if (modelId.Contains("gemini")) return "https://aistudio.google.com/app/apikey";
        return "https://platform.openai.com/api-keys";
    }
}

// ============================================================
// GameAIExecutor - 直接执行 Unity 操作（不废话）
// ============================================================
public static class GameAIExecutor
{
    // 识别并执行命令
    public static string Execute(string command)
    {
        string cmd = command.ToLower().Trim();
        
        // 创建地面
        if (cmd.Contains("地面") || cmd.Contains("floor") || cmd.Contains("ground") || cmd.Contains("plane"))
        {
            return CreateGround();
        }
        
        // 创建立方体/方块
        if (cmd.Contains("立方体") || cmd.Contains("方块") || cmd.Contains("cube") || cmd.Contains("block"))
        {
            return CreateCube();
        }
        
        // 创建球体
        if (cmd.Contains("球") || cmd.Contains("sphere") || cmd.Contains("ball"))
        {
            return CreateSphere();
        }
        
        // 创建圆柱
        if (cmd.Contains("圆柱") || cmd.Contains("cylinder"))
        {
            return CreateCylinder();
        }
        
        // 创建胶囊
        if (cmd.Contains("胶囊") || cmd.Contains("capsule"))
        {
            return CreateCapsule();
        }
        
        // 添加光源
        if (cmd.Contains("灯") || cmd.Contains("light") || cmd.Contains("光照"))
        {
            return CreateLight();
        }
        
        // 创建空对象
        if (cmd.Contains("空对象") || cmd.Contains("empty") || cmd.Contains("空物体"))
        {
            return CreateEmpty();
        }
        
        // 创建相机
        if (cmd.Contains("相机") || cmd.Contains("camera") || cmd.Contains("摄像机"))
        {
            return CreateCamera();
        }
        
        // 添加刚体
        if (cmd.Contains("刚体") || cmd.Contains("rigidbody"))
        {
            return AddRigidbody();
        }
        
        // 添加碰撞器
        if (cmd.Contains("碰撞") || cmd.Contains("collider"))
        {
            return AddCollider();
        }
        
        // 清空场景
        if (cmd.Contains("清空") || cmd.Contains("clear"))
        {
            return ClearScene();
        }
        
        // 保存场景
        if (cmd.Contains("保存") || cmd.Contains("save"))
        {
            return SaveScene();
        }
        
        return null; // 没有匹配的命令
    }
    
    static string CreateGround()
    {
        var go = GameObject.CreatePrimitive(PrimitiveType.Plane);
        go.name = "Ground";
        go.transform.position = Vector3.zero;
        go.transform.localScale = new Vector3(2, 1, 2);
        Selection.activeGameObject = go;
        Undo.RegisterCreatedObjectUndo(go, "Create Ground");
        return "✓ 已创建地面 (Plane)";
    }
    
    static string CreateCube()
    {
        var go = GameObject.CreatePrimitive(PrimitiveType.Cube);
        go.name = "Cube";
        go.transform.position = new Vector3(0, 0.5f, 0);
        Selection.activeGameObject = go;
        Undo.RegisterCreatedObjectUndo(go, "Create Cube");
        return "✓ 已创建立方体";
    }
    
    static string CreateSphere()
    {
        var go = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        go.name = "Sphere";
        go.transform.position = new Vector3(0, 1f, 0);
        Selection.activeGameObject = go;
        Undo.RegisterCreatedObjectUndo(go, "Create Sphere");
        return "✓ 已创建球体";
    }
    
    static string CreateCylinder()
    {
        var go = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
        go.name = "Cylinder";
        go.transform.position = new Vector3(0, 1f, 0);
        Selection.activeGameObject = go;
        Undo.RegisterCreatedObjectUndo(go, "Create Cylinder");
        return "✓ 已创建圆柱";
    }
    
    static string CreateCapsule()
    {
        var go = GameObject.CreatePrimitive(PrimitiveType.Capsule);
        go.name = "Capsule";
        go.transform.position = new Vector3(0, 1f, 0);
        Selection.activeGameObject = go;
        Undo.RegisterCreatedObjectUndo(go, "Create Capsule");
        return "✓ 已创建胶囊";
    }
    
    static string CreateLight()
    {
        var go = new GameObject("Directional Light");
        go.transform.rotation = Quaternion.Euler(50, -30, 0);
        var light = go.AddComponent<Light>();
        light.type = LightType.Directional;
        light.intensity = 1.5f;
        Selection.activeGameObject = go;
        Undo.RegisterCreatedObjectUndo(go, "Create Light");
        return "✓ 已创建方向光";
    }
    
    static string CreateEmpty()
    {
        var go = new GameObject("Empty");
        go.transform.position = Vector3.zero;
        Selection.activeGameObject = go;
        Undo.RegisterCreatedObjectUndo(go, "Create Empty");
        return "✓ 已创建空对象";
    }
    
    static string CreateCamera()
    {
        var go = new GameObject("Camera");
        go.transform.position = new Vector3(0, 2, -10);
        go.transform.rotation = Quaternion.Euler(10, 0, 0);
        go.AddComponent<Camera>();
        go.AddComponent<AudioListener>();
        Selection.activeGameObject = go;
        Undo.RegisterCreatedObjectUndo(go, "Create Camera");
        return "✓ 已创建相机";
    }
    
    static string AddRigidbody()
    {
        var selected = Selection.activeGameObject;
        if (selected == null)
            return "⚠ 请先选择一个物体";
        
        if (selected.GetComponent<Rigidbody>())
            return "⚠ 该物体已有刚体";
        
        var rb = selected.AddComponent<Rigidbody>();
        rb.mass = 1f;
        rb.useGravity = true;
        Undo.RegisterCreatedObjectUndo(rb, "Add Rigidbody");
        return "✓ 已添加刚体到 " + selected.name;
    }
    
    static string AddCollider()
    {
        var selected = Selection.activeGameObject;
        if (selected == null)
            return "⚠ 请先选择一个物体";
        
        if (selected.GetComponent<Collider>())
            return "⚠ 该物体已有碰撞器";
        
        var collider = selected.AddComponent<BoxCollider>();
        Undo.RegisterCreatedObjectUndo(collider, "Add Collider");
        return "✓ 已添加碰撞器到 " + selected.name;
    }
    
    static string ClearScene()
    {
        var objects = GameObject.FindObjectsOfType<GameObject>();
        int count = 0;
        foreach (var obj in objects)
        {
            if (obj != null && obj.transform.parent == null)
            {
                if (!obj.name.StartsWith("Main Camera") && !obj.name.StartsWith("Directional"))
                {
                    Undo.DestroyObjectImmediate(obj);
                    count++;
                }
            }
        }
        return "✓ 已清除 " + count + " 个物体";
    }
    
    static string SaveScene()
    {
        var scene = UnityEditor.SceneManagement.EditorSceneManager.GetActiveScene();
        if (string.IsNullOrEmpty(scene.path))
        {
            UnityEditor.SceneManagement.EditorSceneManager.SaveScene(scene, "Assets/Scenes/Scene.unity");
            return "✓ 场景已保存到 Assets/Scenes/Scene.unity";
        }
        else
        {
            UnityEditor.SceneManagement.EditorSceneManager.SaveScene(scene);
            return "✓ 场景已保存";
        }
    }
}

// ============================================================
// GameAISkill - Skill System
// ============================================================
public static class GameAISkill
{
    public static void Use(string skillName)
    {
        EditorUtility.DisplayDialog("Skill", "Skill: " + skillName, "OK");
    }

    public static void RegisterSkill(string name, Action callback)
    {
        // Placeholder
    }
}
