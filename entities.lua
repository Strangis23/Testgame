-- entities.lua - Manages all non-player entities.

require('globals')

Entities = {}

function Entities.load()
    worldObjects, placedObjects, enemies, particles = {}, {}, {}, {}
end

function Entities.update(dt)
    -- Enemy AI
    for i=#enemies,1,-1 do local e=enemies[i]; if e.health<=0 then table.remove(enemies,i) else local dist=math.sqrt((player.x-e.x)^2+(player.y-e.y)^2); if dist<300 then local angle=math.atan2(player.y-e.y,player.x-e.x); e.vx,e.vy=e.vx+math.cos(angle)*e.speed*dt*20,e.vy+math.sin(angle)*e.speed*dt*20 end; local speed=math.sqrt(e.vx^2+e.vy^2); if speed>e.speed then e.vx,e.vy=e.vx/speed*e.speed,e.vy/speed*e.speed end; e.x,e.y=e.x+e.vx*dt,e.y+e.vy*dt; if speed>20 then e.vx,e.vy=e.vx*0.9,e.vy*0.9 end; if dist<30 then player.health=math.max(0,player.health-e.damage*dt) end end end
    -- Particles
    for i=#particles,1,-1 do local p=particles[i]; p.x,p.y=p.x+p.vx*dt,p.y+p.vy*dt; p.life=p.life-dt; if p.life<=0 then table.remove(particles,i) end end
end

function Entities.draw()
    -- Particles are drawn on top of everything
    for _,p in ipairs(particles) do
        local alpha=(p.life/p.max_life); love.graphics.setColor(p.color[1],p.color[2],p.color[3],alpha)
        love.graphics.circle("fill",p.x,p.y,3)
    end
end

function Entities.drawWorldObjects()
    for offsetY=-2,2 do for offsetX=-2,2 do
        love.graphics.push(); love.graphics.translate(offsetX*MAP_PIXEL_WIDTH,offsetY*MAP_PIXEL_HEIGHT)
        love.graphics.setColor(1,1,1)
        for _,obj in ipairs(worldObjects) do if obj.active then love.graphics.draw(Images[obj.type],obj.x,obj.y,0,1,1,Images[obj.type]:getWidth()/2,Images[obj.type]:getHeight()/2) end end
        for _,e in ipairs(enemies) do love.graphics.draw(Images.slime,e.x,e.y,0,1,1,Images.slime:getWidth()/2,Images.slime:getHeight()/2) end
        for k,obj in pairs(builtObjects) do local x,y=Utils.hex_to_pixel(obj.q,obj.r); love.graphics.draw(Images[obj.type],x,y,0,1,1,Images[obj.type]:getWidth()/2,Images[obj.type]:getHeight()/2) end
        for _,obj in ipairs(placedObjects) do love.graphics.draw(Images[obj.type],obj.x,obj.y,0,1,1,Images[obj.type]:getWidth()/2,Images[obj.type]:getHeight()/2) end
        love.graphics.pop()
    end end
end

function Entities.addResource(type, q, r)
    local x,y = Utils.hex_to_pixel(q,r)
    table.insert(worldObjects, {type=type, x=x, y=y, active=true})
end

function Entities.addEnemy(q,r)
    local x,y = Utils.hex_to_pixel(q,r)
    table.insert(enemies, {x=x,y=y,health=30,speed=100,vx=0,vy=0,damage=10})
end

function Entities.gatherClosest()
    local closestObj, closestDistSq = nil, (HEX_SIZE*3)^2
    for _,obj in ipairs(worldObjects) do if obj.active then for ox=-1,1 do for oy=-1,1 do
        local objX,objY=(obj.x+ox*MAP_PIXEL_WIDTH),(obj.y+oy*MAP_PIXEL_HEIGHT); local distSq=(player.x-objX)^2+(player.y-objY)^2
        if distSq<closestDistSq then closestDistSq,closestObj=distSq,obj end
    end end end end
    if closestObj then
        local itemData=Items[closestObj.type]; player.inventory[itemData.drop]=(player.inventory[itemData.drop] or 0)+itemData.amount
        Utils.spawnParticles(closestObj.x,closestObj.y,10,itemData.particle_color)
        closestObj.active=false
    end
end

function Entities.place(itemType)
    player.inventory[itemType] = player.inventory[itemType] - 1
    table.insert(placedObjects, {type=itemType, x=player.x, y=player.y, timer=60})
end

function Entities.getEnemies()
    return enemies
end

return Entities