#!/usr/bin/env python3
"""Сборка конфигов из структуры репозитория и установка пользовательских файлов.

Команды stage/deploy работают без root. Никакие файлы из репозитория не
исполняются при подготовке; символьные ссылки в источнике не принимаются.
"""
from __future__ import annotations

import argparse
import ast
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import shlex
import stat
import subprocess
import tempfile
import tomllib


ZSHRC = r'''# Основной конфиг Zsh. ~/.zshenv задаёт ZDOTDIR.
[[ -o interactive ]] || return
autoload -Uz colors
colors
# Модули идут по номерам: completion -> клавиши -> интеграции -> плагины.
for n3ur0_file in "$ZDOTDIR"/conf.d/*.zsh(N); do
    source "$n3ur0_file"
done
unset n3ur0_file
'''

LOCK = r'''#!/usr/bin/env bash
# Общий вход для Super+L, панели и Hypridle. Не запускать через sudo.
set -euo pipefail
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
command -v hyprlock >/dev/null || { printf 'Нет hyprlock\n' >&2; exit 1; }
[[ -r "$config_dir/hypr/hyprlock.conf" && -r /etc/pam.d/hyprlock ]] || {
    printf 'Отсутствует конфиг Hyprlock или его PAM service\n' >&2; exit 1;
}
if [[ "${1:-}" != --direct ]] && pgrep -u "$UID" -x hypridle >/dev/null; then
    # Hypridle получает запрос logind и вызывает этот же файл с --direct.
    if [[ -n "${XDG_SESSION_ID:-}" ]]; then
        loginctl lock-session "$XDG_SESSION_ID" && exit 0
    else
        loginctl lock-session && exit 0
    fi
fi
# Общая блокировка на пользователя предотвращает гонку двух запусков locker.
runtime_dir="${XDG_RUNTIME_DIR:?Нет XDG_RUNTIME_DIR: нужна пользовательская сессия}"
exec 9>"$runtime_dir/arch-n3ur0de-lock"
flock -n 9 || exit 0
pgrep -u "$UID" -x hyprlock >/dev/null && exit 0
exec hyprlock -c "$config_dir/hypr/hyprlock.conf"
'''

POWER = r'''#!/usr/bin/env bash
# Waybar -> Fuzzel -> общий locker / Hyprland / systemd.
set -euo pipefail
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
choice="$(printf '%s\n' 'Lock' 'Logout' 'Suspend' 'Reboot' 'Shutdown' |
    fuzzel --dmenu --prompt='Power > ')" || exit 0
case "$choice" in
    Lock) exec bash "$config_dir/hypr/scripts/lock-now.sh" ;;
    Logout) exec hyprctl dispatch 'hl.dsp.exit()' ;;
    Suspend)
        # inhibit_sleep=3 в Hypridle ждёт реального захвата session lock.
        if ! pgrep -u "$UID" -x hypridle >/dev/null; then
            notify-send 'Suspend' 'Hypridle не запущен: сначала восстанови блокировку перед сном.'
            exit 1
        fi
        exec systemctl suspend ;;
    Reboot) exec systemctl reboot ;;
    Shutdown) exec systemctl poweroff ;;
esac
'''

GPU = r'''#!/usr/bin/env python3
"""Метрики NVIDIA для Waybar; N/A не превращается в невалидный JSON."""
import csv
import json
import os
import subprocess

try:
    result = subprocess.run([
        "nvidia-smi", "-i", os.environ.get("GPU_INDEX", "0"),
        "--query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw",
        "--format=csv,noheader,nounits"], text=True, capture_output=True,
        timeout=3, check=True)
    row = next(csv.reader(result.stdout.splitlines()))
    name, util, used, total, temp, power = [value.strip() for value in row]
    utilization = max(0, min(100, int(float(util))))
    tooltip = f"{name}\nLoad: {utilization}%\nVRAM: {used} / {total} MiB\nTemperature: {temp}°C\nPower: {power} W"
    temperature = float(temp) if temp.replace('.', '', 1).isdigit() else 0
    css = 'critical' if temperature >= 85 else 'warning' if temperature >= 75 else 'normal'
    output = dict(text=f"󰢮  {utilization}%", tooltip=tooltip, percentage=utilization, **{'class': css})
except (OSError, subprocess.SubprocessError, ValueError, StopIteration):
    output = dict(text='󰢮  N/A', tooltip='Нет данных NVIDIA. Проверь nvidia-smi после перезагрузки.',
                  percentage=0, **{'class': 'unavailable'})
print(json.dumps(output, ensure_ascii=False))
'''

