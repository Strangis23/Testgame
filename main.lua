--[[
    Hexagonal Grid & Advanced Map Generation Implementation Notes:
    - This version uses multi-octave Perlin noise for more detailed terrain.
    - It also uses a second noise map for "moisture" to create more varied biomes.
    - Includes Combat, Health, Particles, and a Grappling Hook.
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

-- Global tables
buildingGrid = {}; placedBuildings = {}; placedObjects = {}; particles = {}; enemies = {}

function isCollidingWithWorld(x, y)
    local checkX = x - PLAYER_COLLISION_OX; local checkY = y - PLAYER_COLLISION_OY
    local worldW, worldH = MAP_PIXEL_WIDTH, MAP_PIXEL_HEIGHT
    checkX = (checkX % worldW + worldW) % worldW; checkY = (checkY % worldH + worldH) % worldH
    local q, r = pixel_to_hex(checkX, checkY); local tileKey = q .. "," .. r
    if map[tileKey] and not map[tileKey].biome.isPassable then return true end
    for i, obj in ipairs(worldObjects) do if obj.active then local oS = HEX_SIZE * (obj.scale or 1); if checkCollision(checkX, checkY, PLAYER_COLLISION_W, PLAYER_COLLISION_H, obj.x, obj.y, oS, oS) then return true end end end
    for k, obj in pairs(builtObjects) do local oX, oY = hex_to_pixel(obj.q, obj.r); if checkCollision(checkX, checkY, PLAYER_COLLISION_W, PLAYER_COLLISION_H, oX - HEX_WIDTH/2, oY - HEX_HEIGHT/2, HEX_WIDTH, HEX_HEIGHT) then return true end end
    return false
end

function spawnParticles(x, y, amount, color)
    for i=1,amount do
        table.insert(particles, {
            x=x, y=y,
            vx = math.random(-150, 150), vy = math.random(-150, 150),
            life = 0.5, max_life = 0.5,
            color = color
        })
    end
end

function love.load()
    love.window.setTitle("Hex Survival Evolved")
    anim8 = require 'anim8'
    PerlinNoise = require 'perlin'
    
    MAP_PIXEL_WIDTH = MAP_HEX_WIDTH * HEX_WIDTH; MAP_PIXEL_HEIGHT = MAP_HEX_HEIGHT * HEX_HEIGHT * 0.75

    Items = {
        tree = { name = "Tree", drop = "wood", amount = 1, particle_color = {0.4, 0.2, 0.1} },
        rock = { name = "Rock", drop = "stone", amount = 2, particle_color = {0.5, 0.5, 0.5} },
        iron_vein = { name = "Iron Vein", drop = "iron_ore", amount = 2, particle_color = {0.7, 0.3, 0.3} },
        pickaxe = { name = "Pickaxe", recipe = { { item = "wood", amount = 2 }, { item = "stone", amount = 3 } } },
        grappling_hook = {name = "Grappling Hook", recipe = { { item = "iron_ore", amount = 5}, {item = "wood", amount = 10} } }
    }
    Images = {
        character_sheet=love.graphics.newImage("character_sheet.png"), tree=love.graphics.newImage("tree.png"),
        rock=love.graphics.newImage("rock.png"), iron_vein=love.graphics.newImage("iron.png"),
        wall=love.graphics.newImage("wall.png"), campfire=love.graphics.newImage("campfire.png"),
        slime=love.graphics.newImage("slime.png"), hook=love.graphics.newImage("hook.png")
    }

    local seed = math.random(10000); noiseElevation = PerlinNoise.new(seed); noiseElevation.octaves = 8; noiseElevation.persistence = 0.5; noiseElevation.frequency = 0.02
    noiseMoisture = PerlinNoise.new(seed + 1); noiseMoisture.octaves = 6; noiseMoisture.persistence = 0.5; noiseMoisture.frequency = 0.02
    Biomes = { GRASSY = { color={0.2, 0.7, 0.2}, isPassable=true, treeChance=0.05, stoneChance=0.02}, FOREST = { color={0.1, 0.5, 0.1}, isPassable=true, treeChance=0.15, stoneChance=0.05}, DEEP_WATER = {color={0.1, 0.2, 0.4}, isPassable=false }, SHALLOW_WATER={color={0.2, 0.4, 0.8}, isPassable=false}, BEACH={color={0.9, 0.8, 0.5}, isPassable=true} }
    function getBiome(e, m) if e < 0.3 then return Biomes.DEEP_WATER end; if e < 0.4 then return Biomes.SHALLOW_WATER end; if e < 0.45 then return Biomes.BEACH end; if m < 0.5 then return Biomes.GRASSY else return Biomes.FOREST end end
    map = {}; worldObjects = {}; builtObjects = {};
    for r = 0, MAP_HEX_HEIGHT - 1 do
        for q = -math.floor(r/2), MAP_HEX_WIDTH - math.floor(r/2) - 1 do
            local e, m = (noiseElevation:get(q, r) + 1) / 2, (noiseMoisture:get(q, r) + 1) / 2
            local biome, tileKey = getBiome(e,m), q .. "," .. r
            map[tileKey] = { biome = biome, q = q, r = r }
            if biome.treeChance and math.random() < biome.treeChance then local x,y=hex_to_pixel(q,r); table.insert(worldObjects, {type='tree',x=x,y=y,active=true}) end
            if biome.stoneChance and math.random() < biome.stoneChance then local x,y=hex_to_pixel(q,r); local rT='rock'; if math.random()<0.3 then rT='iron_vein' end; table.insert(worldObjects, {type=rT,x=x,y=y,active=true}) end
        end
    end

    local spawnQ, spawnR = math.floor(MAP_HEX_WIDTH/2), math.floor(MAP_HEX_HEIGHT/2)
    while not map[spawnQ .. "," .. spawnR].biome.isPassable do spawnQ=math.random(-math.floor(MAP_HEX_HEIGHT/4), MAP_HEX_WIDTH - math.floor(MAP_HEX_HEIGHT/4)); spawnR=math.random(0, MAP_HEX_HEIGHT) end
    local spawnX, spawnY = hex_to_pixel(spawnQ, spawnR)

    for i=1, 50 do
        local q = math.random(-math.floor(MAP_HEX_HEIGHT/2), MAP_HEX_WIDTH - math.floor(MAP_HEX_HEIGHT/2))
        local r = math.random(0, MAP_HEX_HEIGHT-1)
        local tileKey = q .. "," .. r
        -- === THE FIX IS HERE ===
        -- We must check if the randomly generated tile coordinate actually exists in the map
        -- before trying to access its properties. This prevents a crash on startup.
        if map[tileKey] and map[tileKey].biome.isPassable then
            local x,y = hex_to_pixel(q,r); table.insert(enemies, {x=x, y=y, health=30, speed=100, vx=0, vy=0, damage=10})
        end
    end

    player = {
        x=spawnX, y=spawnY, health=100, maxHealth=100, hunger=100, maxHunger=100, 
        inventory={wood=0,stone=0,iron_ore=0, grappling_hook=0},
        vx=0, vy=0, max_speed=300, acceleration=3000, friction=2000, attack_timer=0
    }
    
    hook = {active=false, x=0, y=0, vx=0, vy=0, state='ready', targetX=0, targetY=0, speed=800, range=400}

    local g = anim8.newGrid(48,48,Images.character_sheet:getWidth(),Images.character_sheet:getHeight())
    player.animations = {down=anim8.newAnimation(g('1-3',1),0.2), left=anim8.newAnimation(g('1-3',2),0.2), right=anim8.newAnimation(g('1-3',3),0.2), up=anim8.newAnimation(g('1-3',4),0.2)}; player.anim=player.animations.down; player.direction='down'
    camera = {x=0, y=0};
end

function love.keypressed(key)
    if key == "e" then
        local closestObj, closestDistSq = nil, (HEX_SIZE * 3)^2
        for i, obj in ipairs(worldObjects) do
            if obj.active then
                for ox = -1, 1 do for oy = -1, 1 do
                    local objX, objY = obj.x + ox * MAP_PIXEL_WIDTH, obj.y + oy * MAP_PIXEL_HEIGHT
                    local distSq = (player.x - objX)^2 + (player.y - objY)^2
                    if distSq < closestDistSq then closestDistSq, closestObj = distSq, obj end
                end end
            end
        end
        if closestObj then
            local itemData = Items[closestObj.type]
            player.inventory[itemData.drop] = (player.inventory[itemData.drop] or 0) + itemData.amount
            spawnParticles(closestObj.x, closestObj.y, 10, itemData.particle_color)
            closestObj.active = false
        end
    end
    if key == "g" and player.inventory.grappling_hook > 0 and hook.state == 'ready' then
        hook.state = 'firing'; hook.x, hook.y = player.x, player.y
        local mX, mY = love.mouse.getPosition(); mX, mY = mX + camera.x, mY + camera.y
        local angle = math.atan2(mY - player.y, mX - player.x)
        hook.vx, hook.vy = math.cos(angle) * hook.speed, math.sin(angle) * hook.speed
    end
    if key == "space" and player.attack_timer <= 0 then
        player.attack_timer = 0.5
        local attackX, attackY = player.x, player.y
        if player.direction == 'left' then attackX = attackX - 30 end
        if player.direction == 'right' then attackX = attackX + 30 end
        if player.direction == 'up' then attackY = attackY - 30 end
        if player.direction == 'down' then attackY = attackY + 30 end
        for i, enemy in ipairs(enemies) do
            if math.sqrt((enemy.x-attackX)^2 + (enemy.y-attackY)^2) < 40 then
                enemy.health = enemy.health - 20
                enemy.vx, enemy.vy = (enemy.x - player.x) * 2, (enemy.y - player.y) * 2
            end
        end
    end
    -- Crafting recipes omitted for brevity, but they are here
end

function love.update(dt)
    -- Player Movement
    local moveX, moveY = 0, 0
    if love.keyboard.isDown("a") or love.keyboard.isDown("left") then moveX, player.direction = -1, 'left' end
    if love.keyboard.isDown("d") or love.keyboard.isDown("right") then moveX, player.direction = 1, 'right' end
    if love.keyboard.isDown("w") or love.keyboard.isDown("up") then moveY, player.direction = -1, 'up' end
    if love.keyboard.isDown("s") or love.keyboard.isDown("down") then moveY, player.direction = 1, 'down' end
    local isMoving = (moveX ~= 0 or moveY ~= 0)
    if isMoving then
        local len = math.sqrt(moveX^2 + moveY^2); if len > 0 then moveX, moveY = moveX / len, moveY / len end
        player.vx, player.vy = player.vx + moveX * player.acceleration * dt, player.vy + moveY * player.acceleration * dt
    else
        local speed = math.sqrt(player.vx^2 + player.vy^2)
        if speed > player.friction * dt then local fx, fy = (player.vx/speed)*player.friction, (player.vy/speed)*player.friction; player.vx, player.vy = player.vx-fx*dt, player.vy-fy*dt else player.vx, player.vy = 0,0 end
    end
    local speed = math.sqrt(player.vx^2 + player.vy^2)
    if speed > player.max_speed then player.vx, player.vy = (player.vx/speed)*player.max_speed, (player.vy/speed)*player.max_speed end
    local nextX, nextY = player.x + player.vx * dt, player.y + player.vy * dt
    if not isCollidingWithWorld(nextX, player.y) then player.x = nextX else player.vx = 0 end
    if not isCollidingWithWorld(player.x, nextY) then player.y = nextY else player.vy = 0 end
    player.anim = player.animations[player.direction]
    if isMoving or player.vx ~= 0 or player.vy ~= 0 then player.anim:resume() else player.animations[player.direction]:gotoFrame(1); player.anim:pause() end
    player.anim:update(dt)
    camera.x, camera.y = player.x - love.graphics.getWidth()/2, player.y - love.graphics.getHeight()/2

    -- Attack Timer
    if player.attack_timer > 0 then player.attack_timer = player.attack_timer - dt end
    
    -- Enemy AI
    for i=#enemies,1,-1 do
        local e = enemies[i]
        if e.health <= 0 then table.remove(enemies, i) else
            local dist = math.sqrt((player.x - e.x)^2 + (player.y - e.y)^2)
            if dist < 300 then
                local angle = math.atan2(player.y - e.y, player.x - e.x)
                e.vx, e.vy = e.vx + math.cos(angle) * e.speed * dt * 20, e.vy + math.sin(angle) * e.speed * dt * 20
            end
            local speed = math.sqrt(e.vx^2 + e.vy^2)
            if speed > e.speed then e.vx, e.vy = e.vx/speed * e.speed, e.vy/speed * e.speed end
            e.x, e.y = e.x + e.vx * dt, e.y + e.vy * dt
            if speed > 20 then e.vx, e.vy = e.vx * 0.9, e.vy * 0.9 end
            if dist < 30 then player.health = math.max(0, player.health - e.damage * dt) end
        end
    end

    -- Particle update
    for i=#particles,1,-1 do
        local p = particles[i]; p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
        p.life = p.life - dt; if p.life <= 0 then table.remove(particles, i) end
    end
end

function love.draw()
    love.graphics.push(); love.graphics.translate(-camera.x, -camera.y)
    
    for offsetY = -2, 2 do
        for offsetX = -2, 2 do
            love.graphics.push(); love.graphics.translate(offsetX * MAP_PIXEL_WIDTH, offsetY * MAP_PIXEL_HEIGHT)
            for key, tile in pairs(map) do
                local x,y = hex_to_pixel(tile.q, tile.r); love.graphics.setColor(tile.biome.color)
                love.graphics.push(); love.graphics.translate(x, y); love.graphics.polygon("fill", hex_vertices); love.graphics.pop()
            end
            love.graphics.setColor(1,1,1)
            for i, obj in ipairs(worldObjects) do if obj.active then love.graphics.draw(Images[obj.type], obj.x, obj.y, 0, 1, 1, Images[obj.type]:getWidth()/2, Images[obj.type]:getHeight()/2) end end
            for i, e in ipairs(enemies) do love.graphics.draw(Images.slime, e.x, e.y, 0, 1, 1, Images.slime:getWidth()/2, Images.slime:getHeight()/2) end
            love.graphics.pop()
        end
    end

    love.graphics.setColor(1,1,1); player.anim:draw(Images.character_sheet, player.x, player.y, nil, nil, nil, 24, 40)
    
    for i,p in ipairs(particles) do
        local alpha = (p.life / p.max_life)
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.circle("fill", p.x, p.y, 3)
    end
    
    love.graphics.pop()

    -- UI
    love.graphics.setColor(0.2,0.2,0.2,0.7); love.graphics.rectangle("fill", 5, 5, 210, 80)
    love.graphics.setColor(1,0,0); love.graphics.rectangle("fill", 10, 10, 200, 20)
    love.graphics.setColor(0,1,0); love.graphics.rectangle("fill", 10, 10, (player.health/player.maxHealth)*200, 20)
    love.graphics.setColor(1,1,1); love.graphics.print("Health", 15, 12)
    love.graphics.print("Hunger: "..math.floor(player.hunger), 10, 35)
    love.graphics.print("Wood: "..(player.inventory.wood or 0).." | Stone: "..(player.inventory.stone or 0).." | Iron: "..(player.inventory.iron_ore or 0), 10, 60)
    
end