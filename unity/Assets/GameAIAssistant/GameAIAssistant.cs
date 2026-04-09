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
// GameAIAssistant.cs - Unity AI Assistant Plugin v1.7
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
    private string statusText = "Ready";
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
        new LocalModelInfo("qwen2.5:14b", "Qwen 2.5 14B", "16GB", "慢", "高端电脑"),
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
        "提示：编辑器暂停时(Pause)也能运行异步协程",
        "提示：使用 [ContextMenu] 属性可添加编辑器内右键菜单",
        "提示：SerializedObject/SerializedProperty 支持批量修改",
        "提示：AssetDatabase.FindAssets() 比 Directory.GetFiles 更快",
        "提示：Undo.RecordObject() 配合 Undo.SetSnapshotGroup() 可实现多步撤销",
        "提示：EditorUtility.SetDirty() 后不必每次都 SaveAssets()",
        "提示：PropertyDrawer 支持异步操作和图标绘制",
        "提示：预制体嵌套(PrefabNesting)可大幅减少 DrawCall",
        "提示：StaticBatchingUtility.Combine 可手动合批动态物体",
        "提示：光照探针代理体(LPPV)对移动物体光照插值很有用",
        "提示：Ollama 本地模型完全免费，无 API 调用次数限制",
        "提示：Unity 2022+ 原生支持 WebP 纹理格式",
    };

    private static readonly string[] learningTips_en = new string[]
    {
        "Tip: Coroutines run even when Editor is paused",
        "Tip: Use [ContextMenu] attribute to add right-click menu in Editor",
        "Tip: SerializedObject/SerializedProperty supports batch modifications",
        "Tip: AssetDatabase.FindAssets() is faster than Directory.GetFiles",
        "Tip: Undo.RecordObject() with Undo.SetSnapshotGroup() enables multi-step undo",
        "Tip: No need to call SaveAssets() every time after EditorUtility.SetDirty()",
        "Tip: PropertyDrawer supports async operations and custom icons",
        "Tip: Prefab nesting can significantly reduce DrawCalls",
        "Tip: StaticBatchingUtility.Combine manually batches dynamic objects",
        "Tip: Light Probe Proxy Volume (LPPV) is useful for moving object lighting",
        "Tip: Ollama local models are completely free with no API call limits",
        "Tip: Unity 2022+ has native WebP texture format support",
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

    private class OllamaTagsResponse
    {
        public List<OllamaModel> models;
    }

    private class OllamaModel
    {
        public string name;
        public string modified_at;
        public long size;
    }

    // ============================================================
    // Menu Entry
    // ============================================================
    [MenuItem("Window/Game AI Assistant")]
    public static void ShowWindow()
    {
        var window = GetWindow<GameAIAssistant>("Octopus AI");
        window.minSize = new Vector2(420, 520);
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
    // GUI
    // ============================================================
    void OnGUI()
    {
        DrawToolbar();

        if (showSettings)
            DrawSettingsPanel();
        else
            DrawMainPanel();
    }

    void DrawToolbar()
    {
        EditorGUILayout.BeginHorizontal(EditorStyles.toolbar);

        Color oldBg = GUI.backgroundColor;
        GUI.backgroundColor = new Color(0.9f, 0.5f, 0.1f);
        if (GUILayout.Button("Octopus AI", EditorStyles.toolbarButton, GUILayout.Width(100)))
            showSettings = !showSettings;
        GUI.backgroundColor = oldBg;

        GUILayout.FlexibleSpace();

        if (GUILayout.Button(modelType == "local" ? "Local: " + selectedLocalModel : "Cloud: " + selectedModel,
            EditorStyles.toolbarDropDown, GUILayout.Width(200)))
        {
            ShowModelSelector();
        }

        EditorGUILayout.Space(5);

        if (GUILayout.Button("Settings", EditorStyles.toolbarButton, GUILayout.Width(70)))
        {
            showSettings = !showSettings;
        }

        EditorGUILayout.EndHorizontal();
    }

    void ShowModelSelector()
    {
        GenericMenu menu = new GenericMenu();

        menu.AddItem(new GUIContent("Cloud Models"), modelType == "cloud", () =>
        {
            modelType = "cloud";
            SaveConfig();
        });

        foreach (var m in cloudModels)
        {
            string label = $"Cloud/{m.name} ({m.id})";
            if (m.chinaFriendly)
                label += " [CN]";
            menu.AddItem(new GUIContent(label), selectedModel == m.id && modelType == "cloud", () =>
            {
                modelType = "cloud";
                selectedModel = m.id;
                SaveConfig();
            });
        }

        menu.AddSeparator("");

        menu.AddItem(new GUIContent("Local Models (Ollama)"), modelType == "local", () =>
        {
            modelType = "local";
            SaveConfig();
        });

        foreach (var m in localModels)
        {
            string label = $"Local/{m.name} ({m.id})";
            menu.AddItem(new GUIContent(label), selectedLocalModel == m.id && modelType == "local", () =>
            {
                modelType = "local";
                selectedLocalModel = m.id;
                SaveConfig();
            });
        }

        menu.ShowAsContext();
    }

    void DrawSettingsPanel()
    {
        settingsScroll = EditorGUILayout.BeginScrollView(settingsScroll);

        EditorGUILayout.Space(5);

        // --- Model Type ---
        EditorGUILayout.LabelField("Model Settings", EditorStyles.boldLabel);
        EditorGUILayout.BeginVertical("box");

        modelType = EditorGUILayout.Popup("Model Type", modelType == "cloud" ? 0 : 1, new string[] { "Cloud (API)", "Local (Ollama)" }) == 0 ? "cloud" : "local";

        if (modelType == "cloud")
        {
            // Cloud model selector
            int currentIdx = -1;
            for (int i = 0; i < cloudModels.Length; i++)
            {
                if (cloudModels[i].id == selectedModel) { currentIdx = i; break; }
            }
            if (currentIdx < 0) currentIdx = 0;
            currentIdx = EditorGUILayout.Popup("Model", currentIdx, Array.ConvertAll(cloudModels, m => m.name));
            selectedModel = cloudModels[currentIdx].id;

            EditorGUILayout.Space(3);
            apiKey = EditorGUILayout.PasswordField("API Key", apiKey);

            EditorGUILayout.BeginHorizontal();
            if (GUILayout.Button("Test Connection"))
            {
                _ = TestCloudConnection();
            }
            if (GUILayout.Button("Get API Key"))
            {
                Application.OpenURL(GetModelKeyUrl(selectedModel));
            }
            EditorGUILayout.EndHorizontal();
        }
        else
        {
            // Local Ollama settings
            EditorGUILayout.HelpBox("Ollama 本地模型 - 完全免费，无需 API Key\n下载地址: https://ollama.com/download", MessageType.Info);

            EditorGUILayout.Space(3);
            localUrl = EditorGUILayout.TextField("Ollama URL", localUrl);

            int localIdx = -1;
            for (int i = 0; i < localModels.Length; i++)
            {
                if (localModels[i].id == selectedLocalModel) { localIdx = i; break; }
            }
            if (localIdx < 0) localIdx = 2; // default to qwen2.5:3b
            localIdx = EditorGUILayout.Popup("Local Model", localIdx, Array.ConvertAll(localModels, m => m.name + " (" + m.minRam + ")"));
            selectedLocalModel = localModels[localIdx].id;

            EditorGUILayout.BeginHorizontal();
            if (GUILayout.Button("Check Ollama Status"))
            {
                _ = TestOllamaConnection();
            }
            if (GUILayout.Button("Download Model"))
            {
                Application.OpenURL("https://ollama.com/library/" + selectedLocalModel.Split(':')[0]);
            }
            EditorGUILayout.EndHorizontal();
        }

        EditorGUILayout.EndVertical();

        EditorGUILayout.Space(5);

        // --- Language ---
        EditorGUILayout.LabelField("Language / 语言", EditorStyles.boldLabel);
        EditorGUILayout.BeginVertical("box");
        int langIdx = selectedLanguage == "zh" ? 0 : 1;
        langIdx = EditorGUILayout.Popup("Language", langIdx, new string[] { "中文", "English" });
        selectedLanguage = langIdx == 0 ? "zh" : "en";
        EditorGUILayout.EndVertical();

        EditorGUILayout.Space(5);

        // --- Other Settings ---
        EditorGUILayout.LabelField("Other Settings", EditorStyles.boldLabel);
        EditorGUILayout.BeginVertical("box");
        autoContext = EditorGUILayout.Toggle("Auto Add Context (发送时附加项目信息)", autoContext);

        if (GUILayout.Button("Save & Apply"))
        {
            SaveConfig();
            AddMessage(selectedLanguage == "zh" ? "配置已保存！" : "Settings saved!", false);
        }

        if (GUILayout.Button("Open Knowledge Base"))
        {
            OpenKnowledgeBase();
        }

        if (GUILayout.Button("Clear Chat"))
        {
            messages.Clear();
        }

        EditorGUILayout.EndVertical();

        EditorGUILayout.EndScrollView();
    }

    void DrawMainPanel()
    {
        // Project info bar
        EditorGUILayout.BeginVertical("box");
        EditorGUILayout.BeginHorizontal();
        GUILayout.Label(currentProjectName, EditorStyles.miniLabel);
        GUILayout.FlexibleSpace();
        GUILayout.Label("Unity " + currentUnityVersion, EditorStyles.miniLabel);
        EditorGUILayout.EndHorizontal();
        EditorGUILayout.EndVertical();

        // Chat area
        scrollPos = EditorGUILayout.BeginScrollView(scrollPos, GUILayout.Height(Mathf.Max(200, position.height - 220)));

        foreach (var msg in messages)
        {
            DrawMessage(msg);
        }

        EditorGUILayout.EndScrollView();

        // Pending code blocks
        if (pendingCodeBlocks.Count > 0)
        {
            EditorGUILayout.BeginVertical("box");
            string lang = selectedLanguage;
            string title = lang == "zh"
                ? $"待应用代码块 ({pendingCodeBlocks.Count}个)"
                : $"Pending Code Blocks ({pendingCodeBlocks.Count})";
            EditorGUILayout.LabelField(title, EditorStyles.boldLabel);

            EditorGUILayout.BeginHorizontal();
            if (GUILayout.Button(lang == "zh" ? "应用 #1" : "Apply #1"))
                ApplyPending(0);
            if (pendingCodeBlocks.Count > 1 && GUILayout.Button(lang == "zh" ? "全部应用" : "Apply All"))
            {
                while (pendingCodeBlocks.Count > 0)
                    ApplyPending(0);
            }
            if (GUILayout.Button(lang == "zh" ? "跳过" : "Skip"))
                SkipPending();
            EditorGUILayout.EndHorizontal();
            EditorGUILayout.EndVertical();
        }

        EditorGUILayout.Space(3);

        // Input area
        EditorGUILayout.BeginHorizontal();
        GUI.SetNextControlName("InputField");
        inputText = EditorGUILayout.TextField(inputText, GUILayout.Height(60));

        Color oldBg = GUI.backgroundColor;
        GUI.backgroundColor = new Color(0.2f, 0.7f, 0.3f);
        GUI.enabled = !isProcessing;
        if (GUILayout.Button("Send", GUILayout.Width(60), GUILayout.Height(60)))
        {
            SendMessage();
        }
        GUI.enabled = true;
        GUI.backgroundColor = oldBg;
        EditorGUILayout.EndHorizontal();

        // Status bar
        EditorGUILayout.BeginHorizontal(EditorStyles.toolbar);
        if (isProcessing)
        {
            GUI.backgroundColor = new Color(1f, 0.8f, 0.2f);
            GUILayout.Label("Thinking...", EditorStyles.miniLabel);
            GUI.backgroundColor = oldBg;
        }
        else
        {
            GUILayout.Label(statusText, EditorStyles.miniLabel);
        }
        GUILayout.FlexibleSpace();
        GUILayout.Label(modelType == "local" ? "Local [" + selectedLocalModel + "]" : "Cloud [" + selectedModel + "]",
            EditorStyles.miniLabel);
        EditorGUILayout.EndHorizontal();
    }

    void DrawMessage(Message msg)
    {
        Color oldBg = GUI.backgroundColor;
        Color txtColor;

        if (msg.role == "user")
        {
            GUI.backgroundColor = new Color(0.15f, 0.45f, 0.85f);
            txtColor = Color.white;
        }
        else if (msg.role == "assistant")
        {
            GUI.backgroundColor = new Color(0.12f, 0.25f, 0.12f);
            txtColor = new Color(0.8f, 1f, 0.8f);
        }
        else
        {
            GUI.backgroundColor = new Color(0.2f, 0.2f, 0.2f);
            txtColor = new Color(0.7f, 0.7f, 0.7f);
        }

        EditorGUILayout.BeginHorizontal();
        Color oldTxt = GUI.contentColor;
        GUI.contentColor = txtColor;
        string roleLabel = msg.role == "user" ? "[User]" : msg.role == "assistant" ? "[AI]" : "[System]";
        GUILayout.Label(roleLabel, GUILayout.Width(60));

        // Show apply button for assistant messages with code
        if (msg.role == "assistant" && (msg.content.Contains("```csharp") || msg.content.Contains("```cs")))
        {
            if (GUILayout.Button(selectedLanguage == "zh" ? "复制代码" : "Copy Code", EditorStyles.miniButton, GUILayout.Width(80)))
            {
                string code = ExtractCode(msg.content);
                EditorGUIUtility.systemCopyBuffer = code;
                statusText = selectedLanguage == "zh" ? "代码已复制!" : "Code copied!";
            }
        }

        GUI.contentColor = oldTxt;
        EditorGUILayout.EndHorizontal();

        string display = msg.content;
        if (display.Length > 3000)
            display = display.Substring(0, 3000) + "\n... (truncated)";

        var style = new GUIStyle(EditorStyles.label) { wordWrap = true, richText = true };
        GUILayout.Label(display, style, GUILayout.MinHeight(20));
        EditorGUILayout.Space(3);

        GUI.backgroundColor = oldBg;
    }

    // ============================================================
    // Message Handling
    // ============================================================
    void AddMessage(string content, bool isUser)
    {
        messages.Add(new Message(isUser ? "user" : "assistant", content));
        scrollPos.y = float.MaxValue;
        Repaint();
    }

    string ExtractCode(string text)
    {
        var match = Regex.Match(text, @"```(?:csharp|cs|gdscript)?\s*\n?([\s\S]*?)```");
        if (match.Success)
            return match.Groups[1].Value.Trim();
        // fallback: just return the whole text
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
        AddMessage(userMsg, true);

        // Handle commands
        if (HandleCommand(userMsg)) return;

        isProcessing = true;
        statusText = selectedLanguage == "zh" ? "思考中..." : "Thinking...";
        Repaint();

        _ = SendToAI(userMsg);
    }

    bool HandleCommand(string cmd)
    {
        string c = cmd.Trim().ToLower();

        if (c == "/clear" || c == "/cls")
        { ClearMessages(); return true; }

        if (c == "/undo")
        { PerformUndo(); return true; }

        if (c == "/redo")
        { PerformRedo(); return true; }

        if (c == "/screenshot")
        { TakeScreenshot(); return true; }

        if (c == "/context")
        { AddProjectContext(); return true; }

        if (c == "/learn")
        { _ = DailyLearning(); return true; }

        if (c == "/help")
        { ShowHelp(); return true; }

        if (c == "/skip")
        { SkipPending(); return true; }

        if (c == "/models")
        { ListModels(); return true; }

        if (c.StartsWith("/apply "))
        {
            string num = c.Replace("/apply ", "").Trim();
            if (int.TryParse(num, out int idx))
                ApplyPending(idx - 1);
            return true;
        }

        return false;
    }

    void ClearMessages()
    {
        messages.Clear();
        AddMessage(selectedLanguage == "zh" ? "对话已清空" : "Chat cleared", false);
    }

    void ShowHelp()
    {
        string lang = selectedLanguage;
        string help = lang == "zh" ? @"Octopus AI - 命令列表:
/help   - 显示此帮助
/clear  - 清空对话
/context - 添加项目上下文
/screenshot - 截图
/learn  - 每日学习
/apply N - 应用第N个代码块
/skip   - 跳过所有待应用代码
/undo   - 撤销
/redo   - 重做
/models - 列出所有可用模型
" : @"Octopus AI - Commands:
/help   - Show this help
/clear  - Clear chat
/context - Add project context
/screenshot - Screenshot
/learn  - Daily learning
/apply N - Apply code block N
/skip   - Skip all pending blocks
/undo   - Undo
/redo   - Redo
/models - List all models
";
        AddMessage(help, false);
    }

    void ListModels()
    {
        string lang = selectedLanguage;
        string output = lang == "zh" ? "=== Cloud Models ===\n" : "=== Cloud Models ===\n";
        foreach (var m in cloudModels)
            output += $"- {m.name}: {m.id}\n";

        output += "\n=== Local Ollama Models ===\n";
        foreach (var m in localModels)
            output += $"- {m.name} ({m.id}) - 需要 {m.minRam} RAM\n";

        output += $"\n当前模式: {(modelType == "local" ? "Local" : "Cloud")}";
        AddMessage(output, false);
    }

    void AddProjectContext()
    {
        string lang = selectedLanguage;
        string context = lang == "zh" ? $@"[项目上下文]
项目名称: {currentProjectName}
Unity版本: {currentUnityVersion}
API: Unity {Application.apiCompatibilityLevel}
平台: {Application.platform}
" : $@"[Project Context]
Project: {currentProjectName}
Unity: {currentUnityVersion}
API: Unity {Application.apiCompatibilityLevel}
Platform: {Application.platform}
";
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
                statusText = "Ready";
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
                    client.DefaultRequestHeaders.Add("Authorization", $"Bearer {key}");

                var content = new StringContent(json, Encoding.UTF8, "application/json");
                var response = await client.PostAsync(url, content);
                string responseText = await response.Content.ReadAsStringAsync();

                if (!response.IsSuccessStatusCode)
                {
                    string errMsg = $"Error ({response.StatusCode}): {responseText.Substring(0, Math.Min(300, responseText.Length))}";
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
            AddMessage($"Error: {ex.Message}", false);
        }
        finally
        {
            isProcessing = false;
            statusText = "Ready";
            Repaint();
        }
    }

    List<Dictionary<string, string>> BuildMessages(string userMessage)
    {
        var msgs = new List<Dictionary<string, string>>();
        string sysPrompt = GetSystemPrompt();
        msgs.Add(new Dictionary<string, string> { { "role", "system" }, { "content", sysPrompt } });

        foreach (var msg in messages)
        {
            msgs.Add(new Dictionary<string, string> { { "role", msg.role }, { "content", msg.content } });
        }

        msgs.Add(new Dictionary<string, string> { { "role", "user" }, { "content", userMessage } });
        return msgs;
    }

    string GetSystemPrompt()
    {
        string lang = selectedLanguage;

        if (lang == "zh")
        {
            return $@"你是一个专业的 Unity 游戏开发 AI 助手，名字叫 Octopus。

## 你的能力
1. 生成 Unity C# 脚本
2. 修改现有代码
3. 搜索免费可商用的游戏素材
4. 解释 Unity 概念和 API
5. 诊断和修复 Bug

## 代码格式
- 使用 C# for Unity
- 代码用 ```csharp 包裹
- 添加注释

## 提示
- 如果生成了代码，提醒用户可以用 /apply N 来保存
- 简洁实用，像和朋友聊天一样
- 可以建议用户保存重要信息到知识库

## 当前项目
项目名: {currentProjectName}
Unity版本: {currentUnityVersion}
平台: {Application.platform}
";
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

## Code Format
- Use C# for Unity
- Wrap code in ```csharp
- Add comments

## Tips
- If code is generated, remind user they can type /apply N to save
- Be concise and practical
- Suggest saving important info to Knowledge Base

## Current Project
Project: {currentProjectName}
Unity: {currentUnityVersion}
Platform: {Application.platform}
";
        }
    }

    string BuildRequestJson(List<Dictionary<string, string>> messages_list)
    {
        var msgsArray = new List<object>();
        foreach (var m in messages_list)
            msgsArray.Add(m);

        if (modelType == "cloud")
        {
            // OpenAI-compatible format
            if (selectedModel.Contains("claude"))
            {
                // Anthropic format
                return JsonUtility.ToJson(new
                {
                    model = selectedModel,
                    messages = messages_list.Where(m => m["role"] != "system").ToList(),
                    system = messages_list.FirstOrDefault(m => m["role"] == "system")?["content"] ?? "",
                    max_tokens = 4000,
                    temperature = 0.7
                });
            }
            else
            {
                return JsonUtility.ToJson(new
                {
                    model = selectedModel,
                    messages = msgsArray,
                    max_tokens = 4000,
                    temperature = 0.7
                });
            }
        }
        else
        {
            // Ollama format (local)
            return JsonUtility.ToJson(new
            {
                model = selectedLocalModel,
                messages = msgsArray,
                stream = false
            });
        }
    }

    string GetApiUrl()
    {
        if (modelType == "local")
            return localUrl + "/chat/completions";

        if (selectedModel.StartsWith("deepseek"))
            return "https://api.deepseek.com/v1/chat/completions";
        if (selectedModel.StartsWith("qwen") || selectedModel.Contains("qwen"))
            return "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions";
        if (selectedModel.Contains("ernie"))
            return "https://qianfan.baidubce.com/v2/chat/completions";
        if (selectedModel.Contains("moonshot") || selectedModel.Contains("kimi"))
            return "https://api.moonshot.cn/v1/chat/completions";
        if (selectedModel.Contains("glm"))
            return "https://open.bigmodel.cn/api/paas/v4/chat/completions";
        if (selectedModel.Contains("spark"))
            return "https://spark-api.xf-yun.com/v3.5/chat/completions";
        if (selectedModel.Contains("groq/"))
            return "https://api.groq.com/openai/v1/chat/completions";
        if (selectedModel.Contains("gemini"))
            return "https://generativelanguage.googleapis.com/v1beta/models/" + selectedModel + ":generateContent?key=" + apiKey;
        if (selectedModel.Contains("claude"))
            return "https://api.anthropic.com/v1/messages";
        if (selectedModel.Contains("mistral") || selectedModel.Contains("cohere"))
            return "https://api.mistral.ai/v1/chat/completions";
        return "https://api.openai.com/v1/chat/completions";
    }

    string GetApiKey()
    {
        if (modelType == "local") return "";
        return apiKey;
    }

    string ParseAIResponse(string json)
    {
        try
        {
            if (modelType == "local" || selectedModel.Contains("qwen") || selectedModel.Contains("glm") ||
                selectedModel.Contains("deepseek") || selectedModel.StartsWith("gpt") ||
                selectedModel.Contains("groq/") || selectedModel.Contains("mistral") ||
                selectedModel.Contains("cohere"))
            {
                var wrapper = JsonUtility.FromJson<OpenAIResponse>(json);
                return wrapper?.choices?[0]?.message?.content ?? "Parse error";
            }
            if (selectedModel.Contains("claude"))
            {
                var data = JsonUtility.FromJson<ClaudeResponse>(json);
                return data?.content?[0]?.text ?? "Parse error";
            }
            if (selectedModel.Contains("ernie"))
            {
                var data = JsonUtility.FromJson<ErnieResponse>(json);
                return data?.result ?? "Parse error";
            }
            if (selectedModel.Contains("gemini"))
            {
                var data = JsonUtility.FromJson<GeminiResponse>(json);
                return data?.candidates?[0]?.content?.parts?[0]?.text ?? "Parse error";
            }
            if (selectedModel.Contains("spark"))
            {
                var data = JsonUtility.FromJson<SparkResponse>(json);
                return data?.choices?[0]?.message?.content ?? "Parse error";
            }
        }
        catch { }
        return json;
    }

    // Response classes
    private class OpenAIResponse
    {
        public List<OpenAIChoice> choices;
    }
    private class OpenAIChoice
    {
        public OpenAIMessage message;
    }
    private class OpenAIMessage
    {
        public string content;
    }
    [Serializable]
    private class ClaudeResponse
    {
        public List<ClaudeContent> content;
    }
    private class ClaudeContent
    {
        public string text;
    }
    [Serializable]
    private class ErnieResponse
    {
        public string result;
    }
    [Serializable]
    private class GeminiResponse
    {
        public List<GeminiCandidate> candidates;
    }
    private class GeminiCandidate
    {
        public GeminiContent content;
    }
    private class GeminiContent
    {
        public List<GeminiPart> parts;
    }
    private class GeminiPart
    {
        public string text;
    }
    [Serializable]
    private class SparkResponse
    {
        public List<OpenAIChoice> choices;
    }

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
            string code = match.Groups[1].Value.Trim();
            codeBlocks.Add(new CodeBlock(code, idx++));
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
            string fileName = string.IsNullOrEmpty(className)
                ? $"GeneratedScript_{i + 1}.cs"
                : $"{className}.cs";

            string filePath = $"{scriptsFolder}/{fileName}";
            bool fileExists = File.Exists(filePath);
            int lines = block.code.Split('\n').Length;

            pendingPreviewBlocks.Add(new PreviewBlock(block.code, i, filePath, fileName, lines, fileExists));

            string lang = selectedLanguage;
            string msg = lang == "zh"
                ? $"代码块 [{i + 1}]: {fileName} ({lines}行)\n覆盖: {(fileExists ? "是" : "否")}\n输入 /apply {i + 1} 应用"
                : $"Code block [{i + 1}]: {fileName} ({lines} lines)\nOverwrite: {(fileExists ? "Yes" : "No")}\nType /apply {i + 1} to apply";
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
            AddMessage(selectedLanguage == "zh" ? "没有待应用的代码块!" : "No code blocks to apply!", false);
            return;
        }

        if (index < 0 || index >= pendingCodeBlocks.Count)
        {
            string msg = selectedLanguage == "zh"
                ? $"无效序号，请使用 /apply 1 - {pendingCodeBlocks.Count}"
                : $"Invalid index, use /apply 1 - {pendingCodeBlocks.Count}";
            AddMessage(msg, false);
            return;
        }

        var block = pendingCodeBlocks[index];
        string className = ExtractClassName(block.code);
        string fileName = string.IsNullOrEmpty(className)
            ? $"GeneratedScript_{index + 1}.cs"
            : $"{className}.cs";

        string scriptsFolder = Application.dataPath + "/Scripts/AIAssistant";
        if (!Directory.Exists(scriptsFolder))
            Directory.CreateDirectory(scriptsFolder);

        string filePath = $"{scriptsFolder}/{fileName}";
        bool fileExists = File.Exists(filePath);
        string originalCode = fileExists ? File.ReadAllText(filePath) : "";

        // Save to history
        var entry = new HistoryEntry(fileExists ? "modify" : "create", filePath, fileName, originalCode, block.code);
        undoStack.Add(entry);
        redoStack.Clear();

        File.WriteAllText(filePath, block.code);
        AssetDatabase.Refresh();

        string lang = selectedLanguage;
        AddMessage(lang == "zh"
            ? $"已保存: {fileName}，还剩 {pendingCodeBlocks.Count - 1} 个待应用"
            : $"Saved: {fileName}, {pendingCodeBlocks.Count - 1} remaining", false);

        pendingCodeBlocks.RemoveAt(index);
        pendingPreviewBlocks.RemoveAt(index);
    }

    void SkipPending()
    {
        int count = pendingCodeBlocks.Count;
        pendingCodeBlocks.Clear();
        pendingPreviewBlocks.Clear();

        string lang = selectedLanguage;
        AddMessage(lang == "zh" ? $"已跳过 {count} 个代码块" : $"Skipped {count} code blocks", false);
    }

    // ============================================================
    // Undo / Redo
    // ============================================================
    void PerformUndo()
    {
        if (undoStack.Count == 0)
        {
            AddMessage(selectedLanguage == "zh" ? "没有可撤销的操作" : "Nothing to undo", false);
            return;
        }

        var history = undoStack[undoStack.Count - 1];
        undoStack.RemoveAt(undoStack.Count - 1);

        try
        {
            if (history.action == "create")
            {
                if (File.Exists(history.filePath))
                {
                    File.Delete(history.filePath);
                    AssetDatabase.Refresh();
                }
                redoStack.Add(history);
                AddMessage(selectedLanguage == "zh" ? $"已删除: {history.fileName}" : $"Deleted: {history.fileName}", false);
            }
            else
            {
                File.WriteAllText(history.filePath, history.originalCode);
                AssetDatabase.Refresh();
                redoStack.Add(history);
                AddMessage(selectedLanguage == "zh" ? $"已撤销: {history.fileName}" : $"Undone: {history.fileName}", false);
            }
        }
        catch (Exception e)
        {
            AddMessage($"Undo failed: {e.Message}", false);
        }
    }

    void PerformRedo()
    {
        if (redoStack.Count == 0)
        {
            AddMessage(selectedLanguage == "zh" ? "没有可重做的操作" : "Nothing to redo", false);
            return;
        }

        var history = redoStack[redoStack.Count - 1];
        redoStack.RemoveAt(redoStack.Count - 1);

        try
        {
            File.WriteAllText(history.filePath, history.newCode);
            AssetDatabase.Refresh();
            undoStack.Add(history);
            AddMessage(selectedLanguage == "zh" ? $"已重做: {history.fileName}" : $"Redone: {history.fileName}", false);
        }
        catch (Exception e)
        {
            AddMessage($"Redo failed: {e.Message}", false);
        }
    }

    // ============================================================
    // Utilities
    // ============================================================
    void OpenKnowledgeBase()
    {
        string path = Application.dataPath + "/Scripts/KnowledgeBase";
        if (!Directory.Exists(path))
            Directory.CreateDirectory(path);
        EditorUtility.RevealInFinder(path);
    }

    async Task DailyLearning()
    {
        System.Random rand = new System.Random();
        int topicIdx = rand.Next(learningTips.Length);
        string tip = selectedLanguage == "zh" ? learningTips[topicIdx] : learningTips_en[topicIdx];

        string msg = selectedLanguage == "zh" ? "每日学习 Tip:" : "Daily Learning Tip:";
        AddMessage(msg, false);
        AddMessage(tip, false);

        await Task.Delay(100);
    }

    void TakeScreenshot()
    {
        string path = Application.dataPath + "/../Screenshots";
        if (!Directory.Exists(path))
            Directory.CreateDirectory(path);
        string filename = $"/screenshot_{DateTime.Now:yyyyMMdd_HHmmss}.png";
        ScreenCapture.CaptureScreenshot(path + filename);
        AddMessage(selectedLanguage == "zh"
            ? $"截图已保存到 Screenshots 文件夹"
            : $"Screenshot saved to Screenshots folder", false);
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
                var testMsg = JsonUtility.ToJson(new { model = selectedModel, messages = new object[] { new { role = "user", content = "hi" } }, max_tokens = 5 });
                var content = new StringContent(testMsg, Encoding.UTF8, "application/json");
                client.DefaultRequestHeaders.Clear();
                if (!string.IsNullOrEmpty(apiKey))
                    client.DefaultRequestHeaders.Add("Authorization", $"Bearer {apiKey}");

                var response = await client.PostAsync(GetApiUrl(), content);
                if (response.IsSuccessStatusCode)
                    AddMessage(selectedLanguage == "zh" ? "连接成功!" : "Connection successful!", false);
                else
                    AddMessage($"Connection failed: {response.StatusCode}", false);
            }
        }
        catch (Exception ex)
        {
            AddMessage($"Connection error: {ex.Message}", false);
        }
        finally
        {
            isProcessing = false;
            statusText = "Ready";
            Repaint();
        }
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
                    string body = await response.Content.ReadAsStringStringAsync();
                    try
                    {
                        var tags = JsonUtility.FromJson<OllamaTagsResponse>(body);
                        string modelList = "";
                        if (tags?.models != null)
                        {
                            foreach (var m in tags.models)
                                modelList += $"- {m.name}\n";
                        }
                        AddMessage(selectedLanguage == "zh"
                            ? $"Ollama 连接成功!\n已安装模型:\n{modelList}"
                            : $"Ollama connected!\nInstalled models:\n{modelList}", false);
                    }
                    catch
                    {
                        AddMessage(selectedLanguage == "zh"
                            ? "Ollama 连接成功，但无法解析模型列表"
                            : "Ollama connected, but failed to parse model list", false);
                    }
                }
                else
                {
                    AddMessage(selectedLanguage == "zh"
                        ? $"无法连接 Ollama (HTTP {(int)response.StatusCode})\n请确保 Ollama 已启动"
                        : $"Cannot connect to Ollama (HTTP {(int)response.StatusCode})\nMake sure Ollama is running", false);
                }
            }
        }
        catch (Exception ex)
        {
            AddMessage(selectedLanguage == "zh"
                ? $"Ollama 连接失败: {ex.Message}\n请确认 Ollama 已安装并运行"
                : $"Ollama connection failed: {ex.Message}\nMake sure Ollama is installed and running", false);
        }
        finally
        {
            isProcessing = false;
            statusText = "Ready";
            Repaint();
        }
    }

    string GetModelKeyUrl(string modelId)
    {
        if (modelId.Contains("deepseek")) return "https://platform.deepseek.com/api_keys";
        if (modelId.StartsWith("qwen") || modelId.Contains("qwen")) return "https://dashscope.console.aliyun.com/apiKey";
        if (modelId.Contains("ernie")) return "https://console.bce.baidu.com/qianfan/ais/console/applicationConsole/application";
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
// GameAISkill - Skill System (Unity C# version)
// ============================================================
public static class GameAISkill
{
    public static void Use(string skillName)
    {
        EditorUtility.DisplayDialog("Skill", $"Skill '{skillName}' called", "OK");
    }

    public static void RegisterSkill(string name, Action callback)
    {
        // Skill registration placeholder
    }
}
