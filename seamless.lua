--[[
    A simplified OpenSimplex noise implementation that generates seamless, tileable 2D noise.
    Corrected version to handle all calculation paths.
--]]

local STRETCH_2D = -0.211324865405187 -- (1/sqrt(2+1)-1)/2
local SQUISH_2D = 0.366025403784439   -- (sqrt(2+1)-1)/2
local NORM_2D = 47.0

local Gradients2D = {
     5, 2,  2, 5,
    -5, 2, -2, 5,
     5,-2,  2,-5,
    -5,-2, -2,-5,
}

local Gradients3D = {
    -1, 1, 0,  1, 1, 0,  -1,-1, 0,  1,-1, 0,
    -1, 0, 1,  1, 0, 1,  -1, 0,-1,  1, 0,-1,
     0, 1, 1,  0,-1, 1,   0, 1,-1,  0,-1,-1,
}

local Gradients4D = {
     0,-1,-1,-1,  0,-1,-1, 1,  0,-1, 1,-1,  0,-1, 1, 1,
     0, 1,-1,-1,  0, 1,-1, 1,  0, 1, 1,-1,  0, 1, 1, 1,
    -1,-1, 0,-1, -1, 1, 0,-1,  1,-1, 0,-1,  1, 1, 0,-1,
    -1,-1, 0, 1, -1, 1, 0, 1,  1,-1, 0, 1,  1, 1, 0, 1,
}

local Seamless = {}
Seamless.__index = Seamless

local function new(period_x, period_y, seed)
    local self = setmetatable({}, Seamless)
    self.period_x = period_x
    self.period_y = period_y
    self.perm = {}
    local source = {}

    for i = 0, 255 do
        source[i+1] = i
    end

    seed = seed or os.time()
    local rnd = math.random
    math.randomseed(seed)

    for i = 256, 2, -1 do
        local r = rnd(i)
        source[i], source[r] = source[r], source[i]
    end

    for i=1, 256 do
        self.perm[i-1] = source[i]
        self.perm[i+255] = source[i]
    end

    return self
end

function Seamless:get(x, y)
    local period_x = self.period_x
    local period_y = self.period_y

    local dx = x / period_x
    local dy = y / period_y
    
    local s = 2 * math.pi
    
    local nx = math.cos(s * dx) / s
    local ny = math.sin(s * dx) / s
    local nz = math.cos(s * dy) / s
    local nw = math.sin(s * dy) / s
    
    return self:noise4d(nx, ny, nz, nw)
end

