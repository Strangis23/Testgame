-- camera.lua - Manages the game camera.

require('globals')

Camera = {}

function Camera.update()
    camera.x = player.x - love.graphics.getWidth() / 2
    camera.y = player.y - love.graphics.getHeight() / 2
end

function Camera.attach()
    love.graphics.push()
    love.graphics.translate(-camera.x, -camera.y)
end

function Camera.detach()
    love.graphics.pop()
end

return Camera