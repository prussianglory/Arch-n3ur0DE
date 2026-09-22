# ==============================================================================
# 90-plugins.zsh — лёгкие Zsh-плагины из официальных репозиториев Arch
#
# Этот файл загружается ПОСЛЕДНИМ.
# Особенно важно, чтобы zsh-syntax-highlighting шёл после компонентов,
# которые создают/оборачивают ZLE widgets.
# ==============================================================================

# ------------------------------------------------------------------------------
# Autosuggestions
# Серый текст справа подсказывает команду из истории.
# Принять подсказку: Right Arrow / End.
# ------------------------------------------------------------------------------

AUTOSUGGEST_PATH="/usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
if [[ -r "$AUTOSUGGEST_PATH" ]]; then
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#5b5769'
    source "$AUTOSUGGEST_PATH"
fi
unset AUTOSUGGEST_PATH


# ------------------------------------------------------------------------------
# Syntax highlighting
# Валидная команда — зелёная, неизвестная — красноватая и т.д.
# ------------------------------------------------------------------------------

HIGHLIGHT_PATH="/usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
if [[ -r "$HIGHLIGHT_PATH" ]]; then
    # Сам plugin source остаётся последним ZLE-компонентом.
    source "$HIGHLIGHT_PATH"

    # После загрузки меняем только палитру — новых widgets здесь уже нет.
    ZSH_HIGHLIGHT_STYLES[command]='fg=#78dba9'
    ZSH_HIGHLIGHT_STYLES[alias]='fg=#6fd6e5'
    ZSH_HIGHLIGHT_STYLES[builtin]='fg=#7aa2f7'
    ZSH_HIGHLIGHT_STYLES[function]='fg=#7aa2f7'
    ZSH_HIGHLIGHT_STYLES[path]='fg=#cbc8d8,underline'
    ZSH_HIGHLIGHT_STYLES[globbing]='fg=#b487ff'
    ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#e8c97a'
    ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#e8c97a'
    ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#ff6b81'
fi
unset HIGHLIGHT_PATH