function Seamless:noise4d(x,y,z,w)

    local F4 = (math.sqrt(5) - 1) / 4
    local G4 = (5 - math.sqrt(5)) / 20

    local n0, n1, n2, n3, n4;
    local s = (x + y + z + w) * F4
    local i = math.floor(x + s)
    local j = math.floor(y + s)
    local k = math.floor(z + s)
    local l = math.floor(w + s)
    local t = (i + j + k + l) * G4
    local X0 = i - t
    local Y0 = j - t
    local Z0 = k - t
    local W0 = l - t
    local x0 = x - X0
    local y0 = y - Y0
    local z0 = z - Z0
    local w0 = w - W0

    local c1 = (x0 > y0) and 32 or 0
    local c2 = (x0 > z0) and 16 or 0
    local c3 = (y0 > z0) and 8 or 0
    local c4 = (x0 > w0) and 4 or 0
    local c5 = (y0 > w0) and 2 or 0
    local c6 = (z0 > w0) and 1 or 0
    local c = c1 + c2 + c3 + c4 + c5 + c6

    local i1, j1, k1, l1
    local i2, j2, k2, l2
    local i3, j3, k3, l3

    local a = {0,0,0,0, 0,0,1,1, 0,1,0,1, 0,1,1,0, 1,0,0,1, 1,0,1,0, 1,1,0,0, 1,1,1,1}
    local b = {0,0,0,0, 0,1,0,1, 1,0,0,1, 1,1,0,1, 0,0,1,1, 0,1,1,1, 1,0,1,1, 1,1,1,1}
    local d = {0,0,0,0, 1,0,1,0, 0,1,1,0, 1,1,1,0, 0,1,0,1, 1,1,0,1, 1,0,0,1, 1,1,1,1}
    
    i1=a[c+1] or 1; j1=b[c+1] or 0; k1=d[c+1] or 0; l1=a[c+1]==0 and 1 or 0;
    i2=a[c+1] or 1; j2=b[c+1] or 1; k2=d[c+1] or 0; l2=1-i2;
    i3=1-b[c+1]; j3=1-d[c+1]; k3=1-(i3+j3); l3=1-a[c+1]

    local x1 = x0 - i1 + G4
    local y1 = y0 - j1 + G4
    local z1 = z0 - k1 + G4
    local w1 = w0 - l1 + G4
    local x2 = x0 - i2 + 2 * G4
    local y2 = y0 - j2 + 2 * G4
    local z2 = z0 - k2 + 2 * G4
    local w2 = w0 - l2 + 2 * G4
    local x3 = x0 - i3 + 3 * G4
    local y3 = y0 - j3 + 3 * G4
    local z3 = z0 - k3 + 3 * G4
    local w3 = w0 - l3 + 3 * G4
    local x4 = x0 - 1 + 4 * G4
    local y4 = y0 - 1 + 4 * G4
    local z4 = z0 - 1 + 4 * G4
    local w4 = w0 - 1 + 4 * G4

    local t0 = 0.6 - x0 * x0 - y0 * y0 - z0 * z0 - w0 * w0
    if t0 < 0 then n0 = 0 else
        t0 = t0*t0
        local p_i=self.perm[(i%256)+1]
        local p_j=self.perm[((p_i+j)%256)+1]
        local p_k=self.perm[((p_j+k)%256)+1]
        local idx = self.perm[((p_k+l)%256)+1]%32
        n0 = t0 * t0 * (Gradients4D[idx*4+1]*x0 + Gradients4D[idx*4+2]*y0 + Gradients4D[idx*4+3]*z0 + Gradients4D[idx*4+4]*w0)
    end

    local t1 = 0.6 - x1 * x1 - y1 * y1 - z1 * z1 - w1 * w1
    if t1 < 0 then n1 = 0 else
        t1 = t1*t1
        local p_i=self.perm[((i+i1)%256)+1]
        local p_j=self.perm[((p_i+j+j1)%256)+1]
        local p_k=self.perm[((p_j+k+k1)%256)+1]
        local idx = self.perm[((p_k+l+l1)%256)+1]%32
        n1 = t1 * t1 * (Gradients4D[idx*4+1]*x1 + Gradients4D[idx*4+2]*y1 + Gradients4D[idx*4+3]*z1 + Gradients4D[idx*4+4]*w1)
    end
    
    local t2 = 0.6 - x2 * x2 - y2 * y2 - z2 * z2 - w2 * w2
    if t2 < 0 then n2 = 0 else
        t2 = t2*t2
        local p_i=self.perm[((i+i2)%256)+1]
        local p_j=self.perm[((p_i+j+j2)%256)+1]
        local p_k=self.perm[((p_j+k+k2)%256)+1]
        local idx = self.perm[((p_k+l+l2)%256)+1]%32
        n2 = t2 * t2 * (Gradients4D[idx*4+1]*x2 + Gradients4D[idx*4+2]*y2 + Gradients4D[idx*4+3]*z2 + Gradients4D[idx*4+4]*w2)
    end

    local t3 = 0.6 - x3 * x3 - y3 * y3 - z3 * z3 - w3 * w3
    if t3 < 0 then n3 = 0 else
        t3 = t3*t3
        local p_i=self.perm[((i+i3)%256)+1]
        local p_j=self.perm[((p_i+j+j3)%256)+1]
        local p_k=self.perm[((p_j+k+k3)%256)+1]
        local idx = self.perm[((p_k+l+l3)%256)+1]%32
        n3 = t3 * t3 * (Gradients4D[idx*4+1]*x3 + Gradients4D[idx*4+2]*y3 + Gradients4D[idx*4+3]*z3 + Gradients4D[idx*4+4]*w3)
    end

    local t4 = 0.6 - x4 * x4 - y4 * y4 - z4 * z4 - w4 * w4
    if t4 < 0 then n4 = 0 else
        t4 = t4*t4
        local p_i=self.perm[((i+1)%256)+1]
        local p_j=self.perm[((p_i+j+1)%256)+1]
        local p_k=self.perm[((p_j+k+1)%256)+1]
        local idx = self.perm[((p_k+l+1)%256)+1]%32
        n4 = t4 * t4 * (Gradients4D[idx*4+1]*x4 + Gradients4D[idx*4+2]*y4 + Gradients4D[idx*4+3]*z4 + Gradients4D[idx*4+4]*w4)
    end

    return 27 * (n0 + n1 + n2 + n3 + n4)
end

return {
    new = new
}