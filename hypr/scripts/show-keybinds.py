#!/usr/bin/env python3
"""Справка Super+K: реальные привязки Hyprland в поисковом окне Fuzzel.

Источник — hyprctl -j binds, а подписи — description в bindings.lua.
Enter только закрывает справку. Команды из списка никогда не исполняются.
Параметр --print печатает список в терминал без Fuzzel.
"""
import json
import shutil
import subprocess
import sys


def clean(value):
    """Одна строка без управляющих символов, пригодная для списка Fuzzel."""
    return " ".join("".join(ch if ch.isprintable() else " " for ch in str(value)).split())


def format_binding(item):
    mask = int(item.get("modmask", 0))
    # Маска модификаторов XKB. Не путаем Mod2 (обычно NumLock) с Super.
    names = [(64, "Super"), (4, "Ctrl"), (8, "Alt"), (1, "Shift"),
             (2, "Caps"), (16, "Mod2"), (32, "Mod3"), (128, "Mod5")]
    keys = [name for bit, name in names if mask & bit]
    key = clean(item.get("key", ""))
    if not key:
        key = "catchall" if item.get("catch_all") else f"code:{item.get('keycode', '?')}"
    key = {"mouse:272": "ЛКМ", "mouse:273": "ПКМ", "Return": "Enter",
           "space": "Space", "mouse_down": "колесо вниз", "mouse_up": "колесо вверх"}.get(key, key)
    keys.append(key)
    submap = clean(item.get("submap", ""))
    prefix = f"[{submap}] " if submap else ""
    description = clean(item.get("description", "")) or "Без описания"
    return f"{prefix}{' + '.join(keys):<32}  {description}"


def main():
    try:
        result = subprocess.run(["hyprctl", "-j", "binds"], check=True,
                                text=True, capture_output=True, timeout=5)
        bindings = json.loads(result.stdout)
        if not isinstance(bindings, list):
            raise ValueError("hyprctl вернул неожиданный формат")
        rows = [format_binding(item) for item in bindings if isinstance(item, dict)]
    except (OSError, ValueError, subprocess.SubprocessError) as exc:
        print(f"Не удалось прочитать хоткеи активной сессии Hyprland: {exc}", file=sys.stderr)
        return 1

    # XKB-переключение не является hl.bind и отсутствует в hyprctl binds.
    rows.append("Дополнительное переключение раскладки XKB: см. kb_options в conf/input.lua.")
    text = "\n".join(rows) + "\n"
    if "--print" in sys.argv[1:] or not shutil.which("fuzzel"):
        print(text, end="")
        if "--print" not in sys.argv[1:]:
            subprocess.run(["hyprctl", "notify", "3", "5000", "rgb(cba6f7)",
                            "Для окна хоткеев установи fuzzel."], check=False)
        return 0

    # Используется будущий ~/.config/fuzzel/fuzzel.ini либо стандартный вид Fuzzel.
    # stdout игнорируем: выбор строки не должен запускать описанное действие.
    result = subprocess.run(["fuzzel", "--dmenu", "--prompt", "Хоткеи: ", "--width", "85"],
                            input=text, text=True, stdout=subprocess.DEVNULL, check=False)
    return 0 if result.returncode in (0, 1) else result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
