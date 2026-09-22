hl.config({
    input = {
        -- us ПЕРВАЯ: буквенные хоткеи задаются по английской раскладке.
        kb_layout = "us,ru",
        kb_variant = "",
        kb_model = "pc105",
        kb_options = "grp:alt_shift_toggle", -- Alt+Shift меняет EN/RU.
        -- Дополнительно есть Super+Space в bindings.lua.
        -- Чтобы оставить только Super+Space, задай kb_options = "".

        -- Привязки ориентируются на первую раскладку и сохраняют привычные
        -- физические позиции клавиш при переключении на русский.
        resolve_binds_by_sym = false,
        repeat_delay = 300, -- Миллисекунды до автоповтора удерживаемой клавиши.
        repeat_rate = 30,   -- Повторов в секунду.
        numlock_by_default = true,

        follow_mouse = 0,   -- Фокус по клику/хоткею. 1 = фокус следует за мышью.
        sensitivity = 0,   -- -1..1; 0 не добавляет поправку скорости.
        accel_profile = "flat", -- Равномерное движение без ускорения.
        touchpad = {
            natural_scroll = false,
            ["tap-to-click"] = true, -- Имя с дефисами в Lua пишется в ["..."].
            disable_while_typing = true,
        },
    },
    binds = {
        scroll_event_delay = 200, -- Защита от слишком быстрого листания столов колесом.
    },
})

-- Имя конкретной мыши/клавиатуры: hyprctl devices.
-- Настройки устройства перекрывают общие настройки только для него:
-- hl.device({ name = "точное-имя-из-hyprctl", sensitivity = -0.2 })

-- Индикатор EN/RU будет в Waybar: модуль hyprland/language.
-- Hyprland уже публикует раскладку через IPC; polling-скрипт для неё не нужен.
