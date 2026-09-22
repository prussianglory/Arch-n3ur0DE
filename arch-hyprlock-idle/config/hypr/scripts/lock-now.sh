#!/usr/bin/env bash
set -euo pipefail

# Preferred manual-lock entry point for this rice.
#
# If Hypridle is alive, use logind so the same lock path is used for:
# - keybinds
# - Waybar power menu
# - idle timeout
# - suspend preparation
#
# If Hypridle is unexpectedly not running, fall back to launching Hyprlock
# directly so "lock now" still actually locks the desktop.

if pgrep -x hyprlock >/dev/null 2>&1; then
    exit 0
fi

if pgrep -x hypridle >/dev/null 2>&1; then
    loginctl lock-session
else
    exec hyprlock
fi
