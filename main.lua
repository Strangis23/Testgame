--[[
    Hexagonal Grid & Advanced Map Generation Implementation Notes:
    - This version uses multi-octave Perlin noise for more detailed terrain.
    - It also uses a second noise map for "moisture" to create more varied biomes.
--]]

-- Hex Grid Constants (Pointy Top)
HEX_SIZE = 32
HEX_WIDTH = math.sqrt(3) * HEX_SIZE
HEX_HEIGHT = 2 * HEX_SIZE
MAP_HEX_WIDTH = 100
MAP_HEX_HEIGHT = 100

-- Helper functions for Hex Grid math
function hex_to_pixel(q, r)
    local x = HEX_SIZE * (math.sqrt(3) * q  +  math.sqrt(3)/2 * r)
    local y = HEX_SIZE * (                               3/2 * r)
    return x, y
end

function pixel_to_hex(x, y)
    local q = (math.sqrt(3)/3 * x  -  1/3 * y) / HEX_SIZE
    local r = (                      2/3 * y) / HEX_SIZE
    return hex_round(q, r)
end

function hex_round(q, r)
    local s = -q - r
    local rq, rr, rs = math.floor(q + 0.5), math.floor(r + 0.5), math.floor(s + 0.5)
    local q_diff, r_diff, s_diff = math.abs(rq - q), math.abs(rr - r), math.abs(rs - s)
    if q_diff > r_diff and q_diff > s_diff then
        rq = -rr - rs
    elseif r_diff > s_diff then
        rr = -rq - rs
    else
        rs = -rq - rr
    end
    return rq, rr
end

local hex_vertices = {}
for i = 0, 5 do
    local angle = 2 * math.pi / 6 * (i + 0.5)
    table.insert(hex_vertices, HEX_SIZE * math.cos(angle))
    table.insert(hex_vertices, HEX_SIZE * math.sin(angle))
end

