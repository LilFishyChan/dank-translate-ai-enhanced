import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    readonly property string dmsLocale: {
        const raw = String(SessionData.locale || "");
        return raw === "" ? String(Qt.locale().name) : raw;
    }
    readonly property bool uiZh: dmsLocale.toLowerCase().indexOf("zh") === 0
    readonly property string defaultPrompt: "Translate the user's text into ${target_lang}. Preserve meaning, tone, paragraphs, Markdown, code, names, and numbers. Output only the translation."
    readonly property string pluginPath: pluginService ? pluginService.getPluginPath(pluginId) : ""
    readonly property string helperPath: pluginPath ? pluginPath + "/translate_stream.py" : ""
    readonly property string captureHelperPath: pluginPath ? pluginPath + "/capture_selection.py" : ""
    readonly property int maxInputChars: 100000
    readonly property int clipboardFreshnessMs: 60000
    readonly property int primaryFreshnessMs: 15000
    readonly property int selfCopyMatchMs: 3000

    property bool initialized: false
    property bool ipcStopping: false
    property bool popupVisible: false
    property var popupScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    property var activeCapture: null
    property var activeProcess: null
    property string currentOriginal: ""
    property string currentTranslation: ""
    property string currentError: ""
    property string currentStatus: "idle"
    property string currentPhase: "idle"
    property string currentLanguage: "Chinese (Simplified)"
    property string currentProvider: ""
    property string providerOverride: ""
    property string currentModel: ""
    property bool currentUsedFallback: false
    property int inputRequestSerial: 0
    property bool inputBaselineReady: false
    property string lastClipboardEntryId: ""
    property string pendingInputMode: "selection"
    property double primaryWatcherStartedAt: 0
    property double lastPrimaryChangeAt: 0
    property var pendingHistorySave: []
    property bool editingOriginal: false
    property string modelOverride: ""
    property string languageOverride: ""
    property string menuName: ""
    property var modelListProcess: null

    readonly property var languageChoices: {
        const entries = [
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
    
        ];
        return entries;
    }
    property string modelListStatus: "idle"
    property string editedOriginal: ""
    property bool showOriginal: true

    function t(en, zh) {
        return uiZh ? zh : en;
    }

    PluginGlobalVar {
        id: globalHistory
        varName: "history"
        defaultValue: []
    }

    PluginGlobalVar {
        id: globalStatus
        varName: "status"
        defaultValue: "idle"
    }

    PluginGlobalVar {
        id: globalOriginal
        varName: "original"
        defaultValue: ""
    }

    PluginGlobalVar {
        id: globalTranslation
        varName: "translation"
        defaultValue: ""
    }

    PluginGlobalVar {
        id: globalError
        varName: "error"
        defaultValue: ""
    }

    PluginGlobalVar {
        id: globalClipboardWriteAt
        varName: "clipboardWriteAt"
        defaultValue: 0
    }

    Timer {
        id: inputDebounceTimer
        interval: 250
        repeat: false
        onTriggered: {
            const requestSerial = root.inputRequestSerial;
            if (root.pendingInputMode === "clipboard")
                root.resolveClipboardInput(requestSerial);
            else
                root.resolveSelectionInput(requestSerial);
        }
    }

    Timer {
        id: helperStartTimer
        interval: 10000
        repeat: false
        onTriggered: {
            const process = root.activeProcess;
            if (process && !process.requestAccepted) {
                root.failActiveProcess(
                    process,
                    root.t(
                        "The translation helper did not accept the request.",
                        "翻译进程未能接收请求。"
                    )
                );
            }
        }
    }

    Timer {
        id: requestTimeoutTimer
        repeat: false
        onTriggered: {
            const process = root.activeProcess;
            if (process) {
                root.failActiveProcess(
                    process,
                    root.t("Request timed out.", "请求超时。")
                );
            }
        }
    }

    Timer {
        id: primaryWatcherRestartTimer
        interval: 2000
        repeat: false
        onTriggered: root.startPrimaryWatcher()
    }

    Timer {
        id: historySaveRetryTimer
        interval: 350
        repeat: false
        onTriggered: {
            if (root.pluginService) {
                root.pluginService.savePluginState(
                    root.pluginId,
                    "history",
                    root.pendingHistorySave
                );
            }
        }
    }

    Process {
        id: primaryWatcher
        command: [
            "wl-paste", "--primary", "--watch",
            "sh", "-c", "printf 'selection-changed\\n'"
        ]
        running: false

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (!line)
                    return;
                const now = Date.now();
                // wl-paste may announce the selection that existed at startup.
                if (now - root.primaryWatcherStartedAt < 1000)
                    return;
                root.lastPrimaryChangeAt = now;
            }
        }

        stderr: StdioCollector {}

        onStarted: root.primaryWatcherStartedAt = Date.now()
        onExited: {
            if (!root.ipcStopping)
                primaryWatcherRestartTimer.restart();
        }
    }

    function initialize() {
        if (initialized || !pluginService || !pluginId)
            return;
        let saved = pluginService.loadPluginState(pluginId, "history", []);
        if (!Array.isArray(saved))
            saved = [];
        saved = saved.slice().sort((a, b) => Number(b.createdAt || 0) - Number(a.createdAt || 0));
        globalHistory.set(saved);
        globalStatus.set("idle");
        globalOriginal.set("");
        globalTranslation.set("");
        globalError.set("");
        currentPhase = "idle";
        currentProvider = "";
        currentModel = "";
        currentUsedFallback = false;
        initialized = true;
        trimHistory();
    }

    function activateIpc() {
        if (ipcStopping || pluginId !== "dankTranslateAI")
            return;

        ipc.target = pluginId;
        ipc.enabled = true;
    }

    function startPrimaryWatcher() {
        if (ipcStopping || primaryWatcher.running)
            return;
        primaryWatcherStartedAt = 0;
        lastPrimaryChangeAt = 0;
        primaryWatcher.running = true;
    }

    function deactivateIpc() {
        if (ipcStopping)
            return;

        ipcStopping = true;

        // Deregister synchronously before clearing the target.
        ipc.enabled = false;
        ipc.target = "";

        inputDebounceTimer.stop();
        primaryWatcherRestartTimer.stop();
        ++inputRequestSerial;
        cancelActive(false);

        if (primaryWatcher.running)
            primaryWatcher.signal(15);

        if (activeCapture) {
            activeCapture.signal(15);
            activeCapture = null;
        }
    }

    Component.onCompleted: {
        Qt.callLater(initialize);
        Qt.callLater(activateIpc);
        Qt.callLater(startPrimaryWatcher);
        Qt.callLater(function () { root.dropdownsReady = true; });
    }

    Component.onDestruction: deactivateIpc()
    onPluginIdChanged: {
        Qt.callLater(initialize);
        if (pluginId === "dankTranslateAI")
            Qt.callLater(activateIpc);
    }
    onPluginServiceChanged: Qt.callLater(initialize)

    Connections {
        target: root.pluginService
        enabled: root.pluginService !== null

        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId === root.pluginId)
                root.trimHistory();
        }

        function onPluginUnloaded(changedPluginId) {
            if (changedPluginId === root.pluginId)
                root.deactivateIpc();
        }
    }

    function historyLimit() {
        const parsed = Number(pluginData?.historyLimit ?? 100);
        return Math.max(20, Math.min(isNaN(parsed) ? 100 : Math.round(parsed), 500));
    }

    function trimHistory() {
        if (!initialized)
            return;
        const history = Array.isArray(globalHistory.value) ? globalHistory.value.slice() : [];
        const trimmed = history.slice(0, historyLimit());
        if (trimmed.length !== history.length) {
            globalHistory.set(trimmed);
            persistHistory(trimmed);
        }
    }

    function persistHistory(history) {
        if (!pluginService)
            return;
        pendingHistorySave = Array.isArray(history) ? history.slice() : [];
        pluginService.savePluginState(pluginId, "history", pendingHistorySave);
        historySaveRetryTimer.restart();
    }

    function syncCurrentState() {
        globalStatus.set(currentStatus);
        globalOriginal.set(currentOriginal);
        globalTranslation.set(currentTranslation);
        globalError.set(currentError);
    }

    function translateManual(value): void {
        const text = String(value || "").trim();
        if (text.length === 0) {
            ToastService.showInfo(t("Nothing to translate", "没有可翻译的文本"));
            return;
        }
        manualEdit.text = "";
        startTranslation(text);
    }

    function prefillText(value) {
        currentStatus = "idle";
        currentPhase = "idle";
        currentOriginal = String(value || "");
        currentTranslation = "";
        currentError = "";
        showPopup();
    }

    function openManualInput() {
        currentStatus = "idle";
        currentPhase = "idle";
        currentOriginal = "";
        currentTranslation = "";
        currentError = "";
        showPopup();
    }

    function showPopup() {
        popupScreen = CompositorService.getFocusedScreen();
        popupVisible = true;
    }

    function closePopup() {
        menuName = "";
        if (editingOriginal) {
            editingOriginal = false;
            editedOriginal = "";
        }
        popupVisible = false;
    }

    function presentError(message, originalText) {
        currentOriginal = originalText || "";
        currentTranslation = "";
        currentError = String(message || t("Translation failed", "翻译失败"));
        currentStatus = "error";
        currentPhase = "error";
        currentProvider = "";
        currentModel = "";
        currentUsedFallback = false;
        syncCurrentState();
        showPopup();
    }

    function beginSelectionTranslation() {
        scheduleInput("selection");
    }

    function beginClipboardTranslation() {
        scheduleInput("clipboard");
    }

    function scheduleInput(mode) {
        ++inputRequestSerial;
        pendingInputMode = mode;
        if (activeCapture) {
            activeCapture.signal(15);
            activeCapture = null;
        }
        inputDebounceTimer.restart();
    }

    function resolveSelectionInput(requestSerial) {
        resolveClipboardState(state => {
            if (requestSerial !== inputRequestSerial)
                return;
            const clipboardChanged = state.entry
                && (!inputBaselineReady || state.currentId !== lastClipboardEntryId);
            if (clipboardChanged) {
                captureText(false, true, state.currentId);
                return;
            }
            if (primarySelectionIsFresh()) {
                captureText(true, true, state.currentId);
                return;
            }
            openManualInput();
        });
    }

    function primarySelectionIsFresh() {
        const age = Date.now() - lastPrimaryChangeAt;
        return lastPrimaryChangeAt > 0
            && age >= -selfCopyMatchMs
            && age <= primaryFreshnessMs;
    }

    function resolveClipboardInput(requestSerial) {
        resolveClipboardState(state => {
            if (requestSerial !== inputRequestSerial)
                return;
            const clipboardChanged = state.entry
                && (!inputBaselineReady || state.currentId !== lastClipboardEntryId);
            if (clipboardChanged) {
                captureText(false, true, state.currentId);
                return;
            }
            if (inputBaselineReady)
                return;
            openManualInput();
        });
    }

    function isTextClipboardEntry(entry) {
        if (!entry || entry.isImage)
            return false;
        const mime = String(entry.mimeType || "").toLowerCase();
        return mime.startsWith("text/plain")
            || mime === "text"
            || mime === "string"
            || mime === "utf8_string";
    }

    function isOwnClipboardWrite(timestamp) {
        const writtenAt = Number(globalClipboardWriteAt.value || 0);
        return writtenAt > 0 && Math.abs(timestamp - writtenAt) <= selfCopyMatchMs;
    }

    function resolveClipboardState(callback) {
        if (!DMSService.isConnected) {
            callback({ entry: null, currentId: "" });
            return;
        }
        DMSService.sendRequest("clipboard.search", {
            query: "",
            limit: 1,
            offset: 0
        }, response => {
            if (response.error) {
                callback({ entry: null, currentId: "" });
                return;
            }
            const entries = response.result?.entries || [];
            const entry = entries.length > 0 ? entries[0] : null;
            const currentId = entry ? String(entry.id ?? "") : "";
            const timestamp = entry ? Date.parse(String(entry.timestamp || "")) : NaN;
            const age = Date.now() - timestamp;
            const fresh = !isNaN(timestamp)
                && age >= -selfCopyMatchMs
                && age <= clipboardFreshnessMs;
            callback({
                entry: fresh && isTextClipboardEntry(entry) && !isOwnClipboardWrite(timestamp)
                    ? entry
                    : null,
                currentId: currentId
            });
        });
    }

    function captureText(primarySelection, smartInput, clipboardEntryId) {
        if (activeCapture) {
            activeCapture.signal(15);
            activeCapture = null;
        }
        const reader = selectionReaderComponent.createObject(root, {
            primarySelection: primarySelection,
            smartInput: !!smartInput,
            clipboardEntryId: String(clipboardEntryId || "")
        });
        activeCapture = reader;
        reader.running = true;
    }

    function onCaptured(reader, exitCode) {
        if (reader !== activeCapture)
            return;
        activeCapture = null;
        const text = String(reader.capturedText || "").trim();
        console.info("[DankTranslateAI] selection capture:", reader.primarySelection ? "primary" : "clipboard", "exit", exitCode, "chars", text.length);

        if (exitCode === 0 && text.length > 0) {
            lastClipboardEntryId = reader.clipboardEntryId;
            inputBaselineReady = true;
            if (autoTranslateEnabled)
                startTranslation(text);
            else
                prefillText(text);
            return;
        }

        if (reader.primarySelection && reader.smartInput) {
            captureText(false, true, reader.clipboardEntryId);
            return;
        }
        if (exitCode === 6) {
            presentError(
                t(
                    "Clipboard may contain a password or key. Automatic translation was blocked.",
                    "剪贴板疑似包含密码或密钥，已阻止自动翻译。"
                ),
                ""
            );
            return;
        }
        if (exitCode === 2) {
            if (reader.smartInput) {
                openManualInput();
            } else {
                presentError(
                    reader.primarySelection
                        ? t("Selection is not plain text.", "选区不是纯文本。")
                        : t("Clipboard is not plain text.", "剪贴板不是纯文本。"),
                    ""
                );
            }
            return;
        }
        if (exitCode === 3) {
            presentError(t("Text exceeds 100k characters.", "文本超过 10 万字符。"), "");
            return;
        }
        if (reader.smartInput) {
            openManualInput();
            return;
        }
        const sourceName = reader.primarySelection ? t("selection", "鼠标主选区") : t("clipboard", "剪贴板");
        presentError(t("No text in " + sourceName + ".", "未读取到" + sourceName + "文本。"), "");
    }

    function resolvedSecondaryLanguage() {
        const selected = String(pluginData?.secondaryLanguage ?? "English");
        if (selected === "__custom__")
            return "";
        return selected;
    }

    function resolvedTargetLanguage() {
        if (String(languageOverride || "").trim().length > 0)
            return String(languageOverride).trim();
        const selected = String(pluginData?.targetLanguage ?? "auto");
        if (selected === "__custom__")
            return String(pluginData?.customTargetLanguage ?? "").trim();
        if (selected === "auto" || selected.length === 0)
            return defaultLanguageForLocale();
        return selected;
    }

    function isLikelyLocalUrl(value) {
        const url = String(value || "").trim().toLowerCase();
        return /^https?:\/\/(localhost|127\.|\[::1\]|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)/.test(url);
    }

    function boundedTimeout(value, fallback, minimum, maximum) {
        const parsed = Number(value);
        if (isNaN(parsed))
            return fallback;
        return Math.max(minimum, Math.min(maximum, parsed));
    }

    function startTranslation(sourceText) {
        const text = String(sourceText || "").trim();
        if (!text) {
            presentError(t("Selection is empty.", "划词内容为空。"), "");
            return;
        }
        if (text.length > maxInputChars) {
            presentError(t("Text exceeds 100k characters.", "文本超过 10 万字符。"), "");
            return;
        }

        const targetLanguage = resolvedTargetLanguage();
        if (!targetLanguage) {
            presentError(t("Set a custom target language.", "请填写自定义目标语言。"), text);
            return;
        }

        cancelActive(false);
        currentOriginal = text;
        currentTranslation = "";
        currentError = "";
        editingOriginal = false;
        editedOriginal = "";
        currentStatus = "running";
        currentPhase = "starting";
        currentLanguage = targetLanguage;
        currentUsedFallback = false;

        const entries = providerEntries();
        if (entries.length === 0) {
            currentStatus = "error";
            currentPhase = "done";
            currentError = t("Add at least one provider in settings.",
                "请先在设置里添加至少一个提供商。");
            syncCurrentState();
            showPopup();
            return;
        }

        let wantedProvider = String(providerOverride || "").trim();
        let wantedModel = String(modelOverride || "").trim();
        if (wantedProvider.length === 0) {
            const fallbackTarget = String(pluginData?.defaultTarget || "").trim();
            const sep = fallbackTarget.indexOf(" · ");
            if (sep > 0) {
                wantedProvider = fallbackTarget.slice(0, sep).trim();
                wantedModel = fallbackTarget.slice(sep + 3).trim();
            }
        }
        // 首选 = 卡片临时选择或全局默认模型；其余提供商按排序紧随其后作为回退
        let primary = null;
        if (wantedProvider.length > 0) {
            for (let i = 0; i < entries.length; i++) {
                if (String(entries[i].name) === wantedProvider) {
                    primary = Object.assign({}, entries[i]);
                    break;
                }
            }
        }
        if (primary && wantedModel.length > 0)
            primary.model = wantedModel;

        let routes = [];
        if (primary)
            routes.push(primary);
        for (let i = 0; i < entries.length; i++) {
            if (primary && String(entries[i].name) === String(primary.name))
                continue;
            routes.push(entries[i]);
        }
        if (routes.length === 0)
            routes = entries;

        currentProvider = String(routes[0].name || "");
        currentModel = String(routes[0].model || "");
        syncCurrentState();
        showPopup();
        Qt.callLater(function () {
            if (translationScroll)
                translationScroll.contentY = 0;
            if (originalScroll)
                originalScroll.contentY = 0;
        });

        let budget = 0;
        for (let i = 0; i < routes.length; i++)
            budget += Number(routes[i].timeout || 60);

        const request = {
            providers: routes,
            target_lang: targetLanguage,
            secondary_lang: resolvedSecondaryLanguage(),
            prompt: String(pluginData?.prompt ?? defaultPrompt),
            stream: pluginData?.streaming ?? true,
            disable_thinking: pluginData?.disableThinking ?? true,
            timeout_budget: budget,
            ui_language: uiZh ? "zh" : "en",
            text: text
        };

        const process = translateProcessComponent.createObject(root, {
            requestData: request
        });
        activeProcess = process;
        helperStartTimer.restart();
        requestTimeoutTimer.interval = Math.ceil((request.timeout_budget + 10) * 1000);
        requestTimeoutTimer.restart();
        process.running = true;
    }

    function handleProtocolLine(process, line) {
        if (process !== activeProcess || !line || !String(line).trim())
            return;

        let event;
        try {
            event = JSON.parse(String(line));
        } catch (error) {
            process.protocolNoise += String(line) + "\n";
            return;
        }

        switch (event.type) {
        case "meta":
            process.requestAccepted = true;
            currentPhase = "waiting";
            currentProvider = String(event.provider || event.source || currentProvider);
            currentModel = String(event.model || currentModel);
            // 副语言生效时后端会改目标语言，这里跟着显示实际使用的语言
            if (event.target_lang)
                currentLanguage = String(event.target_lang);
            helperStartTimer.stop();
            break;
        case "delta":
            process.requestAccepted = true;
            currentPhase = "streaming";
            currentProvider = String(event.provider || event.source || currentProvider);
            helperStartTimer.stop();
            currentTranslation += String(event.text || "");
            globalTranslation.set(currentTranslation);
            break;
        case "fallback":
            process.requestAccepted = true;
            process.usedFallback = true;
            currentUsedFallback = true;
            currentTranslation = "";
            globalTranslation.set("");
            currentProvider = String(event.to_source || "");
            currentModel = "";
            currentPhase = "fallback";
            helperStartTimer.stop();
            break;
        case "done":
            process.gotDone = true;
            currentProvider = String(event.provider || event.source || currentProvider);
            currentModel = String(event.model || currentModel);
            finishSuccess(process);
            break;
        case "error":
            process.protocolError = true;
            helperStartTimer.stop();
            requestTimeoutTimer.stop();
            currentError = String(event.message || t("Translation failed", "翻译失败"));
            currentStatus = "error";
            currentPhase = "error";
            syncCurrentState();
            break;
        }
    }

    function finishSuccess(process) {
        if (process.finishedHandled)
            return;
        process.finishedHandled = true;
        helperStartTimer.stop();
        requestTimeoutTimer.stop();
        const translated = currentTranslation.trim();
        if (!translated) {
            process.protocolError = true;
            currentError = t("Empty translation.", "译文为空。")
            currentStatus = "error";
            currentPhase = "error";
            syncCurrentState();
            return;
        }

        currentTranslation = translated;
        currentStatus = "done";
        currentPhase = "done";
        currentError = "";
        syncCurrentState();
        addHistory(currentOriginal, currentTranslation, currentLanguage, currentProvider, currentModel);
    }

    function onTranslationExited(process, exitCode) {
        const isCurrent = process === activeProcess;
        if (isCurrent) {
            activeProcess = null;
            helperStartTimer.stop();
            requestTimeoutTimer.stop();
        }
        if (!isCurrent || process.cancelled)
            return;
        if (process.gotDone || process.finishedHandled || process.protocolError)
            return;
        if (exitCode === 0 && currentTranslation.trim()) {
            finishSuccess(process);
            return;
        }

        const details = (process.stderrText || process.protocolNoise || t("Translation process ended early.", "翻译进程提前结束。")).trim();
        currentError = details;
        currentStatus = "error";
        currentPhase = "error";
        syncCurrentState();
    }

    function failActiveProcess(process, message) {
        if (process !== activeProcess)
            return;
        activeProcess = null;
        process.cancelled = true;
        process.signal(15);
        helperStartTimer.stop();
        requestTimeoutTimer.stop();
        currentError = String(message || t("Translation failed", "翻译失败"));
        currentStatus = "error";
        currentPhase = "error";
        syncCurrentState();
    }

    function cancelActive(showStatus) {
        const process = activeProcess;
        if (!process)
            return;
        activeProcess = null;
        process.cancelled = true;
        process.signal(15);
        helperStartTimer.stop();
        requestTimeoutTimer.stop();
        if (showStatus) {
            currentStatus = "cancelled";
            currentPhase = "cancelled";
            currentError = t("Stopped", "已停止");
            syncCurrentState();
        }
    }

    function addHistory(original, translated, language, provider, model) {
        const now = Date.now();
        const entry = {
            id: String(now) + "-" + String(Math.floor(Math.random() * 1000000)),
            original: original,
            translated: translated,
            language: language,
            provider: String(provider || ""),
            model: String(model || ""),
            createdAt: now
        };
        let history = Array.isArray(globalHistory.value) ? globalHistory.value.slice() : [];
        history = history.filter(item => !(
            String(item.original || "") === original
                && String(item.translated || "") === translated
                && String(item.language || "") === language
        ));
        history.unshift(entry);
        history = history.slice(0, historyLimit());
        globalHistory.set(history);
        persistHistory(history);
    }

    function clearHistory() {
        globalHistory.set([]);
        persistHistory([]);
    }

    function removeHistoryEntry(entryId) {
        const history = Array.isArray(globalHistory.value) ? globalHistory.value : [];
        const filtered = history.filter(entry => String(entry.id) !== String(entryId));
        globalHistory.set(filtered);
        persistHistory(filtered);
    }

    function updateBarPlacement(section, shouldAdd) {
        const normalizedSection = ["left", "center", "right"].includes(section) ? section : "right";
        const propertyName = normalizedSection + "Widgets";
        const configs = Array.isArray(SettingsData.barConfigs) ? SettingsData.barConfigs : [];
        let changed = 0;

        for (const config of configs) {
            if (!(config?.enabled ?? true))
                continue;
            let widgets = Array.isArray(config[propertyName]) ? config[propertyName].slice() : [];
            const widgetId = widget => typeof widget === "string" ? widget : String(widget?.id || "");
            const existingIndex = widgets.findIndex(widget => widgetId(widget) === pluginId);

            if (shouldAdd && existingIndex < 0) {
                const entry = { id: pluginId, enabled: true };
                const clipboardIndex = widgets.findIndex(widget => widgetId(widget) === "clipboard");
                if (normalizedSection === "right" && clipboardIndex >= 0)
                    widgets.splice(clipboardIndex, 0, entry);
                else
                    widgets.push(entry);
            } else if (!shouldAdd && existingIndex >= 0) {
                widgets = widgets.filter(widget => widgetId(widget) !== pluginId);
            } else {
                continue;
            }

            const update = {};
            update[propertyName] = widgets;
            SettingsData.updateBarConfig(config.id, update);
            changed++;
        }
        return changed;
    }

    function copyTranslation() {
        const text = String(currentTranslation || "").trim();
        if (!text)
            return;
        globalClipboardWriteAt.set(Date.now());
        Quickshell.execDetached(["dms", "cl", "copy", text]);
        ToastService.showInfo(t("Copied", "已复制"));
    }

    function refreshModels() {
        if (modelListProcess)
            return;
        ToastService.showInfo(t("Fetching model list…", "正在获取模型列表…"));
        modelListStatus = "running base=" + String(pluginData?.localBaseUrl ?? "")
            + " keyLen=" + String(pluginData?.localApiKey ?? "").length
            + " path=" + root.pluginPath;
        const proc = modelListComponent.createObject(root);
        if (!proc) {
            ToastService.showError(t("Model list", "模型列表"), t("Could not start the fetch helper", "无法启动获取进程"));
            return;
        }
        modelListProcess = proc;
        proc.running = true;
    }

    function onModelsFetched(raw, exitCode) {
        modelListProcess = null;
        modelListStatus = "exit=" + exitCode + " raw=" + String(raw || "").slice(0, 200);
        let parsed = null;
        try {
            parsed = JSON.parse(String(raw || "").trim());
        } catch (e) {
            parsed = null;
        }
        if (!parsed || exitCode !== 0 || parsed.error) {
            const msg = parsed && parsed.error
                ? String(parsed.error)
                : t("Failed to fetch models", "获取模型列表失败");
            ToastService.showError(t("Model list", "模型列表"), msg);
            return;
        }
        const models = Array.isArray(parsed.models) ? parsed.models : [];
        if (!models.length) {
            ToastService.showError(t("Model list", "模型列表"), t("No models returned", "服务端没有返回模型"));
            return;
        }
        ToastService.showInfo(t("Fetched ", "已获取 ") + models.length + t(" models", " 个模型")
            + t("; set them in the provider form (Sync)", "；请在提供商表单里用「同步」选择"));
    }

    function providerEntries() {
        const raw = pluginData?.providers;
        const out = [];
        if (raw !== undefined && raw !== null && Array.isArray(raw) && raw.length > 0) {
            const ordered = raw.slice().sort((a, b) =>
                Number(a && a.sort ? a.sort : 999) - Number(b && b.sort ? b.sort : 999));
            for (let i = 0; i < ordered.length; i++) {
                const item = ordered[i] || {};
                const name = String(item.name || ("provider" + (i + 1))).trim();
                const baseUrl = String(item.baseUrl || "").trim();
                const model = String(item.model || "").trim();
                if (!baseUrl || !model)
                    continue;
                const keyName = "providerKey_" + name;
                const models = [];
                if (Array.isArray(item.models)) {
                    for (let m = 0; m < item.models.length; m++) {
                        const candidate = String(item.models[m] || "").trim();
                        if (candidate.length > 0 && models.indexOf(candidate) < 0)
                            models.push(candidate);
                    }
                }
                if (model.length > 0 && models.indexOf(model) < 0)
                    models.unshift(model);
                const resolvedModel = model.length > 0 ? model : String(models[0] || "");
                if (resolvedModel.length === 0)
                    continue;
                out.push({
                    name: name,
                    base_url: baseUrl,
                    endpoint: "/chat/completions",
                    api_key: pluginData ? String(pluginData[keyName] ?? "") : "",
                    model: resolvedModel,
                    models: models,
                    timeout: boundedTimeout(item.timeout, 60, 3, 600)
                });
            }
            if (out.length > 0)
                return out;
        }

        const localModel = String(pluginData?.localModel ?? "").trim();
        if (localModel.length > 0) {
            out.push({
                name: "local",
                base_url: String(pluginData?.localBaseUrl ?? "http://127.0.0.1:8080/v1").trim(),
                endpoint: String(pluginData?.localEndpoint ?? "/chat/completions").trim(),
                api_key: String(pluginData?.localApiKey ?? ""),
                model: localModel,
                timeout: boundedTimeout(pluginData?.localTimeoutSeconds, 15, 3, 120)
            });
        }
        const remoteModel = String(pluginData?.remoteModel ?? "").trim();
        if (remoteModel.length > 0) {
            out.push({
                name: "remote",
                base_url: String(pluginData?.remoteBaseUrl ?? "").trim(),
                endpoint: String(pluginData?.remoteEndpoint ?? "/chat/completions").trim(),
                api_key: String(pluginData?.remoteApiKey ?? ""),
                model: remoteModel,
                timeout: boundedTimeout(pluginData?.remoteTimeoutSeconds ?? pluginData?.timeoutSeconds, 120, 5, 600)
            });
        }
        return out;
    }

    function availableTargets() {
        const entries = providerEntries();
        const list = [];
        for (let i = 0; i < entries.length; i++) {
            const entry = entries[i];
            if (!entry.name || !entry.model)
                continue;
            const models = Array.isArray(entry.models) && entry.models.length > 0
                ? entry.models
                : [entry.model];
            for (let m = 0; m < models.length; m++) {
                const model = String(models[m] || "").trim();
                if (model.length === 0)
                    continue;
                list.push({ label: entry.name + " · " + model, provider: entry.name, model: model });
            }
        }
        return list;
    }

    function availableModels() {
        return availableTargets().map(item => String(item.label));
    }

    function modelsEverKnown() {
        return availableTargets().length > 0;
    }

    function currentTargetLabel() {
        const targets = availableTargets();
        let wantedProvider = String(providerOverride || currentProvider || "").trim();
        let wantedModel = String(modelOverride || currentModel || "").trim();
        if (wantedProvider.length === 0) {
            const fallback = String(pluginData?.defaultTarget || "").trim();
            const sep = fallback.indexOf(" · ");
            if (sep > 0) {
                wantedProvider = fallback.slice(0, sep).trim();
                wantedModel = fallback.slice(sep + 3).trim();
            }
        }
        for (let i = 0; i < targets.length; i++) {
            if (String(targets[i].provider) === wantedProvider && String(targets[i].model) === wantedModel)
                return String(targets[i].label);
        }
        if (targets.length > 0 && wantedProvider.length === 0)
            return String(targets[0].label);
        return wantedProvider.length > 0 ? (wantedProvider + " · " + wantedModel) : wantedModel;
    }

    readonly property string popupAnchor: {
        const value = String(pluginData?.popupAnchor ?? "top");
        return value === "bottom" ? value : "top";
    }

    readonly property bool autoTranslateEnabled: pluginData?.autoTranslate !== false
    readonly property bool dismissOnClickOutside: pluginData?.dismissOnClickOutside !== false

    function defaultLanguageForLocale() {
        const raw = String(SessionData.locale || Qt.locale().name || "").toLowerCase();
        if (raw.indexOf("zh") === 0) {
            if (raw.indexOf("tw") >= 0 || raw.indexOf("hk") >= 0 || raw.indexOf("hant") >= 0)
                return "Chinese (Traditional)";
            return "Chinese (Simplified)";
        }
        return "English";
    }

    // 当前主语言与英语置顶，其余保持原顺序
    readonly property var orderedLanguageChoices: {
        const setting = String(pluginData?.targetLanguage ?? "auto");
        const primary = resolvedTargetLanguage();
        const list = [];
        const seen = {};
        const push = function (value) {
            const key = String(value || "");
            if (!key || seen[key])
                return;
            seen[key] = true;
            list.push({ label: languageLabel(key), value: key });
        };
        push(primary);
        push("English");
        for (let i = 0; i < languageChoices.length; i++)
            push(languageChoices[i].value);
        return list;
    }

    function languageLabel(value) {
        for (let i = 0; i < languageChoices.length; i++) {
            if (String(languageChoices[i].value) === String(value))
                return String(languageChoices[i].label);
        }
        return String(value || "");
    }

    function languageLabels() {
        const out = [];
        for (let i = 0; i < languageChoices.length; i++)
            out.push(String(languageChoices[i].label));
        return out;
    }

    function languageValueFor(label) {
        for (let i = 0; i < languageChoices.length; i++) {
            if (String(languageChoices[i].label) === String(label))
                return String(languageChoices[i].value);
        }
        return String(label || "");
    }

    function menuItems() {
        if (menuName === "language") {
            const labels = [];
            const entries = orderedLanguageChoices;
            for (let i = 0; i < entries.length; i++)
                labels.push(String(entries[i].label));
            return labels;
        }
        return availableModels();
    }

    function isMenuRowActive(label) {
        if (menuName === "language")
            return String(currentLanguage) === String(languageValueFor(label));
        return String(currentTargetLabel()) === String(label);
    }

    function activateMenuRow(label) {
        if (menuName === "language")
            retryWithLanguage(languageValueFor(label));
        else
            retryWithModel(label);
    }

    function retryWithLanguage(language) {
        menuName = "";
        const chosen = String(language || "").trim();
        if (!chosen)
            return;
        languageOverride = chosen;
        const original = String(currentOriginal || "").trim();
        if (!original)
            return;
        ToastService.showInfo(t("Translating to ", "正在翻译为 ") + languageLabel(chosen));
        startTranslation(original);
    }

    function retryWithModel(targetLabel) {
        menuName = "";
        const wanted = String(targetLabel || "").trim();
        if (!wanted)
            return;
        const targets = availableTargets();
        let found = null;
        for (let i = 0; i < targets.length; i++) {
            if (String(targets[i].label) === wanted) {
                found = targets[i];
                break;
            }
        }
        if (!found)
            return;
        providerOverride = String(found.provider || "");
        modelOverride = String(found.model || "");
        const original = String(currentOriginal || "").trim();
        if (!original)
            return;
        ToastService.showInfo(t("Switching to ", "正在切换到 ") + wanted);
        startTranslation(original);
    }

    function retryTranslation() {
        const original = String(currentOriginal || "").trim();
        if (!original) {
            ToastService.showInfo(t("Nothing to retry", "没有可重试的原文"));
            return;
        }
        startTranslation(original);
    }

    function beginEditOriginal() {
        if (currentStatus === "running")
            return;
        if (!String(currentOriginal || "").trim())
            return;
        editedOriginal = currentOriginal;
        editingOriginal = true;
        Qt.callLater(function () {
            if (originalEdit)
                originalEdit.forceActiveFocus();
        });
    }

    function cancelEditOriginal() {
        editingOriginal = false;
        editedOriginal = "";
    }

    function commitOriginalAndTranslate() {
        if (!editingOriginal)
            return;
        const text = String(editedOriginal || "").trim();
        editingOriginal = false;
        editedOriginal = "";
        if (!text || text === String(currentOriginal || "").trim())
            return;
        currentOriginal = text;
        startTranslation(text);
    }

    Component {
        id: modelListComponent

        Process {
            id: lister
            property string buffer: ""

            environment: {
                let env = {
                    "UV_NO_PROGRESS": "1",
                    "PYTHONDONTWRITEBYTECODE": "1",
                    "PYTHONUNBUFFERED": "1"
                };
                const entries = root.providerEntries();
                const first = entries.length > 0 ? entries[0] : ({});
                const base = String(first.base_url || "").trim();
                const key = String(first.api_key || "");
                if (base.length > 0)
                    env["DTAI_BASE_URL"] = base;
                if (key.length > 0)
                    env["DTAI_API_KEY"] = key;
                return env;
            }

            command: [
                "uv", "run",
                "--project", root.pluginPath,
                "--offline",
                "--frozen",
                root.pluginPath + "/list_models.py"
            ]

            stdout: StdioCollector {
                onStreamFinished: lister.buffer = text
            }

            stderr: StdioCollector {}

            onExited: (exitCode, exitStatus) => {
                Qt.callLater(() => {
                    root.onModelsFetched(lister.buffer, exitCode);
                    lister.destroy();
                });
            }
        }
    }

    Component {
        id: selectionReaderComponent

        Process {
            id: reader
            property bool primarySelection: true
            property bool smartInput: false
            property string clipboardEntryId: ""
            property string capturedText: ""

            environment: {
                "UV_NO_PROGRESS": "1",
                "PYTHONDONTWRITEBYTECODE": "1",
                "PYTHONUNBUFFERED": "1"
            }
            command: [
                "uv", "run",
                "--project", root.pluginPath,
                "--offline",
                "--frozen",
                root.captureHelperPath,
                primarySelection ? "primary" : "clipboard",
                String(root.maxInputChars),
                primarySelection ? "allow-sensitive" : "protect-sensitive"
            ]

            stdout: StdioCollector {
                onStreamFinished: reader.capturedText = text
            }

            stderr: StdioCollector {}

            onExited: (exitCode, exitStatus) => {
                Qt.callLater(() => {
                    root.onCaptured(reader, exitCode);
                    reader.destroy();
                });
            }
        }
    }

    Component {
        id: translateProcessComponent

        Process {
            id: translateProcess
            property var requestData: ({})
            property bool gotDone: false
            property bool finishedHandled: false
            property bool protocolError: false
            property bool cancelled: false
            property bool requestAccepted: false
            property bool usedFallback: false
            property string stderrText: ""
            property string protocolNoise: ""

            stdinEnabled: true
            environment: {
                "UV_NO_PROGRESS": "1",
                "PYTHONDONTWRITEBYTECODE": "1",
                "PYTHONUNBUFFERED": "1"
            }
            command: [
                "uv", "run",
                "--project", root.pluginPath,
                "--offline",
                "--frozen",
                root.helperPath
            ]

            stdout: SplitParser {
                splitMarker: "\n"
                onRead: line => root.handleProtocolLine(translateProcess, line)
            }

            stderr: SplitParser {
                splitMarker: "\n"
                onRead: line => {
                    if (line)
                        translateProcess.stderrText += String(line) + "\n";
                }
            }

            onStarted: translateProcess.write(JSON.stringify(requestData) + "\n")

            onExited: (exitCode, exitStatus) => {
                root.onTranslationExited(translateProcess, exitCode);
                translateProcess.destroy();
            }
        }
    }

    IpcHandler {
        id: ipc
        target: ""
        enabled: false

        function translateSelection(): string {
            root.beginSelectionTranslation();
            return "TRANSLATE_SELECTION_STARTED";
        }

        function translateClipboard(): string {
            root.beginClipboardTranslation();
            return "TRANSLATE_CLIPBOARD_STARTED";
        }

        function translateText(text: string): string {
            root.startTranslation(text);
            return "TRANSLATE_TEXT_STARTED";
        }

        function openModelMenu(): string {
            root.menuName = root.menuName === "model" ? "" : "model";
            return root.menuName === "model" ? "MODEL_MENU_OPEN" : "MODEL_MENU_CLOSED";
        }

        function openLanguageMenu(): string {
            root.menuName = root.menuName === "language" ? "" : "language";
            return root.menuName === "language" ? "LANGUAGE_MENU_OPEN" : "LANGUAGE_MENU_CLOSED";
        }

        function retry(): string {
            root.retryTranslation();
            return "TRANSLATE_RETRY_STARTED";
        }

        function translateWithModel(model: string): string {
            root.retryWithModel(model);
            return "TRANSLATE_WITH_MODEL_STARTED";
        }

        function translateToLanguage(language: string): string {
            root.retryWithLanguage(language);
            return "TRANSLATE_TO_LANGUAGE_STARTED";
        }

        function models(): string {
            return JSON.stringify(root.availableModels());
        }

        function refreshModels(): string {
            root.refreshModels();
            return "MODEL_LIST_FETCH_STARTED";
        }

        function editOriginal(): string {
            root.beginEditOriginal();
            return "TRANSLATE_SOURCE_EDIT_STARTED";
        }

        function cancelEdit(): string {
            root.cancelEditOriginal();
            return "TRANSLATE_SOURCE_EDIT_CANCELLED";
        }

        function show(): string {
            root.showPopup();
            return "TRANSLATE_POPUP_SHOWN";
        }

        function open(): string {
            root.showPopup();
            return "TRANSLATE_POPUP_SHOWN";
        }

        function close(): string {
            root.closePopup();
            return "TRANSLATE_POPUP_CLOSED";
        }

        function cancel(): string {
            root.cancelActive(true);
            return "TRANSLATE_CANCELLED";
        }

        function clearHistory(): string {
            root.clearHistory();
            return "TRANSLATE_HISTORY_CLEARED";
        }

        function removeHistory(entryId: string): string {
            root.removeHistoryEntry(entryId);
            return "TRANSLATE_HISTORY_ENTRY_REMOVED";
        }

        function debugSetting(key: string): string {
            return JSON.stringify(SettingsData.getPluginSetting(pluginId, key, "MISSING"));
        }

        function status(): string {
            return JSON.stringify({
                state: root.currentStatus,
                phase: root.currentPhase,
                original: root.currentOriginal,
                translation: root.currentTranslation,
                error: root.currentError,
                language: root.currentLanguage,
                provider: root.currentProvider,
                model: root.currentModel,
                usedFallback: root.currentUsedFallback,
                modelListStatus: root.modelListStatus,
                languageOverride: root.languageOverride,
                modelOverride: root.modelOverride,
                popupVisible: root.popupVisible
            });
        }

        function addToBar(section: string): string {
            const changed = root.updateBarPlacement(section || "right", true);
            return "TRANSLATE_BAR_ADDED: " + changed;
        }

        function removeFromBar(section: string): string {
            const changed = root.updateBarPlacement(section || "right", false);
            return "TRANSLATE_BAR_REMOVED: " + changed;
        }
    }

    PanelWindow {
        id: popupWindow

        readonly property real contentWidth: screen
            ? Math.min(760, Math.max(360, screen.width - 32))
            : 680
        readonly property real topOffset: Theme.barHeight + Theme.spacingL
        readonly property real maxCardHeight: screen
            ? Math.max(1, Math.floor(screen.height * 0.5 - topOffset))
            : 400
        readonly property int menuRowHeight: 30
        readonly property int menuMaxRows: 5
        readonly property real menuBoxHeight: Math.min(menuMaxRows * menuRowHeight + Theme.spacingS * 2,
            dropMenuColumn.implicitHeight + Theme.spacingS * 2)
        readonly property bool hasOriginal: root.showOriginal
            && String(root.currentOriginal || "").trim().length > 0
        readonly property real originalBoxHeight: !hasOriginal
            ? 0
            : (root.editingOriginal
                ? Math.min(220, Math.max(96, originalEdit.contentHeight + Theme.spacingS * 2))
                : Math.min(150, Math.max(46, originalText.implicitHeight + Theme.spacingS * 2)))
        // 没有原文（空闲态）时显示手动输入框
        readonly property bool hasManualInput: !hasOriginal && root.currentStatus !== "running"
        // 一行起，按内容撑开，到 160 后内部滚动
        readonly property real manualBoxHeight: Math.min(160,
            Math.max(38, manualEdit.contentHeight + Theme.spacingS * 2))
        readonly property real cardChromeHeight: Theme.spacingM * 2
            + 30
            + 30
            + Theme.spacingS * 4
            + originalBoxHeight
            + (hasManualInput ? manualBoxHeight + Theme.spacingS : 0)
            + (root.menuName !== "" ? menuBoxHeight + Theme.spacingS : 0)
        readonly property real maxTranslationHeight: Math.max(0, maxCardHeight - cardChromeHeight)

        screen: root.popupScreen
        visible: root.popupVisible
        color: "transparent"
        implicitWidth: contentWidth
        implicitHeight: popupCard.height

        // 统一用 top+left 锚点 + margins 定位：anchors.right 在 layer-shell 上
        // 与 margins.right 组合时位置不稳定，四角都改用计算出的 margin。
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        WlrLayershell.namespace: "dms:dank-translate-ai"
        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.exclusiveZone: -1
        // OnDemand 必须在 popup 可见时就打开：Wayland 在 pointer 点击那一刻
        // 就决定是否授予键盘焦点，若等点击回调里再切 OnDemand，这次点击已经白费，
        // 结果就是"进了编辑态但打不了字"。
        WlrLayershell.keyboardFocus: root.popupVisible
            ? WlrKeyboardFocus.OnDemand
            : WlrKeyboardFocus.None
        readonly property real cardX: screen
            ? Math.max(0, Math.round((screen.width - implicitWidth) / 2))
            : Theme.spacingL
        readonly property real cardY: {
            if (!screen)
                return topOffset;
            if (root.popupAnchor === "bottom")
                return Math.max(0, screen.height - implicitHeight - Theme.spacingL);
            return topOffset;
        }

        MouseArea {
            id: dismissLayer
            anchors.fill: parent
            enabled: root.dismissOnClickOutside
            onClicked: root.closePopup()
        }

        StyledRect {
            id: popupCard
            x: popupWindow.cardX
            y: popupWindow.cardY
            width: popupWindow.contentWidth
            height: popupColumn.implicitHeight + Theme.spacingM * 2
            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
            border.width: 1
            border.color: Theme.outlineMedium

            // 卡片区域内吞掉点击，避免点空白处被判成“点了外部”
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            Column {
                id: popupColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS

                Item {
                    width: parent.width
                    height: 30

                    DankIcon {
                        id: headerIcon
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        name: root.currentStatus === "error" ? "error" : "translate"
                        size: Theme.iconSize
                        color: root.currentStatus === "error" ? Theme.error : Theme.primary
                    }

                    StyledText {
                        id: popupTitle
                        anchors.left: headerIcon.right
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.t("Translate", "翻译")
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Bold
                    }

                    StyledText {
                        anchors.left: popupTitle.right
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: progressIcon.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            switch (root.currentStatus) {
                            case "running": return root.t("· To ", "· 翻译为 ") + root.languageLabel(root.currentLanguage);
                            case "done": return root.t("· Done · ", "· 完成 · ") + root.languageLabel(root.currentLanguage);
                            case "cancelled": return root.t("· Stopped", "· 已停止");
                            case "error": return root.t("· Error", "· 错误");
                            default: return "· " + root.languageLabel(root.currentLanguage);
                            }
                        }
                        color: root.currentStatus === "error" ? Theme.error : Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                    }

                    DankIcon {
                        id: progressIcon
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.currentStatus === "running"
                        name: "progress_activity"
                        size: Theme.iconSizeSmall
                        color: Theme.primary

                        RotationAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 900
                            loops: Animation.Infinite
                            running: progressIcon.visible
                        }
                    }
                }

                StyledRect {
                    id: manualBox
                    visible: popupWindow.hasManualInput
                    width: parent.width
                    height: popupWindow.manualBoxHeight
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainer
                    border.width: manualEdit.activeFocus ? 2 : 1
                    border.color: manualEdit.activeFocus ? Theme.primary : Theme.outlineMedium

                    DankFlickable {
                        id: manualScroll
                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        contentWidth: width
                        contentHeight: Math.max(height, manualEdit.contentHeight)
                        clip: true
                        verticalScrollBar.visible: contentHeight > height
                        verticalScrollBar.opacity: contentHeight > height ? 1 : 0

                        TextEdit {
                            id: manualEdit
                            width: Math.max(0, manualScroll.width - Theme.spacingM)
                            height: Math.max(contentHeight, manualScroll.height)
                            color: Theme.surfaceText
                            selectionColor: Theme.primary
                            selectedTextColor: Theme.primaryText
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true
                            activeFocusOnTab: true
                            textFormat: TextEdit.PlainText

                            StyledText {
                                anchors.fill: parent
                                visible: manualEdit.text.length === 0
                                text: root.t("Type or paste text to translate…", "输入或粘贴要翻译的文本…")
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeSmall
                                wrapMode: Text.WordWrap
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignLeft
                            }

                            Keys.onPressed: event => {
                                if ((event.modifiers & Qt.ControlModifier)
                                    && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                                    root.translateManual(manualEdit.text);
                                    event.accepted = true;
                                }
                            }
                        }
                    }
                }

                StyledRect {
                    id: originalBox
                    visible: popupWindow.hasOriginal
                    width: parent.width
                    height: popupWindow.originalBoxHeight
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainer
                    border.width: root.editingOriginal ? 2 : 1
                    border.color: root.editingOriginal ? Theme.primary : Theme.outlineMedium

                    DankFlickable {
                        id: originalScroll
                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        contentWidth: width
                        contentHeight: root.editingOriginal
                            ? Math.max(height, originalEdit.contentHeight)
                            : Math.max(height, originalText.implicitHeight)
                        clip: true
                        verticalScrollBar.visible: contentHeight > height
                        verticalScrollBar.opacity: contentHeight > height ? 1 : 0

                        StyledText {
                            id: originalText
                            visible: !root.editingOriginal
                            width: Math.max(0, originalScroll.width - Theme.spacingM)
                            text: String(root.currentOriginal || "")
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.WordWrap
                            textFormat: Text.PlainText
                            elide: Text.ElideNone
                            verticalAlignment: Text.AlignTop
                        }

                        TextEdit {
                            id: originalEdit
                            visible: root.editingOriginal
                            width: Math.max(0, originalScroll.width - Theme.spacingM)
                            height: Math.max(contentHeight, originalScroll.height)
                            color: Theme.surfaceText
                            selectionColor: Theme.primary
                            selectedTextColor: Theme.primaryText
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true
                            activeFocusOnTab: true

                            onVisibleChanged: {
                                if (visible) {
                                    text = root.editedOriginal;
                                    cursorPosition = text.length;
                                }
                            }

                            onTextChanged: {
                                if (root.editingOriginal)
                                    root.editedOriginal = text;
                            }

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Escape) {
                                    root.cancelEditOriginal();
                                    event.accepted = true;
                                } else if ((event.modifiers & Qt.ControlModifier)
                                           && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                                    root.commitOriginalAndTranslate();
                                    event.accepted = true;
                                }
                            }
                        }
                    }

                    DankIcon {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.spacingS
                        visible: !root.editingOriginal && root.currentStatus !== "running"
                        name: "edit"
                        size: 12
                        color: Theme.surfaceVariantText
                        opacity: 0.5
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !root.editingOriginal && root.currentStatus !== "running"
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.beginEditOriginal()
                    }
                }

                StyledRect {
                    id: translationBox
                    width: parent.width
                    height: Math.min(popupWindow.maxTranslationHeight, Math.max(112, translationText.implicitHeight + Theme.spacingS * 2))
                    radius: Theme.cornerRadius
                    color: root.currentStatus === "error"
                        ? Theme.withAlpha(Theme.error, 0.10)
                        : Theme.surfaceContainerHigh

                    DankFlickable {
                        id: translationScroll
                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        contentWidth: width
                        contentHeight: Math.max(height, translationText.implicitHeight)
                        clip: true
                        verticalScrollBar.visible: contentHeight > height
                        verticalScrollBar.opacity: contentHeight > height ? 1 : 0

                        StyledText {
                            id: translationText
                            width: Math.max(0, translationScroll.width - Theme.spacingM)
                            height: implicitHeight
                            text: root.currentStatus === "error"
                                ? root.currentError
                                : (root.currentTranslation || (root.currentStatus === "idle"
                                    ? (root.currentOriginal.length > 0
                                        ? root.t("Press translate to start.", "点「翻译」开始。")
                                        : root.t("Type or paste text to translate first.", "请先输入或粘贴要翻译的文字。"))
                                    : (root.currentPhase === "waiting"
                                    ? root.t("Waiting for model…", "等待模型响应…")
                                    : root.t("Starting translator…", "正在启动翻译…"))))
                            color: root.currentStatus === "error" ? Theme.error : Theme.surfaceText
                            font.pixelSize: Theme.fontSizeMedium
                            wrapMode: Text.WordWrap
                            textFormat: Text.PlainText
                            elide: Text.ElideNone
                            verticalAlignment: Text.AlignTop
                        }
                    }
                }

                StyledRect {
                    id: dropMenu
                    visible: root.menuName !== ""
                    width: parent.width
                    height: popupWindow.menuBoxHeight
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHighest
                    border.width: 1
                    border.color: Theme.outlineMedium
                    clip: true

                    DankFlickable {
                        id: dropMenuScroll
                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        contentWidth: width
                        contentHeight: dropMenuColumn.implicitHeight
                        clip: true
                        verticalScrollBar.visible: contentHeight > height
                        verticalScrollBar.opacity: contentHeight > height ? 1 : 0

                        Component.onCompleted: contentY = 0

                        Connections {
                            target: root
                            function onMenuNameChanged() {
                                dropMenuScroll.contentY = 0;
                            }
                        }

                        Column {
                            id: dropMenuColumn
                            width: dropMenuScroll.width
                            spacing: 0

                            Repeater {
                                model: root.menuItems()

                                delegate: StyledRect {
                                    required property string modelData
                                    width: dropMenuColumn.width
                                    height: popupWindow.menuRowHeight
                                    radius: Theme.cornerRadius
                                    color: menuRowMouse.containsMouse
                                        ? Theme.surfaceContainer
                                        : "transparent"
                                    border.width: 1
                                    border.color: root.isMenuRowActive(modelData)
                                        ? Theme.primary
                                        : "transparent"

                                    StyledText {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.leftMargin: Theme.spacingS
                                        anchors.rightMargin: Theme.spacingS
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData
                                        color: Theme.surfaceText
                                        font.pixelSize: Theme.fontSizeSmall
                                        wrapMode: Text.NoWrap
                                        elide: Text.ElideRight
                                    }

                                    MouseArea {
                                        id: menuRowMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.activateMenuRow(modelData)
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    id: footerBar
                    width: parent.width
                    height: 30

                    Row {
                        id: footerLeft
                        anchors.left: parent.left
                        anchors.right: footerButtons.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        StyledRect {
                            id: modelSelector
                            visible: root.modelsEverKnown()
                            width: Math.min(230, modelSelectorRow.implicitWidth + Theme.spacingM)
                            height: 26
                            radius: height / 2
                            color: root.menuName === "model" ? Theme.primary : Theme.surfaceContainerHighest
                            border.width: 1
                            border.color: root.menuName === "model" ? Theme.primary : Theme.outlineMedium
                            clip: true

                            Row {
                                id: modelSelectorRow
                                anchors.centerIn: parent
                                spacing: 4

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth, 176)
                                    text: root.currentTargetLabel()
                                    color: root.menuName === "model" ? Theme.primaryText : Theme.surfaceText
                                    font.pixelSize: Math.max(9, Theme.fontSizeSmall - 1)
                                    wrapMode: Text.NoWrap
                                    elide: Text.ElideRight
                                }

                                DankIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: root.menuName === "model" ? "expand_less" : "expand_more"
                                    size: 14
                                    color: root.menuName === "model" ? Theme.primaryText : Theme.surfaceVariantText
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.menuName = root.menuName === "model" ? "" : "model"
                            }
                        }

                        StyledRect {
                            id: languageSelector
                            width: Math.min(160, languageSelectorRow.implicitWidth + Theme.spacingM)
                            height: 26
                            radius: height / 2
                            color: root.menuName === "language" ? Theme.primary : Theme.surfaceContainerHighest
                            border.width: 1
                            border.color: root.menuName === "language" ? Theme.primary : Theme.outlineMedium
                            clip: true

                            Row {
                                id: languageSelectorRow
                                anchors.centerIn: parent
                                spacing: 4

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth, 108)
                                    text: root.languageLabel(root.currentLanguage)
                                    color: root.menuName === "language" ? Theme.primaryText : Theme.surfaceText
                                    font.pixelSize: Math.max(9, Theme.fontSizeSmall - 1)
                                    wrapMode: Text.NoWrap
                                    elide: Text.ElideRight
                                }

                                DankIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: root.menuName === "language" ? "expand_less" : "expand_more"
                                    size: 14
                                    color: root.menuName === "language" ? Theme.primaryText : Theme.surfaceVariantText
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.menuName = root.menuName === "language" ? "" : "language"
                            }
                        }
                    }

                    Row {
                        id: footerButtons
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXS

                        DankActionButton {
                            id: manualTranslateButton
                            visible: root.currentStatus === "idle" && !root.editingOriginal
                            buttonSize: 30
                            iconName: "translate"
                            iconColor: Theme.primaryText
                            backgroundColor: Theme.primary
                            tooltipText: root.t("Translate (Ctrl+Enter)", "翻译（Ctrl+Enter）")
                            onClicked: {
                                const typed = String(manualEdit.text || "").trim();
                                root.translateManual(typed.length > 0 ? typed : root.currentOriginal);
                            }
                        }

                        DankActionButton {
                            id: reTranslateButton
                            visible: root.editingOriginal
                            buttonSize: 30
                            iconName: "check"
                            iconColor: Theme.primaryText
                            backgroundColor: Theme.primary
                            tooltipText: root.t("Translate edited source (Ctrl+Enter)", "用修改后的原文重新翻译（Ctrl+Enter）")
                            onClicked: root.commitOriginalAndTranslate()
                        }

                        DankActionButton {
                            id: cancelEditButton
                            visible: root.editingOriginal
                            buttonSize: 30
                            iconName: "close"
                            iconColor: Theme.surfaceText
                            backgroundColor: Theme.surfaceContainerHighest
                            tooltipText: root.t("Cancel source edit (Esc)", "取消编辑原文（Esc）")
                            onClicked: root.cancelEditOriginal()
                        }

                        DankActionButton {
                            id: retryButton
                            visible: root.currentStatus !== "running" && !root.editingOriginal
                                && String(root.currentOriginal || "").trim().length > 0
                            buttonSize: 30
                            iconName: "refresh"
                            iconColor: Theme.surfaceText
                            backgroundColor: Theme.surfaceContainerHighest
                            tooltipText: root.t("Retry", "重试")
                            onClicked: root.retryTranslation()
                        }

                        DankActionButton {
                            id: stopButton
                            visible: root.currentStatus === "running"
                            buttonSize: 30
                            iconName: "stop_circle"
                            iconColor: Theme.surfaceText
                            backgroundColor: Theme.surfaceContainerHighest
                            onClicked: root.cancelActive(true)
                        }

                        DankActionButton {
                            id: closeButton
                            visible: !root.editingOriginal
                            buttonSize: 30
                            iconName: "close"
                            iconColor: Theme.surfaceText
                            backgroundColor: Theme.surfaceContainerHighest
                            onClicked: root.closePopup()
                        }

                        DankActionButton {
                            id: copyButton
                            visible: !root.editingOriginal
                            buttonSize: 30
                            iconName: "content_copy"
                            iconColor: Theme.primaryText
                            backgroundColor: Theme.primary
                            enabled: root.currentTranslation.trim().length > 0
                            onClicked: root.copyTranslation()
                        }
                    }
                }
            }
        }

        // 开启“点击外部关闭”时不设 mask，全屏背景层才能收到那次点击；
        // 关闭时输入区域收窄到卡片，点击照常穿透到下面的应用。
        mask: root.dismissOnClickOutside
            ? null
            : cardRegion

        Region {
            id: cardRegion
            item: popupCard
        }
    }
}
