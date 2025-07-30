-- main.lua

-- Load all our game modules
local G = require 'modules.globals'
local Utils = require 'modules.utils'
local Data = require 'modules.data'
local World = require 'modules.world'
local Player = require 'modules.player'
local UI = require 'modules.ui'

local gameState = "menu"
local currentSeed = ""
local loadingProgress = 0
local generationState = {}

local function startGame(seed)
    currentSeed = seed or tostring(os.time())
    gameState = "loading"
    generationState.y = 1
    loadingProgress = 0
end

local function finishWorldGen()
    local spawnX, spawnY = World.generate(tonumber(currentSeed))
    Player.load(spawnX, spawnY)
    UI.load()
    gameState = "playing"
end

function love.load()
    Data.loadImages()
    local sW,sH = love.graphics.getDimensions()
    UI.menu.buttons = {
        {x=sW/2-100, y=sH/2-50, w=200, h=40, text="New Game", action=function() gameState="seed_input"; currentSeed=""; UI.menu.buttons={{x=sW/2-100, y=sH/2+40, w=200, h=40, text="Start World", action=function() startGame(currentSeed) end}} end},
        {x=sW/2-100, y=sH/2+10, w=200, h=40, text="Load Game (WIP)", action=function() print("Load Game not implemented"); startGame(os.time()) end}
    }
end

function love.update(dt)
    if gameState == "loading" then
        if generationState.y <= G.MAP_HEIGHT then
            for i = 1, 30 do -- Generate 30 rows per frame
                if generationState.y <= G.MAP_HEIGHT then
                    -- This part is simplified for the main loop, actual generation is now in World.lua
                    generationState.y = generationState.y + 1
                end
            end
            loadingProgress = generationState.y / G.MAP_HEIGHT
        else
            finishWorldGen()
        end
        return
    end

    if gameState ~= "playing" or UI.menu.isOpen then return end

    UI.update(dt)
    Player.update(dt)

    camera.x = Player.x - love.graphics.getWidth()/2
    camera.y = Player.y - love.graphics.getHeight()/2
end

function love.draw()
    if gameState == "playing" then
        World.draw(camera)
        love.graphics.push(); love.graphics.translate(-camera.x, -camera.y)
        Player.draw()
        love.graphics.pop()
        UI.draw()
    elseif gameState == "menu" or gameState == "seed_input" then
        local sW,sH=love.graphics.getDimensions();local mx,my=love.mouse.getPosition();love.graphics.setColor(0.1,0.1,0.15);love.graphics.rectangle("fill",0,0,sW,sH)
        love.graphics.setColor(1,1,1);love.graphics.printf("Hex Survival",0,sH/2-100,sW,"center")
        if gameState=="seed_input"then love.graphics.printf("Enter Seed (or leave blank for random):",0,sH/2-40,sW,"center");love.graphics.rectangle("line",sW/2-150,sH/2-10,300,30);love.graphics.printf(currentSeed,0,sH/2-5,sW,"center")end
        for i,btn in ipairs(UI.menu.buttons)do if Utils.isPointInRect(mx,my,btn.x,btn.y,btn.w,btn.h)then love.graphics.setColor(0.8,0.8,1)else love.graphics.setColor(1,1,1)end;love.graphics.rectangle("line",btn.x,btn.y,btn.w,btn.h);love.graphics.printf(btn.text,btn.x,btn.y+10,btn.w,"center")end
    elseif gameState == "loading" then
        local sW,sH=love.graphics.getDimensions();love.graphics.setColor(0.1,0.1,0.15);love.graphics.rectangle("fill",0,0,sW,sH)
        love.graphics.setColor(1,1,1);love.graphics.printf("Generating World...",0,sH/2-20,sW,"center")
        love.graphics.rectangle("line",sW/2-150,sH/2+10,300,20);love.graphics.rectangle("fill",sW/2-150,sH/2+10,300*loadingProgress,20)
    end
end

function love.keypressed(key) if gameState=="playing" and key=="m"then UI.menu.isOpen=not UI.menu.isOpen;UI.menu.view='inventory'end;if gameState=="seed_input" then if key=="backspace"then currentSeed=string.sub(currentSeed,1,-2)end end end
function love.textinput(t) if gameState=="seed_input"then if tonumber(t)then currentSeed=currentSeed..t end end end
function love.touchpressed(id,x,y)
    if gameState=="menu"or gameState=="seed_input"then for i,btn in ipairs(UI.menu.buttons)do if Utils.isPointInRect(x,y,btn.x,btn.y,btn.w,btn.h)then btn.action()end end;return end
    UI.touchpressed(id,x,y)
end
function love.touchmoved(id,x,y,dx,dy) UI.touchmoved(id,x,y,dx,dy) end
function love.touchreleased(id,x,y) UI.touchreleased(id,x,y) end
function love.mousepressed(x,y,b) love.touchpressed(0,x,y) end
function love.mousereleased(x,y,b) love.touchreleased(0,x,y) end
function love.mousemoved(x,y,dx,dy) if love.mouse.isDown(1) then love.touchmoved(0,x,y,dx,dy) end end