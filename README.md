# Dank Translate AI

[English](README.md) | [简体中文](README.zh-CN.md)

A security-focused DankMaterialShell 1.5+ translation plugin. Press one shortcut after selecting or copying text; translation streams into a compact top-center card, while DankBar keeps a persistent newest-first history.

![Selection translation overlay](docs/translation-popup.png)

![DankBar translation history](docs/translation-history.png)

## Highlights

- One-shot text capture: source text enters QML and the API pipeline after the shortcut is pressed
- A lightweight `wl-paste --watch` process records primary-selection change times
- Text copied within the last 60 seconds takes priority; older clipboard content is treated as empty
- A primary selection changed within the last 15 seconds is eligible for translation
- Repeated shortcuts are coalesced, and exact duplicate history entries are stored once
- Local best-effort secret screening before clipboard text reaches an API
- Plain-text MIME allowlist, file/URI rejection, and a 100,000-character limit
- Any OpenAI-compatible cloud API or local model server
- Custom API Key, Base URL, endpoint, model ID, prompt, and target language
- IPv4 transport for every HTTP(S) API, with SSE streaming and complete JSON response support
- Compact persistent result card with scrolling and stop, close, and copy actions
- Newest-first DankBar history with copy, delete, and clear actions
- English/Chinese settings and direct shortcut recording with conflict detection

## Why another translation plugin?

The three plugins serve different workflows. [DankTranslate](https://github.com/alcxyz/DankTranslate) is a fast launcher command powered by `translate-shell`. [Glance Translate](https://github.com/ChaoXu1997/glance) is an editable side-by-side bar popout powered by `translate-shell`. Dank Translate AI focuses on secure, shortcut-driven AI translation, streaming output, provider-independent API configuration, and persistent translation history.

| Area | DankTranslate | Glance Translate | Dank Translate AI |
|---|---|---|---|
| Main workflow | Type into DMS Launcher with a trigger | Open a DankBar popout for the primary selection or manual editing | Select or recently copy text, then press one shortcut |
| Backend | `translate-shell` | `translate-shell` with engine fallback | Any OpenAI-compatible cloud or local model |
| Output | Launcher result | Side-by-side source and result | Streaming top-center result card |
| Configuration | Default target and language-code prefix | Engine and target language | API Key, Base URL, endpoint, model, prompt, streaming, timeout, and broad target list |
| Saved results | Select a result to copy it | Source/result copy buttons | Persistent newest-first translation history in DankBar |
| Input handling | Explicit launcher text | Primary selection read when the popout opens | One-shot freshness check, MIME filtering, file rejection, 100k limit, and local clipboard secret screening |

This scope gives reviewers a clear distinction: AI and local-model support, streaming near the source context, a translation-history widget, and a privacy-oriented one-shot input pipeline.

## Input and security model

`translateSelection` performs this sequence when invoked:

1. Query one local DMS clipboard metadata entry.
2. Prefer plain text copied during the last 60 seconds.
3. Check the change timestamp maintained by the primary-selection watcher.
4. Read the current Wayland primary selection when it changed during the last 15 seconds.
5. Show “Select or copy text first” when both sources are stale or empty.

This supports text copied from DMS Clipboard History and apps that place selected text on the regular clipboard. The resident watcher sends change markers to QML; source text is captured for translation after the shortcut. The metadata query, MIME checks, size checks, and secret scan stay local. Only the chosen source text enters the configured translation request.

Clipboard screening recognizes password-manager MIME hints, credential labels, private keys, authorization headers, JWTs, common provider key formats, credential-bearing connection URLs, PIN-like values, hashes, and high-entropy mixed strings. Detection is intentionally conservative and remains a best-effort safety layer. The API Key is passed to the short-lived adapter through standard input and stays out of process arguments.

Copies made by the plugin carry a short local marker, so the next shortcut avoids selecting the plugin's own output as a fresh input.

Shortcut presses within 250 ms are coalesced. A new DMS clipboard entry or a primary-selection change within the freshness window starts a request. Copying identical text again still counts as a new copy. Exact duplicate completed translations occupy one history entry.

## Runtime and resource use

The plugin contains `pyproject.toml` and `uv.lock`. QML runs the standard-library adapter directly from the plugin directory:

```bash
uv run --project /path/to/dankTranslateAI --offline --frozen /path/to/dankTranslateAI/translate_stream.py
```

Each input capture and translation uses a short-lived process. Completion, cancellation, and timeout release HTTP responses, pipes, and child processes. A lightweight resident `wl-paste` watcher tracks primary-selection freshness. The Python adapter runs only during a translation and parses streaming responses line by line.

The standard-library HTTP adapter resolves every cloud and local HTTP(S) API connection through IPv4. SSE response chunks continue directly into the result card. DeepSeek requests can disable thinking mode through the low-latency setting to reduce time to first token.

Requirements:

- DankMaterialShell 1.5+
- `uv`
- `wl-paste` from `wl-clipboard`

The workflow supports any Wayland compositor supported by DMS. Registry metadata uses `"compositors": ["any"]` and `"distro": ["any"]`. Direct shortcut recording supports Niri, Hyprland, and MangoWC through the DMS keybind service; other compositors can use the IPC command below.

## Install

```bash
cp -a dank-translate-ai ~/.config/DankMaterialShell/plugins/dankTranslateAI
```

Then:

1. Scan and enable **Dank Translate AI** in DMS Settings → Plugins.
2. Enter the API settings and target language.
3. Add the plugin to a DankBar section.
4. Click the keyboard icon under Shortcut and press a key combination. `Esc` cancels recording.

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

Other IPC actions:

```bash
# Require a regular text copy from the last 60 seconds
dms ipc call dankTranslateAI translateClipboard

# Translate caller-supplied text
dms ipc call dankTranslateAI translateText "Hello, world!"

dms ipc call dankTranslateAI show
dms ipc call dankTranslateAI close
dms ipc call dankTranslateAI cancel
dms ipc call dankTranslateAI clearHistory
dms ipc call dankTranslateAI addToBar right
dms ipc call dankTranslateAI removeFromBar right
```

## API configuration

The plugin sends OpenAI Chat Completions requests. Provider presets stay out of the UI; enter the values exposed by the chosen cloud API or local server.

Default local example:

```text
Base URL: http://127.0.0.1:8080/v1
Endpoint: /chat/completions
Model: tencent/Hy-MT2-1.8B-GGUF
```

DeepSeek example:

```text
Base URL: https://api.deepseek.com
Endpoint: /chat/completions
Model: deepseek-v4-flash
```

The default prompt uses `${target_lang}`. Settings include common languages covering most regions plus a custom target field.

## Development

```bash
.venv/bin/python -m unittest discover -v
python -m json.tool plugin.json >/dev/null
```

## License

MIT
