#!/usr/bin/env bash
# =============================================================================
# NVIDIA GPU -> Waybar JSON
# =============================================================================
# Использует nvidia-smi из пакета nvidia-utils.
# По умолчанию берётся GPU 0. Если когда-нибудь появится второй GPU:
#   GPU_INDEX=1 ~/.config/waybar/scripts/gpu-nvidia.sh
# или можно прописать env прямо в exec через sh -c.
# =============================================================================

set -u

GPU_INDEX="${GPU_INDEX:-0}"

# Если nvidia-smi отсутствует, не ломаем Waybar, а показываем понятное состояние.
if ! command -v nvidia-smi >/dev/null 2>&1; then
    printf '%s\n' '{"text":"󰢮  N/A","tooltip":"nvidia-smi не найден. Установи nvidia-utils.","class":"unavailable","percentage":0}'
    exit 0
fi

# Одним вызовом nvidia-smi получаем всё, что нужно для панели и tooltip.
raw="$({
    nvidia-smi \
        -i "$GPU_INDEX" \
        --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw \
        --format=csv,noheader,nounits
} 2>/dev/null | head -n 1)"

if [[ -z "$raw" ]]; then
    printf '%s\n' '{"text":"󰢮  N/A","tooltip":"Не удалось получить данные NVIDIA GPU. Проверь драйвер и nvidia-smi.","class":"unavailable","percentage":0}'
    exit 0
fi

IFS=',' read -r name util mem_used mem_total temp power <<< "$raw"

# nvidia-smi разделяет поля запятыми и пробелами — аккуратно чистим пробелы.
trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

name="$(trim "$name")"
util="$(trim "$util")"
mem_used="$(trim "$mem_used")"
mem_total="$(trim "$mem_total")"
temp="$(trim "$temp")"
power="$(trim "$power")"

# nvidia-smi отдаёт VRAM в MiB. Для tooltip переводим в GiB.
mem_used_gib="$(awk -v m="$mem_used" 'BEGIN { printf "%.1f", m/1024 }')"
mem_total_gib="$(awk -v m="$mem_total" 'BEGIN { printf "%.1f", m/1024 }')"
power_round="$(awk -v p="$power" 'BEGIN { printf "%.0f", p }')"

# CSS-класс в зависимости от температуры.
class="normal"
if [[ "$temp" =~ ^[0-9]+$ ]]; then
    if (( temp >= 85 )); then
        class="critical"
    elif (( temp >= 75 )); then
        class="warning"
    fi
fi

# name у NVIDIA обычно безопасный, но экранируем обратный слеш и кавычки,
# чтобы JSON оставался валидным даже при необычном имени устройства.
json_escape() {
    local s="$1"
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    printf '%s' "$s"
}

name_json="$(json_escape "$name")"

printf '{"text":"󰢮  %s%%","tooltip":"%s\\nLoad: %s%%\\nVRAM: %s / %s GiB\\nTemperature: %s°C\\nPower: %s W","class":"%s","percentage":%s}\n' \
    "$util" "$name_json" "$util" "$mem_used_gib" "$mem_total_gib" "$temp" "$power_round" "$class" "$util"