AUTOSTART = r'''#!/usr/bin/env bash
# Единственное место прямого автозапуска компонентов n3ur0DE.
set -u
umask 077
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/arch-n3ur0de"
mkdir -p -- "$state_dir" || exit 1
exec >>"$state_dir/session.log" 2>&1
exec 9>"${XDG_RUNTIME_DIR:?}/arch-n3ur0de-start"
flock -n 9 || exit 0
printf '\n[%s] запуск сессии\n' "$(date -Is)"
session_vars=()
for var in WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP \
    XDG_SESSION_TYPE XDG_SESSION_DESKTOP XCURSOR_SIZE HYPRCURSOR_SIZE \
    XCURSOR_THEME __GLX_VENDOR_LIBRARY_NAME XDG_CONFIG_HOME; do
    [[ -n "${!var-}" ]] && session_vars+=("$var")
done
if ((${#session_vars[@]})); then
    dbus-update-activation-environment --systemd "${session_vars[@]}" || true
fi
start_once() {
    local process_name="$1"
    shift
    command -v "$1" >/dev/null 2>&1 || return 0
    pgrep -u "$UID" -x "$process_name" >/dev/null && return 0
    "$@" 9>&- &
}
# Сокеты звука активируют серверы; порталы активируются через D-Bus.
systemctl --user start pipewire.socket pipewire-pulse.socket wireplumber.service || true
systemctl --user start hyprpolkitagent.service || true
gsettings set org.gnome.desktop.interface color-scheme prefer-dark || true
gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark || true
gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark || true
start_once hypridle hypridle -c "$config_dir/hypr/hypridle.conf"
if [[ -f "$config_dir/hypr/hyprpaper.conf" ]]; then
    start_once hyprpaper hyprpaper -c "$config_dir/hypr/hyprpaper.conf"
fi
start_once swaync swaync -c "$config_dir/swaync/config.json" -s "$config_dir/swaync/style.css"
start_once waybar waybar -c "$config_dir/waybar/config.jsonc" -s "$config_dir/waybar/style.css"
start_once nm-applet nm-applet --indicator
start_once spice-vdagent spice-vdagent
start_once vmtoolsd vmware-user-suid-wrapper
# GVfs обеспечивает автомонтирование/корзину в Thunar. Демоны запускаются D-Bus.
'''


def write(path: Path, text: str, mode: int = 0o644) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    path.chmod(mode)


def pick(root: Path, *relative: str) -> Path:
    for name in relative:
        item = root / name
        if item.exists():
            return item
    raise ValueError("В репозитории не найдено: " + " или ".join(relative))


def copy_component(source: Path, dest: Path) -> None:
    for path in [source, *source.rglob("*")]:
        if path.is_symlink():
            raise ValueError(f"Символьная ссылка в исходных конфигах: {path}")
        if not path.is_file():
            continue
        if path.suffix.lower() in {".md", ".pyc"} or ".git" in path.parts:
            continue
        target = dest / path.relative_to(source)
        target.parent.mkdir(parents=True, exist_ok=True)
        # Нормализуем CRLF после загрузки файлов из Windows.
        text = path.read_text(encoding="utf-8").replace("\r\n", "\n")
        write(target, text, 0o755 if path.suffix in {".sh", ".py"} else 0o644)


