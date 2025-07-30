-- globals.lua - Defines all shared variables, tables, and constants.

-- Game Constants
HEX_SIZE = 32
HEX_WIDTH = math.sqrt(3) * HEX_SIZE
HEX_HEIGHT = 2 * HEX_SIZE
MAP_HEX_WIDTH = 100
MAP_HEX_HEIGHT = 100
PLAYER_COLLISION_W = 20; PLAYER_COLLISION_H = 24
PLAYER_COLLISION_OX = 10; PLAYER_COLLISION_OY = 32

-- Initialize Global Tables
Items, Images, player, camera, map = {}, {}, {}, {}, {}
worldObjects, builtObjects, placedObjects, enemies, particles = {}, {}, {}, {}, {}
gameState = 'playing'

-- === NEW FEATURE ===
-- This table holds the stats for all enemy types.
EnemyTypes = {
    slime = { health = 30, speed = 80, damage = 10 }
}

-- Load Assets and Definitions
function LoadGlobals()
    Images = {
        character_sheet=love.graphics.newImage("character_sheet.png"), tree=love.graphics.newImage("tree.png"),
        rock=love.graphics.newImage("rock.png"), iron_vein=love.graphics.newImage("iron.png"),
        wall=love.graphics.newImage("wall.png"), campfire=love.graphics.newImage("campfire.png"),
        slime=love.graphics.newImage("slime.png"), pickaxe=love.graphics.newImage("pickaxe.png")
    }
    Items = {
        tree = { name="Tree", drop="wood", amount=1, particle_color={0.4,0.2,0.1} },
        rock = { name="Rock", drop="stone", amount=2, particle_color={0.5,0.5,0.5} },
        iron_vein = { name="Iron Vein", drop="iron_ore", amount=2, particle_color={0.7,0.3,0.3} },
        pickaxe = { name="Pickaxe", recipe={{item="wood",amount=2},{item="stone",amount=3}}, is_weapon=true, damage=25 },
        stone_wall = { name="Stone Wall", recipe={{item="stone",amount=2}}, is_buildable=true },
        campfire = { name="Campfire", recipe={{item="wood",amount=4}}, is_placeable=true }
    }
end