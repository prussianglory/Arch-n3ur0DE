-- Узнать class и title окна: hyprctl clients.
-- Узнать namespace панели/оверлея: hyprctl layers.
-- class/namespace — регулярное выражение. ^ и $ ограничивают полное имя.

-- Компактный плавающий терминал запускается Super+Ctrl+Enter.
-- Обычный Super+Enter открывает плиточный Kitty.
hl.window_rule({
    name = "arch-floating-terminal",
    match = { class = "^arch-float-terminal$" },
    float = true,
    center = true,
    size = { "monitor_w * 0.62", "monitor_h * 0.64" },
})

-- Окно настройки звука удобнее держать по центру поверх плиток.
hl.window_rule({
    name = "arch-audio-settings",
    match = { class = "^(pavucontrol|org.pulseaudio.pavucontrol)$" },
    float = true,
    center = true,
    size = { "monitor_w * 0.50", "monitor_h * 0.60" },
})

-- Настоящие модальные диалоги (подтверждения, некоторые диалоги файлов).
-- Не привязываемся к тексту заголовка: он зависит от языка приложения.
hl.window_rule({
    name = "arch-modal-dialogs",
    match = { modal = true },
    float = true,
    center = true,
})

-- Верхняя панель, уведомления и launcher — слои, а не обычные окна.
-- Правила могут существовать до установки этих программ.
hl.layer_rule({
    name = "arch-ui-blur",
    match = { namespace = "^(waybar|launcher|swaync-control-center|swaync-notification-window)$" },
    blur = true,
    ignore_alpha = 0.2, -- Не размывать полностью прозрачные части слоя.
})

-- Если namespace новой версии программы отличается, проверь hyprctl layers
-- и обнови выражение. Fuzzel обычно использует namespace launcher.
