# ==============================================================================
# 40-keybindings.zsh — управление командной строкой
# ==============================================================================

# Emacs-style режим — Ctrl+A/E, Ctrl+W и т.д.
bindkey -e

# Home / End.
bindkey '^[[H'  beginning-of-line
bindkey '^[[F'  end-of-line
bindkey '^[[1~' beginning-of-line
bindkey '^[[4~' end-of-line

# Delete.
bindkey '^[[3~' delete-char

# Ctrl+Left / Ctrl+Right — перемещение по словам.
bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word
bindkey '^[[5D'   backward-word
bindkey '^[[5C'   forward-word

# Вверх/вниз ищут в истории по уже набранному началу.
#
# Например:
#   git <Up>
# перебирает предыдущие команды, начинавшиеся с `git`.
autoload -Uz up-line-or-beginning-search
autoload -Uz down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search

bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search

# Ctrl+Backspace — удалить предыдущее слово.
bindkey '^H' backward-kill-word
