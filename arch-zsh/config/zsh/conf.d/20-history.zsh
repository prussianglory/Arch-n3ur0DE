# ==============================================================================
# 20-history.zsh — история команд
# ==============================================================================

# Историю держим в XDG state, а не россыпью файлов в $HOME.
HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
mkdir -p "${HISTFILE:h}"

# Количество команд в памяти / на диске.
HISTSIZE=50000
SAVEHIST=50000

# Записывать timestamp и длительность команды.
setopt EXTENDED_HISTORY

# Писать команды в файл сразу, а не только при закрытии shell.
setopt INC_APPEND_HISTORY

# Не хранить подряд одинаковые команды.
setopt HIST_IGNORE_DUPS

# При очистке истории сначала удалять старые дубликаты.
setopt HIST_EXPIRE_DUPS_FIRST

# Команды, начинающиеся с пробела, не сохранять.
#
# Полезно, если нужно выполнить что-то чувствительное:
#   <space>some-command --token ...
#
# Но помни: это НЕ является полноценной защитой секрета от процессов,
# audit, terminal recording и т.д.
setopt HIST_IGNORE_SPACE

# Удалять лишние пробелы перед сохранением.
setopt HIST_REDUCE_BLANKS

# При вызове команды из history сначала дать её отредактировать.
setopt HIST_VERIFY
