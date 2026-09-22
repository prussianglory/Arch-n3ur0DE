# ==============================================================================
# 50-aliases.zsh — короткие команды
#
# Алиасы, завязанные на необязательную утилиту, создаются только если она
# действительно установлена. Поэтому Zsh не ломается на минимальной системе.
# ==============================================================================

# ------------------------------------------------------------------------------
# Навигация
# ------------------------------------------------------------------------------

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

alias c='clear'

# ------------------------------------------------------------------------------
# eza — современный ls
# ------------------------------------------------------------------------------

if (( $+commands[eza] )); then
    alias ls='eza --icons=auto --group-directories-first'
    alias l='eza --icons=auto --group-directories-first'
    alias ll='eza -lah --icons=auto --group-directories-first --git'
    alias la='eza -a --icons=auto --group-directories-first'
    alias lt='eza --tree --level=2 --icons=auto --group-directories-first'
    alias lta='eza --tree --level=3 -a --icons=auto --group-directories-first'
fi

# ------------------------------------------------------------------------------
# Neovim
# ------------------------------------------------------------------------------

if (( $+commands[nvim] )); then
    alias v='nvim'
    alias vi='nvim'
    alias vim='nvim'
fi

# ------------------------------------------------------------------------------
# Git
# ------------------------------------------------------------------------------

if (( $+commands[git] )); then
    alias g='git'
    alias gs='git status'
    alias ga='git add'
    alias gaa='git add --all'
    alias gc='git commit'
    alias gcm='git commit -m'
    alias gd='git diff'
    alias gds='git diff --staged'
    alias gl='git log --oneline --decorate --graph --all'
    alias gp='git push'
    alias gpl='git pull'
    alias gb='git branch'
    alias gco='git checkout'
    alias gsw='git switch'
fi

# ------------------------------------------------------------------------------
# Arch Linux / systemd
# ------------------------------------------------------------------------------

alias update='sudo pacman -Syu'
alias pacs='pacman -Ss'
alias pacq='pacman -Q'
alias pacqi='pacman -Qi'

# Запущенные failed units.
alias failed='systemctl --failed'

# Логи текущей загрузки с приоритетом error и выше.
alias jerr='journalctl -b -p err'

# ------------------------------------------------------------------------------
# Безопасные мелкие улучшения
# ------------------------------------------------------------------------------

alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias mkdir='mkdir -pv'
