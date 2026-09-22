#!/usr/bin/env bash
# Небольшие действия из bindings.lua. Аргумент — одно из имён в case ниже.
# Пути и пользовательский текст не выполняются через eval.
set -euo pipefail
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"

fail() {
    printf 'Arch Dotfiles: %s\n' "$1" >&2
    # Встроенное уведомление Hyprland работает и без демона SwayNC.
    hyprctl notify 3 6000 'rgb(cba6f7)' "Arch Dotfiles: $1" >/dev/null 2>&1 || true
    exit 1
}

need() {
    command -v "$1" >/dev/null 2>&1 || fail "Не установлена программа: $1"
}

case "${1:-}" in
    lock)
        need hyprlock
        [[ -f "$config_dir/hypr/hyprlock.conf" ]] \
            || fail "Сначала нужен hypr/hyprlock.conf. Экран сейчас НЕ заблокирован."
        # Повторное нажатие не создаёт второй locker.
        if pgrep -u "$UID" -x hyprlock >/dev/null; then
            exit 0
        fi
        exec hyprlock -c "$config_dir/hypr/hyprlock.conf"
        ;;
    notifications)
        need swaync-client
        pgrep -u "$UID" -x swaync >/dev/null \
            || fail "SwayNC ещё не запущен: подготовь его конфиг и выполни autostart.sh."
        exec swaync-client -t
        ;;
    screenshot-area)
        need grim
        need slurp
        need wl-copy
        # Esc в slurp завершает действие ДО вызова grim.
        geometry="$(slurp)" || exit 0
        [[ -n "$geometry" ]] || exit 0
        grim -g "$geometry" - | wl-copy --type image/png
        ;;
    screenshot-all)
        need grim
        need wl-copy
        grim - | wl-copy --type image/png
        ;;
    *)
        printf 'Использование: %s {lock|notifications|screenshot-area|screenshot-all}\n' "$0" >&2
        exit 2
        ;;
esac
