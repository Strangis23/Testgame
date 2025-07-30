-- ui.lua - Manages all user interface elements.

require('globals')

UI = {}

function UI.load()
    joystick={active=false,x=150,y=love.graphics.getHeight()-150,radius=80,knobX=150,knobY=love.graphics.getHeight()-150,knobRadius=40,touchID=nil}
    actionButtons={gather={x=love.graphics.getWidth()-200,y=love.graphics.getHeight()-150,r=50},attack={x=love.graphics.getWidth()-100,y=love.graphics.getHeight()-250,r=50}}
end

function UI.draw()
    -- Hotbar
    local slotSize,padding=64,10; local totalWidth=(slotSize+padding)*5-padding; local startX=(love.graphics.getWidth()-totalWidth)/2
    for i=1,5 do
        local x=startX+(i-1)*(slotSize+padding); local y=love.graphics.getHeight()-slotSize-padding
        if i==player.selected_slot then love.graphics.setColor(1,1,0,0.5) else love.graphics.setColor(0,0,0,0.5) end
        love.graphics.rectangle("fill",x,y,slotSize,slotSize,10)
        love.graphics.setColor(1,1,1,0.8); love.graphics.rectangle("line",x,y,slotSize,slotSize,10)
        local item_name=player.hotbar[i]; if item_name and Images[item_name] then
            local img=Images[item_name]; local scale=math.min(slotSize/img:getWidth(),slotSize/img:getHeight())*0.8
            love.graphics.setColor(1,1,1); love.graphics.draw(img,x+slotSize/2,y+slotSize/2,0,scale,scale,img:getWidth()/2,img:getHeight()/2)
            local count=player.inventory[item_name] or 0; if count>0 then love.graphics.print(count,x+slotSize-20,y+slotSize-20) end
        end
    end
    -- Vitals and Inventory
    love.graphics.setColor(0.2,0.2,0.2,0.7); love.graphics.rectangle("fill",5,5,210,80); love.graphics.setColor(1,0,0); love.graphics.rectangle("fill",10,10,200,20); love.graphics.setColor(0,1,0); love.graphics.rectangle("fill",10,10,(player.health/player.maxHealth)*200,20)
    love.graphics.setColor(1,1,1); love.graphics.print("Health",15,12); love.graphics.print("Hunger: "..math.floor(player.hunger),10,35); love.graphics.print("Wood: "..(player.inventory.wood or 0).." | Stone: "..(player.inventory.stone or 0),10,60)
    -- Action Prompts
    local c1="[E] Gather | [Q] Spin Attack | [B] Build | [F] Place"; local c2="[1-5] Select Item | [Esc] Menu"; love.graphics.print(c1,10,love.graphics.getHeight()-150); love.graphics.print(c2,10,love.graphics.getHeight()-130)
    
    -- Mobile Controls
    love.graphics.setColor(1,1,1,0.3); love.graphics.circle("fill",joystick.x,joystick.y,joystick.radius); love.graphics.circle("fill",actionButtons.gather.x,actionButtons.gather.y,actionButtons.gather.r); love.graphics.circle("fill",actionButtons.attack.x,actionButtons.attack.y,actionButtons.attack.r)
    love.graphics.setColor(1,1,1,0.5); love.graphics.circle("fill",joystick.knobX,joystick.knobY,joystick.knobRadius); love.graphics.setColor(1,1,1); love.graphics.print("E",actionButtons.gather.x-5,actionButtons.gather.y-10); love.graphics.print("Q",actionButtons.attack.x-5,actionButtons.attack.y-10)
end

function UI.drawPauseMenu()
    love.graphics.setColor(0,0,0,0.7); love.graphics.rectangle("fill",0,0,love.graphics.getWidth(),love.graphics.getHeight())
    love.graphics.setColor(1,1,1); love.graphics.setFont(love.graphics.newFont(40)); love.graphics.printf("Paused",0,love.graphics.getHeight()/2-100,love.graphics.getWidth(),"center")
    love.graphics.setFont(love.graphics.newFont(24));
    local btnW,btnH,padding=200,50,20; local btnX=(love.graphics.getWidth()-btnW)/2
    pauseButtons={resume={x=btnX,y=love.graphics.getHeight()/2-25,w=btnW,h=btnH,text="Resume"},newgame={x=btnX,y=love.graphics.getHeight()/2+padding+25,w=btnW,h=btnH,text="New Game"}}
    for name,btn in pairs(pauseButtons) do
        love.graphics.setColor(0.5,0.5,0.5); love.graphics.rectangle("fill",btn.x,btn.y,btn.w,btn.h,10)
        love.graphics.setColor(1,1,1); love.graphics.printf(btn.text,btn.x,btn.y+15,btn.w,"center")
    end
end

function UI.handleMouseClick(x,y)
    for name,btn in pairs(pauseButtons) do
        if x>btn.x and x<btn.x+btn.w and y>btn.y and y<btn.y+btn.h then
            return name
        end
    end
end

function UI.getJoystickInput()
    if joystick.active then
        local dx,dy=joystick.knobX-joystick.x,joystick.knobY-joystick.y
        local len=math.sqrt(dx^2+dy^2)
        if len > joystick.knobRadius*0.2 then return dx/len, dy/len end
    end
    return 0,0
end

function UI.touchpressed(id,x,y)
    if math.sqrt((x-joystick.x)^2+(y-joystick.y)^2) < joystick.radius^2 then joystick.active=true; joystick.touchID=id end
    if math.sqrt((x-actionButtons.gather.x)^2+(y-actionButtons.gather.y)^2) < actionButtons.gather.r^2 then Player.keypressed("e") end
    if math.sqrt((x-actionButtons.attack.x)^2+(y-actionButtons.attack.y)^2) < actionButtons.attack.r^2 then Player.keypressed("q") end
end
function UI.touchmoved(id,x,y)
    if joystick.active and joystick.touchID==id then local dx,dy=x-joystick.x,y-joystick.y; local dist=math.sqrt(dx^2+dy^2); if dist>joystick.radius then joystick.knobX,joystick.knobY=joystick.x+dx/dist*joystick.radius,joystick.y+dy/dist*joystick.radius else joystick.knobX,joystick.knobY=x,y end end
end
function UI.touchreleased(id,x,y)
    if joystick.active and joystick.touchID==id then joystick.active=false; joystick.knobX,joystick.knobY=joystick.x,joystick.y end
end

return UI