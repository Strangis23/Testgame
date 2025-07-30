-- utils.lua - Contains various helper functions.

require('globals')

Utils = {}

-- Pre-calculate vertices for drawing hexagons
Utils.hex_vertices = {}
for i = 0, 5 do
    local angle = 2 * math.pi / 6 * (i + 0.5)
    table.insert(Utils.hex_vertices, HEX_SIZE * math.cos(angle))
    table.insert(Utils.hex_vertices, HEX_SIZE * math.sin(angle))
end

function Utils.hex_to_pixel(q, r)
    local x = HEX_SIZE * (math.sqrt(3) * q + math.sqrt(3)/2 * r)
    local y = HEX_SIZE * (3/2 * r)
    return x, y
end

function Utils.pixel_to_hex(x, y)
    local q = (math.sqrt(3)/3 * x - 1/3 * y) / HEX_SIZE
    local r = (2/3 * y) / HEX_SIZE
    return Utils.hex_round(q, r)
end

function Utils.hex_round(q, r)
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

function Utils.spawnParticles(x, y, amount, color)
    for i=1,amount do
        table.insert(particles, {x=x, y=y, vx=math.random(-150,150), vy=math.random(-150,150), life=0.5, max_life=0.5, color=color})
    end
end

return Utils