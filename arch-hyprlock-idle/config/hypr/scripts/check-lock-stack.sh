#!/usr/bin/env bash
set -euo pipefail

missing=0

for cmd in hyprlock hypridle hyprctl loginctl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        printf 'MISSING: %s\n' "$cmd"
        missing=1
    else
        printf 'OK:      %s -> %s\n' "$cmd" "$(command -v "$cmd")"
    fi
done

printf '\n'

if [[ -r /etc/pam.d/hyprlock ]]; then
    echo "OK:      /etc/pam.d/hyprlock"
else
    echo "WARNING: /etc/pam.d/hyprlock is missing or unreadable"
    missing=1
fi

for f in \
    "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprlock.conf" \
    "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hypridle.conf"
do
    if [[ -r "$f" ]]; then
        echo "OK:      $f"
    else
        echo "MISSING: $f"
        missing=1
    fi
done

printf '\n'
echo "Hyprlock version:"
hyprlock --version 2>/dev/null || true

echo
echo "Hypridle version:"
hypridle --version 2>/dev/null || true

exit "$missing"
