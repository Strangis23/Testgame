-- ===================================================================
-- GAME CONSTANTS
-- ===================================================================
MAP_WIDTH = 1000
MAP_HEIGHT = 1000
CHUNK_SIZE = 16
TILE_SIZE = 32

-- Hexagon Grid Constants
HEX_RADIUS = 24
HEX_WIDTH = math.sqrt(3) * HEX_RADIUS
HEX_HEIGHT = 2 * HEX_RADIUS
HEX_HORZ_SPACING = HEX_WIDTH
HEX_VERT_SPACING = HEX_HEIGHT * 3/4

WORLD_PIXEL_WIDTH = MAP_WIDTH * HEX_HORZ_SPACING
WORLD_PIXEL_HEIGHT = MAP_HEIGHT * HEX_VERT_SPACING

-- Player Collision Box Constants
PLAYER_COLLISION_W = 20
PLAYER_COLLISION_H = 24
PLAYER_COLLISION_OX = 10
PLAYER_COLLISION_OY = 32

-- ===================================================================
-- GLOBAL VARIABLES & DATA TABLES
-- ===================================================================
chunks, map, worldObjects, placedBuildings, builtObjects = {}, {}, {}, {}, {}
player, camera, joystick, attackButton, menuButton = {}, {}, {}, {}, {}
menu = { isOpen = false, view = 'crafting', buttons = {} }
Items, Images, Biomes = {}, {}, {}
noiseElevation = nil

-- ===================================================================
-- LOCAL HELPER FUNCTIONS (Defined before they are used)
-- ===================================================================

local function hexToWorld(gridX, gridY)
    local pixelX = (gridX - 1) * HEX_HORZ_SPACING
    if (gridY % 2) == 0 then pixelX = pixelX + HEX_WIDTH / 2 end
    local pixelY = (gridY - 1) * HEX_VERT_SPACING
    return pixelX, pixelY
end

local function worldToHex(pixelX, pixelY)
    local roughY = pixelY / HEX_VERT_SPACING
    local y = math.floor(roughY + 0.5) + 1
    local offsetX = 0
    if (y % 2) == 0 then offsetX = HEX_WIDTH / 2 end
    local roughX = (pixelX - offsetX) / HEX_HORZ_SPACING
    local x = math.floor(roughX + 0.5) + 1
    return x, y
end

