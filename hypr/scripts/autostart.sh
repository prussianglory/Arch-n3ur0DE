#!/usr/bin/env bash
# Автозапуск для одной обычной сессии Hyprland текущего пользователя.
# Вызывается из conf/autostart.lua. Не запускать через sudo.
set -u
umask 077

config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/arch-dotfiles"
mkdir -p -- "$state_dir" || exit 1
exec >>"$state_dir/autostart.log" 2>&1

# flock входит в util-linux. Защищает от двух одновременных запусков скрипта.
# Дочерним процессам FD 9 не передаём, чтобы они не удерживали блокировку.
exec 9>"$state_dir/autostart.lock"
flock -n 9 || exit 0
printf '\n[%s] запуск компонентов\n' "$(date -Is)"

# Сервисы D-Bus/systemd должны знать переменные именно этой графической сессии.
# Экспортируем только выбранные существующие переменные, а не всё окружение.
session_vars=()
for var in WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP \
    XDG_SESSION_TYPE XDG_SESSION_DESKTOP XCURSOR_SIZE HYPRCURSOR_SIZE \
    __GLX_VENDOR_LIBRARY_NAME; do
    [[ -n "${!var-}" ]] && session_vars+=("$var")
done
if ((${#session_vars[@]})); then
    if command -v dbus-update-activation-environment >/dev/null 2>&1; then
        dbus-update-activation-environment --systemd "${session_vars[@]}" || true
    else
        systemctl --user import-environment "${session_vars[@]}" || true
    fi
fi

# Один экземпляр программы на текущего пользователя.
# Предполагается одна Hyprland-сессия; для нескольких одновременных сессий
# позже нужна отдельная организация процессов, привязанная к session ID.
start_once() {
    local process_name="$1"
    shift
    if ! command -v "$1" >/dev/null 2>&1; then
        printf 'Пропущено: не установлен %s\n' "$1"
        return
    fi
    if pgrep -u "$UID" -x "$process_name" >/dev/null; then
        return
    fi
    "$@" 9>&- &
}

# Агент авторизации нужен графическим программам для запросов Polkit.
# Сам пакет не устанавливаем. Не стартуем другие агенты Polkit параллельно.
if systemctl --user cat hyprpolkitagent.service >/dev/null 2>&1; then
    systemctl --user start hyprpolkitagent.service || true
fi

# Будущие файлы — это договорённость о путях. Пока файлов нет, блок пропускается.
if [[ -f "$config_dir/waybar/config.jsonc" && -f "$config_dir/waybar/style.css" ]]; then
    start_once waybar waybar -c "$config_dir/waybar/config.jsonc" -s "$config_dir/waybar/style.css"
fi

if [[ -f "$config_dir/swaync/config.json" && -f "$config_dir/swaync/style.css" ]]; then
    start_once swaync swaync -c "$config_dir/swaync/config.json" -s "$config_dir/swaync/style.css"
fi

if [[ -f "$config_dir/hypr/hyprpaper.conf" ]]; then
    start_once hyprpaper hyprpaper -c "$config_dir/hypr/hyprpaper.conf"
fi

# Idle-демон запускается только вместе с подготовленным экраном блокировки.
# Таймауты и блокировка до сна будут определены в будущем hypridle.conf.
if [[ -f "$config_dir/hypr/hypridle.conf" && -f "$config_dir/hypr/hyprlock.conf" ]] \
    && command -v hyprlock >/dev/null 2>&1; then
    start_once hypridle hypridle -c "$config_dir/hypr/hypridle.conf"
fi

# PipeWire, WirePlumber и xdg-desktop-portal здесь не запускаем вручную:
# их жизненным циклом управляют штатные пользовательские службы/D-Bus.
# Clipboard history также не включена: текущий этап не требует сохранения истории.
