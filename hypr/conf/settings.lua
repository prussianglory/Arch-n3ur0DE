-- Общие значения. Здесь удобнее всего менять приложения и палитру.
-- Модуль возвращает таблицу; остальные файлы получают её через require().
local config_home = os.getenv("XDG_CONFIG_HOME")
if not config_home or config_home == "" then
    config_home = assert(os.getenv("HOME"), "HOME не задан") .. "/.config"
end

local settings = {
    hypr_dir = config_home .. "/hypr",
    mod = "SUPER", -- Клавиша Windows на обычной PC-клавиатуре.

    apps = {
        terminal = "kitty",
        launcher = "fuzzel",
        -- Следующие приложения — заменяемые стартовые значения, а не
        -- зафиксированный ранее выбор. Они должны быть установлены отдельно.
        browser = "firefox",
        files = "thunar",
        editor = "code",
        notes = "obsidian",
    },

    -- Здесь цвета без # и альфа-канала: ровно шесть hex-символов.
    -- Будущие Waybar, Kitty, Fuzzel и SwayNC получат эту же палитру.
    colors = {
        background = "11111b",
        surface = "1e1e2e",
        surface_alt = "313244",
        text = "cdd6f4",
        muted = "a6adc8",
        purple = "cba6f7",
        violet = "9d7cd8",
        inactive_border = "45475a",
    },
}

-- Экранируем ПУТЬ для shell. Полезно, если в имени каталога есть пробелы.
-- Готовую команду apps.terminal сюда передавать не нужно: она может
-- содержать собственные аргументы. Изменяй команды только своим текстом.
function settings.quote(value)
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

return settings
