-- A helper function to check for rectangle-on-rectangle collision.
-- This is often called AABB (Axis-Aligned Bounding Box) collision.
function checkCollision(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and
           x2 < x1 + w1 and
           y1 < y2 + h2 and
           y2 < y1 + h1
end


-- This function runs only once when the game first starts.
-- It's used for setting up the game state, loading assets, and initializing variables.
function love.load()
    -- Set window properties
    love.window.setTitle("My LÖVE Survival Game")
    love.window.setMode(800, 600)

    -- Player setup using a Lua table to hold all related data
    player = {
        x = 400,
        y = 300,
        speed = 200,
        img = love.graphics.newImage("player.png"),
        -- Survival stats
        hunger = 100,
        maxHunger = 100,
        -- Inventory to hold collected and crafted items
        inventory = {
            wood = 0,
            campfires = 0
        }
    }

    -- Timer variables to control how often hunger decreases
    hungerTimer = 0
    hungerInterval = 1.5 -- Player gets hungrier every 1.5 seconds

    -- Resource object setup
    tree = {
        x = 150,
        y = 200,
        img = love.graphics.newImage("tree.png"),
        active = true -- A flag to check if the tree can be gathered from
    }
    
    -- A table to hold all placed objects, like campfires
    gameObjects = {}
end


-- This function runs once for every single key press.
-- It's best for single-fire actions like interacting, crafting, or jumping.
function love.keypressed(key)
    
    -- GATHERING LOGIC: Press 'e' to gather from the tree
    if key == "e" and tree.active then
        -- Get the width and height of our images for accurate collision checking
        local playerW, playerH = player.img:getDimensions()
        local treeW, treeH = tree.img:getDimensions()
        
        -- Check if the player is colliding with the tree
        if checkCollision(player.x, player.y, playerW, playerH, tree.x, tree.y, treeW, treeH) then
            print("Tree gathered!")
            tree.active = false -- Make the tree inactive so it can't be gathered again
            player.inventory.wood = player.inventory.wood + 1 -- Add wood to inventory
        end
    end
    
    -- CRAFTING LOGIC: Press 'c' to craft a campfire from wood
    if key == "c" then
        -- This is our crafting recipe: 1 campfire costs 4 wood
        if player.inventory.wood >= 4 then
            player.inventory.wood = player.inventory.wood - 4 -- Consume resources
            player.inventory.campfires = player.inventory.campfires + 1 -- Add crafted item
            print("Crafted a campfire!")
        else
            print("Not enough wood! Need 4.")
        end
    end
    
    -- PLACEMENT LOGIC: Press 'f' to place a crafted campfire
    if key == "f" then
        if player.inventory.campfires >= 1 then
            player.inventory.campfires = player.inventory.campfires - 1 -- Consume the item from inventory
            -- Create a new table representing the campfire object
            local newCampfire = {
                img = love.graphics.newImage("campfire.png"),
                x = player.x,
                y = player.y,
                timer = 10 -- The campfire will last for 10 seconds
            }
            table.insert(gameObjects, newCampfire) -- Add the new campfire to our list of game objects
            print("Placed a campfire!")
        end
    end
end


-- This function runs on every frame and is used to update the game's logic.
-- 'dt' (delta time) is the time elapsed since the last frame.
function love.update(dt)
    -- Player Movement Logic (checks for keys being held down)
    if love.keyboard.isDown("d") or love.keyboard.isDown("right") then
        player.x = player.x + player.speed * dt
    end
    if love.keyboard.isDown("a") or love.keyboard.isDown("left") then
        player.x = player.x - player.speed * dt
    end
    if love.keyboard.isDown("s") or love.keyboard.isDown("down") then
        player.y = player.y + player.speed * dt
    end
    if love.keyboard.isDown("w") or love.keyboard.isDown("up") then
        player.y = player.y - player.speed * dt
    end

    -- Hunger Decay Logic
    hungerTimer = hungerTimer + dt
    if hungerTimer >= hungerInterval then
        player.hunger = player.hunger - 1
        hungerTimer = 0 -- Reset the timer
    end

    -- Clamp hunger value so it doesn't go below 0
    if player.hunger < 0 then
        player.hunger = 0
    end

    -- Update all our placed game objects (the campfires)
    for i, obj in ipairs(gameObjects) do
        -- Check if player is near the campfire to get warm (restore hunger)
        local playerW, playerH = player.img:getDimensions()
        local objW, objH = obj.img:getDimensions()
        if checkCollision(player.x, player.y, playerW, playerH, obj.x, obj.y, objW, objH) then
            -- Restore hunger over time while near the fire
            player.hunger = player.hunger + (10 * dt) -- Restore 10 hunger per second
            if player.hunger > player.maxHunger then
                player.hunger = player.maxHunger -- Cap hunger at its max value
            end
        end
        
        -- Decrease the campfire's lifespan
        obj.timer = obj.timer - dt
        if obj.timer < 0 then
            table.remove(gameObjects, i) -- Remove the campfire when its timer runs out
        end
    end
end


-- This function runs on every frame after love.update() and is used to draw everything.
function love.draw()
    -- Set a dark gray background color
    love.graphics.setBackgroundColor(0.2, 0.2, 0.2)

    -- Draw the player
    love.graphics.draw(player.img, player.x, player.y)
    
    -- Only draw the tree if it is 'active'
    if tree.active then
        love.graphics.draw(tree.img, tree.x, tree.y)
    end
    
    -- Loop through and draw all placed game objects
    for i, obj in ipairs(gameObjects) do
        love.graphics.draw(obj.img, obj.x, obj.y)
    end
    
    -- Draw the User Interface (UI) text
    love.graphics.print("Hunger: " .. player.hunger, 10, 10)
    love.graphics.print("Wood: " .. player.inventory.wood, 10, 30)
    love.graphics.print("Campfires: " .. player.inventory.campfires, 10, 50)
    love.graphics.print("[E] Gather | [C] Craft Campfire (4 Wood) | [F] Place Campfire", 10, 560)
end