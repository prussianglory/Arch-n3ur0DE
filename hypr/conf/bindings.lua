local s = require("conf.settings")
local mod = s.mod
local a = s.apps
local scripts = s.hypr_dir .. "/scripts/"

-- Формат: bind("клавиши", "описание", действие, необязательные_флаги).
-- Описания нужны окну справки Super+K: оно читает реальные hyprctl binds.
-- Здесь меняешь и хоткей, и его подпись; отдельной копии списка нет.
local function bind(keys, description, dispatcher, flags)
    flags = flags or {}
    flags.description = description
    hl.bind(keys, dispatcher, flags)
end

-- Запуск приложения. Команды задаются в settings.lua.
bind(mod .. " + Return", "Приложения: терминал Kitty", hl.dsp.exec_cmd(a.terminal))
bind(mod .. " + CTRL + Return", "Приложения: компактный плавающий Kitty", hl.dsp.exec_cmd(a.terminal .. " --class arch-float-terminal"))
bind(mod .. " + D", "Приложения: поиск и запуск через Fuzzel", hl.dsp.exec_cmd(a.launcher))
bind(mod .. " + E", "Приложения: файловый менеджер", hl.dsp.exec_cmd(a.files))
bind(mod .. " + B", "Приложения: браузер", hl.dsp.exec_cmd(a.browser))
bind(mod .. " + C", "Приложения: редактор кода", hl.dsp.exec_cmd(a.editor))
bind(mod .. " + N", "Приложения: заметки", hl.dsp.exec_cmd(a.notes))

-- Окна: закрытие — штатный запрос приложению, не принудительное убийство.
bind(mod .. " + Q", "Окна: закрыть активное", hl.dsp.window.close())
bind(mod .. " + V", "Окна: плиточное / плавающее", hl.dsp.window.float({ action = "toggle" }))
bind(mod .. " + F", "Окна: полный экран", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
bind(mod .. " + SHIFT + F", "Окна: развернуть в рабочей области", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
bind(mod .. " + J", "Окна: изменить направление разделения dwindle", hl.dsp.layout("togglesplit"))

-- Super+стрелка — сменить фокус; +Shift — переместить окно в направлении.
-- Super+Ctrl+стрелка — менять размер, удерживание повторяет действие.
local directions = {
    { "left", "влево", -30, 0 },
    { "right", "вправо", 30, 0 },
    { "up", "вверх", 0, -30 },
    { "down", "вниз", 0, 30 },
}
for _, d in ipairs(directions) do
    bind(mod .. " + " .. d[1], "Фокус: " .. d[2], hl.dsp.focus({ direction = d[1] }))
    bind(mod .. " + SHIFT + " .. d[1], "Окна: переместить " .. d[2], hl.dsp.window.move({ direction = d[1] }))
    bind(mod .. " + CTRL + " .. d[1], "Размер: " .. d[2], hl.dsp.window.resize({ x = d[3], y = d[4], relative = true }), { repeating = true })
end

-- Рабочие столы: 0 соответствует столу 10.
-- Shift переносит окно без перехода за ним; флаг follow можно сменить на true.
for id = 1, 10 do
    local key = tostring(id % 10)
    bind(mod .. " + " .. key, "Столы: открыть " .. id, hl.dsp.focus({ workspace = id }))
    bind(mod .. " + SHIFT + " .. key, "Столы: отправить окно на " .. id, hl.dsp.window.move({ workspace = id, follow = false }))
end
bind(mod .. " + S", "Scratchpad: показать / скрыть", hl.dsp.workspace.toggle_special("scratch"))
bind(mod .. " + SHIFT + S", "Scratchpad: перенести активное окно", hl.dsp.window.move({ workspace = "special:scratch", follow = false }))
bind(mod .. " + mouse_down", "Столы: следующий существующий", hl.dsp.focus({ workspace = "e+1" }))
bind(mod .. " + mouse_up", "Столы: предыдущий существующий", hl.dsp.focus({ workspace = "e-1" }))

-- Удерживать Super и тянуть окно: ЛКМ перемещает, ПКМ меняет размер.
bind(mod .. " + mouse:272", "Мышь: перетаскивать окно", hl.dsp.window.drag(), { mouse = true })
bind(mod .. " + mouse:273", "Мышь: менять размер окна", hl.dsp.window.resize(), { mouse = true })

-- Раскладка переключается у всех подключённых клавиатур одновременно.
bind(mod .. " + space", "Ввод: переключить EN / RU", hl.dsp.exec_cmd("hyprctl switchxkblayout all next"))

-- Справка — доступный для поиска оверлей Fuzzel. Выбор строки НЕ выполняет
-- действие. Сочетания редактируются в этом файле (Super+Ctrl+K).
bind(mod .. " + K", "Справка: найти горячую клавишу", hl.dsp.exec_cmd("python3 " .. s.quote(scripts .. "show-keybinds.py")))
bind(mod .. " + CTRL + K", "Настройки: редактировать горячие клавиши", hl.dsp.exec_cmd(a.terminal .. " -e nano " .. s.quote(s.hypr_dir .. "/conf/bindings.lua")))
bind(mod .. " + SHIFT + R", "Настройки: перечитать Hyprland", hl.dsp.exec_cmd("hyprctl reload"))

-- Связи с компонентами следующего этапа. Скрипт проверяет готовность
-- hyprlock/SwayNC и показывает ошибку, если их ещё не настроили.
bind(mod .. " + L", "Сессия: заблокировать через Hyprlock", hl.dsp.exec_cmd("bash " .. s.quote(scripts .. "session-action.sh") .. " lock"))
bind(mod .. " + A", "Уведомления: открыть центр SwayNC", hl.dsp.exec_cmd("bash " .. s.quote(scripts .. "session-action.sh") .. " notifications"))

-- Снимки отправляются только в буфер обмена. Отмена выделения ничего не снимает.
bind("Print", "Снимок: выделить область в буфер", hl.dsp.exec_cmd("bash " .. s.quote(scripts .. "session-action.sh") .. " screenshot-area"))
bind("SHIFT + Print", "Снимок: все мониторы в буфер", hl.dsp.exec_cmd("bash " .. s.quote(scripts .. "session-action.sh") .. " screenshot-all"))

-- Звук: wpctl из WirePlumber. Громкость ограничена 100%.
bind("XF86AudioRaiseVolume", "Звук: громче", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true, locked = true })
bind("XF86AudioLowerVolume", "Звук: тише", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { repeating = true, locked = true })
bind("XF86AudioMute", "Звук: выключить / включить", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
bind("XF86AudioMicMute", "Звук: микрофон выключить / включить", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
bind("XF86AudioPlay", "Медиа: воспроизведение / пауза", hl.dsp.exec_cmd("playerctl play-pause"))
bind("XF86AudioNext", "Медиа: следующий трек", hl.dsp.exec_cmd("playerctl next"))
bind("XF86AudioPrev", "Медиа: предыдущий трек", hl.dsp.exec_cmd("playerctl previous"))

-- Намеренно нет мгновенного logout на короткой комбинации.
-- Для ручного выхода сохрани работу и выполни в терминале:
--   hyprctl dispatch 'hl.dsp.exit()'
-- Меню питания и корректное завершение UWSM добавим при настройке сессии.
