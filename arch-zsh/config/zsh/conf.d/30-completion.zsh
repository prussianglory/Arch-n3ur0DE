# ==============================================================================
# 30-completion.zsh — completion
# ==============================================================================

# Базовая система completion Zsh.
autoload -Uz compinit

# Кэшируем zcompdump отдельно.
ZSH_COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-${ZSH_VERSION}"
mkdir -p "${ZSH_COMPDUMP:h}"

# -d указывает файл кэша.
compinit -d "$ZSH_COMPDUMP"

# Completion без учёта регистра:
#   doc<Tab> может найти Documents
zstyle ':completion:*' matcher-list \
    'm:{a-zA-Z}={A-Za-z}' \
    'r:|[._-]=* r:|=*'

# Показывать описания групп.
zstyle ':completion:*:descriptions' format '%F{8}-- %d --%f'

# Группировать разные типы completion.
zstyle ':completion:*' group-name ''

# Использовать цвета LS_COLORS в completion.
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# Меню completion появляется только когда есть смысл.
zstyle ':completion:*' menu select

# Completion для `cd` не предлагает текущий и родительский каталог.
zstyle ':completion:*:cd:*' ignore-parents parent pwd

# Кэш для completion, которые умеют его использовать.
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/completion"
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/completion"
