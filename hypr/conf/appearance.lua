local c = require("conf.settings").colors

hl.config({
    general = {
        layout = "dwindle", -- Новые окна делят пространство на вложенные области.
        gaps_in = 5,        -- Внутренние отступы; соседние стороны складываются.
        gaps_out = 10,      -- Отступ от краёв рабочей области.
        border_size = 2,
        resize_on_border = true,
        allow_tearing = false,
        col = {
            active_border = {
                colors = { "rgb(" .. c.purple .. ")", "rgb(" .. c.violet .. ")" },
                angle = 45, -- Угол фиолетового градиента рамки.
            },
            inactive_border = "rgb(" .. c.inactive_border .. ")",
        },
    },
    decoration = {
        rounding = 10,      -- Радиус скругления углов, в пикселях.
        rounding_power = 2,
        -- Текст и интерфейсы остаются непрозрачными. Прозрачность только фона
        -- Kitty позже зададим в kitty.conf: background_opacity = 0.92.
        -- Не умножаем её дополнительно прозрачностью всего окна.
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        fullscreen_opacity = 1.0,
        blur = {
            enabled = true, -- Видно только там, где клиент сделал фон прозрачным.
            size = 6,
            passes = 2,     -- Больше проходов = сильнее blur и больше работа GPU.
            vibrancy = 0.15,
        },
        shadow = {
            enabled = true,
            range = 16,
            render_power = 3,
            color = "rgba(00000055)",
        },
    },
    dwindle = {
        preserve_split = true, -- Сохранять выбранное направление разделения.
    },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        background_color = "rgb(" .. c.background .. ")",
        -- До появления hyprpaper.conf фон будет просто тёмным.
        focus_on_activate = false, -- Фоновое приложение не перехватывает фокус.
        vrr = 0, -- VRR пока выключен: модель монитора и его поддержка неизвестны.
    },
})

-- Этот файл оформляет compositor. Цвета внутри GTK/Qt, Kitty и IDE
-- меняются в их собственных настройках, которые мы подготовим дальше.
