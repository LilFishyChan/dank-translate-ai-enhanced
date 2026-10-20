import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    layerNamespacePlugin: "dank-translate-ai-history"
    readonly property var historyEntries: Array.isArray(globalHistory.value) ? globalHistory.value : []
    readonly property bool translating: globalStatus.value === "running"
    readonly property bool uiZh: {
        const raw = String(SessionData.locale || Qt.locale().name || "");
        return raw.toLowerCase().indexOf("zh") === 0;
    }
    readonly property real pillPadding: (barConfig?.removeWidgetPadding ?? false)
        ? 0
        : Theme.snap((barConfig?.widgetPadding ?? 12) * (widgetThickness / 30),
                     parentScreen ? CompositorService.getScreenScale(parentScreen) : 1)

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

    function languageLabel(value) {
        for (let i = 0; i < languageChoices.length; i++) {
            if (String(languageChoices[i].value) === String(value))
                return String(languageChoices[i].label);
        }
        return String(value || "");
    }

    PluginGlobalVar {
        id: globalClipboardWriteAt
        varName: "clipboardWriteAt"
        defaultValue: 0
    }

    function formatTime(timestamp) {
        const date = new Date(Number(timestamp || 0));
        return Qt.formatDateTime(date, "yyyy-MM-dd  HH:mm:ss");
    }

    function copyText(text, label) {
        const content = String(text || "");
        if (!content)
            return;
        globalClipboardWriteAt.set(Date.now());
        Quickshell.execDetached(["dms", "cl", "copy", content]);
        ToastService.showInfo(label || t("Copied", "已复制"));
    }

    function openTranslate() {
        Quickshell.execDetached(["dms", "ipc", "call", "dankTranslateAI", "show"]);
    }

    function clearHistory() {
        globalHistory.set([]);
        if (pluginService)
            pluginService.savePluginState(pluginId, "history", []);
        ToastService.showInfo(t("History cleared", "历史已清空"));
    }

    function removeHistory(entryId) {
        const filtered = historyEntries.filter(entry => String(entry.id) !== String(entryId));
        globalHistory.set(filtered);
        if (pluginService)
            pluginService.savePluginState(pluginId, "history", filtered);
    }

    horizontalBarPill: Component {
        Item {
            implicitWidth: barIcon.width
            implicitHeight: Math.max(0, root.widgetThickness - root.pillPadding * 2)
            width: implicitWidth
            height: implicitHeight

            DankIcon {
                id: barIcon
                anchors.centerIn: parent
                name: root.translating ? "progress_activity" : "translate"
                size: root.iconSize
                color: root.translating ? Theme.primary : Theme.surfaceText
                rotation: 0
            }
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: verticalIcon.width
            implicitHeight: Math.max(0, root.widgetThickness - root.pillPadding * 2)
            width: implicitWidth
            height: implicitHeight

            DankIcon {
                id: verticalIcon
                anchors.centerIn: parent
                name: root.translating ? "progress_activity" : "translate"
                size: root.iconSize
                color: root.translating ? Theme.primary : Theme.surfaceText
                rotation: 0
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: historyPopout
            headerText: root.t("History", "翻译历史")
            detailsText: root.uiZh
                ? root.historyEntries.length + " 条 · 最新优先"
                : root.historyEntries.length + " · newest first"
            showCloseButton: true

            headerActions: Component {
                Row {
                    spacing: Theme.spacingXS

                    DankActionButton {
                        iconName: "add"
                        iconColor: Theme.surfaceText
                        tooltipText: root.t("New translation", "新建翻译")
                        onClicked: root.openTranslate()
                    }

                    DankActionButton {
                        visible: root.historyEntries.length > 0
                        iconName: "delete_sweep"
                        iconColor: Theme.surfaceText
                        tooltipText: root.t("Clear", "清空")
                        onClicked: root.clearHistory()
                    }
                }
            }

            Item {
                width: parent.width
                implicitHeight: root.popoutHeight
                    - historyPopout.headerHeight
                    - historyPopout.detailsHeight
                    - Theme.spacingXL

                Column {
                    anchors.centerIn: parent
                    visible: root.historyEntries.length === 0
                    spacing: Theme.spacingM

                    DankIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: "translate"
                        size: 28
                        color: Theme.surfaceVariantText
                    }

                    StyledText {
                        text: root.t("No history yet", "暂无历史")
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeMedium
                        horizontalAlignment: Text.AlignHCenter
                    }

                    DankButton {
                        text: root.t("Type text to translate", "手动输入翻译")
                        iconName: "edit"
                        onClicked: root.openTranslate()
                    }
                }

                DankListView {
                    id: historyList
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingS
                    anchors.rightMargin: Theme.spacingS
                    visible: root.historyEntries.length > 0
                    clip: true
                    spacing: Theme.spacingS
                    model: root.historyEntries

                    delegate: StyledRect {
                        id: entryCard
                        required property var modelData

                        width: historyList.width
                        height: entryColumn.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: entryMouse.containsMouse
                            ? Theme.surfaceContainerHighest
                            : Theme.surfaceContainerHigh
                        border.width: 1
                        border.color: Theme.outlineMedium

                        MouseArea {
                            id: entryMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.copyText(entryCard.modelData.translated, root.t("Copied", "已复制"))
                        }

                        Column {
                            id: entryColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingS

                            Item {
                                width: parent.width
                                height: Math.max(timeText.implicitHeight, actionRow.implicitHeight)

                                StyledText {
                                    id: timeText
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.formatTime(entryCard.modelData.createdAt)
                                        + "  ·  "
                                        + root.languageLabel(entryCard.modelData.language)
                                    color: Theme.surfaceVariantText
                                    font.pixelSize: Theme.fontSizeSmall
                                    elide: Text.ElideRight
                                    width: Math.max(0, parent.width - actionRow.width - Theme.spacingS)
                                }

                                Row {
                                    id: actionRow
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    z: 2

                                    DankActionButton {
                                        buttonSize: 30
                                        iconSize: Theme.iconSizeSmall
                                        iconName: "content_copy"
                                        tooltipText: root.t("Copy source", "复制原文")
                                        onClicked: root.copyText(entryCard.modelData.original, root.t("Source copied", "原文已复制"))
                                    }

                                    DankActionButton {
                                        buttonSize: 30
                                        iconSize: Theme.iconSizeSmall
                                        iconName: "delete"
                                        tooltipText: root.t("Delete", "删除")
                                        onClicked: root.removeHistory(entryCard.modelData.id)
                                    }
                                }
                            }

                            StyledText {
                                width: parent.width
                                text: String(entryCard.modelData.original || "")
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeSmall
                                wrapMode: Text.WordWrap
                                textFormat: Text.PlainText
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: Theme.outlineMedium
                            }

                            StyledText {
                                width: parent.width
                                text: String(entryCard.modelData.translated || "")
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                wrapMode: Text.WordWrap
                                textFormat: Text.PlainText
                                maximumLineCount: 5
                                elide: Text.ElideRight
                            }

                            StyledText {
                                width: parent.width
                                visible: String(entryCard.modelData.model || "").length > 0
                                    || String(entryCard.modelData.provider || "").length > 0
                                text: {
                                    const provider = String(entryCard.modelData.provider || "");
                                    const model = String(entryCard.modelData.model || "");
                                    return provider && model ? provider + "  ·  " + model : (provider || model);
                                }
                                color: Theme.outlineButton
                                opacity: 0.68
                                font.pixelSize: Theme.fontSizeSmall
                                elide: Text.ElideMiddle
                            }
                        }
                    }
                }
            }
        }
    }

    popoutWidth: 540
    popoutHeight: 580
}
