-- modules/player.lua
local G = require 'modules.globals'
local Utils = require 'modules.utils'
local Data = require 'modules.data'

local Player = {}

function Player.load(spawnX, spawnY)
    Player.x=spawnX; Player.y=spawnY; Player.speed=200; Player.hunger=100; Player.maxHunger=100
    Player.inventory=Data.baseInventory; Player.moveDX, Player.moveDY=0,0; Player.buildMode=nil; Player.direction='down'
    local g=anim8.newGrid(48,48,Data.Images.character_sheet:getWidth(),Data.Images.character_sheet:getHeight())
    Player.animations={down=anim8.newAnimation(g('1-3',1),0.2),left=anim8.newAnimation(g('1-3',2),0.2),right=anim8.newAnimation(g('1-3',3),0.2),up=anim8.newAnimation(g('1-3',4),0.2)}
    Player.anim=Player.animations.down
end

function Player.update(dt)
    local isMoving=(Player.moveDX~=0 or Player.moveDY~=0)
    if isMoving then
        if math.abs(Player.moveDX)>math.abs(Player.moveDY)then if Player.moveDX>0 then Player.direction='right'else Player.direction='left'end else if Player.moveDY>0 then Player.direction='down'else Player.direction='up'end end
        local mX,mY=Player.moveDX*Player.speed*dt,Player.moveDY*Player.speed*dt;local pX,pY=Player.x+mX,Player.y+mY
        if mX~=0 then if not Utils.isCollidingWithWorld(pX,Player.y)then Player.x=pX end end
        if mY~=0 then if not Utils.isCollidingWithWorld(Player.x,pY)then Player.y=pY end end
    end
    Player.x=(Player.x%G.WORLD_PIXEL_WIDTH+G.WORLD_PIXEL_WIDTH)%G.WORLD_PIXEL_WIDTH
    Player.y=(Player.y%G.WORLD_PIXEL_HEIGHT+G.WORLD_PIXEL_HEIGHT)%G.WORLD_PIXEL_HEIGHT
    Player.anim=Player.animations[Player.direction];if isMoving then Player.anim:resume()else Player.animations[Player.direction]:gotoFrame(1);Player.anim:pause()end
    if Player.buildMode then local ptx,pty=Utils.worldToHex(Player.x,Player.y);Player.buildPreviewX,Player.buildPreviewY=Utils.hexToWorld(ptx,pty)end
end

function Player.draw()
    Player.anim:draw(Data.Images.character_sheet,Player.x,Player.y,nil,nil,nil,24,40)
    if Player.buildMode then
        local pX,pY=Player.buildPreviewX,Player.buildPreviewY
        love.graphics.setColor(1,1,1,0.5);love.graphics.draw(Data.Images[Player.buildMode],pX-G.TILE_SIZE/2,pY-G.TILE_SIZE/2);love.graphics.setColor(1,1,1)
    end
end

return Player