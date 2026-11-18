# data/shell/tengri.zsh — Zsh integration for Tengri
#
# Intercepts interactive prompt lines via ZLE accept-line widget without
# requiring separate compiled binaries or fragile preexec string parsing.

# 1. Type Reflection Mini-Buffer (Ctrl-X Ctrl-T)
_tengri_reflect() {
  local expr="${BUFFER}"
  local ty
  ty=$(tengri toli reflect "${expr}" 2>/dev/null)
  zle -M "[tengri type] ${ty}"
}
zle -N _tengri_reflect
bindkey '^X^T' _tengri_reflect

# 2. Typed Hole Articulation (Ctrl-X Ctrl-A)
_tengri_articulate() {
  local expr="${BUFFER}"
  local replacement
  replacement=$(tengri toli articulate "${expr}" 2>/dev/null)
  if [[ -n "${replacement}" ]]; then
    BUFFER="${BUFFER//_$/${replacement}}"
    CURSOR=${#BUFFER}
  fi
}
zle -N _tengri_articulate
bindkey '^X^A' _tengri_articulate

# 3. ZLE accept-line Widget
# Intercepts commands starting with '=' or 'hs ' and forwards them
# to the warm Tengri daemon.
_tengri_accept_line() {
  if [[ "$BUFFER" == =* ]]; then
    BUFFER="tengri ${BUFFER#=}"
  elif [[ "$BUFFER" == "hs "* ]]; then
    BUFFER="tengri ${BUFFER#hs }"
  fi
  zle .accept-line
}
zle -N accept-line _tengri_accept_line
