--[[
    A simplified OpenSimplex noise implementation that generates seamless, tileable 2D noise.
    Based on the work of Supermunk. Essential for creating toroidal (wrapping) worlds.
--]]

local STRETCH_2D = -0.211324865405187 -- (1/sqrt(3+1)-1)/3
local SQUISH_2D = 0.366025403784439 -- (sqrt(3+1)-1)/3
local NORM_2D = 47.0

local Gradients2D = {
    5, 2, 2, 5,
    -5, 2, -2, 5,
    5, -2, 2, -5,
    -5, -2, -2, -5,
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

local function extrav(x, y, dx, dy)
    local d = dx*dx + dy*dy
    if d >= 1 then return 0 end
    d = d * d
    return (1-d) * d * (dx * x + dy * y)
end

function Seamless:get(x, y)
    local period_x = self.period_x
    local period_y = self.period_y

    local dx = x / period_x
    local dy = y / period_y
    local s = math.sin(2 * math.pi * dy)

    local nx = math.cos(2 * math.pi * dx)
    local ny = math.sin(2 * math.pi * dx)
    local nz = math.cos(2 * math.pi * dy)
    local nw = s

    return self:noise4d(nx, ny, nz, nw)
end

function Seamless:noise4d(x, y, z, w)
    local stretch_offset = (x + y + z + w) * ( (math.sqrt(4+1)-1)/4 )
    local xs, ys, zs, ws = x + stretch_offset, y + stretch_offset, z + stretch_offset, w + stretch_offset

    local xsb, ysb, zsb, wsb = math.floor(xs), math.floor(ys), math.floor(zs), math.floor(ws)
    local squish_offset = (xsb + ysb + zsb + wsb) * ( (1/math.sqrt(4+1)-1)/4 )
    local xb, yb, zb, wb = xsb + squish_offset, ysb + squish_offset, zsb + squish_offset, wsb + squish_offset

    local xins, yins, zins, wins = xs - xsb, ys - ysb, zs - zsb, ws - wsb
    local in_sum = xins + yins + zins + wins

    local dx0, dy0, dz0, dw0 = x - xb, y - yb, z - zb, w - wb

    local value = 0

    local c = (xins > yins and 1) or (xins < yins and 2) or -1
    if c == -1 then c = (ysb%2 == 0 and 1) or 2 end
    if c == 1 then
        if xins > zins then
            if yins > zins then c = 1 else c = 3 end
        else
            c = 3
        end
    else
        if xins < zins then
            if yins < zins then c = 2 else c = 3 end
        else
            c = 3
        end
    end

    if c == 1 then
        if xins > wins then
            if yins > wins then
                if zins > wins then c = 1 else c = 4 end
            else
                c = 4
            end
        else
            c = 4
        end
    elseif c == 2 then
        if xins < wins then
            if yins < wins then
                if zins < wins then c = 2 else c = 4 end
            else
                c = 4
            end
        else
            c = 4
        end
    else
        c = 4
    end

    local dx_ext0, dy_ext0, dz_ext0, dw_ext0 = 0,0,0,0
    local dx_ext1, dy_ext1, dz_ext1, dw_ext1 = 0,0,0,0
    local dx_ext2, dy_ext2, dz_ext2, dw_ext2 = 0,0,0,0

    local xsv_ext0, ysv_ext0, zsv_ext0, wsv_ext0 = 0,0,0,0
    local xsv_ext1, ysv_ext1, zsv_ext1, wsv_ext1 = 0,0,0,0
    local xsv_ext2, ysv_ext2, zsv_ext2, wsv_ext2 = 0,0,0,0

    if c == 1 then
        local x_pos = xins; y_pos = yins; z_pos = zins; w_pos = wins
        xsv_ext0 = xsb + 1; ysv_ext0 = ysb; zsv_ext0 = zsb; wsv_ext0 = wsb
        dx_ext0 = dx0 - 1 - SQUISH_2D*2; dy_ext0 = dy0 - SQUISH_2D*2; dz_ext0 = dz0 - SQUISH_2D*2; dw_ext0 = dw0 - SQUISH_2D*2
        xsv_ext1 = xsb + 1; ysv_ext1 = ysb + 1; zsv_ext1 = zsb; wsv_ext1 = wsb
        dx_ext1 = dx0 - 1 - SQUISH_2D*3; dy_ext1 = dy0 - 1 - SQUISH_2D*3; dz_ext1 = dz0 - SQUISH_2D*3; dw_ext1 = dw0 - SQUISH_2D*3
        xsv_ext2 = xsb + 1; ysv_ext2 = ysb + 1; zsv_ext2 = zsb + 1; wsv_ext2 = wsb
        dx_ext2 = dx0 - 1 - SQUISH_2D*4; dy_ext2 = dy0 - 1 - SQUISH_2D*4; dz_ext2 = dz0 - 1 - SQUISH_2D*4; dw_ext2 = dw0 - SQUISH_2D*4
    elseif c == 2 then
        local x_pos = wins; y_pos = zins; z_pos = yins; w_pos = xins
        xsv_ext0 = xsb; ysv_ext0 = ysb; zsv_ext0 = zsb; wsv_ext0 = wsb + 1
        dx_ext0 = dx0 - SQUISH_2D*2; dy_ext0 = dy0 - SQUISH_2D*2; dz_ext0 = dz0 - SQUISH_2D*2; dw_ext0 = dw0 - 1 - SQUISH_2D*2
        xsv_ext1 = xsb; ysv_ext1 = ysb; zsv_ext1 = zsb + 1; wsv_ext1 = wsb + 1
        dx_ext1 = dx0 - SQUISH_2D*3; dy_ext1 = dy0 - SQUISH_2D*3; dz_ext1 = dz0 - 1 - SQUISH_2D*3; dw_ext1 = dw0 - 1 - SQUISH_2D*3
        xsv_ext2 = xsb; ysv_ext2 = ysb + 1; zsv_ext2 = zsb + 1; wsv_ext2 = wsb + 1
        dx_ext2 = dx0 - SQUISH_2D*4; dy_ext2 = dy0 - 1 - SQUISH_2D*4; dz_ext2 = dz0 - 1 - SQUISH_2D*4; dw_ext2 = dw0 - 1 - SQUISH_2D*4
    elseif c == 3 then
        local x_pos = wins; y_pos = yins; z_pos = zins; w_pos = xins
        xsv_ext0 = xsb; ysv_ext0 = ysb; zsv_ext0 = zsb + 1; wsv_ext0 = wsb
        dx_ext0 = dx0 - SQUISH_2D*2; dy_ext0 = dy0 - SQUISH_2D*2; dz_ext0 = dz0 - 1 - SQUISH_2D*2; dw_ext0 = dw0 - SQUISH_2D*2
        xsv_ext1 = xsb; ysv_ext1 = ysb + 1; zsv_ext1 = zsb + 1; wsv_ext1 = wsb
        dx_ext1 = dx0 - SQUISH_2D*3; dy_ext1 = dy0 - 1 - SQUISH_2D*3; dz_ext1 = dz0 - 1 - SQUISH_2D*3; dw_ext1 = dw0 - SQUISH_2D*3
        xsv_ext2 = xsb + 1; ysv_ext2 = ysb + 1; zsv_ext2 = zsb + 1; wsv_ext2 = wsb
        dx_ext2 = dx0 - 1 - SQUISH_2D*4; dy_ext2 = dy0 - 1 - SQUISH_2D*4; dz_ext2 = dz0 - 1 - SQUISH_2D*4; dw_ext2 = dw0 - SQUISH_2D*4
    else
        local x_pos = zins; y_pos = yins; z_pos = xins; w_pos = wins
        xsv_ext0 = xsb; ysv_ext0 = ysb; zsv_ext0 = zsb; wsv_ext0 = wsb + 1
        dx_ext0 = dx0 - SQUISH_2D*2; dy_ext0 = dy0 - SQUISH_2D*2; dz_ext0 = dz0 - SQUISH_2D*2; dw_ext0 = dw0 - 1 - SQUISH_2D*2
        xsv_ext1 = xsb; ysv_ext1 = ysb + 1; zsv_ext1 = zsb; wsv_ext1 = wsb + 1
        dx_ext1 = dx0 - SQUISH_2D*3; dy_ext1 = dy0 - 1 - SQUISH_2D*3; dz_ext1 = dz0 - SQUISH_2D*3; dw_ext1 = dw0 - 1 - SQUISH_2D*3
        xsv_ext2 = xsb + 1; ysv_ext2 = ysb + 1; zsv_ext2 = zsb; wsv_ext2 = wsb + 1
        dx_ext2 = dx0 - 1 - SQUISH_2D*4; dy_ext2 = dy0 - 1 - SQUISH_2D*4; dz_ext2 = dz0 - SQUISH_2D*4; dw_ext2 = dw0 - 1 - SQUISH_2D*4
    end

    local p = self.perm
    local g = Gradients2D

    local attn_ext0 = 2 - dx_ext0*dx_ext0 - dy_ext0*dy_ext0 - dz_ext0*dz_ext0 - dw_ext0*dw_ext0
    if attn_ext0 > 0 then
        local p_ext0 = p[ (p[ (p[xsv_ext0%256] + ysv_ext0)%256 ] + zsv_ext0)%256 ] + wsv_ext0
        attn_ext0 = attn_ext0 * attn_ext0
        value = value + attn_ext0 * attn_ext0 * (g[p_ext0%16 * 2 + 1]*dx_ext0 + g[p_ext0%16 * 2 + 2]*dy_ext0)
    end
    local attn_ext1 = 2 - dx_ext1*dx_ext1 - dy_ext1*dy_ext1 - dz_ext1*dz_ext1 - dw_ext1*dw_ext1
    if attn_ext1 > 0 then
        local p_ext1 = p[ (p[ (p[xsv_ext1%256] + ysv_ext1)%256 ] + zsv_ext1)%256 ] + wsv_ext1
        attn_ext1 = attn_ext1 * attn_ext1
        value = value + attn_ext1 * attn_ext1 * (g[p_ext1%16 * 2 + 1]*dx_ext1 + g[p_ext1%16 * 2 + 2]*dy_ext1)
    end
    local attn_ext2 = 2 - dx_ext2*dx_ext2 - dy_ext2*dy_ext2 - dz_ext2*dz_ext2 - dw_ext2*dw_ext2
    if attn_ext2 > 0 then
        local p_ext2 = p[ (p[ (p[xsv_ext2%256] + ysv_ext2)%256 ] + zsv_ext2)%256 ] + wsv_ext2
        attn_ext2 = attn_ext2 * attn_ext2
        value = value + attn_ext2 * attn_ext2 * (g[p_ext2%16 * 2 + 1]*dx_ext2 + g[p_ext2%16 * 2 + 2]*dy_ext2)
    end

    local x_pos = x_pos - 1 + SQUISH_2D*3; y_pos = y_pos - 1 + SQUISH_2D*3; z_pos = z_pos - 1 + SQUISH_2D*3; w_pos = w_pos - 1 + SQUISH_2D*3
    local attn_ext3 = 2 - x_pos*x_pos - y_pos*y_pos - z_pos*z_pos - w_pos*w_pos
    if attn_ext3 > 0 then
        local p_ext3 = p[ (p[ (p[(xsb+1)%256] + ysb+1)%256 ] + zsb+1)%256 ] + wsb+1
        attn_ext3 = attn_ext3 * attn_ext3
        value = value + attn_ext3 * attn_ext3 * (g[p_ext3%16 * 2 + 1]*x_pos + g[p_ext3%16 * 2 + 2]*y_pos)
    end

    return value / NORM_2D
end

return {
    new = new
}