function checkCollision(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and x2 < x1 + w1 and y1 < y2 + h2 and y2 < y1 + h1
end

PLAYER_COLLISION_W = 20; PLAYER_COLLISION_H = 24
PLAYER_COLLISION_OX = 10; PLAYER_COLLISION_OY = 32

buildingGrid = {}; placedBuildings = {}; placedObjects = {}

function isCollidingWithWorld(x, y)
    local checkX = x - PLAYER_COLLISION_OX
    local checkY = y - PLAYER_COLLISION_OY
    local worldW, worldH = MAP_PIXEL_WIDTH, MAP_PIXEL_HEIGHT
    checkX = (checkX % worldW + worldW) % worldW
    checkY = (checkY % worldH + worldH) % worldH
    local q, r = pixel_to_hex(checkX, checkY)
    local tileKey = q .. "," .. r
    if map[tileKey] and not map[tileKey].biome.isPassable then
        return true
    end
    for i, obj in ipairs(worldObjects) do if obj.active then local oS = HEX_SIZE * (obj.scale or 1); if checkCollision(checkX, checkY, PLAYER_COLLISION_W, PLAYER_COLLISION_H, obj.x, obj.y, oS, oS) then return true end end end
    for k, obj in pairs(builtObjects) do local oX, oY = hex_to_pixel(obj.q, obj.r); if checkCollision(checkX, checkY, PLAYER_COLLISION_W, PLAYER_COLLISION_H, oX - HEX_WIDTH/2, oY - HEX_HEIGHT/2, HEX_WIDTH, HEX_HEIGHT) then return true end end
    return false
end

function love.load()
    love.window.setTitle("Hex Survival Evolved")
    anim8 = require 'anim8'
    PerlinNoise = require 'perlin'
    
    MAP_PIXEL_WIDTH = MAP_HEX_WIDTH * HEX_WIDTH
    MAP_PIXEL_HEIGHT = MAP_HEX_HEIGHT * HEX_HEIGHT * 0.75

    Items = {
        tree = { name = "Tree", drop = "wood", amount = 1 }, rock = { name = "Rock", drop = "stone", amount = 2 },
        iron_vein = { name = "Iron Vein", drop = "iron_ore", amount = 2 },
        pickaxe = { name = "Pickaxe", recipe = { { item = "wood", amount = 2 }, { item = "stone", amount = 3 } } },
        stone_wall = { name = "Stone Wall", recipe = { { item = "stone", amount = 2 } } }
    }
    Images = {
        character_sheet=love.graphics.newImage("character_sheet.png"), tree=love.graphics.newImage("tree.png"),
        rock=love.graphics.newImage("rock.png"), iron_vein=love.graphics.newImage("iron.png"),
        wall=love.graphics.newImage("wall.png"), campfire=love.graphics.newImage("campfire.png")
    }

    local seed = math.random(10000)
    noiseElevation = PerlinNoise.new(seed)
    noiseElevation.octaves = 8
    noiseElevation.persistence = 0.5
    noiseElevation.frequency = 0.02
    
    noiseMoisture = PerlinNoise.new(seed + 1)
    noiseMoisture.octaves = 6
    noiseMoisture.persistence = 0.5
    noiseMoisture.frequency = 0.02
    
    Biomes = {
        DEEP_WATER = { name="Deep Water",  color={0.1, 0.2, 0.4}, isPassable=false },
        SHALLOW_WATER={ name="Shallow Water",color={0.2, 0.4, 0.8}, isPassable=false },
        BEACH      = { name="Beach",       color={0.9, 0.8, 0.5}, isPassable=true },
        GRASSY     = { name="Grassland",   color={0.2, 0.7, 0.2}, isPassable=true, treeChance=0.02 },
        FOREST     = { name="Forest",      color={0.1, 0.5, 0.1}, isPassable=true, treeChance=0.15 },
        RAINFOREST = { name="Rainforest",  color={0.1, 0.4, 0.1}, isPassable=true, treeChance=0.3 },
        DESERT     = { name="Desert",      color={0.9, 0.8, 0.6}, isPassable=true },
        SAVANNA    = { name="Savanna",     color={0.7, 0.6, 0.3}, isPassable=true, treeChance=0.05 },
        MOUNTAIN   = { name="Mountain",    color={0.5, 0.5, 0.5}, isPassable=true, stoneChance=0.2 },
        SNOWY_PEAK = { name="Snowy Peak",  color={0.9, 0.9, 0.95},isPassable=true, stoneChance=0.05 }
    }

    function getBiome(e, m)
        if e < 0.3 then return Biomes.DEEP_WATER end
        if e < 0.4 then return Biomes.SHALLOW_WATER end
        if e < 0.45 then return Biomes.BEACH end
        if e < 0.65 then
            if m < 0.33 then return Biomes.GRASSY end
            if m < 0.66 then return Biomes.FOREST end
            return Biomes.RAINFOREST
        end
        if e < 0.8 then
            if m < 0.33 then return Biomes.DESERT end
            if m < 0.66 then return Biomes.SAVANNA end
            return Biomes.FOREST
        end
        if e < 0.9 then return Biomes.MOUNTAIN end
        return Biomes.SNOWY_PEAK
    end

    map = {}; worldObjects = {}; builtObjects = {};
    for r = 0, MAP_HEX_HEIGHT - 1 do
        for q = -math.floor(r/2), MAP_HEX_WIDTH - math.floor(r/2) - 1 do
            local e = (noiseElevation:get(q, r) + 1) / 2
            local m = (noiseMoisture:get(q, r) + 1) / 2
            local biome = getBiome(e,m)
            local tileKey = q .. "," .. r
            map[tileKey] = { biome = biome, q = q, r = r }
        end
    end

    local spawnQ, spawnR = math.floor(MAP_HEX_WIDTH/2), math.floor(MAP_HEX_HEIGHT/2)
    while not map[spawnQ .. "," .. spawnR].biome.isPassable do
        spawnQ=math.random(-math.floor(MAP_HEX_HEIGHT/4), MAP_HEX_WIDTH - math.floor(MAP_HEX_HEIGHT/4))
        spawnR=math.random(0, MAP_HEX_HEIGHT)
    end
    local spawnX, spawnY = hex_to_pixel(spawnQ, spawnR)

    for tileKey, tile in pairs(map) do
        local q, r = tile.q, tile.r
        local x, y = hex_to_pixel(q, r)
        local scale = 1; local sizeRoll = math.random(); if sizeRoll > 0.9 then scale = 1.5 elseif sizeRoll > 0.6 then scale = 1.2 end
        if tile.biome.treeChance and math.random() < tile.biome.treeChance then table.insert(worldObjects, {type='tree', x=x, y=y, active=true, scale=scale, q=q, r=r}) end
        if tile.biome.stoneChance and math.random() < tile.biome.stoneChance then local rT = 'rock'; if math.random() < 0.3 then rT = 'iron_vein' end; table.insert(worldObjects, {type=rT, x=x, y=y, active=true, scale=scale, q=q, r=r}) end
    end

    -- === SMOOTHER MOVEMENT (Part 1) ===
    -- New physics variables for the player
    player = {
        x=spawnX, y=spawnY, hunger=100, maxHunger=100, 
        inventory={wood=0,stone=0,iron_ore=0,campfires=0,pickaxe=0,stone_wall=0},
        vx=0, vy=0, -- Velocity
        max_speed=300,
        acceleration=3000,
        friction=2000
    }
    local g = anim8.newGrid(48,48,Images.character_sheet:getWidth(),Images.character_sheet:getHeight())
    player.animations = {down=anim8.newAnimation(g('1-3',1),0.2), left=anim8.newAnimation(g('1-3',2),0.2), right=anim8.newAnimation(g('1-3',3),0.2), up=anim8.newAnimation(g('1-3',4),0.2)}; player.anim=player.animations.down; player.direction='down'
    camera = {x=0, y=0}; hungerTimer=0; hungerInterval=1.5;
end

function love.keypressed(key)
    -- === SMARTER GATHERING ===
    if key == "e" then
        local closestObj = nil
        local closestDistSq = (HEX_SIZE * 2)^2 -- Max gather distance (squared for efficiency)

        -- Find the closest active object to the player
        for i, obj in ipairs(worldObjects) do
            if obj.active then
                for ox = -1, 1 do
                    for oy = -1, 1 do
                        local objX = obj.x + ox * MAP_PIXEL_WIDTH
                        local objY = obj.y + oy * MAP_PIXEL_HEIGHT
                        local distSq = (player.x - objX)^2 + (player.y - objY)^2
                        if distSq < closestDistSq then
                            closestDistSq = distSq
                            closestObj = obj
                        end
                    end
                end
            end
        end

        -- If a close-enough object was found, gather it
        if closestObj then
            local itemData, yield = Items[closestObj.type], Items[closestObj.type].amount * (closestObj.scale or 1)
            if closestObj.type == 'tree' or closestObj.type == 'rock' then
                player.inventory[itemData.drop] = (player.inventory[itemData.drop] or 0) + yield
                closestObj.active = false
            elseif closestObj.type == 'iron_vein' then
                if player.inventory.pickaxe > 0 then
                    player.inventory[itemData.drop] = (player.inventory[itemData.drop] or 0) + yield
                    closestObj.active = false
                else
                    print("You need a pickaxe to mine iron!")
                end
            end
        end
    end

    if key == "1" then
        local r = Items.pickaxe.recipe
        if (player.inventory.wood or 0) >= r[1].amount and (player.inventory.stone or 0) >= r[2].amount then
            player.inventory.wood = player.inventory.wood - r[1].amount
            player.inventory.stone = player.inventory.stone - r[2].amount
            player.inventory.pickaxe = (player.inventory.pickaxe or 0) + 1
        end
    end
    if key == "2" then
        local r = Items.stone_wall.recipe
        if (player.inventory.stone or 0) >= r[1].amount then
            player.inventory.stone = player.inventory.stone - r[1].amount
            player.inventory.stone_wall = (player.inventory.stone_wall or 0) + 1
        end
    end
    if key == "c" then
        if (player.inventory.wood or 0) >= 4 then
            player.inventory.wood = player.inventory.wood - 4
            player.inventory.campfires = (player.inventory.campfires or 0) + 1
        end
    end
    if key == "f" then
        if (player.inventory.campfires or 0) >= 1 then
            player.inventory.campfires = player.inventory.campfires - 1
            table.insert(placedObjects, {type='campfire', x=player.x, y=player.y, timer=10})
        end
    end
    if key == "b" then
        if (player.inventory.stone_wall or 0) > 0 then
            local pX = (player.x % MAP_PIXEL_WIDTH + MAP_PIXEL_WIDTH) % MAP_PIXEL_WIDTH
            local pY = (player.y % MAP_PIXEL_HEIGHT + MAP_PIXEL_HEIGHT) % MAP_PIXEL_HEIGHT
            local q, r = pixel_to_hex(pX, pY)
            local k = q .. "," .. r
            if not builtObjects[k] then
                player.inventory.stone_wall = player.inventory.stone_wall - 1
                builtObjects[k] = {type='wall', q=q, r=r}
            end
        end
    end
end

function love.update(dt)
    -- === SMOOTHER MOVEMENT (Part 2) ===
    -- This new logic uses acceleration and friction for fluid movement.
    
    -- 1. Get movement direction from input
    local moveX, moveY = 0, 0
    if love.keyboard.isDown("a") or love.keyboard.isDown("left") then moveX = moveX - 1; player.direction='left' end
    if love.keyboard.isDown("d") or love.keyboard.isDown("right") then moveX = moveX + 1; player.direction='right' end
    if love.keyboard.isDown("w") or love.keyboard.isDown("up") then moveY = moveY - 1; player.direction='up' end
    if love.keyboard.isDown("s") or love.keyboard.isDown("down") then moveY = moveY + 1; player.direction='down' end
    
    local isMoving = (moveX ~= 0 or moveY ~= 0)
    
    -- 2. Handle acceleration and friction
    if isMoving then
        -- Normalize diagonal movement to prevent faster speed
        local len = math.sqrt(moveX^2 + moveY^2)
        if len > 0 then moveX, moveY = moveX / len, moveY / len end

        -- Accelerate the player
        player.vx = player.vx + moveX * player.acceleration * dt
        player.vy = player.vy + moveY * player.acceleration * dt
    else
        -- Apply friction if not moving
        local current_speed = math.sqrt(player.vx^2 + player.vy^2)
        if current_speed > player.friction * dt then
            local friction_vx = (player.vx / current_speed) * player.friction
            local friction_vy = (player.vy / current_speed) * player.friction
            player.vx = player.vx - friction_vx * dt
            player.vy = player.vy - friction_vy * dt
        else
            player.vx, player.vy = 0, 0
        end
    end

    -- 3. Cap the player's speed
    local current_speed = math.sqrt(player.vx^2 + player.vy^2)
    if current_speed > player.max_speed then
        player.vx = (player.vx / current_speed) * player.max_speed
        player.vy = (player.vy / current_speed) * player.max_speed
    end

    -- 4. Apply velocity to position and check for collision
    local nextX = player.x + player.vx * dt
    local nextY = player.y + player.vy * dt
    
    if not isCollidingWithWorld(nextX, player.y) then
        player.x = nextX
    else
        player.vx = 0 -- Stop horizontal movement on collision
    end
    
    if not isCollidingWithWorld(player.x, nextY) then
        player.y = nextY
    else
        player.vy = 0 -- Stop vertical movement on collision
    end

    -- 5. Update animations
    player.anim = player.animations[player.direction]
    if isMoving or player.vx ~= 0 or player.vy ~= 0 then player.anim:resume() else player.animations[player.direction]:gotoFrame(1); player.anim:pause() end
    player.anim:update(dt)

    -- 6. Update camera and hunger
    camera.x = player.x - love.graphics.getWidth()/2; camera.y = player.y - love.graphics.getHeight()/2
    hungerTimer = hungerTimer + dt; if hungerTimer >= hungerInterval then player.hunger = player.hunger - 1; hungerTimer = 0 end
    if player.hunger < 0 then player.hunger = 0 end

    for i = #placedObjects, 1, -1 do
        local obj = placedObjects[i]
        local oW, oH = Images.campfire:getDimensions()
        local collided = false
        for ox = -1, 1 do
            for oy = -1, 1 do
                local cX = player.x - PLAYER_COLLISION_OX; local cY = player.y - PLAYER_COLLISION_OY
                local objX = obj.x + ox * MAP_PIXEL_WIDTH; local objY = obj.y + oy * MAP_PIXEL_HEIGHT
                if checkCollision(cX, cY, PLAYER_COLLISION_W, PLAYER_COLLISION_H, objX, objY, oW, oH) then
                    collided = true; break
                end
            end
            if collided then break end
        end
        if collided then player.hunger = math.min(player.maxHunger, player.hunger + (10*dt)) end
        obj.timer = obj.timer - dt
        if obj.timer < 0 then table.remove(placedObjects, i) end
    end
end

function love.draw()
    love.graphics.push()
    love.graphics.translate(-camera.x, -camera.y)

    for offsetY = -2, 2 do
        for offsetX = -2, 2 do
            love.graphics.push()
            love.graphics.translate(offsetX * MAP_PIXEL_WIDTH, offsetY * MAP_PIXEL_HEIGHT)
            
            for key, tile in pairs(map) do
                local x, y = hex_to_pixel(tile.q, tile.r)
                love.graphics.setColor(tile.biome.color)
                love.graphics.push()
                love.graphics.translate(x, y)
                love.graphics.polygon("fill", hex_vertices)
                love.graphics.pop()
            end
            
            love.graphics.setColor(1, 1, 1)

            for i, obj in ipairs(worldObjects) do if obj.active then love.graphics.draw(Images[obj.type], obj.x, obj.y, 0, obj.scale or 1, obj.scale or 1, Images[obj.type]:getWidth()/2, Images[obj.type]:getHeight()/2) end end
            for k, obj in pairs(builtObjects) do local x, y = hex_to_pixel(obj.q, obj.r); love.graphics.draw(Images.wall, x, y, 0, 1, 1, Images.wall:getWidth()/2, Images.wall:getHeight()/2) end
            for i, obj in ipairs(placedObjects) do love.graphics.draw(Images[obj.type], obj.x, obj.y, 0, 1, 1, Images[obj.type]:getWidth()/2, Images[obj.type]:getHeight()/2) end
            
            love.graphics.pop()
        end
    end

    love.graphics.setColor(1, 1, 1)
    player.anim:draw(Images.character_sheet, player.x, player.y, nil, nil, nil, 24, 40)

    love.graphics.pop()

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Hunger: " .. math.floor(player.hunger), 10, 10)
    love.graphics.print("Wood: "..(player.inventory.wood or 0).." | Stone: "..(player.inventory.stone or 0).." | Iron: "..(player.inventory.iron_ore or 0), 10, 30)
    love.graphics.print("Pickaxes: "..(player.inventory.pickaxe or 0).." | Walls: "..(player.inventory.stone_wall or 0).." | Campfires: "..(player.inventory.campfires or 0), 10, 50)
    local c1 = "[E] Gather | [B] Build Wall | [F] Place Campfire"
    local c2 = "[1] Craft Pickaxe | [2] Craft Wall | [C] Craft Campfire"
    love.graphics.print(c1, 10, love.graphics.getHeight()-40)
    love.graphics.print(c2, 10, love.graphics.getHeight()-20)
end