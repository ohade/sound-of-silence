# Sound of Silence

Push-to-talk voice input for your terminal. Press a hotkey, speak, and your words appear as text — transcribed locally by [whisper.cpp](https://github.com/ggml-org/whisper.cpp).

No cloud APIs required. All speech processing happens on your machine.

<!-- TODO: Add screenshot of the recording animation -->
<!-- ![Recording Animation](demo.png) -->

## How it works

```
Cmd+Shift+V → ⏺ Recording... 0:03 → ⏳ Transcribing... → text appears in terminal
```

1. Press **Cmd+Shift+V** to start recording — animated indicator appears in the status bar
2. Speak into your microphone
3. Press **Cmd+Shift+V** again to stop and transcribe
4. Transcribed text is typed into the active terminal pane
5. Press **ESC** at any time to cancel without transcribing

## Components

| Component | What it does |
|-----------|-------------|
| `bin/sound-of-silence` | CLI tool — start/stop recording, transcribe via whisper.cpp |
| `wezterm/sound-of-silence.lua` | WezTerm plugin — keybinding, animated recording indicator, ESC to cancel |

## Prerequisites

| Dependency | What it's for | Install |
|------------|---------------|---------|
| **macOS** | Uses `rec` (sox) for recording, `security` for keychain | — |
| **[Homebrew](https://brew.sh/)** | Package manager | `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` |
| **[sox](https://sox.sourceforge.net/)** | Provides the `rec` command for audio capture | `brew install sox` |
| **[jq](https://jqlang.github.io/jq/)** | Parse JSON responses from Whisper API | `brew install jq` |
| **[curl](https://curl.se/)** | Send audio to Whisper API for transcription | Pre-installed on macOS |
| **[WezTerm](https://wezfurlong.org/wezterm/)** | Terminal emulator with Lua plugin support | `brew install --cask wezterm` |
| **[whisper.cpp](https://github.com/ggml-org/whisper.cpp)** | Local speech-to-text engine (OpenAI-compatible API) | See [Setup whisper.cpp](#2-set-up-whispercpp) below |

### Optional

| Dependency | What it's for |
|------------|---------------|
| **OpenAI API key** | Fallback if local whisper.cpp isn't running (paid, cloud-based) |

## Installation

### 1. Install system dependencies

```bash
brew install sox jq
```

### 2. Set up whisper.cpp

You need a local whisper.cpp server running on port 2022. Two options:

#### Option A: Via VoiceMode (easiest)

[VoiceMode](https://github.com/mbailey/voicemode) handles downloading, building, and running whisper.cpp for you:

```bash
pip install voice-mode
voicemode whisper install    # Downloads whisper.cpp + model
voicemode whisper start      # Starts server on port 2022
```

To auto-start on login:

```bash
# VoiceMode creates a launchd plist at:
# ~/Library/LaunchAgents/com.voicemode.whisper.plist
launchctl load ~/Library/LaunchAgents/com.voicemode.whisper.plist
```

#### Option B: Build from source

```bash
git clone https://github.com/ggml-org/whisper.cpp.git
cd whisper.cpp
cmake -B build
cmake --build build --config Release

# Download a model (base recommended for speed/accuracy balance)
./models/download-ggml-model.sh base

# Start the server
./build/bin/whisper-server \
  --host 0.0.0.0 --port 2022 \
  --model models/ggml-base.bin \
  --threads 8
```

#### Verify whisper.cpp is running

```bash
curl -s http://localhost:2022/v1/models | jq .
# Should return model info JSON
```

### 3. Install Sound of Silence

```bash
git clone https://github.com/ohade/sound-of-silence.git
cd sound-of-silence

# Add CLI to PATH (pick one)
ln -s "$PWD/bin/sound-of-silence" ~/bin/sound-of-silence
# or
ln -s "$PWD/bin/sound-of-silence" ~/.local/bin/sound-of-silence
```

Verify:

```bash
sound-of-silence status
# Should print: idle
```

### 4. Add WezTerm integration

Add to the top of your `~/.wezterm.lua` (after `config_builder()`):

```lua
-- Sound of Silence: push-to-talk voice input
package.path = package.path .. ";" .. os.getenv("HOME") .. "/path/to/sound-of-silence/wezterm/?.lua"
local sos = require("sound-of-silence")
```

Then before `return config`:

```lua
sos.apply(config)
```

**Alternative:** symlink the Lua module instead of modifying `package.path`:

```bash
# WezTerm searches ~/.config/wezterm/ for Lua modules
mkdir -p ~/.config/wezterm
ln -s /path/to/sound-of-silence/wezterm/sound-of-silence.lua ~/.config/wezterm/sound-of-silence.lua
```

Then in `~/.wezterm.lua` (no `package.path` needed):

```lua
local sos = require("sound-of-silence")
sos.apply(config)
```

### 5. Test it

1. Open a new WezTerm window (config auto-reloads)
2. Press **Cmd+Shift+V** — you should see `⏺ Recording...` with a timer in the status bar
3. Say something
4. Press **Cmd+Shift+V** again — `⏳ Transcribing...` appears, then text is typed into the pane
5. Or press **ESC** to cancel

## CLI Usage

The CLI works standalone (without WezTerm) for scripting and automation:

```bash
sound-of-silence              # Toggle: start or stop+transcribe
sound-of-silence start        # Start recording
sound-of-silence stop         # Stop and transcribe (outputs text to stdout)
sound-of-silence cancel       # Cancel recording (no transcription)
sound-of-silence status       # Print "recording" or "idle"
```

### Use with other tools

```bash
# Pipe transcription to clipboard
sound-of-silence stop | pbcopy

# Use in scripts
sound-of-silence start
sleep 5
TEXT=$(sound-of-silence stop)
echo "You said: $TEXT"
```

## WezTerm Plugin Options

### Custom keybinding

```lua
-- Use Cmd+Shift+M instead of Cmd+Shift+V
sos.apply(config, { key = "m" })
```

### Custom script path

```lua
sos.apply(config, { script = "/custom/path/to/sound-of-silence" })
```

### Manual setup (for advanced configs)

If you already have custom keybindings or an `update-status` handler:

```lua
local sos = require("sound-of-silence")

-- Add keybindings to your existing keys table
sos.add_keybindings(config.keys)

-- In your update-status handler, guard against clearing the recording animation:
wezterm.on("update-status", function(window, pane)
  -- ... your existing logic ...

  -- Don't clear status bar during recording
  if not wezterm.GLOBAL.sos_recording then
    window:set_right_status("")
  end
end)
```

## Configuration

Environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `STT_BASE_URL` | auto-detect | Whisper API endpoint (tries `localhost:2022`, falls back to OpenAI) |
| `SOS_LANGUAGE` | `en` | Transcription language ([ISO 639-1](https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes)) |
| `SOS_MODEL` | `whisper-1` | Whisper model name |
| `SOS_REC_BIN` | auto-detect | Path to `rec` binary (from sox) |
| `SOS_PID_FILE` | `~/.sound-of-silence.pid` | PID file location |
| `SOS_WAV_FILE` | `/tmp/sound-of-silence.wav` | Temp audio file location |

## OpenAI API Fallback

If no local whisper.cpp server is detected on port 2022, the CLI automatically falls back to the [OpenAI Whisper API](https://platform.openai.com/docs/guides/speech-to-text) (requires a paid API key).

The API key is read from macOS Keychain — no environment variables or config files needed:

```bash
# Store your key once
security add-generic-password -a "$USER" -s "openai-api-key" -w "sk-your-key-here"
```

To force local-only mode (no fallback), set `STT_BASE_URL`:

```bash
export STT_BASE_URL=http://127.0.0.1:2022/v1
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `rec: command not found` | `brew install sox` |
| `Error: No local whisper.cpp and no OpenAI API key` | Start whisper.cpp server or add OpenAI key to Keychain |
| No sound captured | System Settings → Privacy → Microphone → grant terminal access |
| Whisper returns empty text | Check `curl http://localhost:2022/v1/models` — server may be down |
| WezTerm animation not showing | Ensure `sos.apply(config)` is called after `config.keys = { ... }` |
| ESC not canceling | Make sure no other keybinding overrides ESC after `sos.apply()` |

## How it works (architecture)

```
┌─────────────────────────────────────────────────┐
│  WezTerm                                        │
│  ┌───────────────────────────────────────────┐  │
│  │  Cmd+Shift+V pressed                      │  │
│  │  → sound-of-silence.lua callback           │  │
│  │  → runs: sound-of-silence start/stop       │  │
│  │  → shows animated ⏺ Recording... in bar   │  │
│  └───────────────────────────────────────────┘  │
└────────────────────┬────────────────────────────┘
                     │
        ┌────────────▼────────────┐
        │  sound-of-silence CLI   │
        │  (bash script)          │
        │                         │
        │  start → sox rec ───┐   │
        │  stop  → kill rec   │   │
        │         ↓           │   │
        │  POST audio ──────► │   │
        └────────┬────────────┘   │
                 │                │
    ┌────────────▼──────────┐    │
    │  whisper.cpp server   │    │
    │  localhost:2022       │    │
    │  (local, GPU accel)   │    │
    │                       │    │
    │  audio → text         │    │
    └───────────────────────┘    │
                                 │
        text pasted into ◄───────┘
        active terminal pane
```

## License

MIT
