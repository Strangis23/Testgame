--[[
  Perlin noise implementation in Lua.
  Based on the original Java implementation by Ken Perlin.
  Public Domain.
--]]

local M = {}
local M_TWO_PI = math.pi * 2
local M_PI = math.pi

local PERMUTATION
local p = {}

local function new_p()
  for i=0,255 do
    p[i] = i
  end

  for i=255,0,-1 do
    local n = math.random(0, i)
    p[i],p[n] = p[n],p[i]
  end

  PERMUTATION = {}
  for i=0,511 do
    PERMUTATION[i] = p[i % 256]
  end
end

new_p()

local function fade(t)
  return t * t * t * (t * (t * 6 - 15) + 10)
end

local function lerp(t, a, b)
  return a + t * (b - a)
end

local function grad(hash, x, y, z)
  local h = hash % 16
  local u = h < 8 and x or y
  local v

  if h < 4 then
    v = y
  elseif h == 12 or h == 14 then
    v = x
  else
    v = z
  end

  return ((h%2 == 0) and u or -u) + ((h%4 == 0) and v or -v)
end

local Perlin = {}
Perlin.__index = Perlin

function Perlin:get(x, y, z)
  y = y or 0
  z = z or 0

  if self.octaves > 1 then
    local a = 0
    local f = self.frequency
    local w = 0.5
    local total_w = 0

    for i=0,self.octaves do
      a = a + self:noise(x*f,y*f,z*f)*w
      total_w = total_w + w
      f = f*2
      w = w*self.persistence
    end
    return a/total_w
  end
  return self:noise(x*self.frequency, y*self.frequency, z*self.frequency)
end

function Perlin:noise(x, y, z)
  local floorX = math.floor(x)
  local floorY = math.floor(y)
  local floorZ = math.floor(z)

  local X = floorX % 255
  local Y = floorY % 255
  local Z = floorZ % 255

  x = x - floorX
  y = y - floorY
  z = z - floorZ

  local fadeX = fade(x)
  local fadeY = fade(y)
  local fadeZ = fade(z)

  local A = PERMUTATION[X] + Y
  local AA = PERMUTATION[A] + Z
  local AB = PERMUTATION[A+1] + Z
  local B = PERMUTATION[X+1] + Y
  local BA = PERMUTATION[B] + Z
  local BB = PERMUTATION[B+1] + Z

  return lerp(fadeZ, lerp(fadeY, lerp(fadeX, grad(PERMUTATION[AA], x, y, z),
                                          grad(PERMUTATION[BA], x-1, y, z)),
                               lerp(fadeX, grad(PERMUTATION[AB], x, y-1, z),
                                          grad(PERMUTATION[BB], x-1, y-1, z))),
                    lerp(fadeY, lerp(fadeX, grad(PERMUTATION[AA+1], x, y, z-1),
                                          grad(PERMUTATION[BA+1], x-1, y, z-1)),
                               lerp(fadeX, grad(PERMUTATION[AB+1], x, y-1, z-1),
                                          grad(PERMUTATION[BB+1], x-1, y-1, z-1))))
end

function M.new(seed)
  local o = {}
  setmetatable(o, Perlin)
  o.octaves = 1
  o.frequency = 1
  o.persistence = 0.5

  if seed then
    math.randomseed(seed)
    new_p()
  end
  return o
end

return M