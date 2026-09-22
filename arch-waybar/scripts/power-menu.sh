#!/usr/bin/env bash
# =============================================================================
# Power menu через Fuzzel dmenu
# =============================================================================
# Здесь находится намеренная связь Waybar -> Fuzzel -> Hyprland/systemd.
# Позже, когда будем писать config.ini для Fuzzel, power menu автоматически
# унаследует его цвета/шрифт/размеры.
# =============================================================================

set -u

if ! command -v fuzzel >/dev/null 2>&1; then
    command -v notify-send >/dev/null 2>&1 && \
        notify-send "Waybar" "Для power menu нужен fuzzel"
    exit 1
fi

LOCK='  Lock'
LOGOUT='󰍃  Logout'
SUSPEND='󰤄  Suspend'
REBOOT='󰜉  Reboot'
SHUTDOWN='󰐥  Shutdown'

choice="$({
    printf '%s\n' "$LOCK" "$LOGOUT" "$SUSPEND" "$REBOOT" "$SHUTDOWN"
} | fuzzel --dmenu --prompt='Power > ')"

case "$choice" in
    "$LOCK")
        # Мы ещё отдельно настроим hyprlock. Пока команда уже готова к этой связи.
        if command -v hyprlock >/dev/null 2>&1; then
            hyprlock
        else
            command -v notify-send >/dev/null 2>&1 && \
                notify-send "Lock screen" "hyprlock пока не установлен/не настроен"
        fi
        ;;
    "$LOGOUT")
        hyprctl dispatch exit
        ;;
    "$SUSPEND")
        systemctl suspend
        ;;
    "$REBOOT")
        systemctl reboot
        ;;
    "$SHUTDOWN")
        systemctl poweroff
        ;;
    *)
        # Esc/пустой выбор — ничего не делаем.
        exit 0
        ;;
esac
