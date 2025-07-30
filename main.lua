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

    player = {x=spawnX, y=spawnY, speed=200, hunger=100, maxHunger=100, inventory={wood=0,stone=0,iron_ore=0,campfires=0,pickaxe=0,stone_wall=0}}
    local g = anim8.newGrid(48,48,Images.character_sheet:getWidth(),Images.character_sheet:getHeight())
    player.animations = {down=anim8.newAnimation(g('1-3',1),0.2), left=anim8.newAnimation(g('1-3',2),0.2), right=anim8.newAnimation(g('1-3',3),0.2), up=anim8.newAnimation(g('1-3',4),0.2)}; player.anim=player.animations.down; player.direction='down'
    camera = {x=0, y=0}; hungerTimer=0; hungerInterval=1.5;
end

function love.keypressed(key)
    if key == "e" then
        local interactX, interactY; local playerCenterX, playerCenterY = player.x, player.y - 24
        if player.direction == 'up' then interactX, interactY = playerCenterX, playerCenterY - 40
        elseif player.direction == 'down' then interactX, interactY = playerCenterX, playerCenterY + 40
        elseif player.direction == 'left' then interactX, interactY = playerCenterX - 40, playerCenterY
        elseif player.direction == 'right' then interactX, interactY = playerCenterX + 40, playerCenterY end

        -- The interaction point does not need to be wrapped because the objects are drawn in all 9 locations
        for i, obj in ipairs(worldObjects) do
             if obj.active then
                for ox = -1, 1 do
                    for oy = -1, 1 do
                        local objX = obj.x + ox * MAP_PIXEL_WIDTH
                        local objY = obj.y + oy * MAP_PIXEL_HEIGHT
                        if math.sqrt((interactX-objX)^2 + (interactY-objY)^2) < HEX_SIZE * (obj.scale or 1) then
                           local itemData, yield = Items[obj.type], Items[obj.type].amount * (obj.scale or 1)
                            if obj.type == 'tree' or obj.type == 'rock' then
                                player.inventory[itemData.drop] = (player.inventory[itemData.drop] or 0) + yield
                                obj.active = false
                            elseif obj.type == 'iron_vein' then
                                if player.inventory.pickaxe > 0 then
                                    player.inventory[itemData.drop] = (player.inventory[itemData.drop] or 0) + yield
                                    obj.active = false
                                else print("You need a pickaxe to mine iron!") end
                            end
                            return -- Exit after finding the object
                        end
                    end
                end
            end
        end
    end

    -- (Crafting and other key presses remain the same)
    if key == "f" then
        if (player.inventory.campfires or 0) >= 1 then
            player.inventory.campfires = player.inventory.campfires - 1
            -- Place the campfire relative to the player's wrapped position
            local placeX = (player.x % MAP_PIXEL_WIDTH + MAP_PIXEL_WIDTH) % MAP_PIXEL_WIDTH
            local placeY = (player.y % MAP_PIXEL_HEIGHT + MAP_PIXEL_HEIGHT) % MAP_PIXEL_HEIGHT
            table.insert(placedObjects, {type='campfire', x=placeX, y=placeY, timer=10})
            print("Placed a campfire!")
        end
    end
end

