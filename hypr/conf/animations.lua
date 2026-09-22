-- Короткие спокойные анимации. Для полного отключения: enabled = false.
hl.config({ animations = { enabled = true } })

hl.curve("archEase", {
    type = "bezier",
    points = { { 0.22, 1.0 }, { 0.36, 1.0 } },
})
hl.curve("archLinear", {
    type = "bezier",
    points = { { 0, 0 }, { 1, 1 } },
})

-- speed — длительность в единицах 100 мс: 2.5 примерно 250 мс.
-- leaf определяет, что анимируется. Дочерние ветви наследуют параметры.
hl.animation({ leaf = "global", enabled = true, speed = 2.5, bezier = "archEase" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.5, bezier = "archEase", style = "popin 96%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.8, bezier = "archEase", style = "popin 96%" })
hl.animation({ leaf = "fade", enabled = true, speed = 2.0, bezier = "archLinear" })
hl.animation({ leaf = "border", enabled = true, speed = 2.0, bezier = "archLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.5, bezier = "archEase", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2.2, bezier = "archEase", style = "fade" })
hl.animation({ leaf = "layers", enabled = true, speed = 2.0, bezier = "archEase", style = "fade" })
