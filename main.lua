-- Helper function for rectangle collision
function checkCollision(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and x2 < x1 + w1 and y1 < y2 + h2 and y2 < y1 + h1
end

-- Player Collision Box Constants
PLAYER_COLLISION_W = 20; PLAYER_COLLISION_H = 24
PLAYER_COLLISION_OX = 10; PLAYER_COLLISION_OY = 32

-- Global tables that need to be accessed by multiple functions
buildingGrid = {}
placedBuildings = {}

-- Helper function to check collision against all solid world objects
function isCollidingWithWorld(x, y)
    local checkX = x - PLAYER_COLLISION_OX
    local checkY = y - PLAYER_COLLISION_OY
    local worldW, worldH = MAP_WIDTH * TILE_SIZE, MAP_HEIGHT * TILE_SIZE

    checkX = (checkX % worldW + worldW) % worldW
    checkY = (checkY % worldH + worldH) % worldH
    
    local tileX = math.floor(checkX / TILE_SIZE) + 1
    local tileY = math.floor(checkY / TILE_SIZE) + 1
    if map[tileY] and map[tileY][tileX] and not map[tileY][tileX].biome.isPassable then
        return true
    end
    for i,obj in ipairs(worldObjects) do if obj.active then local oS=TILE_SIZE*(obj.scale or 1);if checkCollision(checkX,checkY,PLAYER_COLLISION_W,PLAYER_COLLISION_H,obj.x,obj.y,oS,oS)then return true end end end
    for i,b in ipairs(placedBuildings) do if checkCollision(checkX,checkY,PLAYER_COLLISION_W,PLAYER_COLLISION_H,b.x,b.y,b.width,b.height)then return true end end
    for k,obj in pairs(builtObjects) do local oX,oY=(obj.tileX-1)*TILE_SIZE,(obj.tileY-1)*TILE_SIZE;if checkCollision(checkX,checkY,PLAYER_COLLISION_W,PLAYER_COLLISION_H,oX,oY,TILE_SIZE,TILE_SIZE)then return true end end
    return false
end

function love.load()
    anim8 = require 'anim8'
    SeamlessNoise = require 'seamless'

    MAP_WIDTH = 250; MAP_HEIGHT = 250; TILE_SIZE = 32
    WORLD_PIXEL_WIDTH = MAP_WIDTH * TILE_SIZE
    WORLD_PIXEL_HEIGHT = MAP_HEIGHT * TILE_SIZE

    Items = {
        tree = { name = "Tree", drop = "wood", amount = 1 }, rock = { name = "Rock", drop = "stone", amount = 2 },
        iron_vein = { name = "Iron Vein", drop = "iron_ore", amount = 2 },
        pickaxe = { name = "Pickaxe", recipe = { { item = "wood", amount = 2 }, { item = "stone", amount = 3 } } },
        stone_wall = { name = "Stone Wall", recipe = { { item = "stone", amount = 2 } } }
    }
    Images = {
        character_sheet=love.graphics.newImage("character_sheet.png"), tree=love.graphics.newImage("tree.png"),
        rock=love.graphics.newImage("rock.png"), iron_vein=love.graphics.newImage("iron.png"),
        house=love.graphics.newImage("building_wall.png"), wall=love.graphics.newImage("wall.png"),
        road=love.graphics.newImage("road.png"), campfire=love.graphics.newImage("campfire.png")
    }

    Biomes = {
        deep_water  = { name="Deep Water",  color={0.1, 0.2, 0.4}, threshold=0.25, isPassable=false },
        shallow_water = { name="Shallow Water", color={0.2, 0.4, 0.8}, threshold=0.35, isPassable=false },
        beach       = { name="Beach",       color={0.9, 0.8, 0.5}, threshold=0.4, isPassable=true },
        grassy      = { name="Grassy",      color={0.2, 0.7, 0.2}, threshold=0.55, isPassable=true, treeChance=0.02 },
        forest      = { name="Forest",      color={0.1, 0.5, 0.1}, threshold=0.65, isPassable=true, treeChance=0.15 },
        suburban    = { name="Suburban",    color={0.6, 0.6, 0.6}, threshold=0.75, isPassable=true, isUrban=true },
        city        = { name="City",        color={0.4, 0.4, 0.45}, threshold=0.85, isPassable=true, isUrban=true },
        mountain    = { name="Mountain",    color={0.5, 0.5, 0.5}, threshold=1.0, isPassable=true, stoneChance=0.2 }
    }
    
    local seed = math.random(10000);
    noiseElevation = SeamlessNoise.new(MAP_WIDTH, MAP_HEIGHT, seed)
    map = {}; worldObjects = {}; builtObjects = {}; buildingGrid = {}; placedBuildings = {}
    
    -- Pass 1: Generate Terrain
    for y = 1, MAP_HEIGHT do
        map[y] = {}
        for x = 1, MAP_WIDTH do
            -- === THE FIX IS HERE ===
            local e = (noiseElevation:get(x, y) + 1) / 2
            local b = Biomes.mountain
            if e < Biomes.deep_water.threshold then b = Biomes.deep_water
            elseif e < Biomes.shallow_water.threshold then b = Biomes.shallow_water
            elseif e < Biomes.beach.threshold then b = Biomes.beach
            elseif e < Biomes.grassy.threshold then b = Biomes.grassy
            elseif e < Biomes.forest.threshold then b = Biomes.forest
            elseif e < Biomes.suburban.threshold then b = Biomes.suburban
            elseif e < Biomes.city.threshold then b = Biomes.city
            end
            map[y][x] = { biome = b }
        end
    end

    -- Find Safe Spawn Point
    local spawnX, spawnY = math.floor(MAP_WIDTH/2), math.floor(MAP_HEIGHT/2)
    while not map[spawnY][spawnX].biome.isPassable do spawnX=math.random(1,MAP_WIDTH); spawnY=math.random(1,MAP_HEIGHT) end

    -- Pass 2: Plan and Place Roads
    local roadSpacing=12;for y=1,MAP_HEIGHT do for x=1,MAP_WIDTH do if map[y][x].biome.isUrban and(x%roadSpacing==0 or y%roadSpacing==0)then map[y][x].isRoad=true end end end
    
    -- Pass 3: Place Houses adjacent to Roads
    local houseW,houseH=Images.house:getDimensions();local tilesW,tilesH=math.ceil(houseW/TILE_SIZE),math.ceil(houseH/TILE_SIZE)
    for y=1,MAP_HEIGHT-tilesH do for x=1,MAP_WIDTH-tilesW do if map[y][x].biome.isUrban then local isAdj=false;if(map[y-1]and map[y-1][x].isRoad)or(map[y+tilesH]and map[y+tilesH][x].isRoad)or(map[y][x-1]and map[y][x-1].isRoad)or(map[y][x+tilesW]and map[y][x+tilesW].isRoad)then isAdj=true end;if isAdj and math.random()<0.2 then local canPlace=true;for by=y,y+tilesH-1 do for bx=x,x+tilesW-1 do if(buildingGrid[by]and buildingGrid[by][bx])or map[by][bx].isRoad then canPlace=false;break end end;if not canPlace then break end end;if canPlace then table.insert(placedBuildings,{x=(x-1)*TILE_SIZE,y=(y-1)*TILE_SIZE,width=houseW,height=houseH,img=Images.house});for by=y,y+tilesH-1 do for bx=x,x+tilesW-1 do if not buildingGrid[by]then buildingGrid[by]={}end;buildingGrid[by][bx]=true end end end end end end end
    
    -- Pass 4: Spawn Natural Resources
    for y=1,MAP_HEIGHT do for x=1,MAP_WIDTH do if not(buildingGrid[y]and buildingGrid[y][x])then local tile=map[y][x];local scale=1;local sR=math.random();if sR>0.9 then scale=4 elseif sR>0.6 then scale=2 end;if tile.biome.treeChance and math.random()<tile.biome.treeChance then table.insert(worldObjects,{type='tree',x=(x-1)*TILE_SIZE,y=(y-1)*TILE_SIZE,active=true,scale=scale})end;if tile.biome.stoneChance and math.random()<tile.biome.stoneChance then local rT='rock';if math.random()<0.3 then rT='iron_vein'end;table.insert(worldObjects,{type=rT,x=(x-1)*TILE_SIZE,y=(y-1)*TILE_SIZE,active=true,scale=scale})end end end end

    player={x=(spawnX-0.5)*TILE_SIZE,y=(spawnY-0.5)*TILE_SIZE,speed=200,hunger=100,maxHunger=100,inventory={wood=0,stone=0,iron_ore=0,campfires=0,pickaxe=0,stone_wall=0}}
    local g=anim8.newGrid(48,48,Images.character_sheet:getWidth(),Images.character_sheet:getHeight())
    player.animations={down=anim8.newAnimation(g('1-3',1),0.2),left=anim8.newAnimation(g('1-3',2),0.2),right=anim8.newAnimation(g('1-3',3),0.2),up=anim8.newAnimation(g('1-3',4),0.2)};player.anim=player.animations.down;player.direction='down'
    camera={x=0,y=0};hungerTimer=0;hungerInterval=1.5;placedObjects={};
end


function love.keypressed(key)
    -- (This function is unchanged)
    if key=="e"then local iX,iY;local pCX,pCY=player.x,player.y-24;if player.direction=='up'then iX,iY=pCX,pCY-20 elseif player.direction=='down'then iX,iY=pCX,pCY+20 elseif player.direction=='left'then iX,iY=pCX-24,pCY elseif player.direction=='right'then iX,iY=pCX+24,pCY end;for i,obj in ipairs(worldObjects)do local oS=TILE_SIZE*(obj.scale or 1);if obj.active and iX>obj.x and iX<obj.x+oS and iY>obj.y and iY<obj.y+oS then local iD,y=Items[obj.type],Items[obj.type].amount*(obj.scale or 1);if obj.type=='tree'or obj.type=='rock'then print("Gathered "..iD.name.." got "..y.." "..iD.drop);player.inventory[iD.drop]=player.inventory[iD.drop]+y;obj.active=false elseif obj.type=='iron_vein'then if player.inventory.pickaxe>0 then print("Mined "..iD.name.." got "..y.." "..iD.drop);player.inventory[iD.drop]=player.inventory[iD.drop]+y;obj.active=false else print("Need pickaxe!")end end;break end end end
    if key=="1"then local r=Items.pickaxe.recipe;if player.inventory.wood>=r[1].amount and player.inventory.stone>=r[2].amount then player.inventory.wood=player.inventory.wood-r[1].amount;player.inventory.stone=player.inventory.stone-r[2].amount;player.inventory.pickaxe=player.inventory.pickaxe+1;print("Crafted Pickaxe!")else print("Need 2 Wood, 3 Stone.")end end
    if key=="2"then local r=Items.stone_wall.recipe;if player.inventory.stone>=r[1].amount then player.inventory.stone=player.inventory.stone-r[1].amount;player.inventory.stone_wall=player.inventory.stone_wall+1;print("Crafted Stone Wall!")else print("Need 2 Stone.")end end
    if key=="c"then if player.inventory.wood>=4 then player.inventory.wood=player.inventory.wood-4;player.inventory.campfires=player.inventory.campfires+1;print("Crafted Campfire!")else print("Need 4 Wood.")end end
    if key=="f"then if player.inventory.campfires>=1 then player.inventory.campfires=player.inventory.campfires-1;table.insert(placedObjects,{type='campfire',x=player.x,y=player.y,timer=10});print("Placed campfire!")end end
    if key=="b"then if player.inventory.stone_wall>0 then local tX,tY=math.floor((player.x-PLAYER_COLLISION_OX+PLAYER_COLLISION_W/2)/TILE_SIZE),math.floor((player.y-PLAYER_COLLISION_OY+PLAYER_COLLISION_H)/TILE_SIZE);local k=tX..","..tY;if not builtObjects[k]and not(buildingGrid[tY]and buildingGrid[tY][tX])then player.inventory.stone_wall=player.inventory.stone_wall-1;builtObjects[k]={type='wall',tileX=tX,tileY=tY};print("Built wall at "..k)else print("Cannot build here!")end end end
end


function love.update(dt)
    -- (This function is unchanged)
    player.anim:update(dt);local dX,dY=0,0;local iM=false;if love.keyboard.isDown("s")or love.keyboard.isDown("down")then dY=player.speed*dt;player.direction='down';iM=true end;if love.keyboard.isDown("w")or love.keyboard.isDown("up")then dY=-player.speed*dt;player.direction='up';iM=true end;if love.keyboard.isDown("d")or love.keyboard.isDown("right")then dX=player.speed*dt;player.direction='right';iM=true end;if love.keyboard.isDown("a")or love.keyboard.isDown("left")then dX=-player.speed*dt;player.direction='left';iM=true end
    local pX,pY=player.x+dX,player.y+dY;pX=(pX%WORLD_PIXEL_WIDTH+WORLD_PIXEL_WIDTH)%WORLD_PIXEL_WIDTH;pY=(pY%WORLD_PIXEL_HEIGHT+WORLD_PIXEL_HEIGHT)%WORLD_PIXEL_HEIGHT
    if dX~=0 then if not isCollidingWithWorld(pX,player.y)then player.x=pX end end;if dY~=0 then if not isCollidingWithWorld(player.x,pY)then player.y=pY end end
    player.x=(player.x%WORLD_PIXEL_WIDTH+WORLD_PIXEL_WIDTH)%WORLD_PIXEL_WIDTH;player.y=(player.y%WORLD_PIXEL_HEIGHT+WORLD_PIXEL_HEIGHT)%WORLD_PIXEL_HEIGHT
    player.anim=player.animations[player.direction];if iM then player.anim:resume()else player.animations[player.direction]:gotoFrame(1);player.anim:pause()end
    camera.x=player.x-love.graphics.getWidth()/2;camera.y=player.y-love.graphics.getHeight()/2
    hungerTimer=hungerTimer+dt;if hungerTimer>=hungerInterval then player.hunger=player.hunger-1;hungerTimer=0 end;if player.hunger<0 then player.hunger=0 end
    for i,obj in ipairs(placedObjects)do local cX,cY=player.x-PLAYER_COLLISION_OX,player.y-PLAYER_COLLISION_OY;local oW,oH=Images.campfire:getDimensions();if checkCollision(cX,cY,PLAYER_COLLISION_W,PLAYER_COLLISION_H,obj.x,obj.y,oW,oH)then player.hunger=player.hunger+(10*dt);if player.hunger>player.maxHunger then player.hunger=player.maxHunger end end;obj.timer=obj.timer-dt;if obj.timer<0 then table.remove(placedObjects,i)end end
end


function love.draw()
    -- (This function is unchanged)
    for offsetX=-1,1 do for offsetY=-1,1 do
        love.graphics.push();love.graphics.translate(offsetX*WORLD_PIXEL_WIDTH,offsetY*WORLD_PIXEL_HEIGHT)
        love.graphics.push();love.graphics.translate(-camera.x,-camera.y)
        local sX,eX=math.max(1,math.floor(camera.x/TILE_SIZE)),math.min(MAP_WIDTH,math.ceil((camera.x+love.graphics.getWidth())/TILE_SIZE)+1)
        local sY,eY=math.max(1,math.floor(camera.y/TILE_SIZE)),math.min(MAP_HEIGHT,math.ceil((camera.y+love.graphics.getHeight())/TILE_SIZE)+1)
        for y=sY,eY do for x=sX,eX do love.graphics.setColor(map[y][x].biome.color);love.graphics.rectangle("fill",(x-1)*TILE_SIZE,(y-1)*TILE_SIZE,TILE_SIZE,TILE_SIZE);if map[y][x].isRoad and not(buildingGrid[y]and buildingGrid[y][x])then love.graphics.setColor(1,1,1);love.graphics.draw(Images.road,(x-1)*TILE_SIZE,(y-1)*TILE_SIZE)end end end
        love.graphics.setColor(1,1,1)
        for i,obj in ipairs(worldObjects)do if obj.active then love.graphics.draw(Images[obj.type],obj.x,obj.y,0,obj.scale or 1,obj.scale or 1)end end
        for i,b in ipairs(placedBuildings)do love.graphics.draw(b.img,b.x,b.y)end
        for k,obj in pairs(builtObjects)do love.graphics.draw(Images.wall,(obj.tileX-1)*TILE_SIZE,(obj.tileY-1)*TILE_SIZE)end
        for i,obj in ipairs(placedObjects)do love.graphics.draw(Images[obj.type],obj.x,obj.y)end
        player.anim:draw(Images.character_sheet,player.x,player.y,nil,nil,nil,24,40)
        love.graphics.pop();love.graphics.pop()
    end end
    love.graphics.setColor(1,1,1);love.graphics.print("Hunger: "..math.floor(player.hunger),10,10)
    love.graphics.print("Wood: "..player.inventory.wood.." | Stone: "..player.inventory.stone.." | Iron: "..player.inventory.iron_ore,10,30)
    love.graphics.print("Pickaxes: "..player.inventory.pickaxe.." | Walls: "..player.inventory.stone_wall.." | Campfires: "..player.inventory.campfires,10,50)
    local c1,c2="[E] Gather | [B] Build Wall | [F] Place Campfire","[1] Craft Pickaxe | [2] Craft Wall | [C] Craft Campfire"
    love.graphics.print(c1,10,love.graphics.getHeight()-40);love.graphics.print(c2,10,love.graphics.getHeight()-20)
end