local function checkCollision(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and x2 < x1 + w1 and y1 < y2 + h2 and y2 < y1 + h1
end

local function isCollidingWithWorld(x, y)
    local checkX = x - PLAYER_COLLISION_OX; local checkY = y - PLAYER_COLLISION_OY
    local worldW, worldH = WORLD_PIXEL_WIDTH, WORLD_PIXEL_HEIGHT
    checkX = (checkX % worldW + worldW) % worldW; checkY = (checkY % worldH + worldH) % worldH
    local tileX, tileY = worldToHex(checkX + PLAYER_COLLISION_W/2, checkY + PLAYER_COLLISION_H/2)
    if map[tileY] and map[tileY][tileX] and not map[tileY][tileX].biome.isPassable then return true end
    for i, obj in ipairs(worldObjects) do if obj.active and checkCollision(checkX, checkY, PLAYER_COLLISION_W, PLAYER_COLLISION_H, obj.x, obj.y, TILE_SIZE, TILE_SIZE) then return true end end
    for i, b in ipairs(placedBuildings) do if checkCollision(checkX, checkY, PLAYER_COLLISION_W, PLAYER_COLLISION_H, b.x, b.y, b.width, b.height) then return true end end
    for k, obj in pairs(builtObjects) do local oX, oY = hexToWorld(obj.tileX, obj.tileY); if checkCollision(checkX, checkY, PLAYER_COLLISION_W, PLAYER_COLLISION_H, oX, oY, TILE_SIZE, TILE_SIZE) then return true end end
    return false
end

local function isPointInCircle(px, py, cx, cy, r) return ((px-cx)^2 + (py-cy)^2) < r^2 end
local function isPointInRect(px, py, rx, ry, rw, rh) return px > rx and px < rx + rw and py > ry and py < ry + rh end

local function performInteraction()
    local interactX, interactY; local playerCenterX, playerCenterY = player.x, player.y - 24
    if player.direction == 'up' then interactX, interactY = playerCenterX, playerCenterY - 20
    elseif player.direction == 'down' then interactX, interactY = playerCenterX, playerCenterY + 20
    elseif player.direction == 'left' then interactX, interactY = playerCenterX - 24, playerCenterY
    elseif player.direction == 'right' then interactX, interactY = playerCenterX + 24, playerCenterY end
    for i, obj in ipairs(worldObjects) do
        if obj.active and interactX > obj.x and interactX < obj.x + TILE_SIZE and interactY > obj.y and interactY < obj.y + TILE_SIZE then
            local itemData, yield = Items[obj.type], Items[obj.type].yield
            if itemData.requires then
                if player.inventory[itemData.requires] > 0 then
                    print("Gathered " .. itemData.name); for res, amt in pairs(yield) do player.inventory[res] = player.inventory[res] + amt end; obj.active = false
                else print("You need a " .. itemData.requires) end
            else
                print("Gathered " .. itemData.name); for res, amt in pairs(yield) do player.inventory[res] = player.inventory[res] + amt end; obj.active = false
            end; break
        end
    end
end

local function populateCraftingMenu()
    menu.buttons = {}
    local btnY = 150
    for key, data in pairs(Items) do
        if data.recipe then
            local label = data.name .. ": "; for res, amt in pairs(data.recipe) do label = label .. amt .. " " .. Items[res].name .. ", " end
            table.insert(menu.buttons, {
                x=50,y=btnY,w=400,h=30,text=label,
                action=function() local canCraft=true;for res,amt in pairs(data.recipe)do if player.inventory[res]<amt then canCraft=false;break end end;if canCraft then for res,amt in pairs(data.recipe)do player.inventory[res]=player.inventory[res]-amt end;player.inventory[key]=player.inventory[key]+1;print("Crafted: "..data.name)else print("Not enough resources for: "..data.name)end end
            }); btnY=btnY+35
        end
    end
end

local function populateBuildingMenu()
    menu.buttons = {}; local btnY = 150
    for key, data in pairs(Items) do
        if data.buildable then
            table.insert(menu.buttons, {
                x=50,y=btnY,w=400,h=30,text="Build "..data.name,
                action=function() if player.inventory[key]>0 then player.buildMode=key;menu.isOpen=false;print("Entering build mode for: "..data.name)else print("You don't have any "..data.name.." to build.")end end
            }); btnY=btnY+35
        end
    end
end

local function generateChunk(chunkX, chunkY)
    local chunkKey = chunkX .. "," .. chunkY
    if chunks[chunkKey] then return end
    chunks[chunkKey] = true
    local startX, startY = (chunkX - 1) * CHUNK_SIZE + 1, (chunkY - 1) * CHUNK_SIZE + 1
    for y = startY, startY + CHUNK_SIZE - 1 do
        map[y] = map[y] or {}; for x = startX, startX + CHUNK_SIZE - 1 do
            local e=(noiseElevation:get(x,y)+1)/2;local b=Biomes.mountain;if e<Biomes.deep_water.threshold then b=Biomes.deep_water elseif e<Biomes.shallow_water.threshold then b=Biomes.shallow_water elseif e<Biomes.beach.threshold then b=Biomes.beach elseif e<Biomes.grassy.threshold then b=Biomes.grassy elseif e<Biomes.forest.threshold then b=Biomes.forest elseif e<Biomes.suburban.threshold then b=Biomes.suburban elseif e<Biomes.city.threshold then b=Biomes.city end
            map[y][x]={biome=b};if map[y][x].biome.isUrban and(x%12==0 or y%12==0)then map[y][x].isRoad=true end
            local spawnList=map[y][x].biome.spawn;if spawnList and math.random()<0.25 then local rType=spawnList[math.random(#spawnList)];local pX,pY=hexToWorld(x,y);table.insert(worldObjects,{type=rType,x=pX,y=pY,active=true})end
        end
    end
end

-- ===================================================================
-- LÖVE CALLBACKS
-- ===================================================================

function love.load()
    anim8=require'anim8';SeamlessNoise=require'seamless'
    Items={wood={name="Wood"},stone={name="Stone"},flint={name="Flint"},fiber={name="Fiber"},herb={name="Herb"},coal={name="Coal"},copper_ore={name="Copper Ore"},tin_ore={name="Tin Ore"},iron_ore={name="Iron Ore"},tree={name="Tree",yield={wood=3}},rock={name="Rock",yield={stone=2,flint=1}},fiber_plant={name="Fiber Plant",yield={fiber=3}},herb_plant={name="Herb Plant",yield={herb=2}},coal_vein={name="Coal Vein",yield={coal=3},requires="pickaxe"},copper_vein={name="Copper Vein",yield={copper_ore=2},requires="pickaxe"},tin_vein={name="Tin Vein",yield={tin_ore=2},requires="pickaxe"},iron_vein={name="Iron Vein",yield={iron_ore=2},requires="pickaxe"},stone_axe={name="Stone Axe",recipe={flint=2,wood=2,fiber=2}},pickaxe={name="Pickaxe",recipe={wood=2,stone=3}},stone_wall={name="Stone Wall",recipe={stone=2},buildable=true},campfire={name="Campfire",recipe={wood=5},buildable=true}}
    local baseInventory={};for k,d in pairs(Items)do baseInventory[k]=0 end
    Images={character_sheet=love.graphics.newImage("character_sheet.png"),tree=love.graphics.newImage("tree.png"),rock=love.graphics.newImage("rock.png"),iron_vein=love.graphics.newImage("iron.png"),house=love.graphics.newImage("building_wall.png"),wall=love.graphics.newImage("wall.png"),road=love.graphics.newImage("road.png"),campfire=love.graphics.newImage("campfire.png"),joystick_base=love.graphics.newImage("joystick_base.png"),joystick_nub=love.graphics.newImage("joystick_nub.png"),button_attack=love.graphics.newImage("button_attack.png"),button_menu=love.graphics.newImage("button_menu.png"),coal_vein=love.graphics.newImage("coal_vein.png"),copper_vein=love.graphics.newImage("copper_vein.png"),tin_vein=love.graphics.newImage("tin_vein.png"),fiber_plant=love.graphics.newImage("fiber_plant.png"),herb_plant=love.graphics.newImage("herb_plant.png")}
    Biomes={deep_water={name="Deep Water",color={0.1,0.2,0.4},threshold=0.25,isPassable=false},shallow_water={name="Shallow Water",color={0.2,0.4,0.8},threshold=0.35,isPassable=false},beach={name="Beach",color={0.9,0.8,0.5},threshold=0.4,isPassable=true,spawn={'rock'}},grassy={name="Grassy",color={0.2,0.7,0.2},threshold=0.55,isPassable=true,spawn={'tree','fiber_plant','herb_plant'}},forest={name="Forest",color={0.1,0.5,0.1},threshold=0.65,isPassable=true,spawn={'tree','herb_plant'}},suburban={name="Suburban",color={0.6,0.6,0.6},threshold=0.75,isPassable=true,isUrban=true},city={name="City",color={0.4,0.4,0.45},threshold=0.85,isPassable=true,isUrban=true},mountain={name="Mountain",color={0.5,0.5,0.5},threshold=1.0,isPassable=true,spawn={'rock','coal_vein','copper_vein','tin_vein','iron_vein'}}}
    local seed=math.random(10000);noiseElevation=SeamlessNoise.new(MAP_WIDTH,MAP_HEIGHT,seed)
    local spawnX,spawnY=math.floor(MAP_WIDTH/2),math.floor(MAP_HEIGHT/2)
    generateChunk(math.floor(spawnX/CHUNK_SIZE)+1, math.floor(spawnY/CHUNK_SIZE)+1)
    while not map[spawnY][spawnX].biome.isPassable do spawnX=math.random(1,MAP_WIDTH);spawnY=math.random(1,MAP_HEIGHT);generateChunk(math.floor(spawnX/CHUNK_SIZE)+1, math.floor(spawnY/CHUNK_SIZE)+1)end
    local playerSpawnX,playerSpawnY=hexToWorld(spawnX,spawnY)
    player={x=playerSpawnX,y=playerSpawnY,speed=200,hunger=100,maxHunger=100,inventory=baseInventory,moveDX=0,moveDY=0,buildMode=nil}
    local g=anim8.newGrid(48,48,Images.character_sheet:getWidth(),Images.character_sheet:getHeight());player.animations={down=anim8.newAnimation(g('1-3',1),0.2),left=anim8.newAnimation(g('1-3',2),0.2),right=anim8.newAnimation(g('1-3',3),0.2),up=anim8.newAnimation(g('1-3',4),0.2)};player.anim=player.animations.down;player.direction='down'
    camera={x=0,y=0};hungerTimer=0;hungerInterval=1.5;placedObjects={};
    local sW,sH=love.graphics.getDimensions();joystick={active=false,id=nil,baseX=100,baseY=sH-100,nubX=100,nubY=sH-100,dx=0,dy=0,maxRadius=50};attackButton={x=sW-80,y=sH-80,radius=48};menuButton={x=sW-80,y=sH-190,radius=48}
end

function love.keypressed(key) if key=="e"then performInteraction()end;if key=="m"then menu.isOpen=not menu.isOpen;populateCraftingMenu()end end
function love.touchpressed(id,x,y)
    if menu.isOpen then
        for i,btn in ipairs(menu.buttons)do if isPointInRect(x,y,btn.x,btn.y,btn.w,btn.h)then btn.action();if menu.view=='crafting'then populateCraftingMenu()else populateBuildingMenu()end;return end end
        if isPointInRect(x,y,50,110,100,30)then menu.view='crafting';populateCraftingMenu()end
        if isPointInRect(x,y,160,110,100,30)then menu.view='building';populateBuildingMenu()end
        return
    end
    if isPointInCircle(x,y,attackButton.x,attackButton.y,attackButton.radius)then
        if player.buildMode then
            local buildKey=player.buildMode;local tX,tY=worldToHex(player.buildPreviewX,player.buildPreviewY);local k=tX..","..tY
            if not builtObjects[k]then player.inventory[buildKey]=player.inventory[buildKey]-1;builtObjects[k]={type=buildKey,tileX=tX,tileY=tY};player.buildMode=nil end
        else performInteraction()end
    elseif isPointInCircle(x,y,menuButton.x,menuButton.y,menuButton.radius)then
        if player.buildMode then player.buildMode=nil else menu.isOpen=true;menu.view='crafting';populateCraftingMenu()end
    elseif isPointInCircle(x,y,joystick.baseX,joystick.baseY,joystick.maxRadius*2)then joystick.active=true;joystick.id=id;love.touchmoved(id,x,y,0,0)end
end
function love.touchmoved(id,x,y,dx,dy) if joystick.active and joystick.id==id then local vX,vY=x-joystick.baseX,y-joystick.baseY;local dist=math.sqrt(vX^2+vY^2);if dist>joystick.maxRadius then local r=joystick.maxRadius/dist;joystick.nubX=joystick.baseX+vX*r;joystick.nubY=joystick.baseY+vY*r;joystick.dx,joystick.dy=vX/dist,vY/dist else joystick.nubX,joystick.nubY=x,y;joystick.dx,joystick.dy=vX/joystick.maxRadius,vY/joystick.maxRadius end end end
function love.touchreleased(id,x,y) if joystick.active and joystick.id==id then joystick.active=false;joystick.id=nil;joystick.dx,joystick.dy=0,0;joystick.nubX,joystick.nubY=joystick.baseX,joystick.baseY end end
function love.mousepressed(x,y,b) love.touchpressed(0,x,y) end
function love.mousereleased(x,y,b) love.touchreleased(0,x,y) end
function love.mousemoved(x,y,dx,dy) if love.mouse.isDown(1) then love.touchmoved(0,x,y,dx,dy) end end

function love.update(dt)
    if menu.isOpen then return end
    local playerChunkX,playerChunkY=math.floor(worldToHex(player.x,player.y)/CHUNK_SIZE)+1,math.floor(worldToHex(player.x,player.y)/CHUNK_SIZE)+1
    for y=playerChunkY-1,playerChunkY+1 do for x=playerChunkX-1,playerChunkX+1 do generateChunk(x,y)end end
    player.anim:update(dt);player.moveDX,player.moveDY=0,0;if joystick.active then player.moveDX,player.moveDY=joystick.dx,joystick.dy end
    if love.keyboard.isDown("w")or love.keyboard.isDown("up")then player.moveDY=-1 end;if love.keyboard.isDown("s")or love.keyboard.isDown("down")then player.moveDY=1 end;if love.keyboard.isDown("a")or love.keyboard.isDown("left")then player.moveDX=-1 end;if love.keyboard.isDown("d")or love.keyboard.isDown("right")then player.moveDX=1 end
    local isMoving=(player.moveDX~=0 or player.moveDY~=0)
    if isMoving then
        if math.abs(player.moveDX)>math.abs(player.moveDY)then if player.moveDX>0 then player.direction='right'else player.direction='left'end else if player.moveDY>0 then player.direction='down'else player.direction='up'end end
        local mX,mY=player.moveDX*player.speed*dt,player.moveDY*player.speed*dt;local pX,pY=player.x+mX,player.y+mY
        if mX~=0 then if not isCollidingWithWorld(pX,player.y)then player.x=pX end end
        if mY~=0 then if not isCollidingWithWorld(player.x,pY)then player.y=pY end end
    end
    player.x=(player.x%WORLD_PIXEL_WIDTH+WORLD_PIXEL_WIDTH)%WORLD_PIXEL_WIDTH;player.y=(player.y%WORLD_PIXEL_HEIGHT+WORLD_PIXEL_HEIGHT)%WORLD_PIXEL_HEIGHT
    player.anim=player.animations[player.direction];if isMoving then player.anim:resume()else player.animations[player.direction]:gotoFrame(1);player.anim:pause()end
    
    -- THE FIX IS HERE: Calculate build preview position in update, not draw
    if player.buildMode then
        local ptx, pty = worldToHex(player.x, player.y)
        player.buildPreviewX, player.buildPreviewY = hexToWorld(ptx, pty)
    end
    
    camera.x=player.x-love.graphics.getWidth()/2;camera.y=player.y-love.graphics.getHeight()/2
    hungerTimer=hungerTimer+dt;if hungerTimer>=hungerInterval then player.hunger=player.hunger-1;hungerTimer=0 end;if player.hunger<0 then player.hunger=0 end
end

function love.draw()
    for oX=-1,1 do for oY=-1,1 do
        love.graphics.push();love.graphics.translate(oX*WORLD_PIXEL_WIDTH,oY*WORLD_PIXEL_HEIGHT)
        love.graphics.push();love.graphics.translate(-camera.x,-camera.y)
        local cX_s,cY_s=worldToHex(camera.x,camera.y);local cX_e,cY_e=worldToHex(camera.x+love.graphics.getWidth(),camera.y+love.graphics.getHeight())
        for y=cY_s-2,cY_e+2 do for x=cX_s-2,cX_e+2 do if map[y]and map[y][x]then
            local cX,cY=hexToWorld(x,y);local v={};for i=0,5 do local a=2*math.pi/6*(i+0.5);table.insert(v,cX+HEX_RADIUS*math.cos(a));table.insert(v,cY+HEX_RADIUS*math.sin(a))end
            love.graphics.setColor(map[y][x].biome.color);love.graphics.polygon("fill",v)
            if map[y][x].isRoad then love.graphics.setColor(0.3,0.3,0.3);love.graphics.polygon("fill",v)end
        end end end
        love.graphics.setColor(1,1,1)
        for i,obj in ipairs(worldObjects)do if obj.active then love.graphics.draw(Images[obj.type],obj.x,obj.y)end end
        for i,b in ipairs(placedBuildings)do love.graphics.draw(b.img,b.x,b.y)end
        for k,obj in pairs(builtObjects)do local pX,pY=hexToWorld(obj.tileX,obj.tileY);love.graphics.draw(Images[obj.type],pX-TILE_SIZE/2,pY-TILE_SIZE/2)end
        player.anim:draw(Images.character_sheet,player.x,player.y,nil,nil,nil,24,40)
        if player.buildMode then love.graphics.setColor(1,1,1,0.5);love.graphics.draw(Images[player.buildMode],player.buildPreviewX,player.buildPreviewY)end
        love.graphics.pop();love.graphics.pop()
    end end
    love.graphics.setColor(1,1,1);love.graphics.print("Hunger: "..math.floor(player.hunger),10,10)
    love.graphics.setColor(1,1,1,0.5);love.graphics.draw(Images.joystick_base,joystick.baseX,joystick.baseY,0,1,1,64,64)
    if joystick.active then love.graphics.setColor(1,1,1,0.8);love.graphics.draw(Images.joystick_nub,joystick.nubX,joystick.nubY,0,1,1,32,32)end
    love.graphics.setColor(1,1,1,0.8);love.graphics.draw(Images.button_attack,attackButton.x,attackButton.y,0,1,1,48,48);love.graphics.draw(Images.button_menu,menuButton.x,menuButton.y,0,1,1,48,48)
    if menu.isOpen then
        local sW,sH=love.graphics.getDimensions();love.graphics.setColor(0,0,0,0.8);love.graphics.rectangle("fill",0,0,sW,sH)
        love.graphics.setColor(1,1,1);love.graphics.printf("MENU",0,50,sW,"center")
        love.graphics.rectangle("line",50,110,100,30);love.graphics.printf("Crafting",50,115,100,"center")
        love.graphics.rectangle("line",160,110,100,30);love.graphics.printf("Building",160,115,100,"center")
        for i,btn in ipairs(menu.buttons)do love.graphics.rectangle("line",btn.x,btn.y,btn.w,btn.h);love.graphics.print(btn.text,btn.x+5,btn.y+5)end
    end
end