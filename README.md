# Dank Translate AI Enhanced

[English](README.md) | [简体中文](README.zh-CN.md)

An enhanced fork of [Dank Translate AI](https://github.com/SakuraToErii/dank-translate-ai) for DankMaterialShell 1.6+. Press one shortcut after selecting or copying text and the translation streams into a compact top-center card; DankBar keeps a persistent newest-first history.

![Translation result card](docs/translation-popup.png)

![DankBar translation history](docs/translation-history.png)

## What this fork adds

The upstream plugin talks to one local model and one remote API, shows a streaming card and keeps a history. This fork replaces that with a provider model, adds card-level controls and a configurable prompt:

**Providers and routing**

- A `providers` list instead of separate local/remote slots. Each entry has a name, base URL, model, model list, timeout and sort order.
- Sort order **is** the fallback priority: when a provider times out or fails, the next one is tried automatically.
- Per-provider API keys, stored as `providerKey_<name>`.
- A global default model (`provider · model`) that takes priority over each provider's own model — without dropping the remaining providers from the fallback chain.
- Thinking is disabled for every OpenAI-compatible backend (`chat_template_kwargs` + `reasoning_effort`), with a retry that strips those fields if a server rejects them.

**Prompt template**

- `${target_lang}`, `${secondary_lang}` and `${text}` placeholders.
- `system:` / `user:` sections; a prompt without those prefixes is still treated as a system-only prompt.
- An optional `${secondary_lang}` variable. The default prompt does not reference it — add the rule yourself if you want a fallback language.

**Result card**

- Retry, copy, close, and stop while streaming.
- Source and translation shown together; the source is editable — click it, edit, then confirm (✓) or cancel (✗), `Ctrl+Enter` re-translates.
- Manual input when there is no source text: a one-row box that grows with the content up to 160 px and then scrolls. Reachable from the history popup's `+`, from a shortcut press with nothing to translate, or from the card itself.
- Self-made dropdowns for model and target language, fixed to a 5-row window with vertical scrolling — DMS's own `DankDropdown` cannot render inside a layer-shell surface.
- Long translations scroll inside the card, and the scroll position resets on every new translation.

**Settings page**

- Provider editor with name, base URL, masked API key, model (plus a sync button that pulls `/v1/models` into a dropdown with a Custom entry), timeout and sort order.
- Sort conflicts shift the conflicting and following providers down one slot.
- Configured providers are listed above the form as `name` over `baseUrl · model`, with edit and delete actions.
- Default model selector built from every `provider · model` pair.

**History popup**

- `+` opens a new translation, clear sits to its right.
- Empty state offers a "type text to translate" button instead of an instruction line.
- Target language is rendered through the language table, so it follows the DMS locale.

## Install

DankMaterialShell scans `~/.config/DankMaterialShell/plugins/<id>/` and expects the plugin `id` to stay `dankTranslateAI`. Installing from a git checkout with a symlink keeps `git pull` / `git merge` working:

```bash
git clone https://github.com/LilFishyChan/dank-translate-ai-enhanced.git ~/code/dank-translate-ai
ln -s ~/code/dank-translate-ai ~/.config/DankMaterialShell/plugins/dankTranslateAI
```

Or copy it in place:

```bash
cp -a dank-translate-ai ~/.config/DankMaterialShell/plugins/dankTranslateAI
```

Then:

1. Scan and enable **Dank Translate AI Enhanced** in DMS Settings → Plugins.
2. Open the plugin settings, add at least one provider (name, base URL, model), or press Sync to load the model list from `/v1/models`.
3. Pick a default model, a target language and optionally a fallback language.
4. Add the plugin to a DankBar section.
5. Click the keyboard icon under Shortcut and press a key combination. `Esc` cancels recording.

Requirements: DankMaterialShell 1.6+, `uv`, and `wl-paste` from `wl-clipboard`.

## Prompt template

The default prompt is deliberately unconditional:

```text
system: Translate the text provided by the user into ${target_lang}. Preserve the original meaning, tone, paragraph structure, Markdown formatting, code, names, and numbers. Output only the translation.
user: ${text}
```

- `${target_lang}` — the language picked in settings.
- `${secondary_lang}` — the fallback language from settings. The default prompt does not reference it.
- `${text}` — the source text.

Conditional rules are left to the user. Some local models ignore them and translate into the target language anyway, so the default keeps a single target and stays accurate across models. When you want a fallback language, write it into the prompt yourself, for example:

```text
- If the text's dominant language is ${target_lang}, translate it into ${secondary_lang} instead.
```

The adapter does not detect languages itself; whatever the prompt says is what the model gets.

## Providers

Requests go to any OpenAI-compatible `/chat/completions` endpoint.

```text
Name:      provider-one
Base URL:  http://127.0.0.1:8080/v1
Model:     model-one
Timeout:   60
Sort:      1
```

The model field accepts a synced entry or a custom model ID. Sync fills the dropdown with everything the server reports; leaving the custom field empty saves the whole synced list and uses its first entry as the provider default.

Keys are stored in `~/.config/DankMaterialShell/plugin_settings.json` as `providerKey_<name>`. DMS only masks them in the UI — the file is plain text, so keep its permissions at `600`.

## Input and security model

Unchanged from upstream:

- A shortcut press reads either a clipboard entry copied within the last 60 seconds or a primary selection changed within the last 15 seconds.
- Clipboard text is screened locally for password-manager hints, credentials, private keys, tokens and high-entropy strings before anything is sent.
- Plain-text MIME only, no files or URIs, 100,000-character limit.
- When there is nothing to translate, the card opens with the manual input box instead of an error.
- API keys reach the helper through the environment / stdin, never through process arguments.

## Shortcut and IPC

The settings page records this action:

```bash
dms ipc call dankTranslateAI translateSelection
```

Niri example:

```kdl
Mod+Alt+T repeat=false hotkey-overlay-title="Translate selection or copy" {
    spawn "dms" "ipc" "call" "dankTranslateAI" "translateSelection";
}
```

Other actions:

```bash
dms ipc call dankTranslateAI translateClipboard          # translate a recent copy
dms ipc call dankTranslateAI translateText "Hello!"      # translate caller-supplied text
dms ipc call dankTranslateAI retry                       # retry the last request
dms ipc call dankTranslateAI status                      # JSON state snapshot
dms ipc call dankTranslateAI models                      # available provider · model targets
dms ipc call dankTranslateAI refreshModels               # pull /v1/models from every provider
dms ipc call dankTranslateAI translateToLanguage "Japanese"
dms ipc call dankTranslateAI show
dms ipc call dankTranslateAI close
dms ipc call dankTranslateAI cancel
dms ipc call dankTranslateAI clearHistory
```

## Development

```bash
uv run --offline --frozen python -m unittest discover -v
```

Notes collected while working on this fork:

- `qmllint` (1.0) rejects every file in this plugin and prints nothing useful — verify changes with `dms ipc call plugins reload dankTranslateAI` plus `journalctl --user -u dms.service`.
- Editing `plugin_settings.json` by hand needs `systemctl --user restart dms.service`; `plugins reload` only reloads QML and does not reread settings.
- Shared `.js` files and sibling QML types do not resolve inside a symlinked plugin directory — keep helpers inline or as Python.

## Upstream

```bash
git remote add upstream https://github.com/SakuraToErii/dank-translate-ai.git   # once
git fetch upstream && git merge upstream/master
```

The upstream history is preserved in this repository, so merges stay straightforward. The fork's own work is squashed into a single commit on top of the upstream baseline.

## License

MIT
