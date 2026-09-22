#!/usr/bin/env bash
# Arch-n3ur0DE: установка в уже установленный Arch Linux после archinstall.
# Запускать обычным пользователем с sudo, после загрузки с установленного диска.
# Обязательный соседний файл: installer/prepare.py. Подробности: INSTALL.md.
set -Eeuo pipefail
umask 022

REPOSITORY='https://github.com/prussianglory/Arch-n3ur0DE.git'
REF='HEAD'
PROFILE=auto
GPU=auto
VM_TYPE=auto
DISPLAY_MANAGER=auto
NETWORK=networkmanager
APPS=1
CHANGE_SHELL=1
YES=0
DRY_RUN=0
SOURCE=''
EXPORT_DIR=''
WALLPAPER=''
WORK_DIR=''
BACKUP_DIR=''
LOG_FILE=''
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PREPARE="$SCRIPT_DIR/installer/prepare.py"

usage() {
    cat <<'EOF'
Использование: bash install.sh [параметры]

  --profile desktop|vm|auto      Профиль ПК или ВМ; по умолчанию выбор/определение.
  --gpu auto|nvidia|amd|intel|none
                                nvidia: открытые модули, для RTX 5060 и Turing+.
                                none: не менять видеодрайвер; для ВМ автоматически.
  --vm-type auto|virtualbox|kvm|vmware|generic
  --display-manager auto|sddm|keep|none
                                auto: сохранить существующий, иначе SDDM.
  --network networkmanager|keep  Перевести сеть на NetworkManager после reboot
                                либо сохранить управление сетью как есть.
  --wallpaper /путь/файл.png     Необязательные обои PNG/JPEG/WebP.
  --no-apps                     Пропустить Firefox/Code/Obsidian/просмотрщики.
  --keep-shell                  Не менять login shell на Zsh.
  --ref REF                     Git commit/ветка/tag вместо HEAD.
  --source /путь/репозиторий     Использовать локальные файлы без скачивания.
  --dry-run                     Проверить сборку и вывести план без установки.
  --export /новый/каталог        Только собрать пользовательские конфиги туда.
  --yes                         Без вопросов установщика и pacman.
  -h, --help                    Эта справка.

По умолчанию файлы скачиваются заново из указанного в REPOSITORY репозитория.
Конфиги резервируются перед заменой. Диски, загрузчик и пароли не меняются.
После обычной установки потребуется перезагрузка; она не запускается автоматически.
EOF
}
die() { printf '\nОшибка: %s\n' "$*" >&2; exit 1; }
note() { printf '\n%s\n' "$*"; }
warn() { printf '\nВнимание: %s\n' "$*" >&2; }
need_arg() { [[ $# -ge 2 && -n "$2" ]] || die "После $1 требуется значение"; }
cleanup() { [[ -z "$WORK_DIR" ]] || rm -rf -- "$WORK_DIR"; }
on_error() {
    local code=$? line=$1
    printf '\nУстановка остановлена (строка %s, код %s).\n' "$line" "$code" >&2
    [[ -z "$LOG_FILE" ]] || printf 'Лог: %s\n' "$LOG_FILE" >&2
    [[ -z "$BACKUP_DIR" ]] || printf 'Резервные копии: %s\n' "$BACKUP_DIR" >&2
    printf 'Исправь причину и запусти снова. Перезагрузка не выполнялась.\n' >&2
    exit "$code"
}
trap cleanup EXIT
trap 'on_error "$LINENO"' ERR

while (($#)); do
    case "$1" in
        --profile) need_arg "$@"; PROFILE=$2; shift 2 ;;
        --gpu) need_arg "$@"; GPU=$2; shift 2 ;;
        --vm-type) need_arg "$@"; VM_TYPE=$2; shift 2 ;;
        --display-manager) need_arg "$@"; DISPLAY_MANAGER=$2; shift 2 ;;
        --network) need_arg "$@"; NETWORK=$2; shift 2 ;;
        --ref) need_arg "$@"; REF=$2; shift 2 ;;
        --source) need_arg "$@"; SOURCE=$2; shift 2 ;;
        --wallpaper) need_arg "$@"; WALLPAPER=$2; shift 2 ;;
        --export) need_arg "$@"; EXPORT_DIR=$2; shift 2 ;;
        --no-apps) APPS=0; shift ;;
        --keep-shell) CHANGE_SHELL=0; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        --yes) YES=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "Неизвестный параметр $1; см. --help" ;;
    esac
