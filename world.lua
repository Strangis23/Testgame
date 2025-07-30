-- world.lua - Manages procedural world generation.

require('globals')
PerlinNoise = require('perlin')

World = {}

function World.load()
    MAP_PIXEL_WIDTH, MAP_PIXEL_HEIGHT = MAP_HEX_WIDTH * HEX_WIDTH, MAP_HEX_HEIGHT * HEX_HEIGHT * 0.75
    
    local seed = math.random(10000); 
    local noiseElevation = PerlinNoise.new(seed); noiseElevation.octaves=8; noiseElevation.persistence=0.5; noiseElevation.frequency=0.02
    local noiseMoisture = PerlinNoise.new(seed+1); noiseMoisture.octaves=6; noiseMoisture.persistence=0.5; noiseMoisture.frequency=0.02
    
    -- === THE FIX IS HERE ===
    -- Biomes now define the specific resources and enemies that can spawn in them.
    Biomes = {
        DEEP_WATER = {color={0.1,0.2,0.4}, passable=false},
        SHALLOW_WATER = {color={0.2,0.4,0.8}, passable=false},
        BEACH = {color={0.9,0.8,0.5}, passable=true, resources={{type='rock', chance=0.01}}},
        GRASSY = {color={0.2,0.7,0.2}, passable=true,
            resources = {{type='tree', chance=0.02}, {type='rock', chance=0.01}},
            enemies = {{type='slime', chance=0.01}}
        },
        FOREST = {color={0.1,0.5,0.1}, passable=true,
            resources = {{type='tree', chance=0.15}, {type='rock', chance=0.05}, {type='iron_vein', chance=0.02}},
            enemies = {{type='slime', chance=0.03}}
        }
    }

    local function getBiome(e,m) if e<0.3 then return Biomes.DEEP_WATER end; if e<0.4 then return Biomes.SHALLOW_WATER end; if e<0.45 then return Biomes.BEACH end; if m<0.5 then return Biomes.GRASSY else return Biomes.FOREST end end
    
    map, builtObjects = {}, {}
    -- The generation loop now handles spawning based on the biome's rules.
    for r=0,MAP_HEX_HEIGHT-1 do for q=-math.floor(r/2),MAP_HEX_WIDTH-math.floor(r/2)-1 do
        local e,m = (noiseElevation:get(q,r)+1)/2, (noiseMoisture:get(q,r)+1)/2;
        local biome,tileKey = getBiome(e,m), q..","..r
        map[tileKey] = {biome=biome, q=q, r=r}

        if biome.passable then
            if biome.resources then for _,res in ipairs(biome.resources) do
                if math.random() < res.chance then Entities.addResource(res.type, q, r) end
            end end
            if biome.enemies then for _,enemy in ipairs(biome.enemies) do
                if math.random() < enemy.chance then Entities.addEnemy(enemy.type, q, r) end
            end end
        end
    end end
end

function World.draw()
    for offsetY=-2,2 do for offsetX=-2,2 do
        love.graphics.push(); love.graphics.translate(offsetX*MAP_PIXEL_WIDTH,offsetY*MAP_PIXEL_HEIGHT)
        for _,tile in pairs(map) do
            local x,y=Utils.hex_to_pixel(tile.q,tile.r); love.graphics.setColor(tile.biome.color)
            love.graphics.push(); love.graphics.translate(x,y); love.graphics.polygon("fill",Utils.hex_vertices); love.graphics.pop()
        end
        love.graphics.pop()
    end end
end

function World.getSpawnPoint()
    local spawnQ, spawnR = math.floor(MAP_HEX_WIDTH/2), math.floor(MAP_HEX_HEIGHT/2)
    while not map[spawnQ..","..spawnR].biome.passable do
        spawnQ,spawnR=math.random(-math.floor(MAP_HEX_HEIGHT/4),MAP_HEX_WIDTH-math.floor(MAP_HEX_HEIGHT/4)),math.random(0,MAP_HEX_HEIGHT)
    end
    return Utils.hex_to_pixel(spawnQ, spawnR)
end

function World.isColliding(x, y)
    local checkX, checkY = x - PLAYER_COLLISION_OX, y - PLAYER_COLLISION_OY
    local worldW, worldH = MAP_PIXEL_WIDTH, MAP_PIXEL_HEIGHT
    checkX, checkY = (checkX % worldW + worldW) % worldW, (checkY % worldH + worldH) % worldH
    local q,r = Utils.pixel_to_hex(checkX, checkY); local tileKey = q..","..r
    if map[tileKey] and not map[tileKey].biome.passable then return true end
    return false
end

function World.build(itemType)
    local pX,pY=(player.x%MAP_PIXEL_WIDTH+MAP_PIXEL_WIDTH)%MAP_PIXEL_WIDTH,(player.y%MAP_PIXEL_HEIGHT+MAP_PIXEL_HEIGHT)%MAP_PIXEL_HEIGHT
    local q,r=Utils.pixel_to_hex(pX,pY); local k=q..","..r
    if not builtObjects[k] then
        player.inventory[itemType]=player.inventory[itemType]-1
        builtObjects[k]={type=itemType,q=q,r=r}
    end
end

return World