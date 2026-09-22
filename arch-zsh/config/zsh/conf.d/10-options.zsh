# ==============================================================================
# 10-options.zsh — базовое поведение Zsh
# ==============================================================================

# Не пищать терминалом при ошибках completion и т.п.
setopt NO_BEEP

# Базовая палитра GNU dircolors. Нужна в том числе для цветного completion.
# Не задаём её вручную: системная база Arch знает актуальные типы файлов.
if (( $+commands[dircolors] )); then
    eval "$(dircolors -b)"
fi

# `cd ~/Projects` можно сократить до `~/Projects`.
setopt AUTO_CD

# При `cd` автоматически вести стек последних директорий.
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT

# Разрешает комментарии после команд в интерактивном shell:
#   echo hello  # комментарий
setopt INTERACTIVE_COMMENTS

# Если glob ничего не нашёл, оставляем шаблон как текст вместо ошибки.
# Это менее "строго", зато удобнее при интерактивной работе.
unsetopt NOMATCH

# После `cd` можно использовать:
#   dirs -v
#   cd -1
#   cd -2
DIRSTACKSIZE=20

# Более аккуратное поведение job control.
setopt LONG_LIST_JOBS
setopt AUTO_RESUME