def parse_jsonc(text: str):
    # Строки сохраняем целиком: // внутри URL не является комментарием.
    tokens = r'("(?:\\.|[^"\\])*"|/\*[\s\S]*?\*/|//[^\n\r]*)'
    text = re.sub(tokens, lambda m: m[0] if m[0].startswith('"') else '', text)
    text = re.sub(r'("(?:\\.|[^"\\])*"|,\s*(?=[}\]]))',
                  lambda m: m[0] if m[0].startswith('"') else '', text)
    return json.loads(text)


def waybar_text(data: dict) -> str:
    """Оставляем подсказки к редактированию после преобразования JSONC."""
    comments = {
        'modules-left': 'Порядок слева: запуск приложений, рабочие столы, активное окно.',
        'modules-center': 'Центральный блок панели.',
        'modules-right': 'Порядок справа. Удали имя модуля, чтобы скрыть его.',
        'hyprland/language': 'Раскладка EN/RU. Клик переключает; Alt+Shift и Super+Space тоже работают.',
        'ext/workspaces': 'Клик через Wayland ext-workspace. Постоянные столы: hypr/conf/workspaces.lua.',
        'hyprland/window': 'max-length ограничивает длину заголовка окна.',
        'clock': 'Формат даты — strftime. locale можно добавить для другого языка даты.',
        'cpu': 'Интервал в секундах; states задаёт пороги цветов warning/critical.',
        'memory': 'Использование RAM. Клик открывает btop в Kitty.',
        'custom/gpu': 'NVIDIA: данные nvidia-smi, JSON от scripts/gpu-nvidia.py; GPU_INDEX выбирает GPU.',
        'custom/cpu-temp': 'Температура из hwmon/thermal; скрипт не привязан к номеру hwmon.',
        'network': 'Сеть; клик открывает nmtui. Для NetworkManager.',
        'wireplumber': 'Звук: ЛКМ — микшер, ПКМ — mute, колесо — громкость, предел 100%.',
        'bluetooth': 'Клик открывает blueman-manager.',
        'tray': 'Значки фоновых приложений: размер icon-size и промежуток spacing.',
        'custom/notification': 'SwayNC: ЛКМ — центр уведомлений, ПКМ — Не беспокоить.',
        'custom/power': 'Меню Fuzzel: блокировка, выход, сон, перезагрузка, выключение.',
    }
    lines = ['// n3ur0DE: JSONC допускает // комментарии. Цвета и отступы: style.css.',
             '// Применить: pkill -SIGUSR2 -u "$(id -u)" waybar', '{']
    for index, (key, value) in enumerate(data.items()):
        if key in comments:
            lines.append('  // ' + comments[key])
        serialized = json.dumps(value, ensure_ascii=False, indent=2).splitlines()
        lines.append('  ' + json.dumps(key) + ': ' + serialized[0])
        lines.extend('  ' + line for line in serialized[1:])
        if index + 1 < len(data):
            lines[-1] += ','
    return '\n'.join([*lines, '}', ''])


