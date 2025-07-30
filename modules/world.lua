-- modules/world.lua
local G = require 'modules.globals'
local Utils = require 'modules.utils'
local Data = require 'modules.data'

local World = {}
World.map, World.worldObjects, World.builtObjects, World.spatialGrid = {}, {}, {}, {}

function World.generate(seed)
    World.map, World.worldObjects, World.builtObjects, World.spatialGrid = {}, {}, {}, {}
    love.math.setRandomSeed(seed)
    
    local noiseFrequency = 2.0
    print("Generating terrain...")
    for y=1,G.MAP_HEIGHT do World.map[y]={} for x=1,G.MAP_WIDTH do
        local nx,ny=x/G.MAP_WIDTH,y/G.MAP_HEIGHT;local u,v=nx*2*math.pi,ny*2*math.pi;local p1,p2,p3,p4=noiseFrequency*math.cos(u),noiseFrequency*math.sin(u),noiseFrequency*math.cos(v),noiseFrequency*math.sin(v)
        local e=(love.math.noise(p1,p2,p3,p4)+1)/2;e=e^1.5
        local m=(love.math.noise(p1+100,p2+100,p3+100,p4+100)+1)/2
        local bK="mountain";if e<Data.Biomes.deep_water.threshold then bK="deep_water"elseif e<Data.Biomes.shallow_water.threshold then bK="shallow_water"elseif e<Data.Biomes.beach.threshold then bK="beach"else if m<0.4 then if e<0.85 then bK="grassy"else bK="suburban"end elseif m<0.75 then if e<0.85 then bK="forest"else bK="city"end else bK="mountain"end end
        World.map[y][x]={biome=Data.Biomes[bK]}
    end end

    local spawnX,spawnY=math.floor(G.MAP_WIDTH/2),math.floor(G.MAP_HEIGHT/2)
    while not World.map[spawnY][spawnX].biome.isPassable do spawnX,spawnY=math.random(1,G.MAP_WIDTH),math.random(1,G.MAP_HEIGHT)end
    local playerSpawnTile={x=spawnX,y=spawnY}

    print("Generating roads...")
    for i=1,15 do local px,py=math.random(1,G.MAP_WIDTH),math.random(1,G.MAP_HEIGHT);if World.map[py][px].biome.isUrban then local dir=math.random(1,4);local dx,dy=0,0;if dir==1 then dx=1 elseif dir==2 then dx=-1 elseif dir==3 then dy=1 else dy=-1 end;for step=1,math.random(200,500)do local wX=((px-1)%G.MAP_WIDTH+G.MAP_WIDTH)%G.MAP_WIDTH+1;local wY=((py-1)%G.MAP_HEIGHT+G.MAP_HEIGHT)%G.MAP_HEIGHT+1;if World.map[wY]and World.map[wY][wX]then World.map[wY][wX].isRoad=true end;if math.random()<0.3 then dir=dir+(math.random()<0.5 and-1 or 1);dir=((dir-1)%4+4)%4+1;if dir==1 then dx=1;dy=0 elseif dir==2 then dx=-1;dy=0 elseif dir==3 then dx=0;dy=1 else dx=0;dy=-1 end end;px=px+dx;py=py+dy;local nY=((py-1)%G.MAP_HEIGHT+G.MAP_HEIGHT)%G.MAP_HEIGHT+1;local nX=((px-1)%G.MAP_WIDTH+G.MAP_WIDTH)%G.MAP_WIDTH+1;if World.map[nY]and World.map[nY][nX]and World.map[nY][nX].isRoad then break end end end end
    
    print("Spawning resources...")
    for y=1,G.MAP_HEIGHT do for x=1,G.MAP_WIDTH do if not World.map[y][x].isRoad and not(x==playerSpawnTile.x and y==playerSpawnTile.y)then for i,spawnData in ipairs(World.map[y][x].biome.spawn)do if math.random()<spawnData.chance then local pX,pY=Utils.hexToWorld(x,y);local newObj={type=spawnData.resource,x=pX,y=pY,active=true};table.insert(World.worldObjects,newObj);local key=math.floor(pX/256)..","..math.floor(pY/256);if not World.spatialGrid[key]then World.spatialGrid[key]={}end;table.insert(World.spatialGrid[key],newObj);break end end end end end
    
    print("World generation complete!")
    return Utils.hexToWorld(spawnX,spawnY)
end

function World.draw(camera)
    for oX=-1,1 do for oY=-1,1 do
        love.graphics.push();love.graphics.translate(oX*G.WORLD_PIXEL_WIDTH,oY*G.WORLD_PIXEL_HEIGHT);love.graphics.push();love.graphics.translate(-camera.x,-camera.y)
        local cX_s,cY_s=Utils.worldToHex(camera.x,camera.y);local cX_e,cY_e=Utils.worldToHex(camera.x+love.graphics.getWidth(),camera.y+love.graphics.getHeight())
        for y=cY_s-4,cY_e+4 do for x=cX_s-4,cX_e+4 do
            local wX=((x-1)%G.MAP_WIDTH+G.MAP_WIDTH)%G.MAP_WIDTH+1;local wY=((y-1)%G.MAP_HEIGHT+G.MAP_HEIGHT)%G.MAP_HEIGHT+1
            if World.map[wY]and World.map[wY][wX]then
                local cX,cY=Utils.hexToWorld(x,y);local v={};for i=0,5 do local a=2*math.pi/6*(i+0.5);table.insert(v,cX+G.HEX_RADIUS*math.cos(a));table.insert(v,cY+G.HEX_RADIUS*math.sin(a))end
                love.graphics.setColor(World.map[wY][wX].biome.color);love.graphics.polygon("fill",v)
                if World.map[wY][wX].isRoad then love.graphics.setColor(0.3,0.3,0.3);love.graphics.polygon("fill",v)end
            end
        end end
        love.graphics.setColor(1,1,1);local gridX,gridY=math.floor(camera.x/256),math.floor(camera.y/256)
        for i=-2,2 do for j=-2,2 do local key=(gridX+i)..","..(gridY+j);if World.spatialGrid[key]then for _,obj in ipairs(World.spatialGrid[key])do if obj.active then love.graphics.draw(Data.Images[obj.type],obj.x,obj.y)end end end end
        for i,b in ipairs(World.placedBuildings)do love.graphics.draw(b.img,b.x,b.y)end
        for k,obj in pairs(World.builtObjects)do local pX,pY=Utils.hexToWorld(obj.tileX,obj.tileY);love.graphics.draw(Data.Images[obj.type],pX-G.TILE_SIZE/2,pY-G.TILE_SIZE/2)end
        love.graphics.pop();love.graphics.pop()
    end end
end

return World