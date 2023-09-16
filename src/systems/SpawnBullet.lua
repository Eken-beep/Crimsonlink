local tiny = require("lib.tiny")
local spawnBullet = {}

local px,py
local filter = tiny.requireAll("velocity", "position", "controllable")

for _,v in ipairs(World.entities) do
    if filter(nil,v) then
        px,py = v.position.x, v.position.y
    end
end

spawnBullet.newBullet = function (x,y)
    local angle = math.atan2(py-y,px-x)
    local bullet = {
        parentIsPlayer = true,
        position = {x = px, y = py},
        velocity = {x = math.cos(angle)*-100,
                    y = math.sin(angle)*-100},
    }
    setmetatable(bullet, {
        __index = require("src.entities.Bullet")
    })
    World:addEntity(bullet)
end

return spawnBullet