done
[[ -f "$PREPARE" ]] || die 'Скачай весь комплект: рядом с install.sh нужен installer/prepare.py.'
case "$PROFILE" in auto|desktop|vm) ;; *) die 'Неверный --profile' ;; esac
case "$GPU" in auto|nvidia|amd|intel|none) ;; *) die 'Неверный --gpu' ;; esac
case "$VM_TYPE" in auto|virtualbox|kvm|vmware|generic) ;; *) die 'Неверный --vm-type' ;; esac
case "$DISPLAY_MANAGER" in auto|sddm|keep|none) ;; *) die 'Неверный --display-manager' ;; esac
case "$NETWORK" in networkmanager|keep) ;; *) die 'Неверный --network' ;; esac

# Export/dry-run можно запускать на другой ОС: они не трогают систему.
APPLY=1
if ((DRY_RUN)) || [[ -n "$EXPORT_DIR" ]]; then APPLY=0; fi
USER_HOME="${HOME:?HOME не задан}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$USER_HOME/.config}"
STATE_HOME="${XDG_STATE_HOME:-$USER_HOME/.local/state}"
case "$CONFIG_HOME/" in "$USER_HOME/"*) ;; *) die 'XDG_CONFIG_HOME должен находиться внутри домашнего каталога' ;; esac
case "$STATE_HOME/" in "$USER_HOME/"*) ;; *) die 'XDG_STATE_HOME должен находиться внутри домашнего каталога' ;; esac
for path_value in "$USER_HOME" "$CONFIG_HOME" "$STATE_HOME"; do
    [[ "$path_value" == /* && "$path_value" != *$'\n'* && "$path_value" != *$'\r'* ]] || die 'Некорректный пользовательский путь'
    case "/$path_value/" in */../*|*/./*) die 'Пользовательские пути должны быть абсолютными, без . и ..' ;; esac
done
[[ "$CONFIG_HOME" != "$USER_HOME" && "$STATE_HOME" != "$USER_HOME" ]] || die 'XDG-каталоги не должны совпадать с HOME'
if ((APPLY)); then
    ((EUID != 0)) || die 'Запусти от обычного пользователя: bash install.sh. Не sudo bash install.sh.'
    [[ -f /etc/arch-release ]] || die 'Поддерживается установленный Arch Linux'
    [[ $(uname -m) == x86_64 ]] || die 'Этот комплект рассчитан на x86_64'
    [[ ! -d /run/archiso && ! -f /etc/archiso/airootfs ]] || die 'Сначала загрузи установленный Arch; не запускай из установочного ISO'
    [[ -d /run/systemd/system ]] || die 'Нужна обычная загрузка с systemd, не arch-chroot'
    [[ -z ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || die 'Выйди из Hyprland и запусти установку из TTY, чтобы конфиги не перечитывались во время записи'
    command -v sudo >/dev/null || die 'Нужен sudo и пользователь с правами wheel, созданный через archinstall'
    command -v pacman >/dev/null || die 'Не найден pacman'
fi

virtualization='none'
if command -v systemd-detect-virt >/dev/null; then
    virtualization="$(systemd-detect-virt --vm 2>/dev/null || true)"
fi
if [[ "$PROFILE" == auto ]]; then
    detected=desktop
    [[ -z "$virtualization" || "$virtualization" == none ]] || detected=vm
    if ((YES == 0)) && [[ -t 0 ]]; then
        printf 'Профиль: 1 — настоящий ПК, 2 — виртуальная машина [по умолчанию %s]: ' "$detected"
        read -r answer
        case "$answer" in 1|desktop) PROFILE=desktop ;; 2|vm) PROFILE=vm ;; '') PROFILE=$detected ;; *) die 'Выбери 1 или 2' ;; esac
    else PROFILE=$detected; fi
fi
if [[ "$PROFILE" == vm ]]; then
    [[ "$GPU" == auto || "$GPU" == none ]] || die 'ВМ использует виртуальный адаптер. GPU passthrough настраивается отдельным профилем desktop.'
    GPU=none
    if [[ "$VM_TYPE" == auto ]]; then
        case "$virtualization" in
            oracle) VM_TYPE=virtualbox ;;
            kvm|qemu) VM_TYPE=kvm ;;
            vmware) VM_TYPE=vmware ;;
            *) VM_TYPE=generic ;;
        esac
    fi
else
    VM_TYPE=none
fi

# PCI sysfs существует до установки pciutils, поэтому auto не требует lspci.
if [[ "$GPU" == auto ]]; then
    GPU=none
    for device_dir in /sys/bus/pci/devices/*; do
        [[ -r "$device_dir/class" && -r "$device_dir/vendor" ]] || continue
        device_class="$(<"$device_dir/class")"
        [[ "$device_class" == 0x03* ]] || continue
        vendor="$(<"$device_dir/vendor")"
        case "$vendor" in
            0x10de) GPU=nvidia; break ;;
            0x1002) GPU=amd ;;
            0x8086) if [[ "$GPU" != amd ]]; then GPU=intel; fi ;;
        esac
    done
fi

# Существующий экран входа сохраняем в auto-режиме.
current_dm=''
if [[ -L /etc/systemd/system/display-manager.service ]]; then
    current_dm="$(basename -- "$(readlink -f /etc/systemd/system/display-manager.service)")"
fi
if [[ "$DISPLAY_MANAGER" == auto ]]; then
    if [[ -n "$current_dm" && "$current_dm" != sddm.service ]]; then DISPLAY_MANAGER=keep
    else DISPLAY_MANAGER=sddm; fi
fi
if [[ "$DISPLAY_MANAGER" == sddm && -n "$current_dm" && "$current_dm" != sddm.service ]]; then
    die "Уже выбран $current_dm. Используй --display-manager keep или сначала самостоятельно отключи прежний экран входа."
fi

note "Профиль: $PROFILE | GPU: $GPU | ВМ: $VM_TYPE | экран входа: $DISPLAY_MANAGER | сеть: $NETWORK"
if [[ "$GPU" == nvidia ]]; then
    note 'NVIDIA: профиль рассчитан на Turing и новее (включая RTX 5060), с открытыми модулями ядра.'
fi
if [[ "$PROFILE" == vm ]]; then
    note 'ВМ: включи 3D-ускорение в настройках хоста. VirtualBox: VMSVGA, 128 МБ видеопамяти; рекомендуется 4 vCPU и 8 ГБ RAM.'
fi
if ((APPLY && !YES)); then
    printf 'Скачать конфиги и установить окружение с указанными параметрами? [y/N] '
    read -r answer
    [[ "$answer" == y || "$answer" == Y ]] || exit 0
fi

PACMAN_FLAGS=(-Syu --needed)
((YES == 0)) || PACMAN_FLAGS+=(--noconfirm)
if ((APPLY)); then
    sudo -v
    # Только полное обновление (-Syu), без частичного pacman -Sy.
    if ! command -v git >/dev/null || ! command -v python3 >/dev/null; then
        sudo pacman "${PACMAN_FLAGS[@]}" git python
    fi
fi
command -v python3 >/dev/null || die 'Для подготовки нужен Python 3.11+: sudo pacman -Syu --needed python git'
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/arch-n3ur0de.XXXXXXXX")"
if [[ -n "$SOURCE" ]]; then
    SOURCE="$(cd -- "$SOURCE" && pwd -P)"
else
    command -v git >/dev/null || die 'Для скачивания нужен git'
    SOURCE="$WORK_DIR/repository"
    note "Скачиваю $REPOSITORY ($REF)"
    git init --quiet "$SOURCE"
    git -C "$SOURCE" fetch --quiet --depth 1 -- "$REPOSITORY" "$REF"
    git -C "$SOURCE" checkout --quiet --detach FETCH_HEAD
fi
COMMIT="$(git -C "$SOURCE" rev-parse HEAD 2>/dev/null || printf 'local-files')"
note "Источник: $SOURCE; commit: $COMMIT"

STAGE="$WORK_DIR/stage"
stage_args=(stage --source "$SOURCE" --output "$STAGE" --profile "$PROFILE" --gpu "$GPU"
    --user-home "$USER_HOME" --config-home "$CONFIG_HOME" --state-home "$STATE_HOME")
[[ -z "$WALLPAPER" ]] || stage_args+=(--wallpaper "$WALLPAPER")
python3 "$PREPARE" "${stage_args[@]}"
python3 "$PREPARE" check-paths --user-home "$USER_HOME" --config-home "$CONFIG_HOME" --state-home "$STATE_HOME"

# Все необходимые пакеты — официальные репозитории Arch; AUR не используется.
PACKAGES=(
    hyprland xorg-xwayland hyprland-guiutils kitty fuzzel waybar swaync
    hyprpaper hyprlock hypridle hyprpolkitagent
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk xdg-utils xdg-user-dirs
    pipewire pipewire-alsa pipewire-pulse wireplumber alsa-utils playerctl pavucontrol
    networkmanager network-manager-applet wpa_supplicant bluez bluez-utils blueman
    thunar thunar-volman thunar-archive-plugin tumbler gvfs gvfs-mtp udisks2 file-roller
    polkit dbus gsettings-desktop-schemas gnome-themes-extra adwaita-cursors papirus-icon-theme
    ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols-mono noto-fonts noto-fonts-cjk noto-fonts-emoji
    zsh zsh-completions zsh-autosuggestions zsh-syntax-highlighting starship fzf zoxide eza bat
    git base-devel python lua neovim nano btop ripgrep fd jq curl wget
    grim slurp wl-clipboard libnotify which util-linux procps-ng pciutils usbutils
    man-db man-pages less unzip zip 7zip mesa mesa-utils linux-firmware
)
if ((APPS)); then PACKAGES+=(firefox code obsidian mpv imv evince); fi
[[ "$DISPLAY_MANAGER" != sddm ]] || PACKAGES+=(sddm xorg-server xorg-xauth qt6-svg)

case "$GPU" in
    nvidia)
        PACKAGES+=(nvidia-utils egl-wayland)
        kernels=()
        if command -v pacman >/dev/null; then
            for kernel in linux linux-lts linux-zen linux-hardened; do
                if pacman -Qq "$kernel" >/dev/null 2>&1; then kernels+=("$kernel"); fi
            done
        elif ((APPLY == 0)); then
            kernels=(linux) # Только пример плана на не-Arch; на целевой ОС читается pacman.
        fi
        ((${#kernels[@]})) || die 'Не найдено поддерживаемое ядро linux/linux-lts/linux-zen/linux-hardened; для собственного ядра настрой драйвер и используй --gpu none'
        # Сохраняем уже выбранные пакетные модули для linux/linux-lts.
        driver=nvidia-open-dkms
        if ((${#kernels[@]} == 1)) && command -v pacman >/dev/null; then
            case "${kernels[0]}" in
                linux) if pacman -Qq nvidia-open >/dev/null 2>&1; then driver=nvidia-open; fi ;;
                linux-lts) if pacman -Qq nvidia-open-lts >/dev/null 2>&1; then driver=nvidia-open-lts; fi ;;
            esac
        fi
        PACKAGES+=("$driver")
        if [[ "$driver" == nvidia-open-dkms ]]; then
            for kernel in "${kernels[@]}"; do PACKAGES+=("${kernel}-headers"); done
        fi
        ;;
    amd) PACKAGES+=(vulkan-radeon) ;; # Базовый mesa уже включён в общий список.
    intel) PACKAGES+=(vulkan-intel intel-media-driver) ;;
esac
case "$VM_TYPE" in
    virtualbox) PACKAGES+=(virtualbox-guest-utils) ;;
    kvm) PACKAGES+=(qemu-guest-agent spice-vdagent) ;;
    vmware) PACKAGES+=(open-vm-tools) ;;
esac
# Автоопределение CPU microcode только на настоящем ПК.
if [[ "$PROFILE" == desktop ]]; then
    if grep -q GenuineIntel /proc/cpuinfo; then PACKAGES+=(intel-ucode)
    elif grep -q AuthenticAMD /proc/cpuinfo; then PACKAGES+=(amd-ucode); fi
fi
note 'Пакеты:'
printf '%s\n' "${PACKAGES[*]}"

if [[ -n "$EXPORT_DIR" ]]; then
    [[ ! -e "$EXPORT_DIR" ]] || die '--export требует ещё не существующий каталог'
    mkdir -p -- "$(dirname -- "$EXPORT_DIR")"
    cp -a -- "$STAGE" "$EXPORT_DIR"
    note "Подготовленные файлы: $EXPORT_DIR. Система не изменялась."
    exit 0
fi
if ((DRY_RUN)); then
    note 'Проверка структуры пройдена. Установка пакетов, изменение служб и домашних файлов не выполнялись.'
    exit 0
fi

# Пакеты сначала: при ошибке сети пользовательские конфиги ещё не заменены.
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-$$"
BACKUP_DIR="$STATE_HOME/arch-n3ur0de/backups/$RUN_ID"
mkdir -p -- "$BACKUP_DIR" "$STATE_HOME/arch-n3ur0de/logs"
chmod 700 -- "$BACKUP_DIR"
LOG_FILE="$STATE_HOME/arch-n3ur0de/logs/$RUN_ID.log"
touch -- "$LOG_FILE"
chmod 600 -- "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1
printf '%s\n' "$COMMIT" >"$BACKUP_DIR/source-commit"
printf 'profile=%s\ngpu=%s\nvm=%s\n' "$PROFILE" "$GPU" "$VM_TYPE" >"$BACKUP_DIR/profile"
sudo pacman "${PACMAN_FLAGS[@]}" "${PACKAGES[@]}"

# 0.56.x — проверенная ветка Lua API. Новая несовместимая версия не должна
# молча получать конфиги старого API и оставлять пользователя без рабочего стола.
hypr_version="$(pacman -Q hyprland | awk '{print $2}')"
hypr_version="${hypr_version#*:}"
[[ "$hypr_version" == 0.56.* ]] || die "Получен Hyprland $hypr_version; конфиги проверены для 0.56.x. Требуется адаптация конфигов до их установки."
[[ -r /etc/pam.d/hyprlock ]] || die 'Пакет hyprlock не предоставил /etc/pam.d/hyprlock; настройку PAM вручную не подменяем'

while IFS= read -r -d '' file; do luac -p "$file"; done < <(find "$STAGE/.config/hypr" -name '*.lua' -print0)
while IFS= read -r -d '' file; do zsh -n "$file"; done < <(find "$STAGE/.config/zsh" -type f \( -name '*.zsh' -o -name '.zshrc' \) -print0)
zsh -n "$STAGE/.zshenv"
# Проверяем Fuzzel с include, указывающим на подготовленную копию цветов.
python3 - "$STAGE" "$WORK_DIR/fuzzel-check.ini" <<'PY'
from pathlib import Path
import re, sys
stage, target = map(Path, sys.argv[1:])
text = (stage / '.config/fuzzel/fuzzel.ini').read_text()
text = re.sub(r'^include=.*$', 'include=' + str(stage / '.config/fuzzel/colors.ini'), text, flags=re.M)
target.write_text(text)
PY
fuzzel --check-config --config "$WORK_DIR/fuzzel-check.ini"

python3 "$PREPARE" deploy --source "$STAGE" --user-home "$USER_HOME" \
    --config-home "$CONFIG_HOME" --backup "$BACKUP_DIR"

# Привилегированные записи ограничены конкретными файлами, каждый резервируется.
system_file() {
    local destination="$1" source_file="$2" mode="${3:-644}"
    if sudo test -d "$destination"; then die "Вместо системного файла существует каталог: $destination"; fi
    if sudo test -f "$destination" && sudo cmp -s -- "$source_file" "$destination" \
        && [[ $(sudo stat -c %a -- "$destination") == "$mode" ]]; then return; fi
    if sudo test -e "$destination" || sudo test -L "$destination"; then
        sudo mkdir -p -- "$BACKUP_DIR/system$(dirname -- "$destination")"
        sudo cp -a -- "$destination" "$BACKUP_DIR/system$destination"
    else
        printf '%s\n' "$destination" >>"$BACKUP_DIR/new-system-files"
    fi
    sudo install -D -m "$mode" -- "$source_file" "$destination"
}

cat >"$WORK_DIR/session" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ -r "$HOME/.local/share/arch-n3ur0de/session-env" ]]; then
    source "$HOME/.local/share/arch-n3ur0de/session-env"
fi
export XDG_CURRENT_DESKTOP=Hyprland
export XDG_SESSION_DESKTOP=Hyprland
export XDG_SESSION_TYPE=wayland
if command -v start-hyprland >/dev/null; then compositor=start-hyprland
else compositor=Hyprland; fi
if [[ -n ${DBUS_SESSION_BUS_ADDRESS:-} ]]; then exec "$compositor"; fi
exec dbus-run-session -- "$compositor"
SH
system_file /usr/local/bin/n3ur0de-session "$WORK_DIR/session" 755
cat >"$WORK_DIR/session.desktop" <<'DESKTOP'
[Desktop Entry]
Name=n3ur0DE (Hyprland)
Comment=Hyprland desktop session
Exec=/usr/local/bin/n3ur0de-session
TryExec=/usr/local/bin/n3ur0de-session
Type=Application
DesktopNames=Hyprland
DESKTOP
system_file /usr/share/wayland-sessions/n3ur0de.desktop "$WORK_DIR/session.desktop"

if [[ "$DISPLAY_MANAGER" == sddm ]]; then
    cat >"$WORK_DIR/sddm.conf" <<'CONF'
[General]
DisplayServer=x11
[Theme]
Current=maldives
[Users]
RememberLastSession=true
CONF
    # Maldives поставляется с SDDM. Параметры автоматического входа не задаём.
    system_file /etc/sddm.conf.d/20-n3ur0de.conf "$WORK_DIR/sddm.conf"
fi
if [[ "$GPU" == nvidia ]]; then
    printf 'options nvidia_drm modeset=1\n' >"$WORK_DIR/nvidia.conf"
    system_file /etc/modprobe.d/20-n3ur0de-nvidia.conf "$WORK_DIR/nvidia.conf"
    if command -v mkinitcpio >/dev/null; then sudo mkinitcpio -P
    elif command -v dracut >/dev/null; then sudo dracut --regenerate-all --force
    else die 'Не найден mkinitcpio/dracut: требуется пересборка initramfs с параметрами NVIDIA'; fi
fi

# Состояния служб сохраняем, чтобы при необходимости вернуть прежний выбор.
systemctl list-unit-files --state=enabled >"$BACKUP_DIR/enabled-system-units.txt"
systemctl --user list-unit-files --state=enabled >"$BACKUP_DIR/enabled-user-units.txt" || true
if [[ "$NETWORK" == networkmanager ]]; then
    # Не останавливаем текущую сеть: переход произойдёт после reboot.
    network_units=(systemd-networkd.service systemd-networkd.socket systemd-networkd-wait-online.service dhcpcd.service)
    while read -r unit _; do
        [[ "$unit" == dhcpcd@*.service ]] && network_units+=("$unit")
    done < <(systemctl list-unit-files 'dhcpcd@*.service' --state=enabled --no-legend)
    for unit in "${network_units[@]}"; do
        if systemctl is-enabled --quiet "$unit" 2>/dev/null; then
            sudo systemctl disable "$unit"
            printf '%s\n' "$unit" >>"$BACKUP_DIR/disabled-network-units"
        fi
    done
    # iwd может быть backend самого NetworkManager. Отключаем только
    # самостоятельный iwd, когда NM не настроен использовать его.
    if ! NetworkManager --print-config 2>/dev/null | grep -Eq '^[[:space:]]*wifi\.backend[[:space:]]*=[[:space:]]*iwd'; then
        if systemctl is-enabled --quiet iwd.service 2>/dev/null; then
            sudo systemctl disable iwd.service
            printf '%s\n' iwd.service >>"$BACKUP_DIR/disabled-network-units"
        fi
    fi
    # Сохраняем рабочий DNS при стандартном resolv.conf -> systemd-resolved.
    if [[ -L /etc/resolv.conf && $(readlink -f /etc/resolv.conf) == /run/systemd/resolve/* ]]; then
        sudo systemctl enable systemd-resolved.service
    fi
    sudo systemctl enable NetworkManager.service
fi
sudo systemctl enable bluetooth.service
if [[ "$DISPLAY_MANAGER" == sddm ]]; then
    systemctl get-default >"$BACKUP_DIR/previous-default-target"
    sudo systemctl enable sddm.service
    sudo systemctl set-default graphical.target
fi
case "$VM_TYPE" in
    virtualbox) sudo systemctl enable vboxservice.service ;;
    kvm) sudo systemctl enable qemu-guest-agent.service ;;
    vmware) sudo systemctl enable vmtoolsd.service ;;
esac

# Наш autostart владеет Waybar/SwayNC/Hypridle: убираем дубли user units,
# сохраняя их исходное состояние. Активную сессию здесь не останавливаем.
for unit in waybar.service swaync.service hypridle.service hyprpaper.service; do
    if systemctl --user is-enabled --quiet "$unit" 2>/dev/null; then
        systemctl --user disable "$unit"
    fi
done
if systemctl --user show-environment >/dev/null 2>&1; then
    systemctl --user enable pipewire.socket pipewire-pulse.socket wireplumber.service
else
    warn 'Нет доступного user bus; звуковые службы запустятся через autostart после нового входа.'
fi
if ((CHANGE_SHELL)); then
    login_name="$(id -un)"
    getent passwd "$login_name" | cut -d: -f7 >"$BACKUP_DIR/previous-shell"
    grep -Fxq /usr/bin/zsh /etc/shells || die 'Пакет zsh не зарегистрировал /usr/bin/zsh в /etc/shells'
    sudo chsh -s /usr/bin/zsh "$login_name"
fi
xdg-user-dirs-update
fc-cache -f

# xdg-mime меняет mimeapps.list: резервируем его перед первым вызовом.
if [[ -e "$CONFIG_HOME/mimeapps.list" || -L "$CONFIG_HOME/mimeapps.list" ]]; then
    if [[ -L "$CONFIG_HOME/mimeapps.list" ]]; then
        warn 'mimeapps.list — ссылка; выбор приложений по умолчанию оставлен прежним.'
        MIME_DEFAULTS=0
    else
        cp -a -- "$CONFIG_HOME/mimeapps.list" "$BACKUP_DIR/mimeapps.list"
        MIME_DEFAULTS=1
    fi
else
    MIME_DEFAULTS=1
fi
if ((MIME_DEFAULTS)); then
if ((APPS)); then
    xdg-mime default firefox.desktop text/html x-scheme-handler/http x-scheme-handler/https || true
    xdg-mime default org.gnome.Evince.desktop application/pdf || true
fi
xdg-mime default thunar.desktop inode/directory || true
fi

note 'Установка завершена.'
printf 'Конфиги: %s\nРезервные копии: %s\nЛог: %s\n' "$CONFIG_HOME" "$BACKUP_DIR" "$LOG_FILE"
note 'Сохрани работу и перезагрузи компьютер: systemctl reboot'
note 'На экране входа выбери «n3ur0DE (Hyprland)». Из TTY: n3ur0de-session'
note 'Проверка после входа: hyprctl configerrors; bash ~/.config/hypr/scripts/check-lock-stack.sh'
if [[ -z "$WALLPAPER" ]]; then note 'Обоев в репозитории нет: установлен однотонный тёмный фон. Для картинки есть параметр --wallpaper.'; fi
if [[ "$NETWORK" == networkmanager ]]; then note 'Wi-Fi другого сетевого менеджера может потребовать повторного подключения через nmtui.'; fi
if [[ "$PROFILE" == vm ]]; then note 'Работа Hyprland в ВМ зависит от 3D-драйвера хоста; настройки VM-графики проверяются отдельно.'; fi