def stage(args) -> None:
    repo, output = args.source.resolve(), args.output.resolve()
    if output.exists() and any(output.iterdir()):
        raise ValueError(f"Каталог подготовки должен быть пуст: {output}")
    output.mkdir(parents=True, exist_ok=True)
    config = output / ".config"
    layout = {
        "hypr": pick(repo, "hypr"),
        "kitty": pick(repo, "arch-kitty", "config/kitty", ".config/kitty"),
        "waybar": pick(repo, "arch-waybar", "config/waybar", ".config/waybar"),
        "fuzzel": pick(repo, "arch-fuzzel/config/fuzzel", "arch-fuzzel/.config/fuzzel"),
        "swaync": pick(repo, "arch-swaync/arch-swaync/config/swaync", "arch-swaync/config/swaync", "arch-swaync/.config/swaync"),
        "zsh": pick(repo, "arch-zsh/config/zsh", "arch-zsh/.config/zsh"),
    }
    for component, source in layout.items():
        copy_component(source, config / component)
    lock_source = pick(repo, "arch-hyprlock-idle/config/hypr", "arch-hyprlock-idle/.config/hypr")
    copy_component(lock_source, config / "hypr")
    env = pick(repo, "arch-zsh/zshenv", "arch-zsh/.zshenv")
    state_home = args.state_home or args.user_home / '.local/state'
    bootstrap = ('# Пути выбранной установки; меняй здесь при переносе XDG-каталогов.\n'
                 '[[ -n ${XDG_CONFIG_HOME:-} ]] || export XDG_CONFIG_HOME=' + shlex.quote(str(args.config_home)) + '\n'
                 '[[ -n ${XDG_STATE_HOME:-} ]] || export XDG_STATE_HOME=' + shlex.quote(str(state_home)) + '\n')
    write(output / ".zshenv", bootstrap + env.read_text())
    write(output / '.local/share/arch-n3ur0de/session-env',
          '# Пути для запуска с экрана входа, который не читает .zshenv.\n'
          'export XDG_CONFIG_HOME=' + shlex.quote(str(args.config_home)) + '\n'
          'export XDG_STATE_HOME=' + shlex.quote(str(state_home)) + '\n')
    starship = pick(repo, "arch-zsh/config/starship.toml", "arch-zsh/.config/starship.toml")
    write(config / "starship.toml", starship.read_text())
    tomllib.loads(starship.read_text())
    zsh_dir = config / "zsh"
    if (zsh_dir / "zshrc").exists():
        (zsh_dir / "zshrc").rename(zsh_dir / ".zshrc")
    if not (zsh_dir / ".zshrc").exists():
        write(zsh_dir / ".zshrc", ZSHRC)

    required = ["hypr/hyprland.lua", "hypr/conf/bindings.lua", "hypr/conf/input.lua",
                "hypr/conf/environment.lua", "hypr/conf/settings.lua", "hypr/conf/local.lua",
                "hypr/hypridle.conf", "hypr/hyprlock.conf", "kitty/kitty.conf",
                "kitty/theme.conf", "kitty/keybindings.conf", "waybar/style.css",
                "waybar/config.jsonc", "fuzzel/fuzzel.ini", "fuzzel/colors.ini",
                "swaync/config.json", "swaync/style.css", "zsh/.zshrc"]
    for name in required:
        if not (config / name).is_file():
            raise ValueError(f"Неполный комплект: {name}")

    # Не применяем настройки NVIDIA к виртуальному адаптеру или AMD/Intel.
    environment = config / "hypr/conf/environment.lua"
    env_text = environment.read_text()
    env_text = re.sub(r'^hl\.env\("(?:__GLX_VENDOR_LIBRARY_NAME|LIBVA_DRIVER_NAME)",.*\)\s*$', '', env_text, flags=re.M)
    if args.gpu == "nvidia":
        env_text += '\n-- Профиль NVIDIA с открытыми модулями ядра.\nhl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")\n'
    env_text += '\nhl.env("XCURSOR_THEME", "Adwaita")\n'
    write(environment, env_text)
    write(config / "hypr/conf/installer.lua", "-- Параметры профиля установщика. Личные поправки: conf/local.lua.\n" + (
        'hl.config({\n  animations = { enabled = false },\n  decoration = { blur = { enabled = false }, shadow = { enabled = false } },\n  cursor = { no_hardware_cursors = 1 },\n})\n'
        if args.profile == "vm" else '-- ПК: сохраняем эффекты и автоматический курсор.\n'))
    entry = config / "hypr/hyprland.lua"
    text = entry.read_text()
    anchor = 'require("conf.local")'
    if anchor not in text:
        raise ValueError("Не найдено место подключения conf/local.lua; обнови prepare.py для новой структуры")
    text = text.replace(anchor, 'require("conf.installer")\n' + anchor, 1)
    write(entry, text)

    # Общая актуальная палитра из Kitty/Fuzzel/Zsh.
    settings = config / "hypr/conf/settings.lua"
    text = settings.read_text()
    colors = {"background": "0b0b12", "surface": "181622", "surface_alt": "211d35", "text": "f1eff8",
              "muted": "8f8b9c", "purple": "7c6cff", "violet": "b487ff", "inactive_border": "292538"}
    for name, value in colors.items():
        text = re.sub(r'(' + re.escape(name) + r'\s*=\s*")[0-9a-fA-F]{6}("\s*,)', r'\g<1>' + value + r'\2', text)
    write(settings, text)
    rules = config / "hypr/conf/rules.lua"
    write(rules, rules.read_text() + '\n-- Диалоговые терминалы кнопок панели.\nhl.window_rule({ name = "n3ur0de-panel-tools", match = { class = "^waybar-(btop|nvidia|network)$" }, float = true, center = true, size = { "monitor_w * 0.7", "monitor_h * 0.7" } })\n')

    waybar = parse_jsonc((config / "waybar/config.jsonc").read_text())
    waybar["hyprland/language"] = {"format": "{}", "format-en": "EN", "format-ru": "RU",
                                  "on-click": "hyprctl switchxkblayout all next", "tooltip": False}
    waybar["modules-right"].insert(0, "hyprland/language")
    # Waybar 0.15.0 отправляет старые IPC-команды при клике на hyprland/workspaces.
    # Стандартный ext-workspace-v1 есть в Hyprland 0.56 и работает с Lua-конфигом.
    waybar.pop('hyprland/workspaces')
    waybar['modules-left'] = ['ext/workspaces' if m == 'hyprland/workspaces' else m
                             for m in waybar['modules-left']]
    waybar['ext/workspaces'] = {
        'format': '{name}', 'on-click': 'activate', 'sort-by-name': True,
        'all-outputs': False, 'active-only': False, 'ignore-hidden': True,
        'on-scroll-up': "hyprctl dispatch 'hl.dsp.focus({ workspace = \"e+1\" })'",
        'on-scroll-down': "hyprctl dispatch 'hl.dsp.focus({ workspace = \"e-1\" })'",
    }
    waybar["wireplumber"]["on-scroll-up"] = "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
    waybar["custom/notification"]["exec-if"] = "command -v swaync-client"
    waybar["custom/notification"]["on-click"] = "swaync-client -t"
    waybar["custom/notification"]["on-click-right"] = "swaync-client -d"
    for section in waybar.values():
        if isinstance(section, dict):
            for key, value in section.items():
                if isinstance(value, str) and "$HOME/.config/waybar/" in value:
                    section[key] = value.replace("$HOME/.config/waybar/", '"${XDG_CONFIG_HOME:-$HOME/.config}/waybar/').rstrip('"') + '"'
    waybar["custom/gpu"]["exec"] = 'python3 "${XDG_CONFIG_HOME:-$HOME/.config}/waybar/scripts/gpu-nvidia.py"'
    if args.profile == "vm" or args.gpu != "nvidia":
        waybar["modules-right"] = [m for m in waybar["modules-right"] if m != "custom/gpu"]
    if args.profile == "vm":
        waybar["modules-right"] = [m for m in waybar["modules-right"] if m not in {"custom/cpu-temp", "bluetooth"}]
        waybar["hyprland/window"]["max-length"] = 20
    write(config / "waybar/config.jsonc", waybar_text(waybar))
    css = config / "waybar/style.css"
    write(css, css.read_text() + '\n#language { color: #b487ff; background: #181622; border-radius: 10px; padding: 0 10px; }\n')
    write(config / "waybar/scripts/gpu-nvidia.py", GPU, 0o755)
    write(config / "waybar/scripts/power-menu.sh", POWER, 0o755)
    write(config / "hypr/scripts/lock-now.sh", LOCK, 0o755)
    write(config / "hypr/scripts/autostart.sh", AUTOSTART, 0o755)
    action = config / "hypr/scripts/session-action.sh"
    text = action.read_text()
    text = re.sub(r'    lock\)\n.*?        ;;', '    lock)\n        exec bash "$config_dir/hypr/scripts/lock-now.sh"\n        ;;', text, count=1, flags=re.S)
    write(action, text, 0o755)
    idle = config / "hypr/hypridle.conf"
    lock_command = '    lock_cmd = bash ' + shlex.quote(str(args.config_home / 'hypr/scripts/lock-now.sh')) + ' --direct'
    text = re.sub(r'^\s*lock_cmd\s*=.*$', lambda _: lock_command, idle.read_text(), flags=re.M)
    text = text.replace('# `pidof ... || ...` prevents duplicate Hyprlock instances.',
                        '# lock-now.sh uses a per-user flock to prevent duplicate lockers.')
    write(idle, text)

    fuzzel = config / "fuzzel/fuzzel.ini"
    write(fuzzel, fuzzel.read_text().replace('include=~/.config/fuzzel/colors.ini', 'include=' + str(args.config_home / "fuzzel/colors.ini")))
    # VM не пытается снимать скриншот при блокировке и не тратит GPU на blur.
    if args.profile == "vm":
        locker = config / "hypr/hyprlock.conf"
        text = locker.read_text().replace('path = screenshot', 'path =').replace('blur_passes = 4', 'blur_passes = 0')
        write(locker, text)

    for gtk in ("gtk-3.0", "gtk-4.0"):
        write(config / gtk / "settings.ini", '[Settings]\ngtk-application-prefer-dark-theme=1\ngtk-theme-name=Adwaita-dark\ngtk-icon-theme-name=Papirus-Dark\ngtk-cursor-theme-name=Adwaita\ngtk-font-name=Noto Sans 10\n')
    write(config / "xdg-desktop-portal/hyprland-portals.conf", '[preferred]\ndefault=hyprland;gtk\norg.freedesktop.impl.portal.FileChooser=gtk\norg.freedesktop.impl.portal.Settings=gtk\n')
    if args.wallpaper:
        if not args.wallpaper.is_file() or args.wallpaper.suffix.lower() not in {'.png', '.jpg', '.jpeg', '.webp'}:
            raise ValueError("Обои должны быть существующим PNG/JPEG/WebP")
        relative = Path('.local/share/backgrounds/arch-n3ur0de/wallpaper' + args.wallpaper.suffix.lower())
        (output / relative).parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(args.wallpaper, output / relative)
        final_path = args.user_home / relative
        if any(ch in str(final_path) for ch in '#\n\r'):
            raise ValueError('Путь обоев не должен содержать # или перенос строки')
        write(config / 'hypr/hyprpaper.conf', 'splash = false\nipc = true\nwallpaper {\n    monitor =\n    path = ' + str(final_path) + '\n    fit_mode = cover\n}\n')

    # Синтаксические проверки происходят до изменения домашних конфигов.
    for path in config.rglob('*'):
        if path.suffix == '.sh':
            subprocess.run(['bash', '-n', str(path)], check=True)
        elif path.suffix == '.py':
            ast.parse(path.read_text(), filename=str(path))
    json.loads((config / 'swaync/config.json').read_text())
    print(json.dumps({"profile": args.profile, "gpu": args.gpu,
                      "files": sum(p.is_file() for p in output.rglob('*')),
                      "wallpaper": bool(args.wallpaper)}, ensure_ascii=False))


