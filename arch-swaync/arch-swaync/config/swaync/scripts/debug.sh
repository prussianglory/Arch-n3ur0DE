#!/usr/bin/env bash
set -euo pipefail
pkill -x swaync 2>/dev/null || true
exec env G_MESSAGES_DEBUG=swaync swaync
