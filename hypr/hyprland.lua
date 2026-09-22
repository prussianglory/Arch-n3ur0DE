-- Arch Dotfiles • Hyprland 0.56.2 • версия комплекта 1
-- Установить ВСЮ папку hypr в ~/.config/hypr (или $XDG_CONFIG_HOME/hypr).
-- Это главный файл: он подключает остальные модули в указанном порядке.
-- Документация: https://wiki.hypr.land/Configuring/Start/
--
-- Коротко о Lua:
--   -- начинает комментарий; строка заключается в кавычки;
--   true / false = включено / выключено; в таблицах ставим запятые;
--   require("conf.input") подключает conf/input.lua;
--   hl.config({...}) передаёт настройки самому Hyprland.
--
-- Сохранение конфига обычно применяет изменения автоматически.
-- Принудительно: hyprctl reload. Проверить ошибки: hyprctl configerrors.
-- Переменные окружения и автозапуск полностью проверяй после нового входа.

require("conf.environment") -- Окружение приложений, курсор, NVIDIA.
require("conf.monitors")    -- Экраны, разрешение, частота, масштаб.
require("conf.input")       -- EN/RU, мышь, повтор клавиш.
require("conf.appearance")  -- Цвета рамок, отступы, blur, тени.
require("conf.animations")  -- Кривые и скорость анимаций.
require("conf.workspaces")  -- Постоянные рабочие столы и scratchpad.
require("conf.rules")       -- Плавающие окна и слои Waybar/Fuzzel/SwayNC.
require("conf.bindings")    -- Все горячие клавиши и их описания.
require("conf.autostart")   -- Запуск компонентов один раз при входе.
require("conf.local")       -- Твои дополнительные настройки, загружаются последними.

-- Общие команды и цвета находятся в conf/settings.lua.
-- Этот модуль остальные файлы подключают самостоятельно.
-- Связи с будущими конфигами описаны в Arch-Dotfiles-INTEGRATIONS.md.
