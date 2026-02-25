-- sound-of-silence: WezTerm push-to-talk voice input integration
-- Adds Cmd+Shift+V to toggle recording, ESC to cancel, with animated status bar.
--
-- Usage: In your .wezterm.lua:
--
--   local sos = require("sound-of-silence")
--   sos.apply(config)                     -- adds keybindings + animation
--   sos.apply(config, { key = "m" })      -- custom trigger key (Cmd+Shift+M)
--
-- Or cherry-pick:
--   sos.add_keybindings(config.keys)      -- just the keybindings
--   sos.setup_animation()                 -- just the status bar animation hook
--
-- Requirements:
--   - sound-of-silence CLI in PATH (or ~/bin/sound-of-silence)
--   - sox (rec command) for audio capture
--   - Local whisper.cpp server on port 2022, or OpenAI API key in Keychain

local wezterm = require("wezterm")

local M = {}

-- Default options
local defaults = {
  key = "v",                    -- trigger key (with CMD+SHIFT)
  script = nil,                 -- auto-detect: checks PATH, then ~/bin/
  cancel_key = "Escape",        -- cancel recording key
}

-- Locate the sound-of-silence script
local function find_script(opts)
  if opts.script then return opts.script end
  local home = os.getenv("HOME") or ""
  -- Check common locations
  local candidates = {
    home .. "/bin/sound-of-silence",
    home .. "/.local/bin/sound-of-silence",
    "/usr/local/bin/sound-of-silence",
    "/opt/homebrew/bin/sound-of-silence",
  }
  for _, path in ipairs(candidates) do
    local f = io.open(path, "r")
    if f then
      f:close()
      return path
    end
  end
  -- Fallback: assume it's in PATH
  return "sound-of-silence"
end

-- Animated recording indicator in the status bar
local function start_voice_animation(window)
  if not wezterm.GLOBAL.sos_recording then
    window:set_right_status("")
    return
  end
  local elapsed = os.time() - (wezterm.GLOBAL.sos_start_time or os.time())
  local mins = math.floor(elapsed / 60)
  local secs = elapsed % 60
  local timer = string.format("%d:%02d", mins, secs)
  local tick = (wezterm.GLOBAL.sos_tick or 0) % 4
  local dots = ({ ".  ", ".. ", "...", "   " })[tick + 1]
  wezterm.GLOBAL.sos_tick = tick + 1
  window:set_right_status(wezterm.format({
    { Foreground = { Color = "#ff4444" } },
    { Text = " ⏺ " },
    { Foreground = { Color = "#e0e0e0" } },
    { Text = "Recording" .. dots .. " " },
    { Foreground = { Color = "#47FF9C" } },
    { Attribute = { Intensity = "Bold" } },
    { Text = timer .. " " },
  }))
  wezterm.time.call_after(0.5, function() start_voice_animation(window) end)
end

-- Check if currently recording (ground truth from PID file)
local function check_recording()
  local _, stdout, _ = wezterm.run_child_process({
    "/bin/bash", "-c",
    'f="$HOME/.sound-of-silence.pid"; [ -f "$f" ] && kill -0 "$(cat "$f")" 2>/dev/null && echo -n "1" || echo -n "0"'
  })
  return stdout == "1"
end

-- Sync WezTerm state with reality (survives config reloads)
local function sync_state(window)
  local actual = check_recording()
  if actual ~= (wezterm.GLOBAL.sos_recording or false) then
    wezterm.GLOBAL.sos_recording = actual
    if not actual then window:set_right_status("") end
  end
end

-- Create the toggle keybinding action
function M.make_toggle_action(opts)
  opts = opts or {}
  local script = find_script(opts)

  return wezterm.action_callback(function(window, pane)
    sync_state(window)

    if wezterm.GLOBAL.sos_recording then
      -- STOP: clear animation, show transcribing, get text
      wezterm.GLOBAL.sos_recording = false
      window:set_right_status(wezterm.format({
        { Foreground = { Color = "#FFE073" } },
        { Text = " ⏳ Transcribing... " },
      }))
      local success, stdout, stderr = wezterm.run_child_process({ script, "stop" })
      window:set_right_status("")
      if success and stdout and #stdout > 0 then
        pane:send_text(stdout)
      elseif stderr and #stderr > 0 then
        pane:send_text("# sound-of-silence error: " .. stderr .. "\n")
      end
    else
      -- START: run script, start animation
      local success, _, stderr = wezterm.run_child_process({ script, "start" })
      if success then
        wezterm.GLOBAL.sos_recording = true
        wezterm.GLOBAL.sos_start_time = os.time()
        wezterm.GLOBAL.sos_tick = 0
        start_voice_animation(window)
      else
        pane:send_text("# sound-of-silence error: " .. (stderr or "unknown") .. "\n")
      end
    end
  end)
end

-- Create the cancel keybinding action
function M.make_cancel_action(opts)
  opts = opts or {}
  local script = find_script(opts)

  return wezterm.action_callback(function(window, pane)
    if wezterm.GLOBAL.sos_recording then
      wezterm.GLOBAL.sos_recording = false
      wezterm.run_child_process({ script, "cancel" })
      window:set_right_status("")
    else
      -- Pass through ESC when not recording
      window:perform_action(wezterm.action.SendKey({ key = "Escape" }), pane)
    end
  end)
end

-- Add keybindings to an existing keys table
function M.add_keybindings(keys, opts)
  opts = opts or {}
  local key = opts.key or defaults.key
  local cancel_key = opts.cancel_key or defaults.cancel_key

  table.insert(keys, {
    key = key,
    mods = "CMD|SHIFT",
    action = M.make_toggle_action(opts),
  })

  table.insert(keys, {
    key = cancel_key,
    action = M.make_cancel_action(opts),
  })
end

-- Set up the status bar hook to clear status when not recording
function M.setup_status_hook()
  -- Hook into update-status to avoid overwriting animation
  local original_handler = wezterm.GLOBAL.sos_status_hooked
  if not original_handler then
    wezterm.GLOBAL.sos_status_hooked = true
    -- Note: if you have your own update-status handler, call sync_state(window)
    -- from it instead of using this hook.
  end
end

-- Apply everything to a config in one call
function M.apply(config, opts)
  opts = opts or {}
  if not config.keys then config.keys = {} end
  M.add_keybindings(config.keys, opts)
  M.setup_status_hook()
end

return M
