# home fork 改动（相对上游 v1.1.0）

上游：https://github.com/SakuraToErii/dank-translate-ai

## 1. 重试按钮
结果卡片底部新增 `refresh` 图标按钮（非 running 状态可见）。点击后用当前 `currentOriginal`
重新走一遍完整翻译流程（`startTranslation(currentOriginal)`），不用重新划词。
新增 IPC：`dms ipc call dankTranslateAI retry`。

## 2. 原文/译文对照
卡片在译文框上方新增原文框（`originalBox`）：灰色小字、最多 150px 高、可滚动。
原文为空或 `showOriginal=false` 时自动隐藏。`maxTranslationHeight` 已扣除原文框高度，
避免卡片超出屏幕一半。

## 3. 译文实时编辑
`edit` 按钮进入编辑态，`TextEdit` 就地替换只读文本：
- `Esc` 取消编辑；`Ctrl+Enter` 提交
- 提交后用新译文覆盖 `currentTranslation`，复制按钮复制的是编辑后的文本
- 同步更新历史里"同原文"的那条记录的 `translated` 字段
- Wayland 层壳 `keyboardFocus` 在编辑态切到 `OnDemand`，退出后恢复 `None`
  （否则 layer shell 拿不到键盘输入）


## 4. 提供商（providers）与卡片下拉

- 设置项 `providers` 是一个对象数组，字段：`name` / `baseUrl` / `model` / `timeout`（秒），endpoint 固定 `/chat/completions`。
  设置页用 DMS 自带的 `ListSettingWithInput` 渲染（可增删），密钥按名称存在 `providerKey_<name>`。
- **回退语义**：请求按数组顺序依次尝试，前一个超时或报错就切下一个（python 侧 `run()` 循环 + `fallback` 事件），全部失败才报错。
  `providerEntries()` 在 `providers` 为空时仍回落到旧的 `localModel` / `remoteModel` 两条，保证老配置能用。
- 卡片左下角是 `provider · model` 胶囊 + 语言胶囊，均为自实现下拉：卡片内展开、最多同时 5 行（`menuRowHeight` / `menuMaxRows`）、超出垂直滚动（`DankFlickable`）、文本 `elide: Text.ElideRight`。
  选中项写入 `providerOverride` + `modelOverride`，立即用该目标重译。
- 卡片下拉的每一项就是一个 `provider · model`（每个提供商一个默认模型）。同一服务要挂多个模型，就在提供商列表里加多条（同 Base URL、不同模型），它们的顺序即回退顺序。
- `modelChoices` 设置项已移除：它只对第一个提供商生效，语义与 `providers` 重复。
- **不要用 DMS 的 `DankDropdown`**：它内部走 `PopupWindow`，在 layer shell overlay 里弹不出菜单（`menuOpen=true` 也不渲染），且 `Repeater.visible` 无法隐藏 delegate。
- “获取模型列表”按钮调 `refreshModels`，`list_models.py` 从**环境变量** `DTAI_BASE_URL` / `DTAI_API_KEY` 读配置（不走 argv，避免密钥出现在 `ps`），取值来自第一个 provider。
- 新增 IPC：`refreshModels`、`models`、`translateWithModel <id>`、`openModelMenu`、`openLanguageMenu`、`editOriginal`、`cancelEdit`。
- 界面中英文案**跟随 DMS 全局语言**：读 `SessionData.locale`（`qs.Services`），空值时回退 `Qt.locale().name`，`zh*` 判为中文。插件设置里不再有独立的「界面语言」下拉。
- 注意：列表里会出现 `glm-ocr-f16` 这类非翻译模型（服务端 `/v1/models` 全量返回），选它会翻译失败，属预期。

## 5. 排错备忘

- Wayland 下 `keyboardFocus` 必须在弹窗可见时就是 `OnDemand`。在点击回调里才切会错过 compositor 的焦点授予时机，表现为“进了编辑态但打不了字”。
- `qmllint` 1.0 不支持 `?.` 可选链，对本项目所有 qml 都会返回 255 且无输出，不能作为语法验证手段；验证靠 `dms ipc call plugins reload` + 运行时无 TypeError。
- Quickshell `Process` 创建后必须显式 `proc.running = true`，否则永远不会执行。
- 改 `plugin_settings.json` **不会**刷新 DMS 内存里的 `pluginData`，`plugins reload` 只重载 QML；要让新配置生效必须 `systemctl --user restart dms.service`。
- 上游备份**不能**留在 `~/.config/DankMaterialShell/plugins/` 下（如 `dankTranslateAI.upstream/`）：DMS 会扫描该目录下所有含 `plugin.json` 的子目录，id 相同会冲突，设置页显示上游元数据。备份放在 `~/code/dank-translate-ai-upstream`。
- `plugins.lock.json` 里若留着本插件的上游 repo/commit，DMS 会把它当作 registry 安装的插件，`dms plugins update` 会把 fork 覆盖回原版。fork 化之后要删掉该条目。
- DMS 的 `SecureStringSetting` 只是输入掩码，密钥在 `plugin_settings.json` 里是**明文**，记得 `chmod 600`。

## 部署

DMS 官方插件开发流程是 symlink：

```
mv ~/.config/DankMaterialShell/plugins/dankTranslateAI ~/.config/DankMaterialShell/plugins/dankTranslateAI.upstream
ln -s ~/code/dank-translate-ai ~/.config/DankMaterialShell/plugins/dankTranslateAI
dms ipc call plugins reload dankTranslateAI
```

## 上游同步

```
git remote add upstream https://github.com/SakuraToErii/dank-translate-ai
git fetch upstream && git rebase upstream/main
```
