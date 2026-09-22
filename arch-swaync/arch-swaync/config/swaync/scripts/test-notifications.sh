#!/usr/bin/env bash
set -euo pipefail
command -v notify-send >/dev/null 2>&1 || {
    echo "Ошибка: notify-send не найден. Установи: sudo pacman -S libnotify" >&2
    exit 127
}
notify-send -u low "SwayNC · Low" "Низкий приоритет — короткое информационное уведомление."
sleep 0.4
notify-send -u normal "SwayNC · Normal" "Обычное уведомление для проверки темы, текста и группировки."
sleep 0.4
notify-send -u critical "SwayNC · Critical" "Critical notification не закрывается автоматически при timeout-critical = 0."
