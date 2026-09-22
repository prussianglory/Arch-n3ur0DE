#!/usr/bin/env bash
set -euo pipefail
command -v swaync-client >/dev/null 2>&1 || {
    echo "Ошибка: swaync-client не найден. Установи пакет swaync." >&2
    exit 127
}
swaync-client -R
swaync-client -rs
echo "SwayNC config + CSS reloaded."
