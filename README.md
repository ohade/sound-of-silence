# Sound of Silence

Push-to-talk voice input for your terminal. Press a hotkey, speak, and your words appear as text — transcribed locally by [whisper.cpp](https://github.com/ggml-org/whisper.cpp).

No cloud APIs required. All speech processing happens on your machine.

## How it works

```
Cmd+Shift+V → 🎙️ Recording... 0:03 → ⏳ Transcribing... → text appears in terminal
```

1. Press **Cmd+Shift+V** to start recording
2. Speak
3. Press **Cmd+Shift+V** again to stop and transcribe
4. Transcribed text is pasted into the active terminal pane
5. Press **ESC** to cancel without transcribing

## Components

| Component | What it does |
|-----------|-------------|
| `bin/sound-of-silence` | CLI tool: toggle recording, transcribe via whisper.cpp |
| `wezterm/sound-of-silence.lua` | WezTerm plugin: keybinding + animated recording indicator |

## Requirements

- **macOS** (uses `rec` from sox for recording, `security` for keychain access)
- **[sox](https://sox.sourceforge.net/)** — `brew install sox`
- **[whisper.cpp](https://github.com/ggml-org/whisper.cpp)** server running on port 2022 (or OpenAI API key as fallback)
- **[WezTerm](https://wezfurlong.org/wezterm/)** (for the terminal integration)

## Installation

### 1. Install the CLI

```bash
# Clone
git clone https://github.com/ohade/sound-of-silence.git
cd sound-of-silence

# Add to PATH (pick one)
ln -s "$PWD/bin/sound-of-silence" ~/bin/sound-of-silence
# or
ln -s "$PWD/bin/sound-of-silence" ~/.local/bin/sound-of-silence
```

### 2. Set up whisper.cpp

The easiest way is via [VoiceMode](https://github.com/mbailey/voicemode):

```bash
pip install voice-mode
voicemode whisper install
voicemode whisper start
```

Or build whisper.cpp manually and run the server:

```bash
# See https://github.com/ggml-org/whisper.cpp for build instructions
whisper-server --host 0.0.0.0 --port 2022 --model models/ggml-base.bin
```

### 3. Add WezTerm integration

Copy or symlink the plugin:

```bash
# Create WezTerm plugin directory if needed
mkdir -p ~/.config/wezterm

# Symlink the plugin
ln -s /path/to/sound-of-silence/wezterm/sound-of-silence.lua ~/.config/wezterm/sound-of-silence.lua
```

Add to your `~/.wezterm.lua`:

```lua
local sos = require("sound-of-silence")
sos.apply(config)
```

That's it. **Cmd+Shift+V** to toggle recording, **ESC** to cancel.

#### Custom keybinding

```lua
sos.apply(config, { key = "m" })  -- Cmd+Shift+M instead
```

#### Manual setup (if you want more control)

```lua
local sos = require("sound-of-silence")

-- Add just the keybindings to your existing keys table
sos.add_keybindings(config.keys)

-- In your update-status handler, clear status when not recording:
-- if not wezterm.GLOBAL.sos_recording then window:set_right_status("") end
```

## CLI Usage

```bash
sound-of-silence              # Toggle: start or stop+transcribe
sound-of-silence start        # Start recording
sound-of-silence stop         # Stop and transcribe
sound-of-silence cancel       # Cancel recording
sound-of-silence status       # Print "recording" or "idle"
```

## Configuration

Environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `STT_BASE_URL` | auto-detect | Whisper API endpoint (local:2022 or OpenAI) |
| `SOS_LANGUAGE` | `en` | Transcription language |
| `SOS_MODEL` | `whisper-1` | Whisper model name |
| `SOS_REC_BIN` | auto-detect | Path to `rec` binary (from sox) |
| `SOS_PID_FILE` | `~/.sound-of-silence.pid` | PID file location |
| `SOS_WAV_FILE` | `/tmp/sound-of-silence.wav` | Temp audio file location |

## Fallback to OpenAI

If no local whisper.cpp server is detected, the CLI falls back to the OpenAI Whisper API. It reads the API key from macOS Keychain:

```bash
# Store your key (one-time)
security add-generic-password -a "$USER" -s "openai-api-key" -w "sk-..."
```

## License

MIT
