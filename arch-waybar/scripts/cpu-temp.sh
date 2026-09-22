#!/usr/bin/env bash
# =============================================================================
# CPU temperature -> Waybar JSON
# =============================================================================
# Почему отдельный скрипт, а не просто модуль "temperature":
# номера hwmonX могут меняться после загрузки/обновления ядра. Мы ищем датчик
# по имени драйвера: k10temp/coretemp/zenpower/cpu_thermal, а затем используем
# sysfs напрямую. Это не требует lm_sensors для работы самой панели.
# =============================================================================

set -u

read_millidegrees() {
    local file="$1"
    [[ -r "$file" ]] || return 1

    local value
    value="$(<"$file")"
    [[ "$value" =~ ^-?[0-9]+$ ]] || return 1

    # Большинство hwmon/thermal датчиков отдаёт миллиградусы Celsius.
    awk -v t="$value" 'BEGIN { printf "%.0f", t/1000 }'
}

find_hwmon_temp_file() {
    local wanted driver dir label input

    # Порядок важен: сначала типичные CPU sensors, затем менее частые варианты.
    for wanted in k10temp coretemp zenpower cpu_thermal; do
        for dir in /sys/class/hwmon/hwmon*; do
            [[ -r "$dir/name" ]] || continue
            driver="$(<"$dir/name")"
            [[ "$driver" == "$wanted" ]] || continue

            # Пытаемся выбрать осмысленный package/Tctl/Tdie/CPU sensor.
            for label in "$dir"/temp*_label; do
                [[ -r "$label" ]] || continue
                if grep -Eiq 'Tctl|Tdie|Package id 0|Package|CPU' "$label"; then
                    input="${label%_label}_input"
                    [[ -r "$input" ]] && { printf '%s\n' "$input"; return 0; }
                fi
            done

            # Fallback: первый доступный temp*_input.
            for input in "$dir"/temp*_input; do
                [[ -r "$input" ]] && { printf '%s\n' "$input"; return 0; }
            done
        done
    done

    return 1
}

find_thermal_zone_file() {
    local dir type

    for dir in /sys/class/thermal/thermal_zone*; do
        [[ -r "$dir/type" && -r "$dir/temp" ]] || continue
        type="$(<"$dir/type")"
        if [[ "$type" =~ (x86_pkg_temp|cpu_thermal|cpu-thermal|soc_thermal) ]]; then
            printf '%s\n' "$dir/temp"
            return 0
        fi
    done

    return 1
}

sensor_file=""
if sensor_file="$(find_hwmon_temp_file)"; then
    :
elif sensor_file="$(find_thermal_zone_file)"; then
    :
else
    printf '%s\n' '{"text":"󰔏  N/A","tooltip":"CPU temperature sensor не найден. Проверь /sys/class/hwmon и /sys/class/thermal.","class":"unavailable","percentage":0}'
    exit 0
fi

temp="$(read_millidegrees "$sensor_file")" || {
    printf '%s\n' '{"text":"󰔏  N/A","tooltip":"Не удалось прочитать CPU temperature sensor.","class":"unavailable","percentage":0}'
    exit 0
}

class="normal"
if (( temp >= 90 )); then
    class="critical"
elif (( temp >= 75 )); then
    class="warning"
fi

printf '{"text":"󰔏  %s°C","tooltip":"CPU temperature: %s°C\\nSensor: %s","class":"%s","percentage":%s}\n' \
    "$temp" "$temp" "$sensor_file" "$class" "$temp"
