-- modules/ui.lua
local G = require 'modules.globals'
local Utils = require 'modules.utils'
local Data = require 'modules.data'
local Player = require 'modules.player'

local UI = {}
UI.joystick,UI.attackButton,UI.menuButton={},{},{}
UI.menu={isOpen=false,view='inventory',buttons={}}

function UI.load()
    local sW,sH=love.graphics.getDimensions()
    UI.joystick={active=false,id=nil,baseX=100,baseY=sH-100,nubX=100,nubY=sH-100,dx=0,dy=0,maxRadius=50,pressed=false}
    UI.attackButton={x=sW-80,y=sH-80,radius=48,pressed=false}
    UI.menuButton={x=sW-80,y=sH-190,radius=48,pressed=false}
    UI.menu.closeButton={x=sW-40,y=40,w=30,h=30}
end

function UI.update(dt)
    Player.moveDX,Player.moveDY=0,0
    if UI.joystick.active then Player.moveDX,Player.moveDY=UI.joystick.dx,UI.joystick.dy end
    if love.keyboard.isDown("w")or love.keyboard.isDown("up")then Player.moveDY=-1 end
    if love.keyboard.isDown("s")or love.keyboard.isDown("down")then Player.moveDY=1 end
    if love.keyboard.isDown("a")or love.keyboard.isDown("left")then Player.moveDX=-1 end
    if love.keyboard.isDown("d")or love.keyboard.isDown("right")then Player.moveDX=1 end
end

function UI.draw()
    love.graphics.setColor(1,1,1);love.graphics.print("Hunger: "..math.floor(Player.hunger),10,10)
    local jb_alpha=UI.joystick.pressed and 0.5 or 0.3;local ab_alpha=UI.attackButton.pressed and 0.9 or 0.6;local mb_alpha=UI.menuButton.pressed and 0.9 or 0.6
    love.graphics.setColor(1,1,1,jb_alpha);love.graphics.draw(Data.Images.joystick_base,UI.joystick.baseX,UI.joystick.baseY,0,1,1,64,64)
    if UI.joystick.active then love.graphics.setColor(1,1,1,0.8);love.graphics.draw(Data.Images.joystick_nub,UI.joystick.nubX,UI.joystick.nubY,0,1,1,32,32)end
    love.graphics.setColor(1,1,1,ab_alpha);love.graphics.draw(Data.Images.button_attack,UI.attackButton.x,UI.attackButton.y,0,1,1,48,48)
    love.graphics.setColor(1,1,1,mb_alpha);love.graphics.draw(Data.Images.button_menu,UI.menuButton.x,UI.menuButton.y,0,1,1,48,48)
    if UI.menu.isOpen then
        local sW,sH=love.graphics.getDimensions();local mx,my=love.mouse.getPosition();love.graphics.setColor(0,0,0,0.8);love.graphics.rectangle("fill",0,0,sW,sH)
        love.graphics.setColor(1,1,1);love.graphics.printf("MENU",0,50,sW,"center")
        local tabs={{x=50,y=110,w=100,h=30,text="Inventory",view="inventory"},{x=160,y=110,w=100,h=30,text="Crafting",view="crafting"},{x=270,y=110,w=100,h=30,text="Building",view="building"}}
        for i,tab in ipairs(tabs)do if UI.menu.view==tab.view then love.graphics.setColor(0.4,0.4,0.4)else love.graphics.setColor(0.2,0.2,0.2)end;if Utils.isPointInRect(mx,my,tab.x,tab.y,tab.w,tab.h)then love.graphics.setColor(0.5,0.5,0.5)end;love.graphics.rectangle("fill",tab.x,tab.y,tab.w,tab.h);love.graphics.setColor(1,1,1);love.graphics.printf(tab.text,tab.x,tab.y+5,tab.w,"center")end
        love.graphics.rectangle("line",UI.menu.closeButton.x,UI.menu.closeButton.y,UI.menu.closeButton.w,UI.menu.closeButton.h);love.graphics.printf("X",UI.menu.closeButton.x,UI.menu.closeButton.y+5,UI.menu.closeButton.w,"center")
        if UI.menu.view=='inventory'then local sS,p,c=48,8,math.floor((sW-100)/56);local sX,sY=50,150;local sI=0;for iK,q in pairs(Player.inventory)do if q>0 and Data.Images[iK]then local col=sI%c;local row=math.floor(sI/c);local x,y=sX+col*(sS+p),sY+row*(sS+p);love.graphics.draw(Data.Images.slot,x,y,0,sS/Data.Images.slot:getWidth(),sS/Data.Images.slot:getHeight());love.graphics.draw(Data.Images[iK],x,y,0,sS/Data.Images[iK]:getWidth(),sS/Data.Images[iK]:getHeight());love.graphics.print(q,x+sS-20,y+sS-20);sI=sI+1 end end
        else for i,btn in ipairs(UI.menu.buttons)do if Utils.isPointInRect(mx,my,btn.x,btn.y,btn.w,btn.h)then love.graphics.setColor(0.6,0.6,0.6)else love.graphics.setColor(1,1,1)end;love.graphics.draw(Data.Images.slot,btn.x,btn.y);love.graphics.draw(Data.Images[btn.itemKey],btn.x+4,btn.y+4,0,40/Data.Images[btn.itemKey]:getWidth(),40/Data.Images[btn.itemKey]:getHeight());love.graphics.print(Data.Items[btn.itemKey].name,btn.x+55,btn.y+15)end end
    end
end

return UI