function love.update(dt)
    player.anim:update(dt)
    local dX, dY = 0, 0; local iM = false
    if love.keyboard.isDown("s") or love.keyboard.isDown("down") then dY = player.speed*dt; player.direction='down'; iM=true end
    if love.keyboard.isDown("w") or love.keyboard.isDown("up") then dY = -player.speed*dt; player.direction='up'; iM=true end
    if love.keyboard.isDown("d") or love.keyboard.isDown("right") then dX = player.speed*dt; player.direction='right'; iM=true end
    if love.keyboard.isDown("a") or love.keyboard.isDown("left") then dX = -player.speed*dt; player.direction='left'; iM=true end

    local pX, pY = player.x + dX, player.y + dY

    if dX ~= 0 then if not isCollidingWithWorld(pX, player.y) then player.x = pX end end
    if dY ~= 0 then if not isCollidingWithWorld(player.x, pY) then player.y = pY end end

    -- === THE FIX IS HERE (Part 1) ===
    -- The player's coordinates are NO LONGER wrapped. This allows for a smooth camera.
    -- The drawing function will handle the visual wrapping.

    player.anim = player.animations[player.direction]; if iM then player.anim:resume() else player.animations[player.direction]:gotoFrame(1); player.anim:pause() end
    camera.x = player.x - love.graphics.getWidth()/2; camera.y = player.y - love.graphics.getHeight()/2

    hungerTimer = hungerTimer + dt; if hungerTimer >= hungerInterval then player.hunger = player.hunger - 1; hungerTimer = 0 end
    if player.hunger < 0 then player.hunger = 0 end

    for i = #placedObjects, 1, -1 do
        local obj = placedObjects[i]
        local oW, oH = Images.campfire:getDimensions()
        
        -- === THE FIX IS HERE (Part 2) ===
        -- Check for collision in a 3x3 grid to handle interaction across the wrap-around seam.
        local collided = false
        for ox = -1, 1 do
            for oy = -1, 1 do
                local cX = player.x - PLAYER_COLLISION_OX
                local cY = player.y - PLAYER_COLLISION_OY
                local objX = obj.x + ox * MAP_PIXEL_WIDTH
                local objY = obj.y + oy * MAP_PIXEL_HEIGHT
                if checkCollision(cX, cY, PLAYER_COLLISION_W, PLAYER_COLLISION_H, objX, objY, oW, oH) then
                    collided = true; break
                end
            end
            if collided then break end
        end
        
        if collided then
            player.hunger = player.hunger + (10*dt)
            if player.hunger > player.maxHunger then player.hunger = player.maxHunger end
        end

        obj.timer = obj.timer - dt
        if obj.timer < 0 then table.remove(placedObjects, i) end
    end
end

function love.draw()
    -- === THE FIX IS HERE (Part 3) ===
    -- The drawing loop handles the visual wrapping. By letting the player's
    -- coordinates grow, the camera moves smoothly with them.
    for offsetX = -2, 2 do
        for offsetY = -2, 2 do
            love.graphics.push()
            love.graphics.translate(offsetX * MAP_PIXEL_WIDTH, offsetY * MAP_PIXEL_HEIGHT)
            
            -- All static map elements are drawn here, relative to the current world copy
            for key, tile in pairs(map) do
                local x, y = hex_to_pixel(tile.q, tile.r)
                -- Simple culling to only draw tiles roughly on screen
                 if x > camera.x - love.graphics.getWidth() and x < camera.x + love.graphics.getWidth()*2 and
                    y > camera.y - love.graphics.getHeight() and y < camera.y + love.graphics.getHeight()*2 then
                    love.graphics.setColor(tile.biome.color)
                    love.graphics.push()
                    love.graphics.translate(x, y)
                    love.graphics.polygon("fill", hex_vertices)
                    love.graphics.pop()
                end
            end
            
            for i, obj in ipairs(worldObjects) do if obj.active then love.graphics.draw(Images[obj.type], obj.x, obj.y, 0, obj.scale or 1, obj.scale or 1, Images[obj.type]:getWidth()/2, Images[obj.type]:getHeight()/2) end end
            for k, obj in pairs(builtObjects) do local x, y = hex_to_pixel(obj.q, obj.r); love.graphics.draw(Images.wall, x, y, 0, 1, 1, Images.wall:getWidth()/2, Images.wall:getHeight()/2) end
            for i, obj in ipairs(placedObjects) do love.graphics.draw(Images[obj.type], obj.x, obj.y, 0, 1, 1, Images[obj.type]:getWidth()/2, Images[obj.type]:getHeight()/2) end

            love.graphics.pop()
        end
    end

    -- The camera and player are drawn once, after all the world copies are laid down.
    love.graphics.push()
    love.graphics.translate(-camera.x, -camera.y)
    player.anim:draw(Images.character_sheet, player.x, player.y, nil, nil, nil, 24, 40)
    love.graphics.pop()

    -- UI
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Hunger: " .. math.floor(player.hunger), 10, 10)
    love.graphics.print("Wood: "..(player.inventory.wood or 0).." | Stone: "..(player.inventory.stone or 0).." | Iron: "..(player.inventory.iron_ore or 0), 10, 30)
    love.graphics.print("Pickaxes: "..(player.inventory.pickaxe or 0).." | Walls: "..(player.inventory.stone_wall or 0).." | Campfires: "..(player.inventory.campfires or 0), 10, 50)
end