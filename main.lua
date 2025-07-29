-- === NEW: HEXAGON CONSTANTS AND HELPER FUNCTIONS ===
HEX_RADIUS = 24 -- The distance from the center to a corner
HEX_WIDTH = math.sqrt(3) * HEX_RADIUS
HEX_HEIGHT = 2 * HEX_RADIUS
HEX_HORZ_SPACING = HEX_WIDTH
HEX_VERT_SPACING = HEX_HEIGHT * 3/4

-- Converts hex grid coordinates to world pixel coordinates
function hexToWorld(gridX, gridY)
    local pixelX = gridX * HEX_HORZ_SPACING
    local pixelY = gridY * HEX_VERT_SPACING
    if (gridY % 2) ~= 0 then -- Apply offset for odd rows
        pixelX = pixelX + HEX_WIDTH / 2
    end
    return pixelX, pixelY
end

-- Converts world pixel coordinates back to hex grid coordinates
function worldToHex(pixelX, pixelY)
    local roughY = pixelY / HEX_VERT_SPACING
    local y = math.floor(roughY + 0.5)
    
    local offsetX = 0
    if (y % 2) ~= 0 then offsetX = HEX_WIDTH / 2 end
    local roughX = (pixelX - offsetX) / HEX_HORZ_SPACING
    local x = math.floor(roughX + 0.5)

    -- Refine estimate by checking distance to neighbors (improves accuracy at edges)
    local candidates = {{x, y}, {x+1, y}, {x-1, y}, {x, y+1}, {x, y-1}}
    local minDist = -1
    local finalX, finalY = x, y

    for i, c in ipairs(candidates) do
        local cx, cy = hexToWorld(c[1], c[2])
        local dist = (pixelX - cx)^2 + (pixelY - cy)^2
        if minDist == -1 or dist < minDist then
            minDist = dist
            finalX, finalY = c[1], c[2]
        end
    end
    return finalX, finalY
end


