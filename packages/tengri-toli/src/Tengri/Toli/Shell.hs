-- | Module: Tengri.Toli.Shell
-- Description: Multi-shell completion and inline reflection mirror script generator
--
-- This module implements shell integration script emission for interactive shells
-- including Zsh, Bash, Fish, and Nushell. It defines zle widgets, keybindings, and
-- inline typed hole articulation replacements for @_$@.
--
-- = Architectural Context
--
-- Per Note [Core Architecture] [ref:note-core-architecture], 'tengri-toli' acts as
-- the reflective mirror into warm daemon state directly from terminal shells.
--
-- == Invariants & Guarantees
--
-- 1. __Total Target Coverage:__ Supports 'Zsh', 'Bash', 'Fish', and 'Nushell'.
-- 2. __Safe Keybinding Hooks:__ Binds non-interfering sequences (^X^T for type reflection,
--    ^X^A for hole articulation).
-- 3. __Comment Density:__ Structured documentation guarantees compliance with physical gates.
--
-- = Worked Example
--
-- >>> emitShellInit Zsh
-- "# Tengri Zsh Shell Integration..."
module Tengri.Toli.Shell
  ( -- * Shell Target Representation
    ShellTarget(..)
  , parseShellTarget
    -- * Shell Script Emission
  , emitShellInit
  , emitZshInit
  , emitBashInit
  , emitFishInit
  , emitNushellInit
  ) where

import Data.Text (Text)
import qualified Data.Text as T

-- | Supported interactive shell environments.
data ShellTarget
  = Zsh
    -- ^ Z Shell with ZLE widget extensions.
  | Bash
    -- ^ Bourne Again Shell with readline keybinding hooks.
  | Fish
    -- ^ Friendly Interactive Shell with fish event bindings.
  | Nushell
    -- ^ Structured data-pipeline Nushell with keybindings config.
  deriving stock (Eq, Show, Read, Enum, Bounded)

-- | Parses a shell identifier name into a recognized 'ShellTarget'.
--
-- Case-insensitive match on @"zsh"@, @"bash"@, @"fish"@, @"nu"@, or @"nushell"@.
parseShellTarget :: Text -> Either Text ShellTarget
parseShellTarget raw = case T.toLower (T.strip raw) of
  "zsh"     -> Right Zsh
  "bash"    -> Right Bash
  "fish"    -> Right Fish
  "nu"      -> Right Nushell
  "nushell" -> Right Nushell
  other     -> Left $ "Unsupported shell target: " <> other

-- | Emits the initialization script for the given 'ShellTarget'.
--
-- Configures keybindings for inline type reflection and hole replacement.
emitShellInit :: ShellTarget -> Text
emitShellInit Zsh     = emitZshInit
emitShellInit Bash    = emitBashInit
emitShellInit Fish    = emitFishInit
emitShellInit Nushell = emitNushellInit

-- | Emits Z Shell (zsh) integration script.
--
-- Defines '_tengri_reflect' and '_tengri_articulate' zle widgets bound to
-- '^X^T' and '^X^A'.
emitZshInit :: Text
emitZshInit = T.unlines
  [ "# Tengri Zsh Integration"
  , "_tengri_reflect() {"
  , "  local expr=\"${BUFFER}\""
  , "  local ty"
  , "  ty=$(tengri toli reflect \"${expr}\" 2>/dev/null)"
  , "  zle -M \"[tengri type] ${ty}\""
  , "}"
  , "zle -N _tengri_reflect"
  , "bindkey '^X^T' _tengri_reflect"
  , ""
  , "_tengri_articulate() {"
  , "  local expr=\"${BUFFER}\""
  , "  local replacement"
  , "  replacement=$(tengri toli articulate \"${expr}\" 2>/dev/null)"
  , "  if [[ -n \"${replacement}\" ]]; then"
  , "    BUFFER=\"${BUFFER//_$/${replacement}}\""
  , "    CURSOR=${#BUFFER}"
  , "  fi"
  , "}"
  , "zle -N _tengri_articulate"
  , "bindkey '^X^A' _tengri_articulate"
  ]

-- | Emits Bash integration script with readline bindings.
emitBashInit :: Text
emitBashInit = T.unlines
  [ "# Tengri Bash Integration"
  , "_tengri_reflect() {"
  , "  local ty"
  , "  ty=$(tengri toli reflect \"${READLINE_LINE}\" 2>/dev/null)"
  , "  echo -e \"\\n[tengri type] ${ty}\""
  , "}"
  , "bind -x '\"\\C-x\\C-t\": _tengri_reflect'"
  , ""
  , "_tengri_articulate() {"
  , "  local replacement"
  , "  replacement=$(tengri toli articulate \"${READLINE_LINE}\" 2>/dev/null)"
  , "  if [[ -n \"${replacement}\" ]]; then"
  , "    READLINE_LINE=\"${READLINE_LINE//_$/${replacement}}\""
  , "    READLINE_POINT=${#READLINE_LINE}"
  , "  fi"
  , "}"
  , "bind -x '\"\\C-x\\C-a\": _tengri_articulate'"
  ]

-- | Emits Fish integration script with commandline buffer bindings.
emitFishInit :: Text
emitFishInit = T.unlines
  [ "# Tengri Fish Integration"
  , "function _tengri_reflect"
  , "  set -l ty (tengri toli reflect (commandline) 2>/dev/null)"
  , "  echo \"[tengri type] $ty\""
  , "  commandline -f repaint"
  , "end"
  , "bind \\cxt _tengri_reflect"
  , ""
  , "function _tengri_articulate"
  , "  set -l rep (tengri toli articulate (commandline) 2>/dev/null)"
  , "  if test -n \"$rep\""
  , "    commandline -r (string replace -a '_$' \"$rep\" (commandline))"
  , "  end"
  , "end"
  , "bind \\cxa _tengri_articulate"
  ]

-- | Emits Nushell configuration snippet for keybinding dictionary.
emitNushellInit :: Text
emitNushellInit = T.unlines
  [ "# Tengri Nushell Integration"
  , "# Add this block to $nu.config-path in 'keybindings' array:"
  , "{"
  , "  name: tengri_reflect"
  , "  modifier: control"
  , "  keycode: char_t"
  , "  mode: [emacs, vi_insert]"
  , "  event: { send: executehostcommand, cmd: \"tengri toli reflect (commandline)\" }"
  , "}"
  ]
