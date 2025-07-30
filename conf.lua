-- conf.lua
function love.conf(t)
    t.window.width = 1024
    t.window.height = 768
    t.window.title = "Hex Survival Evolved"
    t.modules.joystick = true
    t.modules.touch = true
end