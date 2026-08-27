-- WezTerm configuration for devmacs.
--
-- The terminal is the one part a container cannot reproduce, and it decides
-- half of the experience, so it is pinned to a single emulator whose config
-- can be shared between macOS and Windows.
--
-- Install to:
--   macOS / Linux  ~/.config/wezterm/wezterm.lua
--   Windows        %USERPROFILE%\.wezterm.lua

local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- Cmd is held by the terminal and never reaches Emacs, which is what leaves
-- Ctrl and Meta as the only modifiers on both platforms. For that to work,
-- Option/Alt has to arrive as Meta rather than as a composed character.
config.send_composed_key_when_left_alt_is_pressed = false
config.send_composed_key_when_right_alt_is_pressed = false

-- Deliberately not "wezterm". Emacs has no term/wezterm.el, so that value
-- would skip term/xterm.el, and without it modifyOtherKeys stays off and keys
-- like C-; and C-. never make it through. A nox Emacs uses nothing
-- wezterm-specific, and 24-bit colour arrives via COLORTERM anyway.
config.term = 'xterm-256color'

config.font = wezterm.font_with_fallback {
  'JetBrains Mono',
  'Cascadia Code',
  'Menlo',
  'Noto Sans Mono CJK JP',
  'Hiragino Sans',
  'Yu Gothic',
}
config.font_size = 13.0
config.line_height = 1.1

config.color_scheme = 'Tokyo Night'
config.window_background_opacity = 1.0
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = 'RESIZE'
config.window_padding = { left = 4, right = 4, top = 4, bottom = 4 }

-- Emacs owns the whole screen, so terminal-side scrollback is wasted memory.
config.scrollback_lines = 1000

config.default_cursor_style = 'SteadyBlock'
config.audible_bell = 'Disabled'

config.keys = {
  -- Copying out of Emacs already reaches the host clipboard over OSC 52;
  -- these are for pasting back in and for copying terminal output.
  { key = 'c', mods = 'SUPER', action = wezterm.action.CopyTo 'Clipboard' },
  { key = 'v', mods = 'SUPER', action = wezterm.action.PasteFrom 'Clipboard' },
  { key = 'c', mods = 'CTRL|SHIFT', action = wezterm.action.CopyTo 'Clipboard' },
  { key = 'v', mods = 'CTRL|SHIFT', action = wezterm.action.PasteFrom 'Clipboard' },

  -- Emacs needs these, so the terminal must not claim them.
  { key = 'n', mods = 'CTRL', action = wezterm.action.DisableDefaultAssignment },
  { key = 'p', mods = 'CTRL', action = wezterm.action.DisableDefaultAssignment },
}

return config
