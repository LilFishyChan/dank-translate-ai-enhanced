pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "dankTranslateAI"

    readonly property bool zh: uiLanguageSetting.value === "zh"
    readonly property string defaultPrompt: "Translate the user's text into ${target_lang}. Preserve meaning, tone, paragraphs, Markdown, code, names, and numbers. Output only the translation."

    function storedValue(key, fallback) {
        const marker = "__dank_translate_missing__";
        const value = loadValue(key, marker);
        return value === marker ? fallback : value;
    }

    function legacyBaseUrl() {
        return String(storedValue("baseUrl", ""));
    }

    function legacyIsLocal() {
        const url = legacyBaseUrl().trim().toLowerCase();
        return /^https?:\/\/(localhost|127\.|\[::1\]|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)/.test(url);
    }
    readonly property var languageEntries: [
        { label: "简体中文", value: "Chinese (Simplified)" },
        { label: "繁體中文", value: "Chinese (Traditional)" },
        { label: "英语", value: "English" },
        { label: "日语", value: "Japanese" },
        { label: "韩语", value: "Korean" },
        { label: "西班牙语", value: "Spanish" },
        { label: "拉丁美洲西班牙语", value: "Spanish (Latin America)" },
        { label: "法语", value: "French" },
        { label: "德语", value: "German" },
        { label: "意大利语", value: "Italian" },
        { label: "葡萄牙语", value: "Portuguese" },
        { label: "巴西葡萄牙语", value: "Portuguese (Brazil)" },
        { label: "俄语", value: "Russian" },
        { label: "乌克兰语", value: "Ukrainian" },
        { label: "阿拉伯语", value: "Arabic" },
        { label: "希伯来语", value: "Hebrew" },
        { label: "波斯语", value: "Persian" },
        { label: "土耳其语", value: "Turkish" },
        { label: "印地语", value: "Hindi" },
        { label: "乌尔都语", value: "Urdu" },
        { label: "孟加拉语", value: "Bengali" },
        { label: "旁遮普语", value: "Punjabi" },
        { label: "古吉拉特语", value: "Gujarati" },
        { label: "马拉地语", value: "Marathi" },
        { label: "泰米尔语", value: "Tamil" },
        { label: "泰卢固语", value: "Telugu" },
        { label: "卡纳达语", value: "Kannada" },
        { label: "马拉雅拉姆语", value: "Malayalam" },
        { label: "奥里亚语", value: "Odia" },
        { label: "阿萨姆语", value: "Assamese" },
        { label: "尼泊尔语", value: "Nepali" },
        { label: "僧伽罗语", value: "Sinhala" },
        { label: "泰语", value: "Thai" },
        { label: "越南语", value: "Vietnamese" },
        { label: "印度尼西亚语", value: "Indonesian" },
        { label: "马来语", value: "Malay" },
        { label: "菲律宾语", value: "Filipino" },
        { label: "爪哇语", value: "Javanese" },
        { label: "缅甸语", value: "Burmese" },
        { label: "高棉语", value: "Khmer" },
        { label: "老挝语", value: "Lao" },
        { label: "蒙古语", value: "Mongolian" },
        { label: "藏语", value: "Tibetan" },
        { label: "哈萨克语", value: "Kazakh" },
        { label: "乌兹别克语", value: "Uzbek" },
        { label: "吉尔吉斯语", value: "Kyrgyz" },
        { label: "普什图语", value: "Pashto" },
        { label: "阿塞拜疆语", value: "Azerbaijani" },
        { label: "亚美尼亚语", value: "Armenian" },
        { label: "格鲁吉亚语", value: "Georgian" },
        { label: "希腊语", value: "Greek" },
        { label: "荷兰语", value: "Dutch" },
        { label: "波兰语", value: "Polish" },
        { label: "捷克语", value: "Czech" },
        { label: "斯洛伐克语", value: "Slovak" },
        { label: "匈牙利语", value: "Hungarian" },
        { label: "罗马尼亚语", value: "Romanian" },
        { label: "保加利亚语", value: "Bulgarian" },
        { label: "塞尔维亚语", value: "Serbian" },
        { label: "克罗地亚语", value: "Croatian" },
        { label: "波斯尼亚语", value: "Bosnian" },
        { label: "斯洛文尼亚语", value: "Slovenian" },
        { label: "北马其顿语", value: "Macedonian" },
        { label: "阿尔巴尼亚语", value: "Albanian" },
        { label: "瑞典语", value: "Swedish" },
        { label: "挪威语", value: "Norwegian" },
        { label: "丹麦语", value: "Danish" },
        { label: "芬兰语", value: "Finnish" },
        { label: "冰岛语", value: "Icelandic" },
        { label: "爱尔兰语", value: "Irish" },
        { label: "威尔士语", value: "Welsh" },
        { label: "爱沙尼亚语", value: "Estonian" },
        { label: "拉脱维亚语", value: "Latvian" },
        { label: "立陶宛语", value: "Lithuanian" },
        { label: "白俄罗斯语", value: "Belarusian" },
        { label: "加泰罗尼亚语", value: "Catalan" },
        { label: "巴斯克语", value: "Basque" },
        { label: "加利西亚语", value: "Galician" },
        { label: "马耳他语", value: "Maltese" },
        { label: "斯瓦希里语", value: "Swahili" },
        { label: "豪萨语", value: "Hausa" },
        { label: "约鲁巴语", value: "Yoruba" },
        { label: "伊博语", value: "Igbo" },
        { label: "祖鲁语", value: "Zulu" },
        { label: "南非荷兰语", value: "Afrikaans" },
        { label: "阿姆哈拉语", value: "Amharic" },
        { label: "奥罗莫语", value: "Oromo" },
        { label: "索马里语", value: "Somali" },
        { label: "卢旺达语", value: "Kinyarwanda" },
        { label: "马达加斯加语", value: "Malagasy" },
        { label: "海地克里奥尔语", value: "Haitian Creole" },
        { label: "瓜拉尼语", value: "Guarani" },
        { label: "克丘亚语", value: "Quechua" },
        { label: "毛利语", value: "Maori" },
        { label: "萨摩亚语", value: "Samoan" },
        { label: "自定义语言", value: "__custom__" }
    ]
    readonly property var languages: {
        const result = [];
        for (let i = 0; i < languageEntries.length; i++) {
            const item = languageEntries[i];
            result.push({
                label: root.zh ? item.label : (item.value === "__custom__" ? "Custom" : item.value),
                value: item.value
            });
        }
        return result;
    }

    Column {
        width: parent.width
        spacing: Theme.spacingM

        StyledText {
            width: parent.width
            text: "Dank Translate AI"
            font.pixelSize: Theme.fontSizeLarge + 2
            font.weight: Font.Bold
            color: Theme.surfaceText
        }

    StyledText {
        width: parent.width
        text: root.zh ? "划词或复制后按快捷键。" : "Select or copy, then press the shortcut."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    SelectionSetting {
        id: uiLanguageSetting
        settingKey: "uiLanguage"
        label: root.zh ? "界面语言" : "UI language"
        options: [
            { label: "English", value: "en" },
            { label: "中文", value: "zh" }
        ]
        defaultValue: "en"
    }

    StyledText {
        width: parent.width
        text: root.zh ? "本地模型（优先）" : "Local model (preferred)"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.primary
    }

    StyledText {
        width: parent.width
        text: root.zh
            ? "填写本地模型 ID 后启用。请求会先发送到本机；本地服务关闭、超时或返回错误时切换到远程 API。"
            : "Set a local model ID to enable it. Requests go local first, then fall back to the remote API when the local service is offline, times out, or returns an error."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StringSetting {
        settingKey: "localBaseUrl"
        label: root.zh ? "本地 Base URL" : "Local Base URL"
        description: root.zh ? "本机或可信局域网内的 OpenAI 兼容地址。" : "OpenAI-compatible endpoint on this device or a trusted LAN."
        placeholder: "http://127.0.0.1:8080/v1"
        defaultValue: root.legacyIsLocal() ? root.legacyBaseUrl() : "http://127.0.0.1:8080/v1"
    }

    StringSetting {
        settingKey: "localEndpoint"
        label: root.zh ? "本地 Endpoint" : "Local endpoint"
        description: root.zh ? "路径或完整 URL。" : "Path or full URL."
        placeholder: "/chat/completions"
        defaultValue: root.legacyIsLocal() ? String(root.storedValue("endpoint", "/chat/completions")) : "/chat/completions"
    }

    StringSetting {
        settingKey: "localModel"
        label: root.zh ? "本地模型" : "Local model"
        description: root.zh ? "留空时直接使用远程 API。" : "Leave empty to use the remote API directly."
        placeholder: "tencent/Hy-MT2-1.8B-GGUF"
        defaultValue: root.legacyIsLocal() ? String(root.storedValue("model", "")) : ""
    }

    SecureStringSetting {
        settingKey: "localApiKey"
        label: root.zh ? "本地 API Key" : "Local API Key"
        description: root.zh ? "多数本地服务可以留空。" : "Most local services accept an empty key."
        placeholder: root.zh ? "可选" : "Optional"
        defaultValue: root.legacyIsLocal() ? String(root.storedValue("apiKey", "")) : ""
    }

    SliderSetting {
        settingKey: "localTimeoutSeconds"
        label: root.zh ? "本地超时" : "Local timeout"
        description: root.zh ? "包含模型冷启动等待时间。" : "Includes model cold-start time."
        defaultValue: 15
        minimum: 3
        maximum: 120
        unit: root.zh ? "秒" : "s"
        leftIcon: "timer"
    }

    ToggleSetting {
        settingKey: "remoteFallbackEnabled"
        label: root.zh ? "本地失败后使用远程 API" : "Use remote API after local failure"
        description: root.zh
            ? "开启后，发生回退时原文会发送到下面配置的远程接口。"
            : "When enabled, fallback sends the source text to the remote endpoint configured below."
        defaultValue: true
    }

    StyledText {
        width: parent.width
        text: root.zh ? "远程 API（回退）" : "Remote API (fallback)"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.primary
    }

    SecureStringSetting {
        settingKey: "remoteApiKey"
        label: root.zh ? "远程 API Key" : "Remote API Key"
        description: root.zh ? "保留现有云端密钥。" : "Your existing cloud API key."
        placeholder: "sk-…"
        defaultValue: root.legacyIsLocal() ? "" : String(root.storedValue("apiKey", ""))
    }

    StringSetting {
        settingKey: "remoteBaseUrl"
        label: root.zh ? "远程 Base URL" : "Remote Base URL"
        description: root.zh ? "OpenAI 兼容云端地址。" : "OpenAI-compatible cloud URL."
        placeholder: "https://api.deepseek.com/v1"
        defaultValue: root.legacyIsLocal() ? "" : root.legacyBaseUrl()
    }

    StringSetting {
        settingKey: "remoteEndpoint"
        label: root.zh ? "远程 Endpoint" : "Remote endpoint"
        description: root.zh ? "路径或完整 URL。" : "Path or full URL."
        placeholder: "/chat/completions"
        defaultValue: root.legacyIsLocal() ? "/chat/completions" : String(root.storedValue("endpoint", "/chat/completions"))
    }

    StringSetting {
        settingKey: "remoteModel"
        label: root.zh ? "远程模型" : "Remote model"
        description: root.zh ? "远程接口使用的模型 ID。" : "Model ID used by the remote API."
        placeholder: "deepseek-chat"
        defaultValue: root.legacyIsLocal() ? "" : String(root.storedValue("model", ""))
    }

    ToggleSetting {
        settingKey: "streaming"
        label: root.zh ? "流式输出" : "Streaming"
        description: root.zh ? "可用时使用 SSE。" : "Uses SSE when available."
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "disableThinking"
        label: root.zh ? "DeepSeek 低延迟翻译" : "Low-latency DeepSeek translation"
        description: root.zh
            ? "对 DeepSeek 模型关闭思考模式，加快首字输出。"
            : "Disables thinking mode for DeepSeek models to reduce time to first token."
        defaultValue: true
    }

    SliderSetting {
        settingKey: "remoteTimeoutSeconds"
        label: root.zh ? "远程请求超时" : "Remote timeout"
        defaultValue: Number(root.storedValue("timeoutSeconds", 120))
        minimum: 15
        maximum: 600
        unit: root.zh ? "秒" : "s"
        leftIcon: "timer"
    }

    StyledText {
        width: parent.width
        text: root.zh ? "翻译" : "Translation"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.primary
    }

    SelectionSetting {
        id: languageSetting
        settingKey: "targetLanguage"
        label: root.zh ? "目标语言" : "Target language"
        description: root.zh ? "替换 ${target_lang}。" : "Replaces ${target_lang}."
        options: root.languages
        defaultValue: "Chinese (Simplified)"
    }

    StringSetting {
        visible: languageSetting.value === "__custom__"
        settingKey: "customTargetLanguage"
        label: root.zh ? "自定义语言" : "Custom language"
        placeholder: "French (Canada)"
        defaultValue: ""
    }

    TextAreaSetting {
        settingKey: "prompt"
        label: root.zh ? "提示词" : "Prompt"
        description: root.zh ? "使用 ${target_lang}。Ctrl+S 保存。" : "Use ${target_lang}. Ctrl+S saves."
        placeholder: root.defaultPrompt
        defaultValue: root.defaultPrompt
        editorHeight: 130
    }

    SliderSetting {
        settingKey: "historyLimit"
        label: root.zh ? "历史数量" : "History limit"
        description: root.zh ? "最新优先。" : "Newest first."
        defaultValue: 100
        minimum: 20
        maximum: 500
        unit: root.zh ? "条" : "items"
        leftIcon: "history"
    }

        ShortcutSetting {
            zh: root.zh
        }
    }
}
