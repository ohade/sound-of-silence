#!/usr/bin/env bash
# Sound of Silence — installer
# Installs dependencies, symlinks CLI to PATH, and sets up WezTerm integration.
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

SOS_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${HOME}/bin"

info()  { printf "${GREEN}[ok]${RESET}  %s\n" "$*"; }
warn()  { printf "${YELLOW}[!!]${RESET}  %s\n" "$*"; }
fail()  { printf "${RED}[err]${RESET} %s\n" "$*"; }
step()  { printf "\n${BOLD}==> %s${RESET}\n" "$*"; }

# ── 1. Check macOS ──────────────────────────────────────────────────
if [[ "$(uname)" != "Darwin" ]]; then
  fail "macOS required (uses sox rec, macOS Keychain). Exiting."
  exit 1
fi

# ── 2. Check Homebrew ───────────────────────────────────────────────
step "Checking Homebrew"
if command -v brew &>/dev/null; then
  info "Homebrew found"
else
  fail "Homebrew not found. Install it first: https://brew.sh"
  exit 1
fi

# ── 3. Install sox + jq ────────────────────────────────────────────
step "Checking system dependencies"

install_if_missing() {
  local cmd="$1" pkg="${2:-$1}"
  if command -v "$cmd" &>/dev/null; then
    info "$pkg already installed"
  else
    printf "     Installing %s..." "$pkg"
    brew install "$pkg" >/dev/null 2>&1
    info "$pkg installed"
  fi
}

install_if_missing rec sox
install_if_missing jq

# ── 4. Symlink CLI to PATH ─────────────────────────────────────────
step "Setting up CLI"

mkdir -p "$BIN_DIR"
if [[ -L "${BIN_DIR}/sound-of-silence" ]] && \
   [[ "$(readlink "${BIN_DIR}/sound-of-silence")" == "${SOS_DIR}/bin/sound-of-silence" ]]; then
  info "CLI already linked at ${BIN_DIR}/sound-of-silence"
elif [[ -e "${BIN_DIR}/sound-of-silence" ]]; then
  warn "${BIN_DIR}/sound-of-silence already exists (not our symlink) — skipping"
  warn "Remove it manually if you want the installer to manage it"
else
  ln -s "${SOS_DIR}/bin/sound-of-silence" "${BIN_DIR}/sound-of-silence"
  info "CLI linked: ${BIN_DIR}/sound-of-silence → bin/sound-of-silence"
fi

# Verify CLI is on PATH
if command -v sound-of-silence &>/dev/null; then
  info "CLI is on PATH"
else
  warn "${BIN_DIR} is not in your PATH. Add it:"
  warn '  export PATH="$HOME/bin:$PATH"  # add to ~/.zshrc or ~/.bashrc'
fi

# ── 5. WezTerm integration ─────────────────────────────────────────
step "Setting up WezTerm integration"

WEZTERM_LUA="${SOS_DIR}/wezterm/sound-of-silence.lua"
WEZTERM_CONFIG_DIR="${HOME}/.config/wezterm"
WEZTERM_LINK="${WEZTERM_CONFIG_DIR}/sound-of-silence.lua"

if [[ -L "$WEZTERM_LINK" ]] && \
   [[ "$(readlink "$WEZTERM_LINK")" == "$WEZTERM_LUA" ]]; then
  info "WezTerm module already linked"
elif [[ -e "$WEZTERM_LINK" ]]; then
  warn "${WEZTERM_LINK} already exists — skipping"
else
  mkdir -p "$WEZTERM_CONFIG_DIR"
  ln -s "$WEZTERM_LUA" "$WEZTERM_LINK"
  info "WezTerm module linked: ${WEZTERM_LINK}"
fi

# Check if .wezterm.lua already requires sound-of-silence
WEZTERM_RC="${HOME}/.wezterm.lua"
if [[ -f "$WEZTERM_RC" ]] && grep -q 'sound-of-silence' "$WEZTERM_RC"; then
  info "WezTerm config already references sound-of-silence"
else
  warn "Add these lines to your ~/.wezterm.lua:"
  echo ""
  printf "  ${BOLD}local sos = require(\"sound-of-silence\")${RESET}\n"
  printf "  ${BOLD}sos.apply(config)${RESET}  -- before 'return config'\n"
  echo ""
fi

# ── 6. Check whisper.cpp ───────────────────────────────────────────
step "Checking speech-to-text backend"

if curl -s --connect-timeout 1 http://127.0.0.1:2022/v1/models >/dev/null 2>&1; then
  info "whisper.cpp server is running on port 2022"
else
  warn "No whisper.cpp server detected on port 2022"
  echo ""
  echo "  Option A — via VoiceMode (easiest):"
  echo "    pip install voice-mode"
  echo "    voicemode whisper install"
  echo "    voicemode whisper start"
  echo ""
  echo "  Option B — build from source:"
  echo "    See https://github.com/ggml-org/whisper.cpp"
  echo ""
  echo "  Or use OpenAI API as fallback:"
  echo "    security add-generic-password -a \"\$USER\" -s \"openai-api-key\" -w \"sk-your-key\""
  echo ""
fi

# ── Done ────────────────────────────────────────────────────────────
step "Done!"
echo ""
echo "  Quick test:"
echo "    1. Open a new WezTerm window"
echo "    2. Press Cmd+Shift+V to start recording"
echo "    3. Speak, then press Cmd+Shift+V again"
echo "    4. Press ESC at any time to cancel"
echo ""
