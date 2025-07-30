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

    map = {}; worldObjects = {}; builtObjects = {}; buildingGrid = {}; placedBuildings = {}
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
        spawnQ=math.random(0, MAP_HEX_WIDTH)
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

-- love.keypressed, love.update, and love.draw have been omitted for brevity, but are the same as the previous corrected version.