-- Helper function for rectangle collision
function checkCollision(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and x2 < x1 + w1 and y1 < y2 + h2 and y2 < y1 + h1
end

-- Player Collision Box Constants
PLAYER_COLLISION_W = 20; PLAYER_COLLISION_H = 24
PLAYER_COLLISION_OX = 10; PLAYER_COLLISION_OY = 32

-- Global tables
buildingGrid = {}; placedBuildings = {}

-- Helper function to check collision against all solid world objects
function isCollidingWithWorld(x, y)
    local checkX = x - PLAYER_COLLISION_OX; local checkY = y - PLAYER_COLLISION_OY
    local worldW, worldH = MAP_WIDTH * HEX_HORZ_SPACING, MAP_HEIGHT * HEX_VERT_SPACING
    checkX = (checkX % worldW + worldW) % worldW; checkY = (checkY % worldH + worldH) % worldH
    
    local tileX, tileY = worldToHex(checkX, checkY)
    if map[tileY] and map[tileY][tileX] and not map[tileY][tileX].biome.isPassable then return true end

    for i, obj in ipairs(worldObjects) do if obj.active and checkCollision(checkX, checkY, PLAYER_COLLISION_W, PLAYER_COLLISION_H, obj.x, obj.y, TILE_SIZE, TILE_SIZE) then return true end end
    for i, b in ipairs(placedBuildings) do if checkCollision(checkX, checkY, PLAYER_COLLISION_W, PLAYER_COLLISION_H, b.x, b.y, b.width, b.height) then return true end end
    for k, obj in pairs(builtObjects) do local oX, oY = hexToWorld(obj.tileX, obj.tileY); if checkCollision(checkX, checkY, PLAYER_COLLISION_W, PLAYER_COLLISION_H, oX, oY, TILE_SIZE, TILE_SIZE) then return true end end
    return false
end

function isPointInCircle(px, py, cx, cy, r) return ((px-cx)^2 + (py-cy)^2) < r^2 end

-- Centralized interaction logic
function performInteraction()
    local interactX, interactY; local playerCenterX, playerCenterY = player.x, player.y - 24
    if player.direction == 'up' then interactX, interactY = playerCenterX, playerCenterY - 20
    elseif player.direction == 'down' then interactX, interactY = playerCenterX, playerCenterY + 20
    elseif player.direction == 'left' then interactX, interactY = playerCenterX - 24, playerCenterY
    elseif player.direction == 'right' then interactX, interactY = playerCenterX + 24, playerCenterY end

    for i, obj in ipairs(worldObjects) do
        if obj.active and interactX > obj.x and interactX < obj.x + TILE_SIZE and interactY > obj.y and interactY < obj.y + TILE_SIZE then
            local itemData, yield = Items[obj.type], Items[obj.type].amount
            if obj.type == 'tree' or obj.type == 'rock' then
                print("Gathered "..itemData.name.." got "..yield.." "..itemData.drop); player.inventory[itemData.drop] = player.inventory[itemData.drop] + yield; obj.active = false
            elseif obj.type == 'iron_vein' then
                if player.inventory.pickaxe > 0 then
                    print("Mined "..itemData.name.." got "..yield.." "..itemData.drop); player.inventory[itemData.drop] = player.inventory[itemData.drop] + yield; obj.active = false
                else print("You need a pickaxe to mine iron!") end
            end; break
        end
    end
end


function love.load()
    anim8 = require 'anim8'; SeamlessNoise = require 'seamless'
    MAP_WIDTH = 250; MAP_HEIGHT = 250; TILE_SIZE = 32 -- Kept for object size reference
    WORLD_PIXEL_WIDTH = MAP_WIDTH * HEX_HORZ_SPACING; WORLD_PIXEL_HEIGHT = MAP_HEIGHT * HEX_VERT_SPACING

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
        road=love.graphics.newImage("road.png"), campfire=love.graphics.newImage("campfire.png"),
        joystick_base=love.graphics.newImage("joystick_base.png"), joystick_nub=love.graphics.newImage("joystick_nub.png"),
        button_attack=love.graphics.newImage("button_attack.png"), button_menu=love.graphics.newImage("button_menu.png")
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
    
    local seed = math.random(10000); noiseElevation = SeamlessNoise.new(MAP_WIDTH, MAP_HEIGHT, seed)
    map={}; worldObjects={}; builtObjects={}; buildingGrid={}; placedBuildings={}
    for y=1,MAP_HEIGHT do map[y]={}; for x=1,MAP_WIDTH do local e=(noiseElevation:get(x,y)+1)/2; local b=Biomes.mountain; if e<Biomes.deep_water.threshold then b=Biomes.deep_water elseif e<Biomes.shallow_water.threshold then b=Biomes.shallow_water elseif e<Biomes.beach.threshold then b=Biomes.beach elseif e<Biomes.grassy.threshold then b=Biomes.grassy elseif e<Biomes.forest.threshold then b=Biomes.forest elseif e<Biomes.suburban.threshold then b=Biomes.suburban elseif e<Biomes.city.threshold then b=Biomes.city end; map[y][x]={biome=b} end end
    local spawnX, spawnY = math.floor(MAP_WIDTH/2), math.floor(MAP_HEIGHT/2); while not map[spawnY][spawnX].biome.isPassable do spawnX=math.random(1,MAP_WIDTH); spawnY=math.random(1,MAP_HEIGHT) end
    local roadSpacing=12; for y=1,MAP_HEIGHT do for x=1,MAP_WIDTH do if map[y][x].biome.isUrban and(x%roadSpacing==0 or y%roadSpacing==0)then map[y][x].isRoad=true end end end
    local houseW,houseH=Images.house:getDimensions(); local tilesW,tilesH=math.ceil(houseW/HEX_WIDTH),math.ceil(houseH/HEX_HEIGHT); for y=1,MAP_HEIGHT-tilesH do for x=1,MAP_WIDTH-tilesW do if map[y][x].biome.isUrban then local isAdj=false;if(map[y-1]and map[y-1][x].isRoad)or(map[y+tilesH]and map[y+tilesH][x].isRoad)or(map[y][x-1]and map[y][x-1].isRoad)or(map[y][x+tilesW]and map[y][x+tilesW].isRoad)then isAdj=true end;if isAdj and math.random()<0.2 then local canPlace=true;for by=y,y+tilesH-1 do for bx=x,x+tilesW-1 do if(buildingGrid[by]and buildingGrid[by][bx])or map[by][bx].isRoad then canPlace=false;break end end;if not canPlace then break end end;if canPlace then local pX,pY=hexToWorld(x,y);table.insert(placedBuildings,{x=pX,y=pY,width=houseW,height=houseH,img=Images.house});for by=y,y+tilesH-1 do for bx=x,x+tilesW-1 do if not buildingGrid[by]then buildingGrid[by]={}end;buildingGrid[by][bx]=true end end end end end end end
    for y=1,MAP_HEIGHT do for x=1,MAP_WIDTH do if not(buildingGrid[y]and buildingGrid[y][x])then local tile=map[y][x];if tile.biome.treeChance and math.random()<tile.biome.treeChance then local pX,pY=hexToWorld(x,y);table.insert(worldObjects,{type='tree',x=pX,y=pY,active=true})end;if tile.biome.stoneChance and math.random()<tile.biome.stoneChance then local rT='rock';if math.random()<0.3 then rT='iron_vein'end;local pX,pY=hexToWorld(x,y);table.insert(worldObjects,{type=rT,x=pX,y=pY,active=true})end end end end

    local playerSpawnX, playerSpawnY = hexToWorld(spawnX, spawnY)
    player={x=playerSpawnX,y=playerSpawnY,speed=200,hunger=100,maxHunger=100,inventory={wood=0,stone=0,iron_ore=0,campfires=0,pickaxe=0,stone_wall=0}}
    local g=anim8.newGrid(48,48,Images.character_sheet:getWidth(),Images.character_sheet:getHeight());player.animations={down=anim8.newAnimation(g('1-3',1),0.2),left=anim8.newAnimation(g('1-3',2),0.2),right=anim8.newAnimation(g('1-3',3),0.2),up=anim8.newAnimation(g('1-3',4),0.2)};player.anim=player.animations.down;player.direction='down'
    camera={x=0,y=0};hungerTimer=0;hungerInterval=1.5;placedObjects={};
    isMenuOpen=false;joystick={active=false,id=nil,baseX=0,baseY=0,nubX=0,nubY=0,dx=0,dy=0,maxRadius=50};local sW,sH=love.graphics.getDimensions();attackButton={x=sW-80,y=sH-80,radius=48};menuButton={x=sW-80,y=sH-190,radius=48}
end


function love.keypressed(key)
    if key == "e" then performInteraction() end
    if key == "m" then isMenuOpen = not isMenuOpen end
    if key=="1"then local r=Items.pickaxe.recipe;if player.inventory.wood>=r[1].amount and player.inventory.stone>=r[2].amount then player.inventory.wood=player.inventory.wood-r[1].amount;player.inventory.stone=player.inventory.stone-r[2].amount;player.inventory.pickaxe=player.inventory.pickaxe+1;print("Crafted Pickaxe!")else print("Need 2 Wood, 3 Stone.")end end
    if key=="2"then local r=Items.stone_wall.recipe;if player.inventory.stone>=r[1].amount then player.inventory.stone=player.inventory.stone-r[1].amount;player.inventory.stone_wall=player.inventory.stone_wall+1;print("Crafted Stone Wall!")else print("Need 2 Stone.")end end
end

function love.touchpressed(id,x,y,dx,dy,pressure) if isMenuOpen then isMenuOpen=false;return end;if isPointInCircle(x,y,attackButton.x,attackButton.y,attackButton.radius)then performInteraction()elseif isPointInCircle(x,y,menuButton.x,menuButton.y,menuButton.radius)then isMenuOpen=true elseif x<love.graphics.getWidth()/2 and not joystick.active then joystick.active=true;joystick.id=id;joystick.baseX,joystick.baseY=x,y;joystick.nubX,joystick.nubY=x,y end end
function love.touchmoved(id,x,y,dx,dy,pressure) if joystick.active and joystick.id==id then local vX,vY=x-joystick.baseX,y-joystick.baseY;local dist=math.sqrt(vX^2+vY^2);if dist>joystick.maxRadius then joystick.nubX=joystick.baseX+(vX/dist)*joystick.maxRadius;joystick.nubY=joystick.baseY+(vY/dist)*joystick.maxRadius;joystick.dx,joystick.dy=vX/dist,vY/dist else joystick.nubX,joystick.nubY=x,y;joystick.dx,joystick.dy=vX/joystick.maxRadius,vY/joystick.maxRadius end end end
function love.touchreleased(id,x,y,dx,dy,pressure) if joystick.active and joystick.id==id then joystick.active=false;joystick.id=nil;joystick.dx,joystick.dy=0,0 end end


function love.update(dt)
    if isMenuOpen then return end
    player.anim:update(dt);local iM=false;local mX,mY=0,0
    if joystick.active and(joystick.dx~=0 or joystick.dy~=0)then mX,mY=joystick.dx*player.speed*dt,joystick.dy*player.speed*dt;iM=true;if math.abs(joystick.dx)>math.abs(joystick.dy)then if joystick.dx>0 then player.direction='right'else player.direction='left'end else if joystick.dy>0 then player.direction='down'else player.direction='up'end end end
    local pX,pY=player.x+mX,player.y+mY;pX=(pX%WORLD_PIXEL_WIDTH+WORLD_PIXEL_WIDTH)%WORLD_PIXEL_WIDTH;pY=(pY%WORLD_PIXEL_HEIGHT+WORLD_PIXEL_HEIGHT)%WORLD_PIXEL_HEIGHT
    if mX~=0 then if not isCollidingWithWorld(pX,player.y)then player.x=pX end end;if mY~=0 then if not isCollidingWithWorld(player.x,pY)then player.y=pY end end
    player.x=(player.x%WORLD_PIXEL_WIDTH+WORLD_PIXEL_WIDTH)%WORLD_PIXEL_WIDTH;player.y=(player.y%WORLD_PIXEL_HEIGHT+WORLD_PIXEL_HEIGHT)%WORLD_PIXEL_HEIGHT
    player.anim=player.animations[player.direction];if iM then player.anim:resume()else player.animations[player.direction]:gotoFrame(1);player.anim:pause()end
    camera.x=player.x-love.graphics.getWidth()/2;camera.y=player.y-love.graphics.getHeight()/2
    hungerTimer=hungerTimer+dt;if hungerTimer>=hungerInterval then player.hunger=player.hunger-1;hungerTimer=0 end;if player.hunger<0 then player.hunger=0 end
    for i,obj in ipairs(placedObjects)do local cX,cY=player.x-PLAYER_COLLISION_OX,player.y-PLAYER_COLLISION_OY;local oW,oH=Images.campfire:getDimensions();if checkCollision(cX,cY,PLAYER_COLLISION_W,PLAYER_COLLISION_H,obj.x,obj.y,oW,oH)then player.hunger=player.hunger+(10*dt);if player.hunger>player.maxHunger then player.hunger=player.maxHunger end end;obj.timer=obj.timer-dt;if obj.timer<0 then table.remove(placedObjects,i)end end
end


function love.draw()
    for offsetX=-1,1 do for offsetY=-1,1 do
        love.graphics.push();love.graphics.translate(offsetX*WORLD_PIXEL_WIDTH,offsetY*WORLD_PIXEL_HEIGHT)
        love.graphics.push();love.graphics.translate(-camera.x,-camera.y)
        
        local sX,eX=math.max(1,math.floor(camera.x/HEX_HORZ_SPACING)-1),math.min(MAP_WIDTH,math.ceil((camera.x+love.graphics.getWidth())/HEX_HORZ_SPACING)+1)
        local sY,eY=math.max(1,math.floor(camera.y/HEX_VERT_SPACING)-1),math.min(MAP_HEIGHT,math.ceil((camera.y+love.graphics.getHeight())/HEX_VERT_SPACING)+1)
        
        -- NEW HEXAGON DRAWING LOOP
        for y=sY,eY do for x=sX,eX do
            local centerX, centerY = hexToWorld(x, y)
            local vertices = {}
            for i = 0, 5 do
                local angle = 2 * math.pi / 6 * (i + 0.5)
                table.insert(vertices, centerX + HEX_RADIUS * math.cos(angle))
                table.insert(vertices, centerY + HEX_RADIUS * math.sin(angle))
            end
            love.graphics.setColor(map[y][x].biome.color)
            love.graphics.polygon("fill", vertices)
            if map[y][x].isRoad and not(buildingGrid[y]and buildingGrid[y][x])then love.graphics.setColor(1,1,1);love.graphics.draw(Images.road,centerX-TILE_SIZE/2,centerY-TILE_SIZE/2)end
        end end
        
        love.graphics.setColor(1,1,1)
        for i,obj in ipairs(worldObjects)do if obj.active then love.graphics.draw(Images[obj.type],obj.x,obj.y)end end
        for i,b in ipairs(placedBuildings)do love.graphics.draw(b.img,b.x,b.y)end
        for k,obj in pairs(builtObjects)do local pX,pY=hexToWorld(obj.tileX,obj.tileY);love.graphics.draw(Images.wall,pX,pY)end
        for i,obj in ipairs(placedObjects)do love.graphics.draw(Images[obj.type],obj.x,obj.y)end
        player.anim:draw(Images.character_sheet,player.x,player.y,nil,nil,nil,24,40)
        
        love.graphics.pop();love.graphics.pop()
    end end
    
    love.graphics.setColor(1,1,1);love.graphics.print("Hunger: "..math.floor(player.hunger),10,10)
    if joystick.active then love.graphics.setColor(1,1,1,0.5);love.graphics.draw(Images.joystick_base,joystick.baseX,joystick.baseY,0,1,1,64,64);love.graphics.setColor(1,1,1,0.8);love.graphics.draw(Images.joystick_nub,joystick.nubX,joystick.nubY,0,1,1,32,32)end
    love.graphics.setColor(1,1,1,0.8);love.graphics.draw(Images.button_attack,attackButton.x,attackButton.y,0,1,1,48,48);love.graphics.draw(Images.button_menu,menuButton.x,menuButton.y,0,1,1,48,48)
    if isMenuOpen then local sW,sH=love.graphics.getDimensions();love.graphics.setColor(0,0,0,0.7);love.graphics.rectangle("fill",0,0,sW,sH);love.graphics.setColor(1,1,1);love.graphics.printf("MENU",0,50,sW,"center");love.graphics.printf("Tap anywhere to close",0,90,sW,"center");love.graphics.print("INVENTORY:",50,150);love.graphics.print("Wood: "..player.inventory.wood.." | Stone: "..player.inventory.stone,50,170);love.graphics.print("Pickaxes: "..player.inventory.pickaxe.." | Walls: "..player.inventory.stone_wall,50,190);love.graphics.print("CRAFTING:",50,250);love.graphics.print("[1] Craft Pickaxe (2 Wood, 3 Stone)",50,270);love.graphics.print("[2] Craft Stone Wall (2 Stone)",50,290)end
end