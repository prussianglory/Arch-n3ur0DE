# ==============================================================================
# 70-integrations.zsh — fzf, zoxide, Starship
# ==============================================================================

# ------------------------------------------------------------------------------
# fzf
# ------------------------------------------------------------------------------

if (( $+commands[fzf] )); then
    # Общий вид fzf под нашу фиолетовую тему.
    export FZF_DEFAULT_OPTS="
        --height=70%
        --layout=reverse
        --border=rounded
        --info=inline
        --pointer='❯'
        --marker='◆'
        --prompt='  '
        --color=bg+:#181622,bg:#0b0b12,spinner:#b487ff,hl:#9c8cff
        --color=fg:#cbc8d8,header:#7c6cff,info:#6fd6e5,pointer:#b487ff
        --color=marker:#78dba9,fg+:#f1eff8,prompt:#7c6cff,hl+:#c7a4ff
    "

    # Ctrl+T: выбрать файл/директорию и вставить путь в команду.
    export FZF_CTRL_T_OPTS="
        --walker-skip=.git,node_modules,target,.venv
        --preview 'bat --color=always --style=numbers --line-range=:300 {} 2>/dev/null || eza -la --icons=auto --color=always {} 2>/dev/null'
        --bind 'ctrl-/:change-preview-window(down|hidden|)'
    "

    # Alt+C: fuzzy cd.
    export FZF_ALT_C_OPTS="
        --walker-skip=.git,node_modules,target,.venv
        --preview 'eza -la --icons=auto --color=always {} 2>/dev/null || ls -la -- {}'
    "

    # Ctrl+R: fuzzy history.
    export FZF_CTRL_R_OPTS="
        --preview-window=hidden
        --header='Enter: выбрать команду'
    "

    # Современный fzf сам генерирует интеграцию для Zsh.
    source <(fzf --zsh)
fi


# ------------------------------------------------------------------------------
# zoxide
#
# Команды:
#   z foo    — перейти в часто посещаемую директорию, похожую на foo
#   zi       — выбрать такую директорию интерактивно через fzf
#
# Обычный `cd` намеренно НЕ подменяем.
# ------------------------------------------------------------------------------

if (( $+commands[zoxide] )); then
    eval "$(zoxide init zsh)"
fi


# ------------------------------------------------------------------------------
# Starship prompt
# ------------------------------------------------------------------------------

if (( $+commands[starship] )); then
    export STARSHIP_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"
    eval "$(starship init zsh)"
fi
