pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Services
import Quickshell.Io

PluginSettings {
    id: root
    pluginId: "dankTranslateAI"

    readonly property string dmsLocale: {
        const raw = String(SessionData.locale || "");
        return raw === "" ? String(Qt.locale().name) : raw;
    }
    readonly property bool zh: dmsLocale.toLowerCase().indexOf("zh") === 0
    readonly property string defaultPrompt: "system: Translate the text provided by the user into ${target_lang}. Preserve the original meaning, tone, paragraph structure, Markdown formatting, code, names, and numbers. Output only the translation.\nuser: ${text}"

    function storedValue(key, fallback) {
        const marker = "__dank_translate_missing__";
        const value = loadValue(key, marker);
        return value === marker ? fallback : value;
    }

    // ---------- 提供商编辑器状态 ----------
    readonly property string pluginDir: String(Quickshell.env("HOME")) + "/.config/DankMaterialShell/plugins/dankTranslateAI"
    property var providerList: []
    property int providerEditingIndex: -1
    property var providerModels: []
    property string draftModel: ""
    property string providerStatus: ""
    property bool providerBusy: false
    property bool providerDropdownReady: false

    readonly property string customModelLabel: zh ? "自定义" : "Custom"

    function providerModelChoices() {
        const list = [];
        for (let i = 0; i < providerModels.length; i++)
            list.push(String(providerModels[i]));
        list.push(customModelLabel);
        return list;
    }

    function refreshProviderList() {
        const raw = storedValue("providers", []);
        const list = Array.isArray(raw) ? raw.slice() : [];
        list.sort((a, b) => Number(a && a.sort ? a.sort : 999) - Number(b && b.sort ? b.sort : 999));
        providerList = list;
    }

    function defaultTargetOptions() {
        const list = [];
        const entries = providerList;
        for (let i = 0; i < entries.length; i++) {
            const entry = entries[i] || {};
            const name = String(entry.name || "");
            if (!name)
                continue;
            const models = Array.isArray(entry.models) && entry.models.length > 0
                ? entry.models
                : [String(entry.model || "")];
            for (let m = 0; m < models.length; m++) {
                const model = String(models[m] || "").trim();
                if (model)
                    list.push({ label: name + " · " + model, value: name + " · " + model });
            }
        }
        return list;
    }

    function resetProviderDraft() {
        providerEditingIndex = -1;
        if (nameField) nameField.text = "";
        if (baseField) baseField.text = "";
        if (keyField) keyField.text = "";
        if (customModelField) customModelField.text = "";
        if (timeoutField) timeoutField.text = "60";
        if (sortField) sortField.text = String(providerList.length + 1);
        providerModels = [];
        draftModel = "";
        providerStatus = "";
    }

    function editProvider(index) {
        const item = providerList[index];
        if (!item)
            return;
        providerEditingIndex = index;
        nameField.text = String(item.name || "");
        baseField.text = String(item.baseUrl || "");
        keyField.text = String(loadValue("providerKey_" + String(item.name || ""), "") || "");
        const existingModels = [];
        if (Array.isArray(item.models)) {
            for (let i = 0; i < item.models.length; i++) {
                const candidate = String(item.models[i] || "").trim();
                if (candidate.length > 0 && existingModels.indexOf(candidate) < 0)
                    existingModels.push(candidate);
            }
        }
        const currentModel = String(item.model || "");
        if (currentModel.length > 0 && existingModels.indexOf(currentModel) < 0)
            existingModels.unshift(currentModel);
        providerModels = existingModels;
        draftModel = currentModel;
        customModelField.text = "";
        timeoutField.text = String(item.timeout || "60");
        sortField.text = String(item.sort || (index + 1));
        providerStatus = root.zh ? "正在修改 " + String(item.name || "") : "Editing " + String(item.name || "");
    }

    function deleteProvider(index) {
        const list = providerList.slice();
        const removed = list.splice(index, 1);
        saveValue("providers", list);
        refreshProviderList();
        providerStatus = removed.length > 0
            ? (root.zh ? "已删除 " + String(removed[0].name || "") : "Deleted " + String(removed[0].name || ""))
            : "";
        if (providerEditingIndex >= 0)
            resetProviderDraft();
    }

    function saveProvider() {
        const name = String(nameField.text || "").trim();
        const baseUrl = String(baseField.text || "").trim();
        const apiKey = String(keyField.text || "");
        let models = providerModels.slice();
        let model = String(draftModel || "").trim();
        if (model === customModelLabel) {
            const custom = String(customModelField.text || "").trim();
            if (custom.length > 0) {
                model = custom;
                if (models.indexOf(custom) < 0)
                    models.push(custom);
            } else {
                // 自定义留空：保存同步到的全部模型，默认取第一个
                model = models.length > 0 ? String(models[0]) : "";
            }
        } else if (model.length === 0) {
            // 没手动选：默认取同步列表的第一个
            model = models.length > 0 ? String(models[0]) : "";
        }
        if (model.length > 0 && models.indexOf(model) < 0)
            models.unshift(model);
        const timeout = String(timeoutField.text || "").trim() || "60";
        if (!name || !baseUrl || models.length === 0) {
            providerStatus = root.zh
                ? "名称、Base URL 不能为空，且至少需要一个模型（点「同步」获取，或选「自定义」填写）"
                : "Name and Base URL are required, and at least one model is needed (Sync or Custom)";
            return;
        }
        let sort = parseInt(String(sortField.text || "").trim(), 10);
        if (isNaN(sort) || sort < 1)
            sort = providerList.length + 1;

        let list = providerList.slice();
        if (providerEditingIndex >= 0)
            list.splice(providerEditingIndex, 1);

        // 同排序冲突：>= sort 的往后移一位（保持插入语义）
        for (let i = 0; i < list.length; i++) {
            const current = Number(list[i].sort || 0);
            if (current >= sort)
                list[i] = Object.assign({}, list[i], { sort: current + 1 });
        }

        list.push({
            name: name,
            baseUrl: baseUrl,
            model: model,
            models: models,
            timeout: timeout,
            sort: sort
        });
        list.sort((a, b) => Number(a.sort || 999) - Number(b.sort || 999));

        saveValue("providers", list);
        saveValue("providerKey_" + name, apiKey);
        refreshProviderList();
        const savedName = name;
        resetProviderDraft();
        providerStatus = root.zh ? "已保存 " + savedName : "Saved " + savedName;
    }

    function syncProviderModels() {
        if (providerBusy)
            return;
        const base = String(baseField.text || "").trim();
        if (!base) {
            providerStatus = root.zh ? "先填 Base URL" : "Fill in the Base URL first";
            return;
        }
        providerBusy = true;
        providerStatus = root.zh ? "正在拉取模型列表…" : "Fetching models…";
        providerModels = [];
        const proc = syncComponent.createObject(root, {
            "targetBase": base,
            "targetKey": String(keyField.text || "")
        });
        if (!proc) {
            providerBusy = false;
            providerStatus = root.zh ? "无法启动获取进程" : "Could not start the fetch helper";
            return;
        }
        syncProcess = proc;
        proc.running = true;
    }

    function applyProviderModel(model) {
        draftModel = String(model || "");
        providerStatus = root.zh ? "已选择 " + String(model || "") : "Selected " + String(model || "");
    }

    property var syncProcess: null

    Component {
        id: syncComponent

        Process {
            id: syncProc
            property string targetBase: ""
            property string targetKey: ""
            property string buffer: ""

            environment: ({
                "UV_NO_PROGRESS": "1",
                "PYTHONDONTWRITEBYTECODE": "1",
                "PYTHONUNBUFFERED": "1",
                "DTAI_BASE_URL": syncProc.targetBase,
                "DTAI_API_KEY": syncProc.targetKey
            })

            command: [
                "uv", "run",
                "--project", root.pluginDir,
                "--offline",
                "--frozen",
                root.pluginDir + "/list_models.py"
            ]

            stdout: StdioCollector {
                onStreamFinished: syncProc.buffer = text
            }

            stderr: StdioCollector {}

            onExited: (exitCode, exitStatus) => {
                Qt.callLater(() => {
                    root.providerBusy = false;
                    let parsed = null;
                    try {
                        parsed = JSON.parse(String(syncProc.buffer || "").trim());
                    } catch (e) {
                        parsed = null;
                    }
                    if (parsed && Array.isArray(parsed.models) && parsed.models.length > 0) {
                        root.providerModels = parsed.models;
                        if (root.providerModels.indexOf(root.draftModel) < 0)
                            root.draftModel = String(parsed.models[0] || "");
                        root.providerStatus = root.zh
                            ? "获取到 " + parsed.models.length + " 个模型"
                            : parsed.models.length + " models fetched";
                    } else {
                        root.providerStatus = parsed && parsed.error
                            ? String(parsed.error)
                            : (root.zh ? "获取模型失败" : "Failed to fetch models");
                    }
                    syncProc.destroy();
                });
            }
        }
    }

    onPluginServiceChanged: Qt.callLater(reloadProvidersFromService)

    Connections {
        target: pluginService
        enabled: pluginService !== null

        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId === pluginId)
                Qt.callLater(reloadProvidersFromService);
        }
    }

    function reloadProvidersFromService() {
        migrateLegacyProviders();
        refreshProviderList();
        providerDropdownReady = true;
        if (sortField && String(sortField.text || "").trim() === "")
            sortField.text = String(providerList.length + 1);
    }

    Component.onCompleted: Qt.callLater(reloadProvidersFromService)

    function migrateLegacyProviders() {
        const existing = storedValue("providers", []);
        if (Array.isArray(existing) && existing.length > 0)
            return;
        const list = [];
        const localModel = String(storedValue("localModel", "") || "").trim();
        if (localModel.length > 0) {
            list.push({
                name: "local",
                baseUrl: String(storedValue("localBaseUrl", "") || "http://127.0.0.1:8080/v1"),
                model: localModel,
                timeout: String(storedValue("localTimeoutSeconds", 15))
            });
        }
        const remoteModel = String(storedValue("remoteModel", "") || "").trim();
        if (remoteModel.length > 0) {
            list.push({
                name: "remote",
                baseUrl: String(storedValue("remoteBaseUrl", "") || ""),
                model: remoteModel,
                timeout: String(storedValue("remoteTimeoutSeconds", 120))
            });
        }
        if (list.length > 0)
            saveValue("providers", list);
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
        result.push({
            label: root.zh ? "跟随界面语言" : "Follow UI language",
            value: "auto"
        });
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
            text: "Dank Translate AI Enhanced"
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

    StyledText {
        width: parent.width
        text: root.zh ? "提供商" : "Providers"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.primary
    }

    StyledText {
        width: parent.width
        text: root.zh
            ? "按列表顺序依次尝试，前一个超时或报错时自动切换到下一个。超时单位：秒。Endpoint 固定为 /chat/completions。"
            : "Tried in order; when one times out or errors the next is used. Timeout in seconds. Endpoint is fixed to /chat/completions."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledText {
        width: parent.width
        text: root.zh ? "已配置的提供商" : "Configured providers"
        visible: root.providerList.length > 0
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    Column {
        width: parent.width
        spacing: Theme.spacingXS

        Repeater {
            model: root.providerList

            delegate: StyledRect {
                required property var modelData
                required property int index
                width: parent.width
                height: 60
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingM
                    anchors.right: providerButtons.left
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    StyledText {
                        width: parent.width
                        text: String(modelData.name || "")
                        elide: Text.ElideRight
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    StyledText {
                        width: parent.width
                        text: {
                            const base = String(modelData.baseUrl || "");
                            const model = String(modelData.model || "");
                            return model.length > 0 ? base + "  ·  " + model : base;
                        }
                        elide: Text.ElideMiddle
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                }

                Row {
                    id: providerButtons
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXS

                    DankButton {
                        text: root.zh ? "修改" : "Edit"
                        iconName: "edit"
                        onClicked: root.editProvider(index)
                    }

                    DankButton {
                        text: root.zh ? "删除" : "Delete"
                        iconName: "delete"
                        onClicked: root.deleteProvider(index)
                    }
                }
            }
        }
    }

    StyledRect {
        width: parent.width
        radius: Theme.cornerRadius
        color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
        height: formColumn.implicitHeight + Theme.spacingM * 2

        Column {
            id: formColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingXS

            StyledText {
                text: root.providerEditingIndex >= 0
                    ? (root.zh ? "修改提供商" : "Edit provider")
                    : (root.zh ? "添加提供商" : "Add provider")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            StyledText {
                text: root.zh ? "名称" : "Name"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            DankTextField {
                id: nameField
                width: parent.width
                placeholderText: root.zh ? "示例提供商1" : "provider-one"
            }

            StyledText {
                text: "Base URL"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            DankTextField {
                id: baseField
                width: parent.width
                placeholderText: "http://127.0.0.1:8080/v1"
            }

            StyledText {
                text: root.zh ? "API Key（可选）" : "API Key (optional)"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            DankTextField {
                id: keyField
                width: parent.width
                echoMode: TextInput.Password
                placeholderText: "sk-…"
            }

            StyledText {
                text: root.zh ? "模型（此提供商默认的）" : "Model (default for this provider)"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            Row {
                width: parent.width
                spacing: Theme.spacingS

                DankDropdown {
                    id: providerModelDropdown
                    width: Math.max(120, parent.width - syncButton.width - Theme.spacingS)
                    dropdownWidth: width
                    text: ""
                    description: ""
                    compactMode: true
                    currentValue: root.draftModel.length > 0
                        ? root.draftModel
                        : (root.zh ? "未选择（先同步）" : "None (sync first)")
                    options: root.providerModelChoices()
                    onValueChanged: value => {
                        if (!root.providerDropdownReady)
                            return;
                        root.draftModel = String(value || "");
                    }
                }

                DankButton {
                    id: syncButton
                    text: root.providerBusy ? "…" : (root.zh ? "同步" : "Sync")
                    iconName: "cloud_download"
                    onClicked: root.syncProviderModels()
                }
            }

            DankTextField {
                id: customModelField
                width: parent.width
                visible: root.draftModel === root.customModelLabel
                placeholderText: root.zh ? "输入自定义模型 ID（留空则保存同步到的全部模型）" : "Custom model ID (empty saves all synced models)"
            }

            StyledText {
                text: root.zh ? "超时（秒）" : "Timeout (seconds)"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            DankTextField {
                id: timeoutField
                width: parent.width
                placeholderText: "60"
            }

            StyledText {
                text: root.zh
                    ? "排序（越小越先用；与其他提供商冲突时，同序及之后的顺延一位）"
                    : "Order (lower is used first; on conflict the same order and below shift down one)"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                width: parent.width
                wrapMode: Text.WordWrap
            }

            DankTextField {
                id: sortField
                width: parent.width
                placeholderText: "1"
            }

            Row {
                spacing: Theme.spacingS

                DankButton {
                    text: root.providerEditingIndex >= 0
                        ? (root.zh ? "保存" : "Save")
                        : (root.zh ? "添加" : "Add")
                    iconName: root.providerEditingIndex >= 0 ? "check" : "add"
                    onClicked: root.saveProvider()
                }

                DankButton {
                    text: root.zh ? "取消" : "Cancel"
                    iconName: "close"
                    onClicked: root.resetProviderDraft()
                }
            }

            StyledText {
                width: parent.width
                text: root.providerStatus
                visible: root.providerStatus !== ""
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.primary
                wrapMode: Text.WordWrap
            }
        }
    }

    Loader {
        id: defaultTargetLoader
        width: parent.width
        // 等提供商列表就绪再创建：DankDropdown 内部索引在 options 为空时初始化，
        // 之后再补 options 也不会回填选中项，表现为“重启后默认模型显示为空”。
        active: root.providerList.length > 0
        sourceComponent: defaultTargetComponent
    }

    Component {
        id: defaultTargetComponent

        SelectionSetting {
            id: defaultTargetSetting
            settingKey: "defaultTarget"
            label: root.zh ? "默认模型" : "Default model"
            description: root.zh
                ? "翻译默认使用的提供商与模型；卡片上的临时切换不会改变这里。"
                : "Provider and model used by default; temporary switches on the card do not change it."
            options: root.defaultTargetOptions()
            defaultValue: root.storedValue("defaultTarget", "")
        }
    }

    ToggleSetting {
        settingKey: "streaming"
        label: root.zh ? "流式输出" : "Streaming"
        description: root.zh ? "可用时使用 SSE。" : "Uses SSE when available."
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "disableThinking"
        label: root.zh ? "禁用模型思考" : "Disable model thinking"
        description: root.zh
            ? "关闭思考模式，避免翻译时死循环；对 OpenAI 兼容后端发送 enable_thinking=false。"
            : "Turns thinking off to avoid translation loops; sends enable_thinking=false to OpenAI-compatible backends."
        defaultValue: true
    }


    StyledText {
        width: parent.width
        text: root.zh ? "翻译" : "Translation"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.primary
    }

    SelectionSetting {
        settingKey: "popupAnchor"
        label: root.zh ? "窗口位置" : "Popup position"
        description: root.zh ? "翻译浮窗出现的位置。" : "Where the translation card appears."
        options: [
            { label: root.zh ? "上方浮窗" : "Top overlay", value: "top" },
            { label: root.zh ? "下方浮窗" : "Bottom overlay", value: "bottom" },

        ]
        defaultValue: "top"
    }

    ToggleSetting {
        settingKey: "dismissOnClickOutside"
        label: root.zh ? "点击浮层外关闭" : "Close when clicking outside"
        description: root.zh
            ? "翻译浮窗失去焦点时自动关闭。"
            : "Close the card when it loses focus."
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "autoTranslate"
        label: root.zh ? "自动翻译选中/剪贴板文本" : "Translate selection/clipboard automatically"
        description: root.zh
            ? "关闭后只把捕获到的文本预填进卡片，点「翻译」或按 Ctrl+Enter 才发送。"
            : "When off, captured text is only prefilled — press translate or Ctrl+Enter to send."
        defaultValue: true
    }

    SelectionSetting {
        id: languageSetting
        settingKey: "targetLanguage"
        label: root.zh ? "目标语言" : "Target language"
        description: root.zh ? "替换 ${target_lang}。" : "Replaces ${target_lang}."
        options: root.languages
        defaultValue: "auto"
    }

    SelectionSetting {
        id: secondaryLanguageSetting
        settingKey: "secondaryLanguage"
        label: root.zh ? "副语言" : "Fallback language"
        description: root.zh
            ? "可选。默认提示词不引用它；需要在自定义提示词里写 ${secondary_lang} 才会生效。"
            : "Optional. The default prompt does not use it — reference ${secondary_lang} in a custom prompt."
        options: root.languages.filter(item => item.value !== "__custom__")
        defaultValue: "English"
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
        description: root.zh
            ? "可用变量：${target_lang}（目标语言）、${secondary_lang}（副语言）、${text}（原文）。支持 `system:` / `user:` 两段式，Ctrl+S 保存。"
            : "Variables: ${target_lang}, ${secondary_lang}, ${text}. Supports `system:` / `user:` sections. Ctrl+S saves."
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
