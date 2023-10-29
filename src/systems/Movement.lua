local tiny = require("lib.tiny")
local lib = require("lib.lib")

local movement = tiny.processingSystem()
movement.filter = tiny.requireAll("position", "hitbox")
movement.updateSystem = true

local abs = math.abs

local function isOverlapping(x1,y1,w1,h1, x2,y2,w2,h2)
  return x1 < x2+w2 and
         x2 < x1+w1 and
         y1 < y2+h2 and
         y2 < y1+h1
end

function movement:process(e,dt)
    if e.velocity then
        local ex,ey = e.position.x,e.position.y
        local evx,evy = e.velocity.x,e.velocity.y
        local goalX, goalY =
            ex + evx * dt,
            ey + evy * dt
        if e.controllable then
            print(ex,ey,evx,evy)
            print(goalX,goalY)
            print(#self.entities)
        end

        if e.collidable and (abs(e.velocity.x) > 0 or abs(e.velocity.y) > 0) then
            for index,object in ipairs(self.entities) do
                if e == object then break end
                local ox,oy = object.position.x, object.position.y
                local oh,ow = object.hitbox.h, object.hitbox.w
                local eh,ew = e.hitbox.h, e.hitbox.w
                if isOverlapping(goalX,goalY,ew,eh, ox,oy,ow,oh) then
                    print("overlap detected")
                    goalX, goalY = e.position.x, e.position.y
                end
            end
            e.position.x, e.position.y = goalX,goalY
        else
            e.position.x, e.position.y = goalX,goalY
        end
    end
    if e.time then
        e.time = e.time + dt
        if e.time > e.lifetime then
            tiny.removeEntity(World, e)
        end
    end
    if e.controllable then
        PlayerX, PlayerY = e.position.x, e.position.y
    end
end

return movement
