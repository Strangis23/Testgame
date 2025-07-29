--[[
    A robust and simple seamless noise generator for LÖVE.
    This version uses a blending technique with four separate noise maps,
    which is much more stable than complex 4D projection methods.
--]]

-- We will use a standard Perlin/OpenSimplex library as the base.
-- This code is a self-contained version of simplex noise.

local STRETCH_2D = -0.211324865405187
local SQUISH_2D = 0.366025403784439
local NORM_2D = 47.0

local Gradients2D = {
     5, 2,  2, 5, -5, 2, -2, 5,
     5,-2,  2,-5, -5,-2, -2,-5,
}

local Simplex = {}
Simplex.__index = Simplex

local function new_simplex(seed)
    local self = setmetatable({}, Simplex)
    self.perm = {}
    local source = {}
    for i=0,255 do source[i+1] = i end
    seed = seed or os.time()
    local rnd = math.random
    math.randomseed(seed)
    for i=256,2,-1 do
        local r = rnd(i)
        source[i], source[r] = source[r], source[i]
    end
    for i=1,256 do self.perm[i-1] = source[i]; self.perm[i+255] = source[i] end
    return self
end

function Simplex:get(x, y)
    local stretchOffset = (x + y) * STRETCH_2D
    local xs, ys = x + stretchOffset, y + stretchOffset
    local xsb, ysb = math.floor(xs), math.floor(ys)
    local squishOffset = (xsb + ysb) * SQUISH_2D
    local xb, yb = xsb + squishOffset, ysb + squishOffset
    local x0, y0 = x - xb, y - yb
    local x1, y1 = x0 - 1 - SQUISH_2D*2, y0 - SQUISH_2D*2
    local x2, y2 = x0 - SQUISH_2D, y0 - 1 - SQUISH_2D
    local inSum = x0 + y0
    if inSum <= 1 then
        local z = 1 - inSum
        if z > x0 or z > y0 then
            if x0 > y0 then x2, y2 = x0 - 1, y0
            else x2, y2 = x0, y0 - 1 end
        end
    else
        local z = 2 - inSum
        if z < x0 or z < y0 then
            if x0 > y0 then x1, y1 = x0 - 1, y0 - 1
            else x1, y1 = x0, y0 - 2 end
        end
    end
    local t0 = 0.5 - x0*x0 - y0*y0
    local n0
    if t0 < 0 then n0 = 0 else
        t0 = t0 * t0
        local p_i=self.perm[(xsb%256)+1]
        local idx = self.perm[((p_i+ysb)%256)+1]%8
        n0 = t0 * t0 * (Gradients2D[idx*2+1]*x0 + Gradients2D[idx*2+2]*y0)
    end
    local t1 = 0.5 - x1*x1 - y1*y1
    local n1
    if t1 < 0 then n1 = 0 else
        t1 = t1 * t1
        local p_i=self.perm[((xsb+1)%256)+1]
        local idx = self.perm[((p_i+ysb+1)%256)+1]%8
        n1 = t1 * t1 * (Gradients2D[idx*2+1]*x1 + Gradients2D[idx*2+2]*y1)
    end
    local t2 = 0.5 - x2*x2 - y2*y2
    local n2
    if t2 < 0 then n2 = 0 else
        t2 = t2 * t2
        local p_i=self.perm[((xsb+(inSum<=1 and 1 or 0))%256)+1]
        local idx = self.perm[((p_i+ysb+(inSum<=1 and 0 or 1))%256)+1]%8
        n2 = t2 * t2 * (Gradients2D[idx*2+1]*x2 + Gradients2D[idx*2+2]*y2)
    end
    return (n0 + n1 + n2) * NORM_2D
end

-- The main seamless noise generator
local Seamless = {}
Seamless.__index = Seamless

function Seamless.new(period_x, period_y, seed)
    local self = setmetatable({}, Seamless)
    self.period_x = period_x
    self.period_y = period_y
    -- Create four separate noise generators with different seeds
    self.noise1 = new_simplex(seed)
    self.noise2 = new_simplex(seed + 1)
    self.noise3 = new_simplex(seed + 2)
    self.noise4 = new_simplex(seed + 3)
    return self
end

function Seamless:get(x, y)
    -- Normalize coordinates to a 0-1 range
    local s = x / self.period_x
    local t = y / self.period_y
    
    -- Get noise values from the four generators
    local n1 = self.noise1:get(s, t)
    local n2 = self.noise2:get(s + self.period_x, t)
    local n3 = self.noise3:get(s, t + self.period_y)
    local n4 = self.noise4:get(s + self.period_x, t + self.period_y)

    -- Blend the noise values together seamlessly
    local xt = (1 - math.cos(s * 2 * math.pi)) * 0.5
    local yt = (1 - math.cos(t * 2 * math.pi)) * 0.5
    
    local xy1 = lerp(n1, n2, xt)
    local xy2 = lerp(n3, n4, xt)
    
    return lerp(xy1, xy2, yt)
end

-- Helper function for linear interpolation
function lerp(a, b, t)
    return a * (1 - t) + b * t
end

return Seamless