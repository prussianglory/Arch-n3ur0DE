local s = require("conf.settings")

-- Событие вызывается при старте compositor, не при каждом hyprctl reload.
-- Скрипт проверит наличие программ И их будущих конфигов.
-- Так можно устанавливать комплект по частям: отсутствие Waybar не мешает входу.
hl.on("hyprland.start", function()
    hl.exec_cmd("bash " .. s.quote(s.hypr_dir .. "/scripts/autostart.sh"))
end)

-- После добавления нового компонента выйди/войди в сессию или выполни:
--   bash "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/autostart.sh"
-- Повторный запуск не плодит уже работающие процессы текущего пользователя.
