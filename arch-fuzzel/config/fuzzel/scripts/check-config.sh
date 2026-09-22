#!/usr/bin/env bash
set -euo pipefail

# Проверяет ~/.config/fuzzel/fuzzel.ini и все подключённые include-файлы.
#
# Успех:
#   "Fuzzel config: OK"
#
# Ошибка:
#   Fuzzel сам напечатает проблемную опцию/строку.

if ! command -v fuzzel >/dev/null 2>&1; then
    echo "Ошибка: fuzzel не установлен." >&2
    echo "Установи: sudo pacman -S fuzzel" >&2
    exit 127
fi

fuzzel --check-config
echo "Fuzzel config: OK"
