-- modules/utils.lua
local G = require 'modules.globals'
local M = {}
function M.hexToWorld(col,row)local x=G.HEX_HORZ_SPACING*(col-1);if(row%2)==0 then x=x+G.HEX_HORZ_SPACING/2 end;local y=G.HEX_VERT_SPACING*(row-1);return x,y end
function M.worldToHex(x,y)local roughRow=y/G.HEX_VERT_SPACING;local row=math.floor(roughRow+0.5)+1;local roughCol=(x-((row%2==0)and(G.HEX_HORZ_SPACING/2)or 0))/G.HEX_HORZ_SPACING;local col=math.floor(roughCol+0.5)+1;return col,row end
function M.checkCollision(x1,y1,w1,h1,x2,y2,w2,h2)return x1<x2+w2 and x2<x1+w1 and y1<y2+h2 and y2<y1+h1 end
function M.isPointInCircle(px,py,cx,cy,r)return((px-cx)^2+(py-cy)^2)<r^2 end
function M.isPointInRect(px,py,rx,ry,rw,rh)return px>rx and px<rx+rw and py>ry and py<ry+rh end
return M