def safe_parents(destination: Path, boundary: Path) -> None:
    destination = Path(os.path.abspath(destination))
    boundary = Path(os.path.abspath(boundary))
    if not destination.is_relative_to(boundary):
        raise ValueError(f"Назначение вне домашнего каталога: {destination}")
    current = destination.parent
    while current != boundary.parent:
        if current.is_symlink():
            raise ValueError(f"Каталог назначения — ссылка: {current}; установка остановлена до записи")
        if current.exists() and not current.is_dir():
            raise ValueError(f"Вместо каталога существует файл: {current}")
        current = current.parent


def check_paths(args) -> None:
    boundary = Path(os.path.abspath(args.user_home))
    if boundary == Path('/'):
        raise ValueError('Домашний каталог не может быть корнем файловой системы')
    for path in (args.config_home, args.state_home):
        path = Path(os.path.abspath(path))
        if path == boundary:
            raise ValueError('XDG-каталог не может совпадать с домашним')
        safe_parents(path / '.n3ur0de-check', boundary)


def deploy(args) -> None:
    stage_dir = args.source.resolve()
    user_home = Path(os.path.abspath(args.user_home))
    config_home = Path(os.path.abspath(args.config_home))
    backup = Path(os.path.abspath(args.backup))
    safe_parents(backup / 'files.json', user_home)
    if (backup / 'files.json').exists():
        raise ValueError('Эта резервная копия уже использована; укажи новый каталог')
    paths = []
    for src in sorted(stage_dir.rglob('*')):
        if src.is_symlink():
            raise ValueError(f"Ссылка в подготовленных файлах: {src}")
        if not src.is_file():
            continue
        rel = src.relative_to(stage_dir)
        dest = config_home / Path(*rel.parts[1:]) if rel.parts[0] == '.config' else user_home / rel
        safe_parents(dest, user_home)
        if dest.exists() and not dest.is_file() and not dest.is_symlink():
            raise ValueError(f"Назначение не является обычным файлом: {dest}")
        # Личный override переживает повторную установку профиля.
        if rel == Path('.config/hypr/conf/local.lua') and (dest.exists() or dest.is_symlink()):
            continue
        paths.append((src, dest))
    # Все назначения проверены. Пользовательские файлы записываются атомарно.
    backup.mkdir(parents=True, exist_ok=True, mode=0o700)
    receipts = []
    for src, dest in paths:
        rel = dest.relative_to(user_home)
        old_exists = dest.exists() or dest.is_symlink()
        mode = stat.S_IMODE(src.stat().st_mode)
        if old_exists and not dest.is_symlink() and dest.read_bytes() == src.read_bytes() and stat.S_IMODE(dest.stat().st_mode) == mode:
            continue
        old = backup / 'home' / rel
        if old_exists:
            old.parent.mkdir(parents=True, exist_ok=True)
            if dest.is_symlink():
                old.symlink_to(os.readlink(dest))
            else:
                shutil.copy2(dest, old)
        dest.parent.mkdir(parents=True, exist_ok=True)
        fd, temporary = tempfile.mkstemp(prefix='.n3ur0de-', dir=dest.parent)
        try:
            with os.fdopen(fd, 'wb') as stream:
                stream.write(src.read_bytes())
            os.chmod(temporary, mode)
            os.replace(temporary, dest)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
        receipts.append({"path": str(dest), "backup": str(old) if old_exists else None,
                         "sha256": hashlib.sha256(dest.read_bytes()).hexdigest()})
        write(backup / 'files.json', json.dumps(receipts, ensure_ascii=False, indent=2) + '\n', 0o600)
    if not receipts:
        write(backup / 'files.json', '[]\n', 0o600)
    print(f'Установлено/обновлено файлов: {len(receipts)}. Копии: {backup}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    build = sub.add_parser('stage')
    build.add_argument('--source', type=Path, required=True)
    build.add_argument('--output', type=Path, required=True)
    build.add_argument('--profile', choices=['desktop', 'vm'], required=True)
    build.add_argument('--gpu', choices=['nvidia', 'amd', 'intel', 'none'], required=True)
    build.add_argument('--wallpaper', type=Path)
    build.add_argument('--user-home', type=Path, required=True)
    build.add_argument('--config-home', type=Path, required=True)
    build.add_argument('--state-home', type=Path)
    check = sub.add_parser('check-paths')
    check.add_argument('--user-home', type=Path, required=True)
    check.add_argument('--config-home', type=Path, required=True)
    check.add_argument('--state-home', type=Path, required=True)
    install = sub.add_parser('deploy')
    install.add_argument('--source', type=Path, required=True)
    install.add_argument('--user-home', type=Path, required=True)
    install.add_argument('--config-home', type=Path, required=True)
    install.add_argument('--backup', type=Path, required=True)
    args = parser.parse_args()
    try:
        {'stage': stage, 'deploy': deploy, 'check-paths': check_paths}[args.command](args)
    except (ValueError, OSError, subprocess.SubprocessError) as exc:
        parser.exit(1, f'Ошибка подготовки/установки: {exc}\n')


if __name__ == '__main__':
    main()
