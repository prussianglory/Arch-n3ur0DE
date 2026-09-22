#!/usr/bin/env bash
# Перечитать config Waybar без ручного kill + restart.
# В Waybar SIGUSR2 по умолчанию означает reload.

if pgrep -x waybar >/dev/null 2>&1; then
    pkill -SIGUSR2 waybar
else
    waybar >/dev/null 2>&1 &
fi
