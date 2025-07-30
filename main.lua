-- main.lua - The entry point for Hex Survival Evolved.

function love.load()
    -- Load global assets and variables first
    require('globals')
    LoadGlobals()

    -- Require all the game modules in the correct order
    Utils = require('utils')
    Camera = require('camera')
    Entities = require('entities')
    World = require('world')
    Player = require('player')
    UI = require('ui')

    -- Initialize all the modules
    World.load()
    Player.load()
    Entities.load()
    UI.load()
    
    gameState = 'playing'
end

function love.update(dt)
    if gameState == 'paused' then return end

    Player.update(dt)
    Entities.update(dt)
    Camera.update()
end

function love.draw()
    Camera.attach()
    World.draw()
    Entities.drawWorldObjects()
    Player.draw()
    -- === THE FIX IS HERE ===
    -- The function is called Entities.draw(), not Entities.drawParticles()
    Entities.draw() 
    Camera.detach()

    UI.draw()
    if gameState == 'paused' then UI.drawPauseMenu() end
end

function love.keypressed(key)
    if key == "escape" then
        if gameState == 'playing' then gameState = 'paused'
        else gameState = 'playing' end
    end
    if gameState == 'playing' then Player.keypressed(key) end
end

function love.mousepressed(x, y, button)
    if gameState == 'paused' then
        local action = UI.handleMouseClick(x, y)
        if action == 'resume' then gameState = 'playing' end
        if action == 'newgame' then love.load() end
    end
end

-- Mobile touch controls
function love.touchpressed(id, x, y) if gameState == 'playing' then UI.touchpressed(id, x, y) end end
function love.touchmoved(id, x, y) if gameState == 'playing' then UI.touchmoved(id, x, y) end end
function love.touchreleased(id, x, y) if gameState == 'playing' then UI.touchreleased(id, x, y) end end