-- Helper function for rectangle collision
function checkCollision(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and x2 < x1 + w1 and y1 < y2 + h2 and y2 < y1 + h1
end

-- Player Collision Box Constants
PLAYER_COLLISION_W = 20; PLAYER_COLLISION_H = 24
PLAYER_COLLISION_OX = 10; PLAYER_COLLISION_OY = 32

-- Helper function to check collision against all solid world objects and impassable terrain
function isCollidingWithWorld(x, y)
    local checkX = x - PLAYER_COLLISION_OX
    local checkY = y - PLAYER_COLLISION_OY

    -- Check if the player is trying to move into an impassable tile
    local tileX = math.floor((x - PLAYER_COLLISION_OX) / TILE_SIZE) + 1
    local tileY = math.floor((y - PLAYER_COLLISION_OY) / TILE_SIZE) + 1
    if map[tileY] and map[tileY][tileX] and not map[tileY][tileX].biome.isPassable then
        return true
    end

    -- Check against active resource nodes
    for i, obj in ipairs(worldObjects) do
        if obj.active then
            local objSize = TILE_SIZE * (obj.scale or 1)
            if checkCollision(checkX, checkY, PLAYER_COLLISION_W, PLAYER_COLLISION_H, obj.x, obj.y, objSize, objSize) then
                return true
            end
        end
    end

    -- Check against built objects (walls)
    for key, obj in pairs(builtObjects) do
        local objX, objY = (obj.tileX - 1) * TILE_SIZE, (obj.tileY - 1) * TILE_SIZE
        if checkCollision(checkX, checkY, PLAYER_COLLISION_W, PLAYER_COLLISION_H, objX, objY, TILE_SIZE, TILE_SIZE) then
            return true
        end
    end
    
    return false
end


function love.load()
    anim8 = require 'anim8'; Perlin = require 'perlin'
    MAP_WIDTH = 250; MAP_HEIGHT = 250; TILE_SIZE = 32

    Items = {
        tree = { name = "Tree", drop = "wood", amount = 1 }, rock = { name = "Rock", drop = "stone", amount = 2 },
        iron_vein = { name = "Iron Vein", drop = "iron_ore", amount = 2 },
        pickaxe = { name = "Pickaxe", recipe = { { item = "wood", amount = 2 }, { item = "stone", amount = 3 } } },
        stone_wall = { name = "Stone Wall", recipe = { { item = "stone", amount = 2 } } }
    }
    Images = {
        character_sheet=love.graphics.newImage("character_sheet.png"), tree=love.graphics.newImage("tree.png"),
        rock=love.graphics.newImage("rock.png"), iron_vein=love.graphics.newImage("iron.png"),
        building_wall=love.graphics.newImage("building_wall.png"), road=love.graphics.newImage("road.png"),
        campfire=love.graphics.newImage("campfire.png")
    }

    Biomes = {
        deep_water  = { name="Deep Water",  color={0.1, 0.2, 0.4}, threshold=0.25, isPassable=false },
        shallow_water = { name="Shallow Water", color={0.2, 0.4, 0.8}, threshold=0.35, isPassable=false },
        beach       = { name="Beach",       color={0.9, 0.8, 0.5}, threshold=0.4, isPassable=true },
        grassy      = { name="Grassy",      color={0.2, 0.7, 0.2}, threshold=0.55, isPassable=true, treeChance=0.02 },
        forest      = { name="Forest",      color={0.1, 0.5, 0.1}, threshold=0.65, isPassable=true, treeChance=0.15 },
        suburban    = { name="Suburban",    color={0.6, 0.6, 0.6}, threshold=0.75, isPassable=true, isSuburban=true },
        city        = { name="City",        color={0.4, 0.4, 0.45}, threshold=0.85, isPassable=true, isCity=true },
        mountain    = { name="Mountain",    color={0.5, 0.5, 0.5}, threshold=1.0, isPassable=true, stoneChance=0.2 }
    }
    
    local seed = math.random(10000); noiseElevation = Perlin.new(seed);
    local mapZoom = 0.03; map = {}; worldObjects = {}; builtObjects = {}
    
    -- Pass 1: Generate Terrain
    for y = 1, MAP_HEIGHT do
        map[y] = {}
        for x = 1, MAP_WIDTH do
            local elev = (noiseElevation:get(x * mapZoom, y * mapZoom) + 1) / 2
            local biome = Biomes.mountain
            if elev < Biomes.deep_water.threshold then biome = Biomes.deep_water
            elseif elev < Biomes.shallow_water.threshold then biome = Biomes.shallow_water
            elseif elev < Biomes.beach.threshold then biome = Biomes.beach
            elseif elev < Biomes.grassy.threshold then biome = Biomes.grassy
            elseif elev < Biomes.forest.threshold then biome = Biomes.forest
            elseif elev < Biomes.suburban.threshold then biome = Biomes.suburban
            elseif elev < Biomes.city.threshold then biome = Biomes.city
            end
            map[y][x] = { biome = biome }
        end
    end

    -- Pass 2: Generate Buildings and Resources
    local buildingGrid = {}
    for y = 1, MAP_HEIGHT do
        for x = 1, MAP_WIDTH do
            local tile = map[y][x]
            local scale = 1; local sizeRoll=math.random(); if sizeRoll>0.9 then scale=4 elseif sizeRoll>0.6 then scale=2 end
            if tile.biome.treeChance and math.random() < tile.biome.treeChance then
                table.insert(worldObjects, {type='tree', x=(x-1)*TILE_SIZE, y=(y-1)*TILE_SIZE, active=true, scale=scale})
            end
            if tile.biome.stoneChance and math.random() < tile.biome.stoneChance then
                local resourceType='rock'; if math.random()<0.3 then resourceType='iron_vein' end
                table.insert(worldObjects, {type=resourceType, x=(x-1)*TILE_SIZE, y=(y-1)*TILE_SIZE, active=true, scale=scale})
            end

            local isBuildable = (tile.biome.isCity or tile.biome.isSuburban) and (not buildingGrid[y] or not buildingGrid[y][x])
            if isBuildable then
                local buildingChance = tile.biome.isCity and 0.05 or 0.02
                if math.random() < buildingChance then
                    local minW, maxW = tile.biome.isCity and 4 or 2, tile.biome.isCity and 8 or 4
                    local minH, maxH = tile.biome.isCity and 4 or 2, tile.biome.isCity and 8 or 4
                    local buildingW, buildingH = math.random(minW, maxW), math.random(minH, maxH)
                    
                    -- === THE FIX IS HERE ===
                    local doorSide = math.random(1, 4)
                    local doorPosRange = (doorSide % 2 == 0) and buildingW or buildingH
                    local doorPos = math.random(1, doorPosRange)
                    
                    for by = y, y + buildingH do for bx = x, x + buildingW do
                        if bx <= MAP_WIDTH and by <= MAP_HEIGHT then
                            if not buildingGrid[by] then buildingGrid[by] = {} end
                            buildingGrid[by][bx] = true
                            local isPerimeter = (bx==x or bx==x+buildingW or by==y or by==y+buildingH)
                            if isPerimeter then
                                local isDoor = (doorSide==1 and by==y and bx==x+doorPos) or (doorSide==2 and bx==x+buildingW and by==y+doorPos) or (doorSide==3 and by==y+buildingH and bx==x+doorPos) or (doorSide==4 and bx==x and by==y+doorPos)
                                if not isDoor then
                                    local key = bx..","..by; builtObjects[key] = {type='building_wall', tileX=bx, tileY=by}
                                end
                            else map[by][bx].isRoad = true
                            end
                        end
                    end end
                end
            end
        end
    end

    player={x=(MAP_WIDTH*TILE_SIZE)/2,y=(MAP_HEIGHT*TILE_SIZE)/2,speed=200,hunger=100,maxHunger=100,inventory={wood=0,stone=0,iron_ore=0,campfires=0,pickaxe=0,stone_wall=0}}
    local g=anim8.newGrid(48,48,Images.character_sheet:getWidth(),Images.character_sheet:getHeight())
    player.animations={down=anim8.newAnimation(g('1-3',1),0.2),left=anim8.newAnimation(g('1-3',2),0.2),right=anim8.newAnimation(g('1-3',3),0.2),up=anim8.newAnimation(g('1-3',4),0.2)}; player.anim=player.animations.down; player.direction='down'
    camera={x=0,y=0}; hungerTimer=0; hungerInterval=1.5; placedObjects={};
end


function love.keypressed(key)
    -- === GATHERING ===
    if key == "e" then
        local interactX, interactY; local playerCenterX, playerCenterY = player.x, player.y - 24
        if player.direction == 'up' then interactX, interactY = playerCenterX, playerCenterY - 20
        elseif player.direction == 'down' then interactX, interactY = playerCenterX, playerCenterY + 20
        elseif player.direction == 'left' then interactX, interactY = playerCenterX - 24, playerCenterY
        elseif player.direction == 'right' then interactX, interactY = playerCenterX + 24, playerCenterY end

        for i, obj in ipairs(worldObjects) do
            local objSize = TILE_SIZE * (obj.scale or 1)
            if obj.active and interactX > obj.x and interactX < obj.x + objSize and interactY > obj.y and interactY < obj.y + objSize then
                local itemData, yield = Items[obj.type], Items[obj.type].amount * (obj.scale or 1)
                if obj.type == 'tree' or obj.type == 'rock' then
                    print("Gathered "..itemData.name.." (x"..(obj.scale or 1)..") and got "..yield.." "..itemData.drop.."!"); player.inventory[itemData.drop] = player.inventory[itemData.drop] + yield; obj.active = false
                elseif obj.type == 'iron_vein' then
                    if player.inventory.pickaxe > 0 then
                        print("Mined "..itemData.name.." (x"..(obj.scale or 1)..") and got "..yield.." "..itemData.drop.."!"); player.inventory[itemData.drop] = player.inventory[itemData.drop] + yield; obj.active = false
                    else print("You need a pickaxe to mine iron!") end
                end; break
            end
        end
    end
    
    -- === CRAFTING ===
    if key == "1" then
        local recipe = Items.pickaxe.recipe
        if player.inventory.wood >= recipe[1].amount and player.inventory.stone >= recipe[2].amount then
            player.inventory.wood = player.inventory.wood - recipe[1].amount; player.inventory.stone = player.inventory.stone - recipe[2].amount
            player.inventory.pickaxe = player.inventory.pickaxe + 1; print("Crafted a Pickaxe!")
        else print("Not enough resources for Pickaxe! Need 2 Wood, 3 Stone.") end
    end
    if key == "2" then
        local recipe = Items.stone_wall.recipe
        if player.inventory.stone >= recipe[1].amount then
            player.inventory.stone = player.inventory.stone - recipe[1].amount
            player.inventory.stone_wall = player.inventory.stone_wall + 1; print("Crafted a Stone Wall!")
        else print("Not enough resources for Stone Wall! Need 2 Stone.") end
    end
    if key == "c" then
        if player.inventory.wood >= 4 then
            player.inventory.wood = player.inventory.wood - 4; player.inventory.campfires = player.inventory.campfires + 1
            print("Crafted a Campfire!")
        else print("Not enough wood for Campfire! Need 4.") end
    end
    
    -- === PLACING & BUILDING ===
    if key == "f" then
        if player.inventory.campfires >= 1 then
            player.inventory.campfires = player.inventory.campfires - 1; table.insert(placedObjects, {type='campfire', x=player.x, y=player.y, timer=10})
            print("Placed a campfire!")
        end
    end
    if key == "b" then
        if player.inventory.stone_wall > 0 then
            local tileX, tileY = math.floor((player.x - PLAYER_COLLISION_OX + PLAYER_COLLISION_W/2) / TILE_SIZE), math.floor((player.y - PLAYER_COLLISION_OY + PLAYER_COLLISION_H) / TILE_SIZE)
            local buildKey = tileX..","..tileY
            if not builtObjects[buildKey] then
                player.inventory.stone_wall = player.inventory.stone_wall - 1; builtObjects[buildKey] = {type='building_wall', tileX=tileX, tileY=tileY}
                print("Built a wall at "..buildKey)
            else print("Cannot build here!") end
        end
    end
end


function love.update(dt)
    player.anim:update(dt)
    
    local dx,dy = 0,0; local isMoving = false
    if love.keyboard.isDown("s") or love.keyboard.isDown("down") then dy = player.speed*dt; player.direction='down'; isMoving=true end
    if love.keyboard.isDown("w") or love.keyboard.isDown("up") then dy = -player.speed*dt; player.direction='up'; isMoving=true end
    if love.keyboard.isDown("d") or love.keyboard.isDown("right") then dx = player.speed*dt; player.direction='right'; isMoving=true end
    if love.keyboard.isDown("a") or love.keyboard.isDown("left") then dx = -player.speed*dt; player.direction='left'; isMoving=true end
    
    local potentialX, potentialY = player.x + dx, player.y + dy
    potentialX = math.max(PLAYER_COLLISION_OX, math.min(potentialX, MAP_WIDTH * TILE_SIZE - PLAYER_COLLISION_W + PLAYER_COLLISION_OX))
    potentialY = math.max(PLAYER_COLLISION_OY, math.min(potentialY, MAP_HEIGHT * TILE_SIZE - PLAYER_COLLISION_H + PLAYER_COLLISION_OY))

    if dx ~= 0 then if not isCollidingWithWorld(potentialX, player.y) then player.x = potentialX end end
    if dy ~= 0 then if not isCollidingWithWorld(player.x, potentialY) then player.y = potentialY end end

    player.anim = player.animations[player.direction]; if isMoving then player.anim:resume() else player.animations[player.direction]:gotoFrame(1); player.anim:pause() end
    
    camera.x=player.x-love.graphics.getWidth()/2; camera.y=player.y-love.graphics.getHeight()/2
    camera.x=math.max(0, math.min(camera.x, MAP_WIDTH * TILE_SIZE - love.graphics.getWidth()))
    camera.y=math.max(0, math.min(camera.y, MAP_HEIGHT * TILE_SIZE - love.graphics.getHeight()))
    
    hungerTimer = hungerTimer + dt; if hungerTimer >= hungerInterval then player.hunger = player.hunger - 1; hungerTimer = 0 end
    if player.hunger < 0 then player.hunger = 0 end
    for i, obj in ipairs(placedObjects) do
        local checkX, checkY = player.x - PLAYER_COLLISION_OX, player.y - PLAYER_COLLISION_OY
        local objW, objH = Images.campfire:getDimensions()
        if checkCollision(checkX, checkY, PLAYER_COLLISION_W, PLAYER_COLLISION_H, obj.x, obj.y, objW, objH) then
            player.hunger = player.hunger + (10 * dt); if player.hunger > player.maxHunger then player.hunger = player.maxHunger end
        end; obj.timer = obj.timer - dt; if obj.timer < 0 then table.remove(placedObjects, i) end
    end
end


function love.draw()
    love.graphics.push(); love.graphics.translate(-camera.x, -camera.y)
    
    local startX, endX = math.max(1, math.floor(camera.x/TILE_SIZE)), math.min(MAP_WIDTH, math.ceil((camera.x+love.graphics.getWidth())/TILE_SIZE)+1)
    local startY, endY = math.max(1, math.floor(camera.y/TILE_SIZE)), math.min(MAP_HEIGHT, math.ceil((camera.y+love.graphics.getHeight())/TILE_SIZE)+1)
    
    for y = startY, endY do for x = startX, endX do
        love.graphics.setColor(map[y][x].biome.color)
        love.graphics.rectangle("fill", (x-1)*TILE_SIZE, (y-1)*TILE_SIZE, TILE_SIZE, TILE_SIZE)
        if map[y][x].isRoad then
            love.graphics.setColor(1,1,1); love.graphics.draw(Images.road, (x-1)*TILE_SIZE, (y-1)*TILE_SIZE)
        end
    end end
    
    love.graphics.setColor(1, 1, 1)

    for i, obj in ipairs(worldObjects) do if obj.active then love.graphics.draw(Images[obj.type], obj.x, obj.y, 0, obj.scale or 1, obj.scale or 1) end end
    for key, obj in pairs(builtObjects) do love.graphics.draw(Images.building_wall, (obj.tileX-1)*TILE_SIZE, (obj.tileY-1)*TILE_SIZE) end
    for i, obj in ipairs(placedObjects) do love.graphics.draw(Images[obj.type], obj.x, obj.y) end
    
    player.anim:draw(Images.character_sheet, player.x, player.y, nil, nil, nil, 24, 40)
    
    love.graphics.pop()

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Hunger: "..math.floor(player.hunger), 10, 10)
    love.graphics.print("Wood: "..player.inventory.wood.." | Stone: "..player.inventory.stone.." | Iron: "..player.inventory.iron_ore, 10, 30)
    love.graphics.print("Pickaxes: "..player.inventory.pickaxe.." | Walls: "..player.inventory.stone_wall.." | Campfires: "..player.inventory.campfires, 10, 50)
    local c1, c2 = "[E] Gather | [B] Build Wall | [F] Place Campfire", "[1] Craft Pickaxe | [2] Craft Wall | [C] Craft Campfire"
    love.graphics.print(c1, 10, love.graphics.getHeight()-40); love.graphics.print(c2, 10, love.graphics.getHeight()-20)
end