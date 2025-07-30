-- player.lua - Manages all player-related logic.

require('globals')
anim8 = require('anim8')

Player = {}

function Player.load()
    local spawnX, spawnY = World.getSpawnPoint()
    
    player = { x = spawnX, y = spawnY, health = 100, maxHealth = 100, hunger = 100, maxHunger = 100,
        inventory = { wood = 10, stone = 10, iron_ore = 0, pickaxe = 1, stone_wall = 10, campfire = 1 },
        vx = 0, vy = 0, max_speed = 300, acceleration = 3000, friction = 2000,
        attack_timer = 0, is_attacking = false, attack_angle = 0,
        hotbar = { 'pickaxe', 'stone_wall', 'campfire', nil, nil }, selected_slot = 1
    }

    local g = anim8.newGrid(48, 48, Images.character_sheet:getWidth(), Images.character_sheet:getHeight())
    player.animations = { down = anim8.newAnimation(g('1-3', 1), 0.2), left = anim8.newAnimation(g('1-3', 2), 0.2), right = anim8.newAnimation(g('1-3', 3), 0.2), up = anim8.newAnimation(g('1-3', 4), 0.2) }
    player.anim = player.animations.down; player.direction = 'down'
end

function Player.update(dt)
    -- Movement
    local moveX,moveY = UI.getJoystickInput()
    if love.keyboard.isDown("a") or love.keyboard.isDown("left") then moveX = moveX - 1; player.direction = 'left' end
    if love.keyboard.isDown("d") or love.keyboard.isDown("right") then moveX = moveX + 1; player.direction = 'right' end
    if love.keyboard.isDown("w") or love.keyboard.isDown("up") then moveY = moveY - 1; player.direction = 'up' end
    if love.keyboard.isDown("s") or love.keyboard.isDown("down") then moveY = moveY + 1; player.direction = 'down' end
    
    local isMoving=(moveX~=0 or moveY~=0)
    if isMoving then local len=math.sqrt(moveX^2+moveY^2); if len>0 then moveX,moveY=moveX/len,moveY/len end; player.vx,player.vy=player.vx+moveX*player.acceleration*dt,player.vy+moveY*player.acceleration*dt
    else local speed=math.sqrt(player.vx^2+player.vy^2); if speed>player.friction*dt then local fx,fy=(player.vx/speed)*player.friction,(player.vy/speed)*player.friction; player.vx,player.vy=player.vx-fx*dt,player.vy-fy*dt else player.vx,player.vy=0,0 end end
    local speed=math.sqrt(player.vx^2+player.vy^2); if speed>player.max_speed then player.vx,player.vy=(player.vx/speed)*player.max_speed,(player.vy/speed)*player.max_speed end
    local nextX,nextY=player.x+player.vx*dt,player.y+player.vy*dt
    if not World.isColliding(nextX,player.y) then player.x=nextX else player.vx=0 end; if not World.isColliding(player.x,nextY) then player.y=nextY else player.vy=0 end
    
    -- Animation
    player.anim=player.animations[player.direction]; if isMoving or player.vx~=0 or player.vy~=0 then player.anim:resume() else player.animations[player.direction]:gotoFrame(1); player.anim:pause() end
    player.anim:update(dt)

    -- Attack
    if player.is_attacking then
        player.attack_timer = player.attack_timer - dt
        player.attack_angle = player.attack_angle + 1500 * dt
        if player.attack_timer <= 0 then
            player.is_attacking = false
            player.attack_angle = 0
        end
    end
end

function Player.draw()
    love.graphics.setColor(1,1,1)
    player.anim:draw(Images.character_sheet, player.x, player.y, nil, nil, nil, 24, 40)
    
    if player.is_attacking then
        local equippedItemName = player.hotbar[player.selected_slot]
        if equippedItemName and Items[equippedItemName] and Items[equippedItemName].is_weapon then
            local wepImg = Images[equippedItemName]
            -- === THE FIX IS HERE ===
            -- Changed the origin point (oy) to the bottom of the image for a better pivot.
            love.graphics.draw(wepImg, player.x, player.y, math.rad(player.attack_angle), 1, 1, wepImg:getWidth()/2, wepImg:getHeight())
        end
    end
end

function Player.keypressed(key)
    if tonumber(key) and tonumber(key) >= 1 and tonumber(key) <= 5 then
        player.selected_slot = tonumber(key)
    end
    if key == "e" then Entities.gatherClosest() end
    if key == "q" and not player.is_attacking then Player.spinAttack() end
    
    local selected = player.hotbar[player.selected_slot]
    if key == "b" and selected and Items[selected] and Items[selected].is_buildable and (player.inventory[selected] or 0) > 0 then
        World.build(selected)
    end
    if key == "f" and selected and Items[selected] and Items[selected].is_placeable and (player.inventory[selected] or 0) > 0 then
        Entities.place(selected)
    end
end

function Player.spinAttack()
    player.is_attacking = true
    player.attack_timer = 0.4
    for _, enemy in ipairs(Entities.getEnemies()) do
        for ox = -1, 1 do for oy = -1, 1 do
            local enemyX, enemyY = enemy.x + ox * MAP_PIXEL_WIDTH, enemy.y + oy * MAP_PIXEL_HEIGHT
            if math.sqrt((player.x - enemyX)^2 + (player.y - enemyY)^2) < 80 then
                local equippedItem = Items[player.hotbar[player.selected_slot]]
                local damage = (equippedItem and equippedItem.is_weapon) and equippedItem.damage or 5
                enemy.health = enemy.health - damage
            end
        end end
    end
